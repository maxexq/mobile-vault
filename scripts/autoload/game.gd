extends Node
## Core simulation: resources, rooms, dwellers, travel, biomes, weather, events, idle/offline progress.
## `s` is the active vehicle (JSON-friendly); the save wraps it with the persistent account (Account,
## envelope v2). Views listen to signals and read `s`.

signal resources_changed
signal rooms_changed
signal dwellers_changed
signal travel_changed
signal biome_changed(index: int, instant: bool)
signal weather_changed(weather: String)
signal vault_level_changed(level: int)
signal event_triggered(event_id: String)
signal toast(text: String, kind: String)
signal floating_text(slot: int, text: String, icon: String)
signal game_started
signal gear_changed
signal squad_changed
signal pets_changed
## v4.3 construction sites. kind = "build" (new room) or "upgrade"
signal construction_started(slot: int, kind: String)
signal construction_finished(slot: int, kind: String)

const AUTOSAVE_SEC := 15.0

var s: Dictionary = {}
var started := false
## UI modes that freeze the road (management mode / pending event)
var closeup_slot := -1
var active_event := ""
var _autosave_t := 0.0
var _float_acc: Dictionary = {}    # "slot:res" -> accumulated amount for floating "+N"
var rng := RandomNumberGenerator.new()
var _offline_built: Array = []     # room names finished while away (for the welcome-back toast)
var sim_offline := false           # MV-244: the current simulation step is offline catch-up


func _ready() -> void:
	rng.randomize()
	Save.flush_requested.connect(save_game)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()


# =================================================================== lifecycle
func new_game() -> void:
	setup_default_state()
	if not Features.on("persistent_account"):
		Account.a = {}      # switch off: NEW RUN starts over from nothing, as before the account
	Account.attach(s)
	# the main vehicle always plays standard at the account's difficulty; pending rules = test / balance runs
	s.mode = Modes.take_pending() if not Modes.pending.is_empty() else Account.main_mode()
	started = true
	save_game()
	game_started.emit()
	_emit_all(true)
	toast.emit("ยินดีต้อนรับสู่ Apocarlypse! แตะที่ห้องเพื่อจัดการ ปัดซ้าย-ขวาเพื่อดูถนน", "info")
	if Modes.id() != "standard" or Modes.diff() != "normal" or not Modes.mutators().is_empty():
		toast.emit("โหมด: " + Modes.label(), "biome")


## fresh state (also used as the live backdrop behind the title screen)
func setup_default_state(keep_meta: bool = false) -> void:
	var meta: Dictionary = s.get("meta", {}) if keep_meta else {}
	var tier_id: String = str(s.get("tier", "van")) if keep_meta else "van"
	s = {
		"version": 1, "route_v": 2, "slots_v": 5, "tier": tier_id, "trailers": 0, "pets": [], "outage": {},
		"vault_level": 1,
		"res": {"power": 60.0, "water": 50.0, "food": 50.0, "scrap": 150.0, "fuel": 30.0, "crops": Data.START_RAW.crops, "meat": Data.START_RAW.meat},
		"items": {"stimpack": 2, "radaway": 1, "ammo": 5},
		"km": 0.0, "biome": 0, "lap": 0,
		"traveling": true, "hull": 100.0, "stall": 0.0,
		"tod": 0.32, "weather": "rain", "weather_t": 70.0,
		"event_t": 50.0, "recruit_t": 180.0,
		"rooms": [], "dwellers": [], "next_id": 1,
		"solar": {"panels": 1, "battery": 1, "tracking": false, "dirt": 0.15},
		"stats": {"events": 0, "km_total": 0.0},
		"saved_at": Time.get_unix_time_from_system(),
		"gear": [], "van_gear": {"turret": null, "plating": null, "engine": null, "spikes": null},
		"squad": [-1, -1, -1], "deck": -1, "next_uid": 1, "pity": {"epic": 0, "legend": 0},
		"combat": {"wave": 1, "best": 1, "push": true, "boss_beaten": {}, "kpm": 0.0, "kills": 0, "auto_salvage": -1, "threat": 0.0, "raid_kpm": 0.0, "fight_share": 0.3},
		"mods": {}, "exp": {}, "at_site": "", "sites_done": {}, "memorial": [], "generator": true,
		"cab": {"type": "engine", "level": 1, "job": {}, "build": {}}, "engine": EngineBay.default_state(),
		"mode": Modes.DEFAULT.duplicate(true),
	}
	if not meta.is_empty():
		s.meta = meta
	for i in slot_count():
		s.rooms.append({"type": "empty", "level": 1, "job": {}, "build": {}})
	s.rooms[1].type = "kitchen"
	s.rooms[2].type = "water"
	if keep_meta:
		# a new generation starts with three fresh volunteers (+ the veterans the caller adds)
		for i in 3:
			var d := recruit_random()
			d.lvl = 1 + Meta.generation() / 2
		s.dwellers[0].room = Data.CAB_SLOT
		s.dwellers[1].room = 1
		s.van_gear.turret = Loot.roll_item("turret", 1, 0, "mg_turret")
		s.items["components"] = 20
		s.squad = [-1, int(s.dwellers[2].id), -1]
		return
	var mark := _add_dweller({"name": "จ่ามาร์ค", "lore": "mark", "variant": "dw_army_brown", "str": 7, "int": 3, "agi": 4, "room": -1, "lvl": 3})
	var leo := _add_dweller({"name": "ลีโอ", "lore": "leo", "variant": "dw_scav_brown", "str": 4, "int": 3, "agi": 7, "room": -1, "lvl": 2})
	_add_dweller({"name": "ต้น", "lore": "ton", "variant": "dw_jumpsuit_black", "str": 6, "int": 4, "agi": 3, "room": Data.CAB_SLOT, "lvl": 1, "role": "builder"})
	_add_dweller({"name": "เชฟบ็อบ", "lore": "bob", "variant": "dw_chef_gray", "str": 3, "int": 4, "agi": 7, "room": 1, "lvl": 2})
	_add_dweller({"name": "พยาบาลคลารา", "lore": "clara", "variant": "dw_medic_red", "str": 3, "int": 7, "agi": 4, "room": 2, "lvl": 2})
	# starter defence squad + gear (common)
	s.squad = [int(leo.id), int(mark.id), -1]
	leo.gear = {"weapon": Loot.roll_item("weapon", 1, 0, "hunting_rifle"), "backpack": Loot.roll_item("backpack", 1, 0, "school_bag")}
	mark.gear = {"weapon": Loot.roll_item("weapon", 1, 0, "pipe_wrench"), "armor": Loot.roll_item("armor", 1, 0, "leather_jacket"), "helmet": Loot.roll_item("helmet", 1, 0, "hard_hat")}
	s.van_gear.turret = Loot.roll_item("turret", 1, 0, "mg_turret")
	s.items["components"] = 20


func load_game() -> bool:
	var u := Account.unwrap(Save.read())
	if u.is_empty() or not (u.main as Dictionary).has("rooms"):
		return false
	Account.a = u.account
	s = u.main
	Account.attach(s)
	_migrate()
	started = true
	# Cloud.now() is the server clock once the cloud has answered, so a moved phone clock can't fake time away
	var now := Cloud.now()
	var elapsed := offline_elapsed(float(s.get("saved_at", now)), now, Cloud.server_seen if Features.on("anticheat") else 0.0)
	Trace.rec("save", "loaded save", {"away_sec": int(elapsed), "bytes": JSON.stringify(s).length()})
	game_started.emit()
	if elapsed > 30.0:
		_offline_progress(minf(elapsed, Data.OFFLINE_CAP_SEC * Modes.mul("offline")))
	_emit_all(true)
	if Account.take_mode_notice():
		toast.emit("ตอนนี้ทุกคนเล่นด้วยไอดีถาวรแล้ว ขบวนของคุณกลับสู่โหมดเอาชีวิตรอด (ความยากเดิม) ของทุกอย่างยังอยู่ครบ", "biome")
	return true


## seconds away for the offline catch-up (MV-174). saved_at sits in the save, which the player can edit, so
## once the cloud has answered, the time the server last accepted a save (server_seen, 0 = unknown) caps it:
## moving saved_at back can't make the trip longer than the server saw. A save that is newer than the last
## upload (played offline) keeps its own, shorter time.
static func offline_elapsed(saved_at: float, now: float, server_seen: float = 0.0) -> float:
	var away := maxf(0.0, now - saved_at)
	if server_seen > 0.0:
		away = minf(away, maxf(0.0, now - server_seen))
	return away


func _migrate() -> void:
	# make old saves forward compatible (missing keys get defaults)
	var pre_combat := not s.has("squad")
	if not s.get("mode") is Dictionary:
		s["mode"] = Modes.DEFAULT.duplicate(true)     # saves before game modes = a standard run
	# route v2 inserted TOXIC BAYOU before the tundra and added SIGNAL METROPOLIS at the end
	if int(s.get("route_v", 1)) < 2:
		if int(s.get("biome", 0)) >= 3:
			s.biome = int(s.biome) + 1
			s.km = float(s.km) + 9.0
		if s.has("combat") and s.combat.has("boss_beaten") and s.combat.boss_beaten.has("3"):
			s.combat.boss_beaten.erase("3")
			s.combat.boss_beaten["4"] = true
		s["route_v"] = 2
	s.merge({"stall": 0.0, "stats": {"events": 0, "km_total": 0.0}, "lap": 0, "gear": [], "next_uid": 1,
		"van_gear": {"turret": null, "plating": null, "engine": null, "spikes": null}, "squad": [-1, -1, -1]}, false)
	for i in (s.squad as Array).size():
		s.squad[i] = int(s.squad[i])    # JSON round-trip turns the ids into floats
	_free_away_squad()
	s.merge({"combat": {}}, false)
	(s.combat as Dictionary).merge({"wave": 1, "best": 1, "push": true, "boss_beaten": {}, "kpm": 0.0, "kills": 0, "auto_salvage": -1, "threat": 0.0, "raid_kpm": 0.0, "fight_share": 0.3}, false)
	# MV-378: the biome came back from JSON as a float, so beaten checkpoints were stored as "2.0" while
	# boss_beaten() looks up "2": the warlord respawned forever. Re-key them as whole numbers.
	s.biome = int(s.get("biome", 0))
	s.lap = int(s.lap)
	var beaten := {}
	for k in (s.combat.boss_beaten as Dictionary):
		if s.combat.boss_beaten[k]:
			beaten[str(int(float(str(k))))] = true
	s.combat.boss_beaten = beaten
	for d in s.dwellers:
		d.merge({"rads": 0.0, "away_until": 0.0, "xp": 0.0, "happy": 70.0}, false)
		if not d.has("gear"):
			d["gear"] = {}
			# v1 saves stored a single weapon/armor id -> convert into gear items
			for field in ["weapon", "armor"]:
				var old: String = str(d.get(field, ""))
				old = {"leather_armor": "leather_jacket", "combat_armor": "riot_gear"}.get(old, old)
				if old != "" and Loot.BASES.has(old):
					d.gear[field] = Loot.roll_item(field, 3, 1, old)
		d.erase("weapon")
		d.erase("armor")
	for old_id in ["pipe_pistol", "hunting_rifle", "assault_rifle", "leather_armor", "combat_armor"]:
		var n := int(s.items.get(old_id, 0))
		var base_id: String = {"leather_armor": "leather_jacket", "combat_armor": "riot_gear"}.get(old_id, old_id)
		for k in n:
			s.gear.append(Loot.roll_item(Loot.BASES[base_id].slot, 3, 1, base_id))
		s.items.erase(old_id)
	if pre_combat:
		# saves from before the combat update: two survivors join as the defence squad
		var g1 := _add_dweller({"name": "ลีโอ", "lore": "leo", "variant": "dw_scav_brown", "str": 4, "int": 3, "agi": 7, "lvl": 2})
		var g2 := _add_dweller({"name": "บรูโน่", "lore": "bruno", "variant": "dw_army_black", "str": 7, "int": 3, "agi": 4, "lvl": 2})
		g1.gear.weapon = Loot.roll_item("weapon", 1, 0, "hunting_rifle")
		g2.gear.weapon = Loot.roll_item("weapon", 1, 0, "pipe_wrench")
		g2.gear.armor = Loot.roll_item("armor", 1, 0, "leather_jacket")
		s.squad = [int(g1.id), int(g2.id), -1]
		s.van_gear.turret = Loot.roll_item("turret", 1, 0, "mg_turret")
		s.items["components"] = int(s.items.get("components", 0)) + 20
		toast.emit("อัปเดตใหม่: ระบบต่อสู้! ลีโอและบรูโน่เข้าร่วมเป็นทีมป้องกันรถบ้าน (เมนู Squad)", "biome")
	for r in s.rooms:
		r.merge({"job": {}, "level": 1, "build": {}}, false)
	# v3: fuel, exterior/interior mods, expeditions, prestige; three rooms per floor
	s.merge({"mods": {}, "exp": {}, "at_site": "", "sites_done": {}, "memorial": [], "generator": true}, false)
	(s.res as Dictionary).merge({"fuel": 30.0}, false)
	# MV-247: raw food (crops + meat) for the kitchen; old saves get the same starting stock as a new game
	(s.res as Dictionary).merge(Data.START_RAW, false)
	_migrate_v4()
	while s.rooms.size() < slot_count():
		s.rooms.append({"type": "empty", "level": 1, "job": {}, "build": {}})
	for d in s.dwellers:
		d.merge({"skills": {}, "infection": 0.0}, false)
		# v4.3: roles. Ton always was the one fixing things on board
		if not d.has("role"):
			d["role"] = "builder" if str(d.get("lore", "")) == "ton" else ""
	for r in s.rooms:
		r.merge({"build": {}}, false)
	_migrate_cab()
	_fix_large_rooms()


