extends Node
## Dev-only smoke test (excluded from exports). Run:
##   godot --path . -- --autotest [--out=/abs/dir]
## Walks through every screen, fires events, fast-forwards the simulation, round-trips the save,
## takes screenshots, then quits. Errors show up in the console/log.

var main: Node
var out_dir := "user://autotest"
var n := 0
var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("[autotest] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_fails += 1


## prints the summary CI looks for and exits non-zero when a check failed (MV-110)
func _finish() -> void:
	print("[autotest] DONE fails=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	n += 1
	img.save_png("%s/%02d_%s.png" % [out_dir, n, name])
	print("[autotest] shot ", name)


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _run() -> void:
	Save.wipe()
	# road events wait for an answer during the run (the scripted taps would otherwise start their clock and a random
	# event could time out in the middle of another test); _qte_test turns the clock on for itself (MV-134)
	Settings.set_value("event_timer", "off")
	await wait(1.2)
	await shot("title")
	_title_backdrop_test()
	main.hud.title_screen._settings_btn.pressed.emit()
	await wait(0.6)
	_check("settings: title menu button opens it", main.hud.settings_panel.is_open and main.hud.settings_panel.visible)
	await shot("title_settings")
	main.hud.settings_panel.close()
	await wait(0.3)
	main.hud.title_screen._go(true)
	await wait(2.5)
	if "--only=touch" in OS.get_cmdline_user_args():
		Tutorial.skip()
		# the full run reaches the touch test in this landscape window; at the default 405x720 the UI scale is 1,
		# so wide = normal = auto and the pinch checks have no zoom level to step to (MV-172)
		get_window().size = Vector2i(1280, 640)
		await wait(1.2)
		await _touch_test()
		_finish()
		return
	if "--only=large" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _large_room_test()
		_finish()
		return
	if "--only=ambience" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _ambience_test()
		_finish()
		return
	if "--only=version" in OS.get_cmdline_user_args():
		await _version_test()
		_finish()
		return
	if "--only=anticheat" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _anticheat_test()
		_finish()
		return
	if "--only=tips" in OS.get_cmdline_user_args():
		await _tips_test()
		_finish()
		return
	if "--only=qte" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _qte_test()
		_finish()
		return
	if "--only=creatures" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _creatures_test()
		_finish()
		return
	if "--only=english" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _english_test()
		_finish()
		return
	if "--only=env" in OS.get_cmdline_user_args():
		await _env_test()
		_finish()
		return
	if "--only=crew" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _crew_roster_test()
		_finish()
		return
	if "--only=shake" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _shake_test()
		await _engine_shake_test()
		_finish()
		return
	if "--only=announce" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _announce_test()
		_finish()
		return
	if "--only=thai" in OS.get_cmdline_user_args():
		_thai_terms_test()
		_finish()
		return
	await _tutorial_test()
	await shot("main_industrial_rain")
	Combat.reset_wave(6)
	Threat.force_raid()
	await wait(6.0)
	await shot("combat_wave")
	await wait(1.2)
	await shot("combat_wave_b")
	# give the squad a pile of loot so the gear screens have content
	for i in 14:
		Loot.add_to_stash(Loot.roll_random(6 + i, 50.0, i % 6))
	Game.s.items.components = 400
	Game.gear_changed.emit()
	Combat.reset_wave(10)
	await wait(8.0)
	await shot("combat_boss")
	main.hud.open_panel("squad")
	await wait(0.6)
	await shot("panel_squad")
	main.hud.panels.squad.tab = "vault"
	main.hud.panels.squad.refresh()
	await wait(0.4)
	await shot("panel_squad_vault")
	main.hud.panels.squad.close()
	await wait(0.4)
	main.hud.open_panel("inventory")
	await wait(0.6)
	await shot("loot_grid")
	main.hud.panels.inventory.detail_uid = int(Loot.stash()[-1].uid)
	main.hud.panels.inventory.refresh()
	await wait(0.4)
	await shot("loot_detail")
	main.hud.panels.inventory.tab = "forge"
	main.hud.panels.inventory.refresh()
	await wait(0.4)
	await shot("loot_forge")
	await _loot_tabs_test()
	main.hud.panels.inventory.close()
	await wait(0.4)
	main.hud.open_loot_pick("weapon", int(Game.s.squad[0]))
	await wait(0.6)
	await shot("loot_pick_weapon")
	main.hud.panels.inventory.close()
	await wait(0.4)
	# room close-up
	main.open_closeup(1)
	await wait(1.0)
	await shot("closeup_kitchen")
	main.hud.room_closeup.close()
	await wait(0.8)
	main.open_closeup(3)
	await wait(1.0)
	await shot("closeup_empty_build")
	main.hud.room_closeup.close()
	await wait(0.6)
	# build hydroponics via placement
	Game.s.res.scrap = 600.0
	main._enter_placement("hydroponics")
	await wait(0.5)
	await shot("placement_mode")
	Game.build_room(3, "hydroponics")
	main._exit_placement()
	await _construction_checks()
	# panels
	for k in ["dwellers", "build", "map", "solar"]:
		main.hud.open_panel(k)
		await wait(0.6)
		await shot("panel_" + k)
		main.hud.panels[k].close()
		await wait(0.3)
	main.hud.open_panel("dwellers")
	main.hud.panels.dwellers.manage(int(Game.s.squad[1]))
	await wait(0.5)
	await shot("dweller_manage")
	main.hud.panels.dwellers.close()
	await wait(0.4)
	# logbook + lore unlocks + idle chatter
	Lore.unlock("signal")
	Lore.unlock("khaotang")
	main.hud.open_panel("log")
	await wait(0.5)
	await shot("panel_log")
	main.hud.panels.log.open_id = "ember_fall"
	main.hud.panels.log.refresh()
	await wait(2.5)
	await shot("log_reader")
	main.hud.panels.log.tab = "crew"
	main.hud.panels.log.open_id = ""
	main.hud.panels.log.refresh()
	await wait(0.4)
	await shot("log_crew")
	main.hud.panels.log.close()
	await wait(0.4)
	var acts: Array = main.vehicle.all_actors()
	if not acts.is_empty():
		main.chatter.say(acts[0], "ข้าวตังกัดรองเท้าฉันอีกแล้ว")
	await wait(0.6)
	await shot("chatter")
	for ev in ["bunker", "signal", "gambler"]:
		Game.trigger_event(ev)
		await wait(0.6)
		await shot("event_" + ev)
		main.hud.event_popup._resolve(0)
		await wait(0.3)
		await shot("event_" + ev + "_result")
		main.hud.event_popup.close()
		await wait(0.3)
	# craft something
	Game.start_craft(1, "cook_meal")
	main.open_closeup(1)
	await wait(1.0)
	await shot("closeup_crafting")
	main.hud.room_closeup.close()
	await wait(0.6)
	# event: wolves -> fight
	Game.trigger_event("wolves")
	await wait(0.6)
	await shot("event_wolves")
	main.hud.event_popup._choice = 0
	main.hud.event_popup._selected = [int(Game.s.dwellers[0].id)]
	main.hud.event_popup.refresh()
	await wait(0.3)
	await shot("event_defenders")
	main.hud.event_popup._resolve(0)
	await wait(0.4)
	await shot("event_result")
	main.hud.event_popup.close()
	Game.trigger_event("raiders")
	await wait(0.6)
	await shot("event_raiders")
	main.hud.event_popup._resolve(2)
	main.hud.event_popup.close()
	await wait(0.4)
	# biomes + weather + time of day
	var looks := [[1, "sandstorm", 0.45], [2, "storm", 0.78], [3, "acid_rain", 0.6], [4, "snow", 0.02], [5, "ashfall", 0.85], [0, "clear", 0.27]]
	for L in looks:
		Game.s.biome = L[0]
		Game.s.km = Data.biome_start_km(L[0]) + 0.5
		Game.s.vault_level = maxi(Game.s.vault_level, L[0] + 1)
		Game.s.tod = L[2]
		Game.biome_changed.emit(L[0], true)
		Game.force_weather(L[1])
		main.weather.light = Color.WHITE
		await wait(3.5)
		await shot("biome_%s_%s" % [Data.biome(L[0]).id, L[1]])
	# --- logic checks
	Game.s.biome = 0
	Game.s.vault_level = 1
	Game.s.km = Data.biome_start_km(1) - 0.01
	Game.s.res.power = 100.0
	Game.s.hull = 100.0
	Game.s.stall = 0.0
	Game.s.traveling = true
	Game.active_event = ""
	for i in 60:
		Game._simulate(1.0, true)
	Game.s.combat.boss_beaten = {}
	_check("checkpoint blocks (no boss kill)", Game.at_checkpoint() and Game.s.biome == 0)
	Game.s.combat.boss_beaten["0"] = true
	_check("checkpoint still blocks at vault Lv1", Game.at_checkpoint())
	Game.s.res.scrap = 900.0
	_check("frame upgrade", Game.upgrade_vault() and Game.s.vault_level == 2)
	for i in 30:
		Game._simulate(1.0, true)
	_check("enters desert after upgrade", Game.s.biome == 1)
	var new_slot: int = 4
	_check("new slot unlocked at Lv2", Game.is_slot_unlocked(new_slot) and Game.unlocked_slots().size() == mini(Data.SLOTS_PER_LEVEL[2], Game.main_slots() - 1) + 1)
	_check("first run is a camper van: 2 floors x 3 rooms", Game.tier() == "van" and Game.slot_count() == 6 and Game.s.rooms.size() == 6)
	_check("build quarters", Game.build_room(new_slot, "quarters") and Game.pop_cap() == Data.BASE_POP_CAP)
	Dev.finish_construction()
	_check("quarters add beds once built", Game.pop_cap() == Data.BASE_POP_CAP + 4)
	# v4.6: the engine lives in the cab, so cell 0 behind it is a free room cell
	Game.s.res.scrap = 600.0
	_check("cell behind the cab is a room cell", Game.is_slot_unlocked(Data.ENGINE_SLOT) and Game.s.rooms[Data.ENGINE_SLOT].type != "engine")
	Meta.add_blueprint("bp_workshop")
	var ws := -1
	for sl in Game.unlocked_slots():
		if Game.s.rooms[sl].type == "empty":
			ws = sl
			break
	_check("build a workshop", ws >= 0 and Game.build_room(ws, "workshop"))
	Dev.finish_construction()
	for dw in Game.s.dwellers:
		if Game.squad_role(dw) < 0 and not Game.is_away(dw) and int(dw.room) != Data.CAB_SLOT:
			Game.assign(dw, ws)
			break
	_check("craft starts", Game.start_craft(ws, "patch_kit"))
	Game.s.hull = 50.0
	for i in 200:
		Game._simulate(1.0, true)
	_check("craft finished -> hull repaired", Game.s.rooms[ws].job.is_empty() and Game.s.hull >= 84.0)
	var d: Dictionary = Game.s.dwellers[1]
	Game.send_explore(d, 5)
	_check("explorer away", Game.is_away(d))
	d.away_until = Time.get_unix_time_from_system() - 1.0
	Game._simulate(1.0, true)
	_check("explorer returned", not Game.is_away(d))
	var rifle := Loot.roll_item("weapon", 5, 3, "assault_rifle")
	Loot.add_to_stash(rifle)
	Loot.equip_from_stash(int(rifle.uid), d)
	_check("equip gear", Loot.equipped_on(d, "weapon").get("uid", -1) == rifle.uid)
	Game.s.res.scrap = 999.0
	Game.s.items.components = 999
	_check("enhance +1", Loot.enhance(rifle) and int(rifle.plus) == 1)
	for i in 3:
		Loot.add_to_stash(Loot.roll_item("armor", 4, 1))
	_check("synthesize 3->1", Loot.synthesize(1).get("rar", -1) == 2)
	var sv := Loot.salvage_bulk(5)
	_check("salvage", int(sv.count) >= 1)
	# the explorer is back with the new assault rifle: put them on the gun so ranged / flying enemies die too
	Game.set_squad(0, int(d.id))
	Combat.rebuild_heroes()
	# a fixed wave of plain Lv1 desert mobs (a walker + a flyer). A real raid here is Lv21 with random elites and
	# mutants: this 2-hero squad wiped before its first kill in ~6% of rolls (17/300 seeds), MV-172
	Combat.debug_spawn([{"t": 0.3, "mob": "scorpion", "lvl": 1, "no_mutate": true},
		{"t": 0.8, "mob": "vulture", "lvl": 1, "no_mutate": true}], false)
	var kills0 := int(Game.s.combat.kills)
	for i in 600:
		Combat.tick(0.1)
	var killed := int(Game.s.combat.kills) - kills0
	_check("combat kills enemies (%d of 2)" % killed, killed == 2)
	var r := Game.resolve_event("trader", 2, [])
	_check("event resolve", r.ok)
	_check("6 hero gear slots", Loot.HERO_SLOTS.size() == 6 and Loot.HERO_SLOTS.has("backpack"))
	var pack := Loot.roll_item("backpack", 10, 2, "military_ruck")
	Loot.add_to_stash(pack)
	Loot.equip_from_stash(int(pack.uid), d)
	_check("backpack supply stat", float(Combat.hero_stats(d, 0).get("supply", 0.0)) > 0.0)
	_check("lore unlocked by event", Lore.is_unlocked("signal") and Lore.count_open() >= 5)
	_check("dialog line", Lore.pick_line(d, RandomNumberGenerator.new()) != "")
	_check("bio", str(Lore.bio(Game.s.dwellers[0]).text) != "")
	_check("6 biomes + bosses", Data.BIOMES.size() == 6 and Combat.BOSSES.size() == 6)
	print("[autotest] logic checks done: %d failed" % _fails)
	# fast-forward 30 minutes of idle simulation
	var t0 := Time.get_ticks_msec()
	for i in 180:
		Game._simulate(10.0, true)
	print("[autotest] 30min sim in %d ms; km=%.2f res=%s dwellers=%d" % [Time.get_ticks_msec() - t0, Game.s.km, Game.s.res, Game.s.dwellers.size()])
	# save round-trip
	Game.save_game()
	var before := JSON.stringify(Game.s)
	Game.load_game()
	print("[autotest] save roundtrip ok=", JSON.stringify(Game.s).length() > 100, " size=", before.length())
	# --- v3/v4 systems: mods on the vehicle, skill tree, hazards, synergy, weight, morale, pets, mutations, tiers
	Game.s.res.scrap = 99999.0
	Game.s.items.components = 9999
	Game.s.vault_level = 4
	for bp in ["bp_roof_turret", "bp_tracks", "bp_solar_covers", "bp_rad_shield", "bp_heater", "bp_engine_tune"]:
		Meta.add_blueprint(bp)
	var ok_all := true
	for id in ["spike_ram", "spike_ram", "spike_ram", "roof_turret", "roof_turret", "fuel_tanks", "fuel_tanks",
			"tracks", "armor_plates", "armor_plates", "solar_covers", "rad_shield", "rain_catcher", "heater",
			"suspension", "suspension", "offroad_wheels", "engine_tune"]:
		ok_all = Mods.install(id) and ok_all
	Mods.mods_changed.emit()
	_check("install exterior mods", ok_all and Mods.level("spike_ram") == 3 and Mods.level("tracks") == 1)
	_check("fuel cap grows with tanks", Env.fuel_cap() > 60.0)
	var sk: Dictionary = Game.s.dwellers[0]
	sk.lvl = 8
	_check("skill learn", Skills.learn(sk, "c1") and Skills.rank(sk, "c1") == 1)
	_check("traits rolled", Crew.traits(sk).size() >= 1)
	Game.s.biome = 4
	Game.s.tod = 0.9
	_check("tundra night needs heating fuel", Env.heating_fuel_pm() > 0.0)
	# room synergy: the cab engine next to quarters (cell 0 behind it) = noise; engine next to workshop = faster repairs
	var cell0_type: String = Game.s.rooms[Data.ENGINE_SLOT].type
	Game.s.rooms[Data.ENGINE_SLOT].type = "quarters"
	var noisy := Synergy.happy_mod(Data.ENGINE_SLOT)
	Game.s.rooms[Data.ENGINE_SLOT].type = "workshop"
	Meta.add_blueprint("bp_workshop")
	_check("synergy: engine noise next to quarters", noisy < 0.0)
	_check("synergy: engine + workshop repairs +15%", Synergy.repair_bonus() > 1.1)
	Game.s.rooms[Data.ENGINE_SLOT].type = cell0_type
	Game.s.rooms[1].type = "kitchen"
	# weight / drivetrain
	var w0 := Haul.weight()
	var es := -1
	for i in Game.s.rooms.size():
		if Game.s.rooms[i].type == "empty":
			es = i
	Game.s.rooms[es].type = "medical"
	_check("weight grows with rooms", es >= 0 and Haul.weight() > w0 and Haul.capacity() > float(Game.vehicle_def().engine))
	Game.s.rooms[es].type = "empty"
	# morale: strike then theft + desertion
	var grumpy := Game._add_dweller({"name": "ทดสอบหนี", "variant": "dw_raider_black", "str": 3, "int": 3, "agi": 3, "lvl": 1})
	grumpy.happy = 5.0
	for i in 12:
		Crew.morale_tick(grumpy, 10.0, false)
	_check("morale: strike when unhappy", grumpy.get("strike", false))
	var food0 := float(Game.s.res.food)
	for i in 20:
		Crew.morale_tick(grumpy, 10.0, false)
	Crew.flush_deserters()
	_check("morale: deserter steals and leaves", not Game.s.dwellers.has(grumpy) and float(Game.s.res.food) < food0)
	# pets live on the vehicle
	var adopt := Game.resolve_event("stray_cat", 0, [])
	_check("adopt a pet", adopt.ok and Game.has_pet("cat"))
	# blackout lighting
	Game.s.outage = {"1": 60.0}
	_check("short circuit darkens a room", Game.room_dark(1) and Game.outage_mult(1) < 1.0)
	# mutations + boss roster
	Game.s.biome = 3
	_check("mutation chance grows with distance", Combat.mutation_chance() > 0.15)
	var bosses := {}
	for w in [10, 20, 30, 40, 50, 60]:
		bosses[Combat.pick_wave_boss(w)] = true
	_check("boss waves rotate through different bosses", bosses.size() >= 4)
	Game.s.biome = 0
	Game.s.tod = 0.4
	Game.s.weather = "clear"
	Game.weather_changed.emit("clear")
	Game.s.outage = {"2": 40.0}
	main.pan_x = 0.0
	Expedition.skip_site()
	_no_events()
	for k in main.hud.panels:
		if main.hud.panels[k].is_open:
			main.hud.panels[k].close()
	await wait(2.0)
	await shot("van_mods_pets_blackout")
	main.open_closeup(2)
	await wait(1.2)
	await shot("closeup_blackout_torches")
	main.hud.room_closeup.close()
	await wait(0.8)
	Game.s.outage = {}
	main.hud.open_panel("garage")
	await wait(0.6)
	await shot("panel_garage_weight")
	main.hud.panels.garage.close()
	main.hud.open_skills(int(sk.id))
	await wait(0.6)
	await shot("panel_skills")
	main.hud.panels.skills.close()
	await wait(0.3)
	# boss fight: big HP bar + wide auto zoom
	_no_events()
	Combat.reset_wave(20)
	Threat.force_raid(1)
	await wait(5.0)
	await shot("boss_fight_bar")
	await wait(4.0)
	await shot("boss_fight_gore")
	Combat.reset_wave(1)
	# X-ray toggle: closed hull
	main.vehicle.set_xray(false)
	await wait(1.2)
	await shot("exterior_view")
	main.vehicle.set_xray(true)
	# expedition at the dead supermarket
	Expedition.arrive("market")
	await wait(2.6)
	main.hud.open_expedition("market")
	await wait(0.6)
	await shot("expedition_plan")
	# a defence squad member goes on the trip: a save loaded from JSON holds the squad ids as floats
	var guard := Game.dweller_by_id(int(Game.s.squad[1]))
	Game.s.squad = JSON.parse_string(JSON.stringify(Game.s.squad))
	_check("squad role survives JSON floats", not guard.is_empty() and Game.squad_role(guard) == 1)
	var team_ids := [int(guard.id)]
	for dd in Game.s.dwellers:
		if not Game.is_away(dd) and team_ids.size() < 2 and not team_ids.has(int(dd.id)):
			team_ids.append(int(dd.id))
	var ep: ExpeditionPanel = main.hud.panels.expedition
	ep.open_site("market")
	ep.picked = team_ids.duplicate()
	ep.refresh()
	await wait(0.3)
	_check("planner tags defence squad member", _find_text(ep, "อยู่ในทีมป้องกันรถ"))
	await shot("expedition_plan_squad_tag")
	var started := Expedition.start("market", team_ids, {"food": 10, "water": 10, "stimpack": 1, "ammo": 0, "antibiotics": 0})
	_check("expedition start (team of 2)", started and Expedition.active())
	Game.s.exp.erase("enc")     # keep this run deterministic; encounters are tested in _encounter_test()
	_check("defence slot freed on expedition", int(Game.s.squad[1]) == -1 and Game.squad_role(guard) < 0)
	var sub := {}
	for dd in Game.s.dwellers:
		if not Game.is_away(dd) and Game.squad_role(dd) < 0:
			sub = dd
			break
	if not sub.is_empty():
		Game.set_squad(1, int(sub.id))
	_check("new member fills freed slot", not sub.is_empty() and int(Game.s.squad[1]) == int(sub.id))
	Game.set_squad(0, int(guard.id))
	_check("away member can't rejoin squad", Game.squad_role(guard) < 0)
	main.hud.panels.expedition.close()
	await wait(2.2)
	await shot("expedition_walkout")
	# live helmet-cam feed in the expedition panel: a search beat, then a fight beat
	var now_t := Time.get_unix_time_from_system()
	Game.s.exp.start = now_t - (7.0 + 2 * ExpeditionFeed.BEAT + 6.0)
	main.hud.open_expedition("market")
	await wait(1.2)
	var feed: ExpeditionFeed = main.hud.panels.expedition._feed
	_check("expedition feed built", feed != null and feed.member_status(0) != "")
	await shot("expedition_feed_search")
	var fb := -1
	for tries in 40:
		Game.s.exp.seed = 1000 + tries
		feed.setup()
		for b in range(1, 11):
			if feed.plan(b).fight:
				fb = b
				break
		if fb >= 0:
			break
	if fb >= 0:
		Game.s.exp.start = Time.get_unix_time_from_system() - (7.0 + fb * ExpeditionFeed.BEAT + float(feed.plan(fb).spawn) + 1.6)
		feed.setup()
	_check("expedition feed stages a fight", fb >= 0)
	await wait(0.2)
	await shot("expedition_feed_fight")
	await wait(2.2)
	await shot("expedition_feed_kill")
	_check("expedition log has entries", feed.log_lines(3).size() >= 2)
	for alt in ["stilt_town", "lab", "mine"]:
		Game.s.exp.site = alt
		feed.setup()
		await wait(0.5)
		await shot("expedition_feed_" + alt)
	Game.s.exp.site = "market"
	Game.s.exp.start = Time.get_unix_time_from_system() - 3.0
	feed.setup()
	await wait(0.6)
	await shot("expedition_feed_walkin")
	main.hud.panels.expedition.close()
	await wait(0.4)
	await wait(4.0)
	Game.s.exp.start = float(Game.s.exp.start) - 99999.0
	Expedition.tick(false)
	_check("expedition finished", not Expedition.active())
	await wait(1.6)
	if main.hud.panels.expedition.is_open:
		main.hud.panels.expedition.close()
	Expedition.skip_site()
	await _encounter_test()
	# the prestige ladder: van -> bus -> rig -> train, with a story screen
	Meta.m().legacy = 9999
	Meta.add_blueprint("bp_bus")
	_check("research the armoured bus", Meta.buy("tier_bus") and Meta.best_tier() == "bus")
	main.hud.open_nextgen(false)
	await wait(1.5)
	await shot("nextgen_story")
	main.hud.panels.nextgen.close()
	Meta.next_generation([int(Game.s.dwellers[0].id)])
	_no_events()
	await wait(1.5)
	_check("gen 2 is a bus: 3 floors / 9 rooms", Game.tier() == "bus" and Game.slot_count() == 9 and main.vehicle.room_views.size() == 9)
	await shot("gen2_bus")
	Meta.add_blueprint("bp_rig")
	Meta.add_blueprint("bp_train")
	Meta.buy("tier_rig")
	Meta.buy("tier_train")
	Meta.next_generation([int(Game.s.dwellers[0].id)], "train")
	_no_events()
	await wait(1.0)
	Game.s.vault_level = 6
	Game.s.res.scrap = 9000.0
	Game.s.items.components = 9999
	Meta.add_blueprint("bp_trailer")
	_check("hitch two wagons to the train", Mods.add_trailer() and Mods.add_trailer() and Game.slot_count() == 24)
	Game.vault_level_changed.emit(6)
	main.set_zoom_mode("wide")
	await wait(1.6)
	await shot("train_two_wagons_wide")
	main.set_zoom_mode("auto")
	# ---- tester console (god mode) + trace log
	_check("dev tools unlocked in debug builds", Dev.unlocked)
	# release builds: the hidden 7-tap unlock on the VAULT chip (real input events through the GUI)
	Dev.unlocked = false
	Dev.changed.emit()
	var chip: Control = main.hud.lvl_lbl.get_parent()
	var cpos := chip.get_global_rect().get_center()
	var cpos_win: Vector2 = chip.get_viewport().get_screen_transform() * chip.get_global_transform_with_canvas().origin + chip.size * 0.5 * chip.get_viewport().get_screen_transform().get_scale()
	for k in 7:
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = cpos_win
			ev.global_position = cpos_win
			Input.parse_input_event(ev)
			await get_tree().process_frame
		await wait(0.12)
	await wait(0.3)
	print("[autotest] chip at ", cpos, " window ", cpos_win, " unlocked=", Dev.unlocked)
	_check("secret 7-tap unlock on the VAULT chip", Dev.unlocked and main.hud._god_btn.visible)
	Dev.unlocked = true
	Dev.set_flag("free", true)
	var scrap_before := float(Game.s.res.scrap)
	var free_slot := -1
	for i in Game.s.rooms.size():
		if Game.is_slot_unlocked(i) and Game.s.rooms[i].type == "empty":
			free_slot = i
			break
	_check("god: free build", free_slot >= 0 and Game.build_room(free_slot, "kitchen") and is_equal_approx(float(Game.s.res.scrap), scrap_before))
	Dev.set_flag("free", false)
	Dev.set_tier("van")
	_check("god: swap chassis keeps trailers", Game.tier() == "van" and Game.slot_count() == 6 + 12 and main.vehicle.room_views.size() == 18)
	Dev.set_tier("train")
	Dev.set_flag("invincible", true)
	Dev.set_hull(0.1)
	await wait(0.2)
	_check("god: invincible refills hull", float(Game.s.hull) >= Game.hull_max() - 0.01)
	Dev.spawn_boss("mech_spider")
	await wait(1.5)
	var gb := Combat.current_boss()
	_check("god: spawn a chosen boss", not gb.is_empty() and str(gb.name).contains(str(Combat.WAVE_BOSSES.mech_spider.th)))
	await shot("god_boss_spawned")
	Dev.set_flag("one_hit", true)
	for k in 20:
		if Combat.current_boss().is_empty():
			break
		await wait(0.5)
	_check("god: one-hit kills", Combat.current_boss().is_empty())
	Dev.set_flag("one_hit", false)
	Dev.set_flag("invincible", false)
	Dev.set_speed(5.0)
	_check("god: game speed", is_equal_approx(Engine.time_scale, 5.0))
	Dev.set_speed(1.0)
	var exported := Dev.export_save()
	_check("god: save export/import round-trip", Dev.import_save(exported) and Game.tier() == "train")
	_check("trace: god actions + boss logged", Trace.filtered("god").size() >= 8 and Trace.filtered("combat").size() >= 1)
	_check("trace: build logged", Trace.filtered("build").size() >= 1)
	_check("trace: save marked as cheated", Game.s.stats.get("cheated", false))
	Dev.set_overlay(true)
	main.hud.open_panel("god")
	await wait(0.6)
	await shot("god_panel_main")
	main.hud.panels.god.tab = "fight"
	main.hud.panels.god.refresh()
	await wait(0.4)
	await shot("god_panel_fight")
	main.hud.panels.god.tab = "log"
	main.hud.panels.god.refresh()
	await wait(0.4)
	await shot("god_panel_log")
	main.hud.panels.god.tab = "veh"
	main.hud.panels.god.refresh()
	await wait(0.4)
	await shot("god_panel_vehicle")
	main.hud.panels.god.close()
	Dev.set_overlay(false)
	await _god_update_test()
	var this_session := Trace.entries.filter(func(e): return str(e.sid) == Trace.session)
	var errs := this_session.filter(func(e): return str(e.cat) == "error")
	print("[autotest] trace entries this session: %d, errors: %d" % [this_session.size(), errs.size()])
	for e in errs:
		print("[autotest] trace error: ", Trace.fmt_entry(e))
	print("[autotest] v3/v4 checks done: %d failed total" % _fails)
	await _roof_deck_test()
	_share_preview_test()
	# portrait phone
	get_window().size = Vector2i(780, 1688)
	var zm0: String = main.zoom_mode
	main.set_zoom_mode("auto")
	await wait(1.5)
	await shot("portrait")
	await _portrait_fit_test()
	main.open_closeup(2)
	await wait(1.0)
	await shot("portrait_closeup")
	main.hud.room_closeup.close()
	await wait(0.8)
	main.hud.open_panel("dwellers")
	await wait(0.6)
	await shot("portrait_dwellers")
	main.hud.panels.dwellers.close()
	await wait(0.4)
	Game.trigger_event("bridge")
	await wait(0.6)
	await shot("portrait_event")
	main.hud.event_popup._resolve(1)
	main.hud.event_popup.close()
	# back to a wide tablet/phone landscape
	main.set_zoom_mode(zm0)
	get_window().size = Vector2i(1280, 640)
	await wait(1.2)
	main.hud.open_panel("solar")
	await wait(0.6)
	await shot("wide_solar")
	main.hud.panels.solar.close()
	await wait(0.4)
	main.hud.open_panel("map")
	await wait(0.6)
	await shot("wide_map")
	main.hud.panels.map.close()
	await wait(0.4)
	await _engine_bay_test()
	await _touch_test()
	await _event_layout_test()
	await _inspection_test()
	await _threat_test()
	await _settings_test()
	_event_variety_test()
	await _cloud_test()
	await _cloud_account_test()
	await _logs_test()
	await _account_test()
	await _resume_test()
	await _large_room_test()
	await _ambience_test()
	await _features_test()
	await _modes_test()
	await _anticheat_test()
	await _version_test()
	await _env_test()
	await _english_test()
	await _shake_test()
	await _tips_test()
	await _qte_test()
	await _creatures_test()
	await _engine_shake_test()
	await _crew_roster_test()
	await _announce_test()
	_thai_terms_test()
	_finish()


## god mode actions for the newer systems (tutorial, construction, builders, squad, forge, event deck,
## encounters, strangers, cloud, settings) + every tab renders
func _god_update_test() -> void:
	var god = main.hud.panels.god
	# tutorial: replay, jump to a step, skip
	Dev.tutorial_skip()
	Dev.tutorial_goto("crew")
	_check("god: tutorial jump to a step (reopens a finished one)", Tutorial.active() and Tutorial.step_id() == "crew")
	Dev.tutorial_skip()
	_check("god: tutorial skip", not Tutorial.active())
	Dev.tutorial_restart()
	_check("god: tutorial replay", Tutorial.active() and Tutorial.step_id() == "welcome")
	Dev.tutorial_skip()
	# builders + traits
	var b := Dev.spawn_builder("engineer")
	_check("god: spawn builder with a construction trait", Crew.is_builder(b) and Crew.has(b, "engineer") and str(b.variant).begins_with("dw_builder_"))
	Dev.toggle_builder(b)
	_check("god: builder role off", not Crew.is_builder(b) and not str(b.variant).begins_with("dw_builder_"))
	Dev.reroll_traits(b)
	_check("god: reroll traits", Crew.traits(b).size() >= 1)
	# construction: half then finish
	var slot := -1
	for i in Game.s.rooms.size():
		if Game.is_slot_unlocked(i) and Game.s.rooms[i].type == "empty" and not Game.is_constructing(i):
			slot = i
			break
	if slot < 0:
		Game.s.rooms.append({"type": "empty", "level": 1, "job": {}})
		slot = Game.s.rooms.size() - 1
	Game.s.res.scrap = Game.cap("scrap")
	var started := Game.build_room(slot, "kitchen")
	var left0 := float(Game.build_info(slot).get("left", 0.0))
	Dev.construction_progress(0.5)
	_check("god: construction +50%", started and Game.is_constructing(slot) and absf(float(Game.build_info(slot).left) - left0 * 0.5) < 0.01)
	Dev.construction_progress(1.0)
	_check("god: construction finish", not Game.is_constructing(slot) and Game.s.rooms[slot].type == "kitchen")
	# defence squad
	Dev.squad_clear()
	_check("god: squad clear", (Game.s.squad as Array).all(func(x): return int(x) < 0))
	Dev.squad_auto()
	var filled := (Game.s.squad as Array).filter(func(x): return int(x) >= 0).size()
	_check("god: squad auto fill", filled >= mini(Combat.slots_unlocked(), 1))
	Dev.drop_gear(2, 6)
	Dev.squad_gear()
	_check("god: gear max +", Dev.gear_max_plus() >= 0)
	# items & forge
	var stim := int(Game.s.items.get("stimpack", 0))
	Dev.items_all(10)
	_check("god: every item +10", int(Game.s.items.get("stimpack", 0)) == stim + 10 and int(Game.s.items.get("dried_meat", 0)) >= 10)
	Dev.stash_clear()
	Dev.forge_kit()
	_check("god: forge kit (3 of each rarity)", Loot.synth_candidates(0).size() >= 3 and Loot.synth_candidates(Loot.RARITY.size() - 2).size() >= 3)
	_check("god: forge kit can be forged", not Loot.synthesize(0).is_empty())
	Dev.stash_clear()
	_check("god: stash clear", Loot.stash().is_empty())
	# road event deck
	Dev.event_deck_reset()
	_check("god: event deck reset", not Game.s.has("ev_bag") and not Game.s.has("ev_recent"))
	Dev.event_draw()
	var drawn := Game.active_event
	_check("god: draw next event card", drawn != "" and (Game.s.ev_recent as Array).back() == drawn)
	Game.cancel_event()
	await wait(0.3)
	main.hud.event_popup.close()
	# strangers: every kind × grade
	Dev.stranger_clear()
	Dev.stranger("mimic", "very_rare")
	Dev.stranger("raider", "rare")
	var q := Inspection.queue()
	_check("god: stranger of a chosen kind and grade", q.size() == 2 and q[0].kind == "mimic" and q[0].grade == "very_rare" and q[1].kind == "raider")
	Dev.stranger("thief", "rare")
	_check("god: stranger queue cap respected", Inspection.queue().size() == Inspection.MAX_QUEUE)
	Dev.stranger_clear()
	_check("god: stranger queue clear", Inspection.queue().is_empty())
	# encounters without an expedition running
	if Expedition.active():
		Dev.finish_expedition()
		await wait(0.6)
		if main.hud.panels.expedition.is_open:
			main.hud.panels.expedition.report = {}
			main.hud.panels.expedition.close()
	Dev.recruit(3)
	Dev.encounter_anywhere("vault")
	_check("god: force an encounter with no trip running", Expedition.active() and Encounter.pending() and Encounter.current_id() == "vault")
	await wait(0.6)
	await shot("god_encounter_forced")
	main.hud.encounter_popup.close()
	Encounter.choose(Encounter.def("vault").choices.size() - 1, true)
	Dev.encounter_recent_clear()
	_check("god: encounter history clear", Encounter.recent().is_empty())
	Dev.finish_expedition()
	await wait(0.6)
	if main.hud.panels.expedition.is_open:
		main.hud.panels.expedition.report = {}
		main.hud.panels.expedition.close()
	# cloud is off in tests: actions must be harmless
	Dev.cloud_sync()
	Dev.cloud_force_upload()
	_check("god: cloud actions are no-ops when the cloud is off", not Cloud.enabled())
	var fps0 = Settings.get_value("fps")
	Settings.set_value("fps", 30)
	Dev.settings_reset()
	_check("god: settings reset to defaults", Settings.get_value("fps") == Settings.DEFAULTS.fps)
	if fps0 != Settings.DEFAULTS.fps:
		Settings.set_value("fps", fps0)
	# every tab renders without errors
	main.hud.open_panel("god")
	for t in god.TABS:
		god.tab = t[0]
		god.refresh()
		await wait(0.25)
		if t[0] in ["res", "crew", "world", "sys"]:
			await shot("god_tab_" + str(t[0]))
	god.tab = "sys"
	god.refresh()
	_check("god: system tab shows version + tutorial + cloud", _find_text(god, "บทสอนเล่น") and _find_text(god, "เซฟคลาวด์") and _find_text(god, BuildInfo.GAME_VERSION))
	god.close()


## event windows: Thai text + choice buttons stay inside the frame (wide + portrait), outcome flair
func _event_layout_test() -> void:
	var pop: EventPopup = main.hud.event_popup
	for win in [Vector2i(1280, 640), Vector2i(720, 1280)]:
		get_window().size = win
		await wait(0.8)
		var tag := "wide" if win.x > win.y else "tall"
		for ev in ["radstorm", "cultists", "survivor"]:
			Game.active_event = ""
			Game.trigger_event(ev)
			await wait(0.7)
			var r := pop.box.get_global_rect().grow(1.0)
			var bad := _outside(pop.body, r)
			_check("event layout %s/%s: all text inside the window %s" % [tag, ev, bad], bad.is_empty())
			var btns := _find_type(pop.body, "ChoiceButton")
			_check("event layout %s/%s: one tall-enough button per choice" % [tag, ev], btns.size() == (Data.EVENTS[ev].choices as Array).size() and btns.all(func(b): return b.size.y >= b.get_combined_minimum_size().y - 0.5))
			await shot("event_layout_%s_%s" % [tag, ev])
		Game.s.res.food = maxf(float(Game.s.res.food), 50.0)
		Game.s.res.water = maxf(float(Game.s.res.water), 50.0)
		pop._resolve(1)   # survivor: give supplies -> food/water rows + happier crew
		await wait(1.4)
		var labels := _find_type(pop.body, "Label").map(func(l): return str(l.text))
		_check("event outcome %s: stamp fits the choice (gave supplies)" % tag, labels.has("SHARED") and not labels.has("SURVIVED"))
		_check("event outcome %s: food loss row counts to -15" % tag, labels.has("-15"))
		_check("event outcome %s: crew happiness chips" % tag, labels.any(func(t): return t.ends_with(":)")))
		_check("event outcome %s: inside window" % tag, _outside(pop.body, pop.box.get_global_rect().grow(1.0)).is_empty())
		await shot("event_outcome_%s" % tag)
		pop.close()
		await wait(0.3)
	get_window().size = Vector2i(1280, 640)
	await wait(0.6)


## names of visible controls under n that poke out of rect r horizontally
func _outside(n: Node, r: Rect2) -> Array:
	var out := []
	for c in n.get_children():
		if c is Control and c.is_visible_in_tree():
			var g: Rect2 = c.get_global_rect()
			if (c is Label or c is ChoiceButton) and (g.position.x < r.position.x or g.end.x > r.end.x):
				out.append("%s(%s)" % [c.get_class(), str(c.text).left(12) if c is Label else "btn"])
			out.append_array(_outside(c, r))
	return out


func _find_type(n: Node, cls: String) -> Array:
	var out := []
	for c in n.get_children():
		if c.get_class() == cls or (c.get_script() and c.get_script().get_global_name() == cls):
			out.append(c)
		out.append_array(_find_type(c, cls))
	return out


## v4.3 construction: build time, builder crew + traits, upgrades, rush, offline, save round-trip
func _construction_checks() -> void:
	var started := []
	var finished := []
	var on_start := func(sl: int, kind: String): started.append([sl, kind])
	var on_finish := func(sl: int, kind: String): finished.append([sl, kind])
	Game.construction_started.connect(on_start)
	Game.construction_finished.connect(on_finish)
	_check("build: placement starts a site, not a finished room", Game.is_site(3) and Game.s.rooms[3].type == "hydroponics" and Game.build_progress(3) < 0.05)
	_check("build: a site has no workers / production yet", Game.room_workers(3).is_empty() and Game.room_rate_pm(3).is_empty())
	_check("build: placement time shown", Game.build_time("hydroponics") > 60.0 and Game.fmt_time(65.0) == "1M05S")
	# builders: one refugee with the builder role, one clumsy helper
	var bob := Game._add_dweller({"name": "ช่างทดสอบ", "variant": "dw_builder_brown", "str": 6, "role": "builder"})
	bob.traits = ["engineer"]
	var klutz := Game._add_dweller({"name": "มือใหม่", "variant": "dw_scav_red", "str": 4})
	klutz.traits = ["clumsy"]
	_check("crew: builder role doubles+ construction speed", Crew.build_mult(bob) >= 2.3 and Crew.is_builder(bob))
	_check("crew: clumsy builds slower than average", Crew.build_mult(klutz) < 1.0)
	var idle_sp := Game.build_speed(3)
	Game.assign(bob, 3)
	_check("build: assigning a builder speeds the site up", Game.build_speed(3) > idle_sp + 1.0 and Game.site_crew(3).has(bob))
	Game.assign(klutz, 3)
	_check("build: site holds at most ROOM_WORKERS builders", not Game.assign(Game.s.dwellers[0], 3))
	main.open_closeup(3)
	await wait(1.6)
	await shot("construction_site_start")
	for i in 30:
		Game._simulate(1.0, false)
	await wait(1.4)
	await shot("construction_site_mid")
	main.hud.room_closeup.close()
	await wait(0.8)
	await shot("construction_site_world")
	var guard := 0
	while Game.is_constructing(3) and guard < 400:
		Game._simulate(1.0, false)
		guard += 1
	_check("build: site finishes over time", not Game.is_constructing(3) and finished.has([3, "build"]))
	_check("build: finished room works with its crew", Game.room_workers(3).size() == 2 and not Game.room_rate_pm(3).is_empty())
	# upgrade: keeps working at the old level until done
	Game.s.res.scrap = 900.0
	_check("upgrade: starts as construction", Game.upgrade_room(3) and Game.is_constructing(3) and not Game.is_site(3) and int(Game.s.rooms[3].level) == 1)
	_check("upgrade: room keeps producing meanwhile", not Game.room_rate_pm(3).is_empty() and not Game.upgrade_room(3))
	main.open_closeup(3)
	await wait(1.2)
	await shot("construction_upgrade")
	main.hud.room_closeup.close()
	Game.s.items["components"] = 500
	var comps := int(Game.s.items.components)
	var rc := Game.rush_cost(3)
	_check("rush: components finish it now", rc > 0 and Game.rush_build(3) and int(Game.s.rooms[3].level) == 2 and int(Game.s.items.components) == comps - rc)
	_check("upgrade: finished signal", finished.has([3, "upgrade"]))
	# architect discount
	var base_cost := Game.build_cost("kitchen")
	bob.traits = ["architect"]
	_check("crew: architect cuts build cost 15%", Game.build_cost("kitchen") == int(round(float(Data.room_def("kitchen").cost) * 0.85)) and base_cost == int(Data.room_def("kitchen").cost))
	bob.traits = ["engineer"]
	# offline progress finishes sites + save round trip keeps a site
	var free := -1
	for i in Game.s.rooms.size():
		if Game.is_slot_unlocked(i) and Game.s.rooms[i].type == "empty":
			free = i
			break
	var raised := free < 0
	if free < 0:
		Game.s.vault_level = 2
		Game.vault_level_changed.emit(2)
		for i in Game.s.rooms.size():
			if Game.is_slot_unlocked(i) and Game.s.rooms[i].type == "empty":
				free = i
				break
	Game.s.res.scrap = 900.0
	_check("build: second site + started signal", free >= 0 and Game.build_room(free, "quarters") and started.has([free, "build"]))
	var cap0 := Game.pop_cap()
	var js: Dictionary = JSON.parse_string(JSON.stringify(Game.s))
	_check("save: site survives JSON round-trip", str((js.rooms[free] as Dictionary).build.kind) == "build")
	_check("build: unfinished quarters add no beds", cap0 == Game.pop_cap())
	Game._offline_progress(1800.0)
	_check("offline: site finished while away", not Game.is_constructing(free) and Game.pop_cap() > cap0)
	Game.demolish_room(free)
	if raised:
		Game.s.vault_level = 1
		Game.vault_level_changed.emit(1)
	# old saves: rooms without the build key, Ton becomes a builder
	var old_room := {"type": "kitchen", "level": 1, "job": {}}
	Game.s.rooms[1] = old_room
	var ton: Dictionary = {}
	for d in Game.s.dwellers:
		if str(d.get("lore", "")) == "ton":
			ton = d
	if not ton.is_empty():
		ton.erase("role")
	Game._migrate()
	_check("migrate: rooms get an empty build slot", (Game.s.rooms[1] as Dictionary).has("build") and not Game.is_constructing(1))
	_check("migrate: Ton is the vault's builder", ton.is_empty() or Crew.is_builder(ton))
	# recruits: some arrive as builders in hi-vis gear
	var builders := 0
	for i in 40:
		var r := Game.recruit_random()
		if Crew.is_builder(r):
			builders += 1
			if builders == 1:
				_check("recruit: builder wears the builder outfit", str(r.variant).begins_with("dw_builder_"))
		Game.s.dwellers.erase(r)
	_check("recruit: builder role appears (~25%)", builders >= 3 and builders <= 22)
	Game.construction_started.disconnect(on_start)
	Game.construction_finished.disconnect(on_finish)
	Game.dwellers_changed.emit()
	Game.rooms_changed.emit()


## keep random road events from popping over the v4 screenshots
func _find_text(n: Node, s: String) -> bool:
	if n is Label and (n as Label).text.contains(s):
		return true
	for c in n.get_children():
		if _find_text(c, s):
			return true
	return false


func _no_events() -> void:
	Game.s.event_t = 1.0e9
	if Game.active_event != "":
		Game.active_event = ""
	if main.hud.event_popup.is_open:
		main.hud.event_popup.close()


## first-run tutorial: walk every step the way a player would, then start a clean run for the rest
func _tutorial_test() -> void:
	_check("tutorial starts on a new run", Tutorial.active() and Tutorial.step_id() == "welcome")
	await wait(1.5)
	await shot("tutorial_welcome")
	Tutorial.next()
	_check("tutorial: resources step", Tutorial.step_id() == "resources")
	await wait(1.5)
	await shot("tutorial_resources")
	Tutorial.next()
	_check("tutorial: waits for a room tap", Tutorial.step_id() == "tap_room")
	Tutorial.next()
	_check("tutorial: action steps ignore Next", Tutorial.step_id() == "tap_room")
	await wait(1.2)
	await shot("tutorial_tap_room")
	main.open_closeup(1)
	await wait(1.0)
	Tutorial.check()
	_check("tutorial: room close-up detected", Tutorial.step_id() == "closeup")
	await wait(1.2)
	await shot("tutorial_closeup")
	main.hud.room_closeup.close()
	await wait(0.8)
	Tutorial.check()
	_check("tutorial: build step + starter scrap", Tutorial.step_id() == "open_build" and float(Game.s.res.scrap) >= Tutorial.START_SCRAP)
	await wait(1.0)
	await shot("tutorial_open_build")
	main.hud.open_panel("build")
	await wait(0.6)
	Tutorial.check()
	_check("tutorial: build window detected", Tutorial.step_id() == "pick_room")
	await wait(1.2)
	await shot("tutorial_pick_room")
	main.hud.panels.build.close()
	await wait(0.3)
	Tutorial.check()
	_check("tutorial: closing the window steps back", Tutorial.step_id() == "open_build")
	main.hud.open_panel("build")
	await wait(0.4)
	Tutorial.check()
	main.hud.panels.build.close()
	main._enter_placement("quarters")
	await wait(0.5)
	Tutorial.check()
	_check("tutorial: placement detected", Tutorial.step_id() == "place_room")
	await wait(1.0)
	await shot("tutorial_place_room")
	var slot := Tutorial.free_slot()
	_check("tutorial: room built", slot >= 0 and Game.build_room(slot, "quarters"))
	main._exit_placement()
	Tutorial.check()
	if Tutorial.constructing_slot() >= 0:
		_check("tutorial: waits for construction", Tutorial.step_id() == "construct")
		await wait(1.0)
		await shot("tutorial_construct")
		for i in 400:
			if Tutorial.constructing_slot() < 0:
				break
			Game._simulate(5.0, false)
		Tutorial.check()
	_check("tutorial: crew step after the build", Tutorial.step_id() == "crew")
	await wait(1.0)
	await shot("tutorial_crew")
	main.hud.open_panel("dwellers")
	await wait(0.6)
	Tutorial.check()
	_check("tutorial: crew window detected", Tutorial.step_id() == "crew_info")
	await wait(1.5)
	await shot("tutorial_crew_info")
	Tutorial.next()
	main.hud.panels.dwellers.close()
	await wait(0.4)
	_check("tutorial: combat step", Tutorial.step_id() == "combat")
	await wait(1.8)
	await shot("tutorial_combat")
	Tutorial.next()
	_check("tutorial: travel step", Tutorial.step_id() == "travel")
	await wait(1.8)
	await shot("tutorial_travel")
	Tutorial.next()
	await wait(1.8)
	await shot("tutorial_done")
	Tutorial.next()
	_check("tutorial: completed", not Tutorial.active() and bool(Game.s.tutorial.done))
	Game.save_game()
	_check("tutorial: progress saved", bool(Account.account_of(Save.read()).get("tutorial", {}).get("done", false)))
	Tutorial.restart()
	_check("tutorial: replay from the logbook", Tutorial.active() and Tutorial.step() == 0)
	Tutorial.skip()
	_check("tutorial: skip", not Tutorial.active())
	# saves from before the tutorial existed never see it
	Game.s.erase("tutorial")
	Game.s.stats.km_total = 42.0
	Tutorial._on_game_started()
	_check("tutorial: old saves skip it", not Tutorial.active())
	# a clean run for the rest of the smoke test
	main._on_start(true)
	Tutorial.skip()
	await wait(1.5)


## settings window: every option applies + persists, version info, save export / validate / reset
func _settings_test() -> void:
	get_window().size = Vector2i(720, 1280)
	await wait(1.2)
	Settings.reset_defaults()
	_check("settings: Music + SFX buses exist", AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("SFX") > 0)
	Settings.set_value("master", 0.3)
	Settings.set_value("sfx", 0.5)
	_check("settings: master volume applied", absf(AudioServer.get_bus_volume_linear(0) - 0.3) < 0.01)
	_check("settings: sfx volume applied", absf(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("SFX")) - 0.5) < 0.01)
	Settings.set_value("mute", true)
	_check("settings: mute", AudioServer.is_bus_mute(0))
	Settings.set_value("fps", 30)
	_check("settings: 30 fps cap", Engine.max_fps == 30)
	Settings.set_value("crt", false)
	_check("settings: CRT filter off", not main.crt.visible)
	Settings.set_value("fx_gpu", false)
	_check("settings: CPU particles", not FX.use_gpu)
	Settings.set_value("shake", false)
	main._shake = 0.0
	main.shake(6.0)
	_check("settings: screen shake off", main._shake == 0.0)
	Settings.set_value("gore", false)
	var n0: int = main.combat_view.get_child_count()
	main.combat_view._gore(Vector2(100, 200), 8, true)
	main.combat_view._splat(Vector2(100, 200))
	_check("settings: gore off spawns nothing", main.combat_view.get_child_count() == n0)
	var s0: float = main.pixel_scale
	Settings.set_value("ui_scale", "small")
	await wait(0.5)
	_check("settings: smaller pixel scale", main.pixel_scale == maxf(1.0, s0 - 1.0))
	Settings.set_value("zoom", "wide")
	_check("settings: camera default", main.zoom_mode == "wide")
	main.cycle_zoom()
	_check("settings: zoom button remembered", Settings.get_value("zoom") == main.zoom_mode)
	# persisted apart from the save: reload from storage
	Settings.v = Settings.DEFAULTS.duplicate()
	Settings._load()
	_check("settings: persisted", is_equal_approx(float(Settings.get_value("master")), 0.3) and int(Settings.get_value("fps")) == 30 and Settings.get_value("gore") == false)
	Settings.reset_defaults()
	await wait(0.5)
	_check("settings: defaults restored", main.crt.visible and FX.use_gpu and Engine.max_fps == 60 and main.pixel_scale == s0)
	# version details
	_check("about: Godot 4.7.2-stable", BuildInfo.godot_version() == "4.7.2-stable")
	_check("about: version rows", BuildInfo.rows().size() >= 8 and BuildInfo.as_text().contains("Apocarlypse: Mobile Vault v" + BuildInfo.GAME_VERSION))
	_check("about: trace uses the game version", Trace.VERSION == BuildInfo.GAME_VERSION)
	# the window, each tab
	main.hud.open_settings()
	await wait(0.6)
	await shot("settings_game")
	(main.hud.settings_panel._list.get_parent() as ScrollContainer).scroll_vertical = 400
	await wait(0.3)
	await shot("settings_game_b")
	Settings.set_value("master", 0.6)
	await wait(0.2)
	_check("settings: tab not rebuilt on change", (main.hud.settings_panel._list.get_parent() as ScrollContainer).scroll_vertical > 0)
	Settings.reset_defaults()
	main.hud.settings_panel.open_tab("data")
	await wait(0.4)
	await shot("settings_data")
	main.hud.settings_panel.open_tab("about")
	await wait(0.4)
	await shot("settings_about")
	# save tools
	var path := Settings.export_save()
	_check("save: exported", path != "" and FileAccess.file_exists(path))
	var text := FileAccess.get_file_as_string(path)
	_check("save: export is a valid save", Settings.validate_save(text) == "")
	_check("save: junk rejected", Settings.validate_save("{\"hello\": 1}") != "" and Settings.validate_save("not json") != "")
	DirAccess.remove_absolute(path)
	main.hud.settings_panel._on_reset_pressed()
	_check("save: reset needs a second tap", Save.has_save())
	main.hud.settings_panel.close()
	await wait(0.3)
	Settings.reset_progress(false)
	_check("save: progress wiped", not Save.has_save() and not Game.started)
	# settings from the title menu
	main.hud.title_screen.modulate.a = 1.0
	main.hud.title_screen.visible = true
	main.hud.title_screen.refresh_buttons()
	main.hud.open_settings("about")
	await wait(0.6)
	await shot("settings_from_title")
	_check("settings: opens over the title menu", main.hud.settings_panel.visible and main.hud.settings_panel.get_index() > main.hud.title_screen.get_index())
	main.hud.settings_panel.close()


# ------------------------------------------------------------------ v4.4 expedition special encounters
func _enc_start(sup: Dictionary) -> bool:
	var ids := []
	for dd in Game.s.dwellers:
		if not Game.is_away(dd) and ids.size() < 2:
			ids.append(int(dd.id))
	Game.s.res.food = maxf(float(Game.s.res.food), 300.0)
	Game.s.res.water = maxf(float(Game.s.res.water), 300.0)
	Game.s.items["ammo"] = maxi(int(Game.s.items.get("ammo", 0)), 30)
	Game.s.items["stimpack"] = maxi(int(Game.s.items.get("stimpack", 0)), 5)
	var ok := Expedition.start("scav", ids, sup)
	if ok:
		Game.s.exp.erase("enc")
	return ok


func _enc_finish() -> Dictionary:
	var got := {}
	var cb := func(r): got.merge(r)
	Expedition.expedition_finished.connect(cb)
	# the save is JSON: ids/numbers come back as floats
	Game.s.exp = JSON.parse_string(JSON.stringify(Game.s.exp))
	Game.s.exp.start = float(Game.s.exp.start) - 99999.0
	Expedition.tick(false)
	Expedition.expedition_finished.disconnect(cb)
	await wait(0.6)
	if main.hud.panels.expedition.is_open:
		main.hud.panels.expedition.report = {}
		main.hud.panels.expedition.close()
	await wait(0.3)
	return got


func _encounter_test() -> void:
	var sup := {"food": 10, "water": 10, "stimpack": 1, "ammo": 10, "antibiotics": 0}
	_check("encounter: rare (under 30 percent per trip) even in the worst site", Encounter.chance_for("market") < 0.3 and Encounter.chance_for("helios") < 0.3 and Encounter.chance_for("market") > 0.05)
	Game.s["enc_recent"] = ["survivor", "vault", "floor"]
	var rep_bad := false
	for i in 200:
		if Encounter.pick(7) in ["survivor", "vault", "floor"]:
			rep_bad = true
	_check("encounter: never repeats one of the last 3", not rep_bad)
	var low_bad := false
	Game.s["enc_recent"] = []
	for i in 200:
		if Encounter.pick(1) in ["cry", "toxic"]:
			low_bad = true
	_check("encounter: dangerous ones stay out of easy sites", not low_bad)
	# 1) hidden survivor -> invite aboard: the refugee walks home with the team
	_check("encounter: expedition starts", _enc_start(sup))
	Encounter.trigger_now("survivor")
	await wait(0.8)
	_check("encounter: pops up while the team is out", Encounter.pending() and main.hud.encounter_popup.is_open)
	_check("encounter: remembered for anti-repeat", Encounter.recent().has("survivor"))
	await shot("encounter_survivor")
	main.hud.encounter_popup.close()
	main.hud._refresh_expedition()
	_check("encounter: HUD chip asks for orders", main.hud._exp_lbl.text.contains("จุดพิเศษ"))
	main.hud.panels.expedition.report = {}
	main.hud.open_expedition("scav")
	await wait(0.8)
	_check("encounter: expedition panel shows the radio button", main.hud.panels.expedition._enc_btn.visible)
	await shot("encounter_panel_button")
	main.hud.panels.expedition._enc_btn.pressed.emit()
	await wait(0.6)
	_check("encounter: radio button reopens the choice", main.hud.encounter_popup.is_open and not main.hud.panels.expedition.is_open)
	var pop0: int = Game.s.dwellers.size()
	var door0: int = Inspection.queue().size()
	var ch0: Dictionary = Encounter.def("survivor").choices[0]
	var room := Encounter.room_free()
	if room:
		main.hud.encounter_popup.choose(0)
		await wait(0.5)
		await shot("encounter_result")
		_check("encounter: invite resolves", not Encounter.pending() and int(Encounter.state().recruits) == 1)
	else:
		_check("encounter: invite blocked when bunks are full", Encounter.blocked(ch0) != "")
		main.hud.encounter_popup.choose(1)
		await wait(0.5)
		await shot("encounter_result")
		_check("encounter: share food spends packed supplies", int(Expedition.state().sup.food) == 0 and not Encounter.pending())
	await wait(1.4)
	var epop: EncounterPopup = main.hud.encounter_popup
	var etx: Array = _find_type(epop.body, "Label").map(func(l): return str(l.text))
	_check("encounter outcome: radio stamp", etx.has("MISSION SUCCESS") or etx.has("MISSION\nSUCCESS") or etx.has("MAYDAY"))
	_check("encounter outcome: haul/supply rows", _find_type(epop.body, "GridContainer").size() == 1 and (etx.has("+1") or etx.has("-10") or etx.any(func(t): return t.begins_with("-"))))
	_check("encounter outcome: inside window %s" % [_outside(epop.body, epop.box.get_global_rect().grow(1.0))], _outside(epop.body, epop.box.get_global_rect().grow(1.0)).is_empty())
	await shot("encounter_result_full")
	main.hud.encounter_popup.close()
	var r1 := await _enc_finish()
	_check("encounter: report carries the encounter", r1.has("enc") and str(r1.get("enc", {}).get("id", "")) == "survivor")
	var xp: ExpeditionPanel = main.hud.panels.expedition
	xp.report = r1
	xp.open()
	await wait(1.6)
	var rtx: Array = _find_type(xp.body, "Label").map(func(l): return str(l.text))
	_check("expedition report: stamp + crew chips", (rtx.has("MISSION SUCCESS") or rtx.has("MISSION\nSUCCESS") or rtx.has("FAILED") or rtx.has("LOST")) and rtx.has(">CREW"))
	_check("expedition report: gains + radio box", r1.has("gain") and rtx.has(">RADIO"))
	_check("expedition report: inside window", _outside(xp.body, xp.box.get_global_rect().grow(1.0)).is_empty())
	await shot("expedition_report")
	xp.report = {}
	xp.close()
	await wait(0.3)
	if room:
		# offer_recruit(.., 1.0) can send an exceptional refugee to the door for inspection instead (~15%)
		_check("encounter: refugee joined on return", Game.s.dwellers.size() == pop0 + 1 or Inspection.queue().size() == door0 + 1)
	# 2) buried safe -> pry it open: rare loot or an injury, plus extra time
	_check("encounter: second expedition starts", _enc_start(sup))
	Encounter.trigger_now("vault")
	await wait(0.6)
	var dur0 := float(Expedition.state().dur)
	var hp0 := 0.0
	for d in Expedition.team():
		hp0 += float(d.hp)
	var stash0: int = Loot.stash().size()
	Encounter.rng.seed = 7
	var res: Dictionary = Encounter.choose(0)
	var hp1 := 0.0
	for d in Expedition.team():
		hp1 += float(d.hp)
	_check("encounter: risky choice costs time", is_equal_approx(float(Expedition.state().dur), dur0 + 60.0))
	if res.ok:
		_check("encounter: pry success banks rare gear", int(Encounter.state().bonus.get("_gear_rare", 0)) == 1)
	else:
		_check("encounter: pry failure injures the explorer", hp1 < hp0)
	main.hud.encounter_popup.close()
	await _enc_finish()
	if res.ok:
		_check("encounter: rare gear delivered", Loot.stash().size() > stash0)
	# 3) toxic pharmacy: a choice the team didn't pack for is refused
	_check("encounter: third expedition starts", _enc_start(sup))
	Encounter.trigger_now("toxic")
	await wait(0.6)
	await shot("encounter_toxic")
	var dose: Dictionary = Encounter.def("toxic").choices[1]
	_check("encounter: needs antibiotics in the pack", Encounter.blocked(dose) != "")
	Encounter.choose(1)
	_check("encounter: refused choice keeps it open", Encounter.pending())
	main.hud.encounter_popup.close()
	# ...and nobody answers: the team plays it safe when it walks back
	var r3 := await _enc_finish()
	_check("encounter: unanswered -> team leaves it", str(r3.get("enc", {}).get("text", "")).begins_with("ทีมตัดสินใจเอง"))
	# 4) an encounter still scheduled when the trip ends never happens; old saves without one still finish
	_check("encounter: fourth expedition starts", _enc_start(sup))
	Encounter.roll("cry")
	Game.s.exp.enc.at = Time.get_unix_time_from_system() + 99999999.0
	var r4 := await _enc_finish()
	_check("encounter: scheduled-but-unreached is dropped", not r4.has("enc") and not Expedition.active())


## random road events: shuffle bag per biome, no back-to-back repeats, survives a save round-trip
func _event_variety_test() -> void:
	var keep := {}
	for k in ["biome", "ev_bag", "ev_bag_biome", "ev_recent"]:
		if Game.s.has(k):
			keep[k] = Game.s[k]
	Game.s.biome = 0
	for k in ["ev_bag", "ev_bag_biome", "ev_recent"]:
		Game.s.erase(k)
	var pool: Array = Data.biome(0).events
	var first: Array = []
	for i in pool.size():
		first.append(Game.next_event_id())
	var all_once := true
	for e in pool:
		if first.count(e) != 1:
			all_once = false
	_check("events: one bag shows every biome event once", all_once and first.size() == pool.size())
	var seq: Array = first.duplicate()
	for i in 300:
		if i == 137:
			# mid-bag save/load: the bag and history come back from JSON and keep going
			var back: Dictionary = JSON.parse_string(JSON.stringify(Game.s))
			for k in ["ev_bag", "ev_bag_biome", "ev_recent"]:
				Game.s[k] = back[k]
		seq.append(Game.next_event_id())
	var gap_ok := true
	var min_gap := 999
	for i in seq.size():
		for j in range(maxi(0, i - Game.EVENT_NO_REPEAT), i):
			if seq[j] == seq[i]:
				gap_ok = false
		var prev := -1
		for j in range(i - 1, -1, -1):
			if seq[j] == seq[i]:
				prev = j
				break
		if prev >= 0:
			min_gap = mini(min_gap, i - prev)
	_check("events: no repeat within %d draws (min gap %d)" % [Game.EVENT_NO_REPEAT, min_gap], gap_ok)
	var counts := {}
	for e in seq:
		counts[e] = int(counts.get(e, 0)) + 1
	var lo := 9999
	var hi := 0
	for e in pool:
		lo = mini(lo, int(counts.get(e, 0)))
		hi = maxi(hi, int(counts.get(e, 0)))
	_check("events: even spread over %d draws (min %d / max %d)" % [seq.size(), lo, hi], hi - lo <= 2)
	var rounds_differ := false
	for r in range(1, seq.size() / pool.size()):
		if seq.slice(r * pool.size(), (r + 1) * pool.size()) != first:
			rounds_differ = true
	_check("events: order changes between rounds (not a fixed pattern)", rounds_differ)
	var recent: Array = Game.s.ev_recent.duplicate()
	Game.s.biome = 1
	var next := Game.next_event_id()
	_check("events: biome change keeps the no-repeat window", next != "" and not recent.has(next) and Data.biome(1).events.has(next))
	for k in ["ev_bag", "ev_bag_biome", "ev_recent"]:
		Game.s.erase(k)
	Game.s.merge(keep, true)
	var d: Dictionary = Game.s.dwellers[0]
	var lrng := RandomNumberGenerator.new()
	var lines: Array = []
	for i in 6:
		lines.append(Lore.pick_line(d, lrng))
	var dup := false
	for i in range(1, lines.size()):
		if lines[i] == lines[i - 1]:
			dup = true
	_check("chatter: no line said twice in a row", not dup and lines[0] != "")


## v4.4 strangers at the door: rare elite recruits, circumstantial tells, inspection points, the call,
## delayed secrets (infected / mimic / thief / raider), JSON round-trip, timeout, UI screenshots
func _inspection_test() -> void:
	for k in Dev.flags:
		Dev.flags[k] = false
	Game.s.erase("insp")
	# rarity: ~6 % rare + ~1.5 % very rare of all recruit offers
	var rare := 0
	var vrare := 0
	for i in 20000:
		match Inspection.roll_grade():
			"rare": rare += 1
			"very_rare": vrare += 1
	_check("inspect: elite recruits are rare (%d rare / %d very rare of 20000)" % [rare, vrare],
		rare > 900 and rare < 1500 and vrare > 180 and vrare < 450)
	# every bad apple leaves at least one real clue; humans are mostly clean
	var clue_ok := true
	for kind in ["infected", "mimic", "thief", "raider"]:
		for i in 200:
			if Inspection._tell_count(kind, Inspection._roll_signs(kind)) < 1:
				clue_ok = false
	_check("inspect: impostors always show >= 1 tell", clue_ok)
	var flagged := 0
	for i in 400:
		var sg := Inspection._roll_signs("human")
		for chk in Inspection.CHECKS:
			if str(sg[chk]) != "normal":
				flagged += 1
				break
	_check("inspect: honest people sometimes look suspicious (%d/400)" % flagged, flagged > 40 and flagged < 300)
	# the recruit hook: an elite roll queues a stranger instead of boarding
	var n0: int = Game.s.dwellers.size()
	var r := Game.offer_recruit("test", 1000.0)
	_check("inspect: elite offer waits at the door", r.is_empty() and Inspection.pending() and Game.s.dwellers.size() == n0)
	Game.s.insp.queue.clear()
	var c := Inspection.queue_candidate("test", "very_rare", "mimic")
	_check("inspect: very rare stranger has a top stat + 3 good traits",
		int(c[str(c.best)]) >= 9 and (c.traits as Array).size() == 3 and (c.traits as Array).all(func(t): return not Crew.TRAITS[t].get("bad", false)))
	var pts := int(c.points)
	Inspection.check(c, "eyes")
	Inspection.check(c, "eyes")
	_check("inspect: a check costs one point, re-looking is free", int(c.points) == pts - 1 and c.seen.has("eyes"))
	for chk in Inspection.CHECKS:
		Inspection.check(c, chk)
	_check("inspect: can't check everything (points run out)", int(c.points) == 0 and c.seen.size() == pts and c.seen.size() < Inspection.CHECKS.size())
	# save round-trip: JSON turns ints into floats; the stranger must still work
	Inspection.queue_candidate("test", "rare", "thief")
	Game.s.insp = JSON.parse_string(JSON.stringify(Game.s.insp))
	var back := Inspection.queue()[1] as Dictionary
	var sg2 := Inspection.check(back, "story")
	_check("inspect: stranger survives a save round-trip", Inspection.queue().size() == 2 and sg2 != "" and int(back.points) == int(back.max_points) - 1)
	Inspection.queue_candidate("test", "rare", "human")
	_check("inspect: at most %d strangers wait" % Inspection.MAX_QUEUE, Inspection.queue().size() == Inspection.MAX_QUEUE)
	# open the door UI on the mimic and look at a detail
	main.hud.open_door()
	await wait(0.6)
	var panel: InspectionPanel = main.hud.panels.door
	_check("inspect: door panel opens", panel.is_open and _find_text(panel, str(Inspection.current().name)))
	panel._last_check = "eyes"
	panel.refresh()
	await wait(0.3)
	await shot("inspect_door")
	panel._guide = true
	panel.refresh()
	await wait(0.3)
	await shot("inspect_guide")
	panel.close()
	await wait(0.3)
	# turn away / shoot
	Game.s.insp.queue.clear()
	var h := Inspection.queue_candidate("test", "rare", "human")
	Game.s.dwellers[0].happy = 80.0
	var happy0 := 80.0
	var mem0 := (Game.s.get("memorial", []) as Array).size()
	Inspection.shoot(h)
	_check("inspect: shooting an innocent hurts morale + memorial", float(Game.s.dwellers[0].happy) <= happy0 - 19.0 and Game.s.memorial.size() == mem0 + 1)
	var th := Inspection.queue_candidate("test", "rare", "thief")
	var scrap0 := float(Game.s.res.scrap)
	Inspection.shoot(th)
	_check("inspect: shooting a thief recovers their loot", float(Game.s.res.scrap) > scrap0 and int(Game.s.insp.stats.caught) >= 1)
	var rf := Inspection.queue_candidate("test", "rare", "raider")
	_check("inspect: turning away clears the door", Inspection.refuse(rf) != "" and not Inspection.pending())
	# admitted impostors go off later
	while Game.s.dwellers.size() > Game.pop_cap() - 4:
		Game.s.dwellers.pop_back()
	for d in Game.s.dwellers:
		d.hp = d.max_hp
	var inf := Inspection.admit(Inspection.queue_candidate("test", "rare", "infected"))
	_check("inspect: admitted infected hides a secret", not inf.is_empty() and inf.has("secret") and not Crew.is_infected(inf))
	Inspection.tick(400.0, false)
	_check("inspect: infection breaks out later", Crew.is_infected(inf) and not inf.has("secret"))
	var food0 := float(Game.s.res.food)
	Game.s.res.food = maxf(food0, 100.0)
	food0 = float(Game.s.res.food)
	var thf := Inspection.admit(Inspection.queue_candidate("test", "rare", "thief"))
	thf.secret = JSON.parse_string(JSON.stringify(thf.secret))   # as loaded from a save
	Inspection.tick(400.0, false)
	_check("inspect: thief robs the larder and runs", not Game.s.dwellers.has(thf) and float(Game.s.res.food) < food0)
	var hull0 := float(Game.s.hull)
	var rd := Inspection.admit(Inspection.queue_candidate("test", "rare", "raider"))
	Inspection.tick(400.0, false)
	_check("inspect: raider mole sabotages the hull", not Game.s.dwellers.has(rd) and float(Game.s.hull) < hull0)
	var before: int = Game.s.dwellers.size()
	var mm := Inspection.admit(Inspection.queue_candidate("test", "rare", "mimic"))
	Inspection.tick(400.0, false)
	_check("inspect: mimic shows itself and leaves (maybe with a victim)", not Game.s.dwellers.has(mm) and Game.s.dwellers.size() <= before)
	var hm := Inspection.admit(Inspection.queue_candidate("test", "rare", "human"))
	Inspection.tick(400.0, false)
	_check("inspect: an honest elite just stays", Game.s.dwellers.has(hm) and not hm.has("secret") and int(hm.str) + int(hm["int"]) + int(hm.agi) >= 15)
	_check("inspect: revelations logged", (Game.s.get("insp_log", []) as Array).size() >= 4)
	# nobody answers -> they walk away
	Inspection.queue_candidate("test", "rare", "human")
	Inspection.tick(Inspection.WAIT_SEC + 1.0, false)
	_check("inspect: unanswered stranger leaves", not Inspection.pending())
	print("[autotest] inspection checks done: %d failed total" % _fails)
func _fake_run(gen: int) -> Dictionary:
	return {"rooms": [], "res": {}, "dwellers": [], "meta": {"gen": gen}, "saved_at": Cloud.now()}


func _local_gen() -> int:
	return int(Account.account_of(Save.read()).get("meta", {}).get("gen", -1))


## anti-cheat F0/F1 (MV-174): the offline catch-up is capped by the server's last accepted save, the account
## counts simulated seconds, a write refused for coming too soon stays queued, GOD tests stay read-only.
## The server side (0006_anticheat.sql) is tested on PostgreSQL by tools/test_error_spike.sh.
func _anticheat_test() -> void:
	Features.clear_overrides()
	var t := 2_000_000_000.0
	_check("anticheat: no server time = the save's own time", is_equal_approx(Game.offline_elapsed(t - 4 * 3600.0, t), 4 * 3600.0))
	_check("anticheat: saved_at moved back is capped by the server", is_equal_approx(Game.offline_elapsed(t - 4 * 3600.0, t, t - 600.0), 600.0))
	_check("anticheat: played offline since the last upload keeps its shorter time", is_equal_approx(Game.offline_elapsed(t - 300.0, t, t - 3 * 3600.0), 300.0))
	_check("anticheat: a save from the future gives nothing", Game.offline_elapsed(t + 50.0, t, t - 600.0) == 0.0)
	# the account counts simulated time, online and offline
	if not Game.started:
		main._on_start(true)
		await wait(0.5)
	Tutorial.skip()
	var sim0 := float(Account.a.get("life", {}).get("sim_sec", 0.0))
	Game._simulate(10.0, true)
	var sim1 := float(Account.a.life.get("sim_sec", 0.0))
	_check("anticheat: account counts simulated seconds (%.1f -> %.1f)" % [sim0, sim1], sim1 >= sim0 + 10.0 and sim1 < sim0 + 11.0)
	Game.save_game()
	_check("anticheat: sim_sec is in the saved account", float(Account.account_of(Save.read()).get("life", {}).get("sim_sec", 0.0)) >= sim1 - 0.01)
	# cloud: the server time of the last accepted save
	var keep := Save.read()
	var fake = load("res://tools/cloud_fake.gd").new()
	Cloud.session = {}
	Cloud.meta = {"rev": 0, "dirty": false, "wiped": false, "device_id": ""}
	Cloud.server_seen = 0.0
	Cloud._save_session()
	Cloud._save_meta()
	var was_started := Game.started
	Game.started = false        # the sync must not count as an open run (it would ask instead of pulling)
	await Cloud.start_for_test(fake)
	var uid := Cloud.user_id()
	_check("anticheat: upload remembers the server time", Cloud.state == Cloud.State.OK and is_equal_approx(Cloud.server_seen, fake.clock))
	fake.min_gap = 3.0
	var rl := Cloud.rate_limited
	Cloud.meta.dirty = true
	await Cloud.upload()
	_check("anticheat: too-soon write refused, kept for later", Cloud.rate_limited == rl + 1 and Cloud.meta.dirty and Cloud.state == Cloud.State.OK
		and int(fake.rows[uid].rev) == 1)
	fake.clock += 60.0
	await Cloud.upload()
	_check("anticheat: next round goes up", not Cloud.meta.dirty and int(fake.rows[uid].rev) == 2 and is_equal_approx(Cloud.server_seen, fake.clock))
	# a fresh boot reads updated_at of the cloud row
	fake.rows[uid].updated_at = fake.clock - 600.0
	Cloud.server_seen = 0.0
	await Cloud.sync()
	_check("anticheat: sync reads the server's last save time", is_equal_approx(Cloud.server_seen, fake.clock - 600.0))
	# loading a save whose saved_at was moved back 4 hours: only the 10 minutes the server saw count
	Game.started = was_started
	var d := Save.read()
	(d.main as Dictionary).saved_at = Cloud.now() - 4 * 3600.0
	Save.write(d)
	Game.load_game()
	var away := -1
	for i in range(Trace.entries.size() - 1, -1, -1):
		if str(Trace.entries[i].msg) == "loaded save":
			away = int(Trace.entries[i].data.away_sec)
			break
	_check("anticheat: edited saved_at gives only the server's 10 minutes (got %d s)" % away, away >= 590 and away <= 700)
	Features.set_override("features", "anticheat", false)
	_check("anticheat: switch off = the save's own time", int(Game.offline_elapsed(Cloud.now() - 4 * 3600.0, Cloud.now(), Cloud.server_seen if Features.on("anticheat") else 0.0)) == 4 * 3600)
	Features.set_override("features", "anticheat", null)
	# GOD tests: read-only, the save stays clean
	Game.s.stats.erase("cheated")
	var r: Dictionary = Dev.anticheat_time_test()
	_check("anticheat: GOD time test shows the cap", r.client > r.capped and r.capped < 900.0)
	var hit: int = await Dev.anticheat_rate_test()
	_check("anticheat: GOD rate test hits the limit", hit >= 1)
	_check("anticheat: GOD tests don't mark the save as cheated", not bool(Game.s.stats.get("cheated", false)))
	# back to a local-only game
	Save.write(keep)
	Cloud.transport = null
	Cloud.state = Cloud.State.OFF
	Cloud.url = ""
	Cloud.server_seen = 0.0
	Cloud.meta = {"rev": 0, "dirty": false, "wiped": false, "device_id": ""}
	Cloud._save_meta()


## persistent account (MV-159): v1 saves migrate, the account survives the next generation, no picker,
## difficulty is a setting, switch "persistent_account" off brings NEW RUN back
func _account_test() -> void:
	Features.clear_overrides()
	main._on_start(true)
	await wait(0.4)
	Tutorial.skip()
	# a v1 save: one run picked as peaceful / hard / fuel_scarce, generation 3 with perks and logbook entries
	var v1: Dictionary = Account.envelope(Game.s).main.duplicate(true)
	v1.meta = {"gen": 3, "legacy": 5, "perks": {"efficient": 2}, "blueprints": ["bp_bus"], "best_km": 40.0}
	v1.lore = ["signal"]
	v1.memorial = [{"name": "ทดสอบ", "lvl": 3, "cause": "test", "km": 1.0}]
	v1.tutorial = {"step": 0, "done": true}
	v1.mode = {"id": "peaceful", "diff": "hard", "mut": ["fuel_scarce"], "started_at": 1234.0}
	Game.started = false
	Save.write(v1)
	var toasts: Array = []
	var grab := func(t: String, _k: String): toasts.append(t)
	Game.toast.connect(grab)
	var ok := Game.load_game()
	Game.toast.disconnect(grab)
	_check("account: v1 save loads", ok and Game.started)
	_check("account: v1 run keeps generation, perks, blueprints, logbook", Meta.generation() == 3 and Meta.perk("efficient") == 2 and Meta.has_blueprint("bp_bus") and Lore.is_unlocked("signal"))
	_check("account: account data shared with the vehicle (same objects)", is_same(Game.s.meta, Account.a.meta) and is_same(Game.s.lore, Account.a.lore))
	_check("account: peaceful + mutators become standard, difficulty kept", Modes.id() == "standard" and Modes.diff() == "hard" and Modes.mutators().is_empty()
		and Features.on("raids") and Account.diff() == "hard" and str(Account.a.legacy_mode.id) == "peaceful")
	_check("account: one-time notice about the change", toasts.any(func(t): return str(t).contains("ไอดีถาวร")) and not Account.take_mode_notice())
	Game.save_game()
	var env := Save.read()
	_check("account: saved as envelope v2, account keys stored once", int(env.get("v", 0)) == 2 and int(env.account.meta.gen) == 3
		and not (env.main as Dictionary).has("meta") and not (env.main as Dictionary).has("lore") and (env.main as Dictionary).has("rooms"))
	# the next generation keeps the account
	Lore.unlock("helios")
	Meta.next_generation([int(Game.s.dwellers[0].id)])
	await wait(0.3)
	_check("account: next generation keeps logbook, memorial, tutorial", Meta.generation() == 4 and Lore.is_unlocked("signal") and Lore.is_unlocked("helios")
		and (Game.s.memorial as Array).size() == 1 and bool(Game.s.tutorial.done) and is_same(Game.s.lore, Account.a.lore))
	_check("account: next generation is standard at the account difficulty", Modes.id() == "standard" and Modes.diff() == "hard")
	# difficulty is a setting and survives a reload
	Account.set_diff("easy")
	Game.save_game()
	Game.started = false
	Game.load_game()
	_check("account: difficulty setting applies and is saved", Modes.diff() == "easy" and Account.diff() == "easy" and Meta.generation() == 4 and Lore.is_unlocked("helios"))
	main.hud.open_settings("game")
	await wait(0.4)
	await shot("account_settings_difficulty")
	main.hud.settings_panel.close()
	Account.set_diff("normal")
	Game.save_game()
	# title: no rules picker, no NEW RUN while there is a save
	var ts = main.hud.title_screen
	ts.refresh_buttons()
	_check("account: title has CONTINUE and no NEW RUN with a save", ts._continue.visible and not ts._new_btn.visible)
	Dev.feature_set("persistent_account", false)
	ts.refresh_buttons()
	_check("account: switch off shows NEW RUN", ts._new_btn.visible and ts._new_btn.text.contains("NEW RUN"))
	main._on_start(true)
	await wait(0.3)
	Tutorial.skip()
	_check("account: switch off NEW RUN starts over from nothing", Meta.generation() == 1 and not Lore.is_unlocked("helios"))
	Dev.feature_set("persistent_account", null)
	Save.wipe()
	ts.refresh_buttons()
	_check("account: a browser without a save gets START", ts._new_btn.visible and ts._new_btn.text.contains("START") and not ts._continue.visible)
	Game.save_game()


## a web page reload goes back into the saved game on its own, but waits for the cloud to answer and never
## skips a login or a save conflict (switch "resume_on_reload"; the reload itself is detected in JS)
func _resume_test() -> void:
	var ts = main.hud.title_screen
	var keep := {"url": Cloud.url, "state": Cloud.state, "need_login": Cloud.need_login, "chose": str(Cloud.meta.get("chose", ""))}
	_check("resume: off outside a web reload", not ts.auto_continue)
	Game.new_game()
	Game.s.stats["resume_mark"] = 1
	Game.save_game()
	Game.started = false
	ts.modulate.a = 1.0
	ts.visible = true
	ts.auto_continue = true
	Cloud.url = "https://test.invalid"
	Cloud.meta.chose = "guest"
	Cloud.state = Cloud.State.CONNECTING
	ts.try_auto_continue()
	_check("resume: waits while the cloud is connecting", ts.auto_continue and ts.visible)
	Cloud.state = Cloud.State.CONFLICT
	ts.try_auto_continue()
	_check("resume: never skips a save conflict", ts.auto_continue)
	Cloud.state = Cloud.State.OK
	Cloud.need_login = true
	ts.try_auto_continue()
	_check("resume: waits for the player to log in again", ts.auto_continue)
	Cloud.need_login = false
	ts.try_auto_continue()
	_check("resume: enters the game once nothing is pending", not ts.auto_continue)
	Cloud.url = keep.url
	Cloud.state = keep.state
	Cloud.need_login = keep.need_login
	Cloud.meta.chose = keep.chose
	await wait(0.6)
	_check("resume: the saved game is running", Game.started and not ts.visible and int(Game.s.stats.get("resume_mark", 0)) == 1)


## Supabase cloud save against tools/cloud_fake.gd (same rev rules as the SQL migration)
func _cloud_test() -> void:
	var fake = load("res://tools/cloud_fake.gd").new()
	_check("cloud: off without cloud_config.json in tests", not Cloud.enabled())
	Cloud.session = {}
	Cloud.meta = {"rev": 0, "dirty": false, "wiped": false, "device_id": ""}
	# stored too: a session left in user:// by an aborted run must not leak into this one
	Cloud._save_session()
	Cloud._save_meta()
	Save.write(_fake_run(3))      # a player who already has a local save when the cloud ships
	await Cloud.start_for_test(fake)
	var uid := Cloud.user_id()
	_check("cloud: anonymous sign-in", uid != "" and fake.calls.has("/auth/v1/signup"))
	_check("cloud: existing local save migrated as rev 1", fake.rows.has(uid) and int(fake.rows[uid].rev) == 1 and int(fake.rows[uid].data.meta.gen) == 3)
	_check("cloud: synced state", Cloud.state == Cloud.State.OK and not Cloud.meta.dirty and int(Cloud.meta.rev) == 1)
	_check("cloud: server clock drives now()", absf(Cloud.now() - fake.clock) < 5.0)
	_check("cloud: settings uploaded with the save", fake.rows[uid].settings.has("master"))
	# another device moved on: this one (not playing, nothing new here) takes it
	fake.write_from_other_device(uid, _fake_run(7), {"fps": 30})
	await Cloud.sync()
	_check("cloud: newer cloud save pulled", _local_gen() == 7 and int(Cloud.meta.rev) == 2 and not Cloud.meta.dirty)
	_check("cloud: settings from the cloud applied", int(Settings.get_value("fps")) == 30 and Engine.max_fps == 30)
	_check("cloud: CONTINUE shows after a pull", main.hud.title_screen._continue.visible)
	Settings.reset_defaults()
	# both changed: the player must choose
	Save.write(_fake_run(8))
	fake.write_from_other_device(uid, _fake_run(9))
	await Cloud.sync()
	_check("cloud: conflict detected", Cloud.state == Cloud.State.CONFLICT and int(Cloud.remote.rev) == 3)
	_check("cloud: local save kept during conflict", _local_gen() == 8)
	await wait(0.4)
	_check("cloud: conflict opens the save tab", main.hud.settings_panel.is_open and main.hud.settings_panel.tab == "data")
	await shot("cloud_conflict")
	await Cloud.use_local()
	_check("cloud: keep this device overwrites cloud", Cloud.state == Cloud.State.OK and int(fake.rows[uid].data.meta.gen) == 8 and int(Cloud.meta.rev) == 4)
	Save.write(_fake_run(11))
	fake.write_from_other_device(uid, _fake_run(10))
	await Cloud.sync()
	Cloud.use_cloud()
	_check("cloud: take cloud save", _local_gen() == 10 and Cloud.state == Cloud.State.OK and int(Cloud.meta.rev) == 5 and not Cloud.meta.dirty)
	await wait(0.3)
	await shot("cloud_synced")
	main.hud.settings_panel.close()
	# offline: the local save keeps working and goes up later
	fake.online = false
	Save.write(_fake_run(12))
	await Cloud.sync()
	_check("cloud: offline falls back to local", Cloud.state == Cloud.State.OFFLINE and _local_gen() == 12 and Cloud.meta.dirty)
	fake.online = true
	await Cloud.sync()
	_check("cloud: catches up when back online", Cloud.state == Cloud.State.OK and int(fake.rows[uid].data.meta.gen) == 12)
	# schema guard (0002): a tab still on an older build can't overwrite the account save
	_check("cloud: rows remember the save schema", int(fake.rows[uid].get("schema", 0)) == Cloud.SCHEMA)
	var old_write: Dictionary = await fake.handle(HTTPClient.METHOD_POST, "/rest/v1/rpc/rpc_save",
		PackedStringArray(["Authorization: Bearer " + str(Cloud.session.access_token)]),
		JSON.stringify({"p_base_rev": int(fake.rows[uid].rev), "p_data": {"rooms": []}, "p_settings": {}, "p_schema": 1, "p_device_id": "old", "p_force": true}))
	_check("cloud: an older build cannot overwrite a newer save", not bool(old_write.body.ok) and bool(old_write.body.get("old_client", false))
		and str(fake.rows[uid].device_id) != "old")
	# expired access token -> refresh token -> retried call
	fake.expire_tokens()
	Save.write(_fake_run(13))
	await Cloud.upload()
	_check("cloud: token refreshed", fake.calls.has("/auth/v1/token?grant_type=refresh_token") and int(fake.rows[uid].data.meta.gen) == 13 and Cloud.user_id() == uid)
	# an empty local save never blanks the cloud unless progress was reset on purpose
	Save.wipe()
	Cloud.meta.wiped = false
	await Cloud.upload()
	_check("cloud: lost local storage does not blank the cloud", int(fake.rows[uid].data.meta.gen) == 13)
	Cloud.meta.rev = 0
	await Cloud.sync()
	_check("cloud: cleared browser restores from cloud", _local_gen() == 13)
	Save.wipe()
	await Cloud.upload()
	_check("cloud: progress reset reaches the cloud", (fake.rows[uid].data as Dictionary).is_empty() and not Cloud.meta.wiped)
	# saved_at uses the server clock
	Game.setup_default_state()
	Game.started = true
	Game.save_game()
	_check("cloud: saved_at stamped with server time", absf(float(Account.vehicle_of(Save.read()).saved_at) - fake.clock) < 5.0)
	Game.started = false
	Save.wipe()
	Cloud.transport = null
	Cloud.state = Cloud.State.OFF
	Cloud.url = ""


## Regression: on the items/forge tab the panel rebuilt itself on every resources_changed (each
## frame), freeing the tab buttons before a tap's release, so the other tabs could not be tapped.
func _loot_tabs_test() -> void:
	var inv: LootPanel = main.hud.panels.inventory
	inv.move_to_front()  # road-event popups fired by the sim may sit on top during the run
	for from in ["items", "forge"]:
		inv.tab = from
		inv.refresh()
		await wait(0.2)
		var btns: Array = inv._tabs.get_children().filter(func(c): return c is Button)
		await wait(0.5)  # ~30 simulation frames of resources_changed
		var alive := btns.size() == 3
		for b in btns:
			alive = alive and is_instance_valid(b) and b.get_parent() == inv._tabs
		_check("loot tabs: %s tab keeps its tab buttons across resource ticks" % from, alive)
		if not alive:
			continue
		var target := "gear" if from == "items" else "items"
		# a real tap: touch-down now, release a few frames later (BaseButton fires on release)
		var btn: Button = btns[0] if target == "gear" else btns[1]
		var pos := btn.get_global_rect().get_center()
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = pos
		ev.global_position = pos
		ev.pressed = true
		var mv := InputEventMouseMotion.new()
		mv.position = pos
		mv.global_position = pos
		get_viewport().push_input(mv, true)
		await wait(0.05)
		var hov := get_viewport().gui_get_hovered_control()
		_check("loot tabs: %s tab button is the control under the finger (got %s)" % [from, str(hov.get_path()) if hov else "none"],
			hov != null and (hov == btn or btn.is_ancestor_of(hov)))
		get_viewport().push_input(ev, true)
		await wait(0.15)
		var up: InputEventMouseButton = ev.duplicate()
		up.pressed = false
		get_viewport().push_input(up, true)
		await wait(0.2)
		_check("loot tabs: tap %s -> %s switches tab" % [from, target], inv.tab == target)
	# the item counts still follow the resources without a rebuild
	inv.tab = "items"
	inv.refresh()
	await wait(0.2)
	var lbl: Label = inv._amounts.get("scrap")
	Game.s.res.scrap = 123.0
	Game.resources_changed.emit()
	_check("loot tabs: items amounts update in place", is_instance_valid(lbl) and lbl == inv._amounts.get("scrap") and lbl.text.begins_with("123"))
	inv.tab = "gear"
	inv.refresh()


## v4.5 threat pacing: what draws enemies in, the quiet -> warning -> raid -> salvage cycle,
## rewards per hour vs the classic back-to-back waves, offline pay, classic toggle
func _threat_test() -> void:
	_no_events()
	Settings.set_value("pacing", "threat")
	Combat.reset_wave(1)
	Threat.reset()
	Game.s.combat.threat = 0.0
	Game.s.weather = "clear"
	Game.s.tod = 0.5
	var day := Threat.rate_pm()
	_check("threat: builds up while travelling", day > 0.0)
	Game.s.tod = 0.0
	var night := Threat.rate_pm()
	_check("threat: night draws more enemies than day", night > day)
	Game.s.weather = "storm"
	_check("threat: a storm masks noise and light", Threat.rate_pm() < night)
	Game.s.weather = "clear"
	Game.s.tod = 0.5
	_check("threat: no raid roll below the floor", Threat.raid_chance() == 0.0)
	Game.s.combat.threat = 100.0
	_check("threat: full meter always raids", Threat.raid_chance() >= 1.0)
	Game.s.combat.threat = 0.0
	for i in 300:
		Combat.tick(0.1)
	_check("threat: quiet road has no enemies", not Combat.wave_active and Combat.enemies.is_empty() and Threat.phase == "quiet")
	main.hud._refresh_combat()
	_check("threat: HUD shows the quiet phase + meter", main.hud._wave_lbl.text == "QUIET" and main.hud._threat_bar.visible)
	await shot("threat_quiet")
	Threat.force_warning()
	_check("threat: warning phase before the raid", Threat.phase == "warning")
	main.hud._refresh_combat()
	await shot("threat_warning")
	var seen_salvage := false
	for i in 1800:
		Combat.tick(0.1)
		if Threat.phase == "salvage":
			seen_salvage = true
			break
	_check("threat: raid ends in salvage", seen_salvage)
	_check("threat: threat drops after the raid", Threat.threat() < 60.0)
	# ---- rewards per hour: classic vs threat, same squad / wave, farm mode, view detached
	var detached := []
	for sig in Combat.get_signal_list():
		for c in Combat.get_signal_connection_list(sig.name):
			if c.callable.get_object() is Node and (c.callable.get_object() as Node).is_inside_tree():
				detached.append([sig.name, c.callable, c.flags])
				Combat.disconnect(sig.name, c.callable)
	var push_was: bool = Game.s.combat.push
	Game.s.combat.push = false
	var res := {}
	for mode in ["classic", "threat"]:
		Settings.set_value("pacing", mode)
		Combat.reset_wave(8)
		Threat.reset()
		Game.s.combat.threat = 20.0
		Game.s.combat.fight_share = 0.3
		Combat.rebuild_heroes()
		var scrap0 := float(Game.s.res.scrap)
		Game.s.res.scrap = 0.0
		var k0 := int(Game.s.combat.kills)
		for k in Threat.stats:
			Threat.stats[k] = 0.0
		var fight := 0
		var raids := 0
		var was := false
		var steps := 36000   # 60 sim minutes
		for i in steps:
			Combat.tick(0.1)
			Game.s.res.scrap = minf(float(Game.s.res.scrap), 1.0e9)
			if Combat.wave_active:
				fight += 1
			if Threat.phase == "raid" and not was:
				raids += 1
			was = Threat.phase == "raid"
		res[mode] = {"scrap": float(Game.s.res.scrap), "kills": int(Game.s.combat.kills) - k0, "fight": float(fight) / steps, "raids": raids,
			"share": snappedf(Threat.fight_share(), 0.01), "mult": snappedf(Threat.reward_mult(), 0.01), "parts": Threat.stats.duplicate()}
		Game.s.res.scrap = scrap0
		print("[autotest] pacing %s: %s" % [mode, res[mode]])
	Game.s.combat.push = push_was
	for d in detached:
		Combat.connect(d[0], d[1], d[2])
	# combat scrap only: gear auto-salvage depends on how full the stash already was
	var earned := func(r: Dictionary) -> float:
		return float(r.parts.kill_scrap) + float(r.parts.salvage) + float(r.parts.scavenge)
	var ratio: float = earned.call(res.threat) / maxf(1.0, earned.call(res.classic))
	print("[autotest] threat/classic combat scrap per hour = %.2f" % ratio)
	_check("threat: fighting is a minority of the time (<60%)", float(res.threat.fight) < 0.6)
	_check("threat: classic fights almost all the time (>80%)", float(res.classic.fight) > 0.8)
	_check("threat: several raids per hour", int(res.threat.raids) >= 10)
	_check("threat: scrap per hour within 80-120% of classic", ratio >= 0.8 and ratio <= 1.2)
	# ---- offline pay follows the measured raids
	Settings.set_value("pacing", "threat")
	Game.s.combat.raid_kpm = 20.0
	Game.s.combat.fight_share = 0.25
	_check("threat: raid bonus = target / fight share", absf(Threat.reward_mult() - Threat.TARGET_PAY / 0.25) < 0.01)
	_check("threat: offline kpm = raid kpm x share x bonus", absf(Threat.offline_kpm(25.0) - 20.0 * Threat.TARGET_PAY) < 0.01)
	Game.s.combat.fight_share = 0.02
	_check("threat: raid bonus is capped", Threat.reward_mult() <= Threat.MULT_MAX)
	Game.s.combat.fight_share = 0.3
	Settings.set_value("pacing", "classic")
	_check("threat: classic offline unchanged", Threat.offline_kpm(25.0) == 25.0 and Threat.reward_mult() == 1.0)
	# ---- classic toggle: waves come back to back again
	Combat.reset_wave(1)
	for i in 40:
		Combat.tick(0.1)
	_check("threat: classic mode starts waves on its own", Combat.wave_active)
	main.hud._refresh_combat()
	_check("threat: meter hidden in classic", not main.hud._threat_bar.visible)
	Settings.set_value("pacing", "threat")
	Combat.reset_wave(1)
	Threat.reset()
	Dev.threat_set(90.0)
	_check("god: set threat", absf(Threat.threat() - 90.0) < 0.01)
	Dev.force_raid()
	_check("god: force a raid (warning first)", Threat.phase == "warning")
	Combat.reset_wave(1)
	Threat.reset()
	Game.s.combat.threat = 0.0
	_check("threat: save keeps the meter", Game.s.combat.has("threat") and Game.s.combat.has("raid_kpm") and Game.s.combat.has("fight_share"))
	print("[autotest] threat checks done: %d failed total" % _fails)


func _rate(slot: int, k: String) -> float:
	return float(Game.room_rate_pm(slot).get(k, 0.0))


## v4.4 large rooms: knock 2-3 same-type neighbours through into one room
func _large_room_test() -> void:
	get_window().size = Vector2i(1280, 640)
	Game.setup_default_state()
	Game.s.tier = "rig"
	Game.s.vault_level = Data.MAX_VAULT_LEVEL
	while Game.s.rooms.size() < Game.slot_count():
		Game.s.rooms.append({"type": "empty", "level": 1, "job": {}, "build": {}})
	for i in range(1, Game.s.rooms.size()):
		Game.s.rooms[i] = {"type": "empty", "level": 1, "job": {}, "build": {}}
	for i in [3, 4, 5]:
		Game.s.rooms[i] = {"type": "kitchen", "level": 1, "job": {}, "build": {}}
	Game.s.rooms[8] = {"type": "kitchen", "level": 1, "job": {}, "build": {}}
	Game.s.outage = {}
	Game.s.res.scrap = 8000.0
	Game.s.items["components"] = 300
	for d in Game.s.dwellers:
		d.room = -1
	var crew := []
	for i in 6:
		var d := Game._add_dweller({"name": "ทดสอบ%d" % i, "variant": "dw_chef_gray", "str": 5, "int": 5, "agi": 5})
		d.traits = []
		d.skills = {}
		d.happy = 70.0
		crew.append(d)
	Game.assign(crew[0], 3)
	Game.assign(crew[1], 3)
	Game.assign(crew[2], 4)
	Game.assign(crew[3], 4)
	Game.rooms_changed.emit()
	_check("large: same-type neighbour is a merge candidate", Game.merge_candidates(3) == [4])
	_check("large: rooms must touch", Game.merge_block(3, 5) != "")
	Game.s.rooms[5].type = "water"
	_check("large: different types can't merge", Game.merge_block(4, 5).contains("ชนิด") and Game.merge_block(5, 8) != "")
	Game.s.rooms[5].type = "kitchen"
	Game.s.rooms[4].level = 2
	_check("large: levels must match", Game.merge_block(3, 4).contains("เลเวล"))
	Game.s.rooms[4].level = 1
	_check("large: engine room never merges", Game.merge_block(0, 1) != "")
	var single := _rate(3, "food") + _rate(4, "food")
	var scrap0 := float(Game.s.res.scrap)
	var comp0 := int(Game.s.items.components)
	var cost := Game.merge_cost(3, 4)
	_check("large: merge costs scrap + components", int(cost.scrap) > 0 and int(cost.components) == Data.MERGE_COMPONENTS)
	_check("large: merge starts", Game.merge_rooms(4, 3))
	_check("large: paid", is_equal_approx(float(Game.s.res.scrap), scrap0 - float(cost.scrap)) and int(Game.s.items.components) == comp0 - int(cost.components))
	_check("large: right cell becomes an annex of the left", Game.is_annex(4) and Game.room_anchor(4) == 3 and Game.room_span(3) == 2)
	_check("large: crew moved to the anchor, 4 seats", Game.room_workers(3).size() == 4 and Game.room_capacity(3) == 4)
	print("[autotest] rates single %.3f merging %.3f" % [single, _rate(3, "food")])
	_check("large: still works during the knock-through (no bonus yet)", Game.is_merging(3) and absf(_rate(3, "food") - single) < 0.01 * single and not Game.is_site(3))
	var t0 := float(Game.build_info(3).left)
	Game._simulate(1.0, false)
	_check("large: knock-through progresses", float(Game.build_info(3).left) < t0)
	Game._finish_build(3, false)
	_check("large: 2-wide room +10%", absf(_rate(3, "food") - single * 1.10) < 0.01 * single and is_equal_approx(Game.room_scale(3), 2.2))
	_check("large: power use 90% per cell", is_equal_approx(Game.room_power_pm(3), float(Data.ROOMS.kitchen.power) * 2.0 * 0.9))
	Game.assign(crew[3], -1)
	Game.assign(crew[3], 4)
	_check("large: assigning to an annex cell goes to the anchor", int(crew[3].room) == 3)
	_check("large: seats are capped at 2 per cell", not Game.assign(crew[4], 4))
	main.vehicle.refresh_rooms()
	var rv3: RoomView = main.vehicle.room_views[3]
	_check("large: room view spans both cells", is_equal_approx(rv3.w, 138.0) and not main.vehicle.room_views[4].visible and rv3.seams.size() == 1)
	_check("large: wide art exists for this layout", Atlas.has(rv3.wide_key("kitchen")))
	_check("large: ladder shaft doesn't cut through a merged room (MV-146)", _shaft_free("kitchen"))
	# third cell
	_check("large: 2+1 merges into 3", Game.merge_candidates(5) == [3])
	Game.merge_rooms(5, 3)
	Game._finish_build(3, false)
	Game.assign(crew[4], 5)
	Game.assign(crew[5], 5)
	_check("large: 3-wide room, 6 seats, x3.75", Game.room_cells(5) == [3, 4, 5] and Game.room_capacity(3) == 6 and is_equal_approx(Game.room_scale(3), 3.75))
	_check("large: max 3 cells", Game.merge_block(3, 8) != "" and Game.merge_candidates(3).is_empty())
	_check("large: upgrade costs span x 80%", Game.upgrade_cost(4) == int(round(float(Data.ROOM_UPGRADE_COST[2]) * 3.0 * 0.8 * Crew.build_cost_mult())))
	_check("large: upgrade takes longer", Game.upgrade_time(2, 3) > Game.upgrade_time(2))
	Game.upgrade_room(5)
	Game._finish_build(3, false)
	_check("large: upgrade levels every cell", int(Game.s.rooms[3].level) == 2 and int(Game.s.rooms[5].level) == 2)
	# synergy: a 2-wide hydroponics above counts once
	Game.s.rooms[6] = {"type": "hydroponics", "level": 1, "job": {}, "build": {}}
	Game.s.rooms[7] = {"type": "annex", "level": 1, "job": {}, "build": {}}
	var hyd := Synergy.effects(3).filter(func(e): return str(e.type) == "hydroponics")
	_check("large: neighbouring large room counts once", hyd.size() == 1 and Synergy.neighbours(3).has(6) and not Synergy.neighbours(3).has(7))
	Game.s.rooms[6] = {"type": "empty", "level": 1, "job": {}, "build": {}}
	Game.s.rooms[7] = {"type": "empty", "level": 1, "job": {}, "build": {}}
	# quarters pop cap scales
	var pop0 := Game.pop_cap()
	Game.s.rooms[9] = {"type": "quarters", "level": 1, "job": {}, "build": {}}
	Game.s.rooms[10] = {"type": "annex", "level": 1, "job": {}, "build": {}}
	_check("large: 2-wide quarters house 2.2x", Game.pop_cap() - pop0 == 9)
	Game.s.rooms[9] = {"type": "empty", "level": 1, "job": {}, "build": {}}
	Game.s.rooms[10] = {"type": "empty", "level": 1, "job": {}, "build": {}}
	# save round-trip (ids/rooms come back as floats) + broken annex cleanup
	Game.s.rooms[6] = {"type": "annex", "level": 1, "job": {}, "build": {}}
	Game.s = JSON.parse_string(JSON.stringify(Game.s))
	Game._migrate()
	_check("large: survives a JSON round-trip", Game.room_span(3) == 3 and Game.room_workers(3).size() == 6 and is_equal_approx(Game.room_scale(4), 3.75))
	_check("large: orphan annex is cleared on load", str(Game.s.rooms[6].type) == "empty")
	Game.rooms_changed.emit()
	Game.dwellers_changed.emit()
	await wait(1.0)
	main.vehicle.peek(9999.0)
	await wait(0.8)
	await shot("large_room_vehicle")
	main.open_closeup(4)
	await wait(1.6)
	_check("large: close-up opens the whole room", main.hud.room_closeup.slot == 3)
	await shot("large_room_closeup")
	main.hud.room_closeup.close()
	await wait(0.6)
	get_window().size = Vector2i(780, 1688)
	await wait(1.2)
	main.open_closeup(3)
	await wait(1.6)
	await shot("large_room_portrait")
	main.hud.room_closeup.close()
	await wait(0.6)
	get_window().size = Vector2i(1280, 640)
	await wait(0.6)
	# split back + demolish
	_check("large: split gives 3 rooms back", Game.split_room(4) and Game.room_span(3) == 1 and str(Game.s.rooms[5].type) == "kitchen" and int(Game.s.rooms[5].level) == 2)
	_check("large: split shares the crew out", Game.room_workers(3).size() <= 2 and Game.room_workers(4).size() <= 2 and Game.room_workers(5).size() <= 2)
	Game.merge_rooms(3, 4)
	Game._finish_build(3, false)
	var sc := float(Game.s.res.scrap)
	Game.demolish_room(4)
	_check("large: demolish clears every cell", str(Game.s.rooms[3].type) == "empty" and str(Game.s.rooms[4].type) == "empty" and float(Game.s.res.scrap) > sc)
	Game.rooms_changed.emit()
	await wait(0.4)
	print("[autotest] large rooms done: %d failed total" % _fails)


## the old ladder art ran solid black outlines down both edges of the 10 px shaft gap; the boarded-over gap
## (steel post on the room wall) leaves those edge columns mostly wall colour
func _shaft_free(t: String) -> bool:
	var img := Atlas.sheet.get_image()
	for key in ["room_%s_x10" % t, "room_%s_x10_2" % t]:
		var r: Array = Atlas.regions[key]
		var dark := 0
		for col in [64, 73]:
			for y in range(8, 44):
				var p := img.get_pixel(int(r[0]) + col, int(r[1]) + y)
				if maxf(p.r, maxf(p.g, p.b)) < 40.0 / 255.0:
					dark += 1
		if dark >= 36:
			return false
	return true


## a wave that stays open for the whole check: one spawn queued far in the future, so neither the squad,
## the turret nor threat pacing can clear it (keeps the tag-in checks deterministic)
func _deck_hold_wave() -> void:
	Combat.debug_spawn([{"t": 999.0, "mob": "rad_rat", "lvl": 1}], false)


## roof rest deck (ดาดฟ้า): reserve seat, rest on the cot, tag-in for a fallen defender, cover bonuses
## link previews (Open Graph / Twitter card) live in the Web preset's html/head_include and need an
## absolute og:image URL; the 1200x630 PNG itself is web/og-image.png (tools/og_image.py).
func _share_preview_test() -> void:
	var cfg := ConfigFile.new()
	_check("share: export_presets.cfg loads", cfg.load("res://export_presets.cfg") == OK)
	var head: String = cfg.get_value("preset.0.options", "html/head_include", "")
	for tag in ["og:title", "og:description", "og:url", "og:image:width", "twitter:card", "theme-color", "name=\"description\""]:
		_check("share: head_include has " + tag, head.contains(tag))
	var m := RegEx.create_from_string("property=\"og:image\" content=\"([^\"]+)\"").search(head)
	var url: String = m.get_string(1) if m else ""
	_check("share: og:image is an absolute https URL", url.begins_with("https://") and url.ends_with("/og-image.png"))
	_check("share: twitter:image matches og:image", url != "" and head.contains("name=\"twitter:image\" content=\"%s\"" % url))
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://web/og-image.png"))
	_check("share: og-image.png is 1200x630", img != null and img.get_size() == Vector2i(1200, 630))
	_check("share: og:title uses the game name", head.contains("property=\"og:title\" content=\"" + BuildInfo.GAME_NAME))
	_check("logo: pixel logo is 192x60", UIKit.LOGO.get_size() == Vector2(192, 60))
	_check("share: project name is the game name", ProjectSettings.get_setting("application/config/name") == BuildInfo.GAME_NAME)
	_check("share: favicon exported", cfg.get_value("preset.0.options", "html/export_icon", false))
	# boot card: the Web export uses the Apocarlypse shell (same page as the artifact), not Godot's loader
	var shell_path: String = cfg.get_value("preset.0.options", "html/custom_html_shell", "")
	_check("boot: Web preset uses tools/web_shell.html", shell_path == "res://tools/web_shell.html")
	var shell := FileAccess.get_file_as_string(shell_path) if shell_path != "" else ""
	for key in ["$GODOT_URL", "$GODOT_CONFIG", "$GODOT_HEAD_INCLUDE", "$GODOT_THREADS_ENABLED", "<!--BOOT_SHIM-->", "src=\"logo.png\""]:
		_check("boot: shell has " + key, shell.contains(key))
	_check("boot: no patch notes on the loading page during the test phase", not shell.contains("ชื่อใหม่") and not shell.contains("class=\"tips\""))
	_check("boot: random tips + driving scene", shell.contains("const TIPS = [") and shell.contains("id=\"scene\""))
	for sprite in ["sky", "sun", "far", "mid", "near", "road", "bus", "walker"]:
		_check("boot: web/boot/%s.png exported" % sprite, FileAccess.file_exists("res://web/boot/%s.png" % sprite))
	_check("boot: shell version matches BuildInfo", shell.contains(">v%s · GODOT 4.7.2<" % BuildInfo.GAME_VERSION))
	var web_logo := Image.load_from_file(ProjectSettings.globalize_path("res://web/logo.png"))
	_check("boot: web/logo.png is the 192x60 pixel logo", web_logo != null and web_logo.get_size() == Vector2i(192, 60))


func _roof_deck_test() -> void:
	_no_events()
	Game.s.mods.erase("roof_deck")
	Mods.mods_changed.emit()
	var free := []
	for d in Game.s.dwellers:
		if Game.squad_role(d) < 0 and not Game.is_away(d):
			free.append(d)
	# a gunner on duty (earlier checks may have sent the squad away)
	if int(Game.s.squad[0]) < 0 and free.size() > 1:
		Game.set_squad(0, int(free.pop_back().id))
	var cand: Dictionary = free[0] if not free.is_empty() else {}
	_check("deck: a free dweller to rest up there", not cand.is_empty())
	if cand.is_empty():
		return
	var rid := int(cand.id)
	Game.set_deck(rid)
	_check("deck: no reserve seat before the deck is built", Game.deck_dweller().is_empty() and Vehicle.deck_lift() == 0.0)
	Game.s.res.scrap = 5000.0
	Game.s.items.components = 500
	_check("deck: install Lv1", Mods.install("roof_deck") and Mods.level("roof_deck") == 1)
	_check("deck: roof crew stands on the planks", Vehicle.deck_lift() > 0.0 and CombatView.hero_view(0).y < CombatView.HERO_VIEW[0].y + CombatView.roof_shift)
	var room_before := int(cand.room)
	Game.set_deck(rid)
	_check("deck: reserve set, off their room", Game.is_deck(cand) and int(cand.room) == -1 and (room_before >= -1))
	_check("deck: reserve is not idle", not Game.idle_dwellers().has(cand))
	# JSON round-trip turns the id into a float
	Game.s.deck = JSON.parse_string(JSON.stringify([rid]))[0]
	_check("deck: float id after load still matches", Game.is_deck(cand))
	cand.hp = float(cand.max_hp) * 0.4
	# only the deck heal may move hp here: an infection, rads or starving left by earlier checks drain more than it heals
	cand.infection = 0.0
	cand.rads = 0.0
	Game.s.res.food = maxf(float(Game.s.res.food), 100.0)
	Game.s.res.water = maxf(float(Game.s.res.water), 100.0)
	var hp0 := float(cand.hp)
	for i in 10:
		Game._simulate(1.0, true)
	_check("deck: reserve heals while resting", float(cand.hp) > hp0)
	# --- tag-in during a wave
	Combat._end_subs()
	Combat.reset_wave(3)
	Combat.rebuild_heroes()
	_deck_hold_wave()
	var orig := int(Combat.heroes[0].did) if not Combat.heroes[0].is_empty() else -1
	_check("deck: gunner on duty", orig >= 0)
	if orig < 0:
		return
	Combat.heroes[0].alive = false
	Combat.heroes[0].hp = 0.0
	for i in int(Combat.DECK_TAG_DELAY[1] / Combat.STEP) + 5:
		Combat.tick(Combat.STEP)
		if not Combat.sub.is_empty():
			break
	_check("deck: reserve jumps in for the fallen gunner", Combat.sub.has(0) and int(Combat.heroes[0].did) == rid and Combat.heroes[0].alive)
	_check("deck: fallen gunner rests on the cot", int(Combat.sub_out.get(0, -1)) == orig)
	await wait(0.6)
	await shot("deck_tag_in")
	Combat._on_wave_cleared()
	_check("deck: wave over restores the line-up", Combat.sub.is_empty() and int(Combat.heroes[0].did) == orig and Combat.heroes[0].alive)
	# --- a pending reserve keeps the fight going even when everyone is down
	_deck_hold_wave()
	for i in 3:
		Combat.tick(Combat.STEP)
	for h in Combat.heroes:
		if not h.is_empty():
			h.alive = false
			h.hp = 0.0
	Combat.tick(Combat.STEP)
	_check("deck: no wipe while the reserve can still come down", Combat.wave_active)
	for i in int(Combat.DECK_TAG_DELAY[1] / Combat.STEP) + 5:
		Combat.tick(Combat.STEP)
		if not Combat.sub.is_empty():
			break
	_check("deck: reserve fights on alone", Combat._alive_count() == 1 and not Combat.sub.is_empty())
	Combat._end_subs()
	Combat.reset_wave(3)
	# --- cover bonuses for the roof crew
	var gd := Game.dweller_by_id(orig)
	var def1 := float(Combat.hero_stats(gd, 0).def)
	var rng1 := float(Combat.hero_stats(gd, 0).range)
	_check("deck: install Lv2 + Lv3", Mods.install("roof_deck") and Mods.install("roof_deck") and Mods.level("roof_deck") == 3)
	var st3 := Combat.hero_stats(gd, 0)
	_check("deck: sandbags + lookout buff the gunner", float(st3.def) > def1 * 1.1 and float(st3.range) > rng1 * 1.05)
	# same person as a rear bruiser: no roof cover
	_check("deck: rear bruiser gets no roof cover", float(Combat.hero_stats(gd, 1).regen) < float(st3.regen))
	# --- reserve XP from kills and offline
	var xp0 := float(cand.xp) + float(cand.lvl) * 1000.0
	Combat.offline_rewards(600.0)
	_check("deck: reserve learns while watching (offline)", float(cand.xp) + float(cand.lvl) * 1000.0 > xp0)
	# --- UI
	main.hud.panels.squad.tab = "squad"
	main.hud.open_panel("squad")
	await wait(0.6)
	_check("deck: squad panel shows the reserve card", _find_text(main.hud.panels.squad, "ROOF DECK RESERVE"))
	await shot("deck_squad_panel")
	main.hud.panels.squad.choosing = main.hud.panels.squad.DECK
	main.hud.panels.squad.refresh()
	await wait(0.4)
	await shot("deck_chooser")
	main.hud.panels.squad.close()
	await wait(0.4)
	await shot("deck_world_lv3")
	# --- leaving the deck by itself
	var free_slot := -1
	for i in Game.s.rooms.size():
		if Game.s.rooms[i].type != "empty" and Game.is_slot_unlocked(i) and not Game.is_site(i) and Game.room_workers(i).size() < Data.ROOM_WORKERS:
			free_slot = i
			break
	if free_slot >= 0:
		Game.assign(cand, free_slot)
		_check("deck: going to work takes them off the deck", not Game.is_deck(cand))
		Game.set_deck(rid)
	Game.set_squad(2 if Combat.slots_unlocked() > 2 else 0, rid)
	_check("deck: joining the squad takes them off the deck", Game.deck_dweller().is_empty())
	if Game.squad_role(cand) == 0 and orig >= 0:
		Game.set_squad(0, orig)
	print("[autotest] roof deck checks done: %d failed total" % _fails)


## Features: layers, per-event switches / weights / date windows, remote file rules, ?ff=, and every gate
## Guest -> link Google keeps the same account and save; second device: Google already taken -> switch
## (conflict between this device's guest run and the account's save) -> sign out back to a fresh guest
## wipe the local save the way a new browser starts (no "progress reset" flag for the cloud)
func _applying_wipe() -> void:
	Cloud._applying = true
	Save.wipe()
	Cloud._applying = false


func _cloud_account_test() -> void:
	var fake = load("res://tools/cloud_fake.gd").new()
	var opened: Array = []
	Cloud.navigate_hook = func(to: String): opened.append(to)
	Cloud.session = {}
	Cloud.meta = {"rev": 0, "dirty": false, "wiped": false, "device_id": "", "oauth": {}}
	Cloud.auth_error = ""
	Cloud._save_session()
	Cloud._save_meta()
	Save.write(_fake_run(20))
	await Cloud.start_for_test(fake)
	var guest := Cloud.user_id()
	_check("account: starts as guest", Cloud.is_guest() and guest != "" and Cloud.account_text().begins_with("Guest"))
	# MV-115: short public player id; the vectors match public.player_id() in 0003_player_id.sql
	_check("player id: base32 of the first 48 bits of the user id", Cloud.short_id("0f1e2d3c-4b5a-4987-8a6b-5c4d3e2f1a0b") == "0G3SQ-MSKUU"
		and Cloud.short_id("ffffffff-ffff-4fff-bfff-ffffffffffff") == "7ZZZZ-ZZZZZ" and Cloud.short_id("not-a-uuid") == "" and Cloud.short_id("") == "")
	var pid := Cloud.player_id()
	_check("player id: a guest has one", pid.length() == 11 and pid == Cloud.short_id(guest))
	var traced := func(e): return str(e.msg) == "player" and str(e.get("data", {}).get("pid", "")) == pid
	_check("player id: in the trace and its export", Trace.entries.any(traced) and Trace.export_text().contains(pid))
	_check("player id: the save carries it", str(Account.envelope({}).account.get("pid", "")) == pid)
	main.hud.settings_panel.open_tab("data")
	await wait(0.2)
	var sp_labels: Array = main.hud.settings_panel._list.find_children("*", "Label", true, false)
	var sp_buttons: Array = main.hud.settings_panel._list.find_children("*", "Button", true, false)
	_check("player id: Settings > เซฟ shows it with a copy button", sp_labels.any(func(l): return l.text == pid)
		and sp_buttons.any(func(b): return b.text.contains("คัดลอกไอดี")))
	await shot("player_id_settings")
	main.hud.settings_panel.close()
	_check("player id: GOD copy gives id + user id", Dev.player_id_copy() == "%s · %s" % [pid, guest])
	Features.set_override("features", "player_id", false)
	_check("player id: switch off hides it", Cloud.player_id() == "")
	Features.set_override("features", "player_id", null)
	Features.set_override("features", "google_login", false)
	_check("account: google_login switch hides Google", not Cloud.can_google())
	Features.set_override("features", "google_login", null)
	_check("account: Google available on a top-level page", Cloud.can_google())
	main.hud.title_screen.modulate.a = 1.0
	main.hud.title_screen.visible = true
	var ts = main.hud.title_screen
	ts._refresh_account()
	await wait(0.2)
	_check("account: first visit asks Guest or Gmail (two buttons, menu hidden)", ts._gate.visible and not ts._menu.visible
		and ts._gate.get_children().filter(func(c): return c is Button and c.visible and (c.text.contains("Guest") or c.text.contains("Gmail"))).size() == 2)
	await shot("account_choice")
	await Cloud.play_as_guest()
	await wait(0.2)
	_check("account: Guest -> menu, same guest, link Gmail offered", not ts._gate.visible and ts._menu.visible
		and Cloud.user_id() == guest and ts._account_btn.text.contains("Gmail") and not Cloud.needs_choice())
	await shot("account_title_guest")
	await Cloud.sign_in_google()
	_check("account: guest links Google (manual linking URL)", opened.size() == 1 and str(opened[0]).contains("link=" + guest) and str(Cloud.meta.oauth.get("mode", "")) == "link")
	_check("account: link request is a GET without a body", fake.calls.any(func(c): return str(c).begins_with("/auth/v1/user/identities/authorize")))
	# the page comes back from Google with the session in the fragment
	await Cloud._take_oauth_return(fake.google_return(opened[0], "parames@gmail.com"))
	await Cloud.sync()
	_check("account: linked, same user id", Cloud.user_id() == guest and not Cloud.is_guest() and Cloud.session.email == "parames@gmail.com")
	_check("player id: kept when the guest links Google", Cloud.player_id() == pid)
	_check("account: the guest save is now the Google save", int(fake.rows[guest].data.meta.gen) == 20 and Cloud.state == Cloud.State.OK and Cloud.meta.oauth.is_empty())
	_check("account: title shows the email", ts._account_btn.text.contains("parames@gmail.com") and not ts._gate.visible)
	# coming back later (new page load): the stored session is used, nobody is asked to log in again
	var calls_before: int = fake.calls.size()
	Cloud._load_session()
	Cloud._load_meta()
	Cloud._user_checked = false
	await Cloud.start_for_test(fake)
	_check("account: reopening keeps the Google session", Cloud.user_id() == guest and not Cloud.is_guest()
		and Cloud.state == Cloud.State.OK and not fake.calls.slice(calls_before).has("/auth/v1/signup"))
	# an hour later: the access token expired; two callers refresh at once (rotation must not end the session)
	fake.expire_tokens()
	Cloud.session.expires_at = 0.0
	var r1 = [null]
	var both := func(): r1[0] = await Cloud._ensure_session()
	both.call()
	var r2: bool = await Cloud._ensure_session()
	await wait(0.1)
	_check("account: expired token refreshes once for two callers, still Google", r1[0] == true and r2 and fake.refreshes == 1
		and Cloud.user_id() == guest and not Cloud.is_guest())
	# the server ends the session: ask to log in again, keep the save, no silent new guest
	fake.revoke(guest)
	Cloud.session.erase("access_token")
	var users_before: int = fake.accounts.size()
	await Cloud.sync()
	await wait(0.2)
	_check("account: refused Google session -> log in again, no new guest", Cloud.need_login and fake.accounts.size() == users_before
		and Cloud.needs_choice() and ts._gate.visible and ts._gate_err.text != "" and _local_gen() == 20)
	await shot("account_relogin")
	opened.clear()
	await Cloud.sign_in_google()
	_check("account: log in again signs in (not link)", opened.size() == 1 and str(opened[0]).contains("/auth/v1/authorize?provider=google"))
	await Cloud._take_oauth_return(fake.google_return(opened[0], "parames@gmail.com"))
	await Cloud.sync()
	_check("account: back on the same account, no conflict", Cloud.user_id() == guest and not Cloud.is_guest()
		and not Cloud.need_login and Cloud.state == Cloud.State.OK and not ts._gate.visible)
	# another browser: a new guest with its own run, then Google -> already linked to the first account
	Cloud.session = {}
	Cloud.meta = {"rev": 0, "dirty": false, "wiped": false, "device_id": "", "oauth": {}}
	Cloud._save_session()     # a new browser has nothing stored either
	Cloud._save_meta()
	Save.write(_fake_run(30))
	await Cloud.start_for_test(fake)
	var guest2 := Cloud.user_id()
	_check("account: second device is its own guest", guest2 != guest and Cloud.is_guest() and int(fake.rows[guest2].data.meta.gen) == 30)
	opened.clear()
	await Cloud.sign_in_google()
	await Cloud._take_oauth_return(fake.google_return(opened[0], "parames@gmail.com"))
	_check("account: Google already used -> told, nothing changed", Cloud.link_taken and Cloud.auth_error != "" and Cloud.user_id() == guest2)
	main.hud.open_settings("data")
	await wait(0.5)
	_check("account: settings offers switching to that account", _find_text(main.hud.settings_panel, "สลับไปบัญชี Google"))
	await shot("account_link_taken")
	opened.clear()
	await Cloud.switch_to_google()
	_check("account: switch signs in (not link)", opened.size() == 1 and str(opened[0]).contains("/auth/v1/authorize?provider=google") and str(opened[0]).contains("redirect_to="))
	await Cloud._take_oauth_return(fake.google_return(opened[0], "parames@gmail.com"))
	await Cloud.sync()
	_check("account: switched to the Google account", Cloud.user_id() == guest and not Cloud.is_guest())
	_check("account: both runs exist -> player picks", Cloud.state == Cloud.State.CONFLICT and _local_gen() == 30 and int(Cloud.remote.data.meta.gen) == 20)
	Cloud.use_cloud()
	_check("account: picked the account's save", _local_gen() == 20 and Cloud.state == Cloud.State.OK)
	await wait(0.3)
	await shot("account_google")
	# a new browser with no progress: Gmail signs straight in and loads the account's save
	Cloud.session = {}
	Cloud.meta = {"rev": 0, "dirty": false, "wiped": false, "device_id": "", "oauth": {}, "chose": ""}
	Cloud._save_session()
	Cloud._save_meta()
	_applying_wipe()
	await Cloud.start_for_test(fake)
	_check("account: fresh browser is asked to choose", Cloud.needs_choice() and not Save.has_save())
	opened.clear()
	await Cloud.sign_in_google()
	_check("account: fresh browser signs in (no link, so no 'already used')", opened.size() == 1 and str(opened[0]).contains("/auth/v1/authorize?provider=google"))
	await Cloud._take_oauth_return(fake.google_return(opened[0], "parames@gmail.com"))
	await Cloud.sync()
	_check("account: fresh browser gets the account's save", Cloud.user_id() == guest and _local_gen() == 20 and Cloud.state == Cloud.State.OK and not Cloud.needs_choice())
	# a cancelled / failed Google page
	await Cloud._take_oauth_return("error=access_denied&error_description=The+user+denied")
	_check("account: Google error shown", Cloud.auth_error.contains("The user denied") and Cloud.user_id() == guest)
	Cloud.auth_error = ""
	# sign out: upload first, then a fresh guest with an empty local save; the account keeps its save
	Save.write(_fake_run(21))
	var ok: bool = await Cloud.sign_out()
	_check("account: sign out uploads, then a new guest", ok and Cloud.is_guest() and Cloud.user_id() != guest and Cloud.user_id() != "")
	_check("account: signed-out device has no save, account keeps it", not Save.has_save() and int(fake.rows[guest].data.meta.gen) == 21)
	_check("account: after sign out the title asks again", Cloud.needs_choice())
	fake.online = false
	_check("account: guest cannot sign out", not await Cloud.sign_out())
	fake.online = true
	main.hud.settings_panel.close()
	Cloud.navigate_hook = Callable()
	Save.wipe()
	Cloud.transport = null
	Cloud.state = Cloud.State.OFF
	Cloud.url = ""
	Cloud.session = {}
	Cloud.status_changed.emit()


## MV-148: a portrait phone's AUTO camera fills the screen with the main body (whole-number scale, crisp pixels),
## trailers stay a swipe away, landscape and the switch keep the old framing. Window is 780x1688 (S = 2).
func _portrait_fit_test() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	var trailers := Game.trailers()
	_check("view: portrait AUTO is not the wide convoy view (S %d, world %d, trailers %d)" % [main.pixel_scale, main.world_scale, trailers],
		main.world_scale >= main.pixel_scale and is_equal_approx(main.world_scale, main.target_ws()))
	_check("view: the main body fits the screen width", Vehicle.MAIN_W * main.world_scale <= win.x)
	# pinch / wheel walk the distinct zoom levels and can always get back to AUTO (fill the screen)
	if is_equal_approx(main._ws_for("auto"), main._ws_for("normal")):
		_check("view: zoom ladder here = wide, auto (%s)" % str(main.zoom_ladder()), main.zoom_ladder() == ["wide", "auto"])
	main.set_zoom_mode("normal")
	main.zoom_step(1)
	_check("view: zooming in from normal returns to auto", main.zoom_mode == "auto")
	main.zoom_step(-1)
	main.zoom_step(-1)
	_check("view: zooming out stops at the widest level", main.zoom_mode == main.zoom_ladder()[0] and main.world_scale < main.pixel_scale)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	main._unhandled_input(wheel)
	_check("view: mouse wheel up from wide -> auto (%s)" % main.zoom_mode, main.zoom_mode == "auto" and main.world_scale >= main.pixel_scale)
	await wait(0.4)
	if trailers > 0:
		_check("view: a swipe reaches the end of the convoy (pan %.0f)" % main.pan_right, main.pan_right > main.PAN_LIMIT)
	# smaller UI pixels (S - 1): now the world zooms in past S, through the rounded-up viewport
	Settings.set_value("ui_scale", "small")
	await wait(0.8)
	var ws: float = main.world_scale
	_check("view: zoomed in past the UI scale (S %d, world %d)" % [main.pixel_scale, ws], ws > main.pixel_scale)
	_check("view: every art pixel is exactly %d screen px" % int(ws),
		is_equal_approx(main.world_tex.size.x * main.pixel_scale, main.world_vp.size.x * ws)
		and is_equal_approx(main.world_tex.size.y * main.pixel_scale, main.world_vp.size.y * ws)
		and main.world_tex.size.x * main.pixel_scale >= win.x - 0.5)
	_check("view: still fits the main body", Vehicle.MAIN_W * ws <= win.x)
	var mid: Vector2 = Vector2(win.x * 0.5, win.y * 0.6) / main.pixel_scale
	_check("view: tap mapping round-trips at this zoom", main.world_to_screen(main.screen_to_world(mid)).distance_to(mid) < 0.6)
	await shot("portrait_fit_small_ui")
	Settings.set_value("ui_scale", "auto")
	await wait(0.6)
	# switch off: the old framing (wide when there are trailers)
	Features.set_override("features", "portrait_fit", false)
	await wait(0.6)
	_check("view: switch off -> old framing", main.world_scale == (main.pixel_scale - 1.0 if trailers > 0 else main.pixel_scale))
	Features.set_override("features", "portrait_fit", null)
	await wait(0.6)
	_check("view: GOD readout names the scales", Dev.view_info().contains("UI x%d" % int(main.pixel_scale)))


## flush until the queue is empty (the full run has hundreds of trace entries by now); false if a batch fails
func _drain_logs() -> bool:
	for i in 50:
		if Telemetry.pending().is_empty():
			return true
		if not await Telemetry.flush():
			return false
	return Telemetry.pending().is_empty()


## MV-116: player logs go up in batches after the privacy notice, wait while offline, respect the opt-out and the
## switch, and a server without rpc_log never breaks the save sync
func _logs_test() -> void:
	var fake = load("res://tools/cloud_fake.gd").new()
	Cloud.session = {}
	Cloud.meta = {"rev": 0, "dirty": false, "wiped": false, "device_id": "", "oauth": {}, "chose": "guest"}
	Cloud._save_session()
	Cloud._save_meta()
	Settings.set_value("telemetry", true)
	await Cloud.start_for_test(fake)
	var uid := Cloud.user_id()
	_check("logs: cloud up and logging allowed", Cloud.state == Cloud.State.OK and Telemetry.active())
	Trace.rec("meta", "logs test first")
	Cloud.meta.log_notice = false     # _process shows it by itself when a run is open; start from "not shown"
	_check("logs: nothing sent before the privacy notice", not await Telemetry.flush() and fake.log_calls == 0)
	var was_started := Game.started
	Game.started = true
	Telemetry._notice()
	Game.started = was_started
	_check("logs: privacy notice shown once and remembered", bool(Cloud.meta.log_notice))
	_check("logs: first batch sent", await Telemetry.flush() and fake.log_calls == 1)
	_check("logs: the whole queue drains in batches", await _drain_logs())
	var first := func(e): return str(e.msg) == "logs test first" and str(e.sid) == Trace.session and str(e.version) == BuildInfo.GAME_VERSION
	_check("logs: entries arrive with session, category and version", fake.logs.get(uid, []).any(first))
	# by session id, not by time: this session's own "session start" entry is stamped to 0.01 s and can equal the
	# cursor start (Trace._t0 after a JSON round trip), which made a time comparison fail now and then (MV-172)
	var older: Array = fake.logs[uid].filter(func(e): return str(e.sid) != Trace.session)
	for e in older.slice(0, 5):
		print("[autotest] sent from another session (%s): %.3f %s %s" % [str(e.sid), float(e.t), str(e.cat), str(e.msg)])
	_check("logs: entries from before this session stay local", older.is_empty())
	_check("logs: queue empty after sending", Telemetry.pending().is_empty())
	var calls: int = fake.log_calls
	_check("logs: nothing new = no request", await Telemetry.flush() and fake.log_calls == calls)
	# offline: the entries wait in the trace and go up when the network is back
	fake.online = false
	for i in 3:
		Trace.rec("meta", "logs offline %d" % i)
	_check("logs: offline batch fails, entries kept, save sync untouched", not await Telemetry.flush() and Telemetry.pending().size() >= 3
		and Telemetry.last_error != "" and Cloud.state == Cloud.State.OK)
	fake.online = true
	var offl := func(e): return str(e.msg).begins_with("logs offline")
	_check("logs: back online, the queue goes up", await _drain_logs() and fake.logs[uid].filter(offl).size() == 3)
	# batches of 10: 25 entries need 3 requests, in order, none lost or doubled
	Features.set_override("tune", "logs.batch", 10.0)
	for i in 25:
		Trace.rec("meta", "logs batch %d" % i)
	calls = fake.log_calls
	await _drain_logs()
	var bat: Array = fake.logs[uid].filter(func(e): return str(e.msg).begins_with("logs batch"))
	var in_order := bat.size() == 25
	for i in bat.size():
		in_order = in_order and str(bat[i].msg) == "logs batch %d" % i
	_check("logs: batch size from tune, all 25 in order", fake.log_calls - calls >= 3 and in_order)
	Features.set_override("tune", "logs.batch", null)
	# a server without rpc_log (0004 not run): logs fail quietly, the save still syncs
	fake.no_rpc_log = true
	Trace.rec("meta", "logs no server")
	_check("logs: missing rpc_log keeps the cloud save OK", not await Telemetry.flush() and Cloud.state == Cloud.State.OK)
	fake.no_rpc_log = false
	_check("logs: sent once rpc_log exists", await _drain_logs() and fake.logs[uid].any(func(e): return str(e.msg) == "logs no server"))
	# opt-out and kill switch: nothing leaves the device
	Settings.set_value("telemetry", false)
	Trace.rec("meta", "logs opted out")
	calls = fake.log_calls
	_check("logs: player opt-out sends nothing", not Telemetry.active() and not await Telemetry.flush() and fake.log_calls == calls)
	Settings.set_value("telemetry", true)
	Features.set_override("features", "cloud_logs", false)
	_check("logs: switch off sends nothing", not Telemetry.active() and not await Telemetry.flush() and fake.log_calls == calls)
	Features.set_override("features", "cloud_logs", null)
	# GOD: a test error reaches the logs
	_check("logs: GOD test error is sent", await Dev.logs_test_error() and fake.logs[uid].any(func(e): return str(e.cat) == "error" and str(e.msg).contains("GOD test error")))
	# Settings > ตั้งค่า: the privacy toggle with its notice
	main.hud.settings_panel.open_tab("game")
	await wait(0.2)
	var priv: Array = main.hud.settings_panel._list.find_children("*", "Label", true, false)
	_check("logs: Settings has the privacy toggle and notice", priv.any(func(l): return l.text.contains("ส่งบันทึกการเล่น"))
		and priv.any(func(l): return l.text.contains("ไอดีผู้เล่น")))
	await shot("logs_privacy_settings")
	main.hud.settings_panel.close()
	Save.wipe()
	Cloud.transport = null
	Cloud.state = Cloud.State.OFF
	Cloud.url = ""
	Cloud.session = {}
	Cloud.status_changed.emit()


func _features_test() -> void:
	if not Game.started or main.hud.title_screen.visible:
		# the cloud checks leave the title screen up: start a fresh run so the gates act on a live game
		main.hud.title_screen._go(true)
		await wait(2.5)
		Tutorial.skip()
	Features.clear_overrides()
	Features.layers.remote = {}
	# switches that ship off on purpose: english until all three MV-151 PRs are in
	var ships_off := ["english"]
	var all_on := true
	for k in Features.FEATURES:
		all_on = all_on and (Features.on(k) != (k in ships_off))
	_check("features: every switch on by default (except %s, off)" % ", ".join(ships_off), all_on)
	_check("features: tune falls back to the code constant", Features.num("threat.rate_scale", Threat.RATE_SCALE) == Threat.RATE_SCALE)
	var base: Array = Data.biome(0).events
	_check("features: default event pool = the biome list", Features.event_pool(0, base) == base)
	# dates: Thai local time, a date-only "to" covers the whole day
	_check("features: parse_time reads UTC+7", Features.parse_time("2026-11-14", 7.0, false) == 1794614400.0 - 7 * 3600)
	_check("features: date-only end is 23:59:59", Features.parse_time("2026-11-16", 7.0, true) == Features.parse_time("2026-11-16 23:59:59", 7.0, false))
	_check("features: malformed date is refused", Features.parse_time("16/11/2026", 7.0, false) < 0.0)
	# per-event switch
	var keep := {}
	for k in ["biome", "ev_bag", "ev_bag_biome", "ev_recent"]:
		if Game.s.has(k):
			keep[k] = Game.s[k]
	Game.s.biome = 0
	for k in ["ev_bag", "ev_bag_biome", "ev_recent"]:
		Game.s.erase(k)
	Dev.event_set("raiders", false)
	var seen_raiders := false
	for i in 200:
		if Game.next_event_id() == "raiders":
			seen_raiders = true
	_check("features: an event switched off never comes up (200 draws)", not seen_raiders and Dev.any_active())
	Dev.event_set("raiders", null)
	# weight
	Features.set_override("events", "trader", {"weight": 3.0})
	_check("features: weight 3 = three cards per round", Game._weighted(base).count("trader") == 3 and Game._weighted(base).count("cache") == 1)
	Features.set_override("events", "trader", {"weight": 0.0})
	_check("features: weight 0 drops the event", not Features.event_pool(0, base).has("trader"))
	Features.set_override("events", "trader", null)
	# date window: the bunker (a mountain event) shows on every road during 14-16 Nov only
	Features.set_override("events", "bunker", {"biomes": ["*"], "from": "2026-11-14", "to": "2026-11-16"})
	Features.now_override = Features.parse_time("2026-11-16 23:30", 7.0, false)
	_check("features: windowed event joins every biome inside the window", Features.event_pool(0, base).has("bunker") and Features.event_pool(1, Data.biome(1).events).has("bunker"))
	Features.now_override = Features.parse_time("2026-11-17 00:01", 7.0, false)
	_check("features: windowed event leaves after the window", not Features.event_pool(0, base).has("bunker"))
	Features.now_override = Features.parse_time("2026-11-13 12:00", 7.0, false)
	_check("features: windowed event not there before the window", not Features.event_pool(0, base).has("bunker"))
	Features.now_override = 0.0
	Features.set_override("events", "bunker", null)
	Dev.feature_set("road_events", false)
	_check("features: road_events off empties the deck", Game.next_event_id() == "")
	Dev.feature_set("road_events", null)
	for k in ["ev_bag", "ev_bag_biome", "ev_recent"]:
		Game.s.erase(k)
	Game.s.merge(keep, true)
	# remote file rules
	_check("features: garbage remote is refused", not Features.apply_remote("nope") and Features.on("raids"))
	_check("features: remote for a newer game is refused", not Features.apply_remote({"min_game": "99.0", "features": {"raids": false}}) and Features.on("raids"))
	var ok := Features.apply_remote({"min_game": "1.0", "features": {"raids": false, "made_up": false}, "tune": {"threat.rate_scale": 999, "made.up": 1}, "events": {"no_such_event": {"on": false}, "cache": {"on": false}}})
	_check("features: remote applies known keys only", ok and not Features.on("raids") and not Features.event_cfg("cache").get("on", true)
		and not Features.layers.remote.get("features", {}).has("made_up") and not Features.layers.remote.get("events", {}).has("no_such_event"))
	_check("features: remote numbers are clamped", Features.num("threat.rate_scale", 1.0) == 10.0)
	_check("features: source() names the remote layer", Features.source("features", "raids") == "remote" and Features.source("features", "strangers") == "default")
	Dev.feature_set("raids", true)
	_check("features: tester override beats remote", Features.on("raids") and Features.source("features", "raids") == "dev")
	Dev.feature_set("raids", null)
	# raids off: a quiet road even at threat 90 (the checkpoint warlord is exempt, so step off the checkpoint)
	var km := float(Game.s.km)
	Game.s.km = maxf(0.0, km - 5.0) if Game.at_checkpoint() else km
	Threat._set_threat(90.0)
	var raided := false
	for i in 1200:
		if Threat.tick(0.1) or Threat.phase != "quiet":
			raided = true
	_check("features: raids off = no raid for 120 s at threat 90", not raided and Threat.threat() == 0.0)
	Game.s.km = km
	Features.layers.remote = {}
	Features.remote_status = "off"
	# ?ff= overrides
	Features.parse_overrides("raids:off,event.trader:off,tune.threat.roll_k:0.5,bogus:on")
	_check("features: ?ff= switches, events and tune", not Features.on("raids") and not Features.event_cfg("trader").get("on", true) and Features.num("threat.roll_k", 0.3) == 0.5)
	Features.clear_overrides()
	_check("features: clear_overrides restores defaults", Features.on("raids") and not Features.has_dev_overrides())
	# dev overrides persist in dev.cfg
	Dev.feature_set("large_rooms", false)
	Features.layers.dev = {}
	Features._load_dev()
	_check("features: tester override survives a reload", not Features.on("large_rooms"))
	_check("features: large_rooms off blocks knock-through", Game.merge_block(0, 1) == "ระบบรวมห้องปิดใช้งานชั่วคราว")
	Dev.feature_set("roof_deck", false)
	_check("features: roof_deck off hides the mod", not Mods.enabled("roof_deck") and not Mods.can_install("roof_deck") and Mods.enabled("armor_plates"))
	# strangers off: even a sure elite joins straight away
	Dev.feature_set("strangers", false)
	var q0 := Inspection.queue().size()
	var d := Game.offer_recruit("radio", 1000.0)
	_check("features: strangers off = no inspection queue", not d.is_empty() and Inspection.queue().size() == q0)
	if not d.is_empty():
		Game.s.dwellers.erase(d)
		Game.dwellers_changed.emit()
	# encounters off: a sure encounter chance still rolls nothing
	Dev.feature_set("encounters", false)
	Dev.tune_set("encounter.base_chance", 1.0)
	_check("features: tune feeds the encounter chance", is_equal_approx(Encounter.chance_for("scav"), 1.0 + Encounter.DANGER_CHANCE * float(Expedition.site_def("scav").danger)))
	if not Expedition.active():
		var ids := []
		for dw in Game.s.dwellers:
			if not Game.is_away(dw) and ids.size() < Expedition.min_team():
				ids.append(int(dw.id))
		Dev.feature_set("expeditions", false)
		_check("features: expeditions off refuses to start", not Expedition.start("scav", ids, {}) and not Expedition.active())
		Dev.feature_set("expeditions", null)
		if Expedition.start("scav", ids, {}):
			_check("features: encounters off = none scheduled", (Expedition.state().get("enc", {}) as Dictionary).is_empty())
			Dev.finish_expedition()
	# the tab renders
	main.hud.open_panel("god")
	main.hud.panels.god.tab = "feat"
	main.hud.panels.god.refresh()
	await wait(0.5)
	_check("features: GOD tab lists switches, events and tune", main.hud.panels.god._list.get_child_count() > 12)
	await shot("god_panel_features")
	main.hud.panels.god.close()
	_check("features: snapshot lists what is off", Features.snapshot().off.has("strangers"))
	Features.clear_overrides()
	_check("features: GOD hidden again clears nothing left on", Features.on("strangers") and Features.on("encounters"))



## v4.6 engine bay: migration from the slot-0 engine room, heat / auto-rest / stall, jobs, engine fit + swap,
## noise -> threat calibration, the engine menu and its GOD actions
func _engine_bay_test() -> void:
	_no_events()
	var e := EngineBay.st()
	# --- migration of a v4.5 save (engine room on cell 0, three crew in it)
	var keep_room: Dictionary = Game.s.rooms[Data.ENGINE_SLOT].duplicate(true)
	var keep_cab: Dictionary = Game.s.cab.duplicate(true)
	var keep_rooms := {}
	for d in Game.s.dwellers:
		keep_rooms[int(d.id)] = int(d.room)
	var movers := []
	for d in Game.s.dwellers:
		if Game.squad_role(d) < 0 and not Game.is_away(d) and movers.size() < 3:
			movers.append(d)
	Game.s.erase("cab")
	Game.s.rooms[Data.ENGINE_SLOT] = {"type": "engine", "level": 3, "job": {}, "build": {}}
	for d in movers:
		d.room = Data.ENGINE_SLOT
	Game._migrate_cab()
	_check("engine mig: cell 0 freed", Game.s.rooms[Data.ENGINE_SLOT].type == "empty")
	_check("engine mig: cab keeps the room level", int(Game.s.cab.level) == 3 and EngineBay.level() == 3)
	_check("engine mig: two crew move into the cab", movers.size() < 2 or (int(movers[0].room) == Data.CAB_SLOT and int(movers[1].room) == Data.CAB_SLOT))
	_check("engine mig: the third goes idle", movers.size() < 3 or int(movers[2].room) == -1)
	_check("engine mig: cab capacity", Game.room_capacity(Data.CAB_SLOT) == Data.CAB_WORKERS and Game.has_room(Data.CAB_SLOT))
	Game.s.rooms[Data.ENGINE_SLOT] = keep_room
	Game.s.cab = keep_cab
	for d in Game.s.dwellers:
		d.room = keep_rooms.get(int(d.id), -1)
	Game.rooms_changed.emit()
	Game.dwellers_changed.emit()
	# --- calibration: the stock diesel makes the same noise as before v4.6
	EngineBay.uninstall()
	e.merge(EngineBay.default_state(), true)
	e.job = {}
	Game.s.stall = 0.0
	_check("engine: stock diesel4", EngineBay.type_id() == "diesel4" and EngineBay.mode() == "normal")
	_check("engine: diesel noise = old threat term", Haul.load_ratio() > 1.0 or is_equal_approx(EngineBay.noise_mult(), 1.0))
	EngineBay.set_mode("silent")
	_check("engine: silent refused for diesel", EngineBay.mode() == "normal")
	# --- fit + swap
	var turbine := Loot.roll_item("engine", 20, 2, "gas_turbine")
	var v8 := Loot.roll_item("engine", 5, 1, "rusty_v8")
	Loot.add_to_stash(turbine)
	Loot.add_to_stash(v8)
	_check("engine: a turbine is too big for the van", Game.tier() != "van" or not EngineBay.fits(turbine))
	if Game.tier() == "van":
		_check("engine: oversized install refused", not Loot.equip_from_stash(int(turbine.uid)) and EngineBay.type_id() == "diesel4")
	_check("engine: V8 installs", Loot.equip_from_stash(int(v8.uid)) and EngineBay.type_id() == "v8")
	_check("engine: V8 is faster and louder", EngineBay.speed_mult() > 1.0 and EngineBay.db() > 90.0)
	_check("engine: V8 burns more fuel", float(EngineBay.burn_pm().get("fuel", 0.0)) > Haul.fuel_pm())
	_check("engine: owned list shows both", EngineBay.owned_engines().size() >= 2)
	# --- heat: hard driving in the desert sun auto-rests, parking cools it back down
	EngineBay.set_mode("boost")
	e.heat = 40.0
	e.auto_rest = true
	e.rest_at = 110.0
	var mins := 0
	while not EngineBay.resting() and mins < 240:
		EngineBay.tick(60.0, 1.0, true, false)
		mins += 1
	_check("engine: boosting a V8 overheats -> auto-rest (%d min, settle %d C)" % [mins, int(EngineBay.settle_temp())], EngineBay.resting() and EngineBay.heat() >= 109.0)
	_check("engine: resting blocks travel", Game.blocked_reason().begins_with("พักเครื่อง"))
	mins = 0
	while EngineBay.resting() and mins < 240:
		EngineBay.tick(60.0, 1.0, false, false)
		mins += 1
	_check("engine: cools down and drives on (%d min)" % mins, not EngineBay.resting() and EngineBay.heat() <= EngineBay.RESUME_AT)
	# auto-rest off: it runs until it dies on its own and takes damage
	e.auto_rest = false
	e.heat = 100.0
	var c0 := EngineBay.cond()
	mins = 0
	while not EngineBay.resting() and mins < 240:
		EngineBay.tick(60.0, 1.0, true, false)
		mins += 1
	_check("engine: no auto-rest -> stalls at 120 C with damage", EngineBay.resting() and EngineBay.cond() <= c0 - 4.9)
	e.resting = false
	e.heat = 40.0
	e.auto_rest = true
	EngineBay.set_mode("normal")
	# stock-ish driving stays under the rest line
	_check("engine: normal V8 cruise settles below auto-rest", EngineBay.settle_temp() < 110.0 or Haul.load_ratio() > 1.0 or EngineBay.ambient() >= 40.0)
	# --- jobs
	Game.s.res.scrap = maxf(500.0, float(Game.s.res.scrap))
	Game.s.res.fuel = maxf(50.0, float(Game.s.res.fuel))
	Game.s.res.water = maxf(50.0, float(Game.s.res.water))
	e.oil = 10.0
	_check("engine job: oil change starts", EngineBay.start_job("oil"))
	_check("engine job: oil change parks the vault", EngineBay.job_holds() and Game.blocked_reason() != "")
	_check("engine job: one at a time", EngineBay.job_block("coolant") != "")
	for i in 120:
		EngineBay._tick_job(1.0, false)
	_check("engine job: oil full", float(e.oil) >= 99.0 and (e.job as Dictionary).is_empty())
	e.cond = 50.0
	_check("engine job: tune", EngineBay.start_job("tune"))
	Dev.engine_finish_job()
	_check("engine job: tune +20%", EngineBay.cond() >= 69.0)
	# --- wear + breakdowns
	Dev.engine_breakdown()
	_check("engine: GOD breakdown stalls", float(Game.s.stall) > 0.0 and EngineBay.state_key() == "broken")
	Game.s.stall = 0.0
	Dev.engine_set("cond", 100.0)
	var n0 := Loot.stash().size()
	Dev.engines_all()
	_check("engine: GOD gives every engine", Loot.stash().size() >= n0 + 7)
	# --- the menu: tap the cab, every tab renders
	var cv: CabView = main.vehicle.cab_view
	_check("engine: cab room view exists", cv != null and cv.interior.texture != null)
	_check("engine: tap target inside the cab is the cab", cv != null and main.vehicle.slot_at(cv.global_position + cv.size * cv.global_scale * 0.5) == Data.CAB_SLOT)
	main.hud.open_panel("engine")
	await wait(0.6)
	_check("engine panel opens", main.hud.panels.engine.is_open)
	await shot("engine_status")
	for tb in ["engines", "jobs"]:
		main.hud.panels.engine.tab = tb
		main.hud.panels.engine.refresh()
		await wait(0.4)
		await shot("engine_" + tb)
	main.hud.panels.engine.tab = "status"
	main.hud.panels.engine.close()
	await wait(0.3)
	main.hud.open_panel("god")
	main.hud.panels.god.tab = "veh"
	main.hud.panels.god.refresh()
	await wait(0.4)
	_check("god: engine bay row", _find_text(main.hud.panels.god, "ห้องเครื่อง"))
	main.hud.panels.god.close()
	# MV-40: switch engine_bay off = the game before v4.6 (stock diesel numbers, nothing simulated, save kept)
	e.heat = 115.0
	e.cond = 20.0
	e.resting = true
	e.mode = "boost"
	Features.set_override("features", "engine_bay", false)
	_check("engine switch off: stock diesel numbers", EngineBay.type_id() == "diesel4" and EngineBay.mode() == "normal"
		and is_equal_approx(EngineBay.speed_mult(), 1.0) and is_equal_approx(EngineBay.tow_mult(), 1.0)
		and is_equal_approx(EngineBay.noise_mult(), 1.0) and is_equal_approx(EngineBay.weight(), 0.0))
	_check("engine switch off: no rest or job holds the vehicle", EngineBay.blocked_reason() == "" and not EngineBay.resting())
	EngineBay.tick(60.0, 1.0, true, false)
	_check("engine switch off: no heat / wear simulated", is_equal_approx(float(e.heat), 115.0) and is_equal_approx(float(e.cond), 20.0))
	Features.set_override("features", "engine_bay", null)
	_check("engine switch on again: the saved engine state is back", EngineBay.resting() and EngineBay.heat() >= 115.0 and EngineBay.mode() == "boost")
	Dev.engine_bay_switch(false)
	var off_ok := not EngineBay.on()
	Dev.engine_bay_switch(true)
	_check("engine switch: GOD button flips it", off_ok and EngineBay.on())
	Features.set_override("features", "engine_bay", null)
	# back to the stock engine for the rest of the run
	EngineBay.uninstall()
	e.merge(EngineBay.default_state(), true)
	e.job = {}


## MV-111: semver + release channel badge + changelog / release tooling
## MV-150: contextual tips: Sgt. Mark explains a system once, the first time its window opens
func _tips_test() -> void:
	Tutorial.skip()
	Settings.set_value("tips", true)
	Tutorial.reset_tips()
	var hud = main.hud
	hud.open_panel("map")
	await wait(0.4)
	_check("tips: first time the map opens, Sgt. Mark's tip shows", hud.tip_card.visible and hud.tip_card.key == "map"
		and hud.tip_card._text.text == Tutorial.tip_text("map") and hud.tip_card._text.text != "")
	await shot("tip_map")
	hud.tip_card.dismiss()
	hud.panels.map.close()
	await wait(0.2)
	hud.open_panel("map")
	await wait(0.4)
	_check("tips: shown once (seen after Got it)", Tutorial.tip_seen("map") and not hud.tip_card.visible)
	hud.panels.map.close()
	_check("tips: kept with the account (survive generations)", "tutorial" in Account.SHARED and (Game.s.tutorial.tips as Array).has("map"))
	Features.set_override("features", "expeditions", false)
	_check("tips: a switched-off system gets no tip", Tutorial.pending_tip(["expedition"]) == "")
	Features.set_override("features", "expeditions", null)
	_check("tips: an unseen, unlocked system does", Tutorial.pending_tip(["expedition"]) == "expedition")
	Settings.set_value("tips", false)
	_check("tips: player setting off -> none", Tutorial.pending_tip(["solar"]) == "")
	Settings.set_value("tips", true)
	Features.set_override("features", "tutorial_tips", false)
	_check("tips: switch off -> none", Tutorial.pending_tip(["solar"]) == "")
	Features.set_override("features", "tutorial_tips", null)
	Tutorial.restart()
	_check("tips: never on top of the first-run tutorial", Tutorial.pending_tip(["solar"]) == "")
	Tutorial.skip()
	Dev.tip_show("solar")
	await wait(0.4)
	_check("tips: GOD shows a tip again", hud.panels.solar.is_open and hud.tip_card.key == "solar")
	hud.tip_card.dismiss()
	hud.panels.solar.close()
	var all_th := true
	for k in Tutorial.TIPS:
		all_th = all_th and Loc.t(Tutorial.TIPS[k].text) != "" and str(Tutorial.TIPS[k].text).contains("ครับ")
	_check("tips: every tip is in Sgt. Mark's voice", all_th)
	await wait(0.2)


func _qte_index(id: String, action: String) -> int:
	var chs: Array = Data.EVENTS[id].choices
	for i in chs.size():
		if str(chs[i].action) == action:
			return i
	return -1


## MV-134: quick-time road events: a clock by danger, the crew's cautious pick on time-out, paused while idle
func _qte_test() -> void:
	_no_events()
	var ep = main.hud.event_popup
	if Game.active_event != "":
		Game.cancel_event()
		ep.close()
	Settings.set_value("event_timer", "normal")
	var d0 := Game.event_danger("cache")
	_check("qte: time by danger (cache %d -> %.1f s)" % [d0, Game.event_decide_sec("cache")],
		is_equal_approx(Game.event_decide_sec("cache"), clampf(30.0 / (1.0 + 0.5 * d0), 5.0, 30.0))
		and Game.event_decide_sec("raiders") < Game.event_decide_sec("cache"))
	var t0 := Game.event_decide_sec("radstorm")
	Settings.set_value("event_timer", "long")
	_check("qte: 'long' setting doubles it", is_equal_approx(Game.event_decide_sec("radstorm"), t0 * 2.0))
	Settings.set_value("event_timer", "off")
	_check("qte: 'off' setting = no timer", Game.event_decide_sec("radstorm") == 0.0)
	Settings.set_value("event_timer", "normal")
	Features.set_override("features", "event_timer", false)
	_check("qte: switch off = no timer", Game.event_decide_sec("radstorm") == 0.0)
	Features.set_override("features", "event_timer", null)
	_check("qte: time-out picks the cautious choice", Game.event_auto_choice("cache") == _qte_index("cache", "ignore")
		and Game.event_auto_choice("radstorm") == _qte_index("radstorm", "shelter") and Game.event_auto_choice("raiders") == _qte_index("raiders", "ram"))
	# through the real pop-up: a player who is there times out, an idle one doesn't
	Game.trigger_event("cache")
	await wait(0.3)
	_check("qte: the pop-up shows a clock", ep.is_open and ep.decide_left > 0.0 and ep._timer_bar != null)
	await shot("qte_event_timer")
	ep.since_input = 999.0
	var left: float = ep.decide_left
	await wait(0.5)
	_check("qte: idle player (no touch for 20 s) -> the clock waits", not ep.clock_running() and is_equal_approx(ep.decide_left, left) and Game.active_event == "cache")
	ep.since_input = 0.0
	ep.decide_left = 0.1
	await wait(0.4)
	_check("qte: time's up -> the crew drives on, the event ends", Game.active_event == ""
		and Trace.entries.any(func(e): return str(e.msg).begins_with("time out cache")))
	ep.close()
	await wait(0.2)
	# a fight picked for the commander goes out with the two strongest crew
	Game.trigger_event("raiders")
	await wait(0.3)
	ep._choice = _qte_index("raiders", "fight")
	ep._selected = []
	ep.since_input = 0.0
	ep.time_out()
	_check("qte: a fight on time-out sends the strongest crew", Game.active_event == "" and ep._selected.size() > 0
		and int(ep._selected[0]) == int(Game.auto_defenders()[0]))
	ep.close()
	await wait(0.2)
	Dev.event_quick_timeout()
	await wait(2.6)
	_check("qte: GOD 'time out in 2 s' button", Game.active_event == "")
	if ep.is_open:
		ep.close()
	Settings.set_value("event_timer", "off")      # back to waiting for the rest of the run
	await wait(0.2)


## MV-178: the nine redesigned creatures keep their exact atlas sizes / frame sets and show up in game (2x shots)
func _creatures_test() -> void:
	var sizes := {"pet_dog": [16, 11, 4], "pet_cat": [14, 11, 4], "pet_hen": [11, 11, 4], "en_wolf": [20, 13, 2],
		"en_spitter": [16, 20, 2], "en_brute": [20, 24, 2], "boss_wolf": [40, 26, 2], "boss_golem": [40, 44, 2],
		"boss_scorpion": [48, 28, 2]}
	var ok := true
	for id in sizes:
		for f in int(sizes[id][2]):
			var key := "%s_%d" % [id, f]
			var r = Atlas.regions.get(key)
			if r == null or int(r[2]) != int(sizes[id][0]) or int(r[3]) != int(sizes[id][1]):
				ok = false
				print("[autotest] creature frame wrong: %s %s" % [key, str(r)])
	_check("creatures: 24 redesigned frames at their exact native sizes", ok)
	var was_win := get_window().size
	var was_vault := int(Game.s.vault_level)
	# landscape at UI scale 2 (one art pixel = 2 screen pixels): the fight behind the vehicle is on screen
	get_window().size = Vector2i(1280, 640)
	Game.s.vault_level = maxi(was_vault, 3)          # the desert and forest warlords need their areas open
	_no_events()
	Dev.kill_enemies()
	Dev.clear_pets()
	await wait(0.3)
	for k in ["dog", "cat", "hen"]:
		Dev.add_pet(k)
	await wait(1.5)
	var npets: int = main.vehicle.pets_root.get_children().filter(func(n): return not n.is_queued_for_deletion()).size()
	_check("creatures: the three pets roam the vehicle (%d in the save, %d on screen)" % [Game.s.pets.size(), npets],
		Game.s.pets.size() == 3 and npets == 3)
	await shot("creatures_pets_2x")
	Combat.reset_wave(40)                              # tough enough that the squad doesn't drop them before the shot
	# one queue: Combat.debug_spawn replaces whatever was queued, so three Dev.spawn_mob calls leave only the last
	var q := []
	for i in 3:
		q.append({"t": 0.2 + i * 0.4, "mob": ["rad_wolf", "spitter", "brute"][i], "lvl": Combat.enemy_level(), "no_mutate": true})
	Combat.debug_spawn(q, false)
	await wait(1.8)
	var sprites := Combat.enemies.map(func(e): return str(e.sprite))
	_check("creatures: wolf, spitter and brute spawn (%s)" % ", ".join(sprites),
		sprites.has("en_wolf") and sprites.has("en_spitter") and sprites.has("en_brute"))
	await shot("creatures_enemies_2x")
	for b in [[0, "boss_golem"], [1, "boss_scorpion"], [2, "boss_wolf"]]:
		Dev.kill_enemies()
		Dev.goto_biome(int(b[0]))
		await wait(0.5)
		Dev.spawn_boss("warlord")
		await wait(2.5)
		_check("creatures: %s is the warlord of area %d (active %s, enemies %s)" % [b[1], int(b[0]) + 1, Combat.active(),
			str(Combat.enemies.map(func(e): return str(e.sprite)))], str(Combat.current_boss().get("sprite", "")) == b[1])
		await shot("creatures_%s_2x" % b[1])
	Dev.kill_enemies()
	Dev.clear_pets()
	Dev.goto_biome(0)
	Combat.reset_wave(1)
	Game.s.vault_level = was_vault
	get_window().size = was_win
	await wait(0.6)


## MV-175: screen shake at half strength by default, tunable, off in settings, same size on screen at any zoom
func _shake_test() -> void:
	var was: bool = bool(Settings.get_value("shake"))
	Settings.set_value("shake", true)
	main._shake = 0.0
	Dev.shake_test(6.0)
	_check("shake: half strength by default (%.2f)" % main._shake, is_equal_approx(main._shake, 3.0))
	main._shake = 0.0
	Features.set_override("tune", "fx.shake", 1.0)
	main.shake(6.0)
	_check("shake: tune fx.shake 1.0 = the old strength", is_equal_approx(main._shake, 6.0))
	Features.set_override("tune", "fx.shake", null)
	main._shake = 0.0
	Settings.set_value("shake", false)
	main.shake(6.0)
	_check("shake: off in settings = no shake", main._shake == 0.0)
	Settings.set_value("shake", true)
	main.shake(6.0)
	await get_tree().process_frame
	var lim: float = ceilf(main._shake * main.view_k + 0.5)
	_check("shake: camera offset scaled to the zoom (|%.0f| <= %.0f)" % [main.camera.offset.x, lim],
		absf(main.camera.offset.x) <= lim and absf(main.camera.offset.y) <= lim)
	Settings.set_value("shake", was)
	await wait(0.6)


## visible Label / Button texts under a node that still contain Thai
func _thai_left(root: Node) -> Array:
	var out := []
	for c in root.find_children("*", "Control", true, false):
		if not (c as Control).is_visible_in_tree():
			continue
		var t := ""
		if c is Label:
			t = (c as Label).text
		elif c is Button:
			t = (c as Button).text
		t = (c as Control).atr(t)      # what is drawn: .text keeps the key, auto_translate translates the drawing
		if t != "" and RegEx.create_from_string("[\\x{0E00}-\\x{0E7F}]").search(t) != null:
			out.append(t.replace("\n", " ").left(70))
	return out


## MV-151: English through TranslationServer; Thai stays the key and the fallback
func _english_test() -> void:
	# Thai is the source: with English loaded, Thai mode must stay Thai (the fallback locale must not be "en")
	_check("english: Thai mode shows Thai", TranslationServer.get_locale() == "th" and Loc.t("ตั้งค่า") == "ตั้งค่า"
		and str(ProjectSettings.get_setting("internationalization/locale/fallback")) == "th")
	Features.set_override("features", "english", true)
	Settings.set_value("lang", "en")
	await wait(0.2)
	_check("english: locale follows the setting", TranslationServer.get_locale() == "en" and Loc.lang() == "en")
	_check("english: Loc.t translates, with context", Loc.t("ตั้งค่า") == "Settings" and Loc.t("ว่าง", "slot") == "Empty" and Loc.t("ว่าง") == "Idle")
	_check("english: format templates keep their placeholders", Loc.t("รุ่นที่ %d · Vault %d · %.1f กม.") % [3, 4, 12.5] == "Generation 3 · Vault 4 · 12.5 km")
	_check("english: untranslated text stays Thai", Loc.t("ข้อความทดสอบที่ไม่มีคำแปล") == "ข้อความทดสอบที่ไม่มีคำแปล")
	var sp = main.hud.settings_panel
	for tab in ["game", "data", "about"]:
		sp.open_tab(tab)
		await wait(0.3)
		var left := _thai_left(sp)
		for t in left:
			print("[autotest] english: Thai left in settings/%s: %s" % [tab, t])
		_check("english: settings %s tab has no Thai left (%d)" % [tab, left.size()], left.is_empty())
		await shot("english_settings_" + tab)
	sp.close()
	await wait(0.2)
	var hud_left := _thai_left(main.hud)
	for t in hud_left:
		print("[autotest] english: Thai left in the HUD: %s" % t)
	await shot("english_hud")
	Features.set_override("features", "english", false)
	await wait(0.1)
	_check("english: switch off -> Thai even with English picked", TranslationServer.get_locale() == "th" and Loc.t("ตั้งค่า") == "ตั้งค่า")
	Features.set_override("features", "english", null)
	Dev.lang_set("en")
	_check("english: GOD language button turns English on", Loc.lang() == "en" and TranslationServer.get_locale() == "en")
	Dev.lang_set("th")
	Features.set_override("features", "english", null)
	_check("english: GOD back to Thai", Loc.lang() == "th" and TranslationServer.get_locale() == "th")
	await wait(0.1)


## MV-112: one build, the environment from the host name; only production hosts reach the production project
func _env_test() -> void:
	_check("env: production host is prod", BuildInfo.env_for_host("apocarlypse-mobile-vault.vercel.app") == "prod")
	_check("env: Vercel branch URLs", BuildInfo.env_for_host("apocarlypse-mobile-vault-git-staging-maxexq.vercel.app") == "staging"
		and BuildInfo.env_for_host("apocarlypse-mobile-vault-git-uat-maxexq.vercel.app") == "uat"
		and BuildInfo.env_for_host("apocarlypse-mobile-vault-git-main-maxexq.vercel.app") == "prod")
	_check("env: PR previews and unknown hosts are dev", BuildInfo.env_for_host("apocarlypse-mobile-vault-k2j3h4-maxexq.vercel.app") == "dev"
		and BuildInfo.env_for_host("apocarlypse-mobile-vault-git-mv-112-env-maxexq.vercel.app") == "dev"
		and BuildInfo.env_for_host("evil.example.com") == "dev")
	_check("env: desktop / editor (tests) is dev, on the test project", BuildInfo.env() == "dev" and BuildInfo.cloud_project() == "test")
	var both := {"projects": {"prod": {"url": "https://p.supabase.co", "anon_key": "pk"}, "test": {"url": "https://t.supabase.co", "anon_key": "tk"}}}
	_check("env: per-project config picks its section", str(Cloud.pick_config(both, "prod").url) == "https://p.supabase.co"
		and str(Cloud.pick_config(both, "test").url) == "https://t.supabase.co")
	var flat := {"url": "https://p.supabase.co", "anon_key": "pk"}
	_check("env: a flat (production) config is never used outside prod", not Cloud.pick_config(flat, "prod").is_empty()
		and Cloud.pick_config(flat, "test").is_empty() and Cloud.pick_config({"projects": {"prod": {}}}, "test").is_empty())
	_check("env: remote config file per environment", Features.remote_files("prod") == ["features.json"]
		and Features.remote_files("staging") == ["features.staging.json", "features.json"])
	_check("env: About shows the environment", BuildInfo.rows().any(func(r): return str(r[0]) == "ENV" and str(r[1]).begins_with("DEV")))
	var tag := UIKit.env_tag()
	_check("env: DEV SERVER badge outside production", tag.visible and tag.text == "DEV SERVER")
	Dev.env_preview("prod")
	UIKit.refresh_env_tag(tag)
	_check("env: no badge in production (GOD preview)", not tag.visible)
	Dev.env_preview("")
	Features.set_override("features", "env_badge", false)
	UIKit.refresh_env_tag(tag)
	_check("env: switch env_badge hides it", not tag.visible)
	Features.set_override("features", "env_badge", null)
	tag.free()
	_check("env: trace session start records it", Trace.entries.any(func(e): return str(e.msg) == "start" and str(e.get("data", {}).get("env", "")) == "dev"))


func _version_test() -> void:
	var v := BuildInfo.GAME_VERSION
	var p := BuildInfo.parse_version(v)
	_check("version: GAME_VERSION is semver X.Y.Z[-alpha|beta|rc.N]", RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+(-(alpha|beta|rc)\\.\\d+)?$").search(v) != null)
	_check("version: parse 4.7.0-beta.2", BuildInfo.parse_version("v4.7.0-beta.2") == {"major": 4, "minor": 7, "patch": 0, "pre": ["beta", "2"]})
	_check("version: short forms fill zeros", BuildInfo.ver_cmp("4.6", "4.6.0") == 0 and BuildInfo.ver_cmp("4.3", v) < 0)
	var order := ["4.6", "4.7.0-alpha.1", "4.7.0-alpha.2", "4.7.0-alpha.10", "4.7.0-beta.1", "4.7.0-rc.1", "4.7.0", "4.7.1", "4.10.0", "5.0.0-alpha.1"]
	var sorted_ok := true
	for i in order.size() - 1:
		sorted_ok = sorted_ok and BuildInfo.ver_cmp(order[i], order[i + 1]) < 0 and BuildInfo.ver_cmp(order[i + 1], order[i]) > 0
	_check("version: semver precedence (pre-release < release, numbers as numbers)", sorted_ok)
	_check("version: channel from the pre-release tag", BuildInfo.release_channel("4.7.0-alpha.1") == "alpha" and BuildInfo.release_channel("4.8.0-beta.3") == "beta"
		and BuildInfo.release_channel("4.8.0-rc.1") == "rc" and BuildInfo.release_channel("4.8.0") == "stable")
	_check("version: current channel %s" % BuildInfo.release_channel(), BuildInfo.release_channel() == ("stable" if p.pre.is_empty() else str(p.pre[0])))
	_check("version: About rows show the channel", BuildInfo.as_text().contains("CHANNEL: ") and BuildInfo.as_text().contains("BUILD: "))
	# the remote features.json version gate uses the same compare
	_check("version: remote min_game 4.3 accepted", Features._accepts({"min_game": "4.3"}))
	_check("version: remote for the stable release refused by its pre-release", Features._accepts({"min_game": "%d.%d.%d" % [p.major, p.minor, p.patch]}) == p.pre.is_empty())
	_check("version: remote max_game below us refused", not Features._accepts({"max_game": "4.6"}))
	# title screen badge: preview every channel through GOD, then the switch hides it
	Features.clear_overrides()
	var tag: Label = main.hud.title_screen._channel
	for ch in ["alpha", "beta", "rc"]:
		Dev.channel_preview(ch)
		_check("version: %s badge on the title" % ch, tag.visible and tag.text.begins_with(str(BuildInfo.CHANNELS[ch][0]) + " TEST"))
	Dev.channel_preview("stable")
	_check("version: no badge on a stable release", not tag.visible)
	Dev.channel_preview("alpha")
	Dev.feature_set("channel_badge", false)
	_check("version: channel_badge switch off hides it", not tag.visible)
	Features.clear_overrides()
	Dev.channel_preview("nope")
	_check("version: unknown preview falls back to the real channel", BuildInfo.channel_preview == "" and tag.visible == (BuildInfo.channel_badge() != ""))
	# GOD system tab: preview row
	var god = main.hud.panels.god
	main.hud.open_panel("god")
	god.tab = "sys"
	god.refresh()
	await wait(0.25)
	_check("version: GOD system tab has the channel preview row", _find_text(god, "ดูป้ายช่อง") and _find_text(god, "CHANNEL: "))
	god.close()
	# Settings > About: badge under the logo
	Dev.channel_preview("beta")
	main.hud.open_settings("about")
	await wait(0.4)
	var about_tag = main.hud.settings_panel.find_child("ChannelTag", true, false)
	_check("version: About shows the badge", about_tag is Label and about_tag.visible and about_tag.text.begins_with("BETA TEST"))
	await shot("about_channel_beta")
	main.hud.settings_panel.close()
	Dev.channel_preview("")
	# release tooling + changelog
	var log := FileAccess.get_file_as_string("res://CHANGELOG.md")
	_check("version: CHANGELOG.md has a section for %s" % v, log.contains("## [%s]" % v) and log.contains("## [Unreleased]"))
	_check("version: release workflow + tool present", FileAccess.file_exists("res://.github/workflows/release.yml") and FileAccess.file_exists("res://tools/release.py"))


## game modes: migration, the New Game picker, peaceful toll, multipliers, mutators, GOD switch, next generation
func _modes_test() -> void:
	Features.clear_overrides()
	Features.layers.remote = {}
	# a save from before game modes is a standard run
	Game.s.erase("mode")
	Game._migrate()
	Modes.apply()
	_check("modes: old save migrates to standard / normal", Modes.id() == "standard" and Modes.diff() == "normal" and Modes.mutators().is_empty())
	var all_one := true
	for k in Modes.MUL_KEYS:
		all_one = all_one and Modes.mul(k) == 1.0
	_check("modes: standard / normal changes no number", all_one and Modes.legacy_mult() == 1.0 and Features.layers.mode.get("features", {}).is_empty())
	_check("modes: make() drops unknown ids and combat mutators in peaceful",
		Modes.make("nope", "nope", ["horde", "fuel_scarce", "made_up"]) == {"id": "standard", "diff": "normal", "mut": ["fuel_scarce", "horde"]}
		and Modes.make("peaceful", "hard", ["horde", "glass_cannon", "lean_rations"]).mut == ["lean_rations"])
	# other rules on a vehicle: event vehicles / the balance bot start like this (players have no picker any more)
	Modes.pending = {"id": "peaceful", "diff": "hard", "mut": ["fuel_scarce", "horde"]}
	main._on_start(true)
	await wait(0.5)
	Tutorial.skip()
	_check("modes: pending rules start a run, cleaned (no combat mutator in peaceful)", Modes.id() == "peaceful" and Modes.diff() == "hard" and Modes.mutators() == ["fuel_scarce"]
		and Modes.pending.is_empty() and float(Game.s.mode.get("started_at", 0.0)) > 0.0)
	_check("modes: peaceful switches raids off through the mode layer", not Features.on("raids") and Features.source("features", "raids") == "mode")
	_check("modes: peaceful x hard x fuel = research x0.84", is_equal_approx(Modes.legacy_mult(), 0.5 * 1.4 * 1.2) and not Modes.ranked())
	# fuel mutator halves every gain, not spending
	Game.s.res.fuel = 10.0
	Game._add_res("fuel", 10.0)
	Game._add_res("fuel", -4.0)
	_check("modes: fuel_scarce halves fuel gains only", is_equal_approx(float(Game.s.res.fuel), 11.0))
	# peaceful checkpoint: no warlord, a scrap toll instead
	var need: int = int(Data.biome(int(Game.s.biome) + 1).req)
	Game.s.vault_level = maxi(int(Game.s.vault_level), need)
	Game.s.km = Game.biome_end_km()
	Game.s.res.scrap = float(Modes.toll()) - 1.0
	Modes.tick(0.0, false)
	_check("modes: peaceful checkpoint waits for the toll", Game.at_checkpoint() and Game.blocked_reason().contains("ค่าผ่านทาง") and not Combat.warlord_due())
	await shot("mode_peaceful_toll")
	Game.s.res.scrap = float(Modes.toll()) + 10.0
	var toll := Modes.toll()
	Modes.tick(0.0, false)
	var sc0 := float(Game.s.res.scrap)
	Modes.tick(60.0, false)
	_check("modes: peaceful squad scavenges cap / 30 per minute", Modes.salvage_pm() > 0.0 and is_equal_approx(float(Game.s.res.scrap) - sc0, Game.cap("scrap") / Modes.SALVAGE_MIN))
	Game.s.res.scrap = sc0
	_check("modes: toll paid opens the checkpoint", Combat.boss_beaten(int(Game.s.biome)) and not Game.at_checkpoint() and is_equal_approx(float(Game.s.res.scrap), 10.0) and toll > 0)
	# difficulty + mutators through GOD (marks the save)
	Dev.mode_set("standard", "hard", "fuel_scarce")
	_check("modes: GOD switch to standard / hard brings raids back", Modes.id() == "standard" and Features.on("raids") and Modes.mutators().is_empty() and not Modes.ranked())
	var q := {"mob": Combat.BIOME_MOBS.industrial[0], "lvl": 5, "no_mutate": true}
	Combat._spawn(q)
	var hard_hp := float(Combat.enemies[-1].max)
	var hard_dmg := float(Combat.enemies[-1].dmg)
	Dev.mode_set("", "normal")
	Combat._spawn(q)
	var norm_hp := float(Combat.enemies[-1].max)
	var norm_dmg := float(Combat.enemies[-1].dmg)
	Combat._clear_enemies()
	_check("modes: hard = enemy HP x1.35, damage x1.25", is_equal_approx(hard_hp, norm_hp * 1.35) and is_equal_approx(hard_dmg, norm_dmg * 1.25))
	var d: Dictionary = Game.s.dwellers[0]
	var st0 := Combat.hero_stats(d, 1)
	Dev.mode_set("", "", "glass_cannon")
	var st1 := Combat.hero_stats(d, 1)
	_check("modes: glass cannon = squad damage x2, HP x0.5", is_equal_approx(float(st1.dmg), float(st0.dmg) * 2.0) and is_equal_approx(float(st1.hp), float(st0.hp) * 0.5))
	Dev.mode_set("", "nightmare", "lean_rations")
	_check("modes: multipliers stack (nightmare x lean rations)", is_equal_approx(Modes.mul("eat"), 1.3 * 1.4) and Modes.mul("offline") == 0.5
		and is_equal_approx(Modes.legacy_mult(), 2.0 * (1.0 + 0.15 + 0.15)))
	Threat._set_threat(0.0)
	var r_night := Threat.rate_pm()
	Dev.mode_set("", "normal", "glass_cannon")
	Dev.mode_set("", "", "lean_rations")
	var r_norm := Threat.rate_pm()
	_check("modes: nightmare threat builds x1.5", r_norm > 0.0 and is_equal_approx(r_night, r_norm * 1.5))
	Dev.mode_set("", "", "lone_road")
	_check("modes: lone road switches expeditions / encounters / strangers off", not Features.on("expeditions") and not Features.on("encounters") and not Features.on("strangers"))
	Dev.feature_set("expeditions", true)
	_check("modes: a tester override still beats the mode", Features.on("expeditions") and Features.source("features", "expeditions") == "dev")
	Dev.feature_set("expeditions", null)
	# UI: GOD system tab and the settings row
	main.hud.open_panel("god")
	main.hud.panels.god.tab = "sys"
	main.hud.panels.god.refresh()
	await wait(0.4)
	await shot("god_sys_modes")
	main.hud.panels.god.close()
	main.hud.open_settings("game")
	await wait(0.4)
	_check("modes: settings shows the difficulty row", main.hud.settings_panel.is_open)
	await shot("settings_difficulty_row")
	main.hud.settings_panel.close()
	# the next generation is the account's main vehicle again: standard at the account's difficulty
	Account.a.settings.diff = "hard"
	Meta.next_generation([int(Game.s.dwellers[0].id)])
	await wait(0.5)
	_check("modes: next generation = standard at the account difficulty", Modes.id() == "standard" and Modes.diff() == "hard" and Modes.mutators().is_empty() and Features.on("expeditions"))
	Account.set_diff("normal")


## Thai wording (MV-93, docs/glossary_th.md): names players pick between are unique, the player is
## never called "Overseer" (the villain AI), and event buttons carry no English inside the Thai label
func _thai_terms_test() -> void:
	var names := {}
	var clash := []
	var sources := [Crew.TRAITS.values(), Skills.NODES.values(), Combat.ROLES]
	for list in sources:
		for e in list:
			for nm in [str(e.th), "en:" + str(e.en)]:
				if names.has(nm):
					clash.append(nm)
				names[nm] = true
	for r in Combat.ROLES:
		if names.has(str(r.skill)):
			clash.append(str(r.skill))
	_check("thai: trait / skill / role names are unique in Thai and English %s" % str(clash), clash.is_empty())
	var british := []
	for v in Data.VEHICLES.values() + Meta.PERKS.values():
		if str(v.get("en", "")).contains("ARMOUR"):
			british.append(v.en)
	_check("thai: English labels use one spelling (ARMORED) %s" % str(british), british.is_empty())
	var overseer := Tutorial.STEPS.filter(func(st): return str(st.get("text", "")).contains("Overseer"))
	_check("thai: tutorial never calls the player Overseer", overseer.is_empty())
	var mixed := []
	for id in Data.EVENTS:
		for ch in Data.EVENTS[id].choices:
			if str(ch.th).contains(" / ") or (str(ch.en) != "" and str(ch.th).contains(str(ch.en))):
				mixed.append(id)
	_check("thai: road event buttons are Thai only %s" % str(mixed), mixed.is_empty())
	var biomes := Data.BIOMES.map(func(b): return str(b.th))
	_check("thai: biome names match the logbook", biomes.has("ทะเลทรายแก้ว") and biomes.has("ทางหลวงน้ำแข็ง") and biomes.has("ซากนิคมอุตสาหกรรม"))
	# outcome wording follows the choice: no "survived" on a trade, no thankful survivor for a dog
	var generic := []
	for id in Data.EVENTS:
		for ch in Data.EVENTS[id].choices:
			if str(EventPopup.stamp_text(ch, true)[0]) == "DONE":
				generic.append("%s/%s" % [id, ch.action])
	_check("thai: every road event choice has its own outcome stamp %s" % str(generic), generic.is_empty())
	_check("thai: trade stamp is a deal, failed check is a miss", EventPopup.stamp_text({"action": "trade"}, true)[1] == "ตกลงกันได้"
		and EventPopup.stamp_text({"action": "check"}, false)[0] == "FAILED")
	Game.s.res.food = maxf(float(Game.s.res.food), 50.0)
	var dog := Game.resolve_event("stray_dog", 1, [])
	_check("thai: feeding the dog reads like a dog, not a survivor", dog.ok and not str(dog.text).contains("ผู้รอดชีวิต")
		and EventPopup.stamp_text(Data.EVENTS.stray_dog.choices[1], true)[0] == "GOOD BOY")


## title screen: the backdrop van drives (wheels turn, engine rumbles) and the menu window stays on screen
func _title_backdrop_test() -> void:
	var v: Node = main.vehicle
	_check("title: van wheels turn", v.wheels.size() > 0 and v.wheels[0].is_playing())
	var ys := {}
	for i in 30:
		await get_tree().process_frame
		ys[v.body.position.y] = true
	_check("title: engine rumble moves the body", ys.size() >= 2)
	var p: Control = main.hud.title_screen._panel
	var vp: Rect2 = main.hud.title_screen.get_viewport_rect()
	_check("title: menu window inside the screen", vp.encloses(p.get_rect()))
	main.hud.title_screen._account_btn.visible = true
	main.hud.title_screen._account_btn.text = "Guest · ล็อกอินด้วย Gmail เพื่อเล่นต่อข้ามเครื่องได้ทุกที่"
	await wait(0.2)
	_check("title: window re-fits after it grows", vp.encloses(p.get_rect()))
	main.hud.title_screen._refresh_account()


# ------------------------------------------------------------------ room ambience (MV-167)
## lamp light pools + micro animation: every room type has moving parts, the layer hides in a blackout,
## on building sites and wide rooms, follows its Features switch, and the GOD flicker reaches every lamp
## MV-176: the vehicle body rumble / road bumps at half strength by default, tunable, off in settings
func _engine_shake_test() -> void:
	var was: bool = bool(Settings.get_value("car_shake"))
	Settings.set_value("car_shake", true)
	Features.set_override("tune", "fx.engine_shake", null)
	_check("engine shake: half strength by default (%.2f)" % Vehicle.shake_scale(), is_equal_approx(Vehicle.shake_scale(), 0.5))
	Dev.engine_shake(1.0)
	_check("engine shake: tune fx.engine_shake 1.0 = the old strength", is_equal_approx(Vehicle.shake_scale(), 1.0))
	Dev.engine_shake(-1.0)
	_check("engine shake: Dev reset clears the override", Features.source("tune", "fx.engine_shake") != "dev")
	# a half pixel on the 1 px grid = a whole pixel half of the time
	var sum := 0.0
	for i in 4000:
		sum += Vehicle.px_amp(0.5)
	_check("engine shake: 0.5 px = 1 px half the time (avg %.3f)" % (sum / 4000.0), absf(sum / 4000.0 - 0.5) < 0.05)
	_check("engine shake: whole pixels stay whole", Vehicle.px_amp(1.0) == 1.0 and Vehicle.px_amp(2.0) == 2.0 and Vehicle.px_amp(0.0) == 0.0)
	Settings.set_value("car_shake", false)
	_check("engine shake: off in settings = 0", Vehicle.shake_scale() == 0.0)
	await wait(0.4)
	var moved := false
	for i in 40:
		await get_tree().process_frame
		moved = moved or main.vehicle.body.position.y != 0.0
	_check("engine shake: the body stays still when off in settings", not moved)
	Settings.set_value("car_shake", was)
	await wait(0.3)


## MV-170: 20 named crew: atlas regions + palette-clean frames, gated recruit path, save/load, rooms, GOD preview
func _crew_roster_test() -> void:
	get_window().size = Vector2i(1280, 640)
	var ids: Array = Data.CREW_ROSTER.keys()
	var regs_ok := ids.size() == 20
	for id in ids:
		var r: Array = Atlas.regions.get("dw_crew_" + str(id), [])
		var p: Array = Atlas.regions.get("pt_dw_crew_" + str(id), [])
		regs_ok = regs_ok and r.size() == 4 and int(r[2]) == 280 and int(r[3]) == 20 and p.size() == 4 and int(p[2]) == 20 \
			and int(p[3]) == 20 and Atlas.dweller_variants.has("dw_crew_" + str(id))
	_check("crew roster: 20 strips 280x20 + 20 portraits 20x20 in the atlas", regs_ok)
	# every one of the 20 cells is drawn, alpha is binary, and standing poses keep the feet on the same baseline
	var img: Image = Atlas.sheet.get_image()
	if img.is_compressed():
		img.decompress()
	var empty := []
	var soft := []
	var off_floor := []
	var standing := [0, 1, 2, 3, 4, 5, 7, 8, 11, 12, 15, 16, 17, 18, 19]
	for id in ids:
		var r: Array = Atlas.regions["dw_crew_" + str(id)]
		for f in 20:
			var bottom := -1
			for y in 20:
				for x in 14:
					var a := img.get_pixel(int(r[0]) + f * 14 + x, int(r[1]) + y).a
					if a > 0.0:
						bottom = y
					if a > 0.0 and a < 1.0:
						soft.append("%s:%d" % [id, f])
			if bottom < 0:
				empty.append("%s:%d" % [id, f])
			elif f in standing and bottom != 19:
				off_floor.append("%s:%d" % [id, f])
	_check("crew roster: all 400 frames drawn %s" % str(empty.slice(0, 4)), empty.is_empty())
	_check("crew roster: binary alpha %s" % str(soft.slice(0, 4)), soft.is_empty())
	_check("crew roster: standing frames end on the actor baseline %s" % str(off_floor.slice(0, 4)), off_floor.is_empty())
	var sf := Atlas.dweller_frames("dw_crew_max")
	_check("crew roster: loader contract (hammer 3 + carry 2 frames, 14x20)", sf.get_frame_count("hammer") == 3 and sf.get_frame_count("carry") == 2
		and sf.get_frame_count("walk") == 4 and sf.get_frame_texture("idle", 0).get_size() == Vector2(14, 20))
	# recruit path: switch on + chance 1 -> named crew (never twice), switch off -> the old outfit x hair path
	Game.setup_default_state()
	_no_events()
	Features.set_override("features", "crew_roster_20", true)
	Dev.roster_chance(1.0)
	var named := 0
	var seen := {}
	var dup := false
	for i in 30:
		var d := Game.recruit_random()
		if Crew.is_roster(str(d.variant)):
			named += 1
			dup = dup or seen.has(d.variant)
			seen[d.variant] = true
			if str(d.name) != str(Data.CREW_ROSTER[str(d.variant).trim_prefix("dw_crew_")].name):
				dup = true
		elif str(d.role) != "builder" and named < Data.CREW_ROSTER.size():
			dup = true
	_check("crew roster: chance 1 = every non-builder recruit is named until all 20 are aboard (%d)" % named, named >= 12 and not dup)
	_check("crew roster: named recruits keep the professions (role/bio)", Lore.bio(Game.s.dwellers[-1]).role != "")
	Features.set_override("features", "crew_roster_20", false)
	var leaked := 0
	for i in 20:
		if Crew.is_roster(str(Game.recruit_random().variant)):
			leaked += 1
	_check("crew roster: switch off = old recruit path", leaked == 0)
	Dev.roster_chance(0.0)
	Features.set_override("features", "crew_roster_20", true)
	leaked = 0
	for i in 10:
		if Crew.is_roster(str(Game.recruit_random().variant)):
			leaked += 1
	_check("crew roster: tune crew.roster_chance 0 = none", leaked == 0)
	Dev.roster_chance(-1.0)
	_check("crew roster: tune back to the code default", is_equal_approx(Features.num("crew.roster_chance", Crew.ROSTER_CHANCE), Crew.ROSTER_CHANCE))
	# GOD: board every one directly, they survive a save/load with the switch off and still render
	Game.setup_default_state()
	_no_events()
	Dev.spawn_roster_all()
	var on_board: Array = Game.s.dwellers.filter(func(d): return Crew.is_roster(str(d.variant)))
	_check("crew roster: GOD boards all 20", on_board.size() == 20)
	var mae: Dictionary = on_board.filter(func(d): return str(d.variant) == "dw_crew_mae")[0]
	Dev.toggle_builder(mae)
	Dev.roster_chance(1.0)
	var gb := Dev.spawn_builder("")
	_check("crew roster: GOD builder keeps the hard hat with chance 1", str(gb.variant).begins_with("dw_builder_") and Crew.is_builder(gb))
	Dev.roster_chance(-1.0)
	_check("crew roster: builder toggle keeps the named look", str(mae.variant) == "dw_crew_mae" and Crew.is_builder(mae))
	Dev.toggle_builder(mae)
	Features.set_override("features", "crew_roster_20", false)
	Game.s.tier = "rig"
	Game.s.vault_level = Data.MAX_VAULT_LEVEL
	var types := ["quarters", "kitchen", "hydroponics", "water", "workshop", "medical", "science", "radio", "armory", "refinery"]
	while Game.s.rooms.size() < Game.slot_count():
		Game.s.rooms.append({"type": "empty", "level": 1, "job": {}, "build": {}})
	for i in Game.s.rooms.size():
		Game.s.rooms[i] = {"type": types[i % types.size()], "level": 1, "job": {}, "build": {}}
	Game.s.res.power = 500.0
	Game.save_game()
	Game.load_game()
	Tutorial.skip()
	var kept: Array = Game.s.dwellers.filter(func(d): return Crew.is_roster(str(d.variant)))
	_check("crew roster: saved crew load back with the switch off", kept.size() == 20)
	var slot := 0
	for d in kept:
		if slot < Game.s.rooms.size() and Game.room_workers(slot).size() < Game.room_capacity(slot) and not Game.s.rooms[slot].type in ["empty", "annex"]:
			Game.assign(d, slot)
		slot = (slot + 1) % maxi(Game.s.rooms.size(), 1)
	Game.dwellers_changed.emit()
	Game.rooms_changed.emit()
	main.vehicle.refresh_rooms()
	await wait(3.5)
	var acting := 0
	var right_frames := true
	for d in kept:
		var a = main.vehicle.actor_for(int(d.id))
		if a != null:
			acting += 1
			right_frames = right_frames and a.spr.sprite_frames == Atlas.dweller_frames(str(d.variant))
	_check("crew roster: named crew walk/work in rooms with the switch off (%d)" % acting, acting >= 1 and right_frames)
	_check("crew roster: portraits resolve for the UI", kept.all(func(d): return Atlas.has("pt_" + str(d.variant))))
	await shot("crew_roster_rooms")
	main.hud.open_panel("dwellers")
	await wait(0.5)
	await shot("crew_roster_list")
	main.hud.panels.dwellers.close()
	Features.set_override("features", "crew_roster_20", null)
	# GOD preview: one cell per crew member with the chosen animation playing
	main.hud.open_panel("god")
	var god = main.hud.panels.god
	god.tab = "crew"
	god._crew_anim = "hammer"
	god.refresh()
	await wait(0.5)
	var grid: Node = god._list.find_child("RosterGrid", true, false)
	var scroll := god._list.get_parent() as ScrollContainer
	if scroll and grid:
		scroll.scroll_vertical = int((grid as Control).position.y) - 80
		await wait(0.3)
	var cells := grid.get_child_count() if grid else 0
	var spr: AnimatedSprite2D = grid.find_child("Sprite", true, false) if grid else null
	_check("crew roster: GOD preview shows 20 with the picked animation (%d)" % cells, cells == 20 and spr != null and spr.animation == "hammer" and spr.is_playing())
	await shot("god_crew_roster")
	god._crew_anim = "idle"
	god.close()
	await wait(0.3)


func _ambience_test() -> void:
	get_window().size = Vector2i(1280, 640)
	Features.set_override("features", "room_ambience", null)
	Game.setup_default_state()
	Game.s.tier = "rig"
	Game.s.vault_level = Data.MAX_VAULT_LEVEL
	var types := ["medical", "quarters", "kitchen", "hydroponics", "water", "armory", "science", "radio", "engine", "refinery", "workshop", "empty"]
	while Game.s.rooms.size() < Game.slot_count():
		Game.s.rooms.append({"type": "empty", "level": 1, "job": {}, "build": {}})
	for i in Game.s.rooms.size():
		Game.s.rooms[i] = {"type": types[i % types.size()], "level": 1, "job": {}, "build": {}}
	Game.s.outage = {}
	Game.s.res.power = 500.0
	Game.s.tod = 0.9
	Game.rooms_changed.emit()
	main.vehicle.refresh_rooms()
	_no_events()
	await wait(0.5)
	var seen := {}
	var moving := true
	for rv in main.vehicle.room_views:
		var r: RoomView = rv
		if not r.visible or not Game.is_slot_unlocked(r.slot):
			continue
		var t: String = Game.s.rooms[r.slot].type
		seen[t] = r.ambience.visible and r.ambience.kind == t
		moving = moving and r.ambience.fx_count() >= (2 if t == "empty" else 3)
	_check("ambience: every room type lit (%d types)" % seen.size(), seen.size() == types.size() and not seen.values().has(false))
	_check("ambience: every room has moving parts", moving)
	var cv: CabView = main.vehicle.cab_view
	_check("ambience: cab engine bay has lamp + gauge + rockers", cv.ambience.visible and cv.ambience.kind.begins_with("cab_") and cv.ambience.fx_count() >= 5)
	var r0: RoomView = main.vehicle.room_views[2]
	var f0 := r0.ambience._frame
	await wait(0.3)
	_check("ambience: redraws while time runs", r0.ambience._frame != f0)
	_check("ambience: night makes the light pools stronger", not Game.is_night() or r0.ambience.night > 0.2)
	_check("god: lamps flicker reaches every lamp", Dev.lamps_flicker() >= Game.slot_count() and r0.ambience.flicker_left > 1.5)
	await wait(0.4)
	await shot("rooms_ambience_night")
	main.open_closeup(2)
	await wait(0.8)
	await shot("closeup_ambience_kitchen")
	main.hud.room_closeup.close()
	await wait(0.4)
	Game.s.outage = {"2": 60.0}
	await wait(0.2)
	_check("ambience: off in a blackout (torches only)", not r0.ambience.visible)
	Game.s.outage = {}
	await wait(0.2)
	_check("ambience: back when the power is", r0.ambience.visible)
	Features.set_override("features", "room_ambience", false)
	await wait(0.1)
	_check("ambience: Features switch hides it", not r0.ambience.visible and not cv.ambience.visible)
	Features.set_override("features", "room_ambience", null)
	await wait(0.1)
	_check("ambience: switch back on", r0.ambience.visible and cv.ambience.visible)
	Game.s.tod = 0.4


# ------------------------------------------------------------------ mobile touch
## design coords -> window coords, so Input.parse_input_event takes the same path as a real finger
## (Input emulates the mouse from the first finger, then the window's stretch transform applies)
func _win(p: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * p


func _finger(idx: int, p: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.position = _win(p)
	ev.pressed = down
	Input.parse_input_event(ev)
	await get_tree().process_frame


## waits until a ScrollContainer's fling has stopped: the scroll offset unchanged for 5 frames in a row (max 5 s)
func _scroll_settled(sc: ScrollContainer) -> void:
	var still := 0
	var last := Vector2i(sc.scroll_horizontal, sc.scroll_vertical)
	var t0 := Time.get_ticks_msec()
	while still < 5 and Time.get_ticks_msec() - t0 < 5000:
		await get_tree().process_frame
		var now := Vector2i(sc.scroll_horizontal, sc.scroll_vertical)
		still = still + 1 if now == last else 0
		last = now


## moves fingers idx[i] from a[i] to b[i] together over `steps` frames
func _fingers_drag(idx: Array, a: Array, b: Array, steps: int = 10) -> void:
	for s in steps:
		for i in idx.size():
			var p0: Vector2 = (a[i] as Vector2).lerp(b[i], float(s) / steps)
			var p1: Vector2 = (a[i] as Vector2).lerp(b[i], float(s + 1) / steps)
			var ev := InputEventScreenDrag.new()
			ev.index = idx[i]
			ev.position = _win(p1)
			ev.relative = _win(p1) - _win(p0)
			Input.parse_input_event(ev)
		await get_tree().process_frame


## v4.6 mobile web touch fixes: a tap that opened a panel left a ghost finger behind (its release hit
## the modal check), so every later one-finger swipe was read as a pinch: no pan + the camera flipping
## normal/wide; pinch steps once per gesture; lists scroll by dragging a finger over their buttons.
func _touch_test() -> void:
	_no_events()
	for k in main.hud.panels:
		if main.hud.panels[k].is_open:
			main.hud.panels[k].close()
	if main.hud.room_closeup.is_open:
		main.hud.room_closeup.close()
	await wait(0.6)
	var zoom_was: String = main.zoom_mode
	var toasts := []
	var on_toast := func(msg: String, _kind: String): if msg.begins_with("มุมกล้อง"): toasts.append(msg)
	Game.toast.connect(on_toast)
	main.set_zoom_mode("normal")
	var wr: Rect2 = main.hud.world_rect()
	var sky := wr.position + Vector2(wr.size.x * 0.5, 24.0)
	# 1) finger 7 lands on the world, a panel opens before it lifts (as when its tap opened one)
	await _finger(7, sky, true)
	main.hud.open_panel("map")
	await wait(0.2)
	await _finger(7, sky, false)
	main.hud.panels.map.close()
	await wait(0.5)
	_check("touch: a release under a panel leaves no ghost finger", main._touches.is_empty())
	# 2) the next finger gets a new id (iOS never reuses Touch.identifier) and swipes left
	toasts.clear()
	main.pan_x = 0.0
	await _finger(8, sky, true)
	await _fingers_drag([8], [sky], [sky + Vector2(-90, 0)])
	await _finger(8, sky + Vector2(-90, 0), false)
	_check("touch: one-finger swipe after a panel pans the camera (pan %.0f)" % main.pan_x, main.pan_x > 40.0)
	_check("touch: that swipe leaves the zoom alone", main.zoom_mode == "normal" and toasts.is_empty())
	# 3) pinch: closing two fingers -> wide once, however far they keep going; spreading -> normal
	var c := wr.get_center()
	toasts.clear()
	await _finger(10, c - Vector2(60, 0), true)
	await _finger(11, c + Vector2(60, 0), true)
	await _fingers_drag([10, 11], [c - Vector2(60, 0), c + Vector2(60, 0)], [c - Vector2(8, 0), c + Vector2(8, 0)], 16)
	await _finger(10, c - Vector2(8, 0), false)
	await _finger(11, c + Vector2(8, 0), false)
	_check("touch: pinch in -> wide view, one toast (%d)" % toasts.size(), main.world_scale < main.pixel_scale and toasts.size() == 1)
	await _finger(12, c - Vector2(10, 0), true)
	await _finger(13, c + Vector2(10, 0), true)
	await _fingers_drag([12, 13], [c - Vector2(10, 0), c + Vector2(10, 0)], [c - Vector2(80, 0), c + Vector2(80, 0)], 16)
	await _finger(12, c - Vector2(80, 0), false)
	await _finger(13, c + Vector2(80, 0), false)
	_check("touch: pinch out -> closer view again (%s)" % main.zoom_mode, main.world_scale >= main.pixel_scale and toasts.size() == 2)
	_check("touch: no fingers left after the pinches", main._touches.is_empty())
	Game.toast.disconnect(on_toast)
	main.set_zoom_mode(zoom_was)
	await wait(0.3)
	# 4) lists: drag a finger that lands on a button -> the list scrolls, the button does not fire;
	# a plain tap still does. ScrollContainer only drags when DisplayServer reports a touchscreen,
	# which a desktop test run fakes with emulate_touch_from_mouse.
	var touch_was := Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	Game.s.res.scrap = 900.0
	main.hud.open_panel("build")
	var bp: BuildPanel = main.hud.panels.build
	bp.move_to_front()
	await wait(0.6)
	var sc: ScrollContainer = _find_type(bp, "ScrollContainer")[0]
	var stops := []
	for n in _find_type(sc, "Button") + _find_type(sc, "PanelContainer"):
		if n.mouse_filter == Control.MOUSE_FILTER_STOP:
			stops.append(n.get_class())
	_check("touch: no button/card inside a list stops the finger %s" % str(stops), stops.is_empty())
	var builds: Array = bp._grid.get_children().map(func(card): return _find_type(card, "Button")).reduce(func(acc, a): return acc + a, [])
	builds = builds.filter(func(b): return not b.disabled and b.text == "สร้าง")
	var fired := [0]
	for b in builds:
		b.pressed.connect(func(): fired[0] += 1, CONNECT_ONE_SHOT)
	sc.scroll_vertical = 0
	await wait(0.2)
	var sr := sc.get_global_rect()
	var btn: Button = builds.filter(func(b): return sr.has_point(b.get_global_rect().get_center()))[0]
	var p0 := btn.get_global_rect().get_center()
	await _finger(20, p0, true)
	await _fingers_drag([20], [p0], [p0 - Vector2(0, 110)], 12)
	await _finger(20, p0 - Vector2(0, 110), false)
	await wait(0.5)
	_check("touch: finger drag over a list scrolls it (%d px)" % sc.scroll_vertical, sc.scroll_vertical > 40)
	_check("touch: the button under a scrolling finger does not fire", fired[0] == 0)
	# the fling keeps the list gliding for a time that depends on the frame rate (ScrollContainer measures the
	# finger speed per frame): pick the button only once it stands still, or the tap lands next to it (MV-172)
	await _scroll_settled(sc)
	btn = builds.filter(func(b): return sr.grow(-4).has_point(b.get_global_rect().get_center()))[0]
	var p1 := btn.get_global_rect().get_center()
	await _finger(21, p1, true)
	await wait(0.08)
	await _finger(21, p1, false)
	await wait(0.3)
	_check("touch: a tap on a button inside a list still fires it", fired[0] == 1)
	if main._placing != "":
		main._exit_placement()
	if bp.is_open:
		bp.close()
	Input.emulate_touch_from_mouse = touch_was
	await wait(0.3)


## MV-188: announcement strip: features.json "announce" list (clean, window, once per browser), loops then hides,
## version.json newer build -> tappable update notice first in line, switch off hides it, GOD actions
func _announce_test() -> void:
	var m: Marquee = main.marquee
	Announce.queue.clear()
	if not m.msg.is_empty():
		m._stop()
	Features.set_override("tune", "announce.speed", 120.0)
	Features.set_override("tune", "announce.loops", null)
	_check("announce: 3 loops by default", Announce.loops_for({"loops": -1}) == 3)
	Features.apply_remote({"announce": [{"id": "t-hello", "text": "ทดสอบประกาศ hello", "loops": 2},
		{"id": "", "text": "no id"}, {"text": "missing id"}, {"id": "t-blank", "text": "  "},
		{"id": "t-future", "text": "later", "from": "2099-01-01"}, {"id": "t-past", "text": "old", "to": "2001-01-01"},
		{"id": "t-loops", "text": "x", "loops": 99}]}, 1.0)
	var ids := []
	for a in Features.announcements():
		ids.append(a.id)
	_check("announce: only valid messages inside their window (%s)" % str(ids), ids == ["t-hello", "t-loops"])
	_check("announce: loops clamped to 1-5", Features.layers.remote.announce.back().loops == 5)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("announce: the strip shows the first message", m.visible and str(m.msg.get("id", "")) == "t-hello" and m._label.text == "ทดสอบประกาศ hello")
	_check("announce: shown id is remembered", Announce.seen.has("t-hello"))
	_check("announce: info message lets taps through", m._strip.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	await wait(0.3)
	await shot("announce_marquee")
	_check("announce: text moves on whole pixels", m._label.position.x == roundf(m._label.position.x) and m._label.position.x < m._width())
	var loops := []
	var t := 0.0
	while str(m.msg.get("id", "")) == "t-hello" and t < 20.0:
		if not loops.has(m.loops_done):
			loops.append(m.loops_done)
		await get_tree().process_frame
		t += get_process_delta_time()
	_check("announce: scrolled 2 times then moved on (%s, %.1fs)" % [str(loops), t], loops == [0, 1] and t < 20.0)
	_check("announce: next message follows", str(m.msg.get("id", "")) == "t-loops")
	m._stop()
	await get_tree().process_frame
	Announce.collect()
	_check("announce: a seen message is not shown again", not Announce.has_id("t-hello") and Announce.queue.is_empty())
	# new deploy detection
	var stamp: Dictionary = BuildInfo.stamp().duplicate()
	BuildInfo._stamp["built"] = "2026-10-24T10:00:00Z"
	_check("announce: same or older build -> no notice", not Announce.check_version({"built": "2026-10-24T10:00:00Z"})
		and not Announce.check_version({"built": "2026-10-24T09:00:00Z"}) and not Announce.check_version("junk"))
	Announce.push("info on the strip", "")
	Announce.push("info waiting", "")
	_check("announce: newer build -> notice", Announce.check_version({"version": "4.7.0-alpha.9", "built": "2026-10-24T11:00:00Z"}))
	_check("announce: the same build is not queued twice", not Announce.check_version({"version": "4.7.0-alpha.9", "built": "2026-10-24T11:00:00Z"}))
	_check("announce: a message on the strip is not cut off", m._label.text == "info on the strip")
	m._stop()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("announce: update notice jumps the queue", str(m.msg.get("kind", "")) == "update" and "4.7.0-alpha.9" in m._label.text and m._tag.text == "UPDATE")
	_check("announce: update notice is tappable", m._strip.mouse_filter == Control.MOUSE_FILTER_STOP)
	await wait(2.0)
	await shot("announce_update")
	var reloaded := [false]
	Announce.reload_hook = func(): reloaded[0] = true
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	m._on_strip_input(tap)
	_check("announce: tap on the update notice saves and reloads", reloaded[0])
	Announce.reload_hook = Callable()
	BuildInfo._stamp = stamp
	_check("announce: dev build (no stamp) never asks to reload", BuildInfo.stamp().get("built", "") != "" or not Announce.check_version({"built": "9999-01-01T00:00:00Z"}))
	# switch off hides the strip and holds the queue
	Dev.feature_set("announce", false)
	await get_tree().process_frame
	_check("announce: switch off hides the strip", not m.visible and m.msg.is_empty() and Announce.take().is_empty())
	Dev.feature_set("announce", null)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("announce: switch on shows what waits", m.visible)
	m._stop()
	Announce.queue.clear()
	await get_tree().process_frame
	# GOD actions
	Dev.announce_test()
	Dev.announce_update_test()
	_check("announce: GOD test message + update notice queued", (m.visible and Announce.queue.size() == 1) or Announce.queue.size() == 2)
	Announce.seen.append("t-hello")
	Dev.announce_forget_seen()
	_check("announce: GOD forget seen", not Announce.seen.has("t-hello"))
	m._stop()
	Announce.queue.clear()
	m._stop()
	Announce.queue.clear()
	Features.clear_remote()
	Features.set_override("tune", "announce.speed", null)
	Announce.seen.clear()
	await get_tree().process_frame
