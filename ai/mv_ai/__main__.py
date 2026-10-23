"""CLI.  uv run python -m mv_ai "question" [--model local|opus|gemini]
        uv run python -m mv_ai --ping      (one tiny call to each model)
"""
import argparse
import sys

from .config import Config
from .graph import ROUTES, build_graph
from .llms import default_llms


def ping(cfg: Config) -> int:
    bad = 0
    for name, llm in default_llms(cfg).items():
        if not llm.available():
            print(f"[{name}] not available (missing key or server down)")
            bad += 1
            continue
        try:
            out = llm.complete("Reply in one short line.", "Say hi to the Mobile Vault team in Thai.")
            print(f"[{name}] ok: {out.strip()[:120]}")
        except Exception as e:
            print(f"[{name}] error: {e}")
            bad += 1
    return 1 if bad else 0


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")  # Thai output on Windows consoles
    ap = argparse.ArgumentParser(prog="mv_ai")
    ap.add_argument("question", nargs="*")
    ap.add_argument("--model", choices=ROUTES, help="skip routing and use this model")
    ap.add_argument("--ping", action="store_true", help="check each model with one short call")
    a = ap.parse_args()
    cfg = Config.from_env()
    if a.ping:
        return ping(cfg)
    if not a.question:
        ap.error("ask a question, or use --ping")
    try:
        out = build_graph(cfg).invoke({"question": " ".join(a.question), "force_route": a.model})
    except RuntimeError as e:
        print(e, file=sys.stderr)
        return 1
    print(f"[{out['model']} · {out['route_reason']}]\n")
    print(out["answer"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