## v4.6: the engine room moved from slot 0 into the cab (Data.CAB_SLOT / s.cab). Slot 0 becomes a free cell;
## the room's level and up to two of its crew come along, the rest go idle.
func _migrate_cab() -> void:
	if not s.has("cab"):
		var old: Dictionary = s.rooms[Data.ENGINE_SLOT] if s.rooms.size() > Data.ENGINE_SLOT else {}
		var lv := 1
		if str(old.get("type", "")) == "engine":
			lv = int(old.get("level", 1))
			s.rooms[Data.ENGINE_SLOT] = {"type": "empty", "level": 1, "job": {}, "build": {}}
			var n := 0
			for d in s.dwellers:
				if int(d.room) == Data.ENGINE_SLOT:
					d.room = Data.CAB_SLOT if n < Data.CAB_WORKERS else -1
					n += 1
		s["cab"] = {"type": "engine", "level": lv, "job": {}, "build": {}}
		(s.get("outage", {}) as Dictionary).erase(str(Data.ENGINE_SLOT))
	(s.cab as Dictionary).merge({"type": "engine", "level": 1, "job": {}, "build": {}}, false)
	s.merge({"engine": EngineBay.default_state()}, false)
	(s.engine as Dictionary).merge(EngineBay.default_state(), false)
	s["slots_v"] = maxi(5, int(s.get("slots_v", 5)))


## the room record at `slot`; the cab's engine room (Data.CAB_SLOT) lives outside the grid in s.cab
func room(slot: int) -> Dictionary:
	if slot == Data.CAB_SLOT:
		return s.get("cab", {})
	if slot < 0 or slot >= s.rooms.size():
		return {}
	return s.rooms[slot]


func has_room(slot: int) -> bool:
	return not s.is_empty() and (slot == Data.CAB_SLOT or (slot >= 0 and slot < s.rooms.size()))


## v4.4: an annex cell must sit right of its room (a hand-edited / imported save could break that);
## crew always work on the anchor cell
func _fix_large_rooms() -> void:
	for i in s.rooms.size():
		if not is_annex(i):
			continue
		var a := room_anchor(i)
		if is_annex(a) or not str(s.rooms[a].type) in Data.MERGEABLE or room_cells(a).size() > Data.MAX_SPAN:
			s.rooms[i] = {"type": "empty", "level": 1, "job": {}, "build": {}}
	for d in s.dwellers:
		if int(d.room) >= 0 and int(d.room) < s.rooms.size():
			d.room = room_anchor(int(d.room))


## v4: vehicle tiers + trailers. Saves made before tiers drive the 18-wheeler (rig); the old
## MK-II/III chassis becomes the armoured train. Slots are renumbered floor*3+column.
func _migrate_v4() -> void:
	if int(s.get("slots_v", 0)) >= 4:
		s.merge({"tier": "van", "trailers": 0, "pets": [], "outage": {}}, false)
		return
	var ch := int(s.get("chassis", 1))
	s["tier"] = "rig" if ch <= 1 else "train"
	s.erase("chassis")
	s.merge({"trailers": 0, "pets": [], "outage": {}}, false)
	var old: Array = s.rooms
	var remap := {}
	var fresh := []
	for i in Data.ROOMS_PER_FLOOR * 4:
		fresh.append({"type": "empty", "level": 1, "job": {}})
	for i in old.size():
		if i >= Data.V3_SLOT_CELL.size():
			continue
		var cell: Array = Data.V3_SLOT_CELL[i]
		if int(cell[1]) >= 4:
			continue      # rooms on the removed 5th/6th floor are lost (their crew becomes idle)
		var ni := int(cell[1]) * Data.ROOMS_PER_FLOOR + int(cell[0])
		fresh[ni] = old[i]
		remap[i] = ni
	s.rooms = fresh
	for d in s.dwellers:
		var r := int(d.get("room", -1))
		if r >= 0:
			d.room = remap.get(r, -1)
	if s.get("pet", false):
		s.pets = [{"kind": "dog", "name": "ข้าวตัง"}]
	var mm: Dictionary = s.get("meta", {})
	if not mm.is_empty():
		var perks: Dictionary = mm.get("perks", {})
		if perks.has("chassis2") or perks.has("chassis3"):
			perks["tier_train"] = 1
		perks.erase("chassis2")
		perks.erase("chassis3")
		perks["tier_bus"] = 1
		perks["tier_rig"] = 1
		var bps: Array = mm.get("blueprints", [])
		for pair in [["bp_chassis2", "bp_bus"], ["bp_chassis3", "bp_rig"]]:
			if bps.has(pair[0]):
				bps.erase(pair[0])
				if not bps.has(pair[1]):
					bps.append(pair[1])
	s["slots_v"] = 4


func save_game() -> void:
	if not started:
		return
	_flush_sim()       # MV-113: the time collected for the next sim step goes into the save too
	s.saved_at = Cloud.now()
	Save.write(Account.envelope(s))


func reset_game() -> void:
	Save.wipe()
	started = false
	s = {}


func _emit_all(instant: bool) -> void:
	resources_changed.emit()
	rooms_changed.emit()
	dwellers_changed.emit()
	travel_changed.emit()
	biome_changed.emit(s.biome, instant)
	weather_changed.emit(s.weather)
	vault_level_changed.emit(s.vault_level)


func _offline_progress(sec: float) -> void:
	var before := (s.res as Dictionary).duplicate()
	var km0: float = s.km
	var step := 10.0
	var t := 0.0
	while t < sec:
		_simulate(step, true)
		t += step
	var parts := []
	for k in ["food", "water", "power", "scrap"] + (Data.RAW_KEYS if Data.raw_food() else []):
		var dv: float = s.res[k] - before[k]
		if absf(dv) >= 1.0:
			parts.append("%s %+d" % [Data.item_name(k), int(dv)])
	parts.append("เดินทาง %.1f กม." % (s.km - km0))
	if not _offline_built.is_empty():
		parts.append("ก่อสร้างเสร็จ: " + ", ".join(_offline_built))
		_offline_built.clear()
	var cr := Combat.offline_rewards(sec)
	if not cr.is_empty():
		parts.append("ทีมป้องกันกำจัดศัตรู %d ตัว (+%d XP)" % [cr.kills, cr.xp])
	toast.emit("ระหว่างที่คุณไม่อยู่ %d นาที: %s" % [int(sec / 60.0), ", ".join(parts)], "info")


## MV-113: the economy doesn't need every rendered frame (its rates are per minute), and at 120 fps it would run twice
## as often as at 60. With fixed_sim on, frame time is collected and a step runs perf.sim_hz times a second, the
## world half and the crew half on alternate steps (each with all the time collected for it: fast-forward and long
## frames work as before), so no frame pays for the whole economy. Off = everything once per frame, as before.
const SIM_HZ := 20.0
var sim_ms := {"world": 0.0, "crew": 0.0}     # the last step of each half (GOD / FPS overlay)
var sim_steps := {"world": 0, "crew": 0}      # live steps run so far (autotest)
var _acc_world := 0.0
var _acc_crew := 0.0
var _acc_step := 0.0
var _crew_next := false


func _process(delta: float) -> void:
	if not started:
		return
	if not Features.on("fixed_sim"):
		_flush_sim()
		_simulate(delta, false)
	else:
		_acc_world += delta
		_acc_crew += delta
		_acc_step += delta
		if _acc_step >= 1.0 / Features.num("perf.sim_hz", SIM_HZ):
			_acc_step = 0.0
			if _crew_next:
				_sim_crew(_acc_crew, false)
				_acc_crew = 0.0
			else:
				_sim_world(_acc_world, false)
				_acc_world = 0.0
			_crew_next = not _crew_next
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_SEC:
		_autosave_t = 0.0
		save_game()


# =================================================================== derived values
func cap(res: String) -> float:
	var lv: int = s.vault_level
	match res:
		"power": return (100.0 + 80.0 * float(s.solar.battery - 1) + 20.0 * lv) * (1.0 + Mods.val("storage_racks"))
		"scrap": return float(Data.SCRAP_CAP[clampi(lv, 1, Data.MAX_VAULT_LEVEL)])
		"fuel": return Env.fuel_cap()
		_: return (80.0 + 40.0 * lv) * (1.0 + Mods.val("storage_racks"))


func pop_cap() -> int:
	var c := Data.BASE_POP_CAP
	for i in s.rooms.size():
		c += room_beds(i)
	return c


## beds a room adds to pop_cap: finished living quarters only (a building site gives none)
func room_beds(slot: int) -> int:
	if slot < 0 or slot >= s.rooms.size() or s.rooms[slot].type != "quarters" or is_site(slot):
		return 0
	return int(round(4.0 * float(s.rooms[slot].level) * room_scale(slot)))


## MV-420: beds left if this living quarters went away (demolish; a split passes the beds its single rooms keep),
## or -1 when that is fine. Not fine = the crew would outnumber the beds left.
func beds_short(slot: int, keep: int = 0) -> int:
	var lose := room_beds(room_anchor(slot)) - keep
	if lose <= 0:
		return -1
	var left := pop_cap() - lose
	return left if s.dwellers.size() > left else -1


## beds the single rooms of a split would give
func split_beds(slot: int) -> int:
	var a := room_anchor(slot)
	if s.rooms[a].type != "quarters":
		return 0
	return room_cells(a).size() * int(round(4.0 * float(s.rooms[a].level)))


func beds_short_text(left: int) -> String:
	return Loc.t("ห้องพักไม่พอ: ลูกเรือ %d คน จะเหลือที่นอน %d ที่ (สร้างห้องพักอื่นก่อน)") % [s.dwellers.size(), left]


# ------------------------------------------------------------------ vehicle tier / layout
func tier() -> String:
	return str(s.get("tier", "van")) if not s.is_empty() else "rig"


func vehicle_def() -> Dictionary:
	return Data.VEHICLES.get(tier(), Data.VEHICLES.van)


func floors() -> int:
	return int(vehicle_def().floors)


func trailers() -> int:
	return clampi(int(s.get("trailers", 0)), 0, Data.MAX_TRAILERS) if not s.is_empty() else 0


## main body slots: slot = floor * 3 + column
func main_slots() -> int:
	return Data.ROOMS_PER_FLOOR * floors()


func slot_count() -> int:
	return main_slots() + Data.TRAILER_SLOTS * trailers()


## which unit a slot belongs to: -1 = main body, 0/1 = trailer index
func slot_unit(slot: int) -> int:
	return -1 if slot < main_slots() else (slot - main_slots()) / Data.TRAILER_SLOTS


## (column, floor) inside its unit
func slot_cell(slot: int) -> Vector2i:
	var local := slot if slot < main_slots() else (slot - main_slots()) % Data.TRAILER_SLOTS
	return Vector2i(local % Data.ROOMS_PER_FLOOR, local / Data.ROOMS_PER_FLOOR)


func unlocked_slots() -> Array:
	var n: int = Data.SLOTS_PER_LEVEL[clampi(s.vault_level, 0, Data.MAX_VAULT_LEVEL)]
	n = mini(n, main_slots() - 1)
	var arr: Array = [Data.ENGINE_SLOT]
	for i in n:
		arr.append(i + 1)
	for i in range(main_slots(), slot_count()):
		arr.append(i)       # trailer rooms are open as soon as the trailer is hitched
	return arr


## vault level a room type becomes buildable (legacy perk "early_rooms" = one level earlier)
func room_unlock_level(t: String) -> int:
	var lv := int(Data.room_def(t).unlock) - Meta.perk("early_rooms")
	var bp: String = Data.room_def(t).get("bp", "")
	if bp != "" and not Meta.has_blueprint(bp):
		return 99
	return maxi(1, lv)


## MV-113: checked for every room many times a tick; unlocked_slots() builds a new array each call, so the set is
## kept until what it depends on (vault level, body size, room count) changes
var _unl_key := -1
var _unl := {}


func is_slot_unlocked(slot: int) -> bool:
	if slot == Data.CAB_SLOT:
		return true
	var key := int(s.vault_level) * 1000000 + main_slots() * 1000 + slot_count()
	if key != _unl_key:
		_unl_key = key
		_unl.clear()
		for i in unlocked_slots():
			_unl[int(i)] = true
	return _unl.has(slot)


func weather_def() -> Dictionary:
	return Data.WEATHER.get(s.weather, Data.WEATHER.clear)


func sun_level() -> float:
	return clampf(sin((float(s.tod) - 0.25) * TAU), 0.0, 1.0)


func is_night() -> bool:
	return sun_level() <= 0.02


func solar_output_pm() -> float:
	var sol: Dictionary = s.solar
	var sun := sun_level()
	if sol.tracking:
		sun = sqrt(sun)
	var panels: float = 1.0 + 0.25 * float(sol.panels - 1)
	return 20.0 * panels * sun * minf(1.0, float(weather_def().solar) * Env.solar_mult()) * (1.0 - 0.6 * float(sol.dirt)) * (1.0 - float(sol.get("damage", 0.0)))


func power_flow_pm() -> float:
	var f := solar_output_pm()
	for slot in s.rooms.size():
		var r: Dictionary = s.rooms[slot]
		if r.type == "empty" or not is_slot_unlocked(slot) or is_site(slot):
			continue
		f -= room_power_pm(slot)
		f += float(room_rate_pm(slot).get("power", 0.0))
	if is_moving():
		f -= Data.TRAVEL_POWER_PM
		f += EngineBay.power_pm() - float(EngineBay.burn_pm().get("power", 0.0))
	return f


