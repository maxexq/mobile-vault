extends Node
## Core simulation: resources, rooms, dwellers, travel, biomes, weather, events, idle/offline progress.
## The whole save is the `s` Dictionary (JSON-friendly). Views listen to signals and read `s`.

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


func _ready() -> void:
	rng.randomize()
	Save.flush_requested.connect(save_game)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()


# =================================================================== lifecycle
func new_game() -> void:
	setup_default_state()
	started = true
	save_game()
	game_started.emit()
	_emit_all(true)
	toast.emit("ยินดีต้อนรับสู่ Mobile Vault! แตะที่ห้องเพื่อจัดการ ปัดซ้าย-ขวาเพื่อดูถนน", "info")


## fresh state (also used as the live backdrop behind the title screen)
func setup_default_state(keep_meta: bool = false) -> void:
	var meta: Dictionary = s.get("meta", {}) if keep_meta else {}
	var tier_id: String = str(s.get("tier", "van")) if keep_meta else "van"
	s = {
		"version": 1, "route_v": 2, "slots_v": 4, "tier": tier_id, "trailers": 0, "pets": [], "outage": {},
		"vault_level": 1,
		"res": {"power": 60.0, "water": 50.0, "food": 50.0, "scrap": 150.0, "fuel": 30.0},
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
		"squad": [-1, -1, -1], "next_uid": 1,
		"combat": {"wave": 1, "best": 1, "push": true, "boss_beaten": {}, "kpm": 0.0, "kills": 0, "auto_salvage": -1, "threat": 0.0, "raid_kpm": 0.0, "fight_share": 0.3},
		"mods": {}, "exp": {}, "at_site": "", "sites_done": {}, "memorial": [], "generator": true,
	}
	if not meta.is_empty():
		s.meta = meta
	for i in slot_count():
		s.rooms.append({"type": "empty", "level": 1, "job": {}, "build": {}})
	s.rooms[Data.ENGINE_SLOT].type = "engine"
	s.rooms[1].type = "kitchen"
	s.rooms[2].type = "water"
	if keep_meta:
		# a new generation starts with three fresh volunteers (+ the veterans the caller adds)
		for i in 3:
			var d := recruit_random()
			d.lvl = 1 + Meta.generation() / 2
		s.dwellers[0].room = Data.ENGINE_SLOT
		s.dwellers[1].room = 1
		s.van_gear.turret = Loot.roll_item("turret", 1, 0, "mg_turret")
		s.items["components"] = 20
		s.squad = [-1, int(s.dwellers[2].id), -1]
		return
	var mark := _add_dweller({"name": "จ่ามาร์ค", "lore": "mark", "variant": "dw_army_brown", "str": 7, "int": 3, "agi": 4, "room": -1, "lvl": 3})
	var leo := _add_dweller({"name": "ลีโอ", "lore": "leo", "variant": "dw_scav_brown", "str": 4, "int": 3, "agi": 7, "room": -1, "lvl": 2})
	_add_dweller({"name": "ต้น", "lore": "ton", "variant": "dw_jumpsuit_black", "str": 6, "int": 4, "agi": 3, "room": Data.ENGINE_SLOT, "lvl": 1, "role": "builder"})
	_add_dweller({"name": "เชฟบ็อบ", "lore": "bob", "variant": "dw_chef_gray", "str": 3, "int": 4, "agi": 7, "room": 1, "lvl": 2})
	_add_dweller({"name": "พยาบาลคลารา", "lore": "clara", "variant": "dw_medic_red", "str": 3, "int": 7, "agi": 4, "room": 2, "lvl": 2})
	# starter defence squad + gear (common)
	s.squad = [int(leo.id), int(mark.id), -1]
	leo.gear = {"weapon": Loot.roll_item("weapon", 1, 0, "hunting_rifle"), "backpack": Loot.roll_item("backpack", 1, 0, "school_bag")}
	mark.gear = {"weapon": Loot.roll_item("weapon", 1, 0, "pipe_wrench"), "armor": Loot.roll_item("armor", 1, 0, "leather_jacket"), "helmet": Loot.roll_item("helmet", 1, 0, "hard_hat")}
	s.van_gear.turret = Loot.roll_item("turret", 1, 0, "mg_turret")
	s.items["components"] = 20


