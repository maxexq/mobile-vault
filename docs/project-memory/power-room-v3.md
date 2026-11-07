---
name: power-room-v3
description: MV-634 battery & switchboard (power) room v3 L1-L3 (Claude picks), anim + hotspots fmt 2 (room "power"), APPROVED + saved (power_v3/approved/), Done; page Battery & Switchboard v3
metadata:
  type: project
  modified: 2026-10-30T13:35:52.546Z
---

2026-10-30 Parames: "ห้องแบตเตอรี่ & สวิตช์บอร์ด L1-L3 ตาม Guide v3 เลือกห้องเองได้เลย". From [[new-rooms-10-ideas]] #7 (power). Plane MV-634 Done. 13:36 Parames "เซฟ" = APPROVED, saved to power_v3/approved/ (art, hotspots.json, anim GIFs, README).
- Zones left -> right: pedal generator bike (L3 flywheel generator) + charge controller/inverter box | switchboard on back wall (power-out order) | battery bank.
- Folder /mnt/project-files/designs/room-redesign-preview/power_v3/: gen_pow3.py A <seed> (quar pattern; prompt must stay < 2000 chars or API 422), edit_pow3.py L2|L3 <seed>, anim_pow3.py (teen_tinkerer works the generator facing it, bus_mechanic flips breakers then checks batteries; L3 fan spins via rotated crop; battery LEDs march when charging, red low blink in power-out; controller amber survives power-out because pedalling = manual power; emergency_light; crew_blend), hotspots_pow3.py, page_power_v3.html, plane_mv.py, plane_id.txt.
- Picks: L1 out/pow3_A_11_1 (no doors), L2 pow3_L2_s2_0, L3 pow3_L3_s2_0; L2/L3 gamma lifted 0.9/0.85 in code (came out 34/32 luma) -> 40/41/41. final/power_L{1,2,3}.png + hotspots.json.
- NEW hotspot actions pedal_generator, set_power_priority, check_batteries -> add to tools/hotspots.py ACTIONS in the repo PR. Generator has no needs_power (usable in power-out).
- 60 gens (generate-image-v2 2x10, edit-images-v2 4x10), balance 3979 -> 3919.
- Page https://claude.ai/artifact/NSmTSvkKaHtMTSWieutz7k (published from scratchpad pow_site/), card on index v53.
**How to apply:** not in game yet (waits for [[world-v2-scale-plan]]). Related: [[room-guide-v3]], [[room-hotspots]], [[room-v3-emergency-light]], [[crew-room-blend]].