func hull_max() -> float:
	if s.is_empty() or not s.has("van_gear"):
		return 100.0
	return 100.0 + float(vehicle_def().hull) + float(Combat.van_stats().hull) + Mods.val("armor_plates")


func speed_factor() -> float:
	if not is_moving():
		return 0.0
	var f: float = weather_def().speed * (1.0 + float(Combat.van_stats().speed) / 100.0) * Env.speed_mult() * Haul.speed_mult() * EngineBay.speed_mult()
	if s.hull < 30.0:
		f *= 0.7
	return f


func speed_kmh() -> float:
	return 35.0 * speed_factor()


func is_moving() -> bool:
	return started and s.traveling and blocked_reason() == "" and closeup_slot < 0 and active_event == ""


func blocked_reason() -> String:
	if s.get("wrecked", false):
		return "รถพังถาวร"
	if Expedition.active():
		return "รอทีมสำรวจกลับ %d:%02d" % [int(Expedition.time_left()) / 60, int(Expedition.time_left()) % 60]
	if Expedition.at_site() != "":
		return "จอดที่ %s" % Expedition.site_def(Expedition.at_site()).th
	if s.res.power <= 0.5:
		return "ไฟหมด! ชาร์จแบตก่อนออกรถ"
	if s.hull <= 0.0:
		return "ตัวถังพัง! ซ่อมก่อนเดินทาง"
	if s.stall > 0.0:
		return "จอดรอ %ds" % int(ceil(s.stall))
	if map_mode() and not WorldMap.driving():
		return "เลือกปลายทางบนแผนที่"
	if Inspection.halting():
		return "จอดรับคนแปลกหน้า"
	var eng := EngineBay.blocked_reason()
	if eng != "":
		return eng
	if at_checkpoint():
		if not Combat.boss_beaten(int(s.biome)):
			if s.biome < Data.BIOMES.size() - 1 and s.vault_level < int(Data.biome(s.biome + 1).req):
				return "ด่านตรวจ: ต้องการ Vault Lv.%d + %s" % [Data.biome(s.biome + 1).req, "ค่าผ่านทาง" if Modes.peaceful() else "ปราบบอส"]
			if Modes.peaceful():
				return "ด่านตรวจ: ค่าผ่านทาง %d เศษเหล็ก" % Modes.toll()
			return "ด่านตรวจ: ปราบบอส %s" % Combat.BOSSES[Data.biome(s.biome).id].th
		return "ด่านตรวจ: ต้องการ Vault Lv.%d" % Data.biome(s.biome + 1).req
	return ""


func biome_end_km() -> float:
	return Data.biome_start_km(s.biome + 1)


## at the end of a biome the van stops until the checkpoint warlord is beaten
## (and, except on the last biome, the vault frame is high enough for the next one)
func at_checkpoint() -> bool:
	if not at_checkpoint_spot():
		return false
	return not Combat.boss_beaten(int(s.biome)) or not checkpoint_vault_ok()


## MV-130: the world map is driving this run (switch on and a world exists)
func map_mode() -> bool:
	return Features.on("seeded_world_map") and not WorldMap.world().is_empty()


## the vehicle stands at the checkpoint: the end of the biome on the old road, before a border road on the map
func at_checkpoint_spot() -> bool:
	if map_mode():
		var t := WorldMap.trip()
		return not t.is_empty() and float(t.prog) <= 0.0 and WorldMap.gate_ahead() > 0
	return s.km >= biome_end_km() - 0.001


## the Vault level the way on past this checkpoint needs (99 = none: end of the road)
func checkpoint_req() -> int:
	if map_mode():
		return WorldMap.gate_ahead()
	return 99 if s.biome >= Data.BIOMES.size() - 1 else int(Data.biome(s.biome + 1).req)


func checkpoint_vault_ok() -> bool:
	if not map_mode() and s.biome >= Data.BIOMES.size() - 1:
		return true
	return int(s.vault_level) >= checkpoint_req()


## MV-130: one travel step on the world map: same speed, power, fuel, scrap and road events as the old road
func _drive_map(m: float, dt: float, offline: bool) -> void:
	var km := WorldMap.step(Data.BASE_TRAVEL_KMPM * speed_factor() * m, offline)
	s.km = float(s.km) + km
	s.stats.km_total = float(s.stats.km_total) + km
	_add_res("power", -Data.TRAVEL_POWER_PM * m)
	var burn := EngineBay.burn_pm()
	for k in burn:
		_add_res(k, -float(burn[k]) * m)
	_add_res("scrap", float(Data.biome(s.biome).scrap_pm) * m)
	if not offline:
		_accumulate_float(-1, "scrap", float(Data.biome(s.biome).scrap_pm) * m)
	if at_checkpoint() and not offline:
		if Modes.peaceful() and not Combat.boss_beaten(int(s.biome)):
			toast.emit("ถึงด่านตรวจ! ค่าผ่านทาง %d เศษเหล็ก (จ่ายเองเมื่อมีพอ)" % Modes.toll(), "warn")
		elif not Combat.boss_beaten(int(s.biome)):
			toast.emit("ถึงด่านตรวจ! บอส %s ขวางทางอยู่" % Combat.BOSSES[Data.biome(s.biome).id].th, "warn")
		else:
			toast.emit("ถึงด่านตรวจ! อัปเกรด Mobile Vault เป็น Lv.%d เพื่อไปต่อ" % checkpoint_req(), "warn")
		travel_changed.emit()
	if not offline:
		s.event_t = float(s.event_t) - dt
		if s.event_t <= 0.0:
			var gap_min := Features.num("events.gap_min", EVENT_GAP.x)
			s.event_t = rng.randf_range(gap_min, maxf(gap_min, Features.num("events.gap_max", EVENT_GAP.y)))
			_trigger_random_event()


func danger_level() -> int:
	return int(Data.biome(s.biome).danger) + int(s.lap)


## crew that actually works the room (strikers sit it out). A room still being built has no workers yet:
## the people assigned there are its builders (see site_crew).
func room_workers(slot: int) -> Array:
	var out := []
	if is_site(slot):
		return out
	for d in s.dwellers:
		if int(d.room) == slot and not is_away(d) and not d.get("strike", false) and not Crew.busy(d):
			out.append(d)
	return out


## crew putting up / upgrading the room
func site_crew(slot: int) -> Array:
	var out := []
	for d in s.dwellers:
		if int(d.room) == slot and not is_away(d) and not d.get("strike", false) and not Crew.busy(d):
			out.append(d)
	return out


## everyone physically in the room (incl. strikers) — for the visuals
func room_occupants(slot: int) -> Array:
	var out := []
	for d in s.dwellers:
		if int(d.room) == slot and not is_away(d):
			out.append(d)
	return out


# ------------------------------------------------------------------ power outages
func blackout() -> bool:
	return not s.is_empty() and float(s.res.power) <= 0.5


func room_dark(slot: int) -> bool:
	if s.is_empty():
		return false
	return blackout() or (s.get("outage", {}) as Dictionary).has(str(slot))


func outage_mult(slot: int) -> float:
	if not (s.get("outage", {}) as Dictionary).has(str(slot)):
		return 1.0
	return 0.35 if float(Data.room_def(s.rooms[slot].type).power) > 0.0 else 0.7


## random short circuits: a room goes dark for a while (faster to fix with a mechanic aboard)
func _tick_outages(dt: float, offline: bool) -> void:
	var o: Dictionary = s.get("outage", {})
	for k in o.keys():
		var fix := 1.0
		for d in room_workers(int(k)):
			fix += 1.5 if Crew.has(d, "mechanic") else 0.5
		o[k] = float(o[k]) - dt * fix
		if float(o[k]) <= 0.0:
			o.erase(k)
			if not offline:
				toast.emit("ไฟห้อง%sกลับมาแล้ว" % Data.room_def(s.rooms[int(k)].type).th, "good")
				rooms_changed.emit()
	s["outage"] = o
	if offline or rng.randf() > dt / 420.0:
		return
	var cands := []
	for i in s.rooms.size():
		if not s.rooms[i].type in ["empty", "annex"] and is_slot_unlocked(i) and not o.has(str(i)):
			cands.append(i)
	if cands.is_empty():
		return
	var slot: int = cands[rng.randi() % cands.size()]
	o[str(slot)] = rng.randf_range(50.0, 110.0)
	toast.emit("ไฟช็อต! ห้อง%sมืดสนิท — คนในห้องใช้ไฟฉายซ่อมอยู่" % Data.room_def(s.rooms[slot].type).th, "warn")
	rooms_changed.emit()


func is_away(d: Dictionary) -> bool:
	return float(d.away_until) > 0.0


func squad_role(d: Dictionary) -> int:
	if not s.has("squad"):
		return -1
	# compare as ints: a save loaded from JSON stores the ids as floats, and Array.find()
	# never matches an int against a float, so a squad member could slip out unnoticed
	var did := int(d.id)
	for i in (s.squad as Array).size():
		if int(s.squad[i]) == did:
			return i
	return -1


## anyone out of the vehicle (expedition / exploring) can't hold a defence slot; old saves could keep one
func _free_away_squad() -> void:
	for i in (s.squad as Array).size():
		var did := int(s.squad[i])
		if did < 0:
			continue
		var d := dweller_by_id(did)
		if d.is_empty() or is_away(d):
			s.squad[i] = -1


func set_squad(role: int, did: int) -> void:
	for i in s.squad.size():
		if int(s.squad[i]) == did:
			s.squad[i] = -1
	if did >= 0:
		var d := dweller_by_id(did)
		if d.is_empty() or is_away(d):
			return
		if Crew.refuses(d):
			Crew.refuse_toast(d)
			return
		d.room = -1
	s.squad[role] = did
	squad_changed.emit()
	dwellers_changed.emit()
	rooms_changed.emit()


## roof rest deck (ดาดฟ้า, Mods "roof_deck"): one reserve defender rests up there and jumps in for the
## first squad member who falls in a wave (Combat). Stored as a dweller id in s.deck; working in a room,
## joining the squad, leaving on an expedition or leaving the vehicle takes them off the deck by itself.
func deck_dweller() -> Dictionary:
	if s.is_empty() or Mods.level("roof_deck") <= 0 or not Features.on("roof_deck"):
		return {}
	var did := int(s.get("deck", -1))
	if did < 0:
		return {}
	var d := dweller_by_id(did)
	if d.is_empty() or is_away(d) or int(d.room) >= 0 or squad_role(d) >= 0:
		return {}
	return d


func is_deck(d: Dictionary) -> bool:
	var r := deck_dweller()
	return not r.is_empty() and int(r.id) == int(d.id)


func set_deck(did: int) -> void:
	if did >= 0:
		var d := dweller_by_id(did)
		if d.is_empty() or is_away(d) or Mods.level("roof_deck") <= 0 or not Features.on("roof_deck"):
			return
		var r := squad_role(d)
		if r >= 0:
			s.squad[r] = -1
		d.room = -1
	s["deck"] = did
	squad_changed.emit()
	dwellers_changed.emit()
	rooms_changed.emit()


func idle_dwellers() -> Array:
	var out := []
	for d in s.dwellers:
		if int(d.room) < 0 and not is_away(d) and squad_role(d) < 0 and not is_deck(d):
			out.append(d)
	return out


func dweller_by_id(id: int) -> Dictionary:
	for d in s.dwellers:
		if int(d.id) == id:
			return d
	return {}


func stat_sum(slot: int) -> float:
	var r: Dictionary = s.rooms[slot]
	var st: String = Data.room_def(r.type).get("stat", "str")
	var sum := 0.0
	for d in room_workers(slot):
		sum += float(d[st])
	return sum


func science_boost() -> float:
	var b := 0.0
	for i in s.rooms.size():
		var r: Dictionary = s.rooms[i]
		if r.type == "science" and not room_workers(i).is_empty():
			b += float(Data.ROOMS.science.boost) * float(r.level) * room_scale(i)
	return b


func avg_happiness() -> float:
	if s.dwellers.is_empty():
		return 0.0
	var t := 0.0
	for d in s.dwellers:
		t += float(d.happy)
	return t / s.dwellers.size()


func room_rate_pm(slot: int) -> Dictionary:
	## production per minute for display
	var r: Dictionary = s.rooms[slot]
	var def := Data.room_def(r.type)
	var out := {}
	var workers := room_workers(slot)
	if workers.is_empty() or not def.has("produce"):
		return out
	var lvl_mult := 1.0 + 0.6 * float(r.level - 1)
	var stat_mult := 0.5 * float(work_span(slot)) + stat_sum(slot) / 10.0          # 1 avg worker per cell = 1.0 per cell
	var happy_mult := 0.6 + avg_happiness() / 250.0
	var mult := lvl_mult * stat_mult * span_efficiency(slot) * happy_mult * (1.0 + science_boost()) * Crew.room_mult(slot) * Synergy.room_mult(slot) * Env.prod_mult() * outage_mult(slot)
	if def.get("weather_crop", false):
		mult *= float(weather_def().crop)
	if def.power > 0.0 and s.res.power <= 0.5:
		mult *= 0.15
	var prod := Data.room_produce(r.type)
	for k in prod:
		out[k] = float(prod[k]) * mult
	return out


## MV-247: what a room uses up per minute to make `rate` (raw food on): the kitchen cooks crops / meat
## ("raw", either one) + water into food, hydroponics turns water into crops
func room_inputs_pm(slot: int, rate: Dictionary) -> Dictionary:
	if not Data.raw_food() or rate.is_empty():
		return {}
	var def := Data.room_def(room(slot).type)
	if def.get("cook", false):
		var f := float(rate.get("food", 0.0))
		return {"raw": f / Features.num("food.cook_yield", Data.COOK_YIELD), "water": f * Features.num("food.cook_water", Data.COOK_WATER)}
	if def.has("raw_produce"):
		return {"water": float(rate.get("crops", 0.0)) * Features.num("food.crop_water", Data.CROP_WATER)}
	return {}


