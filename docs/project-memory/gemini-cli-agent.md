---
name: gemini-cli-agent
description: Gemini/Antigravity as a 3rd repo agent was tried and dropped 2026-10-24 (PR #44 closed, MV-165 cancelled); facts learned about Gemini CLI/agy
metadata:
  type: project
---
2026-10-24 Parames asked for Gemini 4 Argon to work on the repo like Claude; PR #44 (GEMINI.md including CLAUDE.md, plane.py claim/--by, agy permissions) was CLOSED unmerged at Parames's request ("no need anymore"). MV-165 Cancelled. Repo has no GEMINI.md; CLAUDE.md still says two Claudes.
**Why dropped / facts if it comes up again:**
- Gemini CLI "Sign in with Google" is dead for personal accounts (must migrate to Antigravity CLI `agy`).
- Parames's `agy` login shows the Free/Plus model set (3.8 Flash, Sonnet/Opus 4.6), no Gemini 4 Argon, even after re-login, although Gemini web shows 4 Argon. Third-party models leave Free/Plus on 2026-11-02.
- agy reads workspace GEMINI.md/AGENTS.md, include syntax `@[label](path)`; permissions only in user `~/.gemini/antigravity-cli/settings.json`; API key route `modelProvider: gemini` + env GEMINI_API_KEY.
- Docs: antigravity.google/docs/{rules,install,permissions,models} via WebFetch (curl blocked).
Related: [[claude-cli-handover]], [[langgraph-ai-setup]]
