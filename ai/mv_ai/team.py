"""Agent team: Claude Opus 5.5 is the main developer; specialists cover what they do best.

    START -> lead --delegate--> coder   (Opus: reads, searches and edits the repo)              --+
              ^                 tester  (Opus: runs autotest / balance sim, reads)              --+
              |                 analyst (Gemini 4 Argon: whole-repo analysis, long logs, screenshots)+
              |                 writer  (gemma4:12b local: lore, story, event text, localization) --+
              +-------------------------------------------------------------------------------------+
    lead (no more delegations) -> END with a report

File writes pause the graph (LangGraph interrupt) until a human approves them. Nothing is
committed or pushed: review the result with `git diff` and commit yourself.

    uv run python -m mv_ai.team "เพิ่ม feature flag ให้ engine bay แล้วรัน autotest" [--yes]
"""
import argparse
import re
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path
from typing import TypedDict

from langgraph.checkpoint.memory import InMemorySaver
from langgraph.graph import END, START, StateGraph
from langgraph.types import Command, interrupt

from .config import Config
from .llms import ClaudeLLM, GeminiLLM, LocalLLM, claude_turn
from .retrieve import Index, render
from .tools import NEEDS_APPROVAL, RepoTools, ToolError, preview, schemas, validate

MAX_LEAD_TURNS = 25
MAX_WORKER_TURNS = 40

PROJECT = """Project: "Apocarlypse: Mobile Vault", an idle survival game for mobile web (portrait first).
Rules: Godot 4.7.2-stable only, GDScript; never invent Godot APIs (say when unsure, cite docs.godotengine.org
stable). True 16-bit dark post-apocalyptic pixel art; the vehicle has 3 rooms per floor. Every feature needs
an autotest check, a Dev action + GOD MODE button, and a Features switch (see feature-flags in README).
Saves are JSON: ids load as floats, so never Array.find/has an int id."""

LEAD_SYSTEM = f"""You lead a small dev team working on a Godot game repo. {PROJECT}

You cannot touch files yourself. Use the delegate tool, one task at a time:
- coder: Claude Opus with read/search/edit tools. All code changes go through it. Give it precise,
  self-contained tasks.
- tester: Claude Opus that can run the Godot autotest and the headless balance sim, and read code.
- analyst: Gemini 4 Argon with a 1M-token window, fed a wide slice of the repo. Use it for what needs a
  lot read at once: how systems connect, impact of a change across files, long logs and docs. It can
  also look at images: put screenshot paths (e.g. from the autotest output folder) in the task and it
  reviews them for visual/layout problems.
- writer: gemma4:12b running locally (free, private). Use it for lore, story, event and NPC text, item
  flavour, and localization QA: checking Thai/English text for odd, wrong or inconsistent wording
  against the game's existing terms. It returns text; the coder puts it into files.
You are the main developer: you decide the design and code direction yourself and use analyst and writer
for their strengths, not to make engineering decisions.
Plan first, delegate, check results (after code changes, have tester verify), and stop when the task is
done or blocked. Delegated agents don't see this conversation, so include the context they need.
Your final message (no tool call) is the report to the human: what changed (files), what was verified,
what is left. Write it in the language of the task."""

ANALYST_SYSTEM = f"""You are the analyst on a Godot game team. {PROJECT}
Answer from the repository excerpts and cite path:line. Trace how systems connect across files and
call out every place a change would touch. When screenshots are attached, check them for layout,
overlap, clipped or unreadable text (Thai included), and pixel-art problems, naming the image each
finding is in. Say plainly when the excerpts don't cover something."""

WRITER_SYSTEM = """You are the writer for "Apocarlypse: Mobile Vault", a dark post-apocalyptic idle survival game
where survivors live in an armoured vehicle crossing ruined biomes. You write lore, story beats, event
and NPC text and item flavour, and you check localization.
- Match the established names, terms and tone in the reference text; reuse existing Thai terms exactly.
- Thai must read naturally for Thai players: no word-for-word translation, no odd or made-up words, no
  mixed registers. Keep UI strings short enough for a 360 px wide portrait screen.
- For localization checks, list each problem as: original -> suggested fix -> why.
Reply in the language of the task."""

