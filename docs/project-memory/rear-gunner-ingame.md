---
name: rear-gunner-ingame
description: MV-716 rear gunner post in the game as the default rear room (RoomX rear_gunner, switch gunner_room), crew shoot chasers from the rear hatch
metadata:
  type: project
---

2026-11-08 Parames: "เพิ่มห้องนี้ในเกม เป็นห้อง default ท้ายรถ" (the MV-705 rear gunner room v3). Plane MV-716. Branch
mv-716-gunner-room stacked on mv-715-ambulance-v3 (PR #196, itself on #193) to avoid layout conflicts with the
ambulance / world v2 work (that thread owns vehicle.gd, interior_v3_panel.gd, main.gd; this one game.gd new-game layout + data).
- Design decision 2026-11-03 (Parames): turrets dropped, combat = crew shooting from inside rooms. This is the first such room.
- `scripts/rooms/rear_gunner.gd` (RearGunner): RoomX DEFS "rear_gunner" (unlock 1, 160 scrap, AGI, 0.2 power, feature
  gunner_room). Each worker = one gun: dmg (gunner.dmg 4 + gunner.dmg_agi 0.6*AGI) x level [1,1.4,1.9] x 1.12^(enemy lvl-1),
  gunner.aspd 1/s, range gunner.range 240 x RANGE_SCALE. Combat._tick_room_guns, shot kind "room_gun" (CombatView muzzle at
  room x59 y26 of 64x52), GUN_X 340. Manual gun: fires in a power-out. Combat.active() also runs with only gunners.
- Default layout (switch on): slot 2 (ground floor, rear column = enemy side) rear_gunner, slot 0 water (Clara), slot 1 kitchen.
  Nobody on the gun at start. Old saves untouched.
- Art: tools/art/rooms_x/room_rear_gunner.png (64x52 box-downscale of v3 L1, palette-mapped without green ramps) +
  fx_room_gunner_flash_0..3 (6x5 at 56,24, RoomAnim kind "firing"); inserted with NEW tools/atlas_insert.py (adds only named
  regions to the committed atlas; full generate_pixel_art.py is NOT byte-reproducible and rewrites bg/events).
- v3: tools/v3_import.py ROOMS rear_gunner (status approved, idle from gunner3_L%d_idle_room.gif = crew-free render via
  NOCREW=1 anim_gunner3.py), CLIPS + "shoot"; CrewV3Actor plays "shoot" at hotspots with action man_gun.
- GOD รถ → ROOM EXPANSION → ห้องยิง (Dev.gunner_demo, Dev.gunner_level_up). Autotest --only=gunner_room.
Related: [[rear-gunner-v3]], [[ambulance-v3-ingame]], [[rooms-crew-v3-ingame]].
