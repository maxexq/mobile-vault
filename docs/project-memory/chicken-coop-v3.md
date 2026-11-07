---
name: chicken-coop-v3
description: MV-630 chicken coop (pen) room v3, option C tyre pen APPROVED + saved, L1-L3 + 3 egg stages (code-drawn) + anim + hotspots fmt 2, Done; page Chicken Coop v3
metadata:
  type: project
  modified: 2026-10-30T13:01:03.482Z
---

2026-10-30 Parames: "ทำคอกเลี้ยงไก่ L1-L3 ขอตัวอย่าง 3 ห้อง ตาม Guide v3 (ในห้องไม่มีไก่ ...)". Read as 3 design options, each with full L1-L3. Plane MV-630. From [[new-rooms-10-ideas]] #1 (pen).
- 12:54 Parames PICKED option C (tyre pen) + asked for 3 egg stages: none / a few / crate full. Now In Review.
- 2026-10-30 13:03 Parames "เซฟ" = APPROVED: saved to pen_v3/approved/ (art, stages, hotspots.json, anim GIFs, README). Plane MV-630 Done.
- Folder /mnt/project-files/designs/room-redesign-preview/pen_v3/: gen_pen3.py <A|B|C> <seed>, edit_pen3.py <opt> L2|L3 <seed> (opt C3 = L3 with "keep every object where it is" lock), eggs_pen3.py (code eggs 3x4 px in SPOTS per level, s3 superset of s2 + heap TOP over basket; 0 gens), anim_pen3.py (idle/working/powerout at stage 3 + eggs loop with glint; hens hen_brown/hen_white/rooster walk+peck, plant_grower keeper route nest->basket->feed->water; emergency_light), hotspots_pen3.py (format 2, room "pen", new actions collect_eggs/feed_hens/water_hens/dust_bath -> add to tools/hotspots.py ACTIONS in the repo PR), page_pen_v3.html, plane_mv.py.
- Final files final/pen_L{1,2,3}.png + pen_L{n}_stage{1,2,3}.png + hotspots.json. Sources: L1 out/pen3_C_7_0, L2 pen3_C_L2_s1_0, L3 pen3_C3_L3_s3_0 (first L3 rearranged the room).
- inpaint-v3 eggs tried once (10 gens): eggs unreadable, looked like straw -> code eggs instead.
- Unpicked A crate coop / B pallet hen house still on the page for comparison.
- Gens: 120 total (L1 30 generate-image-v2, L2/L3 60 + L3 redo 20 edit-images-v2, 10 inpaint-v3), balance 4289 -> 4169.
- Page https://claude.ai/artifact/Ddfdvw9yrxRvMJQfZk1rUS v2 (publish from the scratchpad copy pen_site/; publishing straight from /mnt/project-files failed with "source file changed"), card on index v49.
**How to apply:** not in game yet (waits for [[world-v2-scale-plan]]). Hens are characters, never baked into the art. Related: [[room-guide-v3]], [[pets-preview]], [[room-hotspots]], [[room-v3-emergency-light]].
