"""LangGraph pipeline: retrieve -> route -> answer with one of three models.

    START -> retrieve -> route -+-> local  (Qwen3-4B on Ollama: quick, cheap, private)
                                +-> opus   (Claude Opus: balance math, design reasoning, code review)
                                +-> gemini (Gemini 4 Argon: whole-repo / very long context)
                                          -> END

The local model picks the route; if it is down or answers nonsense, keyword rules decide.
If the chosen model has no key / isn't running, the next available one takes over.
"""
import re
from typing import Literal, TypedDict

from langgraph.graph import END, START, StateGraph

from .config import Config
from .llms import default_llms
from .retrieve import Index, render

Route = Literal["local", "opus", "gemini"]
ROUTES: tuple[Route, ...] = ("local", "opus", "gemini")
FALLBACK: dict[str, tuple[Route, ...]] = {
    "local": ("local", "opus", "gemini"),
    "opus": ("opus", "gemini", "local"),
    "gemini": ("gemini", "opus", "local"),
}

SYSTEM = (
    "You help develop 'Apocarlypse: Mobile Vault', an idle survival game for mobile web built with "
    "Godot 4.7.2-stable (GDScript). When you state facts about the code, ground them in the repository "
    "excerpts given and cite them as path:line; if the excerpts don't cover it, say so instead of guessing, "
    "and never invent Godot APIs. Tasks that don't need code facts (naming, wording, ticket text, "
    "brainstorming) can be answered directly. Always reply in the same language as the question."
)

ROUTER_PROMPT = """Pick which model should answer this game-dev question. Reply with exactly one word.
local  = short or mechanical: summarise, translate, rename, write ticket text, explain one small function
opus   = needs careful reasoning: game balance and numbers, design trade-offs, bugs, code review, plans
gemini = needs to read a lot at once: whole-repo or many-file questions, long logs, big docs

Question: {question}
Context size: {chars} characters
Answer:"""

_OPUS_WORDS = re.compile(
    r"balanc|tune|tuning|economy|drop rate|loot|dps|difficulty|design|why|bug|review|plan|"
    r"บาลานซ์|สมดุล|ออกแบบ|วิเคราะห์|ทำไม|บั๊ก|รีวิว|วางแผน",
    re.I,
)
_LOCAL_WORDS = re.compile(r"summari[sz]e|translate|rename|ticket|สรุป|แปล|ตั้งชื่อ", re.I)
_WIDE_WORDS = re.compile(r"whole repo|entire|all files|every system|ทั้ง repo|ทั้งโปรเจกต์|ทุกระบบ", re.I)


class State(TypedDict, total=False):
    question: str
    force_route: Route | None
    context: str
    route: Route
    route_reason: str
    answer: str
    model: str


def rule_route(question: str, chars: int, long_chars: int) -> Route:
    if chars > long_chars or _WIDE_WORDS.search(question):
        return "gemini"
    if _OPUS_WORDS.search(question):
        return "opus"
    if _LOCAL_WORDS.search(question):
        return "local"
    return "opus"


def build_graph(cfg: Config | None = None, llms: dict | None = None, index: Index | None = None):
    cfg = cfg or Config.from_env()
    llms = llms or default_llms(cfg)
    index = index or Index.build(cfg.repo_root)

    def retrieve(state: State) -> State:
        q = state["question"]
        wide = state.get("force_route") == "gemini" or bool(_WIDE_WORDS.search(q))
        return {"context": render(index.search(q, k=80 if wide else 8))}

    def route(state: State) -> State:
        q, chars = state["question"], len(state.get("context", ""))
        forced = state.get("force_route")
        if forced:
            choice, why = forced, "forced"
        else:
            choice, why = rule_route(q, chars, cfg.long_context_chars), "rules"
            local = llms["local"]
            if chars <= cfg.long_context_chars and local.available():
                try:
                    word = local.complete("You are a router.", ROUTER_PROMPT.format(question=q, chars=chars), 4096)
                    word = re.sub(r"[^a-z]", "", word.strip().lower().split()[0]) if word.strip() else ""
                    if word in ROUTES:
                        choice, why = word, "local router"
                except Exception as e:  # router failures must never block an answer
                    why = f"rules (router error: {e})"
        for cand in FALLBACK[choice]:
            if llms[cand].available():
                if cand != choice:
                    why += f"; {choice} unavailable"
                return {"route": cand, "route_reason": why}
        raise RuntimeError("No model is available: set API keys in ai/.env or start Ollama.")

    def answerer(name: Route):
        def node(state: State) -> State:
            prompt = f"Repository excerpts:\n\n{state.get('context', '')}\n\nQuestion: {state['question']}"
            return {"answer": llms[name].complete(SYSTEM, prompt), "model": name}

        return node

    g = StateGraph(State)
    g.add_node("retrieve", retrieve)
    g.add_node("route", route)
    for r in ROUTES:
        g.add_node(r, answerer(r))
        g.add_edge(r, END)
    g.add_edge(START, "retrieve")
    g.add_edge("retrieve", "route")
    g.add_conditional_edges("route", lambda s: s["route"], {r: r for r in ROUTES})
    return g.compile()
