---
name: room-merged-widths
description: Parames rule 2026-10-29: v2 merged rooms are 296 px (2 rooms) and 448 px (3 rooms), i.e. rooms + the 8 px walls they absorb
metadata:
  type: feedback
  modified: 2026-10-29T23:11:50.050Z
---

2026-10-29 23:11 Parames (MV-609 thread): use 296 and 448 for merged 2 and 3 rooms.
Vehicle v2 floor: 144 px rooms, 8 px I-beam walls between rooms (wall option 2, out/wall2_s3_0.png), one 16 px ladder shaft at the rear (wall option 5), so the floor width never changes when rooms merge: 1 room 144, merged 2 = 144*2+8 = 296, merged 3 = 144*3+16 = 448. All 96 tall.
**Why:** a merged room takes over the space of the walls it removes.
**How to apply:** new merged gens use one-point guides at 296x96 / 448x96 (armory/guide.py). Older approved merged rooms (kitchen, grow, infirmary, water) were drawn at 288/432: widen 4/8 px per side in code first, regen only if it looks wrong. Spec doc "Room creation spec v2" + repo docs/art/room-style-reference-v2.md must say 296/448. Related: [[armory-redesign]], [[room-camera-one-point]], [[pixellab-room-gen-rules]], [[world-v2-scale-plan]].
