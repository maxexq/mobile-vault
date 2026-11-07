---
name: crew-roster-20
description: MV-170 20 named crew (dw_crew_<id> strips + pt_ portraits) behind Features crew_roster_20, PR #68; art pipeline + gotchas
metadata:
  type: project
  modified: 2026-10-24T19:18:02.675Z
---

2026-10-24, Plane MV-170 (Codex handoff: specs + concept ZIPs attached to the Plane ticket, downloadable via the attachments API). PR maxexq/mobile-vault#68 (branch mv-170-crew-roster), MERGED 2026-10-24 19:42 UTC (Done), artifact v51.
- Art: `CREW` table in tools/art/chars.py (skin/hair style/hat/face/coat/arms/torso/below/pt per id), `crew_strip(id)` 280x20 = 20 frames 14x20, `crew_portrait(id)` 20x20. Pixels restricted to each spec palette (`_crew_snap` + `_crew_shade` ramp steps). References + 40 specs tracked in tools/art/crew_roster_20/ (.gdignore).
- Game: Data.CREW_ROSTER (Thai names; jill/leon display as นีออน/เจฟ per the Plane edit), Crew.roster_pick, rolled in Game.recruit_random after the outfit roll only when the switch is on. Tune crew.roster_chance 0.35, crew.cameo_weight 0.5. Dev.spawn_roster/spawn_roster_all/roster_chance; GOD crew tab "CREW ROSTER" preview grid. Autotest `--only=crew`.
- Gotcha: after regenerating assets/atlas in an already-imported checkout, run `godot --headless --import` again or the game uses the stale atlas texture with the new atlas.json (wrong sprites).
- Gotcha: `pkill -f <pattern>` / `pgrep -f` in Bash matches the tool's own shell and kills it (exit 144); kill Godot by `ps -eo pid,comm`.
- Cloud session could clone (add_repo push access needed to push). Not done: strangers at the door (Inspection) still use outfit x hair only.
Related: [[god-mode]], [[feature-flags-design]], [[codex-art-analyst]], [[ci-autotest]]
