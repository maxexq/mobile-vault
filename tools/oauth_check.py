#!/usr/bin/env python3
"""MV-551: check that "Sign in with Google" comes back to every game URL (no Google account needed).

For each host of config/environments.json (plus the Vercel branch URLs) it starts Supabase's Google
login with redirect_to=https://<host>/, then answers the callback as if the player pressed Cancel at
Google. Supabase sends that answer to the return URL it accepted: the host itself when the host is in
the project's Authentication -> URL Configuration -> Redirect URLs, else the project's Site URL.
A host that does not come back to itself loses the login (the tokens land on another site).

  python tools/oauth_check.py            # project URLs from cloud_config.json, else DEFAULTS
  python tools/oauth_check.py --prod https://<ref>.supabase.co --test https://<ref>.supabase.co

Stdlib only. Read-only: no account is created and nothing is stored on the server but an unused
login attempt. Exit code 1 when a host fails. Fix steps: supabase/google-login-setup.md
"""
import argparse, json, os, sys, urllib.error, urllib.parse, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# the wildcard Vercel hosts of config/environments.json, spelled out (Vercel project "mobile-vault")
VERCEL_BRANCH = {
    "mobile-vault-git-main-maxexqs-projects.vercel.app": "prod",
    "mobile-vault-git-uat-maxexqs-projects.vercel.app": "uat",
    "mobile-vault-git-staging-maxexqs-projects.vercel.app": "staging",
}
# public project URLs (also in every web build); cloud_config.json or --prod / --test win
DEFAULTS = {"prod": "https://phcylgdikidhunjclppr.supabase.co", "test": "https://bedslajlrtwmfyxrppcq.supabase.co"}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


OPENER = urllib.request.build_opener(NoRedirect)


def location(url):
    try:
        r = OPENER.open(url, timeout=20)
        return r.headers.get("Location", "")
    except urllib.error.HTTPError as e:
        return e.headers.get("Location", "") or f"HTTP {e.code}"


def returns_to(project_url, back):
    """where Supabase sends the player after Google for redirect_to=back"""
    q = urllib.parse.urlencode({"provider": "google", "redirect_to": back})
    google = location(f"{project_url}/auth/v1/authorize?{q}")
    state = urllib.parse.parse_qs(urllib.parse.urlsplit(google).query).get("state", [""])[0]
    if not state:
        return f"no Google redirect ({google[:80]}): is the Google provider on?"
    q = urllib.parse.urlencode({"error": "access_denied", "error_description": "oauth_check", "state": state})
    return location(f"{project_url}/auth/v1/callback?{q}").split("?")[0].split("#")[0]


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--prod", help="prod project URL (default: cloud_config.json)")
    ap.add_argument("--test", help="test project URL (default: cloud_config.json)")
    a = ap.parse_args()
    projects = {"prod": a.prod, "test": a.test}
    cfg = os.path.join(ROOT, "cloud_config.json")
    if os.path.exists(cfg):
        with open(cfg, encoding="utf-8") as f:
            d = json.load(f)
        for k, v in (d.get("projects") or {}).items():
            projects[k] = projects.get(k) or v.get("url")
    for k, v in DEFAULTS.items():
        projects[k] = projects.get(k) or v
    with open(os.path.join(ROOT, "config", "environments.json"), encoding="utf-8") as f:
        envs = json.load(f)
    hosts = {h: e for h, e in envs["hosts"].items() if "*" not in h}
    hosts.update(VERCEL_BRANCH)
    bad = checked = 0
    for host, env in hosts.items():
        project = envs["projects"].get(env, "test")
        purl = (projects.get(project) or "").rstrip("/")
        if not purl.startswith("https://"):
            print(f"SKIP {env:8} {host}: no URL for the {project} project (cloud_config.json or --{project})")
            continue
        back = f"https://{host}/"
        got = returns_to(purl, back)
        checked += 1
        ok = got == back
        bad += not ok
        print(f"{'OK  ' if ok else 'FAIL'} {env:8} {host}" + ("" if ok else f"  -> returns to {got}"))
    sys.exit(1 if bad or not checked else 0)


if __name__ == "__main__":
    main()
