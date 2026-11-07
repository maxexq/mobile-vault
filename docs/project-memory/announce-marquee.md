---
name: announce-marquee
description: MV-188 news/new-version marquee strip (PR #70): Announce autoload, features.json "announce", web/version.json from stamp_build.sh
metadata:
  type: project
---

2026-10-24 Parames asked (after learning in-session players never get updates until reload) for a scrolling top-of-screen text strip, 2-3 loops, for updates/news. PR maxexq/mobile-vault#70 MERGED 2026-10-24 20:23 UTC, Plane MV-188 Awaiting Verify (live web check of the UPDATE strip pending), artifact v52.
- Autoload `Announce` (last in list) + `Marquee` (scripts/ui/marquee.gd, CanvasLayer 45 made in main.gd, `main.marquee`).
- Messages: `"announce": [{id, text, text_en?, from?, to?, loops?}]` in web/features.json; each id once per browser (localStorage `mobile_vault_announce_seen_v1`) -> a new message needs a NEW id.
- New version: `tools/stamp_build.sh` also writes `web/version.json` {version, commit, built} (committed with web/). Game polls features.json + version.json 30 s after boot, every `announce.poll_min` (5) min and on visibilitychange; newer `built` = green UPDATE notice, tap = save + reload. NOTIFICATION_APPLICATION_FOCUS_IN is NOT sent on web (docs: desktop+mobile only), so JS visibilitychange is used.
- Switch `announce`, tune announce.loops/speed/poll_min, GOD ระบบ > ANNOUNCE, autotest `--only=announce`.
- Before this: index.pck cached 5 min, index.wasm 1 day (vercel.json) - engine upgrade would need cache busting.
Related: [[feature-flags-design]], [[web-boot-shell]], [[versioning-release]]
- 2026-10-24 Parames chose repeat per message: `"repeat_hours"` (0-720) in an announce entry; seen is now {id: last shown time} (PR #72 MERGED 21:11 UTC, artifact v55). PR #71 merged: first message id `news-strip-2026-10-25` (to 2026-10-31). The claude.ai artifact has its OWN copy of features.json (copied at artifact build), so a features.json-only change must also be republished to the artifact (done as v54). Tester "didn't see it" -> check GOD ระบบ > ANNOUNCE line (no section = old build, reload; open 0 = features.json not loaded; seen>=1 = already shown).
