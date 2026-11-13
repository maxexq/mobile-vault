#!/usr/bin/env python3
"""Pick the autotest groups a change needs (MV-779).

PRs run only the --only=<group> runs that cover the changed files; the whole autotest runs every night
(.github/workflows/nightly-autotest.yml). Prints one line: "full", "none" or the groups, e.g. "core threat".

  python3 tools/ci_select.py                       # this branch + uncommitted work vs origin/staging
  python3 tools/ci_select.py --base origin/main    # another base
  python3 tools/ci_select.py --files changed.txt --patch autotest.patch   # what CI passes
  python3 tools/ci_select.py --explain             # say why each file picked what

How a file maps to suites ("core" = boot + core gameplay walk, "full" = everything):
  1. not a game file (tools/ci_scope.sh says so): nothing
  2. rules in tools/test_map.txt
  3. groups whose name is in the path (scripts/autoload/threat.gd -> threat) or the other way round
     (world_map.gd -> world_map, world_map_detail)
  4. groups whose test functions mention the file (res:// path, file name, autoload name, class_name);
     dropped when more than MENTION_CAP groups mention it (too common to say anything)
  5. nothing matched: core
tools/autotest.gd itself is read from its diff: each changed line -> the function it is in -> the groups
that run that function (the --only blocks in _run and everything they call). Helpers every group uses
(_check, wait, shot ...) reach too many groups and give "full".
More than MAX_GROUPS groups, or any "full", gives the full run.
Python 3.8+ stdlib only.
"""
from __future__ import annotations

import argparse
import fnmatch
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUTOTEST = "tools/autotest.gd"
MAX_GROUPS = 14
MENTION_CAP = 6
CORE_MARKER = 'if "--only=core" in OS.get_cmdline_user_args():'
NEUTRAL_HELPERS = {"_check", "_fold", "_fold_flush", "_finish"}

ONLY_RE = re.compile(r'^\tif "--only=([a-z0-9_]+)" in OS\.get_cmdline_user_args\(\):')
FUNC_RE = re.compile(r"^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\s*\(")
VAR_RE = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:static )?(?:var|const) ([A-Za-z_][A-Za-z0-9_]*)")
IDENT_RE = re.compile(r"\b_[A-Za-z0-9_]+\b")
CALL_LINE_RE = re.compile(r"^\s*(?:await\s+)?(_[A-Za-z0-9_]+)\(\)\s*(?:#.*)?$")
CHECK_DONE_RE = re.compile(r'^\s*_check\(".*",\s*(_[A-Za-z0-9_]+)\)\s*(?:#.*)?$')


STRING_RE = re.compile(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'')


def code_only(line: str) -> str:
    """The line without string literals and comments ("eng_x_run.png" is not a call of _run)."""
    return STRING_RE.sub('""', line).split("#", 1)[0]


def read(path: str) -> str:
    with open(os.path.join(ROOT, path), encoding="utf-8", errors="replace") as f:
        return f.read()


