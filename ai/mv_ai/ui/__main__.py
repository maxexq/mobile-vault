"""uv run python -m mv_ai.ui [--port 8765] [--no-browser]"""
import argparse
import sys
import webbrowser

from ..config import Config
from ..llms import ClaudeLLM
from .server import serve


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="mv_ai.ui", description="Web UI for the agent team (localhost only).")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--no-browser", action="store_true")
    a = ap.parse_args()
    cfg = Config.from_env()
    if not ClaudeLLM(cfg).available():
        print("warning: ANTHROPIC_API_KEY is not set in ai/.env, so runs will fail", file=sys.stderr)
    httpd = serve(cfg, a.port)
    url = f"http://127.0.0.1:{a.port}/"
    print(f"Agent team UI: {url}  (Ctrl+C to stop)")
    if not a.no_browser:
        webbrowser.open(url)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
