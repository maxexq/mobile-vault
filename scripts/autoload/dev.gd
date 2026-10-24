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
	# run after Game/Combat/Env so "invincible" refills whatever they took this frame (MV-41)
	process_priority = 1000
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
	Features.clear_overrides()
	set_speed(1.0)
	unlocked = false
	_save_cfg()
	changed.emit()


func on(flag: String) -> bool:
	return unlocked and bool(flags.get(flag, false))


func any_active() -> bool:
	if speed != 1.0 or Features.has_dev_overrides():
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


## vehicle body rumble strength (MV-176): sets the fx.engine_shake override, < 0 = back to the build's value
func engine_shake(k: float) -> void:
	Trace.rec("god", "engine shake %.2f" % k)
	Features.set_override("tune", "fx.engine_shake", null if k < 0.0 else k)


## feel the screen shake at a given strength (MV-175): 6 = the biggest hit in the game (boss slam)
func shake_test(amount: float = 6.0) -> void:
	Trace.rec("god", "shake test %.1f" % amount)
	get_tree().call_group("shake", "shake", amount)


func set_overlay(v: bool) -> void:
	overlay = v
	_save_cfg()
	changed.emit()


## preview another screen on desktop (MV-148): the window takes a phone / tablet size. Not on web, where the
## browser owns the size. Read-only for the save (not cheated)
func window_preset(sz: Vector2i) -> void:
	Trace.rec("god", "window %dx%d" % [sz.x, sz.y])
	get_window().size = sz


## one line for GOD: real window, UI pixel scale S, world scale (art px -> screen px) and why
func view_info() -> String:
	var m = get_tree().current_scene
	if m == null or not m.has_method("target_ws"):
		return "-"
	var win := DisplayServer.window_get_size()
	var why := "ปกติ"
	if m.world_scale > m.pixel_scale:
		why = "ซูมเต็มจอแนวตั้ง"
	elif m.world_scale < m.pixel_scale:
		why = "มุมกว้าง"
	return "จอ %dx%d · UI x%d · โลก x%d (%s) · กล้อง %s" % [win.x, win.y, int(m.pixel_scale), int(m.world_scale), why, m.zoom_mode]


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


# ------------------------------------------------------------------ engine bay (v4.6)
## the engine_bay Features switch for this tester (MV-40): off = stock diesel, no heat / wear / rests / jobs
func engine_bay_switch(v: bool) -> void:
	feature_set("engine_bay", v)
	EngineBay._changed()


func engine_set(key: String, v: float) -> void:
	var e := EngineBay.st()
	e[key] = v
	act("engine %s %d" % [key, int(v)])
	EngineBay._changed()


## one of every engine base into the stash (rare, ilvl 20)
func engines_all() -> void:
	for id in Loot.BASES:
		if str(Loot.BASES[id].get("slot", "")) == "engine":
			Loot.add_to_stash(Loot.roll_item("engine", 20, 2, id))
	act("engines all")
	Game.gear_changed.emit()


func engine_breakdown() -> void:
	EngineBay.st().cond = minf(EngineBay.cond(), EngineBay.BREAK_BELOW - 5.0)
	Game.s.stall = 45.0
	act("engine breakdown")
	EngineBay._changed()


func engine_rest(on: bool) -> void:
	EngineBay.st().resting = on
	act("engine rest %s" % on)
	EngineBay._changed()


func engine_finish_job() -> void:
	var j: Dictionary = EngineBay.st().get("job", {})
	if not j.is_empty():
		j.left = 0.0
		EngineBay._tick_job(0.0, false)
	act("engine job done")


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


## every room lamp (and the cab's) stutters for 2 s: check the lighting / micro animation layer
func lamps_flicker() -> int:
	var n := 0
	for a in get_tree().get_nodes_in_group(RoomAmbience.GROUP):
		(a as RoomAmbience).flicker(2.0)
		n += 1
	act("lamps flicker x%d" % n)
	return n


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