class Autotest:
    """Static map of tools/autotest.gd: functions, the --only groups and what each group runs."""

    def __init__(self, text: str):
        self.lines = text.split("\n")
        self.funcs: dict[str, tuple[int, int]] = {}   # name -> (first, last) 1-based, inclusive
        self.vars: set[str] = set()
        starts = []
        for i, line in enumerate(self.lines, 1):
            m = FUNC_RE.match(line)
            if m:
                starts.append((i, m.group(1)))
            else:
                v = VAR_RE.match(line)
                if v:
                    self.vars.add(v.group(1))
        for k, (i, name) in enumerate(starts):
            end = starts[k + 1][0] - 1 if k + 1 < len(starts) else len(self.lines)
            self.funcs[name] = (i, end)
        self.calls = {name: self._refs(a, b, name) for name, (a, b) in self.funcs.items()}
        self._parse_run()
        self.closure = {g: self._close(e) for g, e in self.group_entries.items()}
        self.core_closure = self._close(self.core_entries)
        self.full_closure = self._close(self.full_entries)

    def _refs(self, a: int, b: int, skip: str = "") -> set[str]:
        out = set()
        for line in self.lines[a - 1:b]:
            for ident in IDENT_RE.findall(code_only(line)):
                if ident in self.funcs and ident not in (skip, "_run", "_ready"):
                    out.add(ident)
        return out

    def _close(self, entries: set[str]) -> set[str]:
        seen, todo = set(), list(entries)
        while todo:
            f = todo.pop()
            if f in seen or f not in self.funcs:
                continue
            seen.add(f)
            todo.extend(self.calls.get(f, ()))
        return seen

    def _parse_run(self) -> None:
        a, b = self.funcs["_run"]
        self.run_range = (a, b)
        self.group_entries: dict[str, set[str]] = {}
        self.region: dict[int, str] = {}       # line -> group name, "core" or "tail"
        self.bad_groups: set[str] = set()      # blocks that never return (they fall into the full run)
        self.core_entries: set[str] = set()
        self.full_entries = self._refs(a, b, "_run")
        i = a + 1
        first_block = None
        core_marker = None
        last_block_end = a
        while i <= b:
            line = self.lines[i - 1]
            m = ONLY_RE.match(line)
            if m and m.group(1) != "core":
                g = m.group(1)
                first_block = first_block or i
                j = i + 1
                body = []
                while j <= b and (self.lines[j - 1].startswith("\t\t") or not self.lines[j - 1].strip()):
                    body.append(j)
                    j += 1
                while body and not self.lines[body[-1] - 1].strip():
                    body.pop()
                entries = set()
                returns = False
                for k in body:
                    text = self.lines[k - 1]
                    if text.startswith("\t\t\t"):
                        continue  # nested if: only runs with extra flags
                    if text.strip() == "return":
                        returns = True
                    entries |= {x for x in IDENT_RE.findall(code_only(text)) if x in self.funcs}
                for k in [i] + body:
                    self.region[k] = g
                if returns:
                    self.group_entries.setdefault(g, set()).update(entries)
                else:
                    self.bad_groups.add(g)
                last_block_end = body[-1] if body else i
                i = (body[-1] if body else i) + 1
                continue
            if line.strip() == CORE_MARKER:
                core_marker = i
            i += 1
        self.bad_groups -= set(self.group_entries)
        if core_marker is None:
            raise SystemExit("ci_select: the --only=core marker is missing from _run in " + AUTOTEST)
        first_block = first_block or a
        # the marker block itself (if + _finish + return) belongs to core
        marker_end = core_marker
        while marker_end + 1 <= b and self.lines[marker_end].startswith("\t\t"):
            marker_end += 1
        for k in range(a, b + 1):
            if k in self.region:
                continue
            if k < first_block or (last_block_end < k <= marker_end):
                self.region[k] = "core"
                self.core_entries |= {x for x in IDENT_RE.findall(code_only(self.lines[k - 1])) if x in self.funcs}
            else:
                self.region[k] = "tail"
        self.core_entries.discard("_run")

    @property
    def groups(self) -> list[str]:
        return sorted(self.group_entries)

    def suites_of_func(self, f: str) -> set[str]:
        out = {g for g, c in self.closure.items() if f in c}
        if f in self.core_closure:
            out.add("core")
        if not out and f in self.full_closure:
            out.add("full")
        return out

    def suites_of_name(self, name: str) -> set[str]:
        """A function or a top-level var: the suites of everything that uses it."""
        if name in self.funcs:
            return self.suites_of_func(name)
        out = set()
        for f, (a, b) in self.funcs.items():
            if any(re.search(r"\b%s\b" % re.escape(name), l) for l in self.lines[a - 1:b]):
                out |= self.suites_of_func(f)
        return out

    def func_at(self, line: int) -> str | None:
        for name, (a, b) in self.funcs.items():
            if a <= line <= b:
                return name
        return None

    def suites_of_line(self, line: int, text: str) -> tuple[set[str], str]:
        stripped = text.strip()
        if not stripped or stripped.startswith("#"):
            return set(), "comment/blank"
        f = self.func_at(line)
        if f is None:
            v = VAR_RE.match(text)
            if v:
                return self.suites_of_name(v.group(1)) or {"core"}, "var " + v.group(1)
            return {"core"}, "top of file"
        if f != "_run":
            s = self.suites_of_func(f)
            return s, f + ("" if s else " (not run by any test)")
        region = self.region.get(line, "tail")
        if region != "tail":
            return {region}, "_run: " + ("--only=" + region if region != "core" else "core walk")
        # the tail of _run is the list of test calls only the full run reaches
        m = CALL_LINE_RE.match(text) or CHECK_DONE_RE.match(text)
        if m and m.group(1) not in NEUTRAL_HELPERS:
            s = self.suites_of_name(m.group(1))
            named = s - {"full"}
            return (named or {"full"}), "_run tail: " + m.group(1)
        return {"full"}, "_run tail (full run only)"


