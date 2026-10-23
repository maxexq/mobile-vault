"""Offline tests for the agent team: scripted fake Claude, real tools on a temp repo, real LangGraph."""
import subprocess

import pytest
from langgraph.types import Command

from mv_ai.config import Config
from mv_ai.retrieve import Index
from mv_ai.team import build_team
from mv_ai.tools import RepoTools, ToolError


@pytest.fixture
def repo(tmp_path):
    (tmp_path / "scripts").mkdir()
    (tmp_path / "scripts" / "fuel.gd").write_text("var fuel_rate := 1.0\n")
    (tmp_path / ".env").write_text("SECRET=1\n")
    subprocess.run(["git", "init", "-q"], cwd=tmp_path)
    return tmp_path


def use(id_, name, **inp):
    return {"type": "tool_use", "id": id_, "name": name, "input": inp}


def text(t):
    return {"type": "text", "text": t}


class Script:
    """Fake claude(): pops the next scripted turn for each system prompt role."""

    def __init__(self, lead, coder=(), tester=()):
        self.turns = {"lead": list(lead), "coder": list(coder), "tester": list(tester)}
        self.seen = []

    def __call__(self, system, messages, tools, effort, one=False):
        role = "lead" if system.startswith("You lead") else "coder" if "the coder" in system else "tester"
        self.seen.append((role, messages))
        blocks = self.turns[role].pop(0)
        return blocks, "tool_use" if any(b["type"] == "tool_use" for b in blocks) else "end_turn", {}


class Fake:
    def __init__(self, name, up=True):
        self.name, self.up = name, up

    def available(self):
        return self.up

    def complete(self, system, prompt, max_tokens=None):
        return f"{self.name} says ok"


def team(repo, script, auto=False, gemini_up=True):
    cfg = Config(repo_root=repo)
    llms = {"opus": Fake("opus"), "gemini": Fake("gemini", gemini_up), "local": Fake("local")}
    return build_team(cfg, claude=script, llms=llms, tools=RepoTools(cfg), index=Index.build(repo),
                      auto_approve=auto)


CONF = {"configurable": {"thread_id": "t"}, "recursion_limit": 200}


def test_lead_coder_edit_with_approval(repo):
    script = Script(
        lead=[[text("plan"), use("L1", "delegate", agent="coder", task="double fuel_rate")],
              [text("Done: fuel_rate is 2.0 in scripts/fuel.gd")]],
        coder=[[use("C1", "read_file", path="scripts/fuel.gd", start=1, end=0)],
               [use("C2", "edit_file", path="scripts/fuel.gd", old_text="1.0", new_text="2.0")],
               [text("changed scripts/fuel.gd")]],
    )
    t = team(repo, script)
    out = t.invoke({"task": "double the fuel rate"}, CONF)
    assert "__interrupt__" in out
    assert "edit_file scripts/fuel.gd" in out["__interrupt__"][0].value["changes"][0]
    assert (repo / "scripts/fuel.gd").read_text() == "var fuel_rate := 1.0\n"  # nothing written yet
    out = t.invoke(Command(resume=True), CONF)
    assert (repo / "scripts/fuel.gd").read_text() == "var fuel_rate := 2.0\n"
    assert out["report"].startswith("Done")
    # the coder's summary came back to the lead as the delegate tool_result
    lead_msgs = script.seen[-1][1]
    assert lead_msgs[-1]["content"][0] == {"type": "tool_result", "tool_use_id": "L1",
                                           "content": "changed scripts/fuel.gd"}
    # the coder saw line-numbered file content
    assert "1\tvar fuel_rate" in script.seen[2][1][-1]["content"][0]["content"]


def test_declined_change_is_reported_to_coder(repo):
    script = Script(
        lead=[[use("L1", "delegate", agent="coder", task="x")], [text("blocked")]],
        coder=[[use("C1", "write_file", path="scripts/new.gd", content="extends Node\n")], [text("declined")]],
    )
    t = team(repo, script)
    t.invoke({"task": "x"}, CONF)
    t.invoke(Command(resume=False), CONF)
    assert not (repo / "scripts/new.gd").exists()
    coder_last = script.seen[-2][1][-1]["content"][0]
    assert coder_last["is_error"] and "declined" in coder_last["content"]


