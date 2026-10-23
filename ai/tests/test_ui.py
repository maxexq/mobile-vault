"""UI server tests: real HTTP server on a free port, fake Claude team, approval round trip."""
import json
import threading
import time
import urllib.request

import pytest

from mv_ai.config import Config
from mv_ai.retrieve import Index
from mv_ai.team import build_team
from mv_ai.tools import RepoTools
from mv_ai.ui.server import cost, serve
from test_team import Fake, Script, repo, text, use  # noqa: F401  (repo is a fixture)

USAGE = {"model": "claude-opus-5-5", "input": 1000, "output": 500, "cache_read": 2000, "cache_write": 0}


class Billed(Script):
    def __call__(self, *a, **k):
        blocks, stop, _ = super().__call__(*a, **k)
        return blocks, stop, USAGE


@pytest.fixture
def ui(repo):
    def make_team(run):
        script = Billed(
            lead=[[use("L1", "delegate", agent="coder", task="double fuel_rate")], [text("All done")],
                  [text("Follow-up answer")]],
            coder=[[use("C1", "edit_file", path="scripts/fuel.gd", old_text="1.0", new_text="2.0")],
                   [text("changed fuel.gd")]],
        )
        cfg = Config(repo_root=repo)
        llms = {n: Fake(n) for n in ("opus", "gemini", "local")}
        return build_team(cfg, claude=script, llms=llms, tools=RepoTools(cfg), index=Index.build(repo),
                          auto_approve=run.auto, emit=run.emit)

    httpd = serve(Config(repo_root=repo), 0, make_team)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{httpd.server_address[1]}", repo
    httpd.shutdown()


def call(url, body=None, header=True):
    req = urllib.request.Request(url, data=None if body is None else json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", **({"X-MV-UI": "1"} if header else {})})
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


def wait_for(url, status, timeout=5):
    end = time.time() + timeout
    while time.time() < end:
        _, s = call(url)
        if s["status"] == status:
            return s
        time.sleep(0.05)
    raise AssertionError(f"run never reached {status}: {s['status']}")


def test_run_with_approval(ui):
    base, repo = ui
    _, page = 200, urllib.request.urlopen(base + "/").read().decode()
    assert "Agent Team" in page
    code, run = call(base + "/api/runs", {"task": "double the fuel rate"})
    assert code == 200
    url = f"{base}/api/runs/{run['id']}"
    s = wait_for(url, "waiting")
    assert s["pending"]["agent"] == "coder" and s["agents"]["coder"]["state"] == "waiting"
    assert (repo / "scripts/fuel.gd").read_text() == "var fuel_rate := 1.0\n"
    assert call(url + "/approve", {"approve": True})[1]["ok"]
    s = wait_for(url, "done")
    assert (repo / "scripts/fuel.gd").read_text() == "var fuel_rate := 2.0\n"
    assert s["report"] == "All done"
    kinds = [(e["agent"], e["kind"]) for e in s["new_events"]]
    assert ("coder", "task") in kinds and ("coder", "tool") in kinds and ("coder", "done") in kinds
    assert ("coder", "approval") in kinds and kinds[-1] == ("lead", "report")
    a = s["agents"]
    assert a["lead"]["turns"] == 2 and a["coder"]["turns"] == 2 and a["coder"]["tools"] == 1
    assert s["cost"] == pytest.approx(4 * cost(USAGE), abs=1e-4)
    # incremental polling
    _, s2 = call(f"{url}?since={len(s['new_events']) - 1}")
    assert len(s2["new_events"]) == 1


def test_decline_auto_and_cancel(ui):
    base, repo = ui
    _, run = call(base + "/api/runs", {"task": "x", "auto_approve": True})
    s = wait_for(f"{base}/api/runs/{run['id']}", "done")
    assert not any(e["kind"] == "approval_wait" for e in s["new_events"])
    (repo / "scripts/fuel.gd").write_text("var fuel_rate := 1.0\n")
    _, run = call(base + "/api/runs", {"task": "y"})
    url = f"{base}/api/runs/{run['id']}"
    wait_for(url, "waiting")
    call(url + "/cancel", {})
    wait_for(url, "cancelled")
    assert (repo / "scripts/fuel.gd").read_text() == "var fuel_rate := 1.0\n"


def test_post_needs_header_and_task(ui):
    base, _ = ui
    assert call(base + "/api/runs", {"task": "x"}, header=False)[0] == 403
    assert call(base + "/api/runs", {"task": "  "})[0] == 400


def test_follow_up_continues_the_run(ui):
    base, _ = ui
    _, run = call(base + "/api/runs", {"task": "x", "auto_approve": True})
    url = f"{base}/api/runs/{run['id']}"
    s = wait_for(url, "done")
    assert s["agents"]["coder"]["state"] == "done"
    assert call(url + "/message", {"text": " "})[0] == 400
    assert call(url + "/message", {"text": "and the tests?"})[1]["ok"]
    s = wait_for(url, "done")
    assert s["report"] == "Follow-up answer"
    users = [e["data"]["text"] for e in s["new_events"] if e["agent"] == "user"]
    assert users == ["x", "and the tests?"]
    kinds = [(e["agent"], e["kind"]) for e in s["new_events"]]
    assert ("coder", "tool_start") in kinds and ("lead", "llm_start") in kinds
