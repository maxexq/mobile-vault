---
name: web-boot-shell
description: Loading screen = Web preset custom HTML shell tools/web_shell.html (MV-160); artifact built from same export by tools/artifact_html.py
metadata:
  type: project
  modified: 2026-10-24T00:59:10.669Z
---

2026-10-24, MV-160, PR #38 MERGED 06:38 UTC: Vercel showed Godot's default loader because the Apocarlypse boot card only existed in the hand-made artifact page (artifact https://claude.ai/artifact/XZt7RMvDG7TFXjdH5MYmAU).
- Fix: export_presets.cfg `html/custom_html_shell="res://tools/web_shell.html"` (placeholders $GODOT_URL/$GODOT_CONFIG/$GODOT_HEAD_INCLUDE/$GODOT_THREADS_ENABLED/$GODOT_PROJECT_NAME, verified in 4.7.2 export_plugin.cpp). `web/logo.png` = copy of assets/ui/logo.png, committed (Godot doesn't export it).
- Loading page (Parames 2026-10-24): NO patch notes during the test phase (only random gameplay tips, `TIPS` array, one every 6s), plus a 240x112 pixel driving scene (bus + desert parallax + walkers, tap to fire) from web/boot/*.png made by tools/boot_art.py (rerun after art regen). Autotest checks both.
- The "v4.x · GODOT 4.7.2" line lives in the shell; autotest checks version == BuildInfo.GAME_VERSION. Bump both together.
- Artifact: `python3 tools/artifact_html.py --out build/artifact` gzips index.wasm/index.pck -> engine.wasm/pack.wasm and injects the fetch shim at `<!--BOOT_SHIM-->`. Publish build/artifact/index.html with its files to the same artifact URL. Never hand-edit the artifact page again.
- Cloud container setup: Godot 4.7.2 editor + templates download from GitHub release can reset mid-way; resume with curl -C -. cloud_config.json can be rebuilt from strings in web/index.pck (url, sb_publishable key, site_url).
Related: [[og-share-preview]], [[game-name-apocarlypse]], [[backend-database-choice]]
