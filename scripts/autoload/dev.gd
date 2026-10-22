extends Node
## Tester tools ("god mode"). Hidden from players:
##  * always on in debug builds (editor / debug export)
##  * release builds: tap the VAULT chip in the HUD 7 times quickly, or open the page with ?god=1
## The unlock is remembered in user://dev.cfg. Cheat switches are NOT saved: every session starts clean,
## and the save gets stats.cheated = true the first time any of them is used (so bug reports can tell).
## Every god action is written to the Trace log.

signal changed

const CFG := "user://dev.cfg"
const FLAGS := {
	"invincible": "อมตะ (ตัวถัง/ลูกเรือ/ทีมรบไม่ลด)",
	"one_hit": "ฆ่าศัตรูทีเดียวตาย",
	"free": "สร้าง/อัปเกรด/ซื้อฟรี",
	"inf_res": "ทรัพยากรเต็มตลอด",
	"no_events": "ปิดอีเว้นต์สุ่มบนถนน",
	"instant_build": "ก่อสร้าง/อัปเกรดเสร็จทันที",
}
const SPEEDS := [1.0, 2.0, 5.0, 10.0, 20.0]

var unlocked := false
var flags := {}
var speed := 1.0
var overlay := false
var _taps: Array = []
var _layer: CanvasLayer
var _lbl: Label
var _ov_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(CFG) == OK:
		unlocked = bool(cfg.get_value("dev", "unlocked", false))
		overlay = bool(cfg.get_value("dev", "overlay", false))
	if OS.is_debug_build():
		unlocked = true
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("(window.location.search || '') + (window.location.hash || '')", true)
		if q != null and str(q).contains("god"):
			unlocked = true
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	_lbl = Label.new()
	_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl.add_theme_color_override("font_color", Color("98c050"))
	_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_lbl.add_theme_constant_override("outline_size", 2)
	_layer.add_child(_lbl)
	_lbl.visible = false


func _save_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("dev", "unlocked", unlocked)
	cfg.set_value("dev", "overlay", overlay)
	cfg.save(CFG)


## the HUD forwards taps on the VAULT chip here
func secret_tap() -> void:
	if unlocked:
		return
	var now := Time.get_ticks_msec()
	# a finger tap arrives as a touch AND an emulated mouse click: count it once
	if not _taps.is_empty() and now - int(_taps[-1]) < 80:
		return
	_taps.append(now)
	while not _taps.is_empty() and now - int(_taps[0]) > 5000:
		_taps.pop_front()
	if _taps.size() >= 7:
		_taps.clear()
		unlock()
		Game.toast.emit("เปิดโหมดผู้ทดสอบแล้ว: ปุ่ม GOD อยู่ข้างปุ่มมุมมอง", "good")


func unlock() -> void:
	unlocked = true
	_save_cfg()
	Trace.rec("god", "tester mode unlocked")
	changed.emit()


func lock() -> void:
	for k in flags.keys():
		flags[k] = false
	set_speed(1.0)
	unlocked = false
	_save_cfg()
	changed.emit()


func on(flag: String) -> bool:
	return unlocked and bool(flags.get(flag, false))


func any_active() -> bool:
	if speed != 1.0:
		return true
	for k in flags:
		if flags[k]:
			return true
	return false


func set_flag(flag: String, v: bool) -> void:
	flags[flag] = v
	act("flag %s = %s" % [flag, v])
	changed.emit()


func set_speed(x: float) -> void:
	speed = x
	Engine.time_scale = x
	if x != 1.0:
		act("speed x%s" % x)
	changed.emit()


func set_overlay(v: bool) -> void:
	overlay = v
	_save_cfg()
	changed.emit()


## every god action goes through here: logged + the save is marked as a test save
func act(what: String, data: Dictionary = {}) -> void:
	Trace.rec("god", what, data)
	if Game.started and not Game.s.is_empty():
		Game.s.stats["cheated"] = true


