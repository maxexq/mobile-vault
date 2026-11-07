---
name: mushroom-farm-v3
description: MV-643 mushroom farm (โรงเพาะเห็ด) v3 L1-L3 (Claude picks) + 3 code-drawn growth stages + anim + hotspots fmt 2 room "mushroom", APPROVED + saved (mush_v3/approved/), Done; page Mushroom Farm v3
metadata:
  type: project
  modified: 2026-10-30T15:35:31.552Z
---

2026-10-30 Parames: "ทำโรงเพาะเห็ด L1-L3 ตาม Guide v3 เลือกห้องเองได้เลย มี stage 3 stage การโตของเห็ดด้วย". From the extra ideas in [[new-rooms-10-ideas]] (food with no power/light, works in power-out, fertiliser bonus next to pens). Plane MV-643 (id e16be730-8d6e-4c44-be9a-c91396d048da) Done. 15:37 Parames "เซฟ" = APPROVED, saved to mush_v3/approved/.
- Zones left -> right: straw sacks + pasteurising drum | fruiting rack of 2x4 hanging grow bags (centre back wall; L2 plastic curtain over column 4, L3 humidity tent + mister pipe + gauge) | harvest crate, bucket/compost, mister jug, stool.
- Folder /mnt/project-files/designs/room-redesign-preview/mush_v3/: gen_mush3.py A <seed>, edit_mush3.py L2|L3 <seed>, stages_mush3.py (BAGS boxes identical in L1-L3; clones the clean bag 0/4 tile over every bag, wipes old fingers, then s2 = PIN_R buds, s3 = CL_R oyster cluster right + small left; L2 curtain re-hazed with per-column median; L3 skips wipe + bag-7 clone), anim_mush3.py (plant_grower mists + picks + drops in crate, truck_driver stirs drum with steam; power-out keeper keeps harvesting with a hand oil lamp; spores; growth loop with dither reveal), hotspots_mush3.py (new actions harvest_mushrooms, mist_bags, pasteurize_straw -> add to tools/hotspots.py ACTIONS in repo PR), page_mush_v3.html, plane_mv.py.
- Picks: L1 out/mush3_A_7_0, L2 mush3_L2_s1_0, L3 mush3_L3_s1_0 darkened gamma 1.15 (luma 44/44/41). final/mushroom_L{n}.png + _stage{1,2,3}.png + hotspots.json.
- Gens ~100 (generate-image-v2 2 runs, edit-images-v2 4 runs), balance 13064 -> 12964 (other threads also spending).
- Page https://claude.ai/artifact/5go7nnGwUVBmQWi1yJXVyW (published from scratchpad mush_site/), card on index v57.
**How to apply:** if Parames says "เซฟ"/approves, copy finals + anims + hotspots + README to mush_v3/approved/ and move MV-643 to Done. Not in game yet (waits for [[world-v2-scale-plan]]). Related: [[room-guide-v3]], [[chicken-coop-v3]], [[room-hotspots]], [[room-v3-emergency-light]], [[crew-room-blend]].
