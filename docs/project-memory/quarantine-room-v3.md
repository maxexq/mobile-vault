---
name: quarantine-room-v3
description: MV-631 quarantine & decon room v3 L1-L3 (Claude picks), one room with human side + animal side, anim + hotspots fmt 2, APPROVED + saved (quar_v3/approved/), Done; page Quarantine & Decon v3
metadata:
  type: project
  modified: 2026-10-30T13:16:00.354Z
---

2026-10-30 Parames: "ห้องกักโรค & ล้างรังสี L1-L3 ตาม Guide v3 เลือกห้องเองได้เลย" + 13:08 "ต้องมีส่วนของคน และสัตว์ในห้องเดียว" (one room must hold a human section AND an animal section). From [[new-rooms-10-ideas]] #2. Plane MV-631 Done. 13:20 Parames "เซฟ" = APPROVED, saved to quar_v3/approved/ (art, hotspots.json, anim GIFs, README).
- Zones left -> right: human isolation bed behind plastic -> shared decon wash station + hazmat suit -> animal cages + animal wash tub + feed.
- Folder /mnt/project-files/designs/room-redesign-preview/quar_v3/: gen_quar3.py A <seed> (saloon pattern), edit_quar3.py L2|L3 <seed>, anim_quar3.py (medic tends bed then scrubs dog_mutt at the animal tub with spray; hunter hosed at decon (L2/L3 shower water); geiger amber clicks survive power-out; L3 green heart monitor dies; emergency_light; crew_blend; dog = pets-preview approved-realistic walk frames), hotspots_quar3.py (room "quarantine"; new actions decontaminate, quarantine_animal, wash_animal, scan_radiation -> add to tools/hotspots.py ACTIONS in the repo PR), page_quarantine_v3.html, plane_mv.py.
- Picks: L1 out/quar3_A_11_2, L2 quar3_L2_s2_0 (s1 lamp cone hid the radiation sign), L3 quar3_L3_s2_0 (s1 lost the decon cubicle). final/quarantine_L{1,2,3}.png + hotspots.json. Mean luma 46/41/45.
- 60 gens (generate-image-v2 2x10, edit-images-v2 4x10), balance 4169 -> 4109.
- Page https://claude.ai/artifact/7DuWYt4WyhjDEdzcCCDtEf (published from scratchpad copy), card on index v50.
**How to apply:** not in game yet (waits for [[world-v2-scale-plan]]). Animals are characters, never baked into the art. Related: [[room-guide-v3]], [[chicken-coop-v3]], [[room-hotspots]], [[room-v3-emergency-light]].
