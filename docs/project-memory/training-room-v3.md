---
name: training-room-v3
description: MV-633 training room (ห้องฝึก) v3 L1-L3 per Room guide v3, Claude picked all, anim + hotspots fmt 2, APPROVED + saved (train_v3/approved/), Done; files train_v3/, page Training Room v3
metadata:
  type: project
---

2026-10-30 Parames: "ทำห้องฝึก L1-L3 ตาม Guide v3 เลือกห้องเองได้เลย". From [[new-rooms-10-ideas]] #4. Plane MV-633 Done. 13:34 Parames "เซฟ" = APPROVED, saved to train_v3/approved/ (art, hotspots.json, anim GIFs, README).
- Zones left -> right: strength (bench + barbell) -> heavy bag over mat (centre) -> training dummy + pull-up bar (right).
- Folder /mnt/project-files/designs/room-redesign-preview/train_v3/: gen_train3.py A <seed> (quarantine pattern), edit_train3.py L2|L3 <seed>, grid.py, anim_train3.py (soldier at bench, biker punches bag = bag row-shear sway + chalk puffs, hunter drills dummy; idle bag drift; L3 amber timer at (62,27) dies in power-out; emergency_light; crew_blend), hotspots_train3.py (room "training"; NEW actions lift_weights, hit_bag, spar_dummy, pull_ups -> add to tools/hotspots.py ACTIONS in the repo PR), page_training_v3.html, plane_mv.py.
- Picks: L1 out/train3_A_7_0 (bucket barbell, sand jugs, duffel bag, tyre-head dummy; A_11_2 had real plates = not makeshift), L2 train3_L2_s1_0, L3 train3_L3_s1_0 (s2 too dark, dummy tiny). final/training_L{1,2,3}.png + hotspots.json. Mean luma 44/41/40.
- 60 gens (generate-image-v2 2x10, edit-images-v2 4x10), balance 4039 -> 3979.
- Page https://claude.ai/artifact/P5TTtWEkTD6GumosyFoavw (published from scratchpad copy), card on index v52.
**How to apply:** not in game yet (waits for [[world-v2-scale-plan]]). Related: [[room-guide-v3]], [[quarantine-room-v3]], [[room-hotspots]], [[room-v3-emergency-light]].