func _process(delta: float) -> void:
	_lbl.visible = unlocked and overlay and get_tree().get_nodes_in_group("modal_open").is_empty()
	if not unlocked or not Game.started or Game.s.is_empty():
		return
	if on("invincible"):
		Game.s.hull = Game.hull_max()
		for d in Game.s.dwellers:
			d.hp = maxf(float(d.hp), float(d.max_hp) * 0.999)
		for h in Combat.heroes:
			if not (h as Dictionary).is_empty():
				h.hp = h.max
	if on("inf_res"):
		for k in ["food", "water", "power", "scrap", "fuel"]:
			if Game.s.res.has(k):
				Game.s.res[k] = Game.cap(k)
	if on("no_events"):
		Game.s.event_t = maxf(float(Game.s.get("event_t", 0.0)), 30.0)
	if _lbl.visible:
		_ov_t -= delta / maxf(0.01, Engine.time_scale)
		if _ov_t <= 0.0:
			_ov_t = 0.5
			_update_overlay()


func _update_overlay() -> void:
	var on_flags := []
	for k in flags:
		if flags[k]:
			on_flags.append(k)
	var vp := _layer.get_viewport().get_visible_rect().size
	_lbl.text = "FPS %d  x%s  draw %d  nodes %d\nwave %d  enemies %d  km %.2f  b%d L%d\nmem %.1f MB  %s" % [
		Engine.get_frames_per_second(), speed, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), Combat.wave(), Combat.enemies.size(),
		float(Game.s.km), int(Game.s.biome), int(Game.s.get("lap", 0)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, " ".join(on_flags)]
	_lbl.add_theme_font_override("font", UIKit.font_pixel)
	_lbl.add_theme_font_size_override("font_size", UIKit.FP)
	_lbl.position = Vector2(4, floorf(vp.y * 0.42))


# ================================================================== actions (used by GodPanel + tests)
func fast_forward(sec: float) -> void:
	act("fast forward %ds" % int(sec))
	Game._offline_progress(sec)
	Game._emit_all(false)


func set_tod(v: float) -> void:
	Game.s.tod = v
	act("time of day %.2f" % v)


func weather(w: String) -> void:
	Game.force_weather(w)
	act("weather " + w)


func res_set(k: String, v: float) -> void:
	if Game.s.res.has(k):
		Game.s.res[k] = clampf(v, 0.0, Game.cap(k))
	else:
		Game.s.items[k] = maxi(0, int(v))
	act("set %s = %d" % [k, int(v)])
	Game.resources_changed.emit()


func res_all(full: bool) -> void:
	for k in Game.s.res:
		Game.s.res[k] = Game.cap(k) if full else 0.0
	if full:
		for k in ["components", "ammo", "stimpack", "radaway", "antibiotics"]:
			Game.s.items[k] = maxi(int(Game.s.items.get(k, 0)), 99)
	act("resources " + ("full" if full else "empty"))
	Game.resources_changed.emit()


func all_blueprints() -> void:
	for bp in Mods.BLUEPRINT_TH:
		Meta.add_blueprint(bp)
	act("all blueprints")
	Mods.mods_changed.emit()


func legacy_add(n: int) -> void:
	Meta.m().legacy = int(Meta.m().get("legacy", 0)) + n
	act("legacy +%d" % n)


## swap the chassis in place: keeps the rooms that still fit, trailers stay hitched
func set_tier(t: String) -> void:
	if not Data.VEHICLES.has(t) or t == Game.tier():
		return
	var old_main := Game.main_slots()
	var rooms: Array = Game.s.rooms
	var main_part := rooms.slice(0, old_main)
	var trailer_part := rooms.slice(old_main)
	Game.s.tier = t
	var new_main := Game.main_slots()
	while main_part.size() > new_main:
		main_part.pop_back()
		var idx := main_part.size()
		for d in Game.s.dwellers:
			if int(d.room) == idx:
				d.room = -1
	while main_part.size() < new_main:
		main_part.append({"type": "empty", "level": 1, "job": {}})
	# dwellers working in trailers move with their rooms
	var shift := new_main - old_main
	for d in Game.s.dwellers:
		if int(d.room) >= old_main:
			d.room = int(d.room) + shift
	main_part.append_array(trailer_part)
	Game.s.rooms = main_part
	act("tier " + t)
	_vehicle_changed()


