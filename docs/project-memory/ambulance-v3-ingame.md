---
name: ambulance-v3-ingame
description: MV-715 Dr. Ren ambulance replaces the first vehicle (van): v3 interior shell done (switch ambulance_v3), outside world v2 picked by Parames 2026-11-08
metadata:
  type: project
---

2026-11-08 Parames: "save it and use it in the game, replacing the first vehicle". Decision card: Parames picked
**"Outside world too (world v2)"** (not just the v3 interior).
- Done first (branch mv-715-ambulance-v3, stacked on mv-711 PR #193): switch `ambulance_v3`; InteriorV3Panel draws
  assets/vehicles/ambulance_v3/shell_f1..5.png (638 wide, h = 240 + 112*(n-1)) over the cells when tier == van;
  cells at x 146+152*col, y 88+112*row (row 0 = top). Trailers stand behind, bottoms 40 px above shell bottom.
  Dev.ambulance_v3_preview(n) (van is 2-5 floors in game; 1-floor shell unused), GOD รถ tab row, autotest
  `--only=ambulance_v3`.
- Shells built by /mnt/project-files/designs/dr-ren-ambulance/mf/shell.py <out dir> from f1r3/f2r3/f3r3; 4-5 floors
  repeat f3's middle floor with the front wall from the top floor (no extra stack tip / lantern foot).
- Driver A2 (approved) not in the shell yet (cab is empty glass).
- World v2 phase 1 (same branch/PR): switch `world_v2`; Vehicle.v2 draws ambulance + RoomV3Cell at V2_K 0.5
  (world_2x keeps full detail), cells 72x48 at x 73+76*col, floors 56 apart, length 319 (v2_extra 39 added to
  rear_shift/unit_x). Old RoomViews hidden but kept for logic. Phase 2 todo: exterior mods/roof props/solar,
  closed hull (X-ray), turning wheels, cab driver A2, trailers in v3 art, old-scale roof/deck crew.
Related: [[dr-ren-ambulance]], [[ambulance-drive-anim-2]], [[rooms-crew-v3-ingame]].
