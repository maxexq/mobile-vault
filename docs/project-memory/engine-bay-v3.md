---
name: engine-bay-v3
description: MV-707 engine bay v3 room (one-point, empty cradle) + 8 lore engines inpainted on it, artifact Engine Bay v3, awaiting picks
metadata:
  type: project
---
2026-11-03 Parames: design engine bay + each engine type from Dr. Ren lore + road train. Plane MV-707 Needs Decision. Artifact https://claude.ai/artifact/F497YgTisFHRbwNfm3Td4P (publish from a scratchpad copy; publishing straight from /mnt/project-files failed "source file changed").
- Pipeline /mnt/project-files/designs/engine-bay-v3/: gen_bay.py (generate-image-v2 144x96, armory guide + L1 shabby style, 4 images = 11 gens; prompt must be <=2000 chars), inp_eng.py (inpaint-v3 box 42,36-102,88 on out/bay_L1_7_1.png, 1 image ~13 gens). Standalone engine sprites via generate-image-v2 48x40 came out tiny and identical (17 gens wasted) -> inpaint on the cradle instead, cut sprites later by diff.
- Engines (hp -> tow t = 0.23*hp, size S/M/L, ambulance max M, prime mover L): MU-150 ambulance diesel S 150 (AURORA ECU box = rule 4 protection), woodgas "ember cult" S 110, raider V8 M 300, EV S 400, MAMMOTH genset L 420, army turbo6 M 480 (comes with prime mover quest, Col. Krit), HELIOS GSE turbine L 650, ring-shard fusion M 800 (pings OVERSEER, +threat).
- Proposed: bay opened by tapping the hood (not a body cell); AURORA ECU must be moved on engine swap; transponder power from engine supports crew cap. All pending picks.
Related: [[engine-bay-design]], [[road-train-design]], [[dr-ren-lore]], [[room-guide-v3]].