def changed_lines(patch: str):
    """(new-file line, text) for each added or removed line of a unified diff."""
    out = []
    new = 0
    for raw in patch.split("\n"):
        if raw.startswith("@@"):
            m = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", raw)
            new = int(m.group(1)) if m else new
            continue
        if raw.startswith(("+++", "---", "diff ", "index ", "\\")):
            continue
        if raw.startswith("+"):
            out.append((new, raw[1:]))
            new += 1
        elif raw.startswith("-"):
            out.append((max(new, 1), raw[1:]))
        else:
            new += 1
    return out


def is_game_file(path: str) -> bool:
    r = subprocess.run(["bash", os.path.join(ROOT, "tools/ci_scope.sh")], input=path + "\n",
                       capture_output=True, text=True)
    return r.stdout.strip() == "true"


def tokens(s: str) -> list[str]:
    return [t for t in re.split(r"[/_.\-\s]+", s.lower()) if t]


def contains_seq(hay: list[str], needle: list[str]) -> bool:
    n = len(needle)
    return n > 0 and any(hay[i:i + n] == needle for i in range(len(hay) - n + 1))


def load_map(groups: set[str]) -> list[tuple[str, set[str]]]:
    rules = []
    path = os.path.join(ROOT, "tools/test_map.txt")
    if not os.path.exists(path):
        return rules
    for n, line in enumerate(read("tools/test_map.txt").split("\n"), 1):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        glob, *suites = line.split()
        unknown = [s for s in suites if s not in groups and s not in ("core", "full")]
        if unknown:
            print("ci_select: tools/test_map.txt:%d unknown group(s) %s" % (n, " ".join(unknown)), file=sys.stderr)
        rules.append((glob, {s for s in suites if s not in unknown}))
    return rules


def autoload_names() -> dict[str, str]:
    out = {}
    try:
        text = read("project.godot")
    except OSError:
        return out
    sec = re.search(r"^\[autoload\]\n(.*?)(?:^\[|\Z)", text, re.M | re.S)
    for m in re.finditer(r'^(\w+)="\*?res://([^"]+)"', sec.group(1) if sec else "", re.M):
        out[m.group(2)] = m.group(1)
    return out


def mention_suites(at: Autotest, path: str, autoloads: dict[str, str]) -> set[str]:
    needles = ["res://" + path]
    base = os.path.basename(path)
    if len(base) >= 8:
        needles.append(base)
    folder = os.path.dirname(path)
    if not path.endswith(".gd") and folder.count("/") >= 1:
        needles.append("res://" + folder + "/")   # art read by folder: res://assets/v3/portraits/
    idents = []
    if path in autoloads:
        idents.append(autoloads[path])
    if path.endswith(".gd"):
        try:
            m = re.search(r"^class_name\s+(\w+)", read(path), re.M)
            if m:
                idents.append(m.group(1))
        except OSError:
            pass
    out = set()
    for f, (a, b) in at.funcs.items():
        body = "\n".join(at.lines[a - 1:b])
        if any(n in body for n in needles) or any(re.search(r"\b%s\b" % re.escape(i), body) for i in idents):
            out |= at.suites_of_func(f) if f != "_run" else {"core"}
    return out


