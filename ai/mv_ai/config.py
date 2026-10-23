"""Settings read from the environment (and ai/.env when python-dotenv is installed)."""
import os
from dataclasses import dataclass
from pathlib import Path

AI_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = AI_DIR.parent

try:
    from dotenv import load_dotenv

    load_dotenv(AI_DIR / ".env")
except ImportError:
    pass


@dataclass(frozen=True)
class Config:
    claude_model: str = "claude-opus-5-5"
    claude_effort: str = "high"
    gemini_model: str = "gemini-4-argon"
    gemini_thinking: str = "high"
    local_base_url: str = "http://127.0.0.1:11434/v1"
    local_model: str = "gemma4:12b"
    long_context_chars: int = 60000
    repo_root: Path = REPO_ROOT

    @classmethod
    def from_env(cls) -> "Config":
        e = os.environ.get
        return cls(
            claude_model=e("MV_CLAUDE_MODEL", cls.claude_model),
            claude_effort=e("MV_CLAUDE_EFFORT", cls.claude_effort),
            gemini_model=e("MV_GEMINI_MODEL", cls.gemini_model),
            gemini_thinking=e("MV_GEMINI_THINKING", cls.gemini_thinking),
            local_base_url=e("MV_LOCAL_BASE_URL", cls.local_base_url).rstrip("/"),
            local_model=e("MV_LOCAL_MODEL", cls.local_model),
            long_context_chars=int(e("MV_LONG_CONTEXT_CHARS", cls.long_context_chars)),
            repo_root=Path(e("MV_REPO_ROOT", str(REPO_ROOT))),
        )
