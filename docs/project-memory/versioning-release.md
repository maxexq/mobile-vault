---
name: versioning-release
description: Semver GAME_VERSION 4.7.0-alpha.1 + channel badge, CHANGELOG.md, tools/release.py, Release workflow (MV-111, PR #42)
metadata:
  type: project
  modified: 2026-10-24T07:21:04.604Z
---

2026-10-24 MV-111, PR maxexq/mobile-vault#42 MERGED 2026-10-24 07:25 UTC, Plane Done. First release v4.7.0-alpha.1 published by Parames 2026-10-24 (pre-release, web zip attached), workflow verified working.
- Parames chose to CONTINUE numbering: 4.6 -> `4.7.0-alpha.1` (not reset to 0.9). Beta will be `release.py bump beta` -> 4.8.0-beta.1.
- `BuildInfo.ver_cmp` semver (pre-release < release; "4.6" short form ok), also used by Features remote min_game/max_game. `release_channel()` from the pre-release tag; badge "ALPHA TEST" under the logo on title + About (`UIKit.channel_tag`, switch `channel_badge`), GOD ระบบ preview via `Dev.channel_preview`. `BuildInfo.channel()` was renamed `build_type()`.
- Never hand-edit the version: `python tools/release.py bump <alpha|beta|rc|stable|patch|minor|major>` updates build_info.gd + tools/web_shell.html + dates CHANGELOG section; `changelog` pulls merged PRs since last v* tag into [Unreleased]; `check` runs in the Autotest workflow (fails if shell/changelog disagree).
- Release: Actions > Release > Run workflow on main (or push tag v<ver>) -> GitHub Release, pre-release for alpha/beta/rc, web zip attached. No tags existed before; first release v4.7.0-alpha.1 is for Parames to run after merge.
- Autotest group `--only=version`.
Related: [[web-boot-shell]], [[feature-flags-design]], [[ci-autotest]], [[god-mode]]
- 2026-10-24 21:20 UTC: v4.7.0-alpha.2 released by Claude (MV-368, PR #73 after merging #72 with Parames's OK); Parames's "deploy prod + new alpha tag" covers merging the release PR + running Release. `release.py changelog` adds a "Merged pull requests" list on top of the hand-written lines (expected). Vercel prod status = commit status context "Vercel" on main (vercel.app is 403 from cloud). Artifact republish was blocked by the auto-mode classifier: ask Parames before publishing.