func load_game() -> bool:
	var d := Save.read()
	if d.is_empty() or not d.has("rooms"):
		return false
	s = d
	_migrate()
	started = true
	# Cloud.now() is the server clock once the cloud has answered, so a moved phone clock can't fake time away
	var now := Cloud.now()
	var elapsed := maxf(0.0, now - float(s.get("saved_at", now)))
	Trace.rec("save", "loaded save", {"away_sec": int(elapsed), "bytes": JSON.stringify(s).length()})
	game_started.emit()
	if elapsed > 30.0:
		_offline_progress(minf(elapsed, Data.OFFLINE_CAP_SEC))
	_emit_all(true)
	return true


func _migrate() -> void:
	# make old saves forward compatible (missing keys get defaults)
	var pre_combat := not s.has("squad")
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
	s.saved_at = Cloud.now()
	Save.write(s)


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
	for k in ["food", "water", "power", "scrap"]:
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


func _process(delta: float) -> void:
	if not started:
		return
	_simulate(delta, false)
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
		if s.rooms[i].type == "quarters" and not is_site(i):
			c += 4 * int(s.rooms[i].level)
	return c


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


func is_slot_unlocked(slot: int) -> bool:
	return unlocked_slots().has(slot)


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
		var def := Data.room_def(r.type)
		f -= float(def.power) * float(r.level)
		f += float(room_rate_pm(slot).get("power", 0.0))
	if is_moving():
		f -= Data.TRAVEL_POWER_PM
	return f


func hull_max() -> float:
	if s.is_empty() or not s.has("van_gear"):
		return 100.0
	return 100.0 + float(vehicle_def().hull) + float(Combat.van_stats().hull) + Mods.val("armor_plates")


func speed_factor() -> float:
	if not is_moving():
		return 0.0
	var f: float = weather_def().speed * (1.0 + float(Combat.van_stats().speed) / 100.0) * Env.speed_mult() * Haul.speed_mult()
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
		return "ไฟหมด! ต้องการพลังงาน"
	if s.hull <= 0.0:
		return "ตัวถังพัง! ซ่อมก่อนเดินทาง"
	if s.stall > 0.0:
		return "จอดรอ %ds" % int(ceil(s.stall))
	if at_checkpoint():
		if not Combat.boss_beaten(int(s.biome)):
			if s.biome < Data.BIOMES.size() - 1 and s.vault_level < int(Data.biome(s.biome + 1).req):
				return "ด่านตรวจ: ต้องการ Vault Lv.%d + ปราบบอส" % Data.biome(s.biome + 1).req
			return "ด่านตรวจ: ปราบบอส %s" % Combat.BOSSES[Data.biome(s.biome).id].th
		return "ด่านตรวจ: ต้องการ Vault Lv.%d" % Data.biome(s.biome + 1).req
	return ""


func biome_end_km() -> float:
	return Data.biome_start_km(s.biome + 1)


## at the end of a biome the van stops until the checkpoint warlord is beaten
## (and, except on the last biome, the vault frame is high enough for the next one)
func at_checkpoint() -> bool:
	if s.km < biome_end_km() - 0.001:
		return false
	if not Combat.boss_beaten(int(s.biome)):
		return true
	if s.biome >= Data.BIOMES.size() - 1:
		return false
	return s.vault_level < int(Data.biome(s.biome + 1).req)


func danger_level() -> int:
	return int(Data.biome(s.biome).danger) + int(s.lap)


## crew that actually works the room (strikers sit it out). A room still being built has no workers yet:
## the people assigned there are its builders (see site_crew).
func room_workers(slot: int) -> Array:
	var out := []
	if is_site(slot):
		return out
	for d in s.dwellers:
		if int(d.room) == slot and not is_away(d) and not d.get("strike", false):
			out.append(d)
	return out


## crew putting up / upgrading the room
func site_crew(slot: int) -> Array:
	var out := []
	for d in s.dwellers:
		if int(d.room) == slot and not is_away(d) and not d.get("strike", false):
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
		if s.rooms[i].type != "empty" and is_slot_unlocked(i) and not o.has(str(i)):
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
		d.room = -1
	s.squad[role] = did
	squad_changed.emit()
	dwellers_changed.emit()
	rooms_changed.emit()


func idle_dwellers() -> Array:
	var out := []
	for d in s.dwellers:
		if int(d.room) < 0 and not is_away(d) and squad_role(d) < 0:
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
			b += float(Data.ROOMS.science.boost) * float(r.level)
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
	var stat_mult := 0.5 + stat_sum(slot) / 10.0          # 1 avg worker = 1.0
	var happy_mult := 0.6 + avg_happiness() / 250.0
	var mult := lvl_mult * stat_mult * happy_mult * (1.0 + science_boost()) * Crew.room_mult(slot) * Synergy.room_mult(slot) * Env.prod_mult() * outage_mult(slot)
	if def.get("weather_crop", false):
		mult *= float(weather_def().crop)
	if def.power > 0.0 and s.res.power <= 0.5:
		mult *= 0.15
	for k in def.produce:
		out[k] = float(def.produce[k]) * mult
	return out