## MV-170: board one of the 20 named crew directly (no random roll; works with the switch off too)
func spawn_roster(id: String) -> Dictionary:
	if not Data.CREW_ROSTER.has(id):
		return {}
	var r: Dictionary = Data.CREW_ROSTER[id]
	var st := {"str": 3, "int": 3, "agi": 3}
	st[r.stat] = 6
	var d := Game._add_dweller({"name": r.name, "variant": "dw_crew_" + id, "str": st.str, "int": st.int, "agi": st.agi,
		"lvl": 1 + int(Game.s.get("lap", 0))})
	act("spawn crew " + id)
	Game.dwellers_changed.emit()
	return d


## every named crew member not on board yet
func spawn_roster_all() -> void:
	for id in Data.CREW_ROSTER:
		var on_board := false
		for d in Game.s.dwellers:
			on_board = on_board or str(d.variant) == "dw_crew_" + str(id)
		if not on_board:
			spawn_roster(str(id))


## tester override of crew.roster_chance (-1 = back to the default)
func roster_chance(k: float) -> void:
	Trace.rec("god", "roster chance %.2f" % k)
	Features.set_override("tune", "crew.roster_chance", null if k < 0.0 else k)


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


func force_raid() -> void:
	Threat.force_warning()
	act("force raid")


func threat_set(v: float) -> void:
	Game.s.combat.threat = v
	act("threat %d" % int(v))


func spawn_boss(id: String) -> void:
	var q := {"t": 0.3, "boss": "warlord" if id == "warlord" else "boss", "lvl": Combat.warlord_level() if id == "warlord" else Combat.enemy_level()}
	if id != "warlord":
		q["boss_id"] = id      # "warlord" has no boss_id: _spawn then takes this area's warlord (it used to fall back to the golem)
	Combat.debug_spawn([q], true)
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


## MV-134: a random road event whose clock runs out in 2 s (as if the player were watching), to see the crew's pick
func event_quick_timeout() -> void:
	var ids := Data.EVENTS.keys()
	event(str(ids[randi() % ids.size()]))
	var hud = get_tree().current_scene.get("hud") if get_tree().current_scene else null
	if hud and hud.event_popup.is_open:
		hud.event_popup.decide_total = maxf(hud.event_popup.decide_total, 2.0)
		hud.event_popup.decide_left = 2.0
		hud.event_popup.since_input = 0.0


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
	return JSON.stringify(Account.envelope(Game.s))


## turn the running account back into an old one-run save (v1, peaceful / hard / fuel_scarce) and load it,
## so testers can watch the account migration and its one-time notice
func account_v1_reload() -> void:
	act("account v1 reload")
	Game.save_game()
	var v1: Dictionary = Account.envelope(Game.s).main.duplicate(true)
	for k in Account.SHARED:
		var val = Account.a.get(k)
		if val is Dictionary or val is Array:
			v1[k] = val.duplicate(true)
	v1.mode = {"id": "peaceful", "diff": "hard", "mut": ["fuel_scarce"], "started_at": float(Account.a.get("created_at", 0.0))}
	Game.started = false
	Save.write(v1)
	if Game.load_game():
		_vehicle_changed()


func import_save(text: String) -> bool:
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary) or not Account.vehicle_of(parsed).has("rooms"):
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


## contextual tips (MV-150): forget which tips were seen; read-only for the save (not cheated)
func tips_reset() -> void:
	Trace.rec("god", "tips reset")
	Tutorial.reset_tips()


## show one tip now: forget it, then open its window (event / encounter tips show on the next pop-up)
func tip_show(k: String) -> void:
	Trace.rec("god", "tip show " + k)
	if not Game.s.is_empty() and Game.s.get("tutorial") is Dictionary:
		(Game.s.tutorial.get("tips", []) as Array).erase(k)
	var hud = get_tree().current_scene.get("hud") if get_tree().current_scene else null
	if hud and hud.panels.has(k) and k != "god":
		hud.open_panel(k)


