---
name: codex-art-analyst
description: Codex CLI on Parames's PC (ChatGPT sign-in, no API key) as art analyst writing micro-asset Plane tickets; AGENTS.md + tools/micro_asset.py (PR #50, MV-168)
metadata:
  type: project
  modified: 2026-10-24T09:08:32.295Z
---
2026-10-24 Parames picked Codex CLI (own PC, ChatGPT plan login, NOT an API key, to avoid extra cost) as an art analyst/planner; Claude builds. PR maxexq/mobile-vault#50 (MERGED 2026-10-24, branch mv-168-codex-art-analyst, Plane MV-168 Done):
- `AGENTS.md`: Codex rules, reads CLAUDE.md first; planner only (no code/commits/PRs/installs/pixellab gen).
- `docs/micro-assets.md`: spec format `micro-asset/1` (id, size, frames, palette names from RAMPS, outline, light, parent, layer, anchor+pivot, generator, feature, replace, refs, acceptance) + Codex setup.
- `tools/micro_asset.py`: ref/sheet/new/check/post/queue/pull/verify. Tickets titled `[micro] <id>: ...`, Todo, labels `micro-asset`+`art` (label created in Plane), spec JSON embedded in description as `<pre><code>micro-asset-spec ...`; round-trip tested. Drafts/sheets in git-ignored tools/art/micro/.
**Codex facts (official docs learn.chatgpt.com/codex, 2026-10-24):** Windows install `powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"` or `npm i -g @openai/codex`; Plus/Pro get gpt-6.1-sol + GPT-6 Luna with ChatGPT sign-in (Plus ~15-160 Sol msgs/5h); Free/Go only Luna and CLI not confirmed; API-key sign-in bills API rates. AGENTS.md auto-read, no include syntax, 32 KiB cap. Sandbox workspace-write + approvals on-request. `codex --image` attaches images. developers.openai.com redirects to learn.chatgpt.com.
**How to apply:** Claude picks up work with `micro_asset.py queue`/`pull`, `verify` after generate_pixel_art.py. Software install on the PC needs Parames's OK. Related: [[claude-cli-handover]], [[gemini-cli-agent]], [[pixellab-api]], [[plane-setup]].