def test_auto_approve_and_sandbox(repo):
    script = Script(
        lead=[[use("L1", "delegate", agent="coder", task="x")], [text("ok")]],
        coder=[[use("C1", "read_file", path=".env", start=1, end=0),
                use("C2", "write_file", path="../escape.gd", content="x"),
                use("C3", "write_file", path="scripts/a.gd", content="extends Node\n")],
               [text("done")]],
    )
    out = team(repo, script, auto=True).invoke({"task": "x"}, CONF)
    assert "__interrupt__" not in out and out["report"] == "ok"
    results = script.seen[-2][1][-1]["content"]
    assert results[0]["is_error"] and "off limits" in results[0]["content"]
    assert results[1]["is_error"] and "outside the repo" in results[1]["content"]
    assert (repo / "scripts/a.gd").exists() and not (repo.parent / "escape.gd").exists()


def test_analyst_and_writer_and_fallback(repo):
    script = Script(lead=[[use("L1", "delegate", agent="analyst", task="where is fuel_rate used?")],
                          [use("L2", "delegate", agent="writer", task="ticket title")],
                          [text("all good")]])
    out = team(repo, script, gemini_up=False).invoke({"task": "x"}, CONF)
    assert out["report"] == "all good"
    lead_msgs = script.seen[-1][1]
    assert lead_msgs[-3]["content"][0]["content"] == "opus says ok"  # gemini down -> opus
    assert lead_msgs[-1]["content"][0]["content"] == "local says ok"


def test_bad_delegate_gets_error_and_retry(repo):
    script = Script(lead=[[use("L1", "delegate", agent="artist", task="draw")], [text("sorry")]])
    out = team(repo, script).invoke({"task": "x"}, CONF)
    assert out["report"] == "sorry"
    err = script.seen[-1][1][-1]["content"][0]
    assert err["is_error"] and err["tool_use_id"] == "L1"


def test_truncated_tool_input_is_rejected(repo):
    tools = RepoTools(Config(repo_root=repo))
    with pytest.raises(ToolError):
        tools.run("edit_file", {"path": "scripts/fuel.gd", "old_text": "1.0"})
    with pytest.raises(ToolError):
        tools.run("read_file", {"path": "scripts/fuel.gd", "start": "1", "end": 0})


def test_tester_without_godot(repo, monkeypatch):
    monkeypatch.delenv("MV_GODOT_BIN", raising=False)
    tools = RepoTools(Config(repo_root=repo))
    tools.godot = None
    with pytest.raises(ToolError, match="MV_GODOT_BIN"):
        tools.run("run_autotest", {"only": "large"})


class Recorder(Fake):
    def __init__(self, name):
        super().__init__(name)
        self.calls = []

    def complete(self, system, prompt, images=None):
        self.calls.append((system, prompt, images))
        return f"{self.name} says ok"


def test_analyst_gets_screenshots_and_writer_gets_reference_text(repo, tmp_path_factory):
    (repo / "scripts" / "lore.gd").write_text('const LORE := {"vault": "ห้องนิรภัย"}\n')
    shot_dir = tmp_path_factory.mktemp("mv-autotest-x")
    (shot_dir / "01_hud.png").write_bytes(b"\x89PNG fake")
    (repo / "outside.png").write_bytes(b"\x89PNG")
    script = Script(lead=[[use("L1", "delegate", agent="analyst",
                               task=f"check {shot_dir}/01_hud.png and outside.png and /etc/passwd.png")],
                          [use("L2", "delegate", agent="writer", task="เขียนชื่อห้อง vault ใหม่")],
                          [text("ok")]])
    cfg = Config(repo_root=repo)
    llms = {"opus": Fake("opus"), "gemini": Recorder("gemini"), "local": Recorder("local")}
    build_team(cfg, claude=script, llms=llms, tools=RepoTools(cfg), index=Index.build(repo)).invoke({"task": "x"}, CONF)
    imgs = llms["gemini"].calls[0][2]
    assert [m for _, m in imgs] == ["image/png", "image/png"]  # temp autotest shot + repo file, not /etc
    system, prompt, _ = llms["local"].calls[0]
    assert "localization" in system and "ห้องนิรภัย" in prompt
