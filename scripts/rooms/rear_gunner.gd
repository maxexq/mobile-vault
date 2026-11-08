class_name RearGunner
extends RefCounted
## Rear gunner post (MV-716, art MV-705): the room at the back of the vehicle where the crew shoot the monsters and
## bosses chasing it through a firing hatch in the rear wall. Turrets are on their way out (Parames 2026-11-03: the
## crew fight from inside the rooms), so this is the first room that fights: every crew member working here fires
## the room's gun at the closest enemy in range, as part of the normal Combat tick.
##  * a RoomX expansion room (single cell, levels 1..3, two workers), registered in RoomX.DEFS under its own switch
##    `gunner_room`. The gun is manual: it keeps firing in a power-out, never while the room is being built.
##  * damage per gunner = (gunner.dmg + gunner.dmg_agi x AGI) x level multiplier x enemy-level growth (the same 1.12
##    per level the gear and the roof turret use), one shot every 1 / gunner.aspd seconds, range gunner.range.
##  * new games start with it in the rear slot of the ground floor (slot 2, Game.setup_default_state) while the
##    switch is on; the water purifier moves to the front slot. Old saves keep their layout.
##  * Combat runs while anyone is on a gun even with an empty defence squad (Combat.active).
##  * art: 64x52 room_rear_gunner + fx_room_gunner_flash strip (old world / build menu), v3 set rear_gunner
##    (assets/v3, L1-L3 + idle + hotspots, tools/v3_import.py) for the v3 view and world v2.
## GOD → รถ → ห้องยิงท้ายรถ. Autotest --only=gunner_room.

const TYPE := "rear_gunner"
const DEFAULT_SLOT := 2          # ground floor, rear column (vehicle faces left, enemies come from the right)
const LEVEL_MULT := [1.0, 1.0, 1.4, 1.9]


static func on() -> bool:
	return Features.on("gunner_room")


static func base_dmg() -> float:
	return Features.num("gunner.dmg", 4.0)


static func aspd() -> float:
	return Features.num("gunner.aspd", 1.0)


static func range_px() -> float:
	return Features.num("gunner.range", 240.0) * Combat.RANGE_SCALE


## the crew member's damage per shot from a gunner room at `level`
static func shot_dmg(d: Dictionary, level: int) -> float:
	var lv := clampi(level, 1, 3)
	var growth := pow(1.12, maxf(0.0, float(Combat.enemy_level()) - 1.0))
	return (base_dmg() + Features.num("gunner.dmg_agi", 0.6) * float(d.get("agi", 5))) * float(LEVEL_MULT[lv]) * growth


## built gunner rooms (never a construction site)
static func rooms() -> Array:
	var out := []
	if Game.s.is_empty() or not on():
		return out
	for i in (Game.s.rooms as Array).size():
		if str(Game.s.rooms[i].type) == TYPE and Game.is_slot_unlocked(i) and not Game.is_site(i):
			out.append(i)
	return out


## who is on the gun in this room
static func gunners(slot: int) -> Array:
	if not on() or Game.s.is_empty() or slot < 0 or slot >= (Game.s.rooms as Array).size():
		return []
	if str(Game.s.rooms[slot].type) != TYPE or Game.is_site(slot):
		return []
	return Game.room_workers(slot)


## every gun that can fire now: [{slot, did, dmg}]
static func guns() -> Array:
	var out := []
	for slot in rooms():
		var lv := int(Game.s.rooms[slot].get("level", 1))
		for d in gunners(slot):
			out.append({"slot": slot, "did": int(d.id), "dmg": shot_dmg(d, lv)})
	return out


static func dps() -> float:
	var t := 0.0
	for g in guns():
		t += float(g.dmg) * aspd()
	return t


## true while the room's crew are shooting at something (RoomAnim "firing" + the v3 view)
static func firing(slot: int) -> bool:
	return not Combat.enemies.is_empty() and not gunners(slot).is_empty()
