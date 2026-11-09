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


# =================================================================== MV-727: the squad fights from this room
## Switch `room_squad` (Parames 2026-11-08): no more roof crew, rear-wall turret or roof turret. The defence squad is the
## crew of the rear gunner room, and it fights from inside it:
##  * everyone fires their own weapon + gear (Combat.hero_stats) out of the room, x the room level multiplier.
##  * slot 0 GUNNER (AGI) mans the mounted gun: + the vehicle's turret part (the gun in the hatch) and the barrage.
##  * slot 1 LOADER (STR): everyone fires faster; every 9 s a grenade out of the hatch (150 %, 1.5 s stun at the rear).  * slot 2 SPOTTER (INT): everyone gets more crit and range.
##  * the Mobile Vault level opens the slots as before (Lv1 gunner + loader, Lv2 + spotter). Squad members work in the room
##    (d.room = the room), so the room view shows them; leaving the room leaves the squad and the other way round.
##  * enemies can't reach anyone inside: every attack hits the hull. A save without a built gunner room keeps the
##    old roof squad until one is built (Combat.room_mode()).
## Build rules (switch `gunner_room`): only one gunner room, and only in a rear slot (main body, rear column, any floor).

const ROOM_ROLES := [
	{"id": "gunner", "th": "มือปืน", "en": "GUNNER", "stat": "agi", "unlock": 1, "cd": 10.0,
		"skill": "ระดมยิง", "skill_desc": "ทุก 10 วิ ยิงรัว 5 นัด (70% ดาเมจ) ใส่ศัตรูแบบสุ่ม"},
	{"id": "loader", "th": "คนส่งกระสุน", "en": "LOADER", "stat": "str", "unlock": 1, "cd": 9.0,
		"skill": "ระเบิดมือ", "skill_desc": "ป้อนกระสุนให้ทุกคนยิงเร็วขึ้นตาม STR · ทุก 9 วิ ปาระเบิดออกช่องยิง 150% ดาเมจใส่ศัตรูท้ายรถ + มึน 1.5 วิ"},
	{"id": "spotter", "th": "คนชี้เป้า", "en": "SPOTTER", "stat": "int", "unlock": 2, "cd": 0.0,
		"skill": "ชี้เป้า", "skill_desc": "ทุกคนในห้องคริติคอลและระยะยิงเพิ่มตาม INT"},
]


static func squad_on() -> bool:
	return on() and Features.on("room_squad")


## the gunner room the squad fights from: the first built one (-1 = none yet)
static func post() -> int:
	var r := rooms()
	return int(r[0]) if not r.is_empty() else -1


static func room_mode() -> bool:
	return squad_on() and post() >= 0


static func post_level() -> int:
	var p := post()
	return clampi(int(Game.s.rooms[p].get("level", 1)), 1, 3) if p >= 0 else 0


## squad slots: the Mobile Vault level opens them, as before (Lv1 gunner + loader, Lv2 + spotter)
static func roles_open() -> int:
	var n := 0
	for r in ROOM_ROLES:
		if int(Game.s.vault_level) >= int(r.unlock):
			n += 1
	return n


## a rear slot: main body, rear column (the vehicle faces left, so column 2), any floor
static func is_rear_slot(slot: int) -> bool:
	if Game.s.is_empty() or slot < 0 or slot >= Game.main_slots():
		return false
	return Game.slot_cell(slot).x == Data.ROOMS_PER_FLOOR - 1


## why a gunner room can't go into `slot` ("" = it can)
static func build_block(slot: int) -> String:
	if not on():
		return ""
	for i in (Game.s.rooms as Array).size():
		if i != slot and str(Game.s.rooms[i].type) == TYPE:
			return Loc.t("ห้องยิงท้ายรถสร้างได้ห้องเดียว")
	if not is_rear_slot(slot):
		return Loc.t("ห้องยิงสร้างได้เฉพาะช่องท้ายรถ")
	return ""


## the build menus hide the card once the room exists
static func can_build_any() -> bool:
	if not on() or Game.s.is_empty():
		return true
	for r in Game.s.rooms:
		if str(r.type) == TYPE:
			return false
	return true


