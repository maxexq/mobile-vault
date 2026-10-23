"""The three model backends. Each has the same tiny surface: available() and complete()."""
import json
import os
import re
import uuid

import httpx

from .config import Config


class LLMError(RuntimeError):
    pass


def claude_client():
    """Anthropic client. An org-level API key (not scoped to one workspace) must name the
    workspace on every request, so ANTHROPIC_WORKSPACE_ID becomes the anthropic-workspace-id header."""
    import anthropic

    ws = os.environ.get("ANTHROPIC_WORKSPACE_ID", "").strip()
    return anthropic.Anthropic(default_headers={"anthropic-workspace-id": ws} if ws else None)


class ClaudeLLM:
    """Claude Opus through the official Anthropic SDK (reasoning-heavy work)."""

    name = "opus"

    def __init__(self, cfg: Config):
        self.cfg = cfg

    def available(self) -> bool:
        return any(os.environ.get(k) for k in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_PROFILE"))

    def complete(self, system: str, prompt: str) -> str:
        client = claude_client()
        # Streaming avoids HTTP timeouts on long answers; adaptive thinking + effort is
        # the only thinking control on Opus 5.5. "default" fallbacks reroute a
        # safety-classifier refusal to a suitable model server-side.
        with client.beta.messages.stream(
            model=self.cfg.claude_model,
            max_tokens=64000,
            system=system,
            messages=[{"role": "user", "content": prompt}],
            thinking={"type": "adaptive"},
            output_config={"effort": self.cfg.claude_effort},
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
        ) as stream:
            msg = stream.get_final_message()
        if msg.stop_reason == "refusal":
            raise LLMError(f"Claude declined: {msg.stop_details}")
        return "".join(b.text for b in msg.content if b.type == "text")


def claude_turn(cfg: Config, system: str, messages: list, tools: list, effort: str, one_tool_at_a_time=False):
    """One Claude Opus turn with client tools. Returns (content blocks as dicts, stop_reason, usage).

    Blocks are returned unchanged (as dicts) so the caller can append them to the history
    as-is: thinking blocks must be passed back untouched on the next request.
    """
    client = claude_client()
    choice = {"type": "auto", "disable_parallel_tool_use": True} if one_tool_at_a_time else {"type": "auto"}
    with client.beta.messages.stream(
        model=cfg.claude_model,
        max_tokens=64000,
        system=system,
        messages=messages,
        tools=[{**t, "eager_input_streaming": True} for t in tools],
        tool_choice=choice,
        cache_control={"type": "ephemeral"},  # agent loops resend the same prefix every turn
        # "summarized" returns a readable summary of the reasoning for the inspector UI
        thinking={"type": "adaptive", "display": "summarized"},
        output_config={"effort": effort},
        betas=["server-side-fallback-2026-07-01"],
        fallbacks="default",
    ) as stream:
        msg = stream.get_final_message()
    u = msg.usage
    usage = {
        "model": getattr(msg, "model", cfg.claude_model),
        "input": u.input_tokens,
        "output": u.output_tokens,
        "cache_read": getattr(u, "cache_read_input_tokens", 0) or 0,
        "cache_write": getattr(u, "cache_creation_input_tokens", 0) or 0,
    }
    return [b.model_dump(exclude_none=True) for b in msg.content], msg.stop_reason, usage


class GeminiLLM:
    """Gemini 4 Argon through google-genai's Interactions API (1M-token context)."""

    name = "gemini"

    def __init__(self, cfg: Config):
        self.cfg = cfg

    def available(self) -> bool:
        return bool(os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY"))

    def complete(self, system: str, prompt: str, images: list | None = None) -> str:
        """images: [(png/jpeg bytes, mime_type)] sent alongside the prompt (e.g. autotest screenshots)."""
        import base64

        from google import genai

        client = genai.Client()
        inp = prompt
        if images:
            inp = [{"type": "text", "text": prompt}] + [
                {"type": "image", "data": base64.b64encode(b).decode(), "mime_type": m} for b, m in images]
        # Sampling params are ignored on this model; Google recommends >= 32k output
        # tokens and >= 15 min timeouts because thinking spends from the same budget.
        it = client.interactions.create(
            model=self.cfg.gemini_model,
            input=inp,
            system_instruction=system,
            generation_config={"thinking_level": self.cfg.gemini_thinking, "max_output_tokens": 65536},
            timeout=900,
        )
        return it.output_text or ""


_THINK = re.compile(r"<think>.*?</think>\s*", re.S)


class LocalLLM:
    """Any OpenAI-compatible local server (Ollama by default), gemma4:12b by default."""

    name = "local"

    def __init__(self, cfg: Config):
        self.cfg = cfg

    def available(self) -> bool:
        try:
            return httpx.get(f"{self.cfg.local_base_url}/models", timeout=2).status_code == 200
        except httpx.HTTPError:
            return False

    def complete(self, system: str, prompt: str, max_tokens: int = 8192) -> str:
        r = httpx.post(
            f"{self.cfg.local_base_url}/chat/completions",
            json={
                "model": self.cfg.local_model,
                "messages": [{"role": "system", "content": system}, {"role": "user", "content": prompt}],
                # Thinking models (e.g. qwen3:4b on Ollama) always think first and think:false only
                # moves the thinking into content, so leave room for it and strip <think> below.
                "max_tokens": max_tokens,
            },
            timeout=300,
        )
        if r.status_code != 200:
            raise LLMError(f"local LLM {r.status_code}: {r.text[:300]}")
        choice = r.json()["choices"][0]
        text = _THINK.sub("", choice["message"].get("content") or "")
        if "</think>" in text:  # opening tag dropped by the server
            text = text.rsplit("</think>", 1)[1]
        if not text.strip() and choice.get("finish_reason") == "length":
            raise LLMError("local LLM used its whole token budget on thinking")
        return text.strip()


LOCAL_BUDGETS = (8192, 24576)  # output tokens per local turn: normal, then one retry for long thinking
_PROMPT_TOOLS: set = set()  # (base_url, model) pairs whose server rejected native tool calling
_JSON_CALL = re.compile(r"\{.*\}", re.S)


def _to_openai(messages: list, prompt_tools: bool) -> list:
    """Anthropic-style history (text / tool_use / tool_result blocks) -> OpenAI chat messages."""
    out = []
    for m in messages:
        c = m["content"]
        if isinstance(c, str):
            out.append({"role": m["role"], "content": c})
            continue
        texts = [b["text"] for b in c if b.get("type") == "text" and b.get("text")]
        uses = [b for b in c if b.get("type") == "tool_use"]
        results = [b for b in c if b.get("type") == "tool_result"]
        if m["role"] == "assistant":
            if prompt_tools:
                calls = [json.dumps({"tool": u["name"], "input": u.get("input") or {}}, ensure_ascii=False) for u in uses]
                out.append({"role": "assistant", "content": "\n".join(texts + calls)})
            else:
                msg = {"role": "assistant", "content": "\n".join(texts)}
                if uses:
                    msg["tool_calls"] = [{"id": u["id"], "type": "function", "function": {
                        "name": u["name"], "arguments": json.dumps(u.get("input") or {}, ensure_ascii=False)}}
                        for u in uses]
                out.append(msg)
            continue
        for r in results:
            body = r.get("content") if isinstance(r.get("content"), str) else json.dumps(r.get("content"))
            body = ("ERROR: " if r.get("is_error") else "") + (body or "")
            if prompt_tools:
                out.append({"role": "user", "content": f"Tool result:\n{body}"})
            else:
                out.append({"role": "tool", "tool_call_id": r["tool_use_id"], "content": body})
        if texts:
            out.append({"role": "user", "content": "\n".join(texts)})
    return out


def _coerce(args, schema: dict):
    """Small local models send numbers as strings or skip optional-looking ints; fix what is obvious."""
    if not isinstance(args, dict):
        return args
    for k, p in (schema.get("properties") or {}).items():
        if p.get("type") == "integer":
            v = args.get(k)
            if isinstance(v, str) and v.strip().lstrip("-").isdigit():
                args[k] = int(v)
            elif v is None and k in schema.get("required", []):
                args[k] = 0
        elif p.get("type") == "string" and args.get(k) is None and k in schema.get("required", []):
            args[k] = ""
    return args


def local_turn(cfg: Config, system: str, messages: list, tools: list, effort: str, one_tool_at_a_time=False):
    """Same contract as claude_turn, served by the local OpenAI-compatible model (Ollama).

    Uses native tool calling; if the server or model rejects tools, falls back to asking for a
    JSON object {"tool": ..., "input": {...}} in the reply.
    """
    key = (cfg.local_base_url, cfg.local_model)
    schemas = {t["name"]: t["input_schema"] for t in tools}
    budget, retried_tools = LOCAL_BUDGETS[0], False
    while True:
        prompt_tools = key in _PROMPT_TOOLS
        sys_text = system
        if prompt_tools and tools:
            spec = "\n".join(f"- {t['name']}: {t['description']}\n  input schema: {json.dumps(t['input_schema'])}"
                             for t in tools)
            sys_text += ("\n\nTools you can call:\n" + spec + "\n\nTo call a tool, reply with ONLY one JSON object "
                         '{"tool": "<name>", "input": {...}} and nothing else. When you are finished, reply in plain text.')
        body = {"model": cfg.local_model, "max_tokens": budget,
                "messages": [{"role": "system", "content": sys_text}] + _to_openai(messages, prompt_tools)}
        if tools and not prompt_tools:
            body["tools"] = [{"type": "function", "function": {"name": t["name"], "description": t["description"],
                                                               "parameters": t["input_schema"]}} for t in tools]
        r = httpx.post(f"{cfg.local_base_url}/chat/completions", json=body, timeout=600)
        if r.status_code == 400 and tools and not prompt_tools and "tool" in r.text.lower() and not retried_tools:
            _PROMPT_TOOLS.add(key)
            retried_tools = True
            continue
        if r.status_code != 200:
            raise LLMError(f"local LLM {r.status_code}: {r.text[:300]}")
        data = r.json()
        choice = data["choices"][0]
        msg = choice["message"]
        # Thinking models can spend the whole budget before answering: retry once with more room.
        if choice.get("finish_reason") == "length" and not msg.get("tool_calls") \
                and not _THINK.sub("", msg.get("content") or "").split("</think>")[-1].strip() \
                and budget < LOCAL_BUDGETS[-1]:
            budget = LOCAL_BUDGETS[-1]
            continue
        break
    raw = msg.get("content") or ""
    thinking = (msg.get("reasoning") or msg.get("reasoning_content") or "").strip()
    thinking += "".join(m.group(0)[7:-8] for m in re.finditer(r"<think>.*?</think>", raw, re.S))
    text = _THINK.sub("", raw)
    if "</think>" in text:
        thinking += text.rsplit("</think>", 1)[0]
        text = text.rsplit("</think>", 1)[1]
    text = text.strip()
    uses = []
    for tc in msg.get("tool_calls") or []:
        fn = tc.get("function") or {}
        args = fn.get("arguments")
        if isinstance(args, str):
            try:
                args = json.loads(args or "{}")
            except ValueError:
                args = None
        uses.append({"type": "tool_use", "id": tc.get("id") or f"call_{uuid.uuid4().hex[:12]}",
                     "name": fn.get("name"), "input": _coerce(args, schemas.get(fn.get("name"), {}))})
    if not uses and tools and text:
        m = _JSON_CALL.search(text)
        if m:
            try:
                obj = json.loads(m.group(0))
            except ValueError:
                obj = None
            if isinstance(obj, dict) and obj.get("tool") in schemas:
                uses.append({"type": "tool_use", "id": f"call_{uuid.uuid4().hex[:12]}", "name": obj["tool"],
                             "input": _coerce(obj.get("input") or {}, schemas[obj["tool"]])})
                text = (text[:m.start()] + text[m.end():]).strip()
    if one_tool_at_a_time:
        uses = uses[:1]
    blocks = ([{"type": "thinking", "thinking": thinking.strip()}] if thinking.strip() else []) \
        + ([{"type": "text", "text": text}] if text else []) + uses
    stop = "tool_use" if uses else ("max_tokens" if choice.get("finish_reason") == "length" else "end_turn")
    u = data.get("usage") or {}
    return blocks, stop, {"model": cfg.local_model, "input": u.get("prompt_tokens", 0),
                          "output": u.get("completion_tokens", 0), "cache_read": 0, "cache_write": 0}


def default_llms(cfg: Config) -> dict:
    return {m.name: m for m in (LocalLLM(cfg), ClaudeLLM(cfg), GeminiLLM(cfg))}
