---
name: distillery-v3
description: MV-626 distillery (Data id refinery, FUEL REFINERY) v3 per Room guide v3, L1-L3 single cell, Claude picked all, In Review; files distill_v3/
metadata:
  type: project
  modified: 2026-10-30T10:35:30.181Z
---

2026-10-30 Parames: make science lab, radio, distillery, workshop per Room guide v3, L1-L3 only, Claude picks. This note = distillery. Plane MV-626 (In Review). Siblings: radio MV-623, workshop MV-624.
- Folder /mnt/project-files/designs/room-redesign-preview/distill_v3/: gen_dist3.py <A|B|C> <seed> (copy of gen_inf3 pattern), edit_dist3.py L2|L3 <seed> [src] (both from L1), anim_dist3.py (idle/working/powerout; bus_mechanic tends still, truck_driver barrels -> fuel storage; crew-occlusion mask so fire/drip fx stay behind crew; L1/L2 wood fire keeps burning in power-out, L3 gas valve + panel go out), hotspots_dist3.py (format 2, room "refinery"), plane_mv.py.
- Picks: L1 = out/ds3_A_7_1 (barrel mash, drum still on brick fire pit, coil into bucket, jerrycans, oil drum, extinguisher), L2 = ds3_L2_s1_0 (s2 lost the jerrycan zone), L3 = ds3_L3_s1_0 (control panel; s2 too bare).
- Finals final/refinery_L{1,2,3}.png + hotspots.json. NEW action refine_fuel must be added to tools/hotspots.py ACTIONS in the repo PR.
- Page "Distillery v3 Samples" https://claude.ai/artifact/R4aXQAGf4T55zAh9bdSRpZ (source in that session's scratchpad; read before republishing), card on index v45. Asset log group room-v3-distillery (16 images).
- 70 gens (L1 3x10, edits 4x10); balance 4787 -> 4507 in the window with 3 sibling threads spending.
**How to apply:** not in game yet (waits for [[world-v2-scale-plan]]). Related: [[room-guide-v3]], [[infirmary-v3]], [[room-sample-pages]], [[room-hotspots]].
