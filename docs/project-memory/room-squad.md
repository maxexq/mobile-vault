# Squad fights from the rear gunner room (MV-727)

2026-11-08 Parames: "เอาระบบยิงบนหลังคาและท้ายรถออก เป็นยิงออกจากห้อง rear gunner room แทน (สร้าง default ไว้ท้ายรถ 1 ห้อง)",
"เงื่อนไขของห้องคือสร้างได้แค่ห้องเดียว และสร้างได้แค่ห้องที่อยู่ท้ายรถ ไม่ว่าจะเป็นชั้นไหน",
"ทำระบบ squad ใหม่ให้เหมาะสมกับระบบห้อง rear gunner".

- Switch `room_squad` (on). Squad = crew of the rear gunner room, slots opened by Mobile Vault level like before
  (Lv1 gunner + loader, Lv2 + spotter). Everyone shoots their own weapon from the room; GUNNER (AGI) + turret part +
  barrage, LOADER (STR) fire rate + grenade stun every 9 s (old slam), SPOTTER (INT) crit + range. Matches the room's
  hotspot actions man_gun / load_ammo / spot_targets.
- First plan said room level opens slots; changed to Vault level because the room squad otherwise failed the warlord /
  roaming-boss benches. Room level = damage x1 / 1.4 / 1.9.
- Enemies only hit the hull, x gunner.hull_take 0.2 (melee x gunner.melee_take 0.5 more), tuned on the MV-550 + MV-544
  benches. Roof heroes, rear-wall turret shots, roof auto-turret mod and the deck reserve card are gone in room mode;
  the turret part is the gun mounted in the hatch.
- One gunner room per vehicle, rear column of the main body only, any floor (trailers don't count as the rear).
- Saves without a gunner room keep the old roof squad until they build one.
