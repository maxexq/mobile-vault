---
name: library-room-v3
description: MV-644 library & classroom (ห้องสมุด & ห้องเรียน) v3 L1-L3 (Claude picks), anim + hotspots fmt 2 (room "library", 5 new actions), APPROVED + saved (library_v3/approved/), Done; page Library & Classroom v3
metadata:
  type: project
---

2026-10-30 Parames: "ทำห้องสมุด & ห้องเรียน ตาม Guide v3 เลือกห้องเองได้เลย" (reserve idea in [[new-rooms-10-ideas]]: train INT, decode lore logbooks, unlock blueprints). Plane MV-644 (id 3afa6629-4b9a-457d-9d12-25b841c36dbf) Done. 15:56 Parames "เซฟ" = APPROVED, saved to library_v3/approved/ (README there).
- Zones left -> right: book shelves | filing cabinet + blackboard + student bench/desks (back wall, classroom) | study desk with logbooks + blueprint board (L3: drafting lightbox, microfiche reader, projector screen, decoded logbook shelf).
- Folder /mnt/project-files/designs/room-redesign-preview/library_v3/: gen_lib3.py A <seed>, inp_lib3.py <seed> (inpaint-v3: every L1 candidate had a door-like panel left of the board -> filing cabinet; "blackboard made from a painted door" in the prompt causes doors, avoid that wording), edit_lib3.py L2|L3 <seed>, anim_lib3.py (retired_teacher talks then chalks a new line, teen_tinkerer + office_worker listen flipped, scientist decodes at desk, blueprint/lightbox blue pulse = unlock; power-out: teacher holds candle, L3 baked-lit screens darkened via "dead" rects; emergency_light; crew_blend), hotspots_lib3.py (NEW actions read_books, teach_class, attend_class, decode_logbook, unlock_blueprint -> add to tools/hotspots.py ACTIONS in repo PR), page_library_v3.html, plane_mv.py.
- Picks: L1 A_7_2 + inpaint s1, L2 lib3_L2_s1_0, L3 lib3_L3_s2_0 (L3 s1 job 500'd while polling). No gamma, luma 44/42/40. final/lib_L{1,2,3}.png + hotspots.json.
- Page https://claude.ai/artifact/EPBN8K8v8PwV4p6LtYukTh (scratchpad library_site/), card on index v56.
**How to apply:** if Parames approves ("เซฟ"), copy finals + anim + hotspots + README to library_v3/approved/ and move MV-644 to Done. Not in game yet (waits for [[world-v2-scale-plan]]). Related: [[room-guide-v3]], [[room-hotspots]], [[room-v3-emergency-light]], [[crew-room-blend]].
