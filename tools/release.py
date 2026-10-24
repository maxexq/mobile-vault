#!/usr/bin/env python3
"""Version + release helper (MV-111). Stdlib only, works on Windows and in CI.

The game version is semver in scripts/build_info.gd (BuildInfo.GAME_VERSION):
    MAJOR.MINOR.PATCH[-alpha.N | -beta.N | -rc.N]
The pre-release tag is the channel the game shows (ALPHA / BETA / RC badge, nothing when stable).

    python tools/release.py version                 # print the current version
    python tools/release.py check [--tag v4.7.0]    # version, web shell and CHANGELOG agree (CI)
    python tools/release.py changelog               # add merged PRs since the last tag to [Unreleased]
    python tools/release.py bump <part|X.Y.Z[-pre.N]>  # set the version, date the changelog section
    python tools/release.py notes [version]         # print one CHANGELOG section (release body)

bump parts: patch, minor, major (from a pre-release they drop the tag), alpha, beta, rc (next
pre-release number, or start that channel on the same core), stable (drop the tag).
After `bump`: commit on the PR branch; once merged, the "Release" workflow (Actions tab > Release >
Run workflow, or pushing tag v<version>) tags main and publishes the GitHub Release.
"""
import datetime
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD_INFO = ROOT / "scripts" / "build_info.gd"
SHELL = ROOT / "tools" / "web_shell.html"
CHANGELOG = ROOT / "CHANGELOG.md"
REPO_URL = "https://github.com/maxexq/mobile-vault"

VER_RE = re.compile(r'^const GAME_VERSION := "([^"]+)"', re.M)
SHELL_RE = re.compile(r'(<div class="sub">)v[^ <]+( · GODOT [0-9.]+</div>)')
SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)(?:-(alpha|beta|rc)\.(\d+))?$")
CHANNELS = ["alpha", "beta", "rc"]
UNRELEASED = "## [Unreleased]"
MERGE_RE = re.compile(r"Merge pull request #(\d+) from \S+")


def read(p):
    return p.read_text(encoding="utf-8")


def write(p, text):
    p.write_text(text, encoding="utf-8", newline="\n")


def current():
    m = VER_RE.search(read(BUILD_INFO))
    if not m:
        sys.exit("GAME_VERSION not found in " + str(BUILD_INFO))
    return m.group(1)


def parse(v):
    m = SEMVER_RE.match(v.lstrip("v"))
    if not m:
        sys.exit(f"not a release version: {v!r} (want X.Y.Z or X.Y.Z-alpha|beta|rc.N)")
    major, minor, patch, ch, n = m.groups()
    return int(major), int(minor), int(patch), ch, int(n) if n else 0


def fmt(major, minor, patch, ch=None, n=0):
    return f"{major}.{minor}.{patch}" + (f"-{ch}.{n}" if ch else "")


def next_version(v, part):
    if SEMVER_RE.match(part.lstrip("v")):
        return part.lstrip("v")
    major, minor, patch, ch, n = parse(v)
    if part == "stable":
        return fmt(major, minor, patch)
    if part in CHANNELS:
        if ch == part:
            return fmt(major, minor, patch, ch, n + 1)
        if ch and CHANNELS.index(part) < CHANNELS.index(ch):
            sys.exit(f"{part} comes before {ch}: bump minor/major for a new {part}")
        if ch:
            return fmt(major, minor, patch, part, 1)
        return fmt(major, minor + 1, 0, part, 1)
    if part == "patch":
        return fmt(major, minor, patch if ch else patch + 1)
    if part == "minor":
        return fmt(major, minor, 0) if ch and patch == 0 else fmt(major, minor + 1, 0)
    if part == "major":
        return fmt(major, 0, 0) if ch and minor == 0 and patch == 0 else fmt(major + 1, 0, 0)
    sys.exit("unknown bump part: " + part)


def git(*args):
    r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
    return r.stdout.strip() if r.returncode == 0 else ""


def last_tag():
    return git("describe", "--tags", "--abbrev=0", "--match", "v*")


def merged_prs(since):
    """[(number, title)] for PR merge commits after the tag `since` (all history when "")."""
    rng = f"{since}..HEAD" if since else "HEAD"
    out = git("log", rng, "--merges", "--first-parent", "--format=%s%x1f%b%x1e")
    prs = []
    for rec in out.split("\x1e"):
        if "\x1f" not in rec:
            continue
        subject, body = rec.strip().split("\x1f", 1)
        m = MERGE_RE.match(subject)
        if m:
            title = body.strip().splitlines()[0] if body.strip() else subject
            prs.append((int(m.group(1)), title.strip()))
    return prs


