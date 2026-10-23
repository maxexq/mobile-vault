"""Repo tools the agents can call. Paths are sandboxed to the repo; secrets and .git are off limits.

Every tool returns a string (what the model sees). Tools in NEEDS_APPROVAL change files and
are held for a human yes/no before they run.
"""
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from .config import Config

MAX_READ = 60_000
MAX_OUT = 12_000
BLOCKED = re.compile(r"(^|/)(\.git|\.godot|\.venv|node_modules)(/|$)|(^|/)\.env$|cloud_config\.json$")
NEEDS_APPROVAL = {"write_file", "edit_file"}


class ToolError(Exception):
    pass


def _obj(props: dict, required: list[str]) -> dict:
    return {"type": "object", "properties": props, "required": required, "additionalProperties": False}


_S = {"type": "string"}
SCHEMAS = {
    "list_files": {
        "description": "List repo files matching a glob, e.g. 'scripts/**/*.gd'. Returns up to 300 paths.",
        "input_schema": _obj({"glob": {**_S, "description": "Glob relative to the repo root"}}, ["glob"]),
    },
    "read_file": {
        "description": "Read a text file from the repo, with line numbers. start/end are 1-based lines; start=1, end=0 reads the whole file.",
        "input_schema": _obj(
            {"path": _S, "start": {"type": "integer"}, "end": {"type": "integer"}}, ["path", "start", "end"]
        ),
    },
    "search_code": {
        "description": "Regex search over scripts/, tools/, docs/, config/ and README.md. Returns path:line: text.",
        "input_schema": _obj({"pattern": {**_S, "description": "Python regex, case-insensitive"}}, ["pattern"]),
    },
    "write_file": {
        "description": "Create or overwrite a whole file. Prefer edit_file for changes to existing files. "
        "A human approves this before it runs.",
        "input_schema": _obj({"path": _S, "content": _S}, ["path", "content"]),
    },
    "edit_file": {
        "description": "Replace one exact, unique occurrence of old_text with new_text in a file. "
        "A human approves this before it runs.",
        "input_schema": _obj({"path": _S, "old_text": _S, "new_text": _S}, ["path", "old_text", "new_text"]),
    },
    "git_diff": {
        "description": "Show the uncommitted changes in the repo (git diff + untracked files).",
        "input_schema": _obj({}, []),
    },
    "run_autotest": {
        "description": "Run the Godot smoke test (tools/autotest.gd). only='' runs everything (slow); "
        "only='large' runs the ~30 s large-room checks. Returns the tail of the log.",
        "input_schema": _obj({"only": _S}, ["only"]),
    },
    "run_balance": {
        "description": "Run the headless balance bot (tools/balance.gd) for N game minutes with an optional "
        "mode string like 'hard,fuel_scarce' ('' for standard). Returns the progression log.",
        "input_schema": _obj({"minutes": {"type": "integer"}, "mode": _S}, ["minutes", "mode"]),
    },
}


def schemas(names: list[str]) -> list[dict]:
    return [{"name": n, **SCHEMAS[n], "strict": True} for n in names]


def validate(name: str, args) -> None:
    """Inputs can arrive truncated when streamed; check them against the schema before running."""
    if name not in SCHEMAS:
        raise ToolError(f"unknown tool {name}")
    if not isinstance(args, dict):
        raise ToolError("tool input is not a JSON object")
    props = SCHEMAS[name]["input_schema"]["properties"]
    for key in SCHEMAS[name]["input_schema"]["required"]:
        want = props[key]["type"]
        ok = isinstance(args.get(key), str) if want == "string" else type(args.get(key)) is int
        if not ok:
            raise ToolError(f"missing or invalid '{key}' ({want})")