func craft_speed(slot: int) -> float:
	var workers := room_workers(slot)
	if workers.is_empty():
		return 0.0
	var r: Dictionary = s.rooms[slot]
	var sk := 0.0
	for d in workers:
		sk += Skills.val(d, "craft") / workers.size()
	return (0.6 + stat_sum(slot) / 12.0) * (1.0 + 0.25 * float(r.level - 1)) * (1.0 + science_boost()) * (1.0 + sk) * Crew.room_mult(slot) * Synergy.room_mult(slot) * Env.prod_mult() * outage_mult(slot)


func medical_power() -> float:
	var p := 0.0
	for i in s.rooms.size():
		if s.rooms[i].type == "medical" and is_slot_unlocked(i) and not room_workers(i).is_empty():
			p += float(s.rooms[i].level) * Crew.room_mult(i)
	return p


func hull_regen_pm() -> float:
	var r := Mods.val("repair_bay")
	for slot in [Data.ENGINE_SLOT] + _rooms_of("workshop"):
		for d in room_workers(slot):
			r += (2.0 if s.rooms[slot].type == "engine" else 1.5) * float(s.rooms[slot].level) / 2.0
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
		toast.emit("ซอมบี้ปีกหนังจิกแผงโซลาร์พัง! ไฟฟ้าลดลง — ติดป้อม Flak หรือให้มือปืนหลังคาจัดการ", "warn")


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
			b += 2.0 * float(s.rooms[i].level)
	return b


# =================================================================== simulation
func _simulate(dt: float, offline: bool) -> void:
	var m := dt / 60.0     # minutes
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
	# --- hull repair: engine crew (mechanics faster), repair skills, repair bay mod
	if float(s.hull) < hull_max():
		s.hull = minf(hull_max(), float(s.hull) + hull_regen_pm() * m)
	Meta.tick(dt, offline)
	Expedition.tick(offline)
	Inspection.tick(dt, offline)
	_tick_outages(dt, offline)
	_tick_corrosion(m)
	# --- solar + rain collector + vault engine part
	_add_res("power", (solar_output_pm() + float(Combat.van_stats().power)) * m)
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
			_add_res("power", -float(def.power) * float(r.level) * m)
		var rate := room_rate_pm(slot)
		for k in rate:
			var amt: float = rate[k] * m
			_add_res(k, amt)
			if not offline:
				_accumulate_float(slot, k, amt)
		_tick_job(slot, dt, offline)
		if def.has("heal") and not room_workers(slot).is_empty():
			var hm := Crew.room_mult(slot)
			for d in s.dwellers:
				if not is_away(d):
					d.hp = minf(float(d.max_hp), float(d.hp) + float(def.heal) * float(r.level) * hm * m)
					d.rads = maxf(0.0, float(d.rads) - 0.5 * float(r.level) * hm * m)

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
	_add_res("food", -Data.DWELLER_FOOD_PM * eat * m * (0.92 if has_pet("cat") else 1.0))
	if has_pet("hen"):
		_add_res("food", 0.6 * m)
	_add_res("water", -Data.DWELLER_WATER_PM * eat * Env.water_mult() * m)
	var starving: bool = res.food <= 0.0 or res.water <= 0.0
	var crowded: bool = s.dwellers.size() > pop_cap()
	var has_quarters := false
	for i in s.rooms.size():
		if s.rooms[i].type == "quarters" and not is_site(i):
			has_quarters = true
	for d in s.dwellers:
		if is_away(d):
			continue
		if starving:
			d.hp = maxf(1.0, float(d.hp) - 3.0 * m)
		if float(d.rads) > 0.0:
			d.hp = maxf(1.0, float(d.hp) - float(d.rads) * 0.02 * m)
		var target := 45.0 + Crew.happy_aura(d) + Env.happy_mod(d)
		if Crew.is_infected(d):
			target -= 15.0
		target += 6.0 * minf(2.0, float((s.get("pets", []) as Array).size()))
		var home := int(d.room) if int(d.room) >= 0 else _first_quarters()
		if home >= 0:
			target += Synergy.happy_mod(home)
			if room_dark(home):
				target -= 16.0 if Crew.has(d, "afraid_dark") else 4.0
		elif is_night() and Crew.has(d, "afraid_dark"):
			target -= 8.0
		if crowded:
			target -= 10.0
		if res.food < cap("food") * 0.1:
			target -= 8.0
		if has_quarters:
			target += 15.0
		if not starving:
			target += 15.0
		var role := squad_role(d)
		if role >= 0:
			target += 20.0 if _best_stat(d) == Combat.ROLES[role].stat else 10.0
		elif int(d.room) >= 0:
			var st: String = Data.room_def(s.rooms[int(d.room)].type).get("stat", "")
			var xpm := 1.5 * (1.2 if Crew.has(d, "genius") else 1.0)
			if is_constructing(int(d.room)):
				# hauling beams: builds STR, real builders love it
				st = "str"
				if Crew.is_builder(d):
					xpm *= 1.5
					target += 12.0
			target += 20.0 if st != "" and _best_stat(d) == st else 8.0
			for o in room_workers(int(d.room)):
				if o != d:
					xpm *= 1.0 + 2.0 * Skills.val(o, "mentor")
			give_xp(d, xpm * m, st, offline)
		d.happy = move_toward(float(d.happy), target, 2.0 * m)
		Crew.morale_tick(d, dt, offline)

	Crew.flush_deserters()

	# --- travel
	if is_moving():
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
		_add_res("fuel", -Haul.fuel_pm() * m)
		_add_res("scrap", float(Data.biome(s.biome).scrap_pm) * m)
		if not offline:
			_accumulate_float(-1, "scrap", float(Data.biome(s.biome).scrap_pm) * m)
		if s.km >= end_km:
			if at_checkpoint():
				s.km = end_km
				if not offline:
					if not Combat.boss_beaten(int(s.biome)):
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
				s.event_t = rng.randf_range(70.0, 140.0)
				_trigger_random_event()

	# --- radio recruitment (passive)
	var radio_lvl := 0
	for i in s.rooms.size():
		if s.rooms[i].type == "radio" and not room_workers(i).is_empty():
			radio_lvl += int(s.rooms[i].level)
	if radio_lvl > 0:
		s.recruit_t = float(s.recruit_t) - dt * float(radio_lvl)
		if s.recruit_t <= 0.0:
			s.recruit_t = 240.0
			if s.dwellers.size() < pop_cap():
				var d := offer_recruit("radio")
				if not offline and not d.is_empty():
					toast.emit("วิทยุรับสัญญาณ! %s เข้าร่วมรถบ้าน" % d.name, "good")

	if dwellers_dirty:
		dwellers_changed.emit()
	if not offline:
		resources_changed.emit()


