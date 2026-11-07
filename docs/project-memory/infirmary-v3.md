---
name: infirmary-v3
description: MV-617 infirmary redone per Room guide v3 (one-point, single cell L1-L3, no merged), all picks by Claude, Done 2026-10-30; files designs/room-redesign-preview/infirmary_v3/
metadata:
  type: project
  modified: 2026-10-30T03:22:47.121Z
---

2026-10-30 Parames (project chat): make kitchen, grow (3-stage growth anim), infirmary, water purifier as v3, L1-L3 only, "decide yourself". This note = infirmary part. Plane MV-617 (Done).
- Folder /mnt/project-files/designs/room-redesign-preview/infirmary_v3/: gen_inf3.py <A|B|C> <seed> (generate-image-v2 144x96, reference armory/guide.png, style armory/out/ar_L1shabby_s2_0.png), edit_inf3.py L2|L3 <seed> [src], anim_inf3.py (idle/working/powerout, medic treats at bed + scientist preps at cart, crew_blend; power-out: IV keeps dripping, L3 ECG -> red battery blink), hotspots_inf3.py (format 2, treat_patient on bed, imports armory overlay), plane_mv.py (tiny Plane create/state helper).
- Picks: L1 = out/inf3_A_7_1.png (folding cot, bent IV pole, crate table, dented cabinet, roped oxygen, painted red cross, bare bulb = v2 ward A equipment), L2 = out/inf3_L2_s1_0.png (iron bed, tin-shade lamp, privacy screen), L3 = out/inf3_L3_s1_0.png (dark walls, ECG monitor box (29,35,38,42), IV pump, defib on wall, curtain). Alt L3 s2 = light grey walls (rejected: off-tone).
- 70 gens (L1 30, L2 20, L3 20). Page "Infirmary v3 Samples" https://claude.ai/artifact/CRgmJvc5N4AZWUmvBrd4zB (source in that session's scratchpad; read before republishing), card on index v38. Asset log group room-v3-infirmary (16 images; backfill via sparse clone tools/ of the public repo works, env has ASSET_LOG_URL).
- Note: L3 bed legs reach y~92, slightly into the 89-95 walkway.
**How to apply:** rerun the scripts for changes; not in game yet (waits for [[world-v2-scale-plan]]). Related: [[room-guide-v3]], [[infirmary-redesign]], [[halloween-rest-room]], [[room-sample-pages]].
