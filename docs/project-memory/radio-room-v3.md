---
name: radio-room-v3
description: MV-623 radio room per Room guide v3 (one-point, single cell L1-L3, anim, hotspots fmt 2 with new action use_radio), Claude picked all, In Review; files radio_v3/
metadata:
  type: project
  modified: 2026-10-30T10:33:54.852Z
---

2026-10-30 Parames (project chat): make science room, radio room, refinery, workshop per Guide v3, L1-L3 only, "pick yourself". This note = radio room. Plane MV-623 (In Review).
- Folder /mnt/project-files/designs/room-redesign-preview/radio_v3/: gen_radio3.py <A|B|C> <seed> (generate-image-v2, armory guide.png + L1 shabby style), edit_radio3.py L2|L3 <seed> [src], anim_radio3.py (idle CB scan / working: aviator_pilot talks on CB mic with red TX LED + voice bars, teen_tinkerer works at left bench / powerout: emergency_light.py, L3 radio amber standby), hotspots_radio3.py (format 2), plane_mv.py.
- Picks: L1 = out/rad3_C_7_0.png (CB radio on crate desk, tube receiver + morse key bench on oil drums, battery bank + fuse box, antenna cable up right). L2 = rad3_L2_s2_0 (s1 had a baked orange lamp glow, no map). L3 = rad3_L3_s1_0 (s2 cold blue-grey, off-tone). final/radio_L{1,2,3}.png + hotspots.json (room "radio").
- NEW hotspot action use_radio (CB = main station): add to tools/hotspots.py ACTIONS in the repo PR.
- 70 gens (L1 30, edits 10 each x4). Page "Radio Room v3 Samples" https://claude.ai/artifact/EUP1ZVNoMff3Ao7EWTThse (source in that session's scratchpad; read before republishing), card on index v43. Asset log group room-v3-radio (16 images).
**How to apply:** rerun scripts for changes; not in game yet (waits for [[world-v2-scale-plan]]). Related: [[room-guide-v3]], [[infirmary-v3]], [[room-v3-emergency-light]], [[room-sample-pages]].
