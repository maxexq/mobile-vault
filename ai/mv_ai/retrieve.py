"""Dependency-free lexical retrieval over the repo's code and docs (a first RAG step).

Chunks GDScript, docs and data files into ~60-line pieces and ranks them with a
BM25-style score. Good enough to ground answers in real code; swap for embeddings later.
"""
import math
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

GLOBS = ("scripts/**/*.gd", "tools/*.gd", "docs/**/*.md", "README.md", "config/**/*.json", "web/features.json")
CHUNK_LINES = 60
_TOKEN = re.compile(r"[A-Za-z_][A-Za-z0-9_]+|[฀-๿]+|\d+")


@dataclass
class Chunk:
    path: str
    start: int
    text: str

    def cite(self) -> str:
        return f"{self.path}:{self.start}"


def tokens(text: str) -> list[str]:
    out = []
    for t in _TOKEN.findall(text.lower()):
        out.append(t)
        if "_" in t:
            out.extend(p for p in t.split("_") if len(p) > 2)
    return out


class Index:
    def __init__(self, chunks: list[Chunk]):
        self.chunks = chunks
        self.tf = [Counter(tokens(c.text)) for c in chunks]
        self.lens = [sum(tf.values()) or 1 for tf in self.tf]
        self.avg = sum(self.lens) / max(len(self.lens), 1)
        df = Counter(t for tf in self.tf for t in tf)
        n = len(chunks)
        self.idf = {t: math.log(1 + (n - d + 0.5) / (d + 0.5)) for t, d in df.items()}

    @classmethod
    def build(cls, root: Path) -> "Index":
        chunks = []
        seen = set()
        for g in GLOBS:
            for p in sorted(root.glob(g)):
                if p in seen or not p.is_file():
                    continue
                seen.add(p)
                lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
                rel = p.relative_to(root).as_posix()
                for i in range(0, len(lines), CHUNK_LINES):
                    body = "\n".join(lines[i : i + CHUNK_LINES])
                    if body.strip():
                        chunks.append(Chunk(rel, i + 1, body))
        return cls(chunks)

    def search(self, query: str, k: int = 8) -> list[Chunk]:
        q = set(tokens(query))
        scored = []
        for i, tf in enumerate(self.tf):
            s = 0.0
            for t in q:
                f = tf.get(t)
                if f:
                    s += self.idf[t] * f * 2.2 / (f + 1.2 * (0.25 + 0.75 * self.lens[i] / self.avg))
            if s > 0:
                scored.append((s, i))
        scored.sort(reverse=True)
        return [self.chunks[i] for _, i in scored[:k]]


def render(chunks: list[Chunk]) -> str:
    return "\n\n".join(f"### {c.cite()}\n```\n{c.text}\n```" for c in chunks)
