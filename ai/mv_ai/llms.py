"""The three model backends. Each has the same tiny surface: available() and complete()."""
import os
import re

import httpx

from .config import Config


class LLMError(RuntimeError):
    pass


class ClaudeLLM:
    """Claude Opus through the official Anthropic SDK (reasoning-heavy work)."""

    name = "opus"

    def __init__(self, cfg: Config):
        self.cfg = cfg

    def available(self) -> bool:
        return any(os.environ.get(k) for k in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_PROFILE"))

    def complete(self, system: str, prompt: str) -> str:
        import anthropic

        client = anthropic.Anthropic()
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


class GeminiLLM:
    """Gemini 4 Argon through google-genai's Interactions API (1M-token context)."""

    name = "gemini"

    def __init__(self, cfg: Config):
        self.cfg = cfg

    def available(self) -> bool:
        return bool(os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY"))

    def complete(self, system: str, prompt: str) -> str:
        from google import genai

        client = genai.Client()
        # Sampling params are ignored on this model; Google recommends >= 32k output
        # tokens and >= 15 min timeouts because thinking spends from the same budget.
        it = client.interactions.create(
            model=self.cfg.gemini_model,
            input=prompt,
            system_instruction=system,
            generation_config={"thinking_level": self.cfg.gemini_thinking, "max_output_tokens": 65536},
            timeout=900,
        )
        return it.output_text or ""


_THINK = re.compile(r"<think>.*?</think>\s*", re.S)


class LocalLLM:
    """Any OpenAI-compatible local server (Ollama by default) running Qwen3-4B."""

    name = "local"

    def __init__(self, cfg: Config):
        self.cfg = cfg

    def available(self) -> bool:
        try:
            return httpx.get(f"{self.cfg.local_base_url}/models", timeout=2).status_code == 200
        except httpx.HTTPError:
            return False

    def complete(self, system: str, prompt: str, max_tokens: int = 4096) -> str:
        r = httpx.post(
            f"{self.cfg.local_base_url}/chat/completions",
            json={
                "model": self.cfg.local_model,
                "messages": [{"role": "system", "content": system}, {"role": "user", "content": prompt}],
                "max_tokens": max_tokens,
                # Qwen3 thinks by default; routing and small jobs don't need it.
                "reasoning_effort": "none",
            },
            timeout=300,
        )
        if r.status_code != 200:
            raise LLMError(f"local LLM {r.status_code}: {r.text[:300]}")
        text = r.json()["choices"][0]["message"].get("content") or ""
        return _THINK.sub("", text).strip()


def default_llms(cfg: Config) -> dict:
    return {m.name: m for m in (LocalLLM(cfg), ClaudeLLM(cfg), GeminiLLM(cfg))}