func raw_stock() -> float:
	return float(s.res.get("crops", 0.0)) + float(s.res.get("meat", 0.0))


## the share of a room's full output it can make this step: limited by its inputs and by room left in storage
func _input_frac(rate: Dictionary, inputs: Dictionary, m: float) -> float:
	var f := 1.0
	for k in inputs:
		var need: float = float(inputs[k]) * m
		if need > 0.0:
			f = minf(f, (raw_stock() if k == "raw" else float(s.res.get(k, 0.0))) / need)
	for k in rate:
		var make: float = float(rate[k]) * m
		if make > 0.0:
			f = minf(f, maxf(0.0, cap(k) - float(s.res.get(k, 0.0))) / make)
	return clampf(f, 0.0, 1.0)


func _use_inputs(inputs: Dictionary, m: float, f: float) -> void:
	for k in inputs:
		var amt: float = float(inputs[k]) * m * f
		if k != "raw":
			_add_res(k, -amt)
			continue
		# crops and meat are used in proportion to what's stored, so neither piles up untouched
		var tot := raw_stock()
		if tot <= 0.0:
			continue
		for rk in Data.RAW_KEYS:
			_add_res(rk, -amt * float(s.res.get(rk, 0.0)) / tot)


func craft_speed(slot: int) -> float:
	var workers := room_workers(slot)
	if workers.is_empty():
		return 0.0
	var r: Dictionary = s.rooms[slot]
	var sk := 0.0
	for d in workers:
		sk += Skills.val(d, "craft") / workers.size()
	var n := float(work_span(slot))
	return (0.6 + stat_sum(slot) / (12.0 * n)) * (1.0 + 0.5 * (n - 1.0)) * span_efficiency(slot) * (1.0 + 0.25 * float(r.level - 1)) * (1.0 + science_boost()) * (1.0 + sk) * Crew.room_mult(slot) * Synergy.room_mult(slot) * Env.prod_mult() * outage_mult(slot)


func medical_power() -> float:
	var p := 0.0
	for i in s.rooms.size():
		if s.rooms[i].type == "medical" and is_slot_unlocked(i) and not room_workers(i).is_empty():
			p += float(s.rooms[i].level) * Crew.room_mult(i) * room_scale(i)
	return p


func hull_regen_pm() -> float:
	var r := Mods.val("repair_bay")
	for slot in [Data.CAB_SLOT] + _rooms_of("workshop"):
		for d in room_workers(slot):
			r += (2.0 if room(slot).type == "engine" else 1.5) * float(room(slot).level) / 2.0 * (1.0 if slot == Data.CAB_SLOT else span_efficiency(slot))
			if Crew.has(d, "mechanic"):
				r += 1.5
			r += Skills.val(d, "repair")
	return r * Synergy.repair_bonus()


# ------------------------------------------------------------------ acid corrosion / solar damage (mutations)
func corrode(sec: float) -> void:
	var was := float(s.get("corrode", 0.0))
	s["corrode"] = minf(30.0, was + sec)
	if was <= 0.0 and started:
		toast.emit("กรดกัดเกราะรถ! เกราะลดลง ตัวถังค่อยๆ ผุ — ช่างในห้องเครื่อง/อู่ซ่อมช่วยล้างได้", "warn")


func damage_solar(amount: float) -> void:
	var sol: Dictionary = s.solar
	var was := float(sol.get("damage", 0.0))
	sol["damage"] = minf(0.8, was + amount)
	if was < 0.2 and float(sol.damage) >= 0.2 and started:
		toast.emit("ซอมบี้ปีกหนังจิกแผงโซลาร์พัง! ไฟฟ้าลดลง — ติดปืนต่อสู้อากาศยาน หรือให้มือปืนหลังคาจัดการ", "warn")


func _tick_corrosion(m: float) -> void:
	var c := float(s.get("corrode", 0.0))
	if c > 0.0:
		var clean := 1.0 + hull_regen_pm() * 0.15
		s.hull = maxf(0.0, float(s.hull) - 2.0 * m)
		s.corrode = maxf(0.0, c - 60.0 * m * clean)
	var sol: Dictionary = s.solar
	if float(sol.get("damage", 0.0)) > 0.0:
		sol.damage = maxf(0.0, float(sol.damage) - (0.04 + hull_regen_pm() * 0.006) * m)


func has_pet(kind: String) -> bool:
	for p in s.get("pets", []):
		if str(p.kind) == kind:
			return true
	return false


func _first_quarters() -> int:
	for i in s.rooms.size():
		if s.rooms[i].type == "quarters" and is_slot_unlocked(i) and not is_site(i):
			return i
	return -1


func _rooms_of(t: String) -> Array:
	var out := []
	for i in s.rooms.size():
		if s.rooms[i].type == t and is_slot_unlocked(i) and not is_site(i):
			out.append(i)
	return out


func dweller_power(d: Dictionary) -> float:
	return Combat.hero_power(d)


func armory_bonus() -> float:
	var b := 0.0
	for i in s.rooms.size():
		if s.rooms[i].type == "armory" and not is_site(i):
			b += 2.0 * float(s.rooms[i].level) * room_scale(i)
	return b


# =================================================================== simulation
## one simulation step: the world and the rooms (_sim_world), then the crew, travel and radio (_sim_crew). MV-113:
## with fixed_sim on, Game._process runs the two halves on alternate steps, each with the time collected for it, so no
## single frame pays for the whole economy; offline catch-up and the switch off run both at once.
func _simulate(dt: float, offline: bool) -> void:
	_sim_world(dt, offline)
	_sim_crew(dt, offline)


## run whatever each half still has waiting (fixed_sim switched off mid-way, or before a save)
func _flush_sim() -> void:
	if _acc_world > 0.0:
		_sim_world(_acc_world, false)
	if _acc_crew > 0.0:
		_sim_crew(_acc_crew, false)
	_acc_world = 0.0
	_acc_crew = 0.0


func _sim_world(dt: float, offline: bool) -> void:
	var t0 := Time.get_ticks_usec()
	Synergy.sim_begin()
	_sim_world_body(dt, offline)
	Synergy.sim_end()
	if not offline:
		sim_ms.world = float(Time.get_ticks_usec() - t0) / 1000.0
		sim_steps.world += 1


func _sim_world_body(dt: float, offline: bool) -> void:
	sim_offline = offline
	var m := dt / 60.0     # minutes
	if started:
		Account.add_sim_time(dt)
	var res: Dictionary = s.res
	# --- time of day & weather
	s.tod = fmod(float(s.tod) + dt / Data.DAY_LENGTH_SEC, 1.0)
	s.weather_t = float(s.weather_t) - dt
	if s.weather_t <= 0.0:
		_roll_weather()
	var wd := weather_def()
	var dirt := float(wd.dirt)
	if Mods.level("solar_covers") > 0:
		dirt = minf(dirt, 0.0)
	s.solar.dirt = clampf(float(s.solar.dirt) + dirt * m, 0.0, 1.0)
	if s.stall > 0.0:
		s.stall = maxf(0.0, float(s.stall) - dt)

	# --- hazards: heating fuel, generator, radiation, acid, freezing
	Env.tick(dt, offline)
	EngineBay.tick(dt, m, is_moving(), offline)
	# --- hull repair: engine crew (mechanics faster), repair skills, repair bay mod
	if float(s.hull) < hull_max():
		s.hull = minf(hull_max(), float(s.hull) + hull_regen_pm() * m)
	Meta.tick(dt, offline)
	Modes.tick(dt, offline)
	Expedition.tick(offline)
	Inspection.tick(dt, offline)
	RoomX.tick(dt, offline)
	_tick_outages(dt, offline)
	_tick_corrosion(m)
	# --- solar + rain collector + vault engine part
	_add_res("power", (solar_output_pm() + float(Combat.van_stats().power) + EngineBay.power_pm()) * m)
	_add_res("water", float(wd.water) * (1.0 + Mods.val("rain_catcher")) * m)

	# --- rooms
	for slot in s.rooms.size():
		var r: Dictionary = s.rooms[slot]
		if r.type == "empty" or not is_slot_unlocked(slot):
			continue
		if is_site(slot):
			_tick_build(slot, dt, offline)
			continue
		_tick_build(slot, dt, offline)
		var def := Data.room_def(r.type)
		if def.power > 0.0:
			_add_res("power", -room_power_pm(slot) * m)
		var rate := room_rate_pm(slot)
		var inputs := room_inputs_pm(slot, rate)
		var frac := 1.0
		if not inputs.is_empty():
			frac = _input_frac(rate, inputs, m)
			_use_inputs(inputs, m, frac)
		for k in rate:
			var amt: float = rate[k] * m * frac
			_add_res(k, amt)
			if not offline:
				_accumulate_float(slot, k, amt)
		_tick_job(slot, dt, offline)
		if def.has("heal") and not room_workers(slot).is_empty():
			var hm := Crew.room_mult(slot) * room_scale(slot)
			for d in s.dwellers:
				if not is_away(d):
					d.hp = minf(float(d.max_hp), float(d.hp) + float(def.heal) * float(r.level) * hm * m)
					d.rads = maxf(0.0, float(d.rads) - 0.5 * float(r.level) * hm * m)


func _sim_crew(dt: float, offline: bool) -> void:
	var t0 := Time.get_ticks_usec()
	Synergy.sim_begin()
	_sim_crew_body(dt, offline)
	Synergy.sim_end()
	if not offline:
		sim_ms.crew = float(Time.get_ticks_usec() - t0) / 1000.0
		sim_steps.crew += 1


