"""Local web UI for the agent team: start runs, watch every agent step, approve file changes.

Stdlib HTTP server bound to 127.0.0.1 only. Each run executes the LangGraph team in a thread and
records events; the page polls /api/runs/<id>?since=N.
"""
import json
import threading
import time
import uuid
from dataclasses import replace
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from langgraph.types import Command

from ..config import Config
from ..llms import ClaudeLLM, GeminiLLM, LocalLLM
from ..team import build_team

STATIC = Path(__file__).parent / "static"
AGENTS = ["lead", "coder", "tester", "analyst", "writer"]
MAX_FIELD = 20_000
# USD per 1M tokens: input, output, cache read, cache write (5 min). Opus 5.5 list price, Oct 2026.
PRICES = {"claude-opus-5-5": (4.0, 20.0, 0.20, 5.0)}


class Cancelled(Exception):
    pass


def _clip(v):
    if isinstance(v, str):
        return v if len(v) <= MAX_FIELD else v[:MAX_FIELD] + f"\n... ({len(v) - MAX_FIELD} more chars)"
    if isinstance(v, list):
        return [_clip(x) for x in v]
    if isinstance(v, dict):
        return {k: _clip(x) for k, x in v.items() if k != "signature"}
    return v


def cost(usage: dict) -> float:
    """Claude turns only; Gemini/Qwen single shots report no usage. Fallback models are priced as Opus."""
    if not usage or not (usage.get("input") or usage.get("output")):
        return 0.0
    if not str(usage.get("model", "")).startswith("claude"):
        return 0.0  # local model: runs on your own machine
    p = PRICES.get(usage.get("model", ""), PRICES["claude-opus-5-5"])
    return (usage.get("input", 0) * p[0] + usage.get("output", 0) * p[1]
            + usage.get("cache_read", 0) * p[2] + usage.get("cache_write", 0) * p[3]) / 1e6


class Run:
    def __init__(self, task: str, auto_approve: bool, team: str = "claude"):
        self.id = uuid.uuid4().hex[:8]
        self.task, self.auto, self.team_mode = task, auto_approve, team
        self.status = "running"
        self.started = time.time()
        self.events: list[dict] = []
        self.pending = None
        self.report = ""
        self.cancelled = False
        self._decision = None
        self._decided = threading.Event()
        self.team = None
        self.conf = None
        self._lock = threading.Lock()

    def emit(self, agent: str, kind: str, data: dict):
        if self.cancelled:
            raise Cancelled()
        with self._lock:
            self.events.append({"i": len(self.events), "t": round(time.time() - self.started, 2),
                                "agent": agent, "kind": kind, "data": _clip(data)})

    def decide(self, approved: bool) -> bool:
        if self.status != "waiting":
            return False
        self._decision = approved
        self._decided.set()
        return True

    def cancel(self):
        self.cancelled = True
        self._decision = False
        self._decided.set()

    def summary(self) -> dict:
        agents = {a: {"turns": 0, "tools": 0, "input": 0, "output": 0, "cache_read": 0, "cost": 0.0,
                      "models": [], "state": "idle"} for a in AGENTS}
        for e in self.events:
            a = agents.get(e["agent"])
            if a is None:
                continue
            d = e["data"]
            if e["kind"] == "llm":
                a["turns"] += 1
                u = d.get("usage") or {}
                for k in ("input", "output", "cache_read"):
                    a[k] += u.get(k, 0)
                a["cost"] += cost(u)
                if d.get("model") and d["model"] not in a["models"]:
                    a["models"].append(d["model"])
                a["state"] = "working"
            elif e["kind"] == "tool":
                a["tools"] += 1
            elif e["kind"] in ("task", "llm_start", "tool_start"):
                a["state"] = "working"
            elif e["kind"] in ("done", "report"):
                a["state"] = "done"
        if self.pending:
            agents[self.pending["agent"]]["state"] = "waiting"
        return {"id": self.id, "task": self.task, "status": self.status, "auto": self.auto, "team": self.team_mode,
                "elapsed": round(time.time() - self.started, 1), "pending": self.pending,
                "report": self.report, "agents": agents,
                "cost": round(sum(a["cost"] for a in agents.values()), 4), "events": len(self.events)}