# ---- construction & builders
## a refugee with the builder role (hard hat) and, optionally, one construction trait
func spawn_builder(build_trait: String = "") -> Dictionary:
	var d := Game.recruit_random()
	if Crew.is_roster(str(d.variant)):
		# a GOD builder always wears the hard hat: a named crew member rolled here becomes an ordinary builder
		d.variant = "dw_builder_%s" % Data.HAIRS[randi() % Data.HAIRS.size()]
		d.name = str(Data.TITLES.builder) + str(Data.FIRST_NAMES[randi() % Data.FIRST_NAMES.size()])
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
	if Crew.is_roster(str(d.variant)):
		return      # MV-170 named crew keep their own look as builders
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


## player logs (MV-116): send the queued trace entries now; read-only for the save (not cheated)
func logs_flush() -> bool:
	Trace.rec("god", "logs flush", {"queued": Telemetry.pending().size()})
	var ok: bool = await Telemetry.flush()
	Game.toast.emit("ส่ง log แล้ว" if ok else "ส่ง log ไม่ได้: " + (Telemetry.last_error if Telemetry.last_error != "" else "ยังไม่พร้อม"), "info" if ok else "warn")
	return ok


## a fake error entry, sent straight away: checks that errors reach the logs table and the dashboard views
func logs_test_error() -> bool:
	Trace.rec("error", "GOD test error (ignore)", {"kind": "test"})
	return await logs_flush()


## MV-174: what the offline catch-up would give if saved_at had been moved back 4 hours, with and without the
## server cap. Read-only (nothing in the save changes), so the save is not marked as cheated. {client, capped}
func anticheat_time_test() -> Dictionary:
	var now := Cloud.now()
	var faked := float(Game.s.get("saved_at", now)) - 4 * 3600.0
	var r := {"client": Game.offline_elapsed(faked, now), "capped": Game.offline_elapsed(faked, now, Cloud.server_seen if Features.on("anticheat") else 0.0)}
	Trace.rec("god", "anticheat time test", r)
	Game.toast.emit("แก้ saved_at ย้อน 4 ชม.: ได้ %d นาที ถ้าไม่มีกันโกง · ได้ %d นาที เมื่อเทียบเวลาเซิร์ฟเวอร์%s" % [int(r.client / 60.0), int(r.capped / 60.0),
		"" if Cloud.server_seen > 0.0 else " (คลาวด์ยังไม่ตอบ จึงยังจำกัดไม่ได้)"], "info")
	return r


## MV-174: two uploads back to back; the server should refuse the second (too soon) and the save stays queued.
## Read-only for the save.
func anticheat_rate_test() -> int:
	Trace.rec("god", "anticheat rate test")
	var before := Cloud.rate_limited
	Cloud.meta.dirty = true
	await Cloud.upload()
	Cloud.meta.dirty = true
	await Cloud.upload()
	var hit := Cloud.rate_limited - before
	Game.toast.emit("เซิร์ฟเวอร์ปฏิเสธการเซฟที่ถี่เกิน %d ครั้ง%s" % [hit, "" if hit > 0 else " (ยังไม่ได้รัน 0006_anticheat.sql?)"], "info" if hit > 0 else "warn")
	return hit


## copy "player id · full auth user id" for support lookups (MV-115); read-only, so the save stays ranked
func player_id_copy() -> String:
	var t := "%s · %s" % [Cloud.player_id() if Cloud.player_id() != "" else "-", Cloud.user_id() if Cloud.user_id() != "" else "-"]
	DisplayServer.clipboard_set(t)
	Trace.rec("god", "copy player id", {"pid": Cloud.player_id()})
	Game.toast.emit("คัดลอกแล้ว: " + t, "info")
	return t


## save, then reload the page like a player pressing refresh (checks resume_on_reload + staying logged in)
func reload_page() -> void:
	act("reload page")
	Game.save_game()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("location.reload()", true)
	else:
		Game.toast.emit("รีเฟรชหน้าได้เฉพาะบนเว็บ", "info")