func _sim_crew_body(dt: float, offline: bool) -> void:
	sim_offline = offline
	var m := dt / 60.0     # minutes
	var res: Dictionary = s.res
	# --- dwellers: eat, drink, xp, happiness, explorers
	var present := 0
	var now := Time.get_unix_time_from_system()
	var dwellers_dirty := false
	var eat := 0.0
	var med := medical_power()
	for d in s.dwellers.duplicate():
		if is_away(d):
			if now >= float(d.away_until) and not d.has("exp"):
				_return_explorer(d, offline)
				dwellers_dirty = true
			continue
		present += 1
		eat += Crew.food_mult(d)
		Crew.tick(d, m, med)
	eat *= Modes.mul("eat")
	_add_res("food", -Data.DWELLER_FOOD_PM * eat * m * (0.92 if has_pet("cat") else 1.0))
	if has_pet("hen"):
		_add_res("meat" if Data.raw_food() else "food", 0.6 * m)    # eggs
	_add_res("water", -Data.DWELLER_WATER_PM * eat * Env.water_mult() * m)
	var starving: bool = res.food <= 0.0 or res.water <= 0.0
	var crowded: bool = s.dwellers.size() > pop_cap()
	var has_quarters := false
	for i in s.rooms.size():
		if s.rooms[i].type == "quarters" and not is_site(i):
			has_quarters = true
	# MV-113: everything below is the same for every crew member this tick: work it out once, not per person
	var first_q := _first_quarters()
	var env_base := Env.happy_base()
	var freeze := Env.freeze_power()
	var pets_bonus := 6.0 * minf(2.0, float((s.get("pets", []) as Array).size()))
	var low_food: bool = float(res.food) < cap("food") * 0.1
	var night := is_night()
	var deck_lv := Mods.level("roof_deck")
	var deck_id := int(deck_dweller().get("id", -1))
	var home_mod := {}       # slot -> Synergy.happy_mod
	var mentors := {}        # slot -> [workers] for the mentor bonus
	for d in s.dwellers:
		if is_away(d):
			continue
		if starving:
			d.hp = maxf(1.0, float(d.hp) - 3.0 * m)
		if float(d.rads) > 0.0:
			d.hp = maxf(1.0, float(d.hp) - float(d.rads) * 0.02 * m)
		var target := 45.0 + Crew.happy_aura(d) + env_base
		if freeze > 0.0 and not Crew.has(d, "cold_blooded"):
			target -= 30.0 * freeze
		if Crew.is_infected(d):
			target -= 15.0
		target += pets_bonus
		var home := int(d.room) if int(d.room) >= 0 else first_q
		if home >= 0:
			if not home_mod.has(home):
				home_mod[home] = Synergy.happy_mod(home)
			target += float(home_mod[home])
			if room_dark(home):
				target -= 16.0 if Crew.has(d, "afraid_dark") else 4.0
		elif night and Crew.has(d, "afraid_dark"):
			target -= 8.0
		if crowded:
			target -= 10.0
		if low_food:
			target -= 8.0
		if has_quarters:
			target += 15.0
		if not starving:
			target += 15.0
		var role := squad_role(d)
		if role >= 0:
			target += 20.0 if _best_stat(d) == Combat.ROLES[role].stat else 10.0
			target += 2.0 * deck_lv    # a place to sit down between waves
		elif deck_lv > 0 and int(d.id) == deck_id:
			# the reserve dozes in the open air on the cot: rests up, heals, stays sharp
			target += 16.0 + 3.0 * deck_lv
			d.hp = minf(float(d.max_hp), float(d.hp) + float(d.max_hp) * 0.006 * deck_lv * m)
		elif int(d.room) >= 0:
			var st: String = Data.room_def(room(int(d.room)).type).get("stat", "")
			var xpm := 1.5 * (1.2 if Crew.has(d, "genius") else 1.0)
			if is_constructing(int(d.room)):
				# hauling beams: builds STR, real builders love it
				st = "str"
				if Crew.is_builder(d):
					xpm *= 1.5
					target += 12.0
			target += 20.0 if st != "" and _best_stat(d) == st else 8.0
			var mentor := 0.0     # the best mentor in the room (a large room's crew don't multiply it)
			if not mentors.has(int(d.room)):
				mentors[int(d.room)] = room_workers(int(d.room))
			for o in mentors[int(d.room)]:
				if o != d:
					mentor = maxf(mentor, Skills.val(o, "mentor"))
			xpm *= 1.0 + 2.0 * mentor
			give_xp(d, xpm * m, st, offline)
		d.happy = move_toward(float(d.happy), target, 2.0 * m)
		Crew.morale_tick(d, dt, offline)

	Crew.flush_deserters()
	Crew.morale_v2_global_tick(dt)

	# --- travel
	if is_moving() and map_mode():
		_drive_map(m, dt, offline)       # MV-130: along the world map's roads
	elif is_moving():
		var km: float = Data.BASE_TRAVEL_KMPM * speed_factor() * m
		var end_km := biome_end_km()
		var last: bool = s.biome >= Data.BIOMES.size() - 1
		var next_req: int = 99 if last else int(Data.biome(s.biome + 1).req)
		var site := Expedition.crossed(float(s.km), float(s.km) + km)
		if site != "":
			Expedition.arrive(site)
			if offline:
				Expedition.skip_site()   # nobody there to send a team: drive on
			else:
				toast.emit("พบสถานที่สำคัญ: %s! รถจอด — ส่งทีมสำรวจหรือขับผ่าน" % Expedition.SITES[site].th, "biome")
			km = 0.0
		s.km = float(s.km) + km
		s.stats.km_total = float(s.stats.km_total) + km
		_add_res("power", -Data.TRAVEL_POWER_PM * m)
		var burn := EngineBay.burn_pm()
		for k in burn:
			_add_res(k, -float(burn[k]) * m)
		_add_res("scrap", float(Data.biome(s.biome).scrap_pm) * m)
		if not offline:
			_accumulate_float(-1, "scrap", float(Data.biome(s.biome).scrap_pm) * m)
		if s.km >= end_km:
			if at_checkpoint():
				s.km = end_km
				if not offline:
					if Modes.peaceful() and not Combat.boss_beaten(int(s.biome)):
						toast.emit("ถึงด่านตรวจ! ค่าผ่านทาง %d เศษเหล็ก (จ่ายเองเมื่อมีพอ)" % Modes.toll(), "warn")
					elif not Combat.boss_beaten(int(s.biome)):
						toast.emit("ถึงด่านตรวจ! บอส %s ขวางทางอยู่" % Combat.BOSSES[Data.biome(s.biome).id].th, "warn")
					else:
						toast.emit("ถึงด่านตรวจ! อัปเกรด Mobile Vault เป็น Lv.%d เพื่อไปต่อ" % next_req, "warn")
				travel_changed.emit()
			elif last:
				_finish_lap()
			else:
				s.biome = int(s.biome) + 1
				biome_changed.emit(s.biome, offline)
				if not offline:
					toast.emit("เข้าสู่ %s / %s" % [Data.biome(s.biome).th, Data.biome(s.biome).en], "biome")
		# events
		if not offline:
			s.event_t = float(s.event_t) - dt
			if s.event_t <= 0.0:
				var gap_min := Features.num("events.gap_min", EVENT_GAP.x)
				s.event_t = rng.randf_range(gap_min, maxf(gap_min, Features.num("events.gap_max", EVENT_GAP.y)))
				_trigger_random_event()

	# --- radio recruitment (passive)
	var radio_lvl := 0.0
	for i in s.rooms.size():
		if s.rooms[i].type == "radio" and not room_workers(i).is_empty():
			radio_lvl += float(s.rooms[i].level) * room_scale(i)
	if radio_lvl > 0.0:
		s.recruit_t = float(s.recruit_t) - dt * radio_lvl
		if s.recruit_t <= 0.0:
			s.recruit_t = 240.0
			if s.dwellers.size() < pop_cap():
				var d := offer_recruit("radio")
				if not offline and not d.is_empty():
					toast.emit("วิทยุรับสัญญาณได้! %s ตามมาขึ้นรถ" % d.name, "good")

	if dwellers_dirty:
		dwellers_changed.emit()
	if not offline:
		resources_changed.emit()


func _add_res(k: String, v: float) -> void:
	if not s.res.has(k):
		return
	if k == "fuel" and v > 0.0:
		v *= Modes.mul("fuel_gain")
	s.res[k] = clampf(float(s.res[k]) + v, 0.0, cap(k))


func _accumulate_float(slot: int, k: String, amt: float) -> void:
	var key := "%d:%s" % [slot, k]
	var acc: float = _float_acc.get(key, 0.0) + amt
	var step := 5.0
	if acc >= step:
		var n := int(acc)
		acc -= n
		floating_text.emit(slot, "+%d" % n, Data.item_icon(k))
	_float_acc[key] = acc


func _tick_job(slot: int, dt: float, offline: bool) -> void:
	var r: Dictionary = s.rooms[slot]
	if r.job.is_empty():
		return
	var sp := craft_speed(slot)
	if sp <= 0.0:
		return
	r.job.progress = float(r.job.progress) + dt * sp
	if float(r.job.progress) >= float(r.job.total):
		var rec := _recipe(r.type, r.job.id)
		r.job = {}
		var got := give_rewards(rec.get("out", {}))
		if not offline:
			toast.emit("%s เสร็จแล้ว: %s" % [rec.get("th", ""), got], "good")
			floating_text.emit(slot, "DONE", Data.item_icon((rec.out as Dictionary).keys()[0]))
		rooms_changed.emit()


func _recipe(room_type: String, id: String) -> Dictionary:
	for rec in Data.recipes(room_type):
		if rec.id == id:
			return rec
	# a job started before the raw-food switch flipped still finishes with its own output
	for rec in Data.room_def(room_type).get("recipes", []):
		if rec.id == id:
			return rec
	return {}


func _best_stat(d: Dictionary) -> String:
	var best := "str"
	for st in ["int", "agi"]:
		if float(d[st]) > float(d[best]):
			best = st
	return best


func xp_needed(lvl: int) -> float:
	return 15.0 * lvl + 3.0 * lvl * lvl


func give_xp(d: Dictionary, amount: float, st: String, quiet: bool = false) -> void:
	d.xp = float(d.xp) + amount
	var guard := 0
	while float(d.xp) >= xp_needed(int(d.lvl)) and guard < 50:
		d.xp = float(d.xp) - xp_needed(int(d.lvl))
		_level_up(d, st, quiet)
		guard += 1


func _level_up(d: Dictionary, st: String, offline: bool) -> void:
	d.lvl = int(d.lvl) + 1
	d.max_hp = float(d.max_hp) + 5.0
	d.hp = float(d.max_hp)
	if st != "" and int(d[st]) < 10:
		d[st] = int(d[st]) + 1
	if not offline:
		toast.emit("%s เลเวลอัป! Lv.%d" % [d.name, d.lvl], "good")
		dwellers_changed.emit()


func _roll_weather() -> void:
	var weights: Dictionary = Data.biome(s.biome).weather
	var total := 0
	for k in weights:
		total += int(weights[k])
	var pick := rng.randi_range(1, total)
	var w := "clear"
	for k in weights:
		pick -= int(weights[k])
		if pick <= 0:
			w = k
			break
	s.weather_t = rng.randf_range(60.0, 140.0)
	if w != s.weather:
		s.weather = w
		weather_changed.emit(w)


func force_weather(w: String) -> void:
	s.weather = w
	s.weather_t = 90.0
	weather_changed.emit(w)


func _finish_lap() -> void:
	s.combat.boss_beaten = {}
	s.lap = int(s.lap) + 1
	s.km = 0.0
	s.biome = 0
	if map_mode():
		WorldMap.create(WorldMap.random_seed())    # MV-130: every lap is a new world
	toast.emit("ครบเส้นทาง! เริ่มรอบที่ %d (อันตรายขึ้น ผลตอบแทนมากขึ้น)" % (s.lap + 1), "biome")
	biome_changed.emit(0, false)


# =================================================================== dwellers
func _add_dweller(p: Dictionary) -> Dictionary:
	var d := {
		"id": int(s.next_id), "name": p.get("name", "ผู้รอดชีวิต"), "variant": p.get("variant", "dw_scav_brown"),
		"lvl": p.get("lvl", 1), "xp": 0.0, "str": p.get("str", 4), "int": p.get("int", 4), "agi": p.get("agi", 4),
		"hp": 100.0, "max_hp": 100.0, "happy": 75.0, "room": p.get("room", -1), "gear": {},
		"away_until": 0.0, "rads": 0.0, "lore": p.get("lore", ""), "skills": {}, "infection": 0.0,
		"role": p.get("role", ""),
	}
	Crew.roll_traits(d)
	d.max_hp = 90.0 + 5.0 * float(d.lvl)
	d.hp = d.max_hp
	s.next_id = int(s.next_id) + 1
	s.dwellers.append(d)
	return d


## every stranger who wants to join comes through here: usually an ordinary refugee who boards at once
## (returns the dweller), rarely an exceptional one who waits at the door for inspection (returns {}).
func offer_recruit(source: String, elite_bonus: float = 0.0) -> Dictionary:
	var grade := Inspection.roll_grade(elite_bonus) if Features.on("strangers") else ""
	if grade != "" and Inspection.queue().size() < Inspection.MAX_QUEUE:
		Inspection.queue_candidate(source, grade)
		return {}
	return recruit_random()


func recruit_random() -> Dictionary:
	var stats := {"str": rng.randi_range(2, 6), "int": rng.randi_range(2, 6), "agi": rng.randi_range(2, 6)}
	var best := "str"
	for st in stats:
		if stats[st] > stats[best]:
			best = st
	var outfits: Array = Data.OUTFIT_FOR_STAT[best]
	var outfit: String = outfits[rng.randi() % outfits.size()]
	# some refugees were builders before the fall: hard hat + hi-vis vest, and they show up with their tools
	var role := "builder" if rng.randf() < Crew.BUILDER_CHANCE else ""
	if role == "builder":
		outfit = "builder"
		stats.str = maxi(int(stats.str), 4)
	var variant := "dw_%s_%s" % [outfit, Data.HAIRS[rng.randi() % Data.HAIRS.size()]]
	var nm: String = Data.TITLES.get(outfit, "") + Data.FIRST_NAMES[rng.randi() % Data.FIRST_NAMES.size()]
	# MV-170: sometimes one of the 20 named crew boards instead (switch off = the old path, same rolls)
	if role == "" and Features.on("crew_roster_20") and rng.randf() < Features.num("crew.roster_chance", Crew.ROSTER_CHANCE):
		var rid := Crew.roster_pick(best, rng)
		if rid != "":
			variant = "dw_crew_" + rid
			nm = str(Data.CREW_ROSTER[rid].name)
	var d := _add_dweller({"name": nm, "variant": variant, "str": stats.str, "int": stats.int, "agi": stats.agi, "lvl": 1 + int(s.lap), "role": role})
	# builders head straight for an open building site; everybody else to a free room matching their best stat
	for i in s.rooms.size():
		if role == "builder" and is_constructing(i) and is_slot_unlocked(i) and site_crew(i).size() < room_capacity(i):
			d.room = i
			break
	for i in s.rooms.size():
		var r: Dictionary = s.rooms[i]
		if int(d.room) >= 0:
			break
		if not r.type in ["empty", "annex"] and is_slot_unlocked(i) and not is_site(i) and room_workers(i).size() < room_capacity(i) and Data.room_def(r.type).get("stat") == best:
			d.room = i
			break
	dwellers_changed.emit()
	return d


func assign(d: Dictionary, slot: int) -> bool:
	if slot >= 0 and Crew.refuses(d):      # MV-127: Broken crew won't take orders
		Crew.refuse_toast(d)
		return false
	if slot >= 0:
		slot = room_anchor(slot)
		if (site_crew(slot) if is_site(slot) else room_workers(slot)).size() >= room_capacity(slot):
			toast.emit("ห้องนี้เต็มแล้ว (สูงสุด %d คน)" % room_capacity(slot), "warn")
			return false
		if room(slot).get("type", "empty") == "empty":
			return false
		var r := squad_role(d)
		if r >= 0:
			s.squad[r] = -1
			squad_changed.emit()
	d.room = slot
	dwellers_changed.emit()
	rooms_changed.emit()
	return true


func use_item_on(d: Dictionary, item: String) -> bool:
	if not has_item(item):
		return false
	match item:
		"stimpack":
			d.hp = minf(float(d.max_hp), float(d.hp) + float(d.max_hp) * 0.5)
		"radaway":
			d.rads = 0.0
		"antibiotics":
			Crew.cure(d)
		_:
			return false
	add_item(item, -1)
	dwellers_changed.emit()
	return true


func use_item(item: String) -> void:
	if item == "dried_meat" and has_item(item):
		add_item(item, -1)
		_add_res("food", 40.0)
		resources_changed.emit()


func send_explore(d: Dictionary, minutes: float) -> void:
	if Crew.refuses(d):
		Crew.refuse_toast(d)
		return
	d.away_until = Time.get_unix_time_from_system() + minutes * 60.0
	d["explore_min"] = minutes
	d.room = -1
	var role := squad_role(d)
	if role >= 0:
		s.squad[role] = -1
		squad_changed.emit()
	toast.emit("%s ออกสำรวจดินแดนรกร้าง %d นาที" % [d.name, int(minutes)], "info")
	dwellers_changed.emit()
	rooms_changed.emit()


