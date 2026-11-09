---
name: pets-v3-ingame
description: MV-733 approved realistic pets (MV-601, 9 breeds, walk only) in the v3 room cells via PetsV3/PetV3Actor, switch pets_v3, branch mv-733-pets-v3
metadata:
  type: project
  modified: 2026-11-09T16:22:18.560Z
---

2026-11-09 Parames: "เพิ่มสัตว์ v ใหม่ที่ทำไว้ เข้าเกม". Only approved animal set = [[pets-preview]] approved-realistic (MV-601); no newer v3 animal set exists. Plane MV-733, branch mv-733-pets-v3 (base staging).
- tools/pets_v3_import.py: 64x64 canvas cut at (16,30)-(48,54) -> assets/v3/pets/<breed>.png, 32x24 frames (0 still, 1-8 walk), feet bottom centre, + assets/v3/pets.json (kinds dog/cat/hen -> 3 breeds each, speed).
- Drawn 1:1 in room px (art was made at room scale, NOT crew 2/3). Small pixel contact shadow x crew_v3.shadow; dim = RoomV3Cell.DARK in power-out.
- PetsV3 (static) assigns each Game.s.pets index to a built main-body room for 14-32 s (tune pets_v3.stay), prefers rooms with crew; every RoomV3Cell (world v2 body + v3 interior) polls pets_in(slot) each 0.5 s. Old PetActor layer hidden when world v2 + pets_v3.
- Breed: pet "breed" key > STORY names (ข้าวตัง mutt, ส้มจี๊ด ginger, ไข่ดาว brown hen; adoption events now carry breed) > name hash. Game bonuses still by kind (rooster = hen).
- GOD crew tab: dog/cat/hen give next breed not aboard, "ครบ 9 พันธุ์" (Dev.pets_v3_all), "ย้ายห้อง" (Dev.pets_v3_hop). Autotest --only=pets_v3.
- Not done: sit/sleep/idle clips for the realistic set (approved set is walk only).