WORKERS = {
    "coder": {
        "effort": "high",
        "tools": ["list_files", "read_file", "search_code", "edit_file", "write_file", "git_diff"],
        "system": f"""You are the coder on the team. {PROJECT}
Read the relevant code before changing it and match the surrounding style. Make the smallest change that
does the job, prefer edit_file over write_file, and don't commit. A human approves each file change; if
one is declined, adapt or explain. Finish with a short summary: files changed and why, and anything you
could not verify.""",
    },
    "tester": {
        "effort": "medium",
        "tools": ["list_files", "read_file", "search_code", "git_diff", "run_autotest", "run_balance"],
        "system": f"""You are the tester on the team. {PROJECT}
Run the checks the task asks for (prefer run_autotest with only='large' for a quick pass, the full run
when the change is broad), read the logs, and report pass/fail with the exact failing lines. If Godot is
not installed, say so and review the diff by reading code instead. Don't change files.""",
    },
}

DELEGATE = {
    "name": "delegate",
    "description": "Give one task to a team member and get their result back.",
    "input_schema": {
        "type": "object",
        "properties": {
            "agent": {"type": "string", "enum": ["coder", "tester", "analyst", "writer"]},
            "task": {"type": "string", "description": "Self-contained instructions with all needed context"},
        },
        "required": ["agent", "task"],
        "additionalProperties": False,
    },
    "strict": True,
}


class TeamState(TypedDict, total=False):
    task: str
    lead: list
    lead_turns: int
    pending: dict | None  # {"id", "agent", "task"} of the delegation being worked on
    worker: list
    worker_turns: int
    log: list
    report: str


def _text(blocks: list) -> str:
    return "\n".join(b["text"] for b in blocks if b.get("type") == "text").strip()


def _tool_uses(blocks: list) -> list:
    return [b for b in blocks if b.get("type") == "tool_use"]