class Hub:
    def __init__(self, cfg: Config, make_team=None):
        self.cfg = cfg
        self.make_team = make_team or (lambda run: build_team(replace(cfg, team=run.team_mode),
                                                              auto_approve=run.auto, emit=run.emit))
        self.runs: dict[str, Run] = {}

    def info(self) -> dict:
        """Which team setups can run right now, for the picker in the page."""
        c = self.cfg
        return {"default": c.team, "teams": {
            "claude": {"label": "Claude + Gemini", "ready": ClaudeLLM(c).available(),
                       "models": {"lead": c.claude_model, "coder": c.claude_model, "tester": c.claude_model,
                                  "analyst": c.gemini_model if GeminiLLM(c).available() else c.claude_model,
                                  "writer": c.local_model}},
            "local": {"label": f"Local ({c.local_model})", "ready": LocalLLM(c).available(),
                      "models": {a: c.local_model for a in AGENTS}}}}

    def start(self, task: str, auto_approve: bool, team: str | None = None) -> Run:
        run = Run(task, auto_approve, team if team in ("claude", "local") else self.cfg.team)
        self.runs[run.id] = run
        run.team = self.make_team(run)
        run.conf = {"configurable": {"thread_id": run.id}, "recursion_limit": 1000}
        threading.Thread(target=self._work, args=(run, task, {"task": task}), daemon=True).start()
        return run

    def follow_up(self, run: Run, text: str) -> bool:
        """Continue a finished run: the lead sees its whole history plus the new message."""
        if run.status not in ("done", "error", "cancelled") or not getattr(run, "team", None):
            return False
        lead = run.team.get_state(run.conf).values.get("lead") or []
        if not lead or lead[-1]["role"] != "assistant":
            return False
        run.status, run.report, run.cancelled = "running", "", False
        inp = {"lead": lead + [{"role": "user", "content": text}], "report": "", "pending": None,
               "lead_turns": 0, "worker": [], "worker_turns": 0}
        threading.Thread(target=self._work, args=(run, text, inp), daemon=True).start()
        return True

    def _work(self, run: Run, text: str, inp):
        team, conf = run.team, run.conf
        try:
            run.emit("user", "message", {"text": text})
            while True:
                paused = None
                for step in team.stream(inp, conf, stream_mode="updates"):
                    if "__interrupt__" in step:
                        paused = step["__interrupt__"][0].value
                if not paused:
                    break
                run.pending, run.status = paused, "waiting"
                run.emit(paused["agent"], "approval_wait", paused)
                run._decided.wait()
                run._decided.clear()
                approved = bool(run._decision) and not run.cancelled
                run.pending, run.status = None, "running"
                run.emit(paused["agent"], "approval", {"approved": approved})
                inp = Command(resume=approved)
            run.report = team.get_state(conf).values.get("report", "") or "(no report)"
            run.emit("lead", "report", {"text": run.report})
            run.status = "done"
        except Cancelled:
            run.pending, run.status = None, "cancelled"
        except Exception as e:  # surface every failure in the UI instead of killing the thread silently
            run.pending, run.status = None, "error"
            run.report = f"{type(e).__name__}: {e}"
            with run._lock:
                run.events.append({"i": len(run.events), "t": round(time.time() - run.started, 2),
                                   "agent": "lead", "kind": "error", "data": {"error": run.report}})


def make_handler(hub: Hub):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def _json(self, obj, code=200):
            body = json.dumps(obj, ensure_ascii=False).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def _body(self) -> dict:
            n = int(self.headers.get("Content-Length") or 0)
            return json.loads(self.rfile.read(n) or b"{}") if n else {}

        def do_GET(self):
            path, _, query = self.path.partition("?")
            if path in ("/", "/index.html"):
                body = (STATIC / "index.html").read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            elif path == "/api/info":
                self._json(hub.info())
            elif path == "/api/runs":
                self._json([r.summary() | {"events": len(r.events)} for r in reversed(hub.runs.values())])
            elif path.startswith("/api/runs/"):
                run = hub.runs.get(path.split("/")[3])
                if not run:
                    return self._json({"error": "no such run"}, 404)
                since = int(dict(p.split("=", 1) for p in query.split("&") if "=" in p).get("since", 0))
                self._json(run.summary() | {"new_events": run.events[since:]})
            else:
                self._json({"error": "not found"}, 404)

        def do_POST(self):
            # Custom header => a cross-site page can't post here without a CORS preflight we never answer.
            if self.headers.get("X-MV-UI") != "1":
                return self._json({"error": "forbidden"}, 403)
            parts = self.path.strip("/").split("/")
            try:
                body = self._body()
            except ValueError:
                return self._json({"error": "bad json"}, 400)
            if parts == ["api", "runs"]:
                task = str(body.get("task", "")).strip()
                if not task:
                    return self._json({"error": "task is empty"}, 400)
                return self._json(hub.start(task, bool(body.get("auto_approve")), body.get("team")).summary())
            if len(parts) == 4 and parts[:2] == ["api", "runs"] and parts[2] in hub.runs:
                run = hub.runs[parts[2]]
                if parts[3] == "approve":
                    return self._json({"ok": run.decide(bool(body.get("approve")))})
                if parts[3] == "cancel":
                    run.cancel()
                    return self._json({"ok": True})
                if parts[3] == "message":
                    text = str(body.get("text", "")).strip()
                    if not text:
                        return self._json({"error": "message is empty"}, 400)
                    return self._json({"ok": hub.follow_up(run, text)})
            self._json({"error": "not found"}, 404)

    return Handler


def serve(cfg: Config, port: int, make_team=None) -> ThreadingHTTPServer:
    return ThreadingHTTPServer(("127.0.0.1", port), make_handler(Hub(cfg, make_team)))