func _add_res(k: String, v: float) -> void:
	if not s.res.has(k):
		return
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
	var grade := Inspection.roll_grade(elite_bonus)
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
	var d := _add_dweller({"name": nm, "variant": variant, "str": stats.str, "int": stats.int, "agi": stats.agi, "lvl": 1 + int(s.lap), "role": role})
	# builders head straight for an open building site; everybody else to a free room matching their best stat
	for i in s.rooms.size():
		if role == "builder" and is_constructing(i) and is_slot_unlocked(i) and site_crew(i).size() < Data.ROOM_WORKERS:
			d.room = i
			break
	for i in s.rooms.size():
		var r: Dictionary = s.rooms[i]
		if int(d.room) >= 0:
			break
		if r.type != "empty" and is_slot_unlocked(i) and not is_site(i) and room_workers(i).size() < Data.ROOM_WORKERS and Data.room_def(r.type).get("stat") == best:
			d.room = i
			break
	dwellers_changed.emit()
	return d


func assign(d: Dictionary, slot: int) -> bool:
	if slot >= 0:
		if (site_crew(slot) if is_site(slot) else room_workers(slot)).size() >= Data.ROOM_WORKERS:
			toast.emit("ห้องนี้เต็มแล้ว (สูงสุด %d คน)" % Data.ROOM_WORKERS, "warn")
			return false
		if s.rooms[slot].type == "empty":
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
						it = Loot.roll_item(Loot.VAN_SLOTS[rng.randi() % 4], lvl, Loot.roll_rarity(luck, 1))
					else:
						it = Loot.roll_item(k.substr(1), lvl, Loot.roll_rarity(luck, 1))
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
				if s.res.has(k):
					_add_res(k, float(n))
				else:
					add_item(k, n)
				parts.append("+%d %s" % [n, Data.item_name(k)])
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
	var r: Dictionary = s.rooms[slot]
	if int(r.level) >= Data.ROOM_MAX_LEVEL or is_constructing(slot):
		return false
	if not pay({"scrap": upgrade_cost(slot)}):
		return false
	var t := upgrade_time(int(r.level) + 1)
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
	var lv := int(s.rooms[slot].level)
	if lv >= Data.ROOM_MAX_LEVEL:
		return 0
	return int(round(float(Data.ROOM_UPGRADE_COST[lv + 1]) * Crew.build_cost_mult()))


