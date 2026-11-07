---
name: empty-cell-v3
description: MV-621 empty cell v3 per Room guide v3 (no levels/timer, 3 build stages, anim, hotspots fmt 2 with open_build_menu), Claude picked all, In Review; files empty3/
metadata:
  type: project
---

2026-10-30 Parames: make the Empty room (placeholder before building another room) per Room guide v3, no timer, 3 stages (just started, under construction, finished), no picks needed. Plane MV-621 (In Review).
- Folder /mnt/project-files/designs/room-redesign-preview/empty3/: gen_empty3.py <A|B> <seed> (generate-image-v2, armory guide.png layout), edit_empty3.py s2|s3 <seed> [src] (edit-images-v2), anim_empty3.py (idle/working/powerout per stage + em3_build.gif loop with dust puff; worker = construction_worker clip: s1 hauls crates<->sacks, s2 welds at scaffold with sparks, s3 inspects socket/valve), hotspots_empty3.py, plane.py, page_empty_v3.html (page source).
- Picks: stage1 = out/em3_A_7_2 (bare shell + materials both sides), stage2 = out/em3_s2_e1_0 (scaffold, half new panels), stage3 = out/em3_s3_e3_0 (2nd round from stage2 with "still worn, dark" wording; 1st round was too bright grey).
- Finals final/empty_stage{1,2,3}.png + hotspots.json (room "empty_v3", keys stage1..3, per-stage floor). build_site hotspot covers the cell, NEW action open_build_menu must be added to tools/hotspots.py ACTIONS in the repo PR.
- Page "Empty Cell v3" https://claude.ai/artifact/Swa1KdABNEcrBMSSUQkv1P, card on index v42. ~80 gens (8 calls x10), balance 4870 -> 4790.
**How to apply:** game shows stage by build progress of the slot; not in repo yet (no PR asked). Supersedes [[empty-cell-v2]]. Related: [[room-guide-v3]], [[room-sample-pages]], [[room-hotspots]].
