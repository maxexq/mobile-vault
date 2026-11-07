---
name: saloon-v3
description: MV-627 saloon (bar/morale room) per Room guide v3, L1-L3 single cell, Claude picked all, In Review; files saloon_v3/, page Saloon v3
metadata:
  type: project
---

2026-10-30 Parames: "make the Saloon per V3 guide, L1-L3 only, pick yourself". Plane MV-627 (In Review).
- Folder /mnt/project-files/designs/room-redesign-preview/saloon_v3/: gen_sal3.py <A|B|C> <seed> (science pattern: armory guide.png + armory L1 shabby style), edit_sal3.py L2|L3 <seed> [src] (both from L1, TONE clause), anim_sal3.py (biker bartender pours at keg then talks at counter (66,87); gunslinger walks in, talks, drinks at (102,89); keg tap drip; L1/L2 battery radio glow survives power-out; L3 orange neon BAR + jukebox chase die in power-out; emergency_light.py; crew_blend), hotspots_sal3.py (format 2, room "saloon"), plane_mv.py, page_saloon_v3.html (page source; assets under sal3/).
- Picks: L1 = out/sal3_A_7_1 (painted BAR sign, keg on crate, door-on-oil-drums counter, bucket stools, cable-spool card table, dartboard, battery radio; A_0/A_2 had back-wall doors, C fridge too bright), L2 = sal3_L2_s2_0 (s1 had a shovel + harsh lamp cone), L3 = sal3_L3_s2_0 (s1 neon read "EAR"). final/saloon_L{1,2,3}.png + hotspots.json.
- Mean luma 41/39/37 (a bit darker than kitchen v3 47-49, intended dim bar, warm).
- NEW hotspot actions serve_drink, play_cards, play_darts, play_music -> add to tools/hotspots.py ACTIONS in the repo PR.
- 70 gens (L1 30, edits 4x10), balance 4492 -> 4422. Page https://claude.ai/artifact/3TT89Xdh5KkNL8ygomYRyf, card on index v47. Asset log group room-v3-saloon (19 images incl. L1-L3 copies).
**How to apply:** not in game yet (waits for [[world-v2-scale-plan]]); rerun scripts to change. Related: [[room-guide-v3]], [[science-room-v3]], [[room-sample-pages]], [[room-hotspots]], [[room-v3-emergency-light]].