def section(text, version):
    """The body of '## [version]' (or [Unreleased]) up to the next '## [' heading."""
    head = UNRELEASED if version == "Unreleased" else f"## [{version}]"
    i = text.find(head)
    if i < 0:
        return None
    j = text.find("\n## [", i + len(head))
    body = text[i:j if j >= 0 else len(text)]
    return body.split("\n", 1)[1].strip() if "\n" in body else ""


def cmd_changelog():
    text = read(CHANGELOG)
    if UNRELEASED not in text:
        sys.exit("CHANGELOG.md has no " + UNRELEASED + " section")
    known = set(int(n) for n in re.findall(r"\[#(\d+)\]", text))
    new = [(n, t) for n, t in merged_prs(last_tag()) if n not in known]
    if not new:
        print("changelog: nothing new since", last_tag() or "the first commit")
        return
    lines = "".join(f"- {t} ([#{n}]({REPO_URL}/pull/{n}))\n" for n, t in sorted(new))
    body = section(text, "Unreleased")
    block = "### Merged pull requests\n" + lines
    if "### Merged pull requests" in body:
        i = text.find("### Merged pull requests", text.find(UNRELEASED))
        i = text.find("\n", i) + 1
        text = text[:i] + lines + text[i:]
    else:
        i = text.find(UNRELEASED) + len(UNRELEASED)
        text = text[:i] + "\n\n" + block + "\n" + text[i:].lstrip("\n")
    write(CHANGELOG, text)
    print(f"changelog: added {len(new)} PR(s) to [Unreleased]")


def cmd_bump(part):
    old = current()
    new = next_version(old, part)
    if new == old:
        sys.exit("version is already " + old)
    write(BUILD_INFO, VER_RE.sub(f'const GAME_VERSION := "{new}"', read(BUILD_INFO), count=1))
    shell = read(SHELL)
    if not SHELL_RE.search(shell):
        sys.exit("version line not found in " + str(SHELL))
    write(SHELL, SHELL_RE.sub(lambda m: f"{m.group(1)}v{new}{m.group(2)}", shell, count=1))
    cmd_changelog()
    text = read(CHANGELOG)
    today = datetime.date.today().isoformat()
    i = text.find(UNRELEASED) + len(UNRELEASED)
    text = text[:i] + f"\n\n## [{new}] - {today}" + text[i:]
    write(CHANGELOG, text)
    print(f"{old} -> {new}")
    print("next: review CHANGELOG.md, run the autotest + web export, commit, open the PR")


def cmd_check(tag=""):
    v = current()
    parse(v)
    errors = []
    shell = SHELL_RE.search(read(SHELL))
    if not shell or f">v{v} · GODOT" not in shell.group(0):
        errors.append(f"tools/web_shell.html version line is not v{v}")
    text = read(CHANGELOG)
    if not section(text, v) and not section(text, "Unreleased"):
        errors.append(f"CHANGELOG.md has no [{v}] or [Unreleased] entries")
    if tag:
        if tag.lstrip("v") != v:
            errors.append(f"tag {tag} does not match BuildInfo.GAME_VERSION {v}")
        if not section(text, v):
            errors.append(f"CHANGELOG.md has no [{v}] section to publish")
    for e in errors:
        print("::error::" + e)
    if errors:
        sys.exit(1)
    print(f"ok: {v} ({channel(v)})")


def channel(v):
    return parse(v)[3] or "stable"


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return
    cmd, rest = argv[0], argv[1:]
    if cmd == "version":
        print(current())
    elif cmd == "channel":
        print(channel(rest[0] if rest else current()))
    elif cmd == "check":
        tag = rest[rest.index("--tag") + 1] if "--tag" in rest else ""
        cmd_check(tag)
    elif cmd == "changelog":
        cmd_changelog()
    elif cmd == "bump":
        if not rest:
            sys.exit("bump needs a part: patch|minor|major|alpha|beta|rc|stable|X.Y.Z[-pre.N]")
        cmd_bump(rest[0])
    elif cmd == "notes":
        v = rest[0].lstrip("v") if rest else current()
        body = section(read(CHANGELOG), v)
        if body is None:
            sys.exit(f"CHANGELOG.md has no [{v}] section")
        print(body)
    else:
        sys.exit("unknown command: " + cmd)


if __name__ == "__main__":
    main(sys.argv[1:])
