"""uv run python -m mv_ai.ui [--port 8765] [--no-browser]"""
import argparse
import sys
import webbrowser

from ..config import Config
from ..llms import ClaudeLLM, LocalLLM
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
        print("note: no ANTHROPIC_API_KEY in ai/.env, so only the Local team can run", file=sys.stderr)
    if not LocalLLM(cfg).available():
        print(f"note: local model server not reachable at {cfg.local_base_url}", file=sys.stderr)
    try:
        httpd = serve(cfg, a.port)
    except OSError as e:
        print(f"port {a.port} is already in use ({e}). An older UI may still be running: close it, or run "
              f"with --port {a.port + 1}", file=sys.stderr)
        return 1
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