func _return_explorer(d: Dictionary, offline: bool) -> void:
	var mins: float = d.get("explore_min", 10.0)
	d.away_until = 0.0
	var luck: float = (float(d.agi) + float(d.int) * 0.5) / 10.0
	var bp := Loot.equipped_on(d, "backpack")
	var pack_bonus := 1.0 + (Loot.base_stat(bp, "supply") + Loot.sum_key([bp], "supply")) / 100.0
	var loot := {"scrap": int(mins * (3.0 + luck * 2.0) * (1.0 + 0.3 * danger_level()) * pack_bonus),
		"food": int(mins * 1.2 * pack_bonus), "water": int(mins * 1.0 * pack_bonus)}
	if not bp.is_empty() and rng.randf() < 0.25 + Loot.base_stat(bp, "loot") / 100.0:
		loot["_gear"] = 1
	if rng.randf() < 0.3 + luck * 0.2:
		loot["stimpack"] = 1
	if rng.randf() < 0.15 + 0.03 * mins / 5.0:
		loot["_weapon"] = 1
	var dmg: float = mins * rng.randf_range(1.0, 3.0) * float(danger_level()) / (1.0 + dweller_power(d) / 12.0)
	d.hp = maxf(5.0, float(d.hp) - dmg)
	d.xp = float(d.xp) + mins * 0.8
	var got := give_rewards(loot)
	if not offline:
		toast.emit("%s กลับมาแล้ว! ได้ %s (HP -%d)" % [d.name, got, int(dmg)], "good")


# =================================================================== economy actions
func has_item(id: String, n: int = 1) -> bool:
	return int(s.items.get(id, 0)) >= n


func add_item(id: String, n: int) -> void:
	s.items[id] = maxi(0, int(s.items.get(id, 0)) + n)
	if int(s.items[id]) == 0:
		s.items.erase(id)
	resources_changed.emit()


func can_afford(cost: Dictionary) -> bool:
	if Dev.on("free"):
		return true
	for k in cost:
		if s.res.has(k):
			if float(s.res[k]) < float(cost[k]):
				return false
		elif not has_item(k, int(cost[k])):
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		toast.emit("ทรัพยากรไม่พอ: ต้องการ %s" % cost_text(cost), "warn")
		return false
	if Dev.on("free"):
		return true
	for k in cost:
		if s.res.has(k):
			s.res[k] = float(s.res[k]) - float(cost[k])
		else:
			add_item(k, -int(cost[k]))
	resources_changed.emit()
	return true


func cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		parts.append("%d %s" % [int(cost[k]), Data.item_name(k)])
	return ", ".join(parts)


## gives resources/items; returns human-readable text
func give_rewards(rew: Dictionary) -> String:
	var parts := []
	for k in rew:
		var n := int(rew[k])
		match k:
			"_gear", "_gear_rare":
				for i in maxi(1, n):
					var it2 := Loot.roll_random(Combat.enemy_level(), armory_bonus() * 10.0, 2 if k == "_gear_rare" else 1)
					Loot.add_to_stash(it2)
					parts.append("%s [%s]" % [Loot.item_name(it2), Loot.rarity(int(it2.rar)).th])
				gear_changed.emit()
			"_weapon", "_armor", "_vanpart":
				for i in maxi(1, n):
					var it: Dictionary
					var luck := armory_bonus() * 10.0
					var lvl := Combat.enemy_level()
					if k == "_vanpart":
						it = Loot.roll_item(Loot.VAN_SLOTS[rng.randi() % 4], lvl, Loot.drop_rarity(luck, 1))
					else:
						it = Loot.roll_item(k.substr(1), lvl, Loot.drop_rarity(luck, 1))
					Loot.add_to_stash(it)
					parts.append("%s [%s]" % [Loot.item_name(it), Loot.rarity(int(it.rar)).th])
				gear_changed.emit()
			"_hull":
				s.hull = minf(hull_max(), float(s.hull) + n); parts.append("ตัวถัง +%d" % n)
				travel_changed.emit()
			"_recruit":
				if s.dwellers.size() < pop_cap():
					var d := offer_recruit("sos")
					parts.append(d.name if not d.is_empty() else "คนแปลกหน้ารอตรวจที่ประตู")
				else:
					parts.append("(ที่พักเต็ม)")
			_:
				# raw food switched off: crops / meat rewards arrive as food
				var rk: String = "food" if k in Data.RAW_KEYS and not Data.raw_food() else str(k)
				if s.res.has(rk):
					_add_res(rk, float(n))
				else:
					add_item(rk, n)
				parts.append("+%d %s" % [n, Data.item_name(rk)])
	resources_changed.emit()
	return ", ".join(parts)


func start_craft(slot: int, recipe_id: String) -> bool:
	var r: Dictionary = s.rooms[slot]
	if not r.job.is_empty():
		toast.emit("ห้องนี้กำลังผลิตอยู่", "warn")
		return false
	if room_workers(slot).is_empty():
		toast.emit("ต้องมีผู้ทำงานในห้องอย่างน้อย 1 คน", "warn")
		return false
	var rec := _recipe(r.type, recipe_id)
	if rec.is_empty() or not pay(rec.cost):
		return false
	r.job = {"id": recipe_id, "progress": 0.0, "total": float(rec.time)}
	rooms_changed.emit()
	return true


func build_room(slot: int, room_type: String) -> bool:
	if not is_slot_unlocked(slot) or s.rooms[slot].type != "empty":
		return false
	var def := Data.room_def(room_type)
	if room_unlock_level(room_type) > int(s.vault_level):
		toast.emit("ต้องการ Vault Lv.%d หรือพิมพ์เขียว" % room_unlock_level(room_type), "warn")
		return false
	if not pay({"scrap": build_cost(room_type)}):
		return false
	var t := build_time(room_type)
	s.rooms[slot] = {"type": room_type, "level": 1, "job": {}, "build": {"kind": "build", "total": t, "left": t}}
	Trace.rec("build", "start build %s @%d (%ds)" % [room_type, slot, int(t)])
	toast.emit("เริ่มก่อสร้าง %s · ส่งคนไปช่วยจะเสร็จเร็วขึ้น" % def.th, "info")
	construction_started.emit(slot, "build")
	if Dev.on("instant_build"):
		_finish_build(slot, false)
	rooms_changed.emit()
	return true


func upgrade_room(slot: int) -> bool:
	slot = room_anchor(slot)
	var r: Dictionary = s.rooms[slot]
	if int(r.level) >= Data.ROOM_MAX_LEVEL or is_constructing(slot):
		return false
	if not pay({"scrap": upgrade_cost(slot)}):
		return false
	var t := upgrade_time(int(r.level) + 1, room_span(slot))
	r["build"] = {"kind": "upgrade", "total": t, "left": t}
	Trace.rec("build", "start upgrade %s @%d -> Lv%d (%ds)" % [r.type, slot, int(r.level) + 1, int(t)])
	toast.emit("เริ่มอัปเกรด %s → Lv.%d (ห้องยังทำงานระหว่างนี้)" % [Data.room_def(r.type).th, int(r.level) + 1], "info")
	construction_started.emit(slot, "upgrade")
	if Dev.on("instant_build"):
		_finish_build(slot, false)
	rooms_changed.emit()
	return true


# ------------------------------------------------------------------ construction (v4.3)
func build_info(slot: int) -> Dictionary:
	if s.is_empty() or slot < 0 or slot >= s.rooms.size():
		return {}
	return s.rooms[slot].get("build", {})


## a room or upgrade is being worked on
func is_constructing(slot: int) -> bool:
	return not build_info(slot).is_empty()


## a brand-new room that is still scaffolding (does not work yet)
func is_site(slot: int) -> bool:
	return str(build_info(slot).get("kind", "")) == "build"


func build_progress(slot: int) -> float:
	var b := build_info(slot)
	if b.is_empty():
		return 1.0
	return clampf(1.0 - float(b.left) / maxf(float(b.total), 0.01), 0.0, 1.0)


func build_cost(room_type: String) -> int:
	return int(round(float(Data.room_def(room_type).cost) * Crew.build_cost_mult()))


func upgrade_cost(slot: int) -> int:
	slot = room_anchor(slot)
	var lv := int(s.rooms[slot].level)
	if lv >= Data.ROOM_MAX_LEVEL:
		return 0
	var n := room_span(slot)
	var span_mult := 1.0 if n <= 1 else float(n) * Data.SPAN_UPGRADE_DISCOUNT
	return int(round(float(Data.ROOM_UPGRADE_COST[lv + 1]) * span_mult * Crew.build_cost_mult()))


## work seconds to put a room up (cheap rooms are quick, the science lab takes a while)
func build_time(room_type: String) -> float:
	return Data.BUILD_BASE_SEC + Data.BUILD_SEC_PER_SCRAP * float(Data.room_def(room_type).cost)


func upgrade_time(to_level: int, span: int = 1) -> float:
	return float(Data.UPGRADE_SEC[clampi(to_level, 0, Data.ROOM_MAX_LEVEL)]) * (1.0 + Data.SPAN_UPGRADE_TIME * float(maxi(span, 1) - 1))


## work seconds per real second on this site
func build_speed(slot: int) -> float:
	var sp := Data.BUILD_IDLE_SPEED
	for d in site_crew(slot):
		sp += Crew.build_speed(d)
	return sp * (1.0 - 0.3 * float(room_dark(slot)))


## "1M05S" style (pixel font friendly)
func fmt_time(sec: float) -> String:
	var t := int(ceil(sec))
	if t >= 3600:
		return "%dH%02dM" % [t / 3600, (t % 3600) / 60]
	return "%dM%02dS" % [t / 60, t % 60]


func build_left_sec(slot: int) -> float:
	var b := build_info(slot)
	if b.is_empty():
		return 0.0
	return float(b.left) / maxf(build_speed(slot), 0.01)


func rush_cost(slot: int) -> int:
	var b := build_info(slot)
	if b.is_empty():
		return 0
	return maxi(1, int(ceil(float(b.left) / Data.RUSH_SEC_PER_COMPONENT)))


## spend components to finish a site right now
func rush_build(slot: int) -> bool:
	if not is_constructing(slot):
		return false
	if not pay({"components": rush_cost(slot)}):
		return false
	Trace.rec("build", "rush @%d" % slot)
	_finish_build(slot, false)
	return true


func _tick_build(slot: int, dt: float, offline: bool) -> void:
	var b := build_info(slot)
	if b.is_empty():
		return
	b.left = maxf(0.0, float(b.left) - dt * build_speed(slot))
	if float(b.left) <= 0.0:
		_finish_build(slot, offline)


func _finish_build(slot: int, offline: bool) -> void:
	var r: Dictionary = s.rooms[slot]
	var b: Dictionary = r.get("build", {})
	if b.is_empty():
		return
	var kind := str(b.kind)
	r["build"] = {}
	var def := Data.room_def(r.type)
	if kind == "upgrade":
		r.level = mini(int(r.level) + 1, Data.ROOM_MAX_LEVEL)
		for c in room_cells(slot):
			s.rooms[c].level = r.level
	for d in site_crew(slot):
		give_xp(d, 4.0 * (1.5 if Crew.is_builder(d) else 1.0), "str", offline)
	Trace.rec("build", "finished %s %s @%d Lv%d" % [kind, r.type, slot, r.level])
	if offline:
		_offline_built.append("%s%s" % [def.th, (" Lv.%d" % r.level) if kind == "upgrade" else (" x%d" % room_span(slot) if kind == "merge" else "")])
	elif kind == "merge":
		toast.emit("ทุบผนังเสร็จ! %s ขนาด %d ช่อง ทำงานได้ x%.2f" % [def.th, room_span(slot), room_scale(slot)], "good")
		floating_text.emit(slot, "x%d" % room_span(slot), "hammer")
	elif kind == "upgrade":
		toast.emit("%s อัปเกรดเป็น Lv.%d เสร็จแล้ว!" % [def.th, r.level], "good")
		floating_text.emit(slot, "Lv.%d" % r.level, "up")
	else:
		toast.emit("สร้าง %s เสร็จแล้ว!" % def.th, "good")
		floating_text.emit(slot, "DONE", "hammer")
	construction_finished.emit(slot, kind)
	rooms_changed.emit()
	dwellers_changed.emit()


func demolish_room(slot: int) -> void:
	slot = room_anchor(slot)
	var r: Dictionary = s.rooms[slot]
	if r.type in ["empty", "engine", "annex"]:
		return
	var short := beds_short(slot)
	if short >= 0:
		toast.emit(beds_short_text(short), "warn")
		return
	for d in s.dwellers:
		if int(d.room) == slot:
			d.room = -1
	var cells := room_cells(slot)
	_add_res("scrap", float(Data.room_def(r.type).cost) * 0.5 * cells.size())
	Trace.rec("build", "demolish %s @%d x%d" % [r.type, slot, cells.size()])
	for c in cells:
		s.rooms[c] = {"type": "empty", "level": 1, "job": {}, "build": {}}
		(s.get("outage", {}) as Dictionary).erase(str(c))
	rooms_changed.emit()
	dwellers_changed.emit()


# ------------------------------------------------------------------ large rooms (v4.4)
func is_annex(slot: int) -> bool:
	return not s.is_empty() and slot >= 0 and slot < s.rooms.size() and str(s.rooms[slot].type) == "annex"


## the cell that holds a room's data: annex cells walk left (same floor, same unit) to it
func room_anchor(slot: int) -> int:
	var a := slot
	while is_annex(a) and slot_cell(a).x > 0:
		a -= 1
	return a