func set_trailers(n: int) -> void:
	n = clampi(n, 0, Data.MAX_TRAILERS)
	var cur := Game.trailers()
	while cur < n:
		for i in Data.TRAILER_SLOTS:
			Game.s.rooms.append({"type": "empty", "level": 1, "job": {}})
		cur += 1
	while cur > n:
		var start: int = Game.s.rooms.size() - Data.TRAILER_SLOTS
		for d in Game.s.dwellers:
			if int(d.room) >= start:
				d.room = -1
		Game.s.rooms = Game.s.rooms.slice(0, start)
		cur -= 1
	Game.s.trailers = n
	act("trailers %d" % n)
	_vehicle_changed()


func _vehicle_changed() -> void:
	Meta.generation_started.emit(Meta.generation())    # vehicle + combat view rebuild
	Mods.mods_changed.emit()
	Game.rooms_changed.emit()
	Game.dwellers_changed.emit()
	Game.travel_changed.emit()
	Game.vault_level_changed.emit(int(Game.s.vault_level))


func set_vault(n: int) -> void:
	Game.s.vault_level = clampi(n, 1, Data.MAX_VAULT_LEVEL)
	act("vault %d" % n)
	Game.vault_level_changed.emit(int(Game.s.vault_level))
	Game.rooms_changed.emit()
	Game.travel_changed.emit()


func set_hull(frac: float) -> void:
	Game.s.hull = Game.hull_max() * frac
	act("hull %d%%" % int(frac * 100))


func mods_all(maxed: bool) -> void:
	if not Game.s.has("mods"):
		Game.s["mods"] = {}
	for id in Mods.MODS:
		Game.s.mods[id] = int(Mods.MODS[id].max) if maxed else 0
	act("mods " + ("max" if maxed else "none"))
	Mods.mods_changed.emit()
	Game.resources_changed.emit()


func rooms_fill() -> void:
	var types := []
	for k in Data.ROOMS:
		if not k in ["engine", "empty", "locked", "annex"]:
			types.append(k)
	var i := 0
	for slot in Game.s.rooms.size():
		if Game.is_slot_unlocked(slot) and Game.s.rooms[slot].type == "empty":
			Game.s.rooms[slot] = {"type": types[i % types.size()], "level": 1, "job": {}}
			i += 1
	act("fill rooms")
	Game.rooms_changed.emit()


func finish_construction() -> void:
	for slot in Game.s.rooms.size():
		if Game.is_constructing(slot):
			Game._finish_build(slot, false)
	act("finish construction")


func rooms_max() -> void:
	for r in Game.s.rooms:
		if r.type != "empty":
			r.level = Data.ROOM_MAX_LEVEL
	act("rooms max level")
	Game.rooms_changed.emit()


func blackout(all_rooms: bool) -> void:
	if all_rooms:
		Game.s.res.power = 0.0
	else:
		var built := []
		for slot in Game.s.rooms.size():
			if Game.s.rooms[slot].type != "empty":
				built.append(slot)
		if not built.is_empty():
			Game.s.outage[str(built[randi() % built.size()])] = 60.0
	act("blackout " + ("battery" if all_rooms else "short circuit"))
	Game.rooms_changed.emit()


func hazards(kind: String) -> void:
	match kind:
		"acid": Game.corrode(30.0)
		"solar": Game.damage_solar(0.5)
		"rads":
			for d in Game.s.dwellers:
				d.rads = float(d.rads) + 40.0
		"infect":
			for d in Game.s.dwellers:
				Crew.infect(d, 50.0)
	act("hazard " + kind)
	Game.dwellers_changed.emit()


# ---- crew
func recruit(n: int = 1) -> void:
	for i in n:
		Game.recruit_random()
	act("recruit %d" % n)
	Game.dwellers_changed.emit()


## a stranger at the door for inspection (grade "rare"/"very_rare", kind "" = random)
func stranger(kind: String = "", grade: String = "rare") -> void:
	if Inspection.queue_candidate("god", grade, kind).is_empty():
		Game.toast.emit("คิวหน้าประตูเต็ม (%d คน) — ล้างคิวก่อน" % Inspection.MAX_QUEUE, "warn")
		return
	act("stranger %s %s" % [grade, kind])


func heal_all() -> void:
	for d in Game.s.dwellers:
		d.hp = d.max_hp
		d.rads = 0.0
		d.infection = 0.0
	for h in Combat.heroes:
		if not (h as Dictionary).is_empty():
			h.hp = h.max
			h.alive = true
	act("heal all")
	Game.dwellers_changed.emit()
	Combat.heroes_changed.emit()


