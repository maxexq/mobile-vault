---
name: gamedev-agent-skills
description: 17 skills from awesome-gamedev-agent-skills vendored into mobile-vault .claude/skills via PR #4 (2026-10-22)
metadata:
  type: project
  modified: 2026-10-22T17:08:09.617Z
---

On 2026-10-22, Parames asked to adopt gamedev-skills/awesome-gamedev-agent-skills (Apache-2.0, Godot 4.7 baseline, checked against 4.7.2). 17 skills (Godot GDScript/export/headless-testing/UI/resources/etc. plus save-systems, game-ui-ux, game-feel, performance, create-game-assets, survival-crafting) were copied by hand from commit 38a4c25 into `.claude/skills/` in PR maxexq/mobile-vault#4 (merged 2026-10-22). `.claude/skills/README.md` holds the project rules that override them.

**Why:** the npx installer and pip/Pillow were not run, per [[godot-download-approval]]. The web export is single-threaded on Vercel, so the COOP/COEP advice in godot-export does not apply.
**How to apply:** to update, re-copy from upstream by hand and bump the commit hash in the README.