def build_team(cfg: Config | None = None, claude=None, llms: dict | None = None, tools: RepoTools | None = None,
               index: Index | None = None, auto_approve: bool = False, checkpointer=None, emit=None):
    """claude(system, messages, tools, effort, one_tool_at_a_time) -> (blocks, stop_reason, usage).

    emit(agent, kind, data) receives every step (model turns, tool calls, delegations) for the UI.
    """
    cfg = cfg or Config.from_env()
    emit = emit or (lambda agent, kind, data: None)
    if claude is None:
        def claude(system, messages, tool_defs, effort, one=False):
            return claude_turn(cfg, system, messages, tool_defs, effort, one)
    llms = llms or {"opus": ClaudeLLM(cfg), "gemini": GeminiLLM(cfg), "local": LocalLLM(cfg)}
    tools = tools or RepoTools(cfg)
    index = index or Index.build(cfg.repo_root)

    def call_claude(agent, system, messages, tool_defs, effort, one=False):
        t = time.time()
        emit(agent, "llm_start", {"model": cfg.claude_model, "effort": effort})
        blocks, stop, usage = claude(system, messages, tool_defs, effort, one)
        emit(agent, "llm", {"model": usage.get("model", cfg.claude_model), "effort": effort, "stop": stop,
                            "blocks": blocks, "usage": usage, "ms": int((time.time() - t) * 1000)})
        return blocks, stop

    def back_to_lead(state: TeamState, result: str, is_error=False) -> TeamState:
        p = state["pending"]
        emit(p["agent"], "done", {"result": result, "is_error": is_error})
        res = {"type": "tool_result", "tool_use_id": p["id"], "content": result or "(no output)"}
        if is_error:
            res["is_error"] = True
        return {"lead": state["lead"] + [{"role": "user", "content": [res]}], "pending": None,
                "worker": [], "worker_turns": 0,
                "log": state.get("log", []) + [f"{p['agent']} done: {(result or '')[:200]}"]}

    def lead(state: TeamState) -> TeamState:
        msgs = state.get("lead") or [{"role": "user", "content": state["task"]}]
        turns = state.get("lead_turns", 0) + 1
        if turns > MAX_LEAD_TURNS:
            return {"report": f"Stopped after {MAX_LEAD_TURNS} lead turns.\n" + "\n".join(state.get("log", []))}
        blocks, stop = call_claude("lead", LEAD_SYSTEM, msgs, [DELEGATE], "high", True)
        msgs = msgs + [{"role": "assistant", "content": blocks}]
        out: TeamState = {"lead": msgs, "lead_turns": turns}
        if stop == "refusal":
            out["report"] = "The lead model declined this task."
            return out
        calls = _tool_uses(blocks)
        if stop == "tool_use" and calls:
            c = calls[0]
            try:
                validate_delegate(c.get("input"))
            except ToolError as e:
                # answer the bad call right away and let the lead try again
                out["lead"] = msgs + [{"role": "user", "content": [
                    {"type": "tool_result", "tool_use_id": c["id"], "content": str(e), "is_error": True}]}]
                return out
            out["pending"] = {"id": c["id"], **c["input"]}
            emit(c["input"]["agent"], "task", {"task": c["input"]["task"]})
            out["log"] = state.get("log", []) + [f"lead -> {c['input']['agent']}: {c['input']['task'][:200]}"]
            return out
        out["report"] = _text(blocks) or f"(lead stopped: {stop})"
        return out

    def after_lead(state: TeamState) -> str:
        p = state.get("pending")
        if state.get("report"):
            return END
        if not p:  # a malformed delegate call was answered with an error; let the lead retry
            return "lead"
        return {"coder": "worker", "tester": "worker"}.get(p["agent"], p["agent"])

    def worker(state: TeamState) -> TeamState:
        p = state["pending"]
        spec = WORKERS[p["agent"]]
        msgs = state.get("worker") or [{"role": "user", "content": p["task"]}]
        turns = state.get("worker_turns", 0) + 1
        if turns > MAX_WORKER_TURNS:
            return back_to_lead(state, f"{p['agent']} hit {MAX_WORKER_TURNS} turns without finishing.", True)
        blocks, stop = call_claude(p["agent"], spec["system"], msgs, schemas(spec["tools"]), spec["effort"])
        msgs = msgs + [{"role": "assistant", "content": blocks}]
        if stop == "tool_use" and _tool_uses(blocks):
            return {"worker": msgs, "worker_turns": turns}
        if stop == "refusal":
            return back_to_lead(state, f"{p['agent']} declined the task.", True)
        return back_to_lead(state, _text(blocks) or f"({p['agent']} stopped: {stop})")

    def after_worker(state: TeamState) -> str:
        return "worker_tools" if state.get("pending") else "lead"

    def worker_tools(state: TeamState) -> TeamState:
        calls = _tool_uses(state["worker"][-1]["content"])
        # Ask before anything runs: on resume LangGraph re-runs this node from the top.
        risky = [c for c in calls if c["name"] in NEEDS_APPROVAL]
        approved = True
        if risky and not auto_approve:
            ans = interrupt({"agent": state["pending"]["agent"],
                             "changes": [preview(c["name"], c.get("input") or {}) for c in risky]})
            approved = ans is True or str(ans).strip().lower() in ("y", "yes", "ok", "approve")
        results, log = [], []
        agent = state["pending"]["agent"]
        for c in calls:
            res = {"type": "tool_result", "tool_use_id": c["id"]}
            emit(agent, "tool_start", {"name": c["name"], "input": c.get("input")})
            t = time.time()
            try:
                if c["name"] in NEEDS_APPROVAL and not approved:
                    raise ToolError("The human reviewer declined this change.")
                res["content"] = tools.run(c["name"], c.get("input"))
                log.append(f"  {c['name']} ok")
            except (ToolError, OSError, UnicodeDecodeError) as e:
                res.update(content=f"Error: {e}", is_error=True)
                log.append(f"  {c['name']} error: {e}")
            emit(agent, "tool", {"name": c["name"], "input": c.get("input"), "result": res["content"],
                                 "is_error": res.get("is_error", False), "ms": int((time.time() - t) * 1000)})
            results.append(res)
        return {"worker": state["worker"] + [{"role": "user", "content": results}],
                "log": state.get("log", []) + log}

    def _single_shot(agent: str, model: str, system: str, prompt: str, images=None) -> str:
        order = {"gemini": ("gemini", "opus"), "local": ("local", "opus")}[model]
        for name in order:
            if llms[name].available():
                emit(agent, "llm_start", {"model": name, "images": len(images or [])})
                t = time.time()
                ans = llms[name].complete(system, prompt, images) if images and name == "gemini" \
                    else llms[name].complete(system, prompt)
                emit(agent, "llm", {"model": name, "prompt_chars": len(prompt), "images": len(images or []),
                                    "stop": "end_turn",
                                    "blocks": [{"type": "text", "text": ans}], "usage": {},
                                    "ms": int((time.time() - t) * 1000)})
                return ans
        raise ToolError("no model available for this agent")

    def analyst(state: TeamState) -> TeamState:
        task = state["pending"]["task"]
        try:
            ctx = render(index.search(task, k=120))
            images = screenshots(task, cfg.repo_root)
            note = f"\n\n{len(images)} screenshot(s) attached in the order they appear in the task." if images else ""
            ans = _single_shot("analyst", "gemini", ANALYST_SYSTEM,
                               f"Repository excerpts:\n\n{ctx}\n\nTask: {task}{note}", images)
            return back_to_lead(state, ans)
        except Exception as e:
            return back_to_lead(state, f"analyst failed: {e}", True)

    def writer(state: TeamState) -> TeamState:
        task = state["pending"]["task"]
        try:
            # existing in-game text is the reference for names, terms and tone
            ctx = render(index.search(task + " lore event text label name", k=12))
            ans = _single_shot("writer", "local", WRITER_SYSTEM, f"Existing game text and code for reference:\n\n"
                               f"{ctx}\n\nTask: {task}")
            return back_to_lead(state, ans)
        except Exception as e:
            return back_to_lead(state, f"writer failed: {e}", True)

    g = StateGraph(TeamState)
    g.add_node("lead", lead)
    g.add_node("worker", worker)
    g.add_node("worker_tools", worker_tools)
    g.add_node("analyst", analyst)
    g.add_node("writer", writer)
    g.add_edge(START, "lead")
    g.add_conditional_edges("lead", after_lead, ["lead", "worker", "analyst", "writer", END])
    g.add_conditional_edges("worker", after_worker, ["worker_tools", "lead"])
    g.add_edge("worker_tools", "worker")
    g.add_edge("analyst", "lead")
    g.add_edge("writer", "lead")
    return g.compile(checkpointer=checkpointer or InMemorySaver())