func level_up(d: Dictionary, n: int) -> void:
	for i in n:
		Game.give_xp(d, Game.xp_needed(int(d.lvl)) + 1.0, ["str", "int", "agi"][i % 3], true)
	act("level up %s +%d" % [d.name, n])
	Game.dwellers_changed.emit()
	Combat.rebuild_heroes()


func set_happy(d: Dictionary, v: float) -> void:
	d.happy = v
	if v >= 50.0:
		d["strike"] = false
		d["strike_t"] = 0.0
		d["desert_t"] = 0.0
	act("happy %s = %d" % [d.name, int(v)])
	Game.dwellers_changed.emit()


func happy_all(v: float) -> void:
	for d in Game.s.dwellers:
		set_happy(d, v)


func force_strike(d: Dictionary) -> void:
	d.happy = 5.0
	d["strike"] = true
	d["strike_t"] = 90.0
	d["desert_t"] = 0.0
	act("strike " + str(d.name))
	Game.dwellers_changed.emit()
	Game.rooms_changed.emit()


func desert_now(d: Dictionary) -> void:
	act("desert " + str(d.name))
	Crew.desert(d)


func kill(d: Dictionary) -> void:
	act("kill " + str(d.name))
	Crew.kill(d, "ทดสอบระบบ")
	Game.dwellers_changed.emit()


func add_pet(kind: String) -> void:
	var names := {"dog": "ข้าวตัง", "cat": "ส้มจี๊ด", "hen": "ไข่ดาว"}
	if not Game.s.has("pets"):
		Game.s["pets"] = []
	Game.s.pets.append({"kind": kind, "name": names.get(kind, kind)})
	act("pet " + kind)
	Game.pets_changed.emit()


func clear_pets() -> void:
	Game.s.pets = []
	act("clear pets")
	Game.pets_changed.emit()


# ---- combat
func wave_set(w: int) -> void:
	Combat.reset_wave(w)
	act("wave %d" % w)


func spawn_boss(id: String) -> void:
	Combat.debug_spawn([{"t": 0.3, "boss": "warlord" if id == "warlord" else "boss", "boss_id": id, "lvl": Combat.warlord_level() if id == "warlord" else Combat.enemy_level()}], true)
	act("spawn boss " + id)


func spawn_mob(id: String, n: int) -> void:
	var q := []
	for i in n:
		q.append({"t": 0.2 + i * 0.5, "mob": id, "lvl": Combat.enemy_level(), "no_mutate": true})
	Combat.debug_spawn(q, false)
	act("spawn %s x%d" % [id, n])


func kill_enemies() -> void:
	for e in Combat.enemies:
		e.hp = 0.0
	act("kill all enemies")


func drop_gear(rar: int, n: int = 3) -> void:
	for i in n:
		var it := Loot.roll_random(Combat.enemy_level(), 0.0, rar, 0.3)
		Loot.add_to_stash(it)
	act("drop gear rarity %d x%d" % [rar, n])
	Game.gear_changed.emit()


# ---- world
func goto_biome(i: int) -> void:
	i = clampi(i, 0, Data.BIOMES.size() - 1)
	Game.s.biome = i
	Game.s.km = Data.biome_start_km(i) + 0.05
	Game.s.erase("at_site")
	Combat.reset_wave(1)
	act("goto biome %d" % i)
	Game.biome_changed.emit(i, false)
	Game.travel_changed.emit()


func goto_checkpoint() -> void:
	Game.s.km = Game.biome_end_km() - 0.01
	act("goto checkpoint")
	Game.travel_changed.emit()


func beat_warlord() -> void:
	Game.s.combat.boss_beaten[str(int(Game.s.biome))] = true
	act("mark warlord beaten")
	Game.travel_changed.emit()


func lap_add() -> void:
	Game.s.lap = int(Game.s.get("lap", 0)) + 1
	act("lap %d" % Game.s.lap)
	Game.travel_changed.emit()


func event(id: String) -> void:
	if Game.active_event != "":
		Game.cancel_event()
	act("event " + id)
	Game.trigger_event(id)


func arrive(site: String) -> void:
	if Expedition.active():
		return
	act("arrive " + site)
	Expedition.arrive(site)


func finish_expedition() -> void:
	if not Expedition.active():
		return
	act("finish expedition")
	Game.s.exp.start = float(Game.s.exp.start) - float(Game.s.exp.dur)
	Expedition.tick(false)


