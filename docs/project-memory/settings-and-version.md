---
name: settings-and-version
description: Where game version, build stamp and player settings live (Settings autoload, BuildInfo class) since PR #3
metadata:
  type: project
---

Added 2026-10-22 on branch `feat/settings` (PR #3, github.com/maxexq/mobile-vault):
- Version: bump only `BuildInfo.GAME_VERSION` in scripts/build_info.gd (currently "4.3"); Trace.VERSION and the title read it. Run `sh tools/stamp_build.sh` before every web export so Settings > About shows the commit (build_info.json is git-ignored; missing = "dev").
- Player prefs: autoload `Settings` (appended after Tutorial). `Settings.get_value(k)` / `set_value(k, v)` + signal `changed(key)`. Keys: master, music, sfx, mute, lang, ui_scale, zoom, crt, fx_gpu, fps, fullscreen, shake, gore, vibrate. Stored apart from the save.
- Audio buses `Music` and `SFX` exist at runtime: new sounds should play on them so the volume sliders work.
- New panels: `hud.open_settings(tab)` works on the title screen too.
Related: [[construction-tutorial-integration]]