func settings_reset() -> void:
	act("settings reset")
	Settings.reset_defaults()


# ---- game modes (Game.s.mode; switching mid-run marks the save as cheated = never ranked)
func mode_set(id: String = "", diff: String = "", toggle_mut: String = "") -> void:
	var cur: Dictionary = Modes.m()
	var mu: Array = (cur.get("mut", []) as Array).duplicate()
	if toggle_mut != "":
		if mu.has(toggle_mut):
			mu.erase(toggle_mut)
		else:
			mu.append(toggle_mut)
	act("mode %s / %s / %s" % [id, diff, toggle_mut])
	Modes.set_mode({"id": id if id != "" else Modes.id(), "diff": diff if diff != "" else Modes.diff(), "mut": mu})
	Game.toast.emit("โหมด: " + Modes.label(), "info")


## peaceful: jump to the checkpoint with the toll in hand
func mode_toll_test() -> void:
	act("mode toll test")
	Game.s.km = Game.biome_end_km()
	Game.s.res.scrap = float(Modes.toll()) + 10.0
	Game.travel_changed.emit()


# ---- version channel (MV-111)
## preview another channel's ALPHA/BETA/RC badge on the title + About ("" = the real channel); not saved
func channel_preview(ch: String) -> void:
	act("channel preview %s" % (ch if ch != "" else "off"))
	BuildInfo.channel_preview = ch if BuildInfo.CHANNELS.has(ch) else ""
	Features.changed.emit()


## switch the language for testing (MV-151): English also turns the "english" switch on for this tester
func lang_set(l: String) -> void:
	Trace.rec("god", "language %s" % l)
	if l == "en":
		Features.set_override("features", "english", true)
	Settings.set_value("lang", l)
	Loc.apply()


## show another environment's badge (MV-112); the servers in use never change ("" = the real one)
func env_preview(e: String) -> void:
	Trace.rec("god", "env preview %s" % (e if e != "" else "off"))
	BuildInfo.env_preview = e if BuildInfo.ENVS.has(e) else ""
	Features.changed.emit()


# ---- feature switches (Features layer "dev": kept in user://dev.cfg until reset or GOD is hidden)
func feature_set(key: String, v: Variant) -> void:
	act("feature %s = %s" % [key, v])
	Features.set_override("features", key, v)


func event_set(id: String, v: Variant) -> void:
	act("event %s on = %s" % [id, v])
	if v == null:
		Features.set_override("events", id, null)
	else:
		Features.set_event_on(id, bool(v))


func tune_set(key: String, v: Variant) -> void:
	act("tune %s = %s" % [key, v])
	Features.set_override("tune", key, v)


func features_reset() -> void:
	act("features reset overrides")
	Features.clear_overrides()


func features_refetch() -> void:
	act("features refetch remote")
	Features.fetch_remote()


# ---- announcement strip (MV-188)
## put a test message on the top strip (not remembered as seen, so it can be shown again)
func announce_test(text: String = "") -> void:
	Trace.rec("god", "announce test")
	Announce.push(text if text != "" else "ประกาศทดสอบ: ปิดปรับปรุงเซิร์ฟเวอร์ 22:00-22:30 น. เซฟของทุกคนปลอดภัย ขอบคุณที่เล่น Apocarlypse!")


## the "new version" notice as a player would see it after a deploy (tap = save + reload the page)
func announce_update_test() -> void:
	Trace.rec("god", "announce update notice")
	Announce.push_update(BuildInfo.GAME_VERSION)


## fetch features.json + version.json now (web) instead of waiting for announce.poll_min
func announce_poll() -> void:
	Trace.rec("god", "announce poll")
	Announce.poll()


## forget which messages this browser has seen, so the features.json ones show again
func announce_forget_seen() -> void:
	Trace.rec("god", "announce forget seen")
	Announce.seen.clear()
	Save.write_key(Announce.SEEN_KEY, Announce.SEEN_PATH, "[]")
	Announce.collect()
