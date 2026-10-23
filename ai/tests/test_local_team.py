"""Local-only team: the Ollama adapter (native and prompt tool calling) and MV_TEAM=local wiring."""
import json

import httpx
import pytest

import mv_ai.llms as llms
import mv_ai.team as team_mod
from mv_ai.config import Config
from mv_ai.retrieve import Index
from mv_ai.tools import RepoTools, schemas
from test_team import CONF, Fake, Script, repo, text, use  # noqa: F401  (repo is a fixture)

CFG = Config(local_base_url="http://ollama.test/v1", local_model="gemma4:12b")


class Server:
    """Stands in for httpx.post: replays canned responses and records each request body."""

    def __init__(self, *replies):
        self.replies, self.bodies = list(replies), []

    def __call__(self, url, json=None, timeout=None):
        self.bodies.append(json)
        code, body = self.replies.pop(0)
        return httpx.Response(code, json=body, request=httpx.Request("POST", url))


def reply(message, finish="stop"):
    return 200, {"choices": [{"message": message, "finish_reason": finish}],
                 "usage": {"prompt_tokens": 120, "completion_tokens": 30}}


@pytest.fixture(autouse=True)
def fresh(monkeypatch):
    monkeypatch.setattr(llms, "_PROMPT_TOOLS", set())


def test_native_tool_call_round_trip(monkeypatch):
    srv = Server(reply({"content": "อ่านก่อน", "tool_calls": [{"id": "c1", "type": "function", "function": {
        "name": "read_file", "arguments": json.dumps({"path": "scripts/fuel.gd", "start": "1"})}}]}))
    monkeypatch.setattr(llms.httpx, "post", srv)
    history = [{"role": "user", "content": "task"},
               {"role": "assistant", "content": [text("plan"), use("a1", "list_files", glob="*.gd")]},
               {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "a1", "content": "x.gd"}]}]
    blocks, stop, usage = llms.local_turn(CFG, "sys", history, schemas(["read_file", "list_files"]), "high")
    assert stop == "tool_use"
    assert blocks[0] == {"type": "text", "text": "อ่านก่อน"}
    assert blocks[1]["name"] == "read_file" and blocks[1]["input"] == {"path": "scripts/fuel.gd", "start": 1, "end": 0}
    assert usage == {"model": "gemma4:12b", "input": 120, "output": 30, "cache_read": 0, "cache_write": 0}
    sent = srv.bodies[0]
    assert sent["model"] == "gemma4:12b" and sent["tools"][0]["function"]["name"] == "read_file"
    assert sent["messages"][2]["tool_calls"][0]["id"] == "a1"
    assert sent["messages"][3] == {"role": "tool", "tool_call_id": "a1", "content": "x.gd"}


def test_falls_back_to_prompt_tools_when_model_has_none(monkeypatch):
    srv = Server((400, {"error": {"message": "gemma4:12b does not support tools"}}),
                 reply({"content": 'ok\n{"tool": "delegate", "input": {"agent": "writer", "task": "ตรวจคำแปล"}}'}),
                 reply({"content": "เสร็จแล้ว"}))
    monkeypatch.setattr(llms.httpx, "post", srv)
    delegate = {"name": "delegate", "description": "d", "input_schema": {
        "type": "object", "properties": {"agent": {"type": "string"}, "task": {"type": "string"}},
        "required": ["agent", "task"]}}
    blocks, stop, _ = llms.local_turn(CFG, "sys", [{"role": "user", "content": "go"}], [delegate], "high", True)
    assert stop == "tool_use" and blocks[-1]["input"] == {"agent": "writer", "task": "ตรวจคำแปล"}
    assert "tools" not in srv.bodies[1] and '"tool": "<name>"' in srv.bodies[1]["messages"][0]["content"]
    # the next turn remembers prompt mode and replays the call as plain text
    hist = [{"role": "user", "content": "go"}, {"role": "assistant", "content": blocks},
            {"role": "user", "content": [{"type": "tool_result", "tool_use_id": blocks[-1]["id"], "content": "done"}]}]
    blocks, stop, _ = llms.local_turn(CFG, "sys", hist, [delegate], "high", True)
    assert stop == "end_turn" and blocks == [{"type": "text", "text": "เสร็จแล้ว"}]
    assert srv.bodies[2]["messages"][-1] == {"role": "user", "content": "Tool result:\ndone"}


def test_local_team_runs_every_agent_on_the_local_model(repo, monkeypatch):
    script = Script(lead=[[use("L1", "delegate", agent="analyst", task="engine")], [text("all local")]])
    seen = []
    monkeypatch.setattr(team_mod, "local_turn", lambda cfg, *a: (seen.append(cfg.local_model), script(*a))[1])
    cfg = Config(repo_root=repo, team="local")
    events = []
    t = team_mod.build_team(cfg, llms={n: Fake(n) for n in ("opus", "gemini", "local")}, tools=RepoTools(cfg),
                            index=Index.build(repo), emit=lambda a, k, d: events.append((a, k, d)))
    out = t.invoke({"task": "x"}, CONF)
    assert out["report"] == "all local" and seen == ["gemma4:12b", "gemma4:12b"]
    llm = [d["model"] for a, k, d in events if k == "llm"]
    assert llm == ["gemma4:12b", "local", "gemma4:12b"]  # analyst answered by the local model, not Gemini


def test_retries_with_more_room_when_thinking_eats_the_budget(monkeypatch):
    srv = Server(reply({"content": "", "reasoning": "hmm " * 50}, finish="length"),
                 reply({"content": "<think>plan</think>ไม่มีเครื่องมือ Plane ครับ", "reasoning": "checked tools"}))
    monkeypatch.setattr(llms.httpx, "post", srv)
    blocks, stop, _ = llms.local_turn(CFG, "sys", [{"role": "user", "content": "plane?"}], [], "high")
    assert [b["max_tokens"] for b in srv.bodies] == list(llms.LOCAL_BUDGETS)
    assert stop == "end_turn" and blocks[-1] == {"type": "text", "text": "ไม่มีเครื่องมือ Plane ครับ"}
    assert blocks[0]["type"] == "thinking" and "checked tools" in blocks[0]["thinking"] and "plan" in blocks[0]["thinking"]
