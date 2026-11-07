---
name: science-room-v3
description: MV-625 science room made per Room guide v3 (one-point, L1-L3 single cell, Claude picks), In Review; files designs/room-redesign-preview/science_v3/, page Science Room v3
metadata:
  type: project
  modified: 2026-10-30T10:35:31.463Z
---

2026-10-30 Parames: "make the science room, radio room, distillery, workshop per Guide V3, L1-L3 only, pick yourself" (siblings: radio MV-623, workshop MV-624, distillery MV-626). Science = Plane MV-625 (In Review).
- Folder /mnt/project-files/designs/room-redesign-preview/science_v3/: gen_sci3.py <A|B|C> <seed> (generate-image-v2, armory guide.png + armory L1 shabby style), edit_sci3.py L2|L3 <seed> [src] (edit-images-v2 from L1, TONE clause keeps dim warm palette), anim_sci3.py (idle/working/powerout; scientist at still (60,88), retired_teacher at microscope (96,88), crew_blend, emergency_light.draw), hotspots_sci3.py -> hotspots.json format 2 (room "science", new action do_research, add to tools/hotspots.py ACTIONS in the repo PR), plane_mv.py, page_science_v3.html (page source copy).
- Picks: L1 = out/sci3_B_7_0 (= sci3_L1.png; pallet shelf, plank bench on cinder blocks, candle still, microscope, filing cabinet + cooler; A and B_2/B_3 had back-wall doors), L2 = sci3_L2_s1_0 (= sci3_L2.png), L3 = sci3_L3_s2_0 (= sci3_L3.png; fume hood, centrifuge, green flask, terminal, server boxes).
- Tone: mean luma L1/L2/L3 47/45/45, matches kitchen v3 (47-49); infirmary L3 is 77. Power-out: flames keep burning (fuel), L3 electrics die to a red battery blink.
- ~70 gens (L1 30, L2 20, L3 20); balance 4757 -> 4507 incl. sibling threads. Page https://claude.ai/artifact/88ywVzu6TehYL7B1YfhYkv, card on index v46. Asset log group room-v3-science (backfill from out/).
**How to apply:** rerun the scripts to change things; merged x2/x3 not made. Related: [[room-guide-v3]], [[room-sample-pages]], [[crew-room-blend]], [[room-v3-emergency-light]], [[room-lineup-v3]].