## every cell the room covers, left to right (the anchor first)
func room_cells(slot: int) -> Array:
	var a := room_anchor(slot)
	var out := [a]
	if s.is_empty() or a < 0 or a >= s.rooms.size():
		return out
	var c := a + 1
	while c < s.rooms.size() and slot_cell(c).x > 0 and is_annex(c):
		out.append(c)
		c += 1
	return out


func room_span(slot: int) -> int:
	return room_cells(slot).size()


## the walls are still coming down: the room works as its parts (no big-room bonus yet)
func is_merging(slot: int) -> bool:
	return str(build_info(room_anchor(slot)).get("kind", "")) == "merge"


func work_span(slot: int) -> int:
	return room_span(slot)


func span_efficiency(slot: int) -> float:
	if is_merging(slot):
		return 1.0
	return float(Data.SPAN_EFFICIENCY[clampi(room_span(slot), 1, Data.MAX_SPAN)])


## how many single rooms this room is worth (level effects, healing, pop cap, armory...)
func room_scale(slot: int) -> float:
	var span := room_span(slot)      # MV-113: once (it walks the cells), not once each for work_span and span_efficiency
	if is_merging(slot):
		return float(span)
	return float(span) * float(Data.SPAN_EFFICIENCY[clampi(span, 1, Data.MAX_SPAN)])


## crew seats: 2 per cell
func room_capacity(slot: int) -> int:
	if slot == Data.CAB_SLOT:
		return Data.CAB_WORKERS
	return Data.ROOM_WORKERS * room_span(slot)


## battery drain per minute (large rooms share wiring: 90% per cell)
func room_power_pm(slot: int) -> float:
	var r: Dictionary = s.rooms[slot]
	var n := room_span(slot)
	return float(Data.room_def(r.type).get("power", 0.0)) * float(r.level) * float(n) * (1.0 if n <= 1 else Data.SPAN_POWER_MULT)


## why the room at `slot` can't be knocked through into the room at `other` ("" = it can)
func merge_block(slot: int, other: int) -> String:
	if not Features.on("large_rooms"):
		return "ระบบรวมห้องปิดใช้งานชั่วคราว"
	if s.is_empty() or other < 0 or other >= s.rooms.size():
		return "ไม่มีห้องข้างๆ"
	var a := room_anchor(slot)
	var b := room_anchor(other)
	if a == b:
		return "เป็นห้องเดียวกันแล้ว"
	var ca := room_cells(a)
	var cb := room_cells(b)
	if slot_unit(a) != slot_unit(b) or slot_cell(a).y != slot_cell(b).y or not (int(ca[-1]) + 1 == int(cb[0]) or int(cb[-1]) + 1 == int(ca[0])):
		return "ต้องอยู่ติดกันบนชั้นเดียวกัน"
	if not is_slot_unlocked(a) or not is_slot_unlocked(b):
		return "ช่องยังล็อกอยู่"
	var ra: Dictionary = s.rooms[a]
	var rb: Dictionary = s.rooms[b]
	if not str(ra.type) in Data.MERGEABLE:
		return "ห้องนี้ขยายไม่ได้"
	if str(ra.type) != str(rb.type):
		return "ต้องเป็นห้องชนิดเดียวกัน"
	if ca.size() + cb.size() > Data.MAX_SPAN:
		return "ใหญ่สุด %d ช่อง" % Data.MAX_SPAN
	if is_constructing(a) or is_constructing(b):
		return "รอให้งานก่อสร้างเสร็จก่อน"
	if int(ra.level) != int(rb.level):
		return "ต้องเลเวลเท่ากัน (Lv.%d / Lv.%d)" % [int(ra.level), int(rb.level)]
	if not (ra.job as Dictionary).is_empty() and not (rb.job as Dictionary).is_empty():
		return "รอให้การผลิตห้องใดห้องหนึ่งเสร็จก่อน"
	return ""


## neighbouring rooms (anchors) this room could be knocked through into right now
func merge_candidates(slot: int) -> Array:
	var out := []
	var cells := room_cells(slot)
	for c in [int(cells[0]) - 1, int(cells[-1]) + 1]:
		if c >= 0 and c < s.rooms.size() and slot_unit(c) == slot_unit(int(cells[0])) and slot_cell(c).y == slot_cell(int(cells[0])).y:
			if merge_block(slot, c) == "":
				out.append(room_anchor(c))
	return out


func merge_cost(slot: int, other: int) -> Dictionary:
	var a := room_anchor(slot)
	var n := room_span(a) + room_span(other)
	var lv := int(s.rooms[a].level)
	var scrap := float(Data.room_def(s.rooms[a].type).get("cost", 0)) * Data.MERGE_SCRAP_MULT * float(lv) * float(n - 1)
	return {"scrap": int(round(scrap * Crew.build_cost_mult())), "components": Data.MERGE_COMPONENTS * (n - 1)}


func merge_time(slot: int, other: int) -> float:
	var n := room_span(slot) + room_span(other)
	return Data.MERGE_BASE_SEC + Data.MERGE_SEC_PER_LEVEL * float(s.rooms[room_anchor(slot)].level) * float(n - 1)


## knock the wall through: both rooms become one large room on the left-most cell. It keeps working (as two
## rooms) while the crew tear the wall down; the big-room bonus starts when the work is done.
func merge_rooms(slot: int, other: int) -> bool:
	var why := merge_block(slot, other)
	if why != "":
		toast.emit("รวมห้องไม่ได้: " + why, "warn")
		return false
	var cost := merge_cost(slot, other)
	var t := merge_time(slot, other)
	if not pay(cost):
		return false
	var a := mini(room_anchor(slot), room_anchor(other))
	var b := maxi(room_anchor(slot), room_anchor(other))
	var ra: Dictionary = s.rooms[a]
	var rb: Dictionary = s.rooms[b]
	if (ra.job as Dictionary).is_empty() and not (rb.job as Dictionary).is_empty():
		ra.job = rb.job
	for d in s.dwellers:
		if int(d.room) == b:
			d.room = a
	var outage: Dictionary = s.get("outage", {})
	for c in room_cells(b):
		s.rooms[c] = {"type": "annex", "level": int(ra.level), "job": {}, "build": {}}
		outage.erase(str(c))
	ra["build"] = {"kind": "merge", "total": t, "left": t}
	Trace.rec("build", "start merge %s @%d x%d (%ds)" % [ra.type, a, room_span(a), int(t)])
	toast.emit("เริ่มทุบผนังรวม%s เป็น %d ช่อง (ห้องยังทำงานระหว่างนี้)" % [Data.room_def(ra.type).th, room_span(a)], "info")
	construction_started.emit(a, "merge")
	if Dev.on("instant_build"):
		_finish_build(a, false)
	rooms_changed.emit()
	dwellers_changed.emit()
	return true


## put the walls back: every cell becomes its own room again (same type and level, free, instant).
## Crew beyond the left room's 2 seats move to the new right-hand rooms.
func split_room(slot: int) -> bool:
	var a := room_anchor(slot)
	var cells := room_cells(a)
	if cells.size() <= 1 or is_constructing(a):
		return false
	var short := beds_short(a, split_beds(a))
	if short >= 0:
		toast.emit(beds_short_text(short), "warn")
		return false
	var ra: Dictionary = s.rooms[a]
	for i in range(1, cells.size()):
		s.rooms[cells[i]] = {"type": ra.type, "level": int(ra.level), "job": {}, "build": {}}
	var k := 0
	for d in site_crew(a):
		var to: int = cells[mini(k / Data.ROOM_WORKERS, cells.size() - 1)]
		d.room = to
		k += 1
	Trace.rec("build", "split %s @%d x%d" % [ra.type, a, cells.size()])
	toast.emit("แยก%sกลับเป็น %d ห้อง" % [Data.room_def(ra.type).th, cells.size()], "info")
	rooms_changed.emit()
	dwellers_changed.emit()
	return true


func vault_upgrade_cost() -> int:
	return int(Data.VAULT_UPGRADE_COST[clampi(s.vault_level, 0, Data.MAX_VAULT_LEVEL)] * (1.0 - 0.1 * Meta.perk("quick_frame")))


func upgrade_vault() -> bool:
	if int(s.vault_level) >= Data.MAX_VAULT_LEVEL:
		return false
	if not pay({"scrap": vault_upgrade_cost()}):
		return false
	s.vault_level = int(s.vault_level) + 1
	s.hull = hull_max()
	toast.emit("MOBILE VAULT อัปเกรดเป็น Lv.%d! ปลดล็อกห้องใหม่" % s.vault_level, "biome")
	vault_level_changed.emit(s.vault_level)
	rooms_changed.emit()
	travel_changed.emit()
	return true


func repair_hull() -> bool:
	var missing := hull_max() - float(s.hull)
	if missing < 1.0:
		return false
	var c := int(ceil(missing * 0.6))
	if not pay({"scrap": c}):
		return false
	s.hull = hull_max()
	travel_changed.emit()
	return true


func set_traveling(on: bool) -> void:
	s.traveling = on
	travel_changed.emit()


# --- solar upgrades
const SOLAR_COSTS := {"panels": [0, 0, 120, 220, 350], "battery": [0, 0, 150, 260, 400], "tracking": 250}

func solar_upgrade(kind: String) -> bool:
	var sol: Dictionary = s.solar
	match kind:
		"clean":
			if float(sol.dirt) < 0.01:
				return false
			sol.dirt = 0.0
			toast.emit("ทำความสะอาดแผงแล้ว ประสิทธิภาพกลับมาเต็ม", "good")
		"panels", "battery":
			var lv := int(sol[kind])
			if lv >= 4:
				return false
			if not pay({"scrap": SOLAR_COSTS[kind][lv + 1]}):
				return false
			sol[kind] = lv + 1
		"tracking":
			if sol.tracking or not pay({"scrap": SOLAR_COSTS.tracking}):
				return false
			sol.tracking = true
	resources_changed.emit()
	return true


# =================================================================== random events
func _trigger_random_event() -> void:
	if active_event != "":
		return    # don't burn a draw from the bag on an event that can't show
	var id := next_event_id()
	if id != "":
		trigger_event(id)


## Shuffle bag per biome: every event of the biome shows once before any repeats, in a fresh random
## order each round, and none of the last EVENT_NO_REPEAT events can come straight back (also across
## a bag refill or a biome change). The bag lives in the save, so reloading doesn't reset it.
## Ids are strings, so the JSON round-trip keeps them intact.
## Features decides the pool (events switched off, or added for a date window) and each event's weight:
## weight 2 = two cards in every round, 0.5 = a card in about half the rounds.
const EVENT_NO_REPEAT := 3
const EVENT_GAP := Vector2(70.0, 140.0)     # seconds between road events while driving

func next_event_id() -> String:
	var pool: Array = Features.event_pool(int(s.biome), Data.biome(s.biome).events)
	if pool.is_empty():
		return ""
	var bag: Array = []
	if int(s.get("ev_bag_biome", -1)) == int(s.biome):
		for e in s.get("ev_bag", []):
			if pool.has(str(e)):
				bag.append(str(e))
	if bag.is_empty():
		bag = _shuffled(_weighted(pool))
	var recent: Array = s.get("ev_recent", [])
	var keep := mini(EVENT_NO_REPEAT, pool.size() - 1)
	var blocked: Array = recent.slice(maxi(0, recent.size() - keep)) if keep > 0 else []
	var id := ""
	for i in bag.size():
		if not blocked.has(bag[i]):
			id = bag[i]
			bag.remove_at(i)
			break
	if id == "":
		# what's left of the bag was all seen just now: take an unblocked one from the next round
		var fresh := _shuffled(_weighted(pool))
		for e in fresh:
			if not blocked.has(e):
				id = e
				break
		bag = fresh
		bag.erase(id)
	recent.append(id)
	while recent.size() > EVENT_NO_REPEAT:
		recent.pop_front()
	s["ev_bag"] = bag
	s["ev_bag_biome"] = int(s.biome)
	s["ev_recent"] = recent
	return id


## one bag round: every event as many times as its Features weight (fractions are a coin flip)
func _weighted(pool: Array) -> Array:
	var out := []
	for e in pool:
		var w := Features.event_weight(e)
		for i in int(w) + (1 if rng.randf() < w - floorf(w) else 0):
			out.append(e)
	return out if not out.is_empty() else pool.duplicate()


## Fisher-Yates with Game.rng (Array.shuffle() uses the global seed, see @GlobalScope docs)
func _shuffled(arr: Array) -> Array:
	var out := arr.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func trigger_event(id: String) -> void:
	if not Data.EVENTS.has(id) or active_event != "":
		return
	active_event = id
	s.stats.events = int(s.stats.events) + 1
	event_triggered.emit(id)
	travel_changed.emit()


func event_danger(id: String) -> int:
	return int(Data.EVENTS[id].danger) + int(s.lap)


# ------------------------------------------------------------------ quick-time events (MV-134)
const DECIDE_MIN := 5.0
const DECIDE_MAX := 30.0
## what the crew does when the commander doesn't answer in time: the most cautious thing they can afford
const AUTO_ORDER := ["ignore", "detour", "shelter", "flee", "push", "ram", "pay", "repair", "trade", "gift", "adopt",
	"loot", "check", "gamble", "recruit", "fight"]


## seconds to decide, 0 = no timer (switch event_timer off / setting "off"). By danger: a safe event gives 30 s, the
## deadliest about 5 s; an event can set its own "decide"; tune events.decide_scale; the "long" setting doubles it
func event_decide_sec(id: String) -> float:
	if not Features.on("event_timer") or str(Settings.get_value("event_timer")) == "off" or not Data.EVENTS.has(id):
		return 0.0
	var ev: Dictionary = Data.EVENTS[id]
	var sec := float(ev.get("decide", DECIDE_MAX / (1.0 + 0.5 * float(event_danger(id)))))
	sec = clampf(sec * Features.num("events.decide_scale", 1.0), DECIDE_MIN, DECIDE_MAX)
	if str(Settings.get_value("event_timer")) == "long":
		sec *= 2.0
	return sec