def select(files: list[str], patch: str | None, explain: bool) -> list[str] | str:
    at = Autotest(read(AUTOTEST))
    groups = set(at.groups)
    rules = load_map(groups)
    autoloads = autoload_names()
    picked: set[str] = set()
    why = []
    for raw in sorted(set(files)):
        path = raw
        for suffix in (".import", ".uid"):
            if path.endswith(suffix):
                path = path[: -len(suffix)]
        if path == AUTOTEST:
            if patch is None:
                picked.add("full")
                why.append((raw, {"full"}, "no diff available"))
                continue
            for line, text in changed_lines(patch):
                s, reason = at.suites_of_line(line, text)
                if s:
                    picked |= s
                    why.append(("%s:%d" % (raw, line), s, reason))
            continue
        if not is_game_file(raw):
            continue
        s, reason = set(), []
        for glob, suites in rules:
            if fnmatch.fnmatch(path, glob):
                s |= suites
                reason.append("test_map " + glob)
        ptoks = tokens(os.path.splitext(path)[0])
        stoks = tokens(os.path.splitext(os.path.basename(path))[0])
        by_name = {g for g in groups if contains_seq(ptoks, tokens(g))
                   or (len("".join(stoks)) >= 5 and contains_seq(tokens(g), stoks))}
        if by_name:
            s |= by_name
            reason.append("name")
        m = mention_suites(at, path, autoloads)
        if len(m - {"full"}) > 0:
            m.discard("full")   # also used by a test only the full run has: the nightly run covers that one
        if m and len(m - {"core"}) <= MENTION_CAP:
            s |= m
            reason.append("mentioned in tests")
        if not s:
            s = {"core"}
            reason.append("no group covers it")
        picked |= s
        why.append((raw, s, ", ".join(reason)))
    if explain:
        for what, s, reason in why:
            print("  %-60s -> %-30s (%s)" % (what, " ".join(sorted(s)), reason), file=sys.stderr)
        if at.bad_groups:
            print("  note: --only blocks without return (fall into the full run): " + " ".join(sorted(at.bad_groups)),
                  file=sys.stderr)
    if not files:
        return "full"
    if "full" in picked:
        return "full"
    named = sorted(picked - {"core"})
    if len(named) > MAX_GROUPS:
        if explain:
            print("  %d groups > %d: full run instead" % (len(named), MAX_GROUPS), file=sys.stderr)
        return "full"
    return (["core"] if "core" in picked else []) + named


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", ROOT, *args], capture_output=True, text=True, check=True).stdout


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--base", default="origin/staging", help="compare with this ref (local use)")
    ap.add_argument("--files", help="changed paths, one per line ('-' = stdin)")
    ap.add_argument("--patch", help="unified diff of tools/autotest.gd (with --files)")
    ap.add_argument("--explain", action="store_true", help="print why, per file, to stderr")
    ap.add_argument("--list-groups", action="store_true", help="print every runnable group and exit")
    a = ap.parse_args()
    if a.list_groups:
        print(" ".join(["core"] + Autotest(read(AUTOTEST)).groups))
        return 0
    if a.files:
        text = sys.stdin.read() if a.files == "-" else open(a.files, encoding="utf-8").read()
        files = [l.strip() for l in text.split("\n") if l.strip()]
        patch = None
        if AUTOTEST in files and a.patch and os.path.exists(a.patch) and os.path.getsize(a.patch) > 0:
            patch = open(a.patch, encoding="utf-8", errors="replace").read()
    else:
        files = git("diff", "--name-only", "--merge-base", a.base).split("\n")
        files += git("ls-files", "--others", "--exclude-standard").split("\n")
        files = [f for f in files if f.strip()]
        patch = git("diff", "--merge-base", a.base, "--", AUTOTEST) if AUTOTEST in files else None
        if not files:
            print("none")
            return 0
    if files and not any(is_game_file(f) for f in files):
        print("none")
        return 0
    out = select(files, patch, a.explain)
    print(out if isinstance(out, str) else " ".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