SHOT = re.compile(r"[^\s'\"`<>|]+\.(?:png|jpe?g|webp)", re.I)
MAX_IMAGES = 12


def screenshots(task: str, root: Path) -> list:
    """Images named in the task: repo files, or autotest output written to the temp folder."""
    tmp = Path(tempfile.gettempdir()).resolve()
    out = []
    for m in SHOT.findall(task)[:MAX_IMAGES]:
        p = Path(m) if Path(m).is_absolute() else root / m
        p = p.resolve()
        inside = p.is_relative_to(root.resolve()) or (p.is_relative_to(tmp) and "mv-autotest-" in str(p))
        if inside and p.is_file() and p.stat().st_size < 8_000_000:
            mime = "image/png" if p.suffix.lower() == ".png" else "image/webp" if p.suffix.lower() == ".webp" else "image/jpeg"
            out.append((p.read_bytes(), mime))
    return out


def validate_delegate(args) -> None:
    if not isinstance(args, dict) or args.get("agent") not in ("coder", "tester", "analyst", "writer") \
            or not isinstance(args.get("task"), str) or not args["task"].strip():
        raise ToolError("delegate needs agent (coder/tester/analyst/writer) and a non-empty task")


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="mv_ai.team", description="Run the agent team on a task.")
    ap.add_argument("task", nargs="+")
    ap.add_argument("--yes", action="store_true", help="approve every file change without asking")
    a = ap.parse_args()
    cfg = Config.from_env()
    if not ClaudeLLM(cfg).available():
        print("The lead needs ANTHROPIC_API_KEY in ai/.env", file=sys.stderr)
        return 1
    branch = subprocess.run(["git", "branch", "--show-current"], cwd=cfg.repo_root, capture_output=True,
                            text=True).stdout.strip()
    print(f"repo branch: {branch or '?'}" + ("  (tip: work on a feature branch)" if branch == "main" else ""))
    team = build_team(cfg, auto_approve=a.yes)
    conf = {"configurable": {"thread_id": str(uuid.uuid4())}, "recursion_limit": 1000}
    inp = {"task": " ".join(a.task)}
    while True:
        paused = None
        for step in team.stream(inp, conf, stream_mode="updates"):
            for node, upd in step.items():
                if node == "__interrupt__":
                    paused = upd[0].value
                elif upd and upd.get("log"):
                    print(upd["log"][-1])
        if not paused:
            break
        print(f"\n[{paused['agent']}] wants to change files:")
        for ch in paused["changes"]:
            print("-" * 60 + "\n" + ch)
        ans = input("\nApprove? [y/N] ").strip().lower() == "y"
        inp = Command(resume=ans)
    print("\n" + "=" * 60 + "\n" + team.get_state(conf).values.get("report", "(no report)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