func encounter(id: String) -> void:
	if not Expedition.active():
		return
	act("encounter " + id)
	Encounter.trigger_now(id)
	changed.emit()


func force_wreck() -> void:
	act("force wreck")
	Game.s.hull = 0.0
	flags["invincible"] = false
	Game.s["wreck_t"] = Meta.WRECK_SEC - 3.0
	changed.emit()


# ---- save
func export_save() -> String:
	act("export save")
	Game.save_game()
	return JSON.stringify(Game.s)


func import_save(text: String) -> bool:
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("rooms"):
		return false
	Save.write(parsed)
	act("import save")
	Game.started = false
	var ok := Game.load_game()
	if ok:
		_vehicle_changed()
	return ok


# ---- tutorial
func tutorial_restart() -> void:
	act("tutorial restart")
	Tutorial.restart()


func tutorial_skip() -> void:
	act("tutorial skip")
	Tutorial.skip()


## jump straight to a step; reopens a finished tutorial first (Tutorial.goto only works while active)
func tutorial_goto(id: String) -> void:
	if Tutorial.index_of(id) < 0:
		return
	if not Tutorial.active():
		Tutorial.restart()
	act("tutorial goto " + id)
	Tutorial.goto(id)


# ---- construction & builders
## a refugee with the builder role (hard hat) and, optionally, one construction trait
func spawn_builder(build_trait: String = "") -> Dictionary:
	var d := Game.recruit_random()
	_make_builder(d, true)
	if build_trait != "" and Crew.TRAITS.has(build_trait):
		var ts: Array = Crew.traits(d)
		if not ts.has(build_trait):
			if ts.size() >= 2:
				ts.pop_back()
			ts.append(build_trait)
	act("spawn builder %s %s" % [d.name, build_trait])
	Game.dwellers_changed.emit()
	return d


func _make_builder(d: Dictionary, on_: bool) -> void:
	d["role"] = "builder" if on_ else ""
	var parts := str(d.variant).split("_")
	var hair := parts[-1] if parts.size() >= 3 else Data.HAIRS[0]
	if on_:
		d.variant = "dw_builder_%s" % hair
	elif str(d.variant).begins_with("dw_builder_"):
		var best := "str"
		for st in ["int", "agi"]:
			if int(d[st]) > int(d[best]):
				best = st
		d.variant = "dw_%s_%s" % [Data.OUTFIT_FOR_STAT[best][0], hair]


func toggle_builder(d: Dictionary) -> void:
	_make_builder(d, not Crew.is_builder(d))
	act("builder %s = %s" % [d.name, Crew.is_builder(d)])
	Game.dwellers_changed.emit()


func reroll_traits(d: Dictionary) -> void:
	d.erase("traits")
	Crew.roll_traits(d)
	act("reroll traits %s %s" % [d.name, d.traits])
	Game.dwellers_changed.emit()
	Combat.rebuild_heroes()


## work done on every running site, 0..1 of what is left (1.0 = finish now)
func construction_progress(frac: float) -> void:
	for slot in Game.s.rooms.size():
		if Game.is_constructing(slot):
			var b := Game.build_info(slot)
			b.left = float(b.left) * (1.0 - clampf(frac, 0.0, 1.0))
	act("construction progress %d%%" % int(frac * 100.0))
	if frac >= 1.0:
		finish_construction()
	Game.rooms_changed.emit()


func constructing_count() -> int:
	var n := 0
	for slot in Game.s.rooms.size():
		if Game.is_constructing(slot):
			n += 1
	return n


# ---- defence squad
## fills the open squad slots with the strongest idle survivors on board
func squad_auto() -> void:
	var cands := []
	for d in Game.s.dwellers:
		if not Game.is_away(d) and Game.squad_role(d) < 0:
			cands.append(d)
	cands.sort_custom(func(a, b): return Combat.hero_power(a) > Combat.hero_power(b))
	for role in mini(Combat.slots_unlocked(), (Game.s.squad as Array).size()):
		if int(Game.s.squad[role]) < 0 and not cands.is_empty():
			Game.set_squad(role, int(cands.pop_front().id))
	act("squad auto fill")
	Combat.rebuild_heroes()