## keeps the squad and the room's crew the same people (cheap; called from the combat tick and on squad edits)
static func sync_squad() -> bool:
	if not room_mode():
		return false
	var p := post()
	var n := roles_open()
	var changed := false
	var sq: Array = Game.s.squad
	for i in sq.size():
		var did := int(sq[i])
		if did < 0:
			continue
		var d := Game.dweller_by_id(did)
		if d.is_empty() or Game.is_away(d) or i >= n:
			sq[i] = -1
			if not d.is_empty() and int(d.room) == p:
				d.room = -1
			changed = true
		elif int(d.room) != p:
			d.room = p                 # the squad post wins (Game.assign takes people off the squad when it sends them elsewhere)
			changed = true
	# anyone put to work in the room takes the first free squad slot (or leaves if it is full)
	for d in Game.s.dwellers:
		if int(d.room) != p or Game.is_away(d) or Game.squad_role(d) >= 0:
			continue
		var free := -1
		for i in n:
			if int(sq[i]) < 0:
				free = i
				break
		if free >= 0:
			sq[free] = int(d.id)
		else:
			d.room = -1
		changed = true
	return changed


## what each squad member fires from the room: {i: {did, dmg, aspd, range, splash, crit, critd, aa, dps}}.
## Everyone shoots their own weapon (Combat.hero_stats, gunner formula) x the room level. The GUNNER mans the mounted
## gun: + the vehicle's turret part (damage, splash, anti-air). A LOADER makes every shooter fire faster, a SPOTTER
## gives every shooter more crit and range.
static func shooters() -> Dictionary:
	var out := {}
	if not room_mode():
		return out
	var n := roles_open()
	var crew := {}
	for i in mini(n, (Game.s.squad as Array).size()):
		var did := int(Game.s.squad[i])
		var d := Game.dweller_by_id(did) if did >= 0 else {}
		if not d.is_empty() and not Game.is_away(d):
			crew[i] = d
	var aspd_k := 1.0
	if crew.has(1):
		aspd_k += Features.num("gunner.loader_aspd", 0.15) + Features.num("gunner.loader_str", 0.03) * float(crew[1].get("str", 5))
	var crit_add := 0.0
	var range_k := 1.0
	if crew.has(2):
		crit_add = Features.num("gunner.spot_crit", 5.0) + Features.num("gunner.spot_int", 1.0) * float(crew[2].get("int", 5))
		range_k = 1.0 + Features.num("gunner.spot_range", 0.15)
	var vs: Dictionary = Combat.van_stats()
	var mult := float(LEVEL_MULT[post_level()])
	for i in crew:
		var st: Dictionary = Combat.hero_stats(crew[i], 0)
		if bool(st.get("melee", false)):
			st.dmg = float(st.dmg) / 0.6 * Features.num("gunner.melee_k", 1.4)   # a melee fighter takes the spare gun, as hard as the old bruiser
		var g := {"did": int(crew[i].id), "dmg": float(st.dmg), "aspd": float(st.aspd) * aspd_k, "range": maxf(float(st.range), range_px()),
			"splash": int(st.splash), "crit": float(st.crit) + crit_add, "critd": float(st.critd), "aa": false}
		if int(i) == 0:
			g.dmg = float(g.dmg) + float(vs.turret_dmg)
			g.range = maxf(float(g.range), float(vs.turret_range))
			g.splash = maxi(int(g.splash), int(vs.turret_splash))
			g.aa = bool(vs.get("aa", false))
		g.dmg = float(g.dmg) * mult
		g.range = float(g.range) * range_k
		g.dps = float(g.dmg) * float(g.aspd) * (1.0 + minf(100.0, float(g.crit)) / 100.0 * (float(g.critd) - 100.0) / 100.0) * (1.0 + 0.5 * (int(g.splash) - 1))
		out[int(i)] = g
	return out


## the mounted gun (the GUNNER's entry) or {} with nobody on it
static func gun_stats() -> Dictionary:
	return shooters().get(0, {})


static func squad_dps() -> float:
	var t := 0.0
	for g in shooters().values():
		t += float(g.dps)
	return t
