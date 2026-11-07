---
name: workshop-v3
description: MV-624 workshop (โรงช่าง) per Room guide v3, L1-L3 single cell, anim, hotspots fmt 2 (new actions salvage_parts/repair_hull), Claude picked all, In Review; files workshop_v3/
metadata:
  type: project
---

2026-10-30 Parames: make science, radio, refinery and workshop rooms per Guide v3, L1-L3 only, pick yourself. Workshop = this note, Plane MV-624 (In Review). Radio = MV-623 (other thread).
- Folder /mnt/project-files/designs/room-redesign-preview/workshop_v3/: gen_ws3.py <A|B|C> <seed> (generate-image-v2, armory guide.png + L1 shabby style), edit_ws3.py L2|L3 <seed> [src], anim_ws3.py (idle/working/powerout, emergency_light.py, crew_blend), hotspots_ws3.py, plane_mv.py, bal.py (PixelLab balance).
- Picks: L1 = out/ws3_C_7_0 (pallet bench + vice, anvil on stump, scrap welder trolley, parts rack, hull patch plates on floor; A had back-wall doors, B too light grey), L2 = ws3_L2_s1_0 (plates stacked), L3 = ws3_L3_s1_0 (lathe, glowing welder, orange status lamp at (92,33)).
- Working anim: teen_tinkerer hammers hull plates at (88,91) with sparks (work frames 3/8 = impact), bus_mechanic at bench vice (54,91).
- hotspots.json room "workshop": NEW actions salvage_parts (bench) + repair_hull (anvil, plates) -> add to tools/hotspots.py ACTIONS in the repo PR.
- Finals final/workshop_L{1,2,3}.png. Page "Workshop v3 Samples" https://claude.ai/artifact/MQDCCp7Y47dMhYY2r3tYaB (source in that session's scratchpad; Artifact read before republishing), card on index v44. Asset log group room-v3-workshop (16 images, via sparse clone of staging tools/).
- ~70 gens (balance 4787 -> 4507 in the window, radio thread spending at the same time).
**How to apply:** not in game yet (waits for [[world-v2-scale-plan]]); regen only the level asked. Related: [[room-guide-v3]], [[infirmary-v3]], [[room-sample-pages]], [[room-hotspots]].
