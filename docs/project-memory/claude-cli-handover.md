---
name: claude-cli-handover
description: Parames also runs Claude Code CLI locally; repo CLAUDE.md + tools/plane.py (PR #33, MV-94) keep both Claudes in sync
metadata:
  type: project
---

2026-10-23 (MERGED): Parames runs Claude Code CLI on Windows (C:\Users\param\Downloads\mobile-vault) alongside the claude.ai project. PR maxexq/mobile-vault#33 (branch mv-94-claude-cli-handover, Plane MV-94) adds:
- `CLAUDE.md` at repo root: all project rules (the CLI can't see this memory). When a new standing rule is added to memory, also add it to CLAUDE.md.
- `tools/plane.py`: stdlib Plane client (list/show/create/move/link/comment/states/labels; refs like MV-12). Key from env PLANE_API_KEY or git-ignored `.plane-api-key`; in cloud the proxy injects it. Cloud threads can use it too instead of ad-hoc urllib.
- Coordination: before starting, check `plane.py list --state "In Progress"`; an In Progress ticket is owned by whoever moved it. Branches `mv-<n>-name`, never push main.
- The CLI can't update the claude.ai playable artifact; the project side does that after a CLI PR.
- PR #35 (MV-95): CLI opens PRs with `gh pr create` (CLAUDE.md "Opening the PR"), never merges; .claude/settings.json allows plane.py + gh pr create/view, denies push to main, --force, gh pr merge.
Related: [[plane-setup]], [[god-mode]], [[feature-flags-design]]