## index of the choice taken on time-out: a choice marked "auto": true, else the first affordable one in AUTO_ORDER
## (never one that is closed right now, MV-243: no fleeing when the vehicle can't move)
func event_auto_choice(id: String) -> int:
	var chs: Array = Data.EVENTS[id].choices
	for i in chs.size():
		if bool(chs[i].get("auto", false)) and (not chs[i].has("cost") or can_afford(chs[i].cost)) and choice_block(chs[i]) == "":
			return i
	for a in AUTO_ORDER:
		for i in chs.size():
			if str(chs[i].action) == a and (not chs[i].has("cost") or can_afford(chs[i].cost)) and choice_block(chs[i]) == "":
				return i
	return 0


## MV-243: why the vehicle can't pull away right now ("" = it can): the same reasons that stop it on the road
## (expedition out / parked at a site, no power, broken hull, waiting out a stop, engine resting / stalled / in a
## parked job, checkpoint, wrecked). The open event itself doesn't count: fleeing is what ends it.
func drive_block() -> String:
	if not Features.on("flee_guard"):
		return ""
	return blocked_reason()


## MV-243: why this event choice can't be taken right now ("" = it can). Only fleeing needs the vehicle to move.
func choice_block(ch: Dictionary) -> String:
	if str(ch.get("action", "")) == "flee":
		var why := drive_block()
		if why != "":
			return "รถออกตัวไม่ได้: %s" % why
	return ""


## MV-243: nobody aboard to send out (everyone is on an expedition): a fight is the crew bracing inside instead
func nobody_aboard() -> bool:
	return not s.dwellers.any(func(d): return not is_away(d))


## the two strongest crew who are aboard: who goes out when a fight is picked for the commander
func auto_defenders() -> Array:
	var list: Array = s.dwellers.filter(func(d): return not is_away(d))
	list.sort_custom(func(a, b): return dweller_power(a) > dweller_power(b))
	return list.slice(0, 2).map(func(d): return int(d.id))


## resolves an event choice; returns {"ok":bool, "text":String}
func resolve_event(id: String, choice_idx: int, defender_ids: Array) -> Dictionary:
	Trace.rec("event", "choice %s #%d" % [id, choice_idx], {"defenders": defender_ids.size()})
	var ev: Dictionary = Data.EVENTS[id]
	var ch: Dictionary = ev.choices[choice_idx]
	var danger := event_danger(id)
	var res := {"ok": true, "text": ""}
	var blocked := choice_block(ch)
	if blocked != "":
		return {"ok": false, "text": blocked}
	match ch.action:
		"fight":
			var team := []
			for did in defender_ids:
				var dd := dweller_by_id(int(did))
				if not dd.is_empty():
					team.append(dd)
			if team.is_empty() and nobody_aboard() and Features.on("flee_guard"):
				# MV-243: nobody to send out and (often) no way to drive off: the vehicle takes the hit
				var hb := rng.randf_range(6, 12) * danger
				s.hull = maxf(0.0, float(s.hull) - hb)
				res.ok = false
				res.text = "ไม่มีใครอยู่บนรถ ทำได้แค่ปิดประตูตั้งรับ... ตัวถังเสียหาย -%d%%" % int(hb)
			elif team.is_empty():
				return {"ok": false, "text": "ต้องเลือกผู้ป้องกันอย่างน้อย 1 คน"}
			else:
				var power := armory_bonus()
				for d in team:
					power += dweller_power(d)
				if has_item("ammo", 3):
					power += 4.0
					add_item("ammo", -3)
				var need := 8.0 + danger * 6.0
				var roll := rng.randf_range(0.75, 1.25)
				if power * roll >= need:
					var got := give_rewards(_scale_reward(ch.get("reward", {})))
					for d in team:
						d.hp = maxf(5.0, float(d.hp) - rng.randf_range(2, 8) * danger)
						d.xp = float(d.xp) + 4.0 * danger
					res.text = "ชนะ! ทีมป้องกันขับไล่ศัตรูได้สำเร็จ\nได้รับ: %s" % got
				else:
					for d in team:
						d.hp = maxf(5.0, float(d.hp) - rng.randf_range(10, 20) * danger)
					var hd := rng.randf_range(6, 12) * danger
					s.hull = maxf(0.0, float(s.hull) - hd)
					res.ok = false
					res.text = "แพ้... ทีมบาดเจ็บหนัก ตัวถังเสียหาย -%d%%\n(พลังทีม %.0f vs อันตราย %.0f)" % [int(hd), power * roll, need]
		"flee":
			var pw := float(s.res.power) * 0.2
			s.res.power = float(s.res.power) - pw
			if rng.randf() < 0.35:
				var hd2 := rng.randf_range(4, 9) * danger
				s.hull = maxf(0.0, float(s.hull) - hd2)
				res.text = "หนีพ้น แต่โดนโจมตีท้ายรถ! ไฟ -%d ตัวถัง -%d%%" % [int(pw), int(hd2)]
			else:
				res.text = "เร่งเครื่องหนีพ้นได้สำเร็จ! ไฟ -%d" % int(pw)
		"pay", "repair":
			var cost: Dictionary = (ch.get("cost", {}) as Dictionary).duplicate()
			var stat: String = ch.get("stat_discount", "")
			if stat != "":
				var best := 0
				for d in s.dwellers:
					if not is_away(d):
						best = maxi(best, int(d[stat]))
				for k in cost:
					cost[k] = int(float(cost[k]) * (1.0 - best * 0.05))
			if not pay(cost):
				return {"ok": false, "text": "ทรัพยากรไม่พอ (%s)" % cost_text(cost)}
			res.text = str(ch.get("result", "จ่าย %s แล้ว เส้นทางเปิดให้ผ่าน" % cost_text(cost))) if ch.action == "pay" else "ซ่อมเสร็จ (ใช้ %s)" % cost_text(cost)
			if ch.has("reward"):
				res.text += "\nได้รับ: %s" % give_rewards(_scale_reward(ch.reward))
		"ram":
			var hd3 := rng.randf_range(5, 14) * danger * 0.6 * (1.0 - Mods.val("spike_ram"))
			s.hull = maxf(0.0, float(s.hull) - hd3)
			res.text = "ชนฝ่าไปได้! ตัวถังเสียหาย -%d%%" % int(hd3)
			if rng.randf() < 0.3:
				var victim: Dictionary = s.dwellers[rng.randi() % s.dwellers.size()]
				victim.hp = maxf(5.0, float(victim.hp) - 15.0)
				res.text += "\n%s ได้รับบาดเจ็บจากแรงกระแทก" % victim.name
		"loot":
			var agi := 0
			for d in s.dwellers:
				agi = maxi(agi, int(d.agi))
			if rng.randf() < 0.25 - agi * 0.02:
				var victim2: Dictionary = s.dwellers[rng.randi() % s.dwellers.size()]
				victim2.hp = maxf(5.0, float(victim2.hp) - 25.0)
				res.text = "กับดักระเบิด! %s บาดเจ็บ แต่ยังเก็บของได้บ้าง\n%s" % [victim2.name, give_rewards({"scrap": 15})]
			else:
				res.text = "เจอของดี!\nได้รับ: %s" % give_rewards(_scale_reward(ch.reward))
		"recruit":
			if s.dwellers.size() >= pop_cap():
				return {"ok": false, "text": "ที่พักเต็ม! สร้าง/อัปเกรดห้องพักก่อน"}
			var nd := offer_recruit("event")
			if nd.is_empty():
				res.text = "ผู้รอดชีวิตคนนี้ดูไม่ธรรมดา... ฝีมือดีเกินกว่าจะรับขึ้นรถโดยไม่ตรวจ เขารออยู่ที่ประตู"
			else:
				res.text = "%s ขึ้นรถมาร่วมทางแล้ว! (STR %d / INT %d / AGI %d)" % [nd.name, nd.str, nd.int, nd.agi]
		"gift":
			if not pay(ch.cost):
				return {"ok": false, "text": "เสบียงไม่พอ"}
			for d in s.dwellers:
				d.happy = minf(100.0, float(d.happy) + 10.0)
			res.text = str(ch.get("result", "ผู้รอดชีวิตขอบคุณด้วยน้ำตา ทุกคนในรถรู้สึกดีขึ้น (+ความสุข)"))
		"trade":
			if not pay(ch.cost):
				return {"ok": false, "text": "ไม่มีของพอจะแลก"}
			res.text = "แลกเปลี่ยนสำเร็จ: %s" % give_rewards(ch.reward)
		"shelter":
			s.stall = float(ch.get("time", 30.0))
			res.text = str(ch.get("result", "จอดหลบอย่างปลอดภัย รอ %d วินาที" % int(s.stall)))
			if ch.has("reward"):
				res.text += "\nได้รับ: %s" % give_rewards(ch.reward)
		"check":
			# best present dweller attempts a stat test: d10 + stat vs dc + danger
			var stat2: String = ch.get("stat", "agi")
			var best_d: Dictionary = {}
			for d in s.dwellers:
				if not is_away(d) and (best_d.is_empty() or int(d[stat2]) > int(best_d[stat2])):
					best_d = d
			var roll := rng.randi_range(1, 10) + int(best_d.get(stat2, 3))
			var dc := int(ch.get("dc", 7)) + int(s.lap) * 2
			if roll >= dc + 3:
				res.text = "%s ทำได้สำเร็จ! (%s %d vs %d)\nได้รับ: %s" % [best_d.get("name", "?"), stat2.to_upper(), roll, dc + 3, give_rewards(_scale_reward(ch.get("reward", {})))]
				if not best_d.is_empty():
					give_xp(best_d, 6.0 + danger * 2.0, stat2)
			else:
				res.ok = false
				var f: Dictionary = ch.get("fail", {})
				var parts2 := []
				if f.has("hull"):
					s.hull = maxf(0.0, float(s.hull) - float(f.hull) * (1.0 + 0.3 * float(s.lap)))
					parts2.append("ตัวถัง -%d" % int(f.hull))
				if f.has("hp") and not best_d.is_empty():
					best_d.hp = maxf(5.0, float(best_d.hp) - float(f.hp))
					parts2.append("%s บาดเจ็บ" % best_d.name)
				res.text = "ล้มเหลว... (%s %d vs %d) %s" % [stat2.to_upper(), roll, dc + 3, ", ".join(parts2)]
		"gamble":
			if not pay(ch.cost):
				return {"ok": false, "text": "เศษเหล็กไม่พอแทง"}
			if rng.randf() < 0.45:
				_add_res("scrap", 150.0)
				res.text = "ลูกเต๋าออกหกหกหก! ได้ +150 เศษเหล็ก"
			else:
				res.ok = false
				res.text = "แพ้พนัน... นักพนันยิ้มกว้างแล้วหายไปในฝุ่น"
		"adopt":
			if not pay(ch.get("cost", {})):
				return {"ok": false, "text": "อาหารไม่พอ"}
			var pet: Dictionary = ch.get("pet", {"kind": "dog", "name": "ข้าวตัง"})
			if not s.has("pets"):
				s["pets"] = []
			s.pets.append(pet.duplicate())
			s["pet"] = true
			for d in s.dwellers:
				d.happy = minf(100.0, float(d.happy) + 15.0)
			res.text = "%s กระโดดขึ้นรถบ้าน วิ่งวนไปทั่วทุกห้อง ทุกคนยิ้มออก (ความสุข +15 และเพิ่มขึ้นช้าๆ ตลอดไป)" % pet.name
			pets_changed.emit()
		"push":
			var hd4 := rng.randf_range(4, 10) * danger * 0.6
			s.hull = maxf(0.0, float(s.hull) - hd4)
			for d in s.dwellers:
				if not is_away(d):
					d.rads = float(d.rads) + rng.randf_range(5, 15) * danger * 0.3
			if ch.has("dirt"):
				s.solar.dirt = minf(1.0, float(s.solar.dirt) + float(ch.dirt))
			res.text = "ฝ่าไปได้... ตัวถัง -%d%% ทุกคนได้รับรังสี (ใช้ยาต้านรังสีหรือห้องพยาบาลรักษา)" % int(hd4)
		"detour":
			if ch.has("cost") and not pay(ch.cost):
				return {"ok": false, "text": "ไฟไม่พอสำหรับเส้นทางอ้อม"}
			s.stall = float(ch.get("time", 20.0))
			res.text = str(ch.get("result", "เลือกเส้นทางที่ปลอดภัยกว่า"))
		"ignore":
			if ch.has("happy"):
				for d in s.dwellers:
					d.happy = maxf(0.0, float(d.happy) + float(ch.happy))
			res.text = "เดินทางต่อไป..."
	if ch.has("lore") and res.ok:
		if Lore.unlock(str(ch.lore)):
			res.text += "\n\n[บันทึกใหม่ในสมุดบันทึก: %s]" % Lore.entry_title(str(ch.lore))
	active_event = ""
	resources_changed.emit()
	dwellers_changed.emit()
	travel_changed.emit()
	save_game()
	return res


func _scale_reward(rew: Dictionary) -> Dictionary:
	var out := {}
	var m := 1.0 + 0.35 * float(danger_level() - 1)
	for k in rew:
		out[k] = int(rew[k]) if k.begins_with("_") or Data.ITEMS.has(k) else int(float(rew[k]) * m)
	return out


func cancel_event() -> void:
	active_event = ""
	travel_changed.emit()
