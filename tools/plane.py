#!/usr/bin/env python3
"""Small Plane (app.plane.so) client for the Mobile Vault tickets (project MV).

Used by Claude Code (cloud or local CLI), Gemini CLI and by hand to keep tickets in sync with the work.
Stdlib only, so it runs on Windows/macOS/Linux with any Python 3.8+.

  python tools/plane.py list [--state "In Progress"] [--limit 20]
  python tools/plane.py show MV-12
  python tools/plane.py create "Title" [--state Todo] [--priority medium] [--label feature ...]
                                       [--desc "text"] [--link URL [TITLE]]
  python tools/plane.py claim MV-12 [--force]      # take a ticket: In Progress + "Claimed by <agent>"
  python tools/plane.py move MV-12 "In Review"
  python tools/plane.py link MV-12 https://github.com/maxexq/mobile-vault/pull/40 "PR #40"
  python tools/plane.py comment MV-12 "text"
  python tools/plane.py states | labels

Who is working: --by "Gemini CLI" (before the command) or env MV_AGENT. create and claim then
leave a "Claimed by ..." comment, so the other agents can see who owns an In Progress ticket.

API key, first match wins (never commit it, never paste it into a chat):
  1. env PLANE_API_KEY
  2. file .plane-api-key in the repo root (git-ignored), first line
  3. none: the claude.ai cloud environment adds X-API-Key through its proxy
API reference: https://developers.plane.so/api-reference/introduction
"""
import argparse, html, json, os, ssl, sys, time, urllib.error, urllib.request

BASE = os.environ.get("PLANE_BASE_URL", "https://api.plane.so/api/v1")
WS = os.environ.get("PLANE_WORKSPACE", "mobile-vault")
PROJECT_ID = os.environ.get("PLANE_PROJECT_ID", "c18b3b42-dee2-4767-9a63-b278a184f125")
IDENT = "MV"
SRC = "mobile-vault-seed"  # same external_source as the seed script
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W = f"/workspaces/{WS}"
PJ = f"{W}/projects/{PROJECT_ID}"

_ctx = ssl.create_default_context()
_ca = os.environ.get("SSL_CERT_FILE") or "/root/.ccr/ca-bundle.crt"  # cloud proxy CA
if os.path.exists(_ca):
    _ctx.load_verify_locations(_ca)


def _key():
    k = os.environ.get("PLANE_API_KEY", "").strip()
    if k:
        return k
    p = os.path.join(ROOT, ".plane-api-key")
    if os.path.exists(p):
        with open(p, encoding="utf-8") as f:
            return f.readline().strip()
    return ""


KEY = _key()


