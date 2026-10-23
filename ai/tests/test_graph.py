"""Offline tests: fake models, real retrieval over the repo, real LangGraph wiring."""
from mv_ai.config import Config
from mv_ai.graph import build_graph, rule_route
from mv_ai.retrieve import Index

CFG = Config.from_env()
INDEX = Index.build(CFG.repo_root)


class Fake:
    def __init__(self, name, up=True, reply=None):
        self.name, self.up, self.reply, self.calls = name, up, reply, []

    def available(self):
        return self.up

    def complete(self, system, prompt, max_tokens=None):
        self.calls.append(prompt)
        return self.reply if self.reply is not None else f"answer from {self.name}"


def fakes(**over):
    d = {n: Fake(n) for n in ("local", "opus", "gemini")}
    d.update(over)
    return d


def test_index_finds_balance_sim():
    hits = INDEX.search("balance sim minutes mode", k=5)
    assert hits and any(c.path == "tools/balance.gd" for c in hits)


def test_rule_route():
    assert rule_route("ปรับบาลานซ์ดรอปของบอส", 1000, 60000) == "opus"
    assert rule_route("สรุป changelog ให้หน่อย", 1000, 60000) == "local"
    assert rule_route("explain fuel", 100000, 60000) == "gemini"
    assert rule_route("map every system in the whole repo", 10, 60000) == "gemini"


def test_local_router_decides():
    llms = fakes(local=Fake("local", reply="gemini"))
    out = build_graph(CFG, llms, INDEX).invoke({"question": "how does fuel work?"})
    assert out["route"] == "gemini" and out["route_reason"] == "local router"
    assert out["answer"] == "answer from gemini"


def test_router_nonsense_falls_back_to_rules():
    llms = fakes(local=Fake("local", reply="banana"))
    out = build_graph(CFG, llms, INDEX).invoke({"question": "is loot drop rate balanced?"})
    assert out["route"] == "opus" and out["route_reason"] == "rules"


def test_unavailable_model_falls_through():
    llms = fakes(local=Fake("local", up=False), opus=Fake("opus", up=False))
    out = build_graph(CFG, llms, INDEX).invoke({"question": "review the engine bay code"})
    assert out["model"] == "gemini" and "opus unavailable" in out["route_reason"]


def test_forced_route_and_context_reaches_model():
    llms = fakes()
    out = build_graph(CFG, llms, INDEX).invoke({"question": "balance sim minutes", "force_route": "opus"})
    assert out["model"] == "opus" and out["route_reason"] == "forced"
    assert "tools/balance.gd:" in llms["opus"].calls[0]
    assert llms["local"].calls == []  # forced routes skip the router call


def test_gemini_gets_wide_context():
    llms = fakes()
    narrow = build_graph(CFG, llms, INDEX).invoke({"question": "fuel", "force_route": "opus"})
    wide = build_graph(CFG, llms, INDEX).invoke({"question": "fuel", "force_route": "gemini"})
    assert len(wide["context"]) > len(narrow["context"])