func squad_clear() -> void:
	for role in (Game.s.squad as Array).size():
		Game.set_squad(role, -1)
	act("squad clear")
	Combat.rebuild_heroes()


func squad_gear() -> int:
	var n := Loot.auto_equip_squad()
	act("squad auto equip %d" % n)
	Combat.rebuild_heroes()
	return n


# ---- items & forge
func items_all(n: int) -> void:
	for k in Data.ITEMS:
		if str(Data.ITEMS[k].kind) in ["use", "mat"]:
			Game.s.items[k] = maxi(0, int(Game.s.items.get(k, 0)) + n)
	act("items +%d" % n)
	Game.resources_changed.emit()


## 3 items of every rarity below the top one, so every forge recipe can be tried at once
func forge_kit() -> void:
	# straight into the stash: roll_random's rarity is only a floor, and auto-salvage would eat the low ones
	var slots: Array = Loot.HERO_SLOTS + Loot.VAN_SLOTS
	for r in Loot.RARITY.size() - 1:
		for i in 3:
			if Loot.stash().size() < Loot.STASH_CAP:
				Loot.stash().append(Loot.roll_item(slots[randi() % slots.size()], Combat.enemy_level(), r))
	Game.s.res.scrap = maxf(float(Game.s.res.scrap), minf(Game.cap("scrap"), 500.0))
	Game.s.items["components"] = maxi(int(Game.s.items.get("components", 0)), 200)
	act("forge kit")
	Game.resources_changed.emit()
	Game.gear_changed.emit()


## every equipped item (squad + vehicle) to its rarity's max +level
func gear_max_plus() -> int:
	var n := 0
	var all := []
	for d in Game.s.dwellers:
		for slot in Loot.HERO_SLOTS:
			all.append(Loot.equipped_on(d, slot))
	for slot in Loot.VAN_SLOTS:
		all.append(Loot.van_equipped(slot))
	for it in all:
		if not (it as Dictionary).is_empty() and Loot.can_enhance(it):
			it.plus = int(Loot.rarity(int(it.rar)).max_plus)
			n += 1
	act("gear max plus %d" % n)
	Game.gear_changed.emit()
	Combat.rebuild_heroes()
	return n


func stash_clear() -> void:
	Loot.stash().clear()
	act("stash clear")
	Game.gear_changed.emit()


# ---- road event deck
func event_deck_reset() -> void:
	Game.s.erase("ev_bag")
	Game.s.erase("ev_bag_biome")
	Game.s.erase("ev_recent")
	act("event deck reset")


## draw the next card from the shuffle bag (the same path the road uses)
func event_draw() -> void:
	if Game.active_event != "":
		Game.cancel_event()
	var id := Game.next_event_id()
	act("event draw " + id)
	if id != "":
		Game.trigger_event(id)


# ---- expedition encounters
func encounter_recent_clear() -> void:
	Game.s.erase("enc_recent")
	act("encounter history clear")


## no trip running: send a free scavenging team first, then put the encounter on it
func encounter_anywhere(id: String) -> void:
	if not Expedition.active():
		var ids := []
		for d in Game.s.dwellers:
			if not Game.is_away(d) and ids.size() < Expedition.min_team():
				ids.append(int(d.id))
		if not Expedition.start("scav", ids, {}):
			Game.toast.emit("ส่งทีมสำรวจไม่ได้ (ลูกเรือไม่พอ)", "warn")
			return
		act("quick expedition for encounter")
	encounter(id)


# ---- strangers
func stranger_clear() -> void:
	Inspection.queue().clear()
	act("stranger queue clear")
	Inspection.queue_changed.emit()


# ---- cloud save
func cloud_sync() -> void:
	act("cloud sync")
	Cloud.sync()


func cloud_force_upload() -> void:
	act("cloud force upload")
	if Game.started:
		Game.save_game()
	Cloud.upload(true)


## forget the sign-in and the sync bookkeeping, as if this browser had never synced (cloud row stays)
func cloud_forget() -> void:
	Cloud.session = {}
	Cloud._save_session()
	Cloud.meta.rev = 0
	Cloud.meta.dirty = Save.has_save()
	Cloud.meta.wiped = false
	Cloud._save_meta()
	act("cloud forget link")
	Cloud.sync()


func settings_reset() -> void:
	act("settings reset")
	Settings.reset_defaults()