def api(method, path, body=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    for attempt in range(5):
        headers = {"Content-Type": "application/json"}
        if KEY:
            headers["X-API-Key"] = KEY
        req = urllib.request.Request(url, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, context=_ctx, timeout=60) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            if e.code == 429:  # 60 requests/minute
                time.sleep(15 * (attempt + 1))
                continue
            msg = e.read().decode(errors="replace")[:400]
            hint = ""
            if e.code in (401, 403) and not KEY:
                hint = "\nNo API key found: set PLANE_API_KEY or create .plane-api-key (see CLAUDE.md)."
            raise SystemExit(f"{method} {path} -> {e.code}: {msg}{hint}")
    raise SystemExit(f"{method} {path}: rate limited")


def results(r):
    return r.get("results", []) if isinstance(r, dict) else r


def states():
    return {s["name"]: s["id"] for s in results(api("GET", f"{PJ}/states/"))}


def labels():
    return {l["name"]: l["id"] for l in results(api("GET", f"{PJ}/labels/?per_page=100"))}


def item(ref):
    """MV-12, 12 or a uuid -> work item dict."""
    ref = ref.strip()
    if ref.isdigit():
        ref = f"{IDENT}-{ref}"
    if ref.upper().startswith(IDENT + "-"):
        return api("GET", f"{W}/work-items/{ref.upper()}/")
    return api("GET", f"{PJ}/work-items/{ref}/")


def ref_of(i):
    return f"{IDENT}-{i.get('sequence_id')}"


def url_of(i):
    return f"https://app.plane.so/{WS}/projects/{PROJECT_ID}/issues/{i['id']}"


def state_id(name, st=None):
    st = st or states()
    for n, sid in st.items():
        if n.lower() == name.lower():
            return sid
    raise SystemExit(f"unknown state {name!r}; one of: {', '.join(st)}")


def cmd_list(a):
    st = {v: k for k, v in states().items()}
    q = f"{PJ}/work-items/?per_page={a.limit}&order_by=-updated_at"
    for i in results(api("GET", q)):
        s = st.get(i.get("state"), "?")
        if a.state and s.lower() != a.state.lower():
            continue
        print(f"{ref_of(i):7} {s:16} {i.get('priority') or '':7} {i['name']}")


def cmd_show(a):
    i = item(a.ref)
    st = {v: k for k, v in states().items()}
    print(f"{ref_of(i)}  {i['name']}\nstate: {st.get(i.get('state'), '?')}   priority: {i.get('priority')}")
    print(url_of(i))
    for l in results(api("GET", f"{PJ}/work-items/{i['id']}/links/")):
        print(f"  link: {l.get('title') or ''} {l['url']}")


def cmd_create(a):
    body = {"name": a.title, "state": state_id(a.state), "priority": a.priority,
            "description_html": f"<p>{html.escape(a.desc)}</p>" if a.desc else "<p></p>",
            "external_source": SRC, "external_id": a.external_id or f"cli-{int(time.time())}"}
    if a.label:
        lb = labels()
        missing = [l for l in a.label if l not in lb]
        if missing:
            raise SystemExit(f"unknown label(s) {missing}; one of: {', '.join(lb)}")
        body["labels"] = [lb[l] for l in a.label]
    i = api("POST", f"{PJ}/work-items/", body)
    for link in a.link or []:
        api("POST", f"{PJ}/work-items/{i['id']}/links/", {"url": link[0], "title": " ".join(link[1:]) or link[0]})
    if a.state.lower() == "in progress":
        claim_note(i, a)
    print(f"{ref_of(i)} created: {url_of(i)}")


def claim_note(i, a):
    if a.by:
        api("POST", f"{PJ}/work-items/{i['id']}/comments/", {"comment_html": f"<p>Claimed by {html.escape(a.by)}</p>"})


def cmd_claim(a):
    i = item(a.ref)
    st = states()
    if i.get("state") == st.get("In Progress") and not a.force:
        raise SystemExit(f"{ref_of(i)} is already In Progress (someone owns it); --force to take it anyway")
    api("PATCH", f"{PJ}/work-items/{i['id']}/", {"state": state_id("In Progress", st)})
    claim_note(i, a)
    print(f"{ref_of(i)} -> In Progress" + (f" (claimed by {a.by})" if a.by else ""))


def cmd_move(a):
    i = item(a.ref)
    api("PATCH", f"{PJ}/work-items/{i['id']}/", {"state": state_id(a.state)})
    print(f"{ref_of(i)} -> {a.state}")


def cmd_link(a):
    i = item(a.ref)
    api("POST", f"{PJ}/work-items/{i['id']}/links/", {"url": a.url, "title": a.title or a.url})
    print(f"{ref_of(i)} + link {a.url}")


def cmd_comment(a):
    i = item(a.ref)
    api("POST", f"{PJ}/work-items/{i['id']}/comments/", {"comment_html": f"<p>{html.escape(a.text)}</p>"})
    print(f"{ref_of(i)} + comment")


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")  # Thai titles on a Windows console
    p = argparse.ArgumentParser(description="Mobile Vault Plane tickets (project MV)")
    p.add_argument("--by", default=os.environ.get("MV_AGENT", ""),
                   help='who is doing the work, e.g. "Gemini CLI" (default: env MV_AGENT)')
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("list"); s.add_argument("--state"); s.add_argument("--limit", type=int, default=30)
    s.set_defaults(f=cmd_list)
    s = sub.add_parser("show"); s.add_argument("ref"); s.set_defaults(f=cmd_show)
    s = sub.add_parser("create"); s.add_argument("title")
    s.add_argument("--state", default="In Progress"); s.add_argument("--priority", default="medium",
                   choices=["urgent", "high", "medium", "low", "none"])
    s.add_argument("--label", action="append"); s.add_argument("--desc", default="")
    s.add_argument("--link", nargs="+", action="append", metavar=("URL", "TITLE"))
    s.add_argument("--external-id"); s.set_defaults(f=cmd_create)
    s = sub.add_parser("claim"); s.add_argument("ref"); s.add_argument("--force", action="store_true")
    s.set_defaults(f=cmd_claim)
    s = sub.add_parser("move"); s.add_argument("ref"); s.add_argument("state"); s.set_defaults(f=cmd_move)
    s = sub.add_parser("link"); s.add_argument("ref"); s.add_argument("url"); s.add_argument("title", nargs="?")
    s.set_defaults(f=cmd_link)
    s = sub.add_parser("comment"); s.add_argument("ref"); s.add_argument("text"); s.set_defaults(f=cmd_comment)
    sub.add_parser("states").set_defaults(f=lambda a: print("\n".join(states())))
    sub.add_parser("labels").set_defaults(f=lambda a: print("\n".join(labels())))
    a = p.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