## work seconds to put a room up (cheap rooms are quick, the science lab takes a while)
func build_time(room_type: String) -> float:
	return Data.BUILD_BASE_SEC + Data.BUILD_SEC_PER_SCRAP * float(Data.room_def(room_type).cost)


func upgrade_time(to_level: int) -> float:
	return float(Data.UPGRADE_SEC[clampi(to_level, 0, Data.ROOM_MAX_LEVEL)])


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
	for d in site_crew(slot):
		give_xp(d, 4.0 * (1.5 if Crew.is_builder(d) else 1.0), "str", offline)
	Trace.rec("build", "finished %s %s @%d Lv%d" % [kind, r.type, slot, r.level])
	if offline:
		_offline_built.append("%s%s" % [def.th, (" Lv.%d" % r.level) if kind == "upgrade" else ""])
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
	var r: Dictionary = s.rooms[slot]
	if r.type in ["empty", "engine"]:
		return
	for d in room_workers(slot):
		d.room = -1
	_add_res("scrap", float(Data.room_def(r.type).cost) * 0.5)
	Trace.rec("build", "demolish %s @%d" % [r.type, slot])
	s.rooms[slot] = {"type": "empty", "level": 1, "job": {}, "build": {}}
	rooms_changed.emit()
	dwellers_changed.emit()


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
const EVENT_NO_REPEAT := 3

func next_event_id() -> String:
	var pool: Array = []
	for e in Data.biome(s.biome).events:
		if Data.EVENTS.has(e) and not pool.has(e):
			pool.append(e)
	if pool.is_empty():
		return ""
	var bag: Array = []
	if int(s.get("ev_bag_biome", -1)) == int(s.biome):
		for e in s.get("ev_bag", []):
			if pool.has(str(e)):
				bag.append(str(e))
	if bag.is_empty():
		bag = _shuffled(pool)
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
		var fresh := _shuffled(pool)
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


## resolves an event choice; returns {"ok":bool, "text":String}
func resolve_event(id: String, choice_idx: int, defender_ids: Array) -> Dictionary:
	Trace.rec("event", "choice %s #%d" % [id, choice_idx], {"defenders": defender_ids.size()})
	var ev: Dictionary = Data.EVENTS[id]
	var ch: Dictionary = ev.choices[choice_idx]
	var danger := event_danger(id)
	var res := {"ok": true, "text": ""}
	match ch.action:
		"fight":
			var team := []
			for did in defender_ids:
				var dd := dweller_by_id(int(did))
				if not dd.is_empty():
					team.append(dd)
			if team.is_empty():
				return {"ok": false, "text": "ต้องเลือกผู้ป้องกันอย่างน้อย 1 คน"}
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
			res.text = "จ่าย %s แล้ว เส้นทางเปิดให้ผ่าน" % cost_text(cost) if ch.action == "pay" else "ซ่อมเสร็จ (ใช้ %s)" % cost_text(cost)
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
				res.text = "%s เข้าร่วมรถบ้านแล้ว! (STR %d / INT %d / AGI %d)" % [nd.name, nd.str, nd.int, nd.agi]
		"gift":
			if not pay(ch.cost):
				return {"ok": false, "text": "เสบียงไม่พอ"}
			for d in s.dwellers:
				d.happy = minf(100.0, float(d.happy) + 10.0)
			res.text = "ผู้รอดชีวิตขอบคุณด้วยน้ำตา ทุกคนในรถรู้สึกดีขึ้น (+ความสุข)"
		"trade":
			if not pay(ch.cost):
				return {"ok": false, "text": "ไม่มีของพอจะแลก"}
			res.text = "แลกเปลี่ยนสำเร็จ: %s" % give_rewards(ch.reward)
		"shelter":
			s.stall = float(ch.get("time", 30.0))
			res.text = "จอดหลบอย่างปลอดภัย รอ %d วินาที" % int(s.stall)
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
			res.text = "ฝ่าไปได้... ตัวถัง -%d%% ทุกคนได้รับรังสี (ใช้ RadAway หรือห้องแล็บรักษา)" % int(hd4)
		"detour":
			if ch.has("cost") and not pay(ch.cost):
				return {"ok": false, "text": "ไฟไม่พอสำหรับเส้นทางอ้อม"}
			s.stall = float(ch.get("time", 20.0))
			res.text = "เลือกเส้นทางที่ปลอดภัยกว่า"
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
