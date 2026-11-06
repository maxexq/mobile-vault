---
name: dr-ren-25d-redraw
description: MV-655 Dr. Ren redraw in 2.5D side view, 10 options R-01..R-10 at 64 canvas (~60 px), artifact Dr. Ren 2.5D Redraw, awaiting pick
metadata:
  type: project
  modified: 2026-10-30T18:11:14.335Z
---

2026-10-30 (Plane MV-655, Needs Decision): Parames "ใช้ pl วาดหมอ ren ใหม่ เป็น 2.5D side view ความละเอียดชัดขึ้นมา 10 แบบ".
- Recipe: /mnt/project-files/designs/dr-ren-25d/gen.py <key> <seed> = Pro generate-image-v2 64x64 (16 imgs, 10 gens/call). ref1 = Dr. Ren A (crew-anim-fix/dr_ren/raw/A_1.png) face+hair, ref2 = soldier idle (2.5D stance), style = armory L3. Works first try; stance is 3/4-ish side with staggered feet.
- 10 concepts (keys): field, cryo, cape, surgeon, plague, driver, genius, combat, woke, scav. Picks R-01..R-10 in picks/ (+ _room.png in armory L3). page.py + tpl.html build index.html.
- Artifact: https://claude.ai/artifact/GoVV1kccUA9HgaxV6KyRBH
- Size: figures ~60 px vs crew ~38 px; after pick, shrink via PixelLab /resize (see [[crew-v2-detail]]) or move crew to bigger size.
- Spend: 100 gens own (10 calls), balance 12576 -> 12446 (130 incl. other threads).
Related: [[dr-ren-lore]], [[dr-ren-ambulance]].
- 18:23 Parames: "ทำ idle Field Doctor" (= R-01 picked for idle). idle.py <seed> <frames> = POST /animate-with-text-v3, first+last = picks/R01_field.png, 1 gen/call. Takes idle/s1_8 (twists, too much), s2_16, s3_16 (calmest, recommended). idle_gif.py -> idle/gif/*.gif + room_*.gif (drop last frame, 16f @10fps). Artifact v2 top section. Awaiting pick.
- 18:31 Parames: walk for field doctor. walk.py (normal wording, walk/s1-3) + walk_b.py (long-stride wording, walk/b4-6), animate-with-text-v3 8f, first+last = R01 still, 6 gens. Gotcha: anchoring both ends on the standing still keeps strides short; some takes add a brown hip bag mid-loop (b4, s2). Recommended W-2 = walk/b5_8. walk_gif.py -> walk/gif (+ room walk-across with flip). Artifact v3. If stride still too short: make a mid-stride key pose first (edit-image) and animate from it.
- 19:22 Parames: work/eat/drink/hammer/talk clips. act.py <key> <seed> <frames> [p] (animate-with-text-v3 12f). Gotcha: from the empty-hand still, props never appear and hammer never strikes. Fix = pose.py <key> <seed> (edit-image-pro-flash, 5 gens) makes a prop-holding key pose (act/pose/*_1.png), then act.py ... p animates first+last = that pose -> act/<key>_{1,2}p. Talk uses the plain still (act/talk_1,2). act_gif.py -> act/gif. Artifact v4. Total 38 gens (10 first pass + 20 poses + 8). Awaiting picks.