class RepoTools:
    def __init__(self, cfg: Config):
        self.root = cfg.repo_root.resolve()
        self.godot = os.environ.get("MV_GODOT_BIN") or shutil.which("godot") or shutil.which("godot4")

    def _path(self, rel: str) -> Path:
        p = (self.root / rel).resolve()
        if not p.is_relative_to(self.root):
            raise ToolError(f"{rel} is outside the repo")
        r = p.relative_to(self.root).as_posix()
        if BLOCKED.search(r):
            raise ToolError(f"{rel} is off limits")
        return p

    def run(self, name: str, args: dict) -> str:
        validate(name, args)
        return getattr(self, name)(**args)

    def list_files(self, glob: str) -> str:
        out = []
        for p in sorted(self.root.glob(glob)):
            r = p.relative_to(self.root).as_posix()
            if p.is_file() and not BLOCKED.search(r):
                out.append(r)
        return "\n".join(out[:300]) + (f"\n... {len(out) - 300} more" if len(out) > 300 else "") or "(no files)"

    def read_file(self, path: str, start: int, end: int) -> str:
        p = self._path(path)
        if not p.is_file():
            raise ToolError(f"{path} not found")
        lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
        s = max(start, 1)
        e = len(lines) if end <= 0 else min(end, len(lines))
        text = "\n".join(f"{i}\t{lines[i - 1]}" for i in range(s, e + 1))
        if len(text) > MAX_READ:
            text = text[:MAX_READ] + f"\n... truncated; {len(lines)} lines total, read a smaller range"
        return text or "(empty)"

    def search_code(self, pattern: str) -> str:
        try:
            rx = re.compile(pattern, re.I)
        except re.error as e:
            raise ToolError(f"bad regex: {e}")
        hits = []
        for g in ("scripts/**/*.gd", "tools/*.gd", "docs/**/*.md", "config/**/*.json", "README.md"):
            for p in sorted(self.root.glob(g)):
                for i, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                    if rx.search(line):
                        hits.append(f"{p.relative_to(self.root).as_posix()}:{i}: {line.strip()[:200]}")
                        if len(hits) >= 200:
                            return "\n".join(hits) + "\n... capped at 200 hits"
        return "\n".join(hits) or "(no matches)"

    def write_file(self, path: str, content: str) -> str:
        p = self._path(path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8", newline="\n")
        return f"wrote {path} ({len(content.splitlines())} lines)"

    def edit_file(self, path: str, old_text: str, new_text: str) -> str:
        p = self._path(path)
        text = p.read_text(encoding="utf-8")
        n = text.count(old_text)
        if n != 1:
            raise ToolError(f"old_text found {n} times in {path}; it must match exactly once")
        p.write_text(text.replace(old_text, new_text), encoding="utf-8", newline="\n")
        return f"edited {path}"

    def git_diff(self) -> str:
        diff = self._cmd(["git", "diff"], 60)
        new = self._cmd(["git", "ls-files", "--others", "--exclude-standard"], 60)
        return (diff + ("\nuntracked:\n" + new if new.strip() else ""))[-MAX_OUT * 2 :] or "(no changes)"

    def run_autotest(self, only: str) -> str:
        out = tempfile.mkdtemp(prefix="mv-autotest-")
        args = [self._godot(), "--path", ".", "--", "--autotest", f"--out={out}"]
        if only:
            args.append(f"--only={only}")
        return self._cmd(args, 1800)

    def run_balance(self, minutes: int, mode: str) -> str:
        args = [self._godot(), "--headless", "--path", ".", "--", "--balance", f"--minutes={max(1, minutes)}"]
        if mode:
            args.append(f"--mode={mode}")
        return self._cmd(args, 1800)

    def _godot(self) -> str:
        if not self.godot:
            raise ToolError("Godot not found: set MV_GODOT_BIN in ai/.env to the Godot 4.7.2 executable")
        return self.godot

    def _cmd(self, args: list[str], timeout: int) -> str:
        try:
            r = subprocess.run(args, cwd=self.root, capture_output=True, text=True, timeout=timeout,
                               encoding="utf-8", errors="replace")
        except subprocess.TimeoutExpired:
            raise ToolError(f"timed out after {timeout}s")
        out = (r.stdout or "") + (r.stderr or "")
        tail = out[-MAX_OUT:] if len(out) > MAX_OUT else out
        return f"exit code {r.returncode}\n{tail}"


def preview(name: str, args: dict) -> str:
    """Short human-readable description of a pending file change, for the approval prompt."""
    if name == "write_file":
        body = args.get("content", "")
        return f"write_file {args.get('path')} ({len(body.splitlines())} lines)\n{body[:1500]}"
    if name == "edit_file":
        return f"edit_file {args.get('path')}\n--- old\n{args.get('old_text', '')[:800]}\n+++ new\n{args.get('new_text', '')[:800]}"
    return f"{name} {args}"
