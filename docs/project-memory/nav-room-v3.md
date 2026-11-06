---
name: nav-room-v3
description: MV-632 navigation room (ห้องนำทาง) per Room guide v3, L1-L3 single cell, APPROVED 2026-10-30 + saved nav_v3/approved/, Done; files nav_v3/, page Navigation Room v3
metadata:
  type: project
---

- 13:26 Parames "เซฟ" = APPROVED: saved to nav_v3/approved/ (art, hotspots, GIFs, README). Plane MV-632 Done.
2026-10-30 Parames: "ทำห้องนำทาง L1-L3 ตาม Guide v3 เลือกห้องเองได้เลย" ([[new-rooms-10-ideas]] #3 nav). Plane MV-632 (In Review).
- Folder /mnt/project-files/designs/room-redesign-preview/nav_v3/: gen_nav3.py <A|B|C> <seed> (saloon pattern), edit_nav3.py L2|L3 <seed> [src], anim_nav3.py (aviator_pilot plots at chart table (70,86), old_fisherman at periscope/gauges (118,89); L2 amber gauge lamps, L3 radar sweep + blinking map pins + lit table; power-out = navigator keeps plotting by flashlight, emergency_light), hotspots_nav3.py (format 2, room "nav", NEW actions plot_route + scout_road -> add to tools/hotspots.py ACTIONS in the repo PR), plane_mv.py.
- Picks: L1 out/nav3_A_7_1 (A_7_0 no gauges, A_7_2/3 back-wall doors), L2 nav3_L2_s1_0 (red string routes), L3 nav3_L3_s1_0 (s2 table glowed bright cyan). final/nav_L{1,2,3}.png + hotspots.json + GIFs. Luma 47/41/42.
- 70 gens (generate-image-v2 30, edit-images-v2 40), balance 4109 -> 4039.
- Page https://claude.ai/artifact/Py28ukYCJnBuLMv14C7oBP (source scratchpad nav_site/, copy nav_v3/page_nav_v3.html), card on index v51.
**How to apply:** not in game yet (waits for [[world-v2-scale-plan]]). Related: [[room-guide-v3]], [[saloon-v3]], [[room-hotspots]], [[room-v3-emergency-light]], [[crew-room-blend]].
