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
	_button_skin_contract_test()
	if "--only=confirm" in OS.get_cmdline_user_args():
		Tutorial.skip()
		if "--confirm-ui-sequence" in OS.get_cmdline_user_args():
			get_window().size = Vector2i(1280, 640)
			await wait(0.6)
			await _touch_test()
			await _settings_test()
		await _confirm_actions_test()
		_finish()
		return
	if "--only=buttons" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _button_skin_menu_test()
		_finish()
		return
	if "--only=background" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _industrial_background_test()
		_finish()
		return
	if "--only=icons" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _icon_art_test()
		_finish()
		return
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
	if "--only=checkpoint" in OS.get_cmdline_user_args():
		Tutorial.skip()
		_checkpoint_test()
		_finish()
		return
	if "--only=engine_rest" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _engine_rest_test()
		_finish()
		return
	if "--only=analytics" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _analytics_test()
		_finish()
		return
	if "--only=outbox" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _outbox_test()
		_finish()
		return
	if "--only=window_fit" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _window_fit_test()
		_finish()
		return
	if "--only=trait_cards" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _trait_cards_test()
		_finish()
		return
	if "--only=gear_slots" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _gear_slots_test()
		_finish()
		return
	if "--only=perf" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _perf_test()
		_finish()
		return
	if "--only=responsive" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _responsive_test()
		_finish()
		return
	if "--only=morale" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _morale_test()
		_finish()
		return
	if "--only=hull_warning" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _hull_warning_test()
		_finish()
		return
	if "--only=barks" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _barks_test()
		_finish()
		return
	if "--only=flee_guard" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _flee_guard_test()
		_finish()
		return
	if "--only=flagged" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _flagged_test()
		_finish()
		return
	if "--only=rooms_x" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _rooms_x_test()
		_finish()
		return
	if "--only=saloon" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _saloon_test()
		_finish()
		return
	if "--only=stat_view" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _stat_view_test()
		_finish()
		return
	if "--only=world_map" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _world_map_test()
		_finish()
		return
	if "--only=world_travel" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _world_travel_test()
		_finish()
		return
	if "--only=quarters_guard" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _quarters_guard_test()
		_finish()
		return
	if "--only=env_micro" in OS.get_cmdline_user_args():
		_env_micro_test()
		_finish()
		return
	if "--only=driver_cab" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _driver_cab_test()
		_finish()
		return
	if "--only=idle_motion" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _idle_motion_test()
		_finish()
		return
	if "--only=engine_detail" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _engine_detail_test()
		_finish()
		return
	if "--only=cozy_roof" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _cozy_roof_test()
		_finish()
		return
	if "--only=vehicle_detail" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _vehicle_detail_test()
		_finish()
		return
	if "--only=boss_intro" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _boss_intro_test()
		_finish()
		return
	if "--only=enemy_size" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _enemy_size_test()
		_finish()
		return
	if "--only=pity" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _pity_test()
		_finish()
		return
	if "--only=raw_food" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _raw_food_test()
		_finish()
		return
	if "--only=scene_art" in OS.get_cmdline_user_args():
		Tutorial.skip()
		await _scene_art_test()
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
	# morale: strike then theft + desertion (the legacy rules, morale_v2 off; v2 is _morale_test)
	Features.set_override("features", "morale_v2", false)
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
	Features.set_override("features", "morale_v2", null)
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
	# an outage that outlived its room (smaller vehicle / room gone) ends quietly instead of crashing the tick
	Game.s.outage = {str(Game.s.rooms.size() + 3): 0.01}
	Game._tick_outages(0.02, false)      # tiny dt: no new random outage gets rolled
	_check("short circuit: an outage on a room that no longer exists just ends", (Game.s.outage as Dictionary).is_empty())
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
	await _confirm_actions_test()
	_event_variety_test()
	await _cloud_test()
	await _cloud_account_test()
	await _logs_test()
	await _outbox_test()
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
	await _icon_art_test()
	await _crew_roster_test()
	await _announce_test()
	await _scene_art_test()
	await _industrial_background_test()
	await _raw_food_test()
	await _pity_test()
	await _boss_intro_test()
	await _enemy_size_test()
	await _vehicle_detail_test()
	await _cozy_roof_test()
	await _engine_detail_test()
	await _idle_motion_test()
	await _driver_cab_test()
	_env_micro_test()
	await _engine_rest_test()
	await _quarters_guard_test()
	await _world_travel_test()
	await _world_map_test()
	await _stat_view_test()
	await _rooms_x_test()
	await _saloon_test()
	await _flagged_test()
	await _flee_guard_test()
	await _barks_test()
	await _hull_warning_test()
	await _morale_test()
	await _responsive_test()
	await _perf_test()
	await _window_fit_test()
	await _gear_slots_test()
	await _trait_cards_test()
	await _analytics_test()
	_checkpoint_test()
	_thai_terms_test()
	_finish()


## god mode actions for the newer systems (tutorial, construction, builders, squad, forge, event deck,
## encounters, strangers, cloud, settings) + every tab renders
## MV-418: real controls retain the old geometry even though the nine-slice caps grow.
func _button_skin_contract_test() -> void:
	var fixture := Control.new()
	fixture.theme = UIKit.theme()
	fixture.visible = false
	add_child(fixture)
	var old_image := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	old_image.fill(UIKit.C_BG2)
	var old_texture := ImageTexture.create_from_image(old_image)
	for key in ["green", "yellow", "gray", "blue", "red", "orange"]:
		var b := UIKit.button("สร้าง / Build", key, "hammer")
		fixture.add_child(b)
		var complete := true
		for state in UIKit.BUTTON_STATES:
			var style := b.get_theme_stylebox(state) as StyleBoxTexture
			var down: bool = state in ["pressed", "hover_pressed"]
			var expected: String = "btn_disabled" if state == "disabled" else str(UIKit.BTN_TEX[key]) + ("_pressed" if down else ("_hover" if state == "hover" else ""))
			complete = complete and style.texture.get_size() == Vector2(24, 24) and style.texture.resource_path.ends_with("/" + expected + ".png")
			complete = complete and style.texture_margin_left == 6 and style.texture_margin_top == 6 and style.texture_margin_right == 6 and style.texture_margin_bottom == 6
		_check("buttons: %s routes every state to its own family" % key, complete)
		for sample in ["+", "", "สร้าง / Build", "รายละเอียด / Details"]:
			b.text = sample
			var actual := b.get_combined_minimum_size()
			var saved := {}
			for state in UIKit.BUTTON_STATES:
				var style := b.get_theme_stylebox(state) as StyleBoxTexture
				saved[state] = style
				var legacy := style.duplicate() as StyleBoxTexture
				legacy.texture = old_texture
				legacy.set_texture_margin_all(3)
				b.add_theme_stylebox_override(state, legacy)
			_check("buttons: %s '%s' keeps the legacy minimum size" % [key, sample], actual == b.get_combined_minimum_size())
			for state in UIKit.BUTTON_STATES:
				b.add_theme_stylebox_override(state, saved[state])
		# Settings and toggled HUD controls restyle the same node without rebuilding it.
		UIKit.style_button(b, "yellow")
		UIKit.style_button(b, key)
		_check("buttons: restyled %s keeps its pressed and disabled faces" % key,
			b.get_theme_stylebox("pressed").texture == UIKit.button_style(key, "pressed").texture
			and b.get_theme_stylebox("disabled").texture == UIKit.ui_tex("btn_disabled"))
		b.free()
	var inherited := Button.new()
	fixture.add_child(inherited)
	_check("buttons: theme defaults and node overrides use the same pressed face", inherited.get_theme_stylebox("pressed").texture == UIKit.ui_tex("btn_pressed"))
	_check("buttons: pressed and disabled labels remain readable", inherited.get_theme_color("font_pressed_color") == UIKit.C_WHITE
		and inherited.get_theme_color("font_hover_pressed_color") == UIKit.C_WHITE and inherited.get_theme_color("font_disabled_color") == UIKit.C_DIM)
	var choice := ChoiceButton.new("สร้างห้องนี้ / Build this room", "BUILD", "120 scrap", "red")
	fixture.add_child(choice)
	choice.disabled = true
	_check("buttons: wrapped choices share the coloured pressed skin and remain disabled", choice.button.disabled
		and choice.button.get_theme_stylebox("pressed").texture == UIKit.ui_tex("btn_red_pressed"))
	fixture.free()


## Focused captures of the original menus; this does not replace the full touch checks.
func _button_skin_menu_test() -> void:
	var previous_lang: String = str(Settings.get_value("lang"))
	var previous_tips: bool = bool(Settings.get_value("tips"))
	var previous_size := DisplayServer.window_get_size()
	var previous_english = Features.layers.dev.get("features", {}).get("english")
	var previous_raids = Features.layers.dev.get("features", {}).get("raids")
	Settings.set_value("tips", false)
	Features.set_override("features", "english", true)
	Features.set_override("features", "raids", false)
	Game.s.res.scrap = 500.0
	for size_case in [[Vector2i(720, 1280), "portrait"], [Vector2i(1600, 1200), "landscape"]]:
		DisplayServer.window_set_size(size_case[0])
		await wait(0.6)
		_check("buttons: captures use the requested %s resolution" % size_case[1], DisplayServer.window_get_size() == size_case[0])
		for language in ["th", "en"]:
			Settings.set_value("lang", language)
			await wait(0.2)
			for key in ["build", "dwellers", "inventory", "settings"]:
				_no_events()
				if key == "settings": main.hud.open_settings("game")
				else: main.hud.open_panel(key)
				await wait(0.4)
				var panel: ModalPanel = main.hud.panels[key]
				var vp: Vector2 = main.hud.get_viewport_rect().size
				_check("buttons: %s/%s/%s keeps the original floating window" % [size_case[1], language, key], panel.box.size.x < vp.x and panel.box.size.y < vp.y)
				await shot("buttons_%s_%s_%s" % [size_case[1], language, key])
				panel.close()
				await wait(0.25)
	Features.set_override("features", "english", previous_english)
	Features.set_override("features", "raids", previous_raids)
	Settings.set_value("lang", previous_lang)
	Settings.set_value("tips", previous_tips)
	DisplayServer.window_set_size(previous_size)


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
	# test cleanup, not a player demolish (MV-420 would rightly refuse it: the crew needs these beds)
	Game.s.rooms[free] = {"type": "empty", "level": 1, "job": {}, "build": {}}
	for d in Game.s.dwellers:
		if int(d.room) == free:
			d.room = -1
	Game.rooms_changed.emit()
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
## MV-422: real UI entry points must leave state untouched until a named confirmation.
func _confirm_actions_test() -> void:
	var saved_state := Game.s
	var saved_account := Account.a
	var saved_store := Save.read()
	var saved_started := Game.started
	var saved_processing := Game.is_processing()
	var saved_title: bool = main.hud.title_screen.visible
	var saved_features: Dictionary = Features.layers.dev.duplicate(true)
	var saved_settings := Settings.v.duplicate(true)
	var saved_size := get_window().size
	Game.set_process(false)
	# Earlier integration checks deliberately leave stale squad IDs; use a fresh, isolated vehicle.
	Account.a = {}
	Game.setup_default_state()
	Account.attach(Game.s)
	Game.started = true
	main.hud.title_screen.visible = false
	Features.set_override("features", "confirm_actions", true)
	Features.set_override("features", "english", true)
	Settings.set_value("tips", false)
	_no_events()
	Tutorial.skip()
	Game._emit_all(true)
	var dialog: ConfirmPanel = main.hud.confirmation
	var room_ui: RoomCloseup = main.hud.room_closeup
	Game.s.rooms[1] = {"type": "kitchen", "level": 1, "job": {}, "build": {}}
	Game.s.rooms[2] = {"type": "empty", "level": 1, "job": {}, "build": {}}
	Game.s.res.scrap = 50.0
	main.open_closeup(1)
	await wait(0.5)
	var room_before: Dictionary = Game.s.rooms[1]
	var scrap_before := float(Game.s.res.scrap)
	(room_ui.find_child("DemolishButton", true, false) as Button).pressed.emit()
	_check("confirm: demolish click opens a modal without deleting or refunding", dialog.is_open and is_same(Game.s.rooms[1], room_before) and float(Game.s.res.scrap) == scrap_before)
	_check("confirm: Cancel has keyboard focus and the HUD treats it as modal", dialog.cancel_button.has_focus() and main.hud.any_modal_open())
	# Keyboard acceptance acts on Cancel, never on the destructive option by default.
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await get_tree().process_frame
	enter = enter.duplicate()
	enter.pressed = false
	Input.parse_input_event(enter)
	await wait(0.1)
	_check("confirm: default Enter cancels and preserves the room", not dialog.is_open and is_same(Game.s.rooms[1], room_before))
	room_ui._request_demolish()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await get_tree().process_frame
	escape = escape.duplicate()
	escape.pressed = false
	Input.parse_input_event(escape)
	_check("confirm: Escape cancels without a refund", not dialog.is_open and float(Game.s.res.scrap) == scrap_before)
	room_ui._request_demolish()
	await _finger(81, Vector2(1, 1), true)
	await _finger(81, Vector2(1, 1), false)
	await wait(0.1)
	_check("confirm: backdrop tap cancels without deleting", not dialog.is_open and is_same(Game.s.rooms[1], room_before))
	room_ui._request_demolish()
	await wait(0.1)
	var point := dialog.cancel_button.get_global_rect().get_center()
	await _finger(82, point, true)
	await wait(0.08)
	var hit := get_viewport().gui_get_hovered_control()
	_check("confirm: touch reaches Cancel (hit %s)" % (str(hit.get_path()) if hit else "none"), hit == dialog.cancel_button)
	await _finger(82, point, false)
	await wait(0.1)
	_check("confirm: touch Cancel preserves the target", not dialog.is_open and is_same(Game.s.rooms[1], room_before))
	room_ui._request_demolish()
	dialog.confirm_button.pressed.emit()
	dialog.confirm_button.pressed.emit()
	var refund := float(Data.room_def("kitchen").cost) * 0.5
	# an economy step can land between the click and this check on a slow machine (MV-113 runs it 20x a second), so
	# "once" = the change is one refund, not none and not two
	_check("confirm: accepting demolishes once and refunds once (scrap %.4f, expected %.4f)" % [float(Game.s.res.scrap), scrap_before + refund],
		Game.s.rooms[1].type == "empty" and absf(float(Game.s.res.scrap) - scrap_before - refund) < refund * 0.5)
	Game.s.rooms[1] = room_before
	room_ui.refresh()
	room_ui._request_demolish()
	Game.s.rooms[1] = room_before.duplicate(true)
	dialog.confirm_button.pressed.emit()
	_check("confirm: a replaced room cannot be deleted by a stale prompt", Game.s.rooms[1].type == "kitchen")
	room_ui._request_demolish()
	room_ui.close()
	dialog.confirm_button.pressed.emit()
	_check("confirm: closing the originating window invalidates the action", Game.s.rooms[1].type == "kitchen")
	await wait(0.2)
	Game.s.rooms[1] = {"type": "kitchen", "level": 1, "job": {}, "build": {"kind": "build", "left": 100.0, "total": 100.0}}
	main.open_closeup(1)
	await wait(0.2)
	(room_ui.find_child("CancelConstructionButton", true, false) as Button).pressed.emit()
	_check("confirm: construction cancellation waits for a decision", dialog.is_open and Game.is_site(1))
	dialog.close_btn.pressed.emit()
	_check("confirm: X cancels construction deletion", Game.is_site(1))
	room_ui._request_demolish()
	dialog.confirm_button.pressed.emit()
	_check("confirm: construction cancellation commits after confirmation", Game.s.rooms[1].type == "empty")
	Game.s.rooms[1] = {"type": "kitchen", "level": 1, "job": {}, "build": {}}
	Game.s.rooms[2] = {"type": "annex", "level": 1, "job": {}, "build": {}}
	room_ui.refresh()
	(room_ui.find_child("SplitButton", true, false) as Button).pressed.emit()
	dialog.close()
	_check("confirm: cancelling a split preserves the large room", Game.room_span(1) == 2)
	room_ui._request_split()
	dialog.confirm_button.pressed.emit()
	_check("confirm: accepting a split preserves both rooms and their level", Game.room_span(1) == 1 and Game.s.rooms[2].type == "kitchen" and int(Game.s.rooms[2].level) == 1)
	room_ui.close()
	await wait(0.2)
	var loot_ui: LootPanel = main.hud.panels.inventory
	var item := Loot.roll_item("weapon", 1, 0)
	Game.s.gear = [item]
	main.hud.open_panel("inventory")
	loot_ui.detail_uid = int(item.uid)
	loot_ui.refresh()
	(loot_ui.find_child("SalvageButton", true, false) as Button).pressed.emit()
	_check("confirm: single salvage names the item without removing it", dialog.is_open and dialog.message.text.contains(Loot.item_name(item)) and Loot.stash().size() == 1)
	dialog.cancel_button.pressed.emit()
	_check("confirm: cancelling single salvage preserves gear", Loot.stash().size() == 1)
	loot_ui._request_salvage(item)
	dialog.confirm_button.pressed.emit()
	_check("confirm: accepting single salvage removes that item", Loot.stash().is_empty())
	var first := Loot.roll_item("weapon", 1, 0)
	var locked := Loot.roll_item("armor", 1, 0)
	locked.lock = true
	Game.s.gear = [first, locked]
	loot_ui._request_bulk_salvage(0)
	dialog.cancel_button.pressed.emit()
	_check("confirm: cancelling bulk salvage preserves every item", Loot.stash().size() == 2 and Loot.stash().has(first))
	loot_ui._request_bulk_salvage(0)
	_check("confirm: bulk preview excludes locked gear", dialog.is_open and dialog.confirm_button.text.contains("1"))
	var later := Loot.roll_item("boots", 1, 0)
	Game.s.gear.append(later)
	dialog.confirm_button.pressed.emit()
	_check("confirm: bulk salvage preserves locked gear and drops arriving after the prompt", Loot.stash().size() == 2 and Loot.stash().has(locked) and Loot.stash().has(later))
	Game.s.gear = [Loot.roll_item("weapon", 1, 0), Loot.roll_item("armor", 1, 0), Loot.roll_item("boots", 1, 0)]
	Game.s.res.scrap = 200.0
	loot_ui._request_synthesize(0)
	_check("confirm: synthesis waits without consuming items or scrap", dialog.is_open and Loot.stash().size() == 3 and float(Game.s.res.scrap) == 200.0)
	Game.s.gear[0].lock = true
	dialog.confirm_button.pressed.emit()
	_check("confirm: locking an ingredient invalidates synthesis", Loot.stash().size() == 3 and float(Game.s.res.scrap) == 200.0)
	Game.s.gear[0].lock = false
	loot_ui._request_synthesize(0)
	dialog.confirm_button.pressed.emit()
	_check("confirm: synthesis consumes exactly three ingredients after acceptance", Loot.stash().size() == 1 and int(Loot.stash()[0].rar) == 1 and float(Game.s.res.scrap) == 185.0)
	Game.s.combat.auto_salvage = -1
	loot_ui._request_auto_salvage(1)
	dialog.close()
	_check("confirm: cancelling auto-salvage keeps it off", int(Game.s.combat.auto_salvage) == -1)
	loot_ui._request_auto_salvage(1)
	dialog.confirm_button.pressed.emit()
	_check("confirm: enabling auto-salvage requires acceptance", int(Game.s.combat.auto_salvage) == 1)
	loot_ui._request_auto_salvage(-1)
	_check("confirm: turning auto-salvage off is immediate", not dialog.is_open and int(Game.s.combat.auto_salvage) == -1)
	main.hud.open_settings("data")
	Game.save_game()
	var stored := JSON.stringify(Save.read())
	main.hud.settings_panel._on_reset_pressed()
	main.hud.settings_panel._on_reset_pressed()
	_check("confirm: repeated reset clicks still wait and preserve the saved game", dialog.is_open and JSON.stringify(Save.read()) == stored and Game.started)
	dialog.close()
	Settings._finish_import("not json")
	_check("confirm: invalid imported files never open a confirmation", not dialog.is_open)
	Settings._finish_import(stored)
	_check("confirm: a valid import waits before replacing the saved game", dialog.is_open and JSON.stringify(Save.read()) == stored)
	dialog.close()
	_check("confirm: cancelling import leaves the saved game byte-for-byte unchanged", JSON.stringify(Save.read()) == stored)
	main.hud.settings_panel.close()
	await wait(0.2)
	main.hud.title_screen.visible = true
	main.hud.title_screen.modulate.a = 1.0
	main.hud.title_screen._new_run()
	_check("confirm: NEW RUN waits when an existing save would be erased", dialog.is_open and JSON.stringify(Save.read()) == stored)
	dialog.close()
	_check("confirm: cancelling NEW RUN keeps the existing save", JSON.stringify(Save.read()) == stored and main.hud.title_screen.visible)
	main.hud.title_screen.visible = false
	main.hud.open_settings("data")
	# Long localized prompts remain inside the viewport, with both choices always reachable.
	for size in [Vector2i(360, 640), Vector2i(720, 1280), Vector2i(1600, 1200)]:
		get_window().size = size
		await wait(0.3)
		for language in ["th", "en"]:
			Settings.set_value("lang", language)
			main.hud.settings_panel._on_reset_pressed()
			await wait(0.1)
			var screen: Rect2 = main.hud.get_global_rect()
			_check("confirm: %s %s frame and both choices fit the screen" % [size, language], screen.encloses(dialog.box.get_global_rect()) and dialog.box.get_global_rect().encloses(dialog.cancel_button.get_global_rect()) and dialog.box.get_global_rect().encloses(dialog.confirm_button.get_global_rect()))
			await shot("confirm_%s_%dx%d" % [language, size.x, size.y])
			dialog.close()
	main.hud.settings_panel.close()
	await wait(0.2)
	var nextgen: NextGenPanel = main.hud.panels.nextgen
	main.hud.open_nextgen(false)
	nextgen.step = "crew"
	nextgen.refresh()
	var gen := Meta.generation()
	(nextgen.find_child("NextGenerationButton", true, false) as Button).pressed.emit()
	_check("confirm: next generation waits without replacing the vehicle", dialog.is_open and Meta.generation() == gen)
	dialog.close()
	_check("confirm: cancelling next generation retains its selection screen", nextgen.is_open and nextgen.step == "crew" and Meta.generation() == gen)
	nextgen.close()
	await wait(0.2)
	Inspection.queue().clear()
	var stranger := Inspection.queue_candidate("confirm-test", "rare", "human")
	main.hud.open_door()
	var door: InspectionPanel = main.hud.panels.door
	(door.find_child("RefuseStranger", true, false) as Button).pressed.emit()
	dialog.close()
	_check("confirm: cancelling stranger dismissal keeps them at the door", is_same(Inspection.current(), stranger))
	(door.find_child("ShootStranger", true, false) as Button).pressed.emit()
	dialog.close()
	_check("confirm: cancelling shooting leaves the visitor alive", is_same(Inspection.current(), stranger))
	door.close()
	await wait(0.2)
	main.hud.open_panel("god")
	Dev.confirm_preview()
	_check("confirm: GOD MODE previews the actual dialog", dialog.is_open)
	dialog.close()
	var calls := [0]
	Features.set_override("features", "confirm_actions", false)
	ConfirmPanel.ask(main.hud.panels.god, "test", "test", "test", func(): calls[0] += 1)
	_check("confirm: feature off restores direct actions without leaving a modal", calls[0] == 1 and not dialog.is_open)
	main.hud.panels.god.close()
	await wait(0.2)
	if saved_store.is_empty():
		Save.wipe()
	else:
		Save.write(saved_store)
	Account.a = saved_account
	Game.s = saved_state
	Game.started = saved_started
	Game.set_process(saved_processing)
	for key in saved_settings:
		Settings.set_value(key, saved_settings[key])
	Features.layers.dev = saved_features
	Features.changed.emit()
	main.hud.title_screen.visible = saved_title
	Game._emit_all(true)
	get_window().size = saved_size
	await wait(0.3)


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
	_check("save: reset waits for confirmation", Save.has_save() and main.hud.confirmation.is_open)
	main.hud.confirmation.close()
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
		_check("loot tabs: %s tab button is the control under the finger (got %s; button %s, window %s, open %s)" % [from, str(hov.get_path()) if hov else "none",
			btn.get_global_rect(), Rect2(inv.box.global_position, inv.box.size), inv.is_open],
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
	# switches that ship off on purpose: english until all three MV-151 PRs are in; seeded_world_map until the
	# world map screen ships (MV-500 phase 3: phases 1-2 change travel without a screen to drive it)
	var ships_off := ["english", "seeded_world_map"]
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
	_check("env: Cloudflare Pages branch URLs (MV-499)", BuildInfo.env_for_host("apocarlypse-mobile-vault.pages.dev") == "prod"
		and BuildInfo.env_for_host("uat.apocarlypse-mobile-vault.pages.dev") == "uat"
		and BuildInfo.env_for_host("staging.apocarlypse-mobile-vault.pages.dev") == "staging"
		and BuildInfo.env_for_host("3f2a9c1b.apocarlypse-mobile-vault.pages.dev") == "dev"
		and BuildInfo.env_for_host("mv-499-cloudflare-pages.apocarlypse-mobile-vault.pages.dev") == "dev")
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
	# Half-pixel rumble randomly skips beats; test motion with a deterministic whole-pixel amplitude.
	# _engine_shake_test separately checks the default half strength and its distribution.
	var rumble_override = Features.layers.dev.get("tune", {}).get("fx.engine_shake")
	Features.set_override("tune", "fx.engine_shake", 1.0)
	var ys := {}
	for i in 30:
		await get_tree().process_frame
		ys[v.body.position.y] = true
	_check("title: engine rumble moves the body", ys.size() >= 2)
	Features.set_override("tune", "fx.engine_shake", rumble_override)
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
func _icon_art_test() -> void:
	var names: Array[String] = []
	var sizes_ok := true
	for key in Atlas.regions:
		if str(key).begins_with("ic_"):
			var id := str(key).trim_prefix("ic_")
			names.append(id)
			var texture := Atlas.icon(id)
			sizes_ok = sizes_ok and texture.get_width() == 16 and texture.get_height() == 16
	_check("icons: all 92 native atlas regions remain 16x16", names.size() == 92 and sizes_ok)
	main.hud.open_panel("god")
	var god = main.hud.panels.god
	god.tab = "icons"
	for scale in [1, 2, 3]:
		Dev.icon_preview(scale)
		god.refresh()
		await wait(0.3)
		var grid: Node = god._list.find_child("IconGrid", true, false)
		var cells_ok: bool = grid != null and grid.get_child_count() == 92
		if grid:
			for cell in grid.get_children():
				var texture: TextureRect = cell.get_node("Icon")
				cells_ok = cells_ok and texture.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and texture.custom_minimum_size == Vector2(scale * 16, scale * 16)
		_check("icons: GOD gallery has 92 nearest-filtered entries at x%d" % scale, cells_ok)
		var scroll := god._list.get_parent() as ScrollContainer
		if scroll:
			scroll.scroll_vertical = 0
			await wait(0.2)
		await shot("icons_gallery_x%d" % scale)
		if scroll and scale == 2:
			for page in [1, 2, 3, 4]:
				scroll.scroll_vertical = page * 400
				await wait(0.2)
				await shot("icons_gallery_x2_page%d" % page)
	Dev.icon_preview(2)
	god.tab = "main"
	god.close()
	await wait(0.2)
	main.hud.open_panel("inventory")
	await wait(0.3)
	await shot("icons_inventory")
	main.hud.panels.inventory.close()
	await shot("icons_hud")


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
	# repeat_hours: shown again once that much time has passed since it was last shown
	var now_t := Time.get_unix_time_from_system()
	Announce.seen["t-rep"] = now_t - 2.0 * 3600.0
	_check("announce: repeat_hours cleaned + clamped", Features._clean({"announce": [{"id": "a", "text": "x", "repeat_hours": 9999}]}).announce[0].repeat_hours == 720.0)
	_check("announce: repeat_hours 6 not due after 2 h", not Announce.due({"id": "t-rep", "repeat_hours": 6.0}))
	_check("announce: repeat_hours 1 due after 2 h", Announce.due({"id": "t-rep", "repeat_hours": 1.0}))
	_check("announce: no repeat_hours = once", not Announce.due({"id": "t-rep"}) and Announce.due({"id": "never-seen"}))
	Announce.seen.erase("t-rep")
	_check("announce: shown time is remembered", float(Announce.seen.get("t-hello", 0.0)) > now_t - 60.0)
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
	Announce.seen["t-hello"] = 1.0
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


## MV-189: the 49 approved V2 scene images (tools/art/v2, built by tools/art/v2_native.py) keep the art contract
## in the game itself: event/encounter art 160x80 and interiors 256x100, opaque; interiors repeat without a seam;
## the 13 landmark sprites keep a 100 px width, binary alpha, ground contact and something solid at the door x=30
func _scene_art_test() -> void:
	var ev_ok := true
	var ev_n := 0
	for f in DirAccess.get_files_at("res://assets/events"):
		if not f.ends_with(".png"):
			continue
		var im: Image = (load("res://assets/events/" + f) as Texture2D).get_image()
		ev_n += 1
		if im.get_size() != Vector2i(160, 80) or im.detect_alpha() != Image.ALPHA_NONE:
			ev_ok = false
			print("scene art: bad event image ", f, " ", im.get_size())
	_check("scene art: %d event/encounter images are opaque 160x80" % ev_n, ev_ok and ev_n == 29)
	var int_ok := true
	for k in ["bunker", "hospital", "lab", "mine", "plant", "ruins", "store"]:
		var im: Image = (load("res://assets/exp/exp_%s.png" % k) as Texture2D).get_image()
		if im.get_size() != Vector2i(256, 100) or im.detect_alpha() != Image.ALPHA_NONE:
			int_ok = false
			print("scene art: bad interior ", k)
			continue
		# the wrap from the last column to the first is no rougher than the room's own busy columns
		var steps: Array = []
		for x in 255:
			steps.append(_col_diff(im, x, x + 1))
		steps.sort()
		if _col_diff(im, 255, 0) > float(steps[int(steps.size() * 0.9)]) + 0.001:
			int_ok = false
			print("scene art: seam in interior ", k)
	_check("scene art: 7 interiors are opaque 256x100 and tile without a seam", int_ok)
	var sheet: Image = Atlas.sheet.get_image()
	var lm_ok := true
	for id in Expedition.SITES:
		var key := str(Expedition.SITES[id].sprite)
		var r: Array = Atlas.regions.get(key, [])
		if r.is_empty():
			lm_ok = false
			continue
		var im := sheet.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		var used := im.get_used_rect()
		var ground := used.end.y - 1
		var door := false
		for y in range(ground - 5, ground + 1):
			door = door or im.get_pixel(int(ExpeditionView.DOOR_OFF), y).a > 0.5
		var binary := true
		for y in range(0, im.get_height(), 2):
			for x in im.get_width():
				var a := im.get_pixel(x, y).a
				binary = binary and (a == 0.0 or a == 1.0)
		if im.get_width() != 100 or ground < im.get_height() - 2 or not door or not binary:
			lm_ok = false
			print("scene art: landmark ", key, " w=", im.get_width(), " ground=", ground, " door=", door, " binary=", binary)
	_check("scene art: every landmark sprite is 100 px wide, stands on the ground with its door at x=30", lm_ok and Expedition.SITES.size() >= 12)
	# in the real consumers (Sgt. Mark's tips off so they don't cover the art)
	var tips0: Variant = Settings.get_value("tips")
	Settings.set_value("tips", false)
	main.hud.tip_card.dismiss()
	Dev.event("raiders")
	await wait(0.8)
	await shot("scene_art_event_raiders")
	await wait(0.4)
	main.hud.event_popup.close()
	Game.cancel_event()
	await wait(0.3)
	var km0 := float(Game.s.km)
	var site0 := Expedition.at_site()
	Expedition.arrive("mall")
	await wait(2.6)
	var ev: ExpeditionView = main.expedition_view
	_check("scene art: the mall landmark rolls in at the stop", ev.site_spr != null and ev.site_spr.visible)
	await shot("scene_art_landmark_mall")
	await wait(0.4)
	main.hud.open_expedition("mall")
	await wait(0.6)
	await shot("scene_art_planner_mall")
	await wait(0.4)
	main.hud.panels.expedition.close()
	Settings.set_value("tips", tips0)
	Game.s["at_site"] = site0
	Game.s.km = km0
	Game.travel_changed.emit()
	await wait(0.3)


func _industrial_background_test() -> void:
	var old_window := get_window().size
	var old_tod: float = Game.s.tod
	var old_biome: int = int(Game.s.biome)
	var old_weather: String = Game.s.weather
	var overrides: Dictionary = Features.layers.dev.duplicate(true)
	Features.set_override("features", "industrial_parallax", true)
	get_window().size = Vector2i(1280, 640)
	Game.s.biome = 0
	Game.force_weather("clear")
	main.background._on_biome_changed(0, true)
	await wait(0.8)
	var live: IndustrialBackdrop = main.background.groups.industrial.modern
	_check("background: new art only on the industrial biome", live.is_visible_in_tree() and not main.background.groups.desert.has("modern"))
	var long_layers := true
	var periods := {}
	for key in live.layers:
		var px: Parallax2D = live.layers[key].node
		long_layers = long_layers and px.repeat_size.x >= 1920 and px.repeat_size.x == (px.get_child(0) as Sprite2D).texture.get_width()
		periods[int(px.repeat_size.x)] = true
	_check("background: actual texture widths drive long independent repeats", long_layers and periods.size() >= 4)
	var child_count := live.get_child_count()
	for entry in [[0.25, "sunrise", true, 1], [0.5, "daylight", true, 2], [0.75, "sunset", false, 3], [0.0, "moonlight", false, 0]]:
		Game.s.tod = float(entry[0])
		live.update_clock()
		_check("background: simulation clock selects %s sky and celestial body" % entry[1], live.sky_state == int(entry[3]) and live.sun_visible == bool(entry[2]))
		_check("background: %s celestial position stays on the pixel grid" % entry[1], live.celestial_position == live.celestial_position.round())
		await wait(0.5)
		await shot("industrial_" + str(entry[1]))
	Game.s.tod = 0.35
	live.update_clock()
	var morning := live.celestial_position
	Game.s.tod = 0.60
	live.update_clock()
	_check("background: sun moves after an in-game clock jump", morning.distance_to(live.celestial_position) > 20)
	var phase0 := live.phase
	await wait(0.6)
	_check("background: smoke/dust animation advances without spawning nodes", live.phase > phase0 and live.get_child_count() == child_count)
	live.preview_offset(99999.0)
	var snapped := true
	for key in live.layers:
		var px: Parallax2D = live.layers[key].node
		snapped = snapped and px.scroll_offset.x == roundf(px.scroll_offset.x) and absf(px.scroll_offset.x) <= px.repeat_size.x
	_check("background: large travel offsets wrap on whole pixels", snapped)
	Features.set_override("features", "industrial_parallax", false)
	_check("background: feature off restores the old industrial background", not live.visible and main.background.groups.industrial.legacy[0].visible)
	Features.set_override("features", "industrial_parallax", true)
	main.background._on_biome_changed(1, true)
	phase0 = live.phase
	await wait(0.3)
	_check("background: hidden industrial biome stops ambience updates", live.phase == phase0)
	main.background._on_biome_changed(0, true)
	Game.s.tod = 0.0
	get_window().size = Vector2i(405, 720)
	await wait(0.8)
	await shot("industrial_portrait_moonlight")
	main.hud.open_panel("god")
	var god = main.hud.panels.god
	god.tab = "world"
	god.refresh()
	await wait(0.2)
	var preview_buttons := {}
	for row in god._list.get_children():
		for control in row.get_children():
			if control is Button:
				preview_buttons[control.text] = control
	_check("background: GOD world tab provides all four clock previews", preview_buttons.has("รุ่งเช้า") and preview_buttons.has("กลางวัน") and preview_buttons.has("พระอาทิตย์ตก") and preview_buttons.has("กลางคืน") and preview_buttons.has("ฉากเดิม"))
	god.close()
	Features.layers.dev = overrides
	Features.changed.emit()
	Game.s.tod = old_tod
	Game.s.biome = old_biome
	Game.force_weather(old_weather)
	main.background._on_biome_changed(old_biome, true)
	get_window().size = old_window
	await wait(0.3)


func _col_diff(im: Image, a: int, b: int) -> float:
	var d := 0.0
	for y in im.get_height():
		var p := im.get_pixel(a, y)
		var q := im.get_pixel(b, y)
		d += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)
	return d


## MV-247: raw food. Hydroponics grows crops, mutated animals drop meat, the kitchen cooks crops / meat + water
## into food (and stops when they run out or the pantry is full); recipes use sensible inputs; switch off = old game
## MV-378: a save load turns the biome into a float; the beaten warlord must still open the checkpoint
func _checkpoint_test() -> void:
	var keep := {"biome": Game.s.biome, "km": Game.s.km, "vault_level": Game.s.vault_level, "beaten": (Game.s.combat.boss_beaten as Dictionary).duplicate(), "warlord_cd": Combat.warlord_cd}
	# Earlier boss tests can leave a retry cooldown; this fixture models a fresh load.
	Combat.warlord_cd = 0.0
	Game.s.biome = 0.0     # as JSON.parse_string hands it back
	Game.s.km = Data.biome_start_km(1)
	Game.s.vault_level = maxi(int(Game.s.vault_level), int(Data.biome(1).req))
	Game.s.combat.boss_beaten = {}
	_check("checkpoint: warlord blocks the road after a load", Game.at_checkpoint() and Combat.warlord_due())
	Combat.wave_is_warlord = true
	Combat._on_wave_cleared()
	Combat.wave_is_warlord = false
	_check("checkpoint: killing the warlord opens it (no respawn)", Combat.boss_beaten(0) and not Game.at_checkpoint() and not Combat.warlord_due())
	Game.s.combat.boss_beaten = {"0.0": true}     # a save written before the fix
	Game.s.biome = 0.0
	Game._migrate()
	_check("checkpoint: old saves with \"0.0\" keys are repaired", Combat.boss_beaten(0) and typeof(Game.s.biome) == TYPE_INT and not Game.at_checkpoint())
	Game.s.biome = int(keep.biome)
	Game.s.km = float(keep.km)
	Game.s.vault_level = int(keep.vault_level)
	Game.s.combat.boss_beaten = keep.beaten
	Combat.warlord_cd = float(keep.warlord_cd)
	Combat.wave_changed.emit()


func _raw_food_test() -> void:
	var res0: Dictionary = (Game.s.res as Dictionary).duplicate()
	_check("raw food: the switch is on by default", Data.raw_food())
	_check("raw food: every save has crops and meat", Game.s.res.has("crops") and Game.s.res.has("meat"))
	var kitchen := -1
	for i in Game.s.rooms.size():
		if Game.room(i).type == "kitchen" and not Game.is_site(i):
			kitchen = i
			break
	_check("raw food: the start layout has a kitchen", kitchen >= 0)
	if Game.room_workers(kitchen).is_empty():
		for d in Game.s.dwellers:
			if not Game.is_away(d) and Game.squad_role(d) < 0 and int(d.room) != Data.CAB_SLOT:
				Game.assign(d, kitchen)
				break
	var rate := Game.room_rate_pm(kitchen)
	var ins := Game.room_inputs_pm(kitchen, rate)
	var f := float(rate.get("food", 0.0))
	_check("raw food: the kitchen cooks crops/meat + water (%.2f food uses %.2f raw, %.2f water)" % [f, float(ins.get("raw", 0.0)), float(ins.get("water", 0.0))],
		f > 0.0 and is_equal_approx(float(ins.get("raw", 0.0)), f / Data.COOK_YIELD) and is_equal_approx(float(ins.get("water", 0.0)), f * Data.COOK_WATER))
	Game.s.res.water = 100.0
	Game.s.res.food = 0.0
	Game.s.res.crops = 0.0
	Game.s.res.meat = 0.0
	_check("raw food: no crops or meat = the kitchen makes nothing", Game._input_frac(rate, ins, 1.0) == 0.0)
	Game.s.res.crops = 40.0
	Game.s.res.meat = 20.0
	_check("raw food: stocked = full output", is_equal_approx(Game._input_frac(rate, ins, 1.0), 1.0))
	Game._use_inputs(ins, 1.0, 1.0)
	var used_c := 40.0 - float(Game.s.res.crops)
	var used_m := 20.0 - float(Game.s.res.meat)
	_check("raw food: crops and meat are used in proportion to stock (%.2f / %.2f)" % [used_c, used_m],
		used_c > 0.0 and used_m > 0.0 and absf(used_c - 2.0 * used_m) < 0.01 and absf(used_c + used_m - float(ins.raw)) < 0.01)
	Game.s.res.food = Game.cap("food")
	_check("raw food: a full pantry stops cooking (nothing wasted)", Game._input_frac(rate, ins, 1.0) == 0.0)
	# the real tick, run twice from the same state: with crops the kitchen adds food, with none it adds nothing
	Game.s.res.food = 20.0
	Game.s.res.meat = 0.0
	var orig: Dictionary = Game.s      # both runs on copies; the live save object goes back untouched
	Game.s = orig.duplicate(true)
	Game.s.res.crops = 40.0
	Game._simulate(30.0, true)
	var food_fed := float(Game.s.res.food)
	Game.s = orig.duplicate(true)
	Game.s.res.crops = 0.0
	Game._simulate(30.0, true)
	var food_empty := float(Game.s.res.food)
	Game.s = orig
	_check("raw food: the tick cooks crops into food (%.1f with crops, %.1f without)" % [food_fed, food_empty], food_fed > food_empty + 1.0)
	_check("raw food: hydroponics grows crops (switch off: food)", Data.room_produce("hydroponics").has("crops") and not Data.room_produce("hydroponics").has("food"))
	# recipes
	var kr := Data.recipes("kitchen").map(func(r): return str(r.id))
	var cook: Dictionary = Data.recipes("kitchen").filter(func(r): return r.id == "cook_meal")[0]
	_check("raw food: kitchen recipes cook crops / grill meat, no scrap", kr.has("grill_meat") and cook.cost.has("crops") and not cook.cost.has("scrap"))
	var sr := Data.recipes("science").map(func(r): return str(r.id))
	_check("raw food: science grows lab meat instead of making scrap out of power", sr.has("lab_meat") and not sr.has("refine"))
	var no_scrap := true
	for room_type in ["kitchen", "hydroponics", "medical", "refinery"]:
		for rec in Data.recipes(room_type):
			if room_type != "refinery" or rec.id == "biofuel":
				no_scrap = no_scrap and not (rec.cost as Dictionary).has("scrap")
	_check("raw food: food, medicine and biofuel recipes no longer use scrap", no_scrap)
	# hunting: animals drop meat, people / machines don't
	Game.s.res.meat = 0.0
	Combat._on_kill({"id": -1, "mob": "rad_wolf", "lvl": 5, "boss": false, "warlord": false, "elite": false, "x": 300.0, "y": 150.0, "mech": [], "scale": 1.0, "tint": ""})
	var wolf_meat := float(Game.s.res.meat)
	Combat._on_kill({"id": -2, "mob": "scav_raider", "lvl": 5, "boss": false, "warlord": false, "elite": false, "x": 300.0, "y": 150.0, "mech": [], "scale": 1.0, "tint": ""})
	_check("raw food: a rad-wolf kill gives meat (%.2f), a raider none" % wolf_meat, wolf_meat > 0.1 and is_equal_approx(float(Game.s.res.meat), wolf_meat))
	# UI
	_check("raw food: HUD shows crops and meat", main.hud.res_labels.has("crops") and main.hud.res_labels.has("meat"))
	Game.s.res.crops = 0.0
	Game.s.res.meat = 0.0
	main.open_closeup(kitchen)
	await wait(1.0)
	_check("raw food: the kitchen close-up warns when crops and meat run out", _find_text(main.hud.room_closeup, "พืชผลและเนื้อหมด"))
	await shot("raw_food_kitchen_empty")
	main.hud.room_closeup.close()
	await wait(0.4)
	Game.s.res.crops = 60.0
	Game.s.res.meat = 30.0
	await wait(0.4)
	await shot("raw_food_hud")
	# switch off: the old game
	Features.set_override("features", "raw_food", false)
	_check("raw food off: kitchen recipes use scrap again", (Data.recipes("kitchen").filter(func(r): return r.id == "cook_meal")[0].cost as Dictionary).has("scrap") and not Data.recipes("kitchen").any(func(r): return r.id == "grill_meat"))
	_check("raw food off: the kitchen cooks without inputs", Game.room_inputs_pm(kitchen, rate).is_empty() and Data.room_produce("hydroponics").has("food"))
	var food0 := float(Game.s.res.food)
	Game.s.res.food = 0.0
	Game.give_rewards({"meat": 10, "crops": 5})
	_check("raw food off: crop / meat rewards arrive as food", is_equal_approx(float(Game.s.res.food), 15.0))
	Game.s.res.food = food0
	Features.set_override("features", "raw_food", null)
	Game.s.res = res0
	Game.resources_changed.emit()


## MV-47: loot pity: never more than N-1 random drops in a row without Epic+ / Legendary+, switch + tune +
## GOD actions, tester drops don't count, JSON floats in the counter, the gear panel line
func _pity_test() -> void:
	Dev.pity_reset()
	Features.set_override("tune", "loot.pity_epic", 5.0)
	Features.set_override("tune", "loot.pity_legend", 20.0)
	var run_e := 0
	var run_l := 0
	var worst_e := 0
	var worst_l := 0
	for i in 400:
		var r := Loot.drop_rarity(0.0, 0)
		run_e = 0 if r >= 3 else run_e + 1
		run_l = 0 if r >= 4 else run_l + 1
		worst_e = maxi(worst_e, run_e)
		worst_l = maxi(worst_l, run_l)
	_check("pity: at most 4 drops in a row without Epic+ (tune 5)", worst_e <= 4)
	_check("pity: at most 19 drops in a row without Legendary+ (tune 20)", worst_l <= 19)
	Dev.pity_next(4)
	_check("pity: GOD next drop is Legendary+", Loot.pity_left(4) == 1 and Loot.drop_rarity(0.0, 0) >= 4 and int(Loot.pity().legend) == 0)
	Loot.pity().epic = 3.0     # a save from JSON gives floats
	_check("pity: float counter from a save", Loot.pity_left(3) == 2)
	Dev.pity_next(3)
	var before := int(Loot.pity().epic)
	Dev.drop_gear(0, 3)
	_check("pity: GOD drops don't move the counter", int(Loot.pity().epic) == before)
	Features.set_override("features", "loot_pity", false)
	for i in 30:
		Loot.drop_rarity(0.0, 0)
	_check("pity: switch off = plain rolls, counter kept", int(Loot.pity().epic) == before)
	Features.set_override("features", "loot_pity", null)
	Dev.pity_reset()
	_check("pity: GOD reset", int(Loot.pity().epic) == 0 and int(Loot.pity().legend) == 0 and Loot.pity_left(3) == 5)
	var inv = main.hud.panels.inventory
	inv.tab = "gear"
	inv.pick_slot = ""
	inv.detail_uid = -1
	inv.open()
	await wait(0.3)
	var line = inv.find_child("PityLine", true, false)
	_check("pity: gear panel shows the guarantee", line != null and str(line.text).contains("5"))
	await shot("loot_pity")
	inv.close()
	Features.set_override("tune", "loot.pity_epic", null)
	Features.set_override("tune", "loot.pity_legend", null)
	_check("pity: default tune 40 / 150", Loot.pity_need(3) == 40 and Loot.pity_need(4) == 150)


## waits (up to max_s) until cond() is true
func _wait_for(cond: Callable, max_s: float) -> void:
	var t := 0.0
	while t < max_s and not cond.call():
		await wait(0.02)
		t += 0.02


## MV-517: monsters drawn bigger: whole-number scale per kind for every mob / boss sprite, boss > elite > normal,
## raiders from the crew sheet one step smaller, everything fits the fight zone, the GOD lineup on screen at its stop
## spots (hp bar + crown included), tune steps down when too big, switch off = the old size
func _enemy_size_test() -> void:
	var cv: CombatView = main.combat_view
	_no_events()
	Dev.kill_enemies()
	await wait(0.4)
	var dims := func(sprite: String) -> Vector2:
		if sprite.begins_with("dw_"):
			return Vector2(Atlas.DW_W, Atlas.DW_H)
		var r: Array = Atlas.regions[sprite + "_0"]
		return Vector2(float(r[2]), float(r[3]))
	var whole := true
	var grows := true
	var fits := true
	var people := true
	var max_elite := Vector2.ZERO
	var max_normal := Vector2.ZERO
	for id in Combat.MOBS:
		var sp: String = Combat.MOBS[id].sprite
		var d: Vector2 = dims.call(sp)
		var sn := CombatView.enemy_scale({"sprite": sp}, d.x, d.y)
		var se := CombatView.enemy_scale({"sprite": sp, "elite": true}, d.x, d.y)
		whole = whole and sn >= 1 and se >= 1
		grows = grows and se > sn
		fits = fits and d.x * se <= CombatView.FIGHT_W and d.y * se <= CombatView.FIGHT_H
		if sp.begins_with("dw_"):
			people = people and sn == 1 and se == 2
		else:
			people = people and sn == 2 and se == 3
		max_elite = max_elite.max(d * se)
		max_normal = max_normal.max(d * sn)
	var min_boss := Vector2(INF, INF)
	var boss_kinds := true
	for bd in Combat.BOSSES.values() + Combat.WAVE_BOSSES.values():
		var d: Vector2 = dims.call(str(bd.sprite))
		var sb := CombatView.enemy_scale({"sprite": bd.sprite, "boss": true}, d.x, d.y)
		var sw := CombatView.enemy_scale({"sprite": bd.sprite, "boss": true, "warlord": true}, d.x, d.y)
		whole = whole and sb >= 1 and sw >= sb
		fits = fits and d.x * sw <= CombatView.FIGHT_W and d.y * sw <= CombatView.FIGHT_H
		boss_kinds = boss_kinds and sb == 3 and sw == 3
		min_boss = min_boss.min(d * sb)
	_check("enemy size: whole-number scales, normal x2 / elite x3 / boss + warlord x3, raiders one step smaller", whole and people and boss_kinds)
	_check("enemy size: every elite bigger than the same mob as a normal", grows)
	_check("enemy size: smallest boss %s taller and wider than the biggest elite %s" % [min_boss, max_elite],
		min_boss.x > max_elite.x and min_boss.y > max_elite.y and max_elite.y > Atlas.DW_H)
	_check("enemy size: every kind fits the fight zone (%dx%d)" % [CombatView.FIGHT_W, CombatView.FIGHT_H], fits)
	# the GOD lineup: a normal, an elite and the boss, real enemies
	main.set_zoom_mode("auto")
	Dev.enemy_size_preview("lineup")
	await _wait_for(func(): return cv.enemy_nodes.size() >= 3, 4.0)
	await wait(0.6)
	var by_kind := {}
	for e in Combat.enemies:
		var node = cv.enemy_nodes.get(int(e.id))
		if node:
			by_kind[CombatView.size_kind(e)] = [e, node]
	_check("enemy size: GOD lineup spawns normal + elite + boss", by_kind.has("normal") and by_kind.has("elite") and by_kind.has("boss"))
	var sizes_ok := by_kind.size() == 3
	var on_screen := true
	var vp: Vector2 = main.vp_size()
	var view := Rect2(main.camera.get_screen_center_position() - vp * 0.5, vp)
	for k in by_kind:
		var e: Dictionary = by_kind[k][0]
		var node = by_kind[k][1]
		sizes_ok = sizes_ok and node.z_index == (4 if node.is_boss else 5) and node.spr.scale == Vector2(node.size, node.size) and node.size == {"normal": 2, "elite": 3, "boss": 3}[k]
		# where it ends up: its stop spot behind the truck, hp bar (+ crown for a boss) above the head
		var stop: Vector2 = node.place(CombatView.sim_to_view(Vector2(float(e.stop_x), float(e.y))))
		var r: Rect2 = node.sprite_rect()
		r.position += stop - node.position
		r = r.expand(r.position + Vector2(0, -(25.0 if node.is_boss else 6.0)))
		var g := Rect2(cv.to_global(r.position), r.size)
		var ok := view.encloses(g) and r.end.x <= CombatView.fight_right() + 0.5
		if not ok:
			print("[autotest] enemy size: %s at %s off the view %s" % [k, g, view])
		on_screen = on_screen and ok
	_check("enemy size: lineup drawn at x2 / x3 / x3", sizes_ok)
	_check("enemy size: lineup at its stop spots stays on screen (view %s)" % view, on_screen)
	await shot("enemy_size_lineup")
	# too big for the fight zone: a x4 boss steps down instead of hanging off the screen
	Features.set_override("tune", "enemy_size.boss", 4.0)
	var wide_boss := CombatView.enemy_scale({"sprite": "boss_scorpion", "boss": true}, 48.0, 28.0)
	Features.set_override("tune", "enemy_size.boss", null)
	Features.set_override("tune", "enemy_size.normal", 3.0)
	var tuned := CombatView.enemy_scale({"sprite": "en_rat"}, 16.0, 10.0)
	Features.set_override("tune", "enemy_size.normal", null)
	_check("enemy size: tune enemy_size.* (x4 boss steps down to %d, normal x%d)" % [wide_boss, tuned], wide_boss == 3 and tuned == 3)
	# switch off = the old size, road zombies included
	Dev.kill_enemies()
	await wait(0.4)
	Features.set_override("features", "enemy_size", false)
	Dev.enemy_size_preview("normal")
	await _wait_for(func(): return cv.enemy_nodes.size() >= 1, 3.0)
	var off_ok := cv.enemy_nodes.size() >= 1
	for node in cv.enemy_nodes.values():
		off_ok = off_ok and node.size == 1 and node.spr.scale == Vector2.ONE
	_check("enemy size: switch off = original size", off_ok and CombatView.enemy_scale({"boss": true}, 48.0, 48.0) == 1)
	Features.set_override("features", "enemy_size", null)
	Dev.kill_enemies()
	await wait(0.4)


## MV-387: boss / warlord / elite entrances: the HUD band with the name, drop-in + landing in the world, elites
## without a band, never takes taps, switch off, tune, GOD previews
func _boss_intro_test() -> void:
	var intro: BossIntro = main.hud.boss_intro
	var cv: CombatView = main.combat_view
	_no_events()
	Dev.kill_enemies()
	await wait(0.4)
	cv.last_entrance = ""
	Dev.spawn_boss("warlord")
	await _wait_for(func(): return cv.last_entrance != "", 3.0)
	var b := Combat.current_boss()
	var n = cv.enemy_nodes.get(int(b.get("id", -1)))
	_check("boss intro: warlord drops in from above", cv.last_entrance == "warlord" and n != null and float(n.drop) > 0.0)
	await wait(0.15)
	_check("boss intro: warlord WARNING band with its name (%s)" % intro._name.text, intro.visible and intro.kind == "warlord"
		and not b.is_empty() and intro._name.text.contains(str(b.name)))
	_check("boss intro: the band never takes taps", intro.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and intro._name.mouse_filter == Control.MOUSE_FILTER_IGNORE and intro._title.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	await shot("boss_intro_warlord")
	await wait(0.4)
	_check("boss intro: warlord landed", n != null and is_instance_valid(n) and float(n.drop) == 0.0)
	await shot("boss_intro_warlord_landed")
	await _wait_for(func(): return not intro.visible, 4.0)
	_check("boss intro: band goes away on its own", not intro.visible and intro.kind == "")
	# a mutant boss: the smaller band
	Dev.kill_enemies()
	await wait(0.4)
	cv.last_entrance = ""
	Dev.spawn_boss(str(Combat.WAVE_BOSSES.keys()[0]))
	await _wait_for(func(): return cv.last_entrance != "", 3.0)
	await wait(0.15)
	_check("boss intro: mutant boss gets the BOSS band", cv.last_entrance == "boss" and intro.visible and intro.kind == "boss")
	await shot("boss_intro_boss")
	await _wait_for(func(): return not intro.visible, 4.0)
	# elites: world cue only
	Dev.kill_enemies()
	await wait(0.4)
	cv.last_entrance = ""
	Dev.spawn_elites(1)
	await _wait_for(func(): return cv.last_entrance != "", 3.0)
	_check("boss intro: elite gets a glint, no band", cv.last_entrance == "elite" and not intro.visible)
	# switch off
	Dev.kill_enemies()
	await wait(0.4)
	Features.set_override("features", "boss_intro", false)
	cv.last_entrance = ""
	Dev.spawn_boss("warlord")
	await wait(1.2)
	_check("boss intro: switch off = no entrance", cv.last_entrance == "" and not intro.visible and not Combat.current_boss().is_empty())
	Features.set_override("features", "boss_intro", null)
	Dev.kill_enemies()
	await wait(0.4)
	# GOD previews + tune
	Features.set_override("tune", "boss_intro.time", 0.5)
	Dev.entrance_preview("warlord")
	_check("boss intro: GOD preview + tune boss_intro.time", intro.kind == "warlord" and is_equal_approx(intro._dur, 1.3) and cv.last_entrance == "warlord")
	Features.set_override("tune", "boss_intro.time", null)
	Dev.entrance_preview("elite")
	_check("boss intro: GOD elite preview", cv.last_entrance == "elite")
	await _wait_for(func(): return not intro.visible, 4.0)
	Dev.kill_enemies()
	await wait(0.4)


## MV-388 phase 1: wheel redraws keep their sizes / phases, the static shell details are in the atlas, leaf springs
## sit over every road wheel (main + trailers), give way to the coil-overs and the tracks, none on rails, switch off
## MV-462 cozy roof: the nine parts at their spec sizes, the roof parts / old roof follow the switch on every
## chassis, the deck art follows it at every level, and the roof deck keeps its stats
func _cozy_roof_test() -> void:
	var v: Vehicle = main.vehicle
	var sizes := {"prop_roof_water_tank": [32, 20], "prop_roof_satellite_dish": [16, 17], "prop_roof_planter_tray": [14, 17],
		"prop_roof_deck_frame": [76, 60], "prop_roof_patched_awning": [38, 22], "prop_roof_bench_blanket": [24, 7],
		"prop_roof_glass_windbreak": [22, 16], "prop_roof_caged_lamp": [6, 12], "prop_roof_water_can": [9, 14],
		"mod_roof_deck_cozy_1": [76, 60], "mod_roof_deck_cozy_2": [76, 60], "mod_roof_deck_cozy_3": [76, 60],
		"roof_legacy_van": [146, 38], "roof_legacy_bus": [146, 38], "roof_legacy_rig": [146, 38], "roof_legacy_train": [146, 38]}
	var ok := true
	for k in sizes:
		var r = Atlas.regions.get(k)
		if r == null or int(r[2]) != int(sizes[k][0]) or int(r[3]) != int(sizes[k][1]):
			ok = false
			print("[autotest] cozy roof sprite wrong: %s %s" % [k, str(r)])
	_check("cozy roof: 9 parts, 3 deck levels and 4 old-roof sprites at their sizes", ok)
	var was_mods: Dictionary = Game.s.mods.duplicate(true)
	var was_tier := Game.tier()
	var was_tr := Game.trailers()
	var cozy := ["prop_roof_planter_tray", "prop_roof_planter_tray", "prop_roof_water_tank", "prop_roof_satellite_dish"]
	Dev.set_trailers(0)
	for t in ["van", "bus", "rig", "train"]:
		Dev.set_tier(t)
		await wait(0.1)
		Dev.cozy_roof_switch(true)
		await wait(0.05)
		var on_parts := v.sprite_regions(true)
		on_parts.sort()
		var want := cozy.duplicate()
		want.sort()
		Dev.cozy_roof_switch(false)
		await wait(0.05)
		_check("cozy roof %s: switch on = tank, dish, 2 trays; off = the old roof (%s / %s)" % [t, str(on_parts), str(v.sprite_regions(true))],
			on_parts == want and v.sprite_regions(true) == ["roof_legacy_" + t])
	Dev.cozy_roof_switch(true)
	Dev.set_tier("rig")
	await wait(0.1)
	for lv in [1, 2, 3]:
		Dev.roof_deck_preview(lv)
		await wait(0.05)
		_check("cozy roof: deck Lv%d uses the cozy art" % lv, v.sprite_regions(false).has("mod_roof_deck_cozy_%d" % lv))
		if lv == 3:
			await shot("cozy_roof_rig_deck3")
		Dev.cozy_roof_switch(false)
		await wait(0.05)
		_check("cozy roof: switch off = the old deck Lv%d" % lv, v.sprite_regions(false).has("mod_roof_deck_%d" % lv)
			and not v.sprite_regions(false).has("mod_roof_deck_cozy_%d" % lv))
		Dev.cozy_roof_switch(true)
		await wait(0.05)
	_check("cozy roof: the deck keeps its height (lift %d)" % int(Vehicle.deck_lift()), Vehicle.deck_lift() == float(Vehicle.ROOF_DECK_H))
	Dev.roof_deck_preview(0)
	await wait(0.05)
	_check("cozy roof: no deck sprite at Lv0", not v.sprite_regions(false).any(func(r): return str(r).begins_with("mod_roof_deck")))
	await shot("cozy_roof_rig")
	Features.set_override("features", "cozy_roof", null)
	Game.s.mods = was_mods
	Mods.mods_changed.emit()
	Dev.set_tier(was_tier)
	Dev.set_trailers(was_tr)
	await wait(0.1)


func _vehicle_detail_test() -> void:
	var v: Vehicle = main.vehicle
	var sizes := {"wheel_0": [32, 32], "wheel_3": [32, 32], "bwheel_0": [32, 32], "bwheel_3": [32, 32], "rwheel_0": [20, 20],
		"rwheel_3": [20, 20], "decal_car_pillar_wear": [6, 52], "decal_car_weld_patch": [12, 8], "decal_car_tank_detail": [54, 12],
		"prop_car_leaf_spring": [32, 10], "decal_car_lamp_cage": [2, 6], "decal_train_bogie_detail": [44, 6]}
	var ok := true
	for k in sizes:
		var r = Atlas.regions.get(k)
		if r == null or int(r[2]) != int(sizes[k][0]) or int(r[3]) != int(sizes[k][1]):
			ok = false
			print("[autotest] detail sprite wrong: %s %s" % [k, str(r)])
	_check("vehicle detail: wheels + 6 detail sprites at their spec sizes", ok and Atlas.wheel_frames(false).get_frame_count("default") == 4
		and Atlas.rail_wheel_frames().get_frame_count("default") == 4)
	var was_mods: Dictionary = Game.s.mods.duplicate(true)
	var was_tier := Game.tier()
	var was_tr := Game.trailers()
	for id in ["suspension", "tracks"]:
		Game.s.mods[id] = 0
	var cab_crew: int = Game.s.dwellers.filter(func(d): return int(d.room) == Data.CAB_SLOT).size()
	Dev.set_tier("rig")
	Dev.set_trailers(0)
	await wait(0.2)
	_check("god: changing tier / trailers keeps the cab crew in the cab (%d)" % cab_crew,
		Game.s.dwellers.filter(func(d): return int(d.room) == Data.CAB_SLOT).size() == cab_crew)
	_check("vehicle detail: a leaf spring over each of the rig's 3 road wheels (%d)" % v.leaf_springs(), v.leaf_springs() == 3)
	Dev.set_trailers(1)
	await wait(0.2)
	_check("vehicle detail: + 2 on a trailer (%d)" % v.leaf_springs(), v.leaf_springs() == 5)
	await shot("vehicle_detail_rig")
	Game.s.mods["tracks"] = 1
	Mods.mods_changed.emit()
	await wait(0.1)
	_check("vehicle detail: tracks hide the rear springs (%d)" % v.leaf_springs(), v.leaf_springs() == 3)
	Game.s.mods["tracks"] = 0
	Game.s.mods["suspension"] = 1
	Mods.mods_changed.emit()
	await wait(0.1)
	_check("vehicle detail: coil-overs replace the main springs, trailer keeps its own (%d)" % v.leaf_springs(), v.leaf_springs() == 2)
	Game.s.mods["suspension"] = 0
	Mods.mods_changed.emit()
	Dev.vehicle_detail_switch(false)
	await wait(0.1)
	_check("vehicle detail: switch off = no springs", v.leaf_springs() == 0)
	Dev.vehicle_detail_switch(true)
	await wait(0.1)
	_check("vehicle detail: switch back on", v.leaf_springs() == 5)
	Dev.set_tier("train")
	await wait(0.2)
	_check("vehicle detail: none on the train or its wagons (%d)" % v.leaf_springs(), v.leaf_springs() == 0)
	await shot("vehicle_detail_train")
	Features.set_override("features", "vehicle_detail", null)
	Game.s.mods = was_mods
	Dev.set_tier(was_tier)
	Dev.set_trailers(was_tr)
	Mods.mods_changed.emit()
	await wait(0.2)


## MV-388 phase 2: engine-room block detail (healthy idle / run only), fan + hose (half speed parked, held when
## broken), hot-vent wisps replace the old steam (max 2), broken keeps the old smoke, every switch off
func _engine_detail_test() -> void:
	var ok := true
	for t in ["van", "bus", "rig", "train"]:
		ok = ok and Atlas.has("decal_engine_%s_block" % t)
	for k in ["prop_engine_fan_idle_3", "prop_engine_hose_idle_3", "fx_engine_heat_vent_5"]:
		ok = ok and Atlas.has(k)
	_check("engine detail: 4 block decals + fan / hose / vent strips in the atlas", ok)
	var was_tier := Game.tier()
	var was_trav: bool = Game.s.traveling
	var e := EngineBay.st()
	var was_heat := float(e.get("heat", 40.0))
	var was_cond := float(e.get("cond", 100.0))
	Dev.set_tier("rig")
	await wait(0.2)
	var cv: CabView = main.vehicle.cab_view
	Game.s.traveling = false
	Dev.engine_set("heat", 40.0)
	Dev.engine_set("cond", 100.0)
	await wait(0.4)
	_check("engine detail: parked healthy = idle, block detail on (%s)" % EngineBay.state_key(), EngineBay.state_key() == "idle" and cv._block.visible)
	_check("engine detail: fan + hose turn, the fan at half speed parked", cv.fan.visible and cv.fan.is_playing()
		and is_equal_approx(cv.fan.speed_scale, 0.5) and cv.hose.visible and cv.hose.is_playing())
	_check("engine detail: no steam or wisp on a healthy engine", not cv._steam.emitting and cv.vents_active() == 0)
	Dev.engine_set("heat", 115.0)
	await wait(0.4)
	_check("engine detail: hot = block detail off, wisps replace the old steam (%d)" % cv.vents_active(), EngineBay.state_key() == "hot"
		and not cv._block.visible and not cv._steam.emitting and cv.vents_active() >= 1)
	cv.vent_now()
	cv.vent_now()
	cv.vent_now()
	_check("engine detail: at most two wisps at once", cv.vents_active() == 2)
	await shot("engine_detail_hot")
	Dev.vehicle_ambience_switch(false)
	await wait(0.1)
	_check("engine detail: ambience off = old steam back, no fan / hose / wisps", cv._steam.emitting and not cv.fan.visible
		and not cv.hose.visible and cv.vents_active() == 0)
	Dev.vehicle_ambience_switch(true)
	Dev.engine_set("heat", 40.0)
	Dev.engine_set("cond", 0.0)
	await wait(0.4)
	_check("engine detail: broken = old dark smoke, fan held on frame 0, no detail (%s)" % EngineBay.state_key(), EngineBay.state_key() == "broken"
		and cv._steam.emitting and not cv.fan.is_playing() and cv.fan.frame == 0 and not cv._block.visible and cv.vents_active() == 0)
	Dev.engine_set("cond", 100.0)
	Features.set_override("features", "room_ambience", false)
	await wait(0.1)
	_check("engine detail: room_ambience off hides the fan and hose", not cv.fan.visible and not cv.hose.visible)
	Features.set_override("features", "room_ambience", null)
	Dev.vehicle_detail_switch(false)
	await wait(0.1)
	_check("engine detail: vehicle_detail off hides the block detail", not cv._block.visible)
	Features.set_override("features", "vehicle_detail", null)
	Features.set_override("features", "vehicle_ambience", null)
	Dev.engine_set("heat", was_heat)
	Dev.engine_set("cond", was_cond)
	Game.s.traveling = was_trav
	Dev.set_tier(was_tier)
	await wait(0.2)


## MV-388 phase 3: roof flag animates (frame 0 when off), rear chain follows the last deck, mudflap behind the
## rearmost road tyre (not under tracks, not on rails), exhaust puffs replace the smoke emitter (max 2, none when
## broken), roof drips only in rain / storm, switch off restores the old smoke
## MV-519: Viktor in every driving cab (baked) + the driver_cab micro-animation over the window
func _driver_cab_test() -> void:
	var v: Vehicle = main.vehicle
	var sizes := {"van": [23, 29], "bus": [13, 18], "rig": [17, 17], "train": [18, 14]}
	var ok := true
	for t in sizes:
		for k in ["decal_%s_driver_cockpit" % t, "decal_%s_driver_cockpit_idle_1" % t,
				"decal_%s_driver_cockpit_idle_2" % t, "decal_%s_driver_cockpit_idle_3" % t]:
			var r = Atlas.regions.get(k)
			if r == null or int(r[2]) != int(sizes[t][0]) or int(r[3]) != int(sizes[t][1]):
				ok = false
				print("[autotest] driver cab sprite wrong: %s %s" % [k, str(r)])
	_check("driver cab: 4 cab decals + 3 idle frames each at their spec sizes", ok)
	var was_tier := Game.tier()
	var was_tr := Game.trailers()
	var was_tod: float = float(Game.s.tod)
	Dev.set_trailers(0)
	Dev.driver_cab_switch(true)
	for t in ["van", "bus", "rig", "train"]:
		Dev.set_tier(t)
		await wait(0.1)
		_check("driver cab %s: overlay sits on the baked window (%s)" % [t, str(v.driver_cab.position)],
			v.driver_cab.position == Vehicle.DRIVER_CAB[t] and not v.driver_cab.visible)
		var moves := {}
		for kind in ["blink", "lamp", "wheel"]:
			var started := Dev.driver_cab_preview(kind)
			moves[kind] = started and v.driver_cab.visible and int(v.driver_cab.get_meta("frame", 0)) == {"blink": 1, "lamp": 2, "wheel": 3}[kind] 				and v.driver_cab.texture == Atlas.tex("decal_%s_driver_cockpit_idle_%d" % [t, {"blink": 1, "lamp": 2, "wheel": 3}[kind]])
			if kind == "wheel":
				await shot("driver_cab_%s_wheel" % t)
			await wait(0.8)
			moves[kind] = moves[kind] and not v.driver_cab.visible
		_check("driver cab %s: blink / lamp / wheel each show their frame, then the baked look (%s)" % [t, str(moves)],
			not moves.values().has(false))
		for xr in [true, false]:
			v.set_xray(xr)
			for tod in [0.5, 0.0]:
				Game.s.tod = tod
				await wait(0.3)
				await shot("driver_cab_%s_%s_%s" % [t, "cutaway" if xr else "exterior", "day" if tod > 0.0 else "night"])
		v.set_xray(true)
	Game.s.tod = was_tod
	Features.set_override("tune", "vehicle.driver_gap", 1.5)
	var seen := false
	for i in 40:
		await wait(0.1)
		seen = seen or v.driver_cab.visible
	_check("driver cab: moves on its own every few seconds", seen)
	Features.set_override("tune", "vehicle.driver_gap", null)
	Dev.driver_cab_preview("wheel")
	Dev.driver_cab_switch(false)
	await wait(0.1)
	_check("driver cab: switch off = no overlay and no moves (the seated Viktor stays baked)", not v.driver_cab.visible
		and not Dev.driver_cab_preview("blink") and not v.driver_cab.visible)
	Features.set_override("features", "driver_cab", null)
	Dev.set_tier(was_tier)
	Dev.set_trailers(was_tr)
	await wait(0.1)


func _idle_motion_test() -> void:
	var v: Vehicle = main.vehicle
	var was_tier := Game.tier()
	var was_tr := Game.trailers()
	var was_mods: Dictionary = Game.s.mods.duplicate(true)
	var was_w := str(Game.s.get("weather", "clear"))
	Game.s.mods["tracks"] = 0
	Dev.set_tier("rig")
	Dev.set_trailers(0)
	Dev.engine_set("cond", 100.0)
	Dev.engine_set("heat", 40.0)
	await wait(0.3)
	_check("idle motion: the roof flag waves (shells no longer carry it)", v.flag.visible and v.flag.is_playing()
		and v.flag.position == Vehicle.FLAG_POS)
	_check("idle motion: chain on the rear deck (%s)" % str(v.chain.position), v.chain.visible and v.chain.position == Vector2(266, 263))
	_check("idle motion: mudflap behind the rig's rear tyre (%s)" % str(v.mudflap.position), v.mudflap.visible and v.mudflap.position == Vector2(238, 276))
	_check("idle motion: puffs replace the old smoke emitter", not v.smoke.emitting and v.exhaust_burning())
	v.puff_now()
	v.puff_now()
	v.puff_now()
	_check("idle motion: at most two exhaust puffs (%d)" % v.puffs_active(), v.puffs_active() == 2)
	await shot("idle_motion_rig")
	Game.s.mods["tracks"] = 1
	Mods.mods_changed.emit()
	await wait(0.1)
	_check("idle motion: tracks hide the mudflap", not v.mudflap.visible)
	Dev.set_trailers(1)
	await wait(0.2)
	_check("idle motion: with a trailer the chain and mudflap move to its rear (%s, %s)" % [str(v.chain.position), str(v.mudflap.position)],
		v.chain.position == Vector2(266 + 248, 263) and v.mudflap.visible and v.mudflap.position == Vector2(280 + 200, 276))
	Dev.engine_set("cond", 0.0)
	await wait(0.4)
	_check("idle motion: a broken engine makes no puffs", not v.exhaust_burning() and v.puffs_active() == 0)
	Dev.engine_set("cond", 100.0)
	Dev.weather("rain")
	await wait(0.1)
	_check("idle motion: rain runs off the roof", v.drip_now() or v.drip.visible)
	Dev.weather("acid_rain")
	await wait(0.1)
	_check("idle motion: no water drip in acid rain", not v.drip.visible)
	Dev.weather("clear")
	await wait(0.1)
	_check("idle motion: dry = no drip", not v.drip.visible)
	Features.set_override("features", "vehicle_ambience", false)
	await wait(0.2)
	_check("idle motion: switch off = old smoke back, flag still on frame 0, no chain / flap / puffs", v.smoke.emitting
		and v.flag.visible and not v.flag.is_playing() and v.flag.frame == 0 and not v.chain.visible and not v.mudflap.visible and v.puffs_active() == 0)
	Features.set_override("features", "vehicle_ambience", null)
	Dev.set_tier("train")
	Dev.set_trailers(0)
	await wait(0.2)
	_check("idle motion: no mudflap on the train", not v.mudflap.visible)
	Game.s.mods = was_mods
	Dev.set_tier(was_tier)
	Dev.set_trailers(was_tr)
	Dev.weather(was_w)
	Mods.mods_changed.emit()
	await wait(0.2)


## MV-388 phase 4: the eight environment micro sprites are in the atlas at their spec sizes (the living-background
## owner, MV-370 / MV-371, places them; nothing in the game uses them yet)
func _env_micro_test() -> void:
	var specs := {"prop_env_torn_ribbon": [16, 20, 4], "fx_env_puddle_ripple": [24, 6, 4], "prop_env_scrap_can": [16, 8, 4],
		"prop_env_grass_sway": [12, 12, 4], "prop_env_reed_sway": [12, 18, 4], "fx_env_snow_scud": [24, 8, 6],
		"prop_env_loose_cable": [12, 20, 4], "fx_env_swamp_bubble": [12, 8, 4]}
	var ok := true
	for id in specs:
		var sp: Array = specs[id]
		for i in int(sp[2]):
			var r = Atlas.regions.get("%s_%d" % [id, i])
			if r == null or int(r[2]) != int(sp[0]) or int(r[3]) != int(sp[1]):
				ok = false
				print("[autotest] env micro wrong: %s_%d %s" % [id, i, str(r)])
		if Atlas.regions.has("%s_%d" % [id, int(sp[2])]):
			ok = false
	_check("env micro: 8 environment strips in the atlas at their spec sizes and frame counts", ok)


## MV-419: the engine panel's park-to-rest works on a cool engine (it used to end on the next tick), the same button
## sets off again; a rest started hot still ends by itself once cooled
func _engine_rest_test() -> void:
	var e := EngineBay.st()
	var was_heat := float(e.get("heat", 40.0))
	Dev.engine_rest(false)
	Dev.engine_set("heat", 40.0)
	main.hud.open_panel("engine")
	var ep = main.hud.panels.engine
	ep.tab = "status"
	ep.refresh()
	await wait(0.2)
	var btn: Button = ep.find_child("RestButton", true, false)
	_check("engine rest: park button on a cool engine", btn != null and not btn.disabled and btn.text == Loc.t("จอดพักเครื่องตอนนี้"))
	btn.pressed.emit()
	for i in 20:
		EngineBay.tick(0.5, 0.5 / 60.0, false, false)
	await wait(0.2)
	_check("engine rest: a cool engine stays parked (was cancelled on the next tick)", EngineBay.resting()
		and EngineBay.blocked_reason() != "")
	btn = ep.find_child("RestButton", true, false)
	_check("engine rest: the same button now sets off again", btn != null and not btn.disabled and btn.text == Loc.t("ออกเดินทางต่อ"))
	await shot("engine_rest_resume")
	btn.pressed.emit()
	await wait(0.1)
	_check("engine rest: set off", not EngineBay.resting() and EngineBay.blocked_reason() == "")
	Dev.engine_set("heat", 105.0)
	EngineBay.rest_now()
	_check("engine rest: too hot to set off yet", not EngineBay.can_resume() and not EngineBay.resume_now() and EngineBay.resting())
	Dev.engine_set("heat", EngineBay.RESUME_AT - 5.0)
	EngineBay.tick(0.5, 0.5 / 60.0, false, false)
	_check("engine rest: a rest started hot ends by itself once cooled", not EngineBay.resting())
	ep.close()
	Dev.engine_set("heat", was_heat)
	await wait(0.1)


## MV-420: living quarters can't be torn down (or split) when the crew would outnumber the beds left
func _quarters_guard_test() -> void:
	var was_rooms: Array = Game.s.rooms.duplicate(true)
	var was_dw: Array = Game.s.dwellers.duplicate(true)
	# only one finished quarters (Lv2 = 8 beds) on board: pop cap = base 6 + 8
	var free := []
	for i in Game.s.rooms.size():
		if Game.s.rooms[i].type == "quarters":
			Game.s.rooms[i] = {"type": "empty", "level": 1, "job": {}, "build": {}}
		if Game.is_slot_unlocked(i) and Game.s.rooms[i].type == "empty" and not Game.is_annex(i):
			free.append(i)
	var q: int = free[0]
	var q2: int = free[free.size() - 1]
	Game.s.rooms[q] = {"type": "quarters", "level": 2, "job": {}, "build": {}}
	# exactly 8 crew: more than the base 6 beds, fewer than base + this room's 8 (restored afterwards)
	if Game.s.dwellers.size() > Data.BASE_POP_CAP + 2:
		Game.s.dwellers = Game.s.dwellers.slice(0, Data.BASE_POP_CAP + 2)
	while Game.s.dwellers.size() < Data.BASE_POP_CAP + 2:
		Game.recruit_random()
	Game.rooms_changed.emit()
	Game.dwellers_changed.emit()
	var n: int = Game.s.dwellers.size()
	_check("quarters guard: setup %d crew, %d beds" % [n, Game.pop_cap()], n > Data.BASE_POP_CAP and n <= Game.pop_cap())
	_check("quarters guard: tearing down the only quarters is refused (%d beds would be left)" % Game.beds_short(q),
		Game.beds_short(q) == Data.BASE_POP_CAP)
	Game.demolish_room(q)
	_check("quarters guard: demolish_room leaves it standing", Game.s.rooms[q].type == "quarters")
	main.open_closeup(q)
	await wait(0.8)
	var btn: Button = main.hud.room_closeup.find_child("DemolishButton", true, false)
	_check("quarters guard: the close-up's demolish button is disabled with the reason", btn != null and btn.disabled)
	await shot("quarters_guard")
	main.hud.room_closeup.close()
	await wait(0.4)
	_check("quarters guard: keeping every bed (a split that loses none) is fine", Game.beds_short(q, Game.room_beds(q)) == -1)
	Game.s.rooms[q2] = {"type": "quarters", "level": 2, "job": {}, "build": {}}
	_check("quarters guard: with a second quarters it may go", Game.beds_short(q) == -1)
	Game.demolish_room(q)
	_check("quarters guard: demolished once there are beds elsewhere", Game.s.rooms[q].type == "empty")
	var other := -1
	for i in Game.s.rooms.size():
		if Game.s.rooms[i].type == "kitchen":
			other = i
	_check("quarters guard: other rooms are never blocked", other >= 0 and Game.beds_short(other) == -1)
	Game.s.rooms = was_rooms
	Game.s.dwellers = was_dw
	Game.rooms_changed.emit()
	Game.dwellers_changed.emit()
	await wait(0.3)


## MV-423: GameAnalytics over the Collection API, with a fake transport (the autotest never calls the network):
## signing (the API's own test vector), consent + switches, the session, cleaned event ids, map progression, the
## error cap, batching and the resend rules
func _analytics_test() -> void:
	const SANDBOX_GK := "5c6bcb5402204249437fb5a7a80a4959"
	const SANDBOX_SK := "16813a12f718bc5c620f56944e1abc3ea13ccbac"
	_check("analytics: HMAC matches GameAnalytics' test vector",
		Analytics.hmac_auth('{"test": "test"}', SANDBOX_SK) == "slnR8CKJtKtFDaESSrqnqQeUvp5FaVV7d5XHxt50N5A=")
	_check("analytics: no network in test runs without a fake transport", not Analytics.active())
	var sent := []
	var codes := [201]
	Analytics.transport = func(route: String, body: String, auth: String) -> int:
		sent.append({"route": route, "body": body, "auth": auth})
		return int(codes.pop_front()) if not codes.is_empty() else 200
	Analytics.set_keys(SANDBOX_GK, SANDBOX_SK)
	Analytics.queue.clear()
	Analytics.errors_sent = 0
	Analytics._session_id = ""
	var was_tel: bool = bool(Settings.get_value("telemetry"))
	var was_notice: bool = bool(Cloud.meta.get("log_notice", false))
	Settings.set_value("telemetry", true)
	Cloud.meta.log_notice = true
	_check("analytics: active with keys, consent and the switch", Analytics.active() and Analytics.status() == "on")
	Analytics.start_session()
	_check("analytics: a session sends init and queues the user event", sent.size() == 1 and sent[0].route == "init"
		and Analytics.queue.size() == 1 and Analytics.queue[0].category == "user")
	var ev: Dictionary = Analytics.queue[0]
	var re := RegEx.create_from_string("^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$")
	_check("analytics: annotations (v2, uuid session, rest api v2, build)", int(ev.v) == 2 and re.search(str(ev.session_id)) != null
		and ev.sdk_version == "rest api v2" and ev.build == BuildInfo.GAME_VERSION and int(ev.session_num) >= 1)
	_check("analytics: ids keep only GameAnalytics' characters", Analytics.clean_id("RoadEvent:ปล้นรถ #1:a:b:c:d:e", 5) == "RoadEvent:______ _1:a:b:c")
	Analytics.design("Room:Built:kitchen")
	Analytics._on_biome(1, false)
	var cats := Analytics.queue.map(func(e): return str(e.get("event_id", e.category)))
	_check("analytics: design + map progression (%s)" % ", ".join(cats), cats.has("Room:Built:kitchen")
		and cats.has("Complete:Map:" + str(Data.biome(0).id)) and cats.has("Start:Map:" + str(Data.biome(1).id)))
	for i in 15:
		Analytics.error("error", "boom %d" % i)
	_check("analytics: at most 10 errors per launch", Analytics.queue.filter(func(e): return e.category == "error").size() == 10)
	var n := Analytics.queue.size()
	Analytics.flush()
	var last: Dictionary = sent[-1]
	var arr = JSON.parse_string(last.body)
	_check("analytics: one signed batch to /events", last.route == "events" and arr is Array and (arr as Array).size() == n
		and last.auth == Analytics.hmac_auth(last.body, SANDBOX_SK) and Analytics.queue.is_empty() and Analytics.sent_total >= n)
	codes.assign([413])
	Analytics.design("Test:Again")
	Analytics.flush()
	_check("analytics: 413 keeps the batch and halves the next one", Analytics.queue.size() == 1 and Analytics._batch_max == Analytics.BATCH_MAX / 2)
	codes.assign([400])
	Analytics.flush()
	_check("analytics: 400 drops it (never resend bad data)", Analytics.queue.is_empty() and Analytics.last_error.begins_with("400"))
	codes.assign([502])
	Analytics.design("Test:Down")
	Analytics.flush()
	_check("analytics: 502 / 5xx keeps the batch (signer or GameAnalytics down)", Analytics.queue.size() == 1 and Analytics.last_error == "server 502")
	codes.assign([200])
	Analytics.flush()
	# offline: nothing is lost, even across a reload
	codes.assign([0])
	Analytics.design("Offline:One")
	Analytics.design("Offline:Two")
	Analytics.flush()
	var stored = JSON.parse_string(Save.read_key(Analytics.QUEUE_KEY, Analytics.QUEUE_PATH))
	_check("analytics: offline = the batch stays queued and is saved in the browser", Analytics.queue.size() == 2
		and stored is Array and (stored as Array).size() == 2 and Analytics.last_error == "offline")
	Analytics.queue.clear()
	Analytics._load_queue()
	_check("analytics: a reload brings the saved queue back with whole numbers", Analytics.queue.size() == 2
		and typeof(Analytics.queue[0].client_ts) == TYPE_INT and typeof(Analytics.queue[0].session_num) == TYPE_INT
		and str(Analytics.queue[1].event_id) == "Offline:Two")
	Analytics.flush()
	stored = JSON.parse_string(Save.read_key(Analytics.QUEUE_KEY, Analytics.QUEUE_PATH))
	_check("analytics: back online they go up and leave the saved queue", Analytics.queue.is_empty() and stored is Array
		and (stored as Array).is_empty() and str(JSON.parse_string(sent[-1].body)[1].event_id) == "Offline:Two")
	# full queue: the oldest session goes first, as a whole
	var fill := []
	for i in Analytics.QUEUE_MAX - 50:
		fill.append({"category": "design", "event_id": "Old:%d" % i, "session_id": "old-session"})
	for i in 100:
		fill.append({"category": "design", "event_id": "New:%d" % i, "session_id": "new-session"})
	Analytics.queue = fill
	Analytics._trim()
	_check("analytics: over the cap the oldest session is dropped whole (%d left)" % Analytics.queue.size(),
		Analytics.queue.size() == 100 and str(Analytics.queue[0].session_id) == "new-session")
	Analytics.clear_queue()
	Analytics.end_session()
	_check("analytics: session_end with its length", JSON.parse_string(sent[-1].body)[0].category == "session_end"
		and int(JSON.parse_string(sent[-1].body)[0].length) >= 0)
	Analytics.queue = [{"category": "design", "event_id": "Waiting:One", "session_id": "x"}]
	Analytics._persist()
	Settings.set_value("telemetry", false)
	Analytics._process(0.1)
	Analytics.design("Test:OptedOut")
	_check("analytics: player opted out = nothing queued, the saved queue is cleared", Analytics.queue.is_empty()
		and Save.read_key(Analytics.QUEUE_KEY, Analytics.QUEUE_PATH) == "[]" and Analytics.status() == "player opted out")
	Settings.set_value("telemetry", true)
	Features.set_override("features", "game_analytics", false)
	Analytics.design("Test:SwitchOff")
	_check("analytics: switch off = nothing queued", Analytics.queue.is_empty())
	Features.set_override("features", "game_analytics", null)
	# MV-426: no secret in the build: unsigned, through the signing function on the game's own site
	Analytics.set_keys(SANDBOX_GK, "")
	Analytics.design("Test:Proxy")
	Analytics.flush()
	_check("analytics: without a secret the batch goes unsigned via /api/ga", Analytics.configured() and sent[-1].auth == ""
		and Analytics.mode() == "via /api/ga" and Analytics.queue.is_empty())
	Analytics.set_keys("", "")
	_check("analytics: no keys for this environment = off", not Analytics.active() and Analytics.status().begins_with("no keys"))
	Analytics.transport = Callable()
	Analytics.clear_queue()
	Analytics._batch_max = Analytics.BATCH_MAX
	Analytics._load_keys()
	Analytics._session_id = ""
	Analytics.queue.clear()
	Analytics.errors_sent = 0
	Settings.set_value("telemetry", was_tel)
	Cloud.meta.log_notice = was_notice


## MV-424: the server outbox: backoff with jitter and its cap, Retry-After, one request at a time by priority, and a
## held lane pausing Cloud's automatic retry / upload / last try on hide and the log batches (tools/cloud_fake.gd)
func _outbox_test() -> void:
	const L := "outbox-test"
	var SB := Outbox.SUPABASE
	Outbox.rng = func() -> float: return 0.0
	_check("outbox: first hold is half the base (jitter floor)", is_equal_approx(Outbox.backoff(1), Outbox.BASE_SEC * 0.5))
	Outbox.rng = func() -> float: return 1.0
	_check("outbox: doubles per failure", is_equal_approx(Outbox.backoff(3), Outbox.BASE_SEC * 4.0))
	_check("outbox: capped at max", is_equal_approx(Outbox.backoff(30), Outbox.MAX_SEC))
	Outbox.rng = Callable()
	var spread := {}
	for i in 20:
		spread[snappedf(Outbox.backoff(2), 0.01)] = true
	_check("outbox: jitter spreads the holds (%d different of 20)" % spread.size(), spread.size() >= 10
		and spread.keys().all(func(v): return v >= Outbox.BASE_SEC and v <= Outbox.BASE_SEC * 2.0))
	_check("outbox: Retry-After in seconds, a date is ignored", Outbox.retry_after(PackedStringArray(["Content-Type: x", "Retry-After: 120"])) == 120.0
		and Outbox.retry_after(PackedStringArray(["retry-after: Wed, 21 Oct 2026 07:28:00 GMT"])) == 0.0)
	Outbox.report(L, 503)
	_check("outbox: 503 holds the lane", not Outbox.open(L) and Outbox.hold_left(L) > 0.0 and int(Outbox.lane(L).fails) == 1)
	Outbox.report(L, 429, 400.0)
	_check("outbox: Retry-After wins when longer", Outbox.hold_left(L) > 390.0 and int(Outbox.lane(L).fails) == 2)
	Outbox.report(L, 404)
	_check("outbox: any other answer (404) clears it", Outbox.open(L) and int(Outbox.lane(L).fails) == 0)
	Outbox.report(L, 0)
	Features.set_override("features", "server_outbox", false)
	_check("outbox: switch off = never held", Outbox.open(L))
	Features.set_override("features", "server_outbox", null)
	Outbox.reset(L)
	# one request at a time; the waiting ones by priority
	var order := []
	await Outbox.acquire(L, Outbox.Prio.SAVE)
	var job := func(p: int, tag: String) -> void:
		await Outbox.acquire(L, p)
		order.append(tag)
		await get_tree().process_frame
		Outbox.release(L)
	job.call(Outbox.Prio.LOGS, "logs")
	job.call(Outbox.Prio.SAVE, "save")
	job.call(Outbox.Prio.AUTH, "auth")
	_check("outbox: a busy lane makes the others wait", order.is_empty() and (Outbox.lane(L).waiting as Array).size() == 3)
	Outbox.release(L)
	await wait(0.3)
	_check("outbox: then one at a time: sign-in, save, logs (%s)" % ", ".join(order), order == ["auth", "save", "logs"]
		and not Outbox.lane(L).busy and (Outbox.lane(L).waiting as Array).is_empty())
	# the real lane, against the fake server
	var fake = load("res://tools/cloud_fake.gd").new()
	Cloud.session = {}
	Cloud.meta = {"rev": 0, "dirty": false, "wiped": false, "device_id": "", "oauth": {}, "chose": "guest"}
	Cloud._save_session()
	Cloud._save_meta()
	Settings.set_value("telemetry", true)
	await Cloud.start_for_test(fake)
	Outbox.reset(SB)
	_check("outbox: cloud up, lane open", Cloud.state == Cloud.State.OK and Outbox.open(SB))
	fake.online = false
	Cloud.meta.dirty = true
	await Cloud.sync()
	_check("outbox: server gone = cloud offline and the lane held", Cloud.state == Cloud.State.OFFLINE and not Outbox.open(SB))
	fake.online = true
	var n: int = fake.calls.size()
	Cloud._t = 0.0
	Cloud._process(Cloud.RETRY_SEC * 2.0)
	await wait(0.2)
	_check("outbox: held = no automatic retry, even after 60 s", fake.calls.size() == n and Cloud.state == Cloud.State.OFFLINE)
	Outbox.lane(SB).hold_until = 0     # the hold ran out
	Cloud._process(Cloud.RETRY_SEC * 0.5 + 0.1)
	await wait(0.5)
	_check("outbox: hold over = it retries and recovers", fake.calls.size() > n and Cloud.state == Cloud.State.OK
		and int(Outbox.lane(SB).fails) == 0)
	# the save: no upload round and no last try on hide while held, but "sync now" still goes
	Cloud.meta.dirty = true
	Outbox.report(SB, 503)
	n = fake.calls.size()
	Cloud._process(Cloud.UPLOAD_SEC + 1.0)
	Cloud._on_flush()
	await wait(0.2)
	_check("outbox: held = no upload round, no last try on hide", fake.calls.size() == n)
	await Cloud.sync()
	_check("outbox: what the player asks for still goes and opens the lane", fake.calls.size() > n and Outbox.open(SB)
		and Cloud.state == Cloud.State.OK)
	# player logs wait in the trace while held
	Cloud.meta.log_notice = true
	Trace.rec("meta", "outbox log wait")
	Outbox.report(SB, 503)
	var lc: int = fake.log_calls
	Telemetry._t = 0.0
	Telemetry._process(Features.num("logs.flush_sec", Telemetry.FLUSH_SEC) + 1.0)
	Telemetry._on_hide()
	await wait(0.2)
	_check("outbox: held = log batches wait in the trace", fake.log_calls == lc and not Telemetry.pending().is_empty())
	Outbox.reset(SB)
	Telemetry._process(0.1)
	await wait(0.3)
	_check("outbox: open again = the batch goes", fake.log_calls > lc)
	Outbox.rng = Callable()
	Outbox._lanes.erase(L)
	Outbox.reset(SB)
	Save.wipe()

## MV-427: situational lines: every moment has lines in the right voice, the right person says them, cooldown / gap /
## bubble cap keep a fight readable, nothing over an event pop-up or with the switch off, "raid won" only after a raid
## nobody lost, and a badly hurt hero speaks up
func _barks_test() -> void:
	_no_events()
	if Game.active_event != "":
		Game.cancel_event()
		main.hud.event_popup.close()
	var ch: Chatter = main.chatter
	var rng := RandomNumberGenerator.new()
	rng.seed = 427
	var missing: Array = ch.BARK_RULES.keys().filter(func(k): return k != "weather" and (Lore.BARKS.get(k, []) as Array).is_empty())
	_check("barks: every moment has lines (%s)" % ", ".join(missing), missing.is_empty())
	var stray := []
	for bio in Lore.BARKS_PERSONAL:
		for k in Lore.BARKS_PERSONAL[bio]:
			if not Lore.BARKS.has(k):
				stray.append("%s.%s" % [bio, k])
	_check("barks: personal lines only for real moments (%s)" % ", ".join(stray), stray.is_empty() and Lore.BARKS_PERSONAL.keys().all(func(b): return Lore.BIOS.has(b)))
	var mark := {"name": "จ่ามาร์ค", "id": -99}
	var own := false
	for i in 30:
		own = own or (Lore.BARKS_PERSONAL.mark.raid_start as Array).has(Lore.pick_bark("raid_start", mark, rng))
	_check("barks: a named character uses their own voice", own and Lore.bio_key(mark) == "mark")
	_check("barks: weather change uses the weather lines", (Lore.LINES_WEATHER.rain as Array).has(Lore.pick_bark("weather:rain", {}, rng))
		and Lore.pick_bark("no_such_moment", {}, rng) == "")
	# live, through the real chatter layer
	var reset := func():
		ch._cool = {}
		ch._bark_gap = 0.0
		for b in ch._bubbles.duplicate():
			ch._free_bubble(b)
	reset.call()
	var cands: Array = ch._candidates()
	_check("barks: someone in view to talk (%d)" % cands.size(), not cands.is_empty())
	var who: Array = cands[0]
	_check("barks: the named person says it", ch.bark("hurt", int(who[0])) and ch._bubbles.size() == 1 and ch._bubbles[0].actor == who[1]
		and ch.last_bark.begins_with("hurt|"))
	ch._t = 999.0
	ch.bark("site", -1, "", true)
	_check("barks: a second line goes to someone else, the first stays", ch._bubbles.size() == (2 if cands.size() > 1 else 1)
		and ch._bubbles[0].actor == who[1])
	await wait(0.4)     # bubbles fade in / out over 0.15-0.2 s
	var r0 := Rect2((ch._bubbles[0].node as Node2D).position, ch._bubbles[0].size)
	_check("barks: two bubbles never cover each other", ch._bubbles.size() < 2
		or not r0.intersects(Rect2((ch._bubbles[1].node as Node2D).position, ch._bubbles[1].size)))
	await shot("barks_hurt")
	ch._t = 5.0
	ch._bark_gap = 0.0
	_check("barks: same moment again waits for the cooldown", not ch.bark("hurt", int(who[0])))
	ch._bark_gap = 0.0
	ch._cool = {}
	ch.bark("site")
	ch._bark_gap = 0.0
	ch.bark("built")
	ch._bark_gap = 0.0
	ch.bark("new_area")
	ch._bark_gap = 0.0
	ch.bark("level_up")
	_check("barks: never more than %d bubbles" % ch.BARK_MAX, ch._bubbles.size() <= ch.BARK_MAX)
	reset.call()
	_check("barks: a gap of %.1f s between any two" % ch.BARK_GAP, ch.bark("site") and not ch.bark("built"))
	reset.call()
	Game.active_event = "cache"
	_check("barks: quiet while an event pop-up is open", not ch.bark("site", -1, "", true))
	Game.active_event = ""
	Features.set_override("features", "barks", false)
	_check("barks: switch off = no barks", not ch.bark("site", -1, "", true))
	Features.set_override("features", "barks", null)
	# raid won only when nobody was wiped out
	reset.call()
	ch._on_phase("raid")
	reset.call()
	ch._on_phase("quiet")
	var won := ch.last_bark.begins_with("raid_won|")
	reset.call()
	ch.last_bark = ""
	ch._on_phase("raid")
	ch._on_wiped()
	reset.call()
	ch.last_bark = ""
	ch._on_phase("quiet")
	_check("barks: 'raid won' after a clean raid, not after a wipe", won and not ch.last_bark.begins_with("raid_won|"))
	# a badly hurt hero speaks up (the hit carries the hero's slot)
	reset.call()
	var keep_heroes: Array = Combat.heroes.duplicate(true)
	Combat.heroes = [{"slot": 0, "did": int(who[0]), "hp": 80.0, "max": 100.0, "alive": true}]
	ch.last_bark = ""
	ch._on_hit("hero", 0, 5.0, false)
	var calm := ch.last_bark == ""
	Combat.heroes[0].hp = 20.0
	ch._on_hit("hero", 0, 5.0, false)
	_check("barks: a hero below 35% HP says a hurt line, a scratch doesn't", calm and ch.last_bark.begins_with("hurt|"))
	Combat.heroes = keep_heroes
	# GOD
	reset.call()
	_check("barks: GOD 'say it now' works for every moment", Lore.BARKS.keys().all(func(k):
		ch._cool = {}
		ch._bark_gap = 0.0
		return Dev.bark(k) == k))
	reset.call()


## MV-243: "เร่งเครื่องหนี" is closed (with the reason) whenever the vehicle can't pull away, for every reason
## blocked_reason() knows; resolve_event refuses it, a time-out fights instead, and with nobody aboard the fight
## becomes "brace inside" so the event can always end
func _flee_guard_test() -> void:
	_no_events()
	var ep = main.hud.event_popup
	if Game.active_event != "":
		Game.cancel_event()
		ep.close()
	var keep := {"stall": float(Game.s.stall), "hull": float(Game.s.hull), "power": float(Game.s.res.power),
		"wrecked": Game.s.get("wrecked", false), "away": Game.s.dwellers.map(func(d): return float(d.away_until))}
	Game.s.stall = 0.0
	Game.s.hull = maxf(50.0, float(Game.s.hull))
	Game.s.res.power = maxf(50.0, float(Game.s.res.power))
	var fi := _qte_index("wolves", "flee")
	var fight := _qte_index("wolves", "fight")
	var flee: Dictionary = Data.EVENTS.wolves.choices[fi]
	_check("flee guard: free road = flee open (%s)" % Game.blocked_reason(), Game.drive_block() == "" and Game.choice_block(flee) == ""
		and Game.event_auto_choice("wolves") == fi)
	# every reason the vehicle can't move closes it, and a time-out picks the fight instead
	var cases := {
		"waiting out a stop": func(on: bool): Game.s.stall = 45.0 if on else 0.0,
		"no power": func(on: bool): Game.s.res.power = 0.0 if on else maxf(50.0, float(keep.power)),
		"hull broken": func(on: bool): Game.s.hull = 0.0 if on else maxf(50.0, float(keep.hull)),
		"engine resting": func(on: bool):
			EngineBay.st().resting = on
			EngineBay.st().rest_hold = false,
		"wrecked": func(on: bool): Game.s.wrecked = on,
	}
	for why in cases:
		cases[why].call(true)
		var blk := Game.choice_block(flee)
		_check("flee guard: %s -> flee closed (%s)" % [why, blk], blk.begins_with("รถออกตัวไม่ได้") and Game.drive_block() != ""
			and Game.event_auto_choice("wolves") == fight)
		cases[why].call(false)
	var site: String = Expedition.SITES.keys()[0]
	Expedition.arrive(site)
	_check("flee guard: parked at a site -> flee closed", Game.choice_block(flee) != "" and Expedition.at_site() == site)
	Expedition.skip_site()
	_check("flee guard: open again once it can drive", Game.choice_block(flee) == "" and Game.event_auto_choice("wolves") == fi)
	_check("flee guard: the stray dog's 'drive away' is no longer called flee", not Data.EVENTS.stray_dog.choices.any(func(c): return str(c.th) == "เร่งเครื่องหนี"))
	# the game refuses it, not only the button
	Game.s.stall = 45.0
	Game.trigger_event("wolves")
	await wait(0.3)
	var p0 := float(Game.s.res.power)
	var r: Dictionary = Game.resolve_event("wolves", fi, [])
	_check("flee guard: resolve refuses flee, the event stays, no power spent", not r.ok and str(r.text).begins_with("รถออกตัวไม่ได้")
		and Game.active_event == "wolves" and is_equal_approx(float(Game.s.res.power), p0))
	# the pop-up shows it closed with the reason
	ep.refresh()
	await wait(0.1)
	var btns: Array = ep.find_children("*", "", true, false).filter(func(n): return n is ChoiceButton)
	var texts: Array = ep.find_children("*", "Label", true, false).map(func(l): return str(l.text))
	_check("flee guard: pop-up button closed, reason shown", btns.size() == Data.EVENTS.wolves.choices.size() and bool(btns[fi].disabled)
		and not bool(btns[fight].disabled) and texts.any(func(t): return t.contains("รถออกตัวไม่ได้")))
	await shot("flee_guard_closed")
	# a time-out sends the crew to fight
	Settings.set_value("event_timer", "normal")
	ep.decide_total = 2.0
	ep.decide_left = 0.1
	ep.since_input = 0.0
	await wait(0.5)
	_check("flee guard: time-out fights instead of fleeing", Game.active_event == ""
		and Trace.entries.any(func(e): return str(e.msg).begins_with("time out wolves -> #%d fight" % fight)))
	ep.close()
	Settings.set_value("event_timer", "off")
	await wait(0.2)
	# nobody aboard: the fight is "brace inside", the hull takes it, the event ends
	for d in Game.s.dwellers:
		d.away_until = 9e9
	Game.s.hull = 100.0
	Game.trigger_event("wolves")
	await wait(0.3)
	ep._choice = fight
	ep.refresh()
	await wait(0.1)
	var brace: Array = ep.find_children("*", "Button", true, false).filter(func(b): return str(b.text).contains("ปิดประตูตั้งรับ"))
	_check("flee guard: nobody aboard -> 'brace' button, not a dead 'send team'", Game.nobody_aboard() and brace.size() == 1 and not brace[0].disabled)
	await shot("flee_guard_brace")
	r = Game.resolve_event("wolves", fight, [])
	_check("flee guard: bracing ends the event and costs hull", Game.active_event == "" and float(Game.s.hull) < 100.0
		and str(r.text).contains("ปิดประตูตั้งรับ"))
	ep.close()
	await wait(0.2)
	for i in Game.s.dwellers.size():
		Game.s.dwellers[i].away_until = keep.away[i]
	# switch off = the old behaviour
	Features.set_override("features", "flee_guard", false)
	Game.s.stall = 45.0
	_check("flee guard: switch off = flee always open", Game.choice_block(flee) == "" and Game.event_auto_choice("wolves") == fi)
	Features.set_override("features", "flee_guard", null)
	Game.s.stall = keep.stall
	Game.s.hull = keep.hull
	Game.s.res.power = keep.power
	Game.s.wrecked = keep.wrecked
	Game.dwellers_changed.emit()
	Game.travel_changed.emit()


## MV-244: a stranger who turns up while the vehicle drives flags it down: it parks, the door window opens by itself
## (once), "drive past" leaves them and lets it go, as does any other answer or them giving up; never when it was
## already parked, during offline catch-up, or with the switch off
func _flagged_test() -> void:
	_no_events()
	if main.hud.confirmation.is_open:
		main.hud.confirmation.close()     # an earlier group's confirmation would (rightly) keep the door window shut
	if Game.active_event != "":
		Game.cancel_event()
		main.hud.event_popup.close()
	for k in main.hud.panels:
		if main.hud.panels[k].is_open:
			main.hud.panels[k].close()
	var keep_q: Array = Inspection.queue().duplicate(true)
	var keep_trav: bool = bool(Game.s.traveling)
	var keep_stall := float(Game.s.stall)
	Inspection.queue().clear()
	Game.s.traveling = true
	Game.s.stall = 0.0
	Game.s.hull = maxf(50.0, float(Game.s.hull))
	Game.s.res.power = maxf(50.0, float(Game.s.res.power))
	_check("flagged: road clear to start (%s)" % Game.blocked_reason(), Game.blocked_reason() == "")
	var c := Inspection.queue_candidate("test", "rare", "human")
	_check("flagged: a stranger while driving flags it down", bool(c.get("halt", false)) and Inspection.halting()
		and Game.blocked_reason() == "จอดรับคนแปลกหน้า" and not Game.is_moving() and Game.speed_factor() == 0.0)
	await wait(0.6)
	var door = main.hud.panels.door
	_check("flagged: the door window opens by itself (modal %s, confirm %s, event %s, encounter %s, title %s)" % [main.hud.any_modal_open(),
		main.hud.confirmation.is_open, main.hud.event_popup.is_open, main.hud.encounter_popup.is_open, main.hud.title_screen.visible], door.is_open)
	var past: Array = door.find_children("*", "Button", true, false).filter(func(b): return str(b.text).contains("ขับผ่าน"))
	_check("flagged: the window offers 'drive past'", past.size() == 1)
	await shot("flagged_door")
	var passed0 := int(Inspection.st().stats.get("passed", 0))
	past[0].pressed.emit()
	await wait(0.2)
	_check("flagged: drive past asks first (MV-422 confirmation), nothing happens yet", main.hud.confirmation.is_open
		and Inspection.halting() and int(Inspection.st().stats.get("passed", 0)) == passed0)
	main.hud.confirmation.confirm_button.pressed.emit()
	await wait(0.2)
	_check("flagged: drive past leaves them and the vehicle goes", Inspection.queue().is_empty() and not Inspection.halting()
		and Game.blocked_reason() == "" and int(Inspection.st().stats.passed) == passed0 + 1)
	door.close()
	await wait(0.2)
	# closing the window doesn't make it pop up again for the same stranger
	c = Inspection.queue_candidate("test", "rare", "human")
	await wait(0.6)
	door.close()
	await wait(0.6)
	_check("flagged: opens once per stranger, not again after closing", not door.is_open and Inspection.halting())
	Inspection.refuse(c)
	_check("flagged: turning them away lets it go", not Inspection.halting() and Game.blocked_reason() == "")
	c = Inspection.queue_candidate("test", "rare", "human")
	c.wait = 0.01
	Inspection.tick(0.1, false)
	_check("flagged: giving up lets it go", Inspection.queue().is_empty() and not Inspection.halting())
	await wait(0.3)
	for k in main.hud.panels:
		if main.hud.panels[k].is_open:
			main.hud.panels[k].close()
	# no stop: already parked, offline catch-up, switch off
	Game.s.traveling = false
	c = Inspection.queue_candidate("test", "rare", "human")
	_check("flagged: already parked = just knocks", not bool(c.halt) and not Inspection.halting())
	Inspection.queue().clear()
	Game.s.traveling = true
	Game.sim_offline = true
	c = Inspection.queue_candidate("test", "rare", "human")
	Game.sim_offline = false
	_check("flagged: offline catch-up never parks the vehicle", not bool(c.halt) and Game.blocked_reason() == "")
	Inspection.queue().clear()
	Features.set_override("features", "stop_for_strangers", false)
	c = Inspection.queue_candidate("test", "rare", "human")
	_check("flagged: switch off = drives on as before", not bool(c.halt) and not Inspection.halting() and Game.blocked_reason() == "")
	Features.set_override("features", "stop_for_strangers", null)
	await wait(0.6)
	for k in main.hud.panels:
		if main.hud.panels[k].is_open:
			main.hud.panels[k].close()
	Inspection.queue().clear()
	for q in keep_q:
		Inspection.queue().append(q)
	Game.s.traveling = keep_trav
	Game.s.stall = keep_stall
	Inspection.queue_changed.emit()


## MV-429: room expansion foundation, with a stand-in room (radio art + the weld strip) since the foundation ships no
## real room: registry and build menu, saved namespace, jobs (pay once, pause dark / building, freeze when off, claim
## once, JSON float ids, demolition), and the shared RoomAnim (rest / active / dark / paused / hidden / switches / GOD)
func _rooms_x_test() -> void:
	_no_events()
	if Game.active_event != "":
		Game.cancel_event()
		main.hud.event_popup.close()
	var regs_ok := Data.buildable() == Data.BUILDABLE + RoomX.buildable()
	for t in RoomX.DEFS:
		regs_ok = regs_ok and Atlas.has(RoomX.art_key(t)) and not Data.BUILDABLE.has(t) and not Data.MERGEABLE.has(t)
		for sp in RoomX.anims(t):
			for f in int(sp.count):
				regs_ok = regs_ok and Atlas.has("%s_%d" % [sp.prefix, f])
	_check("rooms_x: every registered room (%d) has its art and strips, single-cell, after the original ten" % RoomX.DEFS.size(), regs_ok)
	var keep_res: Dictionary = Game.s.res.duplicate(true)
	var keep_rooms: Array = Game.s.rooms.duplicate(true)
	Game.s.erase("rx")
	var before: String = JSON.stringify(Game.s.res)
	RoomX.st()
	_check("rooms_x: an old save gets the namespace once, nothing else changes", Game.s.rx is Dictionary and int(Game.s.rx.v) == RoomX.VERSION
		and JSON.stringify(Game.s.res) == before and RoomX.jobs().is_empty())
	RoomX.extra["rx_test"] = {"th": "ห้องทดสอบ", "en": "TEST ROOM", "cost": 50, "unlock": 1, "stat": "int", "produce": {}, "power": 0.2,
		"effect_th": "ทดสอบ", "effect_en": "TEST", "recipes": [], "art": "room_radio",
		"anims": [{"prefix": "fx_weld", "count": 4, "fps": 8.0, "loop": true, "rest": 0, "x": 20, "y": 20, "active": "job"}]}
	_check("rooms_x: a registered room joins the build menu", Data.buildable().has("rx_test") and Data.room_def("rx_test").en == "TEST ROOM"
		and Data.room_art("rx_test") == "room_radio" and Data.room_art("kitchen") == "room_kitchen")
	Features.set_override("features", "rooms_expansion", false)
	_check("rooms_x: switch off = not offered", not Data.buildable().has("rx_test") and Data.buildable() == Data.BUILDABLE)
	Features.set_override("features", "rooms_expansion", null)
	# the full run reaches here with every slot built: free one single-cell room (all rooms are restored at the end)
	var has_empty := false
	for i in Game.s.rooms.size():
		has_empty = has_empty or (Game.is_slot_unlocked(i) and str(Game.s.rooms[i].type) == "empty" and not Game.is_annex(i))
	if not has_empty:
		for i in Game.s.rooms.size():
			if Game.is_slot_unlocked(i) and not Game.is_annex(i) and Game.room_cells(i).size() == 1 and str(Game.s.rooms[i].type) != "engine":
				Game.s.rooms[i] = {"type": "empty", "level": 1, "job": {}}
				break
	var slot := Dev.rx_build("rx_test")
	await wait(0.3)
	_check("rooms_x: built in an empty slot (%d)" % slot, slot >= 0 and str(Game.room(slot).type) == "rx_test" and not Game.is_constructing(slot))
	if slot < 0:
		RoomX.extra.erase("rx_test")
		Game.s.rooms = keep_rooms
		Game.rooms_changed.emit()
		return
	var rv = main.vehicle.room_views.filter(func(v): return v.slot == slot)[0]
	_check("rooms_x: the room shows its art and one animation strip", rv.anims.size() == 1 and rv.interior.texture == Atlas.tex("room_radio"))
	var anim: RoomAnim = rv.anims[0]
	await wait(0.4)
	_check("rooms_x: idle room holds the rest frame", anim.cur_frame == 0)
	# jobs: pay once, one per room
	Game.s.res.power = maxf(80.0, float(Game.s.res.power))
	Game.s.res.scrap = 100.0
	var j := RoomX.start_job(slot, "test", 10.0, {"scrap": 30})
	var again := RoomX.start_job(slot, "test", 10.0, {"scrap": 30})
	_check("rooms_x: a job starts and pays once; a second one is refused", not j.is_empty() and again.is_empty()
		and is_equal_approx(float(Game.s.res.scrap), 70.0) and RoomX.start_block(slot) != "")
	_check("rooms_x: no job in a room that isn't an expansion room", RoomX.start_job(0 if slot != 0 else 1, "x", 5.0).is_empty())
	RoomX.tick(4.0, false)
	_check("rooms_x: the clock runs", is_equal_approx(float(j.left), 6.0) and is_equal_approx(RoomX.progress(j), 0.4))
	await wait(0.6)
	_check("rooms_x: a busy room animates (frame %d)" % anim.cur_frame, anim.cur_frame != 0 or anim._t > 0.0)
	await shot("rooms_x_active")
	# dark room: paused, animation at rest
	var pw := float(Game.s.res.power)
	Game.s.res.power = 0.0
	var l0 := float(j.left)        # the real game clock keeps ticking jobs between checks: compare from here
	RoomX.tick(2.0, false)
	await wait(0.2)
	_check("rooms_x: a dark room pauses the job and the animation", is_equal_approx(float(j.left), l0) and RoomX.paused_why(j) == "dark" and anim.cur_frame == 0)
	Game.s.res.power = pw
	# switch off: frozen, no catch-up later
	Features.set_override("features", "rooms_expansion", false)
	l0 = float(j.left)
	RoomX.tick(3.0, false)
	await wait(0.2)
	_check("rooms_x: switch off freezes the job and holds the rest frame", is_equal_approx(float(j.left), l0) and anim.cur_frame == 0)
	Features.set_override("features", "rooms_expansion", null)
	_check("rooms_x: switched back on: no hidden catch-up", is_equal_approx(float(j.left), l0))
	Features.set_override("features", "room_ambience", false)
	await wait(0.3)
	_check("rooms_x: room_ambience off holds the rest frame", anim.cur_frame == 0)
	Features.set_override("features", "room_ambience", null)
	# paused game / hidden room: the animation clock stops
	await wait(0.3)
	var t0 := anim._t
	get_tree().paused = true
	await get_tree().create_timer(0.3, true).timeout
	var paused_ok := is_equal_approx(anim._t, t0)
	get_tree().paused = false
	rv.visible = false
	t0 = anim._t
	await wait(0.3)
	var hidden_ok := is_equal_approx(anim._t, t0)
	rv.visible = true
	_check("rooms_x: the animation clock stops while paused and while hidden", paused_ok and hidden_ok)
	# GOD preview + frame step
	Dev.rx_anim_preview("rest")
	await wait(0.2)
	var rest_ok := anim.cur_frame == 0
	Dev.rx_anim_preview("active")
	Dev.rx_anim_step()
	var f1 := anim.cur_frame
	Dev.rx_anim_step()
	_check("rooms_x: GOD rest / active preview and frame step", rest_ok and anim.cur_frame == (f1 + 1) % 4)
	Dev.rx_anim_preview("")
	# finish + claim exactly once, after a JSON round trip (ids come back as floats)
	RoomX.tick(10.0, false)
	_check("rooms_x: the job finishes and waits to be claimed", bool(j.done) and not bool(j.claimed) and RoomX.claim(int(j.id) + 999).is_empty())
	Game.s.rx = JSON.parse_string(JSON.stringify(Game.s.rx))
	var claimed := [0]
	var cb := func(_j): claimed[0] += 1
	RoomX.job_claimed.connect(cb)
	var c1 := RoomX.claim(int(j.id))
	var c2 := RoomX.claim(int(j.id))
	RoomX.job_claimed.disconnect(cb)
	_check("rooms_x: claimed once after a reload, a repeated tap gets nothing", not c1.is_empty() and c2.is_empty() and claimed[0] == 1
		and RoomX.job_in(slot).is_empty())
	# demolition drops a running job, no refund, no reward
	var j2 := RoomX.start_job(slot, "test", 30.0, {"scrap": 10})
	var scrap_after := float(Game.s.res.scrap)
	var dropped := [""]
	var dcb := func(_j, why): dropped[0] = why
	RoomX.job_dropped.connect(dcb)
	Game.s.rooms[slot] = {"type": "empty", "level": 1, "job": {}}
	Game.rooms_changed.emit()
	RoomX.tick(1.0, false)
	RoomX.job_dropped.disconnect(dcb)
	_check("rooms_x: demolishing the room drops its job (no refund)", not j2.is_empty() and RoomX.jobs().is_empty() and dropped[0] == "room gone"
		and is_equal_approx(float(Game.s.res.scrap), scrap_after))
	await wait(0.3)
	_check("rooms_x: the strip goes with the room", rv.anims.is_empty())
	RoomX.extra.erase("rx_test")
	Game.s.rooms = keep_rooms
	Game.s.res = keep_res
	Game.rooms_changed.emit()
	Game.resources_changed.emit()
	await wait(0.2)


## MV-430 Salvagers' Saloon (+ MV-440 background, MV-441 steam): art in the atlas, build, seat two diners and pay
## once, steam only while they eat (rest when dark / off), the cooldown shared by two Saloons, a diner moved away mid-
## meal gets nothing, everyone goes back to work, claim once after a JSON reload (happiness capped, one bond, the
## conversation), demolition sends the diners back without a reward, the close-up buttons and GOD.
func _saloon_test() -> void:
	_no_events()
	if Game.active_event != "":
		Game.cancel_event()
		main.hud.event_popup.close()
	var keep_res: Dictionary = Game.s.res.duplicate(true)
	var keep_rooms: Array = Game.s.rooms.duplicate(true)
	var keep_dw: Array = Game.s.dwellers.duplicate(true)
	var keep_squad: Array = (Game.s.get("squad", []) as Array).duplicate()
	var keep_rx = (Game.s.rx as Dictionary).duplicate(true) if Game.s.get("rx") is Dictionary else null
	# --- art: 64x52 background + four 6x8 steam frames in the spec palette, frame 0 empty
	var sheet: Image = Atlas.sheet.get_image()
	if sheet.is_compressed():
		sheet.decompress()
	var bg: Array = Atlas.regions.get("room_salvagers_saloon", [])
	_check("saloon: room_salvagers_saloon is 64x52 in the atlas", bg.size() == 4 and int(bg[2]) == 64 and int(bg[3]) == 52)
	var pal := [Color("3a3a3e"), Color("54544e"), Color("6e6450"), Color("908670")]
	var frames_ok := true
	var counts := []
	for f in 4:
		var r: Array = Atlas.regions.get("fx_room_saloon_steam_%d" % f, [])
		if r.size() != 4 or int(r[2]) != 6 or int(r[3]) != 8:
			frames_ok = false
			continue
		var n := 0
		for y in 8:
			for x in 6:
				var c := sheet.get_pixel(int(r[0]) + x, int(r[1]) + y)
				if c.a == 0.0:
					continue
				n += 1
				frames_ok = frames_ok and c.a == 1.0 and pal.any(func(p): return p.is_equal_approx(Color(c.r, c.g, c.b)))
		counts.append(n)
	_check("saloon: steam = 4 frames 6x8, binary alpha, spec palette, rest frame empty, others drawn %s" % [counts],
		frames_ok and counts.size() == 4 and counts[0] == 0 and counts[1] > 0 and counts[2] > 0 and counts[3] > 0)
	# --- registry / build menu / switch
	var def := Data.room_def(Saloon.TYPE)
	_check("saloon: registered (Lv.%d, %d scrap, %s)" % [int(def.get("unlock", 0)), int(def.get("cost", 0)), def.get("stat", "")],
		RoomX.is_rx(Saloon.TYPE) and int(def.unlock) == 2 and int(def.cost) == 180 and def.stat == "agi" and is_equal_approx(float(def.power), 0.25)
		and Data.buildable().has(Saloon.TYPE) and Data.room_art(Saloon.TYPE) == "room_salvagers_saloon")
	Features.set_override("features", "rooms_expansion", false)
	_check("saloon: rooms_expansion off = not in the build menu", not Data.buildable().has(Saloon.TYPE))
	Features.set_override("features", "rooms_expansion", null)
	# --- a room to work in, two Saloons in freed slots, three crew aboard
	var work := -1
	for i in Game.s.rooms.size():
		var t := str(Game.s.rooms[i].type)
		if work < 0 and Data.BUILDABLE.has(t) and t != "quarters" and Game.room_cells(i).size() == 1 and not Game.is_constructing(i):
			work = i
	for i in Game.s.rooms.size():
		if i != work and Game.is_slot_unlocked(i) and not Game.is_annex(i) and Game.room_cells(i).size() == 1 				and not str(Game.s.rooms[i].type) in ["engine", "empty", "quarters"]:
			Game.s.rooms[i] = {"type": "empty", "level": 1, "job": {}}
	for d in Game.s.dwellers:
		d.room = -1
	for i in (Game.s.get("squad", []) as Array).size():
		Game.s.squad[i] = -1
	while Game.s.dwellers.size() < 3:
		Game.recruit_random()
	Game.s.erase("rx")
	var a := Dev.rx_build(Saloon.TYPE)
	var b := Dev.rx_build(Saloon.TYPE)
	_check("saloon: two Saloons built (%d, %d), a room to work in (%d)" % [a, b, work], a >= 0 and b >= 0 and work >= 0)
	if a < 0 or b < 0 or work < 0:
		_saloon_restore(keep_res, keep_rooms, keep_dw, keep_squad, keep_rx)
		return
	var d1: Dictionary = Game.s.dwellers[0]
	var d2: Dictionary = Game.s.dwellers[1]
	var d3: Dictionary = Game.s.dwellers[2]
	for d in [d1, d2, d3]:
		d.away_until = 0.0
		d.erase("exp")
		d.strike = false
	d1.room = work
	d2.room = -1
	d3.room = work
	Game.rooms_changed.emit()
	Game.dwellers_changed.emit()
	await wait(0.4)
	var rv = main.vehicle.room_views.filter(func(v): return v.slot == a)[0]
	_check("saloon: the room shows its art and the steam strip at (22,19)", rv.interior.texture == Atlas.tex("room_salvagers_saloon")
		and rv.anims.size() == 1 and rv.anims[0].position == Vector2(22, 19) and rv.anims[0].prefix == "fx_room_saloon_steam")
	var steam: RoomAnim = rv.anims[0]
	_check("saloon: an empty Saloon holds the empty rest frame", steam.cur_frame == 0)
	# --- start: pay once, only the diners leave their work
	Game.s.res.power = maxf(80.0, float(Game.s.res.power))
	Game.s.res.food = 50.0
	Game.s.res.water = 50.0
	var id1 := int(d1.id)
	var id2 := int(d2.id)
	var id3 := int(d3.id)
	_check("saloon: nobody / three people / an unknown id can't start", Saloon.start_block(a, []) != "" and Saloon.start_block(a, [id1, id2, id3]) != ""
		and Saloon.start_block(a, [999999]) != "")
	var j := Saloon.start(a, [id1, id2, id2])
	var again := Saloon.start(a, [id1, id2])
	_check("saloon: a supper starts and pays 8 food + 4 water once; a second tap is refused", not j.is_empty() and again.is_empty()
		and is_equal_approx(float(Game.s.res.food), 42.0) and is_equal_approx(float(Game.s.res.water), 46.0) and Saloon.diners(j) == [id1, id2])
	_check("saloon: the diners sit in the Saloon, the third keeps working", int(d1.room) == a and int(d2.room) == a and int(d3.room) == work
		and Game.room_workers(work).has(d3) and not Game.room_workers(work).has(d1))
	_check("saloon: a diner can't sit at the other Saloon meanwhile", Saloon.start_block(b, [id1]) != "" and Saloon.diner_block(d1) != "")
	await wait(0.6)
	_check("saloon: steam moves while they eat (frame %d)" % steam.cur_frame, steam.cur_frame != 0 or steam._t > 0.0)
	await shot("saloon_supper")
	var pw := float(Game.s.res.power)
	Game.s.res.power = 0.0
	await wait(0.3)
	_check("saloon: a dark Saloon holds the steam at rest", steam.cur_frame == 0 and RoomX.paused_why(j) == "dark")
	Game.s.res.power = pw
	Features.set_override("features", "rooms_expansion", false)
	await wait(0.3)
	_check("saloon: switch off holds the steam at rest", steam.cur_frame == 0)
	Features.set_override("features", "rooms_expansion", null)
	# --- the meal ends: diners back to work, cooldown shared by both Saloons
	var happy0 := float(d1.happy)
	d2.happy = 97.0
	RoomX.tick(Saloon.duration() + 1.0, false)
	_check("saloon: the meal ends, the diners go back where they came from", bool(j.done) and int(d1.room) == work and int(d2.room) == -1)
	_check("saloon: no happiness before the claim", is_equal_approx(float(d1.happy), happy0))
	_check("saloon: both diners are on cooldown in every Saloon (%.0fs)" % Saloon.cd_left(id1), is_equal_approx(Saloon.cd_left(id1), Saloon.cooldown())
		and Saloon.start_block(b, [id1]) != "" and Saloon.start_block(b, [id2]) != "" and Saloon.start_block(b, [id3]) == "")
	_check("saloon: an unclaimed supper keeps the table", Saloon.start_block(a, [id3]) != "")
	# --- claim once after a reload (JSON floats)
	Game.s.rx = JSON.parse_string(JSON.stringify(Game.s.rx))
	j = RoomX.job(int(j.id))
	main.chatter.last_talk = []
	var l1 := Saloon.claim(int(j.id))
	var l2 := Saloon.claim(int(j.id))
	d1 = Game.dweller_by_id(id1)
	d2 = Game.dweller_by_id(id2)
	_check("saloon: claimed once: +8 happiness, capped at 100, one bond, a two-line talk", l1.size() == 2 and l2.is_empty()
		and is_equal_approx(float(d1.happy), minf(100.0, happy0 + 8.0)) and is_equal_approx(float(d2.happy), 100.0) and Saloon.bonds(id1, id2) == 1
		and main.chatter.last_talk.size() == 2 and int(main.chatter.last_talk[0][0]) == id1)
	# --- cooldown runs on the game clock, frozen while the switch is off
	Features.set_override("features", "rooms_expansion", false)
	var cd0 := Saloon.cd_left(id1)
	RoomX.tick(60.0, false)
	_check("saloon: cooldowns freeze with the switch off", is_equal_approx(Saloon.cd_left(id1), cd0))
	Features.set_override("features", "rooms_expansion", null)
	RoomX.tick(Saloon.cooldown() + 1.0, false)
	_check("saloon: the cooldown runs out", Saloon.cd_left(id1) == 0.0 and Saloon.diner_block(d1) == "")
	# --- stale diner: moved elsewhere mid-meal = no reward; the other one still eats
	var j2 := Saloon.start(a, [id1, id3])
	Game.assign(d3, work)
	RoomX.tick(Saloon.duration() + 1.0, false)
	var h3 := float(d3.happy)
	var l3 := Saloon.claim(int(j2.id))
	_check("saloon: someone moved away mid-meal gets nothing, the other diner eats alone", not j2.is_empty() and l3.size() == 1
		and int(l3[0][0]) == id1 and is_equal_approx(float(d3.happy), h3) and Saloon.cd_left(id3) == 0.0 and Saloon.bonds(id1, id3) == 0)
	# --- demolition mid-meal: diners back to work, no reward, no refund
	Dev.saloon_clear_cd()
	d1.room = work
	var food0 := float(Game.s.res.food)
	var j3 := Saloon.start(a, [id1])
	var paid := float(Game.s.res.food)
	var h1 := float(d1.happy)
	Game.demolish_room(a)
	RoomX.tick(1.0, false)
	_check("saloon: demolished mid-meal: the job is gone, the diner is back at work, no refund, no reward", not j3.is_empty() and paid < food0
		and RoomX.job(int(j3.id)).is_empty() and int(d1.room) == work and is_equal_approx(float(d1.happy), h1)
		and is_equal_approx(float(Game.s.res.food), paid))
	# --- close-up: pick two people, start, then claim with the real buttons
	a = Dev.rx_build(Saloon.TYPE)
	Dev.saloon_clear_cd()
	main.open_closeup(a)
	await wait(0.6)
	var cu: RoomCloseup = main.hud.room_closeup
	var pick: Button = cu.find_child("SupperPickButton", true, false)
	_check("saloon: the close-up offers the supper", pick != null and not pick.disabled)
	if pick:
		pick.pressed.emit()
		await wait(0.3)
	cu._diners = [id1, id2]
	cu.refresh()
	await wait(0.2)
	var go: Button = cu.find_child("SupperStartButton", true, false)
	_check("saloon: two diners picked, the start button is live", go != null and not go.disabled)
	await shot("saloon_pick")
	if go:
		go.pressed.emit()
		await wait(0.3)
	var j4 := Saloon.supper(a)
	_check("saloon: started from the close-up", not j4.is_empty() and cu.mode == "main" and Saloon.diners(j4).size() == 2)
	Dev.rx_finish_jobs()
	await wait(0.4)
	var claim_btn: Button = cu.find_child("SupperClaimButton", true, false)
	_check("saloon: a finished supper shows the claim button", claim_btn != null)
	if claim_btn:
		claim_btn.pressed.emit()
		await wait(0.3)
	_check("saloon: claimed from the close-up, bond 2 for the pair", Saloon.supper(a).is_empty() and Saloon.bonds(id1, id2) == 2)
	await shot("saloon_closeup")
	cu.close()
	await wait(0.3)
	# --- GOD
	Dev.saloon_clear_cd()
	var gj := Dev.saloon_supper()
	Dev.rx_finish_jobs()
	RoomX.tick(0.1, false)
	Dev.saloon_claim_all()
	Game.s.rooms[a].level = 3
	_check("saloon: a Lv.3 Saloon serves supper 30%% faster (%.0fs)" % Saloon.duration(a), is_equal_approx(Saloon.duration(a), Saloon.duration() * 0.7)
		and is_equal_approx(Saloon.duration(), 90.0))
	_check("saloon: GOD starts, finishes and claims a supper", not gj.is_empty() and RoomX.jobs().is_empty() and int(Saloon.st().meals) >= 4)
	_saloon_restore(keep_res, keep_rooms, keep_dw, keep_squad, keep_rx)
	await wait(0.2)


func _saloon_restore(res: Dictionary, rooms: Array, dw: Array, squad: Array, rx) -> void:
	Game.s.res = res
	Game.s.rooms = rooms
	Game.s.dwellers = dw
	if Game.s.has("squad"):
		Game.s.squad = squad
	if rx == null:
		Game.s.erase("rx")
	else:
		Game.s.rx = rx
	Game.rooms_changed.emit()
	Game.dwellers_changed.emit()
	Game.resources_changed.emit()


## MV-250: hull warning stages (50 / 25 / 10 %), hysteresis, one alert per worse stage, red frame + strip, the
## strip's repair button, shake only with the setting on, switch off = nothing
func _hull_warning_test() -> void:
	_no_events()
	if Game.active_event != "":
		Game.cancel_event()
		main.hud.event_popup.close()
	var ha: HullAlert = main.hud.hull_alert
	var keep_hull := float(Game.s.hull)
	var keep_scrap := float(Game.s.res.scrap)
	var keep_shake = Settings.get_value("shake")
	_check("hull warning: stage lines 50/25/10 with 5% hysteresis", HullAlert.stage_for(1.0, 0) == 0 and HullAlert.stage_for(0.5, 0) == 1
		and HullAlert.stage_for(0.3, 0) == 1 and HullAlert.stage_for(0.24, 1) == 2 and HullAlert.stage_for(0.09, 2) == 3
		and HullAlert.stage_for(0.28, 2) == 2 and HullAlert.stage_for(0.31, 2) == 1 and HullAlert.stage_for(0.56, 1) == 0)
	var got := []
	var cb := func(st): got.append(st)
	ha.alerted.connect(cb)
	Settings.set_value("shake", true)
	Dev.hull_warning_preview(0)
	await wait(0.3)
	_check("hull warning: full hull = no stage, no strip, no frame", ha.stage == 0 and not ha._strip.visible and ha.pulse_alpha() == 0.0)
	Dev.hull_warning_preview(1)
	await wait(0.3)
	_check("hull warning: under 50% warns once and shows the strip for a while", ha.stage == 1 and got == [1] and ha._strip.visible
		and ha.pulse_alpha() == 0.0)
	main._shake = 0.0
	Dev.hull_warning_preview(2)
	await wait(0.05)
	var shook: bool = main._shake > 0.0
	await wait(0.3)
	_check("hull warning: under 25% alerts again, shakes, red frame + strip stay", ha.stage == 2 and got == [1, 2] and shook and ha._strip.visible
		and ha.pulse_alpha() > 0.0)
	Game.s.hull = Game.hull_max() * 0.27
	await wait(0.3)
	Game.s.hull = Game.hull_max() * 0.24
	await wait(0.3)
	_check("hull warning: hovering on the 25% line doesn't alert again", ha.stage == 2 and got == [1, 2])
	Settings.set_value("shake", false)
	main._shake = 0.0
	Dev.hull_warning_preview(3)
	await wait(0.05)
	var still: bool = is_zero_approx(main._shake)
	await wait(0.3)
	_check("hull warning: the HUD hull bar follows the hull (%.2f)" % main.hud.hull_bar.value, is_equal_approx(main.hud.hull_bar.value, HullAlert.ratio()))
	_check("hull warning: the red frame covers the screen", ha._edge.size.is_equal_approx(main.hud.size) and ha.size.x > 0.0)
	_check("hull warning: under 10% is critical; no shake with the shake setting off", ha.stage == 3 and got == [1, 2, 3] and still
		and ha.pulse_alpha() > 0.0 and ha._lbl.text.contains("%d%%" % int(round(HullAlert.ratio() * 100.0))))
	await shot("hull_warning_critical")
	Game.s.res.scrap = 0.0
	await wait(0.2)
	_check("hull warning: the repair button needs the scrap", ha._fix.disabled)
	Game.s.res.scrap = 9999.0
	await wait(0.2)
	ha._fix.pressed.emit()
	await wait(0.3)
	# damage can tick between the repair and this check (acid rain, a raid, one economy step), so "full" is 99 %
	_check("hull warning: repair from the strip fills the hull and clears the warning (hull %.1f/%.1f, scrap %.0f, stage %d, weather %s)" % [
		float(Game.s.hull), Game.hull_max(), float(Game.s.res.scrap), ha.stage, str(Game.s.weather)],
		float(Game.s.hull) >= Game.hull_max() * 0.99 and ha.stage == 0 and not ha._strip.visible and float(Game.s.res.scrap) < 9999.0)
	Features.set_override("features", "hull_warning", false)
	Dev.hull_warning_preview(3)
	await wait(0.3)
	_check("hull warning: switch off = no alert, strip or frame", ha.stage == 0 and got == [1, 2, 3] and not ha._strip.visible and ha.pulse_alpha() == 0.0)
	Features.set_override("features", "hull_warning", null)
	ha.alerted.disconnect(cb)
	Settings.set_value("shake", keep_shake)
	Game.s.hull = keep_hull
	Game.s.res.scrap = keep_scrap
	await wait(0.3)


## MV-127 morale v2: Depressed (slower work, hysteresis) → Broken (no work, quarters, refuses orders, squad freed) →
## leaves only at night without stealing; recovery sends them back to their room; talk (best INT talker, gain, talker
## off work, pair cooldown, frozen with the switch off); the dossier talk button; switch off = old rules; GOD
func _morale_test() -> void:
	_no_events()
	if Game.active_event != "":
		Game.cancel_event()
		main.hud.event_popup.close()
	var keep_dw: Array = Game.s.dwellers.duplicate(true)
	var keep_rooms: Array = Game.s.rooms.duplicate(true)
	var keep_res: Dictionary = Game.s.res.duplicate(true)
	var keep_squad: Array = (Game.s.get("squad", []) as Array).duplicate()
	var keep_tod = Game.s.get("tod", 0.5)
	Features.set_override("features", "morale_v2", true)
	# a room to work in and finished quarters
	var work := -1
	var quarters := -1
	for i in Game.s.rooms.size():
		var t := str(Game.s.rooms[i].type)
		if t == "quarters" and quarters < 0 and not Game.is_site(i):
			quarters = i
		elif work < 0 and Data.BUILDABLE.has(t) and t != "quarters" and t != "engine" and Game.room_cells(i).size() == 1 and not Game.is_site(i):
			work = i
	if quarters < 0:
		for i in Game.s.rooms.size():
			if i != work and Game.is_slot_unlocked(i) and str(Game.s.rooms[i].type) == "empty" and not Game.is_annex(i):
				Game.s.rooms[i] = {"type": "quarters", "level": 1, "job": {}, "build": {}}
				quarters = i
				break
	_check("morale: setup (work %d, quarters %d)" % [work, quarters], work >= 0 and quarters >= 0)
	while Game.s.dwellers.size() < 3:
		Game.recruit_random()
	var sad: Dictionary = Game.s.dwellers[0]
	var pal: Dictionary = Game.s.dwellers[1]
	var pal2: Dictionary = Game.s.dwellers[2]
	for d in [sad, pal, pal2]:
		d.away_until = 0.0
		d.erase("exp")
		for k in ["mood", "mood_room", "talk_t", "strike", "strike_t", "desert_t", "desert_warn"]:
			d.erase(k)
		d.happy = 70.0
		d.room = -1
	for i in (Game.s.get("squad", []) as Array).size():
		Game.s.squad[i] = -1
	Game.s.erase("morale")
	sad.room = work
	pal.int = 9
	pal2.int = 3
	Game.rooms_changed.emit()
	# --- Depressed: slower, with a gap before it clears
	var full := Crew.room_mult(work)
	sad.happy = 30.0
	Crew.morale_tick(sad, 1.0, false)
	_check("morale: below 35 = Depressed, works at 70%", Crew.is_depressed(sad) and is_equal_approx(Crew.work_mult(sad), 0.7)
		and Crew.room_mult(work) < full and Game.room_workers(work).has(sad))
	sad.happy = 38.0
	Crew.morale_tick(sad, 1.0, false)
	var held: bool = Crew.is_depressed(sad)
	sad.happy = 43.0
	Crew.morale_tick(sad, 1.0, false)
	_check("morale: stays Depressed until 42, then clears", held and Crew.mood(sad) == "")
	# --- Broken after 90 s under 20: no work, into the quarters, squad freed, refuses orders
	Game.set_squad(0, int(sad.id))
	sad.happy = 10.0
	for i in 8:
		Crew.morale_tick(sad, 10.0, false)
	var not_yet: bool = not Crew.is_broken(sad)
	Crew.morale_tick(sad, 15.0, false)
	_check("morale: Broken only after 90 s under 20", not_yet and Crew.is_broken(sad) and bool(sad.strike))
	_check("morale: Broken = in the quarters, out of the squad, not working", int(sad.room) == quarters and Game.squad_role(sad) < 0
		and not Game.room_workers(quarters).has(sad))
	_check("morale: Broken refuses room / squad / Saloon orders", not Game.assign(sad, work) and int(sad.room) == quarters
		and (func(): Game.set_squad(0, int(sad.id)); return Game.squad_role(sad) < 0).call() and Saloon.diner_block(sad) != "")
	# --- leaves only at night, after the wait, without stealing
	Game.s.tod = 0.5
	var food0 := float(Game.s.res.food)
	for i in 30:
		Crew.morale_tick(sad, 10.0, false)
	Crew.flush_deserters()
	var day_stays: bool = Game.s.dwellers.has(sad) and bool(sad.get("desert_warn", false))
	var sad_copy := sad.duplicate(true)
	Game.s.tod = 0.0
	Crew.morale_tick(sad, 1.0, false)
	Crew.flush_deserters()
	_check("morale: a Broken crew member warned in the day leaves at night with nothing stolen", day_stays and not Game.s.dwellers.has(sad)
		and is_equal_approx(float(Game.s.res.food), food0))
	# bring them back for the rest
	Game.s.dwellers.append(sad_copy)
	sad = sad_copy
	Game.s.tod = 0.5
	# --- talk: best INT talker, gain, talker off work, pair cooldown
	pal.room = work
	sad.desert_t = 0.0
	_check("morale: the best talker is the highest INT one", int(Crew.best_talker(sad).id) == int(pal.id) and Crew.talk_block(sad) == "")
	var h0 := float(sad.happy)
	var gain: float = Crew.talk(int(sad.id))
	_check("morale: talking gives %.1f happiness (more with INT 9)" % gain, gain > 10.0 and is_equal_approx(float(sad.happy), h0 + gain))
	_check("morale: the talker is off work for a minute", Crew.busy(pal) and not Game.room_workers(work).has(pal))
	_check("morale: the same pair waits; someone else talks next", Crew.talker_block(pal, sad) != "" and not Crew.best_talker(sad).is_empty()
		and int(Crew.best_talker(sad).id) != int(pal.id))
	Features.set_override("features", "morale_v2", false)
	var t0 := float(pal.talk_t)
	Crew.morale_v2_global_tick(30.0)
	_check("morale: talk timers freeze with the switch off", is_equal_approx(float(pal.talk_t), t0))
	Features.set_override("features", "morale_v2", true)
	Crew.morale_v2_global_tick(61.0)
	_check("morale: the talker goes back to work after the talk", not Crew.busy(pal) and Game.room_workers(work).has(pal))
	# --- recovery: back to the room they had when it has a seat, idle when it is full
	for o in Game.s.dwellers:
		if o != sad and int(o.room) == work:
			o.room = -1
	sad.mood_room = work
	sad.happy = 31.0
	Crew.morale_tick(sad, 1.0, false)
	_check("morale: from 30 Broken ends: back to their old room, still Depressed", not Crew.is_broken(sad) and not bool(sad.strike)
		and int(sad.room) == work and Crew.is_depressed(sad))
	Dev.mood_force(sad, "broken")
	sad.mood_room = work
	pal.room = work
	pal2.room = work
	sad.happy = 31.0
	Crew.morale_tick(sad, 1.0, false)
	_check("morale: a full old room = they recover idle, nobody is pushed out", not Crew.is_broken(sad) and int(sad.room) == -1
		and int(pal.room) == work and int(pal2.room) == work)
	pal.room = -1
	pal2.room = -1
	# --- the dossier talk button
	Dev.talk_reset()
	Dev.mood_force(sad, "depressed")
	main.hud.open_panel("dwellers")
	(main.hud.panels.dwellers as DwellersPanel).manage(int(sad.id))
	await wait(0.4)
	var tb: Button = main.hud.panels.dwellers.find_child("TalkButton", true, false)
	_check("morale: the dossier shows the talk button", tb != null and not tb.disabled)
	await shot("morale_dossier")
	var h1 := float(sad.happy)
	if tb:
		tb.pressed.emit()
		await wait(0.3)
	_check("morale: talking from the dossier lifts them", float(sad.happy) > h1)
	main.hud.panels.dwellers.close()
	await wait(0.3)
	# --- switch off: the old strike rules, no mood
	Features.set_override("features", "morale_v2", false)
	_check("morale: switch off = no stages, no refusals", Crew.mood(sad) == "" and not Crew.refuses(sad) and is_equal_approx(Crew.work_mult(sad), 1.0))
	Features.set_override("features", "morale_v2", true)
	# --- GOD
	Dev.mood_force(sad, "broken")
	var gb: bool = Crew.is_broken(sad)
	Dev.mood_force(sad, "")
	_check("morale: GOD sets Broken and back to fine", gb and Crew.mood(sad) == "" and not bool(sad.get("strike", false)))
	Features.set_override("features", "morale_v2", null)
	Game.s.dwellers = keep_dw
	Game.s.rooms = keep_rooms
	Game.s.res = keep_res
	if Game.s.has("squad"):
		Game.s.squad = keep_squad
	Game.s.tod = keep_tod
	Game.s.erase("morale")
	Game.rooms_changed.emit()
	Game.dwellers_changed.emit()
	Game.squad_changed.emit()
	await wait(0.3)


## MV-266: every screen class (phones portrait / landscape, tablets, laptops, large screens): a sane whole-number UI
## scale, the HUD inside the screen without its bars overlapping, every window / popup inside the screen (centred
## ones in the middle at their real size, the close-up docked beside the room), screenshots of each class
const RESPONSIVE_SIZES := [Vector2i(360, 640), Vector2i(390, 844), Vector2i(412, 915), Vector2i(844, 390), Vector2i(768, 1024),
	Vector2i(1024, 768), Vector2i(1024, 1366), Vector2i(1280, 800), Vector2i(1366, 768), Vector2i(2560, 1440)]


func _inside(r: Rect2, vp: Vector2) -> bool:
	return r.position.x >= -0.5 and r.position.y >= -0.5 and r.end.x <= vp.x + 0.5 and r.end.y <= vp.y + 0.5


func _grect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)


func _responsive_test() -> void:
	_no_events()
	if Game.active_event != "":
		Game.cancel_event()
		main.hud.event_popup.close()
	var keep := DisplayServer.window_get_size()
	var keep_tips = Settings.get_value("tips")
	Settings.set_value("tips", false)
	_check("responsive: scale rule (768x1024 -> 2, 1024x768 -> 2, 390x844 -> 1, 1170x2532 -> 3, 1920x1080 -> 3, 2560x1440 -> 4)",
		main.ui_scale_for(Vector2(768, 1024), Vector2(main.PORTRAIT_BASE)) == 2.0 and main.ui_scale_for(Vector2(1024, 768), Vector2(main.LANDSCAPE_BASE)) == 2.0
		and main.ui_scale_for(Vector2(390, 844), Vector2(main.PORTRAIT_BASE)) == 1.0 and main.ui_scale_for(Vector2(1170, 2532), Vector2(main.PORTRAIT_BASE)) == 3.0
		and main.ui_scale_for(Vector2(1920, 1080), Vector2(main.LANDSCAPE_BASE)) == 3.0 and main.ui_scale_for(Vector2(2560, 1440), Vector2(main.LANDSCAPE_BASE)) == 4.0)
	Features.set_override("features", "responsive_scale", false)
	_check("responsive: switch off = the old round-down (768x1024 -> 1)", main.ui_scale_for(Vector2(768, 1024), Vector2(main.PORTRAIT_BASE)) == 1.0)
	Features.set_override("features", "responsive_scale", null)
	var hud: HUD = main.hud
	var tested := 0
	# the window's own size first (always real), then every size class. Under xvfb without a window manager (CI) the
	# OS reports the new size but the viewport never follows: such a size is skipped (logged), not tested at a stale size
	for sz in [Vector2i.ZERO] + RESPONSIVE_SIZES:
		if sz != Vector2i.ZERO:
			DisplayServer.window_set_size(sz)
		await wait(0.8)
		var real: Vector2i = DisplayServer.window_get_size()
		var vp: Vector2 = hud.get_viewport_rect().size
		var tag := "%dx%d" % [real.x, real.y]
		if sz != Vector2i.ZERO and (absf(vp.x * main.pixel_scale - real.x) > main.pixel_scale or absf(vp.y * main.pixel_scale - real.y) > main.pixel_scale):
			print("[autotest] SKIP responsive %s: the window didn't really resize (design %s at %dx), no window manager?" % [tag, vp, int(main.pixel_scale)])
			continue
		tested += 1
		var base := Vector2(main.PORTRAIT_BASE if main.is_portrait() else main.LANDSCAPE_BASE)
		_check("responsive %s: whole scale %d, design %s at least %d%% of the base" % [tag, int(main.pixel_scale), vp, int(main.SCALE_MIN * 100)],
			main.pixel_scale == floorf(main.pixel_scale) and vp.x >= base.x * main.SCALE_MIN - 1.0 and vp.y >= base.y * main.SCALE_MIN - 1.0)
		var bars := [hud._top, hud._bottom, hud._tools, hud._combat_box, hud._view_box]
		var out := bars.filter(func(c): return c.visible and not _inside(_grect(c), vp))
		_check("responsive %s: HUD bars inside the screen" % tag, out.is_empty())
		var clash: bool = _grect(hud._bottom).intersects(_grect(hud._tools)) or (not main.is_portrait() and _grect(hud._top).intersects(_grect(hud._tools)))
		_check("responsive %s: the tool bar doesn't cover the top / route bars" % tag, not clash)
		await shot("responsive_%s_hud" % tag)
		var bad := []
		var off_mid := []
		for key in ["build", "map", "dwellers", "squad", "solar", "inventory", "log", "garage", "skills", "engine", "god", "settings"]:
			_no_events()
			if key == "settings":
				hud.open_settings("game")
			else:
				hud.open_panel(key)
			await wait(0.35)
			var p: ModalPanel = hud.panels[key]
			var r := _grect(p.box)
			if not _inside(r, vp):
				bad.append("%s %s" % [key, r])
			elif p.centered and absf(r.position.x - (vp.x - r.end.x)) > 1.5 and r.size.x < vp.x - 1.0:
				off_mid.append("%s %s" % [key, r])
			if key == "build":
				await shot("responsive_%s_build" % tag)
			p.close()
			await wait(0.2)
		# a loot grid built while the window was wide must not keep its columns on a narrower screen
		var loot: LootPanel = hud.panels.inventory
		if Game.s.get("stash", []).is_empty():
			Dev.forge_kit()          # a gear grid needs gear in the stash
		loot.tab = "gear"
		loot.filter = "all"
		loot.pick_slot = ""
		hud.open_panel("inventory")
		await wait(0.2)
		loot.box.custom_minimum_size.x = 900.0      # as if the grid was last built on a wide screen
		loot.box.size.x = 900.0
		loot.refresh()
		await wait(0.1)
		loot.close()
		await wait(0.2)
		hud.open_panel("inventory")
		await wait(0.3)
		if not _inside(_grect(loot.box), vp):
			bad.append("inventory after a wide grid %s" % _grect(loot.box))
		loot.close()
		await wait(0.2)
		_check("responsive %s: every window inside the screen %s" % [tag, bad], bad.is_empty())
		_check("responsive %s: centred windows sit in the middle at their real size %s" % [tag, off_mid], off_mid.is_empty())
		# a confirm on top, a road event, the room close-up docked beside the room
		ConfirmPanel.ask(hud, "ทดสอบ", "ทดสอบขนาดจอ", "ตกลง", func(): pass)
		await wait(0.35)
		var cp := get_tree().get_first_node_in_group("confirm_dialog") as ConfirmPanel
		var conf_ok: bool = cp != null and cp.is_open and _inside(_grect(cp.box), vp)
		if cp:
			cp.close()
		Game.trigger_event("stray_dog")
		await wait(0.5)
		var ev_ok: bool = _inside(_grect(hud.event_popup.box), vp)
		await shot("responsive_%s_event" % tag)
		Game.cancel_event()
		hud.event_popup.close()
		await wait(0.3)
		_check("responsive %s: confirm and event windows inside the screen" % tag, conf_ok and ev_ok)
		main.open_closeup(1)
		await wait(0.8)
		var cu: RoomCloseup = hud.room_closeup
		var cr := _grect(cu.box)
		var f := cu.focus_rect()
		var room := f       # landscape: the room fills the left focus area; portrait: a 80x52 room at zoom 2-3 in its middle
		if cu._portrait():
			var z := clampi(int(minf(f.size.x / 80.0, f.size.y / 52.0)), 2, 3)
			room = Rect2(f.get_center() - Vector2(40, 26) * z, Vector2(80, 52) * z)
		_check("responsive %s: the close-up is docked beside the room and inside the screen %s" % [tag, cr], _inside(cr, vp)
			and not cr.intersects(room.grow(-2.0)))
		await shot("responsive_%s_closeup" % tag)
		cu.close()
		await wait(0.5)
	_check("responsive: at least the window's own size was checked (%d sizes)" % tested, tested >= 1)
	Settings.set_value("tips", keep_tips)
	DisplayServer.window_set_size(keep)
	await wait(0.6)


## MV-113: frame-rate setting 30 / 60 / 120, the fixed-rate economy (alternating halves, no time lost, switch off =
## every frame), the Features fast path and the synergy cache give exactly the old answers, and a loose time budget
## for the economy in a heavy scene (CI renders in software, so only a big regression fails it)
func _perf_test() -> void:
	_no_events()
	if Game.active_event != "":
		Game.cancel_event()
		main.hud.event_popup.close()
	# --- frame-rate setting
	var fps0 = Settings.get_value("fps")
	Settings.set_value("fps", 120)
	var at120 := Engine.max_fps
	Settings.set_value("fps", 30)
	var at30 := Engine.max_fps
	Settings.apply_remote({"fps": 90})
	_check("perf: frame cap 120 / 30 apply, an unknown 90 falls back to 60", at120 == 120 and at30 == 30 and int(Settings.get_value("fps")) == 60
		and Engine.max_fps == 60)
	Settings.set_value("fps", fps0)
	# --- Features fast path == the old merged lookup (dev + session overrides included)
	Features.set_override("features", "barks", false)
	Features.set_override("tune", "fx.shake", 1.5)
	Features._session_dev = {"features": {"raids": false}, "tune": {"barks.cooldown": 30.0}}
	var mism := []
	for blk in ["features", "tune"]:
		var keys: Array = Features.FEATURES.keys() if blk == "features" else Features.TUNE.keys()
		for k in keys:
			var slow = null
			for l in Features.LAYERS:
				var b = Features._layer(l).get(blk, {})
				if b is Dictionary and b.has(k):
					slow = b[k]
			if Features._value(blk, k, null) != slow:
				mism.append("%s/%s" % [blk, k])
	_check("perf: feature switches and tunables read the same as before %s" % [mism], mism.is_empty() and not Features.on("raids")
		and is_equal_approx(Features.num("barks.cooldown", 12.0), 30.0) and not Features.on("barks"))
	Features._session_dev = {}
	Features.set_override("features", "barks", null)
	Features.set_override("tune", "fx.shake", null)
	# --- synergy cache == a fresh calculation, also right after a layout change without any signal
	var keep_rooms: Array = Game.s.rooms.duplicate(true)
	var stale := []
	for round in 2:
		for i in Game.s.rooms.size():
			if JSON.stringify(Synergy.effects(i)) != JSON.stringify(Synergy._effects(i)):
				stale.append("%d:%d" % [round, i])
		Game.s.rooms[Data.ENGINE_SLOT].type = "quarters" if str(Game.s.rooms[Data.ENGINE_SLOT].type) != "quarters" else "workshop"
	_check("perf: cached room synergies match a fresh calculation %s" % [stale], stale.is_empty())
	Game.s.rooms = keep_rooms
	Game.rooms_changed.emit()
	# --- fixed-rate economy: alternating halves, fewer steps than frames, no game time lost
	Features.set_override("features", "fixed_sim", true)
	Game._flush_sim()
	var w0: int = Game.sim_steps.world
	var c0: int = Game.sim_steps.crew
	var tod0 := float(Game.s.tod)
	var frames := 0
	var elapsed := 0.0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 1500000:
		await get_tree().process_frame
		frames += 1
		elapsed += get_process_delta_time() * Engine.time_scale
	var wn: int = Game.sim_steps.world - w0
	var cn: int = Game.sim_steps.crew - c0
	Game._flush_sim()
	var sim_sec := fposmod(float(Game.s.tod) - tod0, 1.0) * Data.DAY_LENGTH_SEC
	_check("perf: %d frames ran %d world + %d crew steps, alternating" % [frames, wn, cn], absi(wn - cn) <= 1 and wn + cn <= frames
		and wn + cn >= mini(frames, 20))
	_check("perf: no game time lost (%.2f s simulated for %.2f s of frames)" % [sim_sec, elapsed], absf(sim_sec - elapsed) < 0.2)
	Features.set_override("features", "fixed_sim", false)
	w0 = Game.sim_steps.world
	frames = 0
	for i in 20:
		await get_tree().process_frame
		frames += 1
	_check("perf: switch off = the economy every frame (%d steps in %d frames)" % [Game.sim_steps.world - w0, frames],
		Game.sim_steps.world - w0 >= frames - 1)
	Features.set_override("features", "fixed_sim", null)
	# --- loose budget in a heavy scene (prints the numbers for the PR)
	var keep_dw: Array = Game.s.dwellers.duplicate(true)
	var keep_tier = Game.s.get("tier", "van")
	Dev.set_tier("rig")
	Dev.set_trailers(2)
	Dev.rooms_fill()
	Dev.spawn_roster_all()
	await wait(0.5)
	var t1 := Time.get_ticks_usec()
	for i in 60:
		Game._simulate(1.0 / 60.0, false)
	var per := float(Time.get_ticks_usec() - t1) / 60.0 / 1000.0
	print("[perf] heavy scene (%d crew, %d rooms): economy %.2f ms per full step, last halves %.2f + %.2f ms" % [Game.s.dwellers.size(),
		Game.s.rooms.size(), per, float(Game.sim_ms.world), float(Game.sim_ms.crew)])
	_check("perf: the economy in a heavy scene stays under the budget (%.2f ms per full step)" % per, per < 25.0)
	Dev.set_trailers(0)
	Dev.set_tier(str(keep_tier))
	Game.s.dwellers = keep_dw
	Game.s.rooms = keep_rooms
	Game.rooms_changed.emit()
	Game.dwellers_changed.emit()
	await wait(0.5)


## MV-482: windows are as tall as their content (no empty space, up to the screen), a later change of content height
## slides there, and the room close-up shows the whole room with nothing over it, centred on portrait screens
func _window_fit_test() -> void:
	_no_events()
	if Game.active_event != "":
		Game.cancel_event()
		main.hud.event_popup.close()
	var hud: HUD = main.hud
	var vp: Vector2 = hud.get_viewport_rect().size
	var keep_tips = Settings.get_value("tips")
	Settings.set_value("tips", false)
	# --- every window: content height, clamped to the screen
	var off := []
	for key in ["build", "map", "dwellers", "squad", "solar", "inventory", "log", "garage", "skills", "engine", "settings"]:
		_no_events()
		if key == "settings":
			hud.open_settings("game")
		elif key == "skills":
			hud.open_skills(int(Game.s.dwellers[0].id))
		else:
			hud.open_panel(key)
		await wait(0.5)
		var p: ModalPanel = hud.panels[key]
		var want := clampf(p.natural_height(), minf(ModalPanel.MIN_H, p.max_height()), p.max_height())
		if p.fit_height and absf(p.box.size.y - floorf(want)) > 2.0:
			off.append("%s %.0f (content %.0f, max %.0f)" % [key, p.box.size.y, p.natural_height(), p.max_height()])
		if p.box.position.y < -0.5 or p.box.position.y + p.box.size.y > vp.y + 0.5:
			off.append("%s off screen" % key)
		p.close()
		await wait(0.25)
	_check("window fit: every window is as tall as its content, up to the screen %s" % [off], off.is_empty())
	Features.set_override("features", "window_fit", false)
	hud.open_panel("dwellers")
	await wait(0.5)
	var full_h: float = hud.panels.dwellers.box.size.y
	var full_max: float = hud.panels.dwellers.max_height()
	hud.panels.dwellers.close()
	await wait(0.25)
	Features.set_override("features", "window_fit", null)
	_check("window fit: switch off = the full height as before (%.0f of %.0f)" % [full_h, full_max], absf(full_h - full_max) <= 1.0)
	# --- the crew list grows: the window slides taller, then back
	var keep_dw: Array = Game.s.dwellers.duplicate(true)
	while Game.s.dwellers.size() > 2:
		Game.s.dwellers.pop_back()
	Game.dwellers_changed.emit()
	hud.open_panel("dwellers")
	await wait(0.6)
	var dp: ModalPanel = hud.panels.dwellers
	var h0 := dp.box.size.y
	for i in 3:
		Game.recruit_random()
	Game.dwellers_changed.emit()
	var seen_between := false
	for i in 12:
		await get_tree().process_frame
		if dp.box.size.y > h0 + 1.0 and dp.box.size.y < dp.fit_target() - 1.0:
			seen_between = true
	await wait(0.4)
	_check("window fit: more crew = the window slides taller (%.0f -> %.0f, in between seen %s)" % [h0, dp.box.size.y, seen_between],
		dp.box.size.y > h0 + 20.0 and absf(dp.box.size.y - dp.fit_target()) <= 2.0 and seen_between)
	Game.s.dwellers = keep_dw.duplicate(true)
	while Game.s.dwellers.size() > 2:
		Game.s.dwellers.pop_back()
	Game.dwellers_changed.emit()
	await wait(0.6)
	_check("window fit: fewer crew = it shrinks back (%.0f)" % dp.box.size.y, absf(dp.box.size.y - h0) <= 2.0)
	dp.close()
	Game.s.dwellers = keep_dw
	Game.dwellers_changed.emit()
	await wait(0.3)
	# --- the room close-up: the whole room, nothing over it, centred on portrait
	var slot := -1
	for i in Game.s.rooms.size():
		if Game.is_slot_unlocked(i) and str(Game.s.rooms[i].type) != "empty" and Game.room_cells(i).size() == 1 and i != Data.CAB_SLOT:
			slot = i
			break
	main.open_closeup(slot)
	await wait(0.9)
	var cu: RoomCloseup = hud.room_closeup
	var r: Rect2 = main.vehicle.slot_global_rect(slot)
	var a: Vector2 = main.world_to_screen(r.position)
	var b: Vector2 = main.world_to_screen(r.end)
	var room := Rect2(a, b - a)
	var panel := Rect2(cu.box.position, cu.box.size)
	var top_bar: float = hud._top.position.y + hud._top.size.y
	_check("window fit: close-up hides the view buttons and the hull strip", not hud._view_box.visible and not hud.hull_alert._strip.visible)
	_check("window fit: the whole room is on screen, under the top bar, not under the panel (room %s, panel %s)" % [room, panel],
		room.position.y >= top_bar - 1.0 and room.position.x >= -1.0 and room.end.x <= vp.x + 1.0 and not room.grow(-1.0).intersects(panel))
	if cu._portrait():
		var f := cu.focus_rect()
		_check("window fit: portrait = the room centred above the panel (room %s, area %s)" % [room, f],
			absf(room.get_center().x - vp.x * 0.5) <= 2.0 and absf(room.get_center().y - f.get_center().y) <= 2.0)
	await shot("window_fit_closeup")
	cu.mode = "assign"
	cu.refresh()
	await wait(0.8)
	a = main.world_to_screen(r.position)
	b = main.world_to_screen(r.end)
	room = Rect2(a, b - a)
	panel = Rect2(cu.box.position, cu.box.size)
	_check("window fit: a shorter panel and the room follows to the middle of the new space (room %s, panel %s)" % [room, panel],
		not room.grow(-1.0).intersects(panel) and (not cu._portrait() or absf(room.get_center().y - cu.focus_rect().get_center().y) <= 2.0))
	await shot("window_fit_closeup_assign")
	cu.close()
	await wait(0.6)
	Settings.set_value("tips", keep_tips)


## MV-473 (MV-474..481): steel equipment slots and the six rarity light loops: atlas sprites (sizes, mask codes,
## empty item centre, bounded overscan, motion), the tile (frame per width, light only on filled items, old renderer
## with the switch off), presentations (aura moves, neon / still clip, still / paused / hidden hold), one shared
## phase, aura clearance in the stash and crew layouts, taps still work, GOD preview
func _gear_slots_test() -> void:
	_no_events()
	if Game.active_event != "":
		Game.cancel_event()
		main.hud.event_popup.close()
	var keep_tips = Settings.get_value("tips")
	Settings.set_value("tips", false)
	var sheet: Image = Atlas.sheet.get_image()
	if sheet.is_compressed():
		sheet.decompress()
	# --- atlas: frames per width, 16 masks per rarity per width
	var frames_ok := true
	for w in GearFx.WIDTHS:
		var r: Array = Atlas.regions.get("ui_gear_slot_frame" + ("" if w == 32 else "_%d" % w), [])
		frames_ok = frames_ok and r.size() == 4 and int(r[2]) == w and int(r[3]) == w
	_check("gear slots: a steel frame drawn for each width 28/30/32/36/40", frames_ok)
	var codes := [Color("26262a"), Color("54544e"), Color("9a9684")]
	var bad := []
	var moving := 0
	for rank in 6:
		for w in GearFx.WIDTHS:
			var cell: int = w + 24
			var first := PackedByteArray()
			var differs := false
			for p in 16:
				var key := GearFx.mask_key(rank, w, p)
				var r: Array = Atlas.regions.get(key, [])
				if r.size() != 4 or int(r[2]) != cell or int(r[3]) != cell:
					bad.append("%s size" % key)
					continue
				var img := sheet.get_region(Rect2i(int(r[0]), int(r[1]), cell, cell))
				var ic: int = 12 + (int(w) - 16) / 2
				for y in cell:
					for x in cell:
						var c := img.get_pixel(x, y)
						if c.a == 0.0:
							continue
						if c.a < 1.0 or not codes.any(func(k): return k.is_equal_approx(Color(c.r, c.g, c.b))):
							bad.append("%s colour" % key)
						elif x >= ic and x < ic + 16 and y >= ic and y < ic + 16:
							bad.append("%s item centre" % key)
						elif x < 12 - UIKit.GEAR_AURA or y < 12 - UIKit.GEAR_AURA or x >= 12 + w + UIKit.GEAR_AURA or y >= 12 + w + UIKit.GEAR_AURA:
							bad.append("%s overscan" % key)
				if p == 0:
					first = img.get_data()
				elif img.get_data() != first:
					differs = true
			if differs:
				moving += 1
	_check("gear slots: 480 light masks, three grey codes only, item centre empty, light within 6 px %s" % [bad.slice(0, 4)], bad.is_empty())
	_check("gear slots: every rarity's light moves at every width (%d / 30)" % moving, moving == 30)
	# --- the tile
	var hud: HUD = main.hud
	var item := Dev.gear_sample(4, "boots", 3, true)
	var t := UIKit.gear_tile(item, "boots", 36)
	var e := UIKit.gear_tile({}, "helmet", 28)
	var sb := t.get_theme_stylebox("normal") as StyleBoxTexture
	_check("gear slots: a filled tile = 36 px steel frame + one light; an empty one has none", sb != null and sb.texture == Atlas.tex("ui_gear_slot_frame_36")
		and t.custom_minimum_size == Vector2(36, 36) and t.find_children("*", "GearFx", true, false).size() == 1
		and e.find_children("*", "GearFx", true, false).is_empty() and e.get_child(0).material != null)
	t.free()
	e.free()
	Features.set_override("features", "gear_slot_style", false)
	var old := UIKit.gear_tile(item, "boots", 36)
	var osb := old.get_theme_stylebox("normal") as StyleBoxTexture
	_check("gear slots: style off = the old tile, no light", osb != null and osb.texture != Atlas.tex("ui_gear_slot_frame_36") and old.find_children("*", "GearFx", true, false).is_empty())
	old.free()
	Features.set_override("features", "gear_slot_style", null)
	# --- presentations on live tiles (GOD preview grid)
	hud.open_panel("god")
	var god = hud.panels.god
	god.tab = "icons"
	god.refresh()
	await wait(0.4)
	var fxs: Array = god.find_children("*", "GearFx", true, false)
	_check("gear slots: GOD shows every rarity at every width (%d lights)" % fxs.size(), fxs.size() >= 30)
	await shot("gear_slots_god_aura")
	var a: GearFx = fxs[fxs.size() - 1]
	var b: GearFx = fxs[0]
	var seen := {}
	for i in 20:
		await wait(0.05)
		seen[a.phase] = true
	_check("gear slots: aura moves through its phases (%d seen) and every tile shares one phase" % seen.size(), seen.size() >= 4 and a.phase == b.phase
		and not a.clip_contents)
	Dev.gear_preview("neon")
	await wait(0.2)
	_check("gear slots: neon = the same light clipped to the slot", a.clip_contents and a._tex.visible)
	await shot("gear_slots_god_neon")
	Features.set_override("features", "gear_slot_vfx", false)
	Dev.gear_preview("")
	await wait(0.4)
	var p0 := a.phase
	await wait(0.4)
	_check("gear slots: vfx off = a still rarity rim (phase %d, clipped)" % a.phase, a.phase == 0 and p0 == 0 and a.clip_contents and a._tex.visible)
	Features.set_override("features", "gear_slot_vfx", null)
	await wait(0.3)
	get_tree().paused = true
	var held := GearFx.current_phase()
	await get_tree().create_timer(0.4, true).timeout
	var paused_ok := GearFx.current_phase() == held
	get_tree().paused = false
	god.visible = false
	held = a.phase
	await wait(0.4)
	var hidden_ok := a.phase == held
	god.visible = true
	_check("gear slots: the light holds while paused and does no work while hidden", paused_ok and hidden_ok)
	Dev.gear_preview("base")
	await wait(0.2)
	_check("gear slots: GOD base = metal only", not a._tex.visible)
	Dev.gear_step()
	var s1 := GearFx.current_phase()
	Dev.gear_step()
	_check("gear slots: GOD frame step", GearFx.current_phase() == (s1 + 1) % 16)
	Dev.gear_preview("")
	god.close()
	await wait(0.3)
	# --- clearance and taps in the real stash and crew layouts
	if Loot.stash().size() < 8:
		Dev.forge_kit()
	var loot: LootPanel = hud.panels.inventory
	loot.tab = "gear"
	loot.filter = "all"
	loot.pick_slot = ""
	loot.detail_uid = -1
	hud.open_panel("inventory")
	await wait(0.5)
	var tiles: Array = loot.find_children("*", "Button", true, false).filter(func(x): return x.find_child("GearFx", false, false) != null)
	var clash := 0
	for i in tiles.size():
		for j in range(i + 1, tiles.size()):
			var ri := Rect2(tiles[i].global_position, tiles[i].size).grow(UIKit.GEAR_AURA)
			if ri.intersects(Rect2(tiles[j].global_position, tiles[j].size)):
				clash += 1
	_check("gear slots: in the stash no aura reaches another slot (%d tiles)" % tiles.size(), tiles.size() >= 5 and clash == 0)
	await shot("gear_slots_stash")
	if not tiles.is_empty():
		tiles[0].pressed.emit()
		await wait(0.3)
	_check("gear slots: tapping a slot still opens the item", loot.detail_uid >= 0)
	await shot("gear_slots_detail")
	loot.close()
	await wait(0.3)
	var crew: Dictionary = Game.s.dwellers[0]
	hud.open_panel("dwellers")
	(hud.panels.dwellers as DwellersPanel).manage(int(crew.id))
	await wait(0.5)
	var f28 := Atlas.tex("ui_gear_slot_frame_28")
	var ct: Array = hud.panels.dwellers.find_children("*", "Button", true, false).filter(func(x):
		var tsb = x.get_theme_stylebox("normal")
		return tsb is StyleBoxTexture and tsb.texture == f28)
	var caps_ok := true
	for tb in ct:
		var h: Control = tb.get_parent()
		if h is BoxContainer and h.get_child_count() > 1:
			var cap: Control = h.get_child(1)
			caps_ok = caps_ok and cap.global_position.x - (tb.global_position.x + tb.size.x) >= UIKit.GEAR_AURA - 0.5
	_check("gear slots: crew gear labels sit clear of the aura (%d slots)" % ct.size(), ct.size() == 6 and caps_ok)
	await shot("gear_slots_crew")
	hud.panels.dwellers.close()
	await wait(0.3)
	Settings.set_value("tips", keep_tips)


## MV-483 (MV-484..498): compact trait cards and their light. The frame, the 192 canonical masks (codes, content
## cutout, 4 px bound, motion), the in-game light == those masks at 160x58, real trait values (cost red, upside kept,
## warning mark), the untiered fallback, cards that grow with their text, the crew dossier (columns, clearance), the
## switch off = old chips, live / still / paused, the bounded cache, GOD preview
func _trait_cards_test() -> void:
	_no_events()
	if Game.active_event != "":
		Game.cancel_event()
		main.hud.event_popup.close()
	var keep_tips = Settings.get_value("tips")
	Settings.set_value("tips", false)
	var fr: Array = Atlas.regions.get("ui_trait_card_frame", [])
	_check("trait cards: the compact frame is 160x58 in the atlas", fr.size() == 4 and int(fr[2]) == 160 and int(fr[3]) == 58)
	# --- the canonical masks (reference sheet, not shipped) and the in-game port
	var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://tools/art/trait_cards/fx_trait_masks.png"))
	var regions = JSON.parse_string(FileAccess.get_file_as_string("res://tools/art/trait_cards/fx_trait_masks.json"))
	_check("trait cards: 192 canonical light masks (12 profiles x 16)", sheet != null and regions is Dictionary and regions.size() == 192)
	if sheet == null or not (regions is Dictionary):
		return
	var codes := [Color("26262a"), Color("54544e"), Color("9a9684")]
	var bad := []
	var mismatch := []
	var moving := 0
	var names := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
	for neg in [false, true]:
		for rank in 6:
			var first := PackedByteArray()
			var differs := false
			for i in 16:
				var key := "fx_trait_%s_%s_%d" % ["tradeoff" if neg else "benefit", names[rank], i]
				var r: Array = regions[key]
				var img := sheet.get_region(Rect2i(int(r[0]), int(r[1]), 172, 70))
				var lit := TraitFx.light(neg, rank, i, 160, 58, false)
				for y in 70:
					for x in 172:
						var c := img.get_pixel(x, y)
						var want := TraitFx.level(float(lit.get(Vector2i(x, y), 0.0)))
						var got := 0
						if c.a > 0.0:
							for ci in codes.size():
								if codes[ci].is_equal_approx(Color(c.r, c.g, c.b)):
									got = ci + 1
							if got == 0:
								bad.append("%s colour" % key)
							elif x >= 10 and x < 162 and y >= 10 and y < 60:
								bad.append("%s content" % key)
							elif x < 2 or y < 2 or x >= 170 or y >= 68:
								bad.append("%s bound" % key)
						if got != want and mismatch.size() < 4:
							mismatch.append("%s %d,%d mask %d game %d" % [key, x, y, got, want])
				if i == 0:
					first = img.get_data()
				elif img.get_data() != first:
					differs = true
			if differs:
				moving += 1
	_check("trait cards: masks use only the three codes, never light the content, stay within 4 px %s" % [bad.slice(0, 3)], bad.is_empty())
	_check("trait cards: all 12 profiles move (%d)" % moving, moving == 12)
	_check("trait cards: the in-game light matches the approved masks pixel for pixel %s" % [mismatch], mismatch.is_empty())
	# --- real cards
	var cook := TraitCard.new()
	cook.size = Vector2(170, 60)
	add_child(cook)
	cook.setup("cook", -1)
	var glut := TraitCard.new()
	glut.size = Vector2(170, 60)
	add_child(glut)
	glut.setup("glutton", -1)
	await wait(0.2)
	var g_lbls: Array = glut.find_children("*", "Label", true, false).map(func(l): return l.text)
	_check("trait cards: untiered = no tier label; a benefit gets the accent only, a trade-off the still crimson edge",
		cook.find_child("Tier", true, false) == null and TraitFx.mode_for(false, cook.tier) == "accent" and TraitFx.mode_for(true, glut.tier) == "still")
	_check("trait cards: a trade-off shows the warning, its red cost and keeps its upside (%s)" % [g_lbls], glut.find_child("Warning", true, false) != null
		and g_lbls.has(Loc.t(TraitCard.COST.glutton)) and g_lbls.has(Loc.t(TraitCard.UPSIDE.glutton)))
	cook.queue_free()
	glut.queue_free()
	# --- MV-497 tiers: every trait classified, mythic kept free, trade-offs at most rare, the switch falls back
	var unlisted := Crew.TRAITS.keys().filter(func(t): return Crew.trait_tier(t) < 0 or Crew.trait_tier(t) > 4)
	var harsh := Crew.TRAITS.keys().filter(func(t): return Crew.TRAITS[t].get("bad", false) and Crew.trait_tier(t) > 2)
	_check("trait tiers: all %d traits classified common..legendary %s, trade-offs at most rare %s" % [Crew.TRAITS.size(), unlisted, harsh],
		unlisted.is_empty() and harsh.is_empty() and Crew.TRAIT_TIERS.size() == Crew.TRAITS.size())
	_check("trait tiers: architect and lucky legendary, cook uncommon, afraid of the dark the harshest trade-off",
		Crew.trait_tier("architect") == 4 and Crew.trait_tier("lucky") == 4 and Crew.trait_tier("cook") == 1
		and Crew.trait_tier("afraid_dark") == 2 and Crew.trait_tier("grumpy") == 0)
	var tiered := TraitCard.new()
	tiered.size = Vector2(170, 60)
	add_child(tiered)
	tiered.setup("cook")
	Dev.trait_tiers(false)
	var off_ok := Crew.trait_tier("cook") == -1 and Crew.trait_tier("architect") == -1
	Dev.trait_tiers(true)
	await wait(0.2)
	_check("trait tiers: a classified card shows its tier label and the tier light; switch off = untiered",
		tiered.find_child("Tier", true, false) != null and TraitFx.mode_for(false, tiered.tier) in ["anim", "still"] and off_ok)
	tiered.queue_free()
	Features.set_override("features", "trait_tiers", null)
	# --- MV-516 roll odds: seeded 4000 recruits land on the approved shares; off = every trait even; named crew fixed
	Crew.rng.seed = 51600
	var on_r := Dev.trait_roll_test(4000)
	var want := {"common": 47.7, "uncommon": 42.8, "rare": 25.9, "epic": 10.7, "legendary": 2.9, "bad": 22.6}
	var off_by := []
	for k in want:
		if absf(float(on_r[k]) - want[k]) > (1.5 if k == "legendary" else 3.0):
			off_by.append("%s %.1f" % [k, on_r[k]])
	_check("trait odds: weighted roll matches the approved shares %s" % [off_by], off_by.is_empty())
	_check("trait odds: legendary weight 1 vs common 10, a trade-off 5",
		Crew.trait_weight("architect") == 1.0 and Crew.trait_weight("quick_hands") == 10.0 and Crew.trait_weight("afraid_dark") == 5.0)
	Features.set_override("features", "trait_roll_weights", false)
	Crew.rng.seed = 51601
	var off_r := Dev.trait_roll_test(4000)
	var even := Crew.trait_weight("architect") == 1.0 and Crew.trait_weight("quick_hands") == 1.0
	Features.set_override("features", "trait_roll_weights", null)
	_check("trait odds: switch off = every trait equally likely (legendary %.1f%%, was 13.8%%)" % float(off_r.legendary),
		even and absf(float(off_r.legendary) - 13.8) < 3.0)
	var mark := {"lore": "mark"}
	Crew.roll_traits(mark)
	_check("trait odds: named crew keep their fixed traits (%s)" % [mark.traits], mark.traits == Crew.FIXED.mark)
	Crew.rng.randomize()
	var arch := TraitCard.new()
	arch.custom_minimum_size.x = 160
	add_child(arch)
	arch.setup("architect", 4)
	await wait(0.3)
	arch.size = arch.get_combined_minimum_size()
	await wait(0.2)
	_check("trait cards: a long description grows the card (%s) and its light follows (%s)" % [arch.size, arch.fx.size],
		arch.size.y > 58.0 and arch.fx.size == arch.size + Vector2(12, 12) and arch.find_child("Tier", true, false) != null
		and arch.fx.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var ph := {}
	for i in 12:
		await wait(0.06)
		ph[arch.fx.phase] = true
	_check("trait cards: a classified card's light moves (%d phases seen)" % ph.size(), ph.size() >= 4)
	get_tree().paused = true
	var held := TraitFx.current_phase()
	await get_tree().create_timer(0.4, true).timeout
	var paused_ok := TraitFx.current_phase() == held
	get_tree().paused = false
	Features.set_override("features", "trait_card_vfx", false)
	await wait(0.4)
	var still_ok := arch.fx.phase == 0
	Features.set_override("features", "trait_card_vfx", null)
	_check("trait cards: the light holds while paused, and stands still with trait_card_vfx off", paused_ok and still_ok)
	arch.queue_free()
	_check("trait cards: the light cache stays bounded (%d)" % TraitFx._cache.size(), TraitFx._cache.size() <= TraitFx.CACHE_MAX)
	# --- the crew dossier
	var hud: HUD = main.hud
	var crew: Dictionary = {}
	for d in Game.s.dwellers:
		if Crew.traits(d).size() >= 2:
			crew = d
			break
	if crew.is_empty():
		crew = Game.s.dwellers[0]
		crew["traits"] = ["cook", "glutton"]
	hud.open_panel("dwellers")
	(hud.panels.dwellers as DwellersPanel).manage(int(crew.id))
	await wait(0.6)
	var dp: ModalPanel = hud.panels.dwellers
	var cards: Array = dp.find_children("*", "TraitCard", true, false)
	var clash := 0
	for i in cards.size():
		for j in range(i + 1, cards.size()):
			if Rect2(cards[i].global_position, cards[i].size).grow(4).intersects(Rect2(cards[j].global_position, cards[j].size).grow(4)):
				clash += 1
	_check("trait cards: the dossier shows one card per trait, their light never meets (%d cards)" % cards.size(),
		cards.size() == Crew.traits(crew).size() and clash == 0)
	await shot("trait_cards_dossier")
	dp.close()
	await wait(0.3)
	Features.set_override("features", "trait_card_style", false)
	hud.open_panel("dwellers")
	(hud.panels.dwellers as DwellersPanel).manage(int(crew.id))
	await wait(0.5)
	_check("trait cards: style off = the old trait chips", dp.find_children("*", "TraitCard", true, false).is_empty())
	dp.close()
	await wait(0.3)
	Features.set_override("features", "trait_card_style", null)
	# --- GOD preview
	hud.open_panel("god")
	var god = hud.panels.god
	god.tab = "crew"
	god.refresh()
	await wait(0.5)
	_check("trait cards: GOD previews all twelve profiles + fallbacks", god.find_children("*", "TraitCard", true, false).size() >= 16)
	await shot("trait_cards_god")
	god.close()
	await wait(0.3)
	Settings.set_value("tips", keep_tips)

## MV-518: crew stats easy to read: same order and colour everywhere, one bar segment per point, the best stat boxed in
## gold with "ถนัด" (none when all three tie), compact chips in list rows, what the best stat is good for, and what
## the equipment adds shown apart (gear never changes STR / AGI / INT)
func _stat_view_test() -> void:
	for k in main.hud.panels:
		if main.hud.panels[k].is_open:
			main.hud.panels[k].close()
	var d: Dictionary = Game.s.dwellers[0]
	var keep := {"str": d.str, "agi": d.agi, "int": d.int}
	d.str = 7
	d.agi = 4
	d["int"] = 5
	_check("stat view: best stat found (STR)", UIKit.best_stats(d) == ["str"] and UIKit.best_stats({"str": 5, "agi": 5, "int": 5}).is_empty()
		and UIKit.best_stats({"str": 6, "agi": 6, "int": 2}) == ["str", "agi"])
	var bars := UIKit.stat_bars(d)
	add_child(bars)
	var segs: Array = bars.find_children("Segments", "", true, false)
	var lit := 0
	for r in segs[0].get_children():
		lit += 1 if (r as ColorRect).color == UIKit.STAT_COLOR.str else 0
	_check("stat view: order STR AGI INT, one segment per point (STR 7 = %d lit)" % lit, segs.size() == 3 and segs[0].get_child_count() == 10 and lit == 7
		and bars.get_child(0).name == "BestStat_str" and bars.get_child(1).name == "Stat_agi" and bars.get_child(2).name == "Stat_int")
	_check("stat view: only the best stat is boxed in gold", bars.find_children("BestStat_*", "", true, false).size() == 1)
	bars.queue_free()
	var chips := UIKit.stat_chips(d)
	add_child(chips)
	_check("stat view: compact chips box the best one", chips.find_children("BestChip_*", "", true, false).size() == 1
		and chips.find_children("BestChip_str", "", true, false).size() == 1)
	chips.queue_free()
	_check("stat view: the best stat says which rooms it suits", UIKit.stat_rooms("str").size() > 0)
	# the crew window: list row and detail
	main.hud.open_panel("dwellers")
	await wait(0.3)
	var panel = main.hud.panels.dwellers
	_check("stat view: crew list rows show the chips", panel.find_children("StatChips", "", true, false).size() >= 1)
	await shot("stat_view_list")
	panel.manage(int(d.id))
	await wait(0.3)
	var gear: Array = panel.find_children("GearLine", "", true, false)
	var labels: Array = panel.find_children("*", "Label", true, false).map(func(l): return str(l.text))
	_check("stat view: detail has the bars, the best boxed, what it suits and the gear line", panel.find_children("BestStat_str", "", true, false).size() == 1
		and gear.size() == 1 and str(gear[0].text).begins_with("จากอุปกรณ์") and labels.any(func(t): return t.begins_with("ถนัด STR")))
	await shot("stat_view_detail")
	panel.close()
	d.str = keep.str
	d.agi = keep.agi
	d["int"] = keep.int
	await wait(0.2)


## MV-129 (MV-500 phase 1): the seeded world map is generated the same way from the same seed, holds all six regions
## (each bordering the next) and all 13 landmarks once, every stop is reachable at Vault 6 and only the first region at
## Vault 1, border roads carry the gate + warlord, routes are shortest and respect gates, a save round trip keeps it,
## opening never regenerates it, and the switch off makes no world
func _world_map_test() -> void:
	var keep = Game.s.get("world")
	Game.s.erase("world")
	_check("world map: switch off (shipped default) = no world", not Features.on("seeded_world_map") and WorldMap.ensure().is_empty() and not Game.s.has("world"))
	Features.set_override("features", "seeded_world_map", true)
	var a := WorldMap.generate("ASH-271")
	var b := WorldMap.generate("ASH-271")
	var c := WorldMap.generate("RUN-042")
	_check("world map: same seed = same world, another seed = another", JSON.stringify(a) == JSON.stringify(b) and JSON.stringify(a.nodes) != JSON.stringify(c.nodes)
		and int(a.gen) == WorldMap.GEN_VERSION)
	var w := WorldMap.create("ASH-271")
	_check("world map: six regions, each bordering the next on the 2 x 3 grid", (w.regions as Array).size() == 6 and range(1, 6).all(func(i):
		var p: Dictionary = w.regions[i - 1]
		var q: Dictionary = w.regions[i]
		return absi(int(p.x) - int(q.x)) + absi(int(p.y) - int(q.y)) < 200))
	var sites := (w.nodes as Array).filter(func(n): return n.has("site")).map(func(n): return str(n.site))
	var all_sites := Expedition.SITES.keys()
	_check("world map: all %d landmarks, each once, in its own biome (%d)" % [all_sites.size(), sites.size()], sites.size() == all_sites.size()
		and all_sites.all(func(id): return sites.count(id) == 1)
		and (w.nodes as Array).filter(func(n): return n.has("site")).all(func(n): return str(Data.biome(int(n.biome)).id) == str(Expedition.SITES[n.site].biome)))
	_check("world map: a start in the first region and an exit in the last", WorldMap.node("start").get("biome", -1) == 0
		and int(WorldMap.node("world_exit").get("biome", -1)) == 5 and str(w.at) == "start")
	var ids := (w.nodes as Array).map(func(n): return str(n.id))
	var uniq := {}
	for id in ids:
		uniq[id] = true
	_check("world map: stop and road ids are unique", uniq.size() == ids.size())
	var r6 := WorldMap.reachable("start", 6)
	var r1 := WorldMap.reachable("start", 1)
	_check("world map: every stop reachable at Vault 6 (%d/%d)" % [r6.size(), ids.size()], r6.size() == ids.size())
	_check("world map: Vault 1 reaches only the first region", r1.keys().all(func(id): return int(WorldMap.node(id).biome) == 0) and r1.size() >= 4)
	var borders := (w.edges as Array).filter(func(e): return int(WorldMap.node(e.a).biome) != int(WorldMap.node(e.c).biome))
	_check("world map: 5 border roads, each with the next region's Vault level and the warlord of the one it leaves", borders.size() == 5
		and borders.all(func(e):
			var hi := maxi(int(WorldMap.node(e.a).biome), int(WorldMap.node(e.c).biome))
			return int(e.gate) == int(Data.biome(hi).req) and int(e.boss) == hi - 1))
	var rt := WorldMap.route("start", "helios", 6)
	_check("world map: a route reaches the last region (%.1f km, %d stops)" % [float(rt.get("km", 0)), (rt.get("ids", []) as Array).size()], not rt.is_empty()
		and rt.ids[0] == "start" and rt.ids[-1] == "helios" and (rt.edges as Array).size() == (rt.ids as Array).size() - 1)
	_check("world map: gates hold (no route to the last region at Vault 3)", WorldMap.route("start", "helios", 3).is_empty())
	var direct := (w.edges as Array).filter(func(e): return str(e.a) == "market" or str(e.c) == "market")
	var one: Dictionary = direct[0]
	var other: String = str(one.c) if str(one.a) == "market" else str(one.a)
	_check("world map: neighbours route along their road", is_equal_approx(float(WorldMap.route("market", other, 6).km), float(one.km)))
	var km_total := 0.0
	for e in w.edges:
		km_total += float(e.km)
	_check("world map: roads have sensible lengths (%.1f km in all)" % km_total, (w.edges as Array).all(func(e): return float(e.km) >= 0.1 and float(e.km) < 30.0))
	# save round trip (JSON turns numbers into floats) and no regeneration on open
	Game.s.world = JSON.parse_string(JSON.stringify(Game.s.world))
	var rt2 := WorldMap.route("start", "helios", 6)
	_check("world map: still routes after a save round trip", not rt2.is_empty() and is_equal_approx(float(rt2.km), float(rt.km)))
	var snap := JSON.stringify(Game.s.world)
	WorldMap.ensure()
	Game.game_started.emit()
	_check("world map: opening / starting again never regenerates it", JSON.stringify(Game.s.world) == snap)
	_check("world map: GOD verify regenerates the same world from the saved seed", Dev.world_verify())
	Dev.world_new("XYZ-001")
	_check("world map: GOD new world changes the seed", str(WorldMap.world().seed) == "XYZ-001")
	Features.set_override("features", "seeded_world_map", null)
	if keep == null:
		Game.s.erase("world")
	else:
		Game.s.world = keep


## MV-130 (MV-500 phase 2): driving the world map. Driven straight through Game._simulate (the real travel step), with
## the clock of the real game frozen in between so only the test's steps move the vehicle.
func _world_travel_test() -> void:
	_no_events()
	if Game.active_event != "":
		Game.cancel_event()
		main.hud.event_popup.close()
	# the test drives hundreds of real simulation steps (crew, morale, offline catch-up, a lap): the whole save is
	# put back afterwards so later groups see exactly what they saw before
	var snap: Dictionary = Game.s.duplicate(true)
	var keep := {"world": Game.s.get("world"), "biome": int(Game.s.biome), "km": float(Game.s.km), "lap": int(Game.s.lap),
		"vault": int(Game.s.vault_level), "trav": bool(Game.s.traveling), "beaten": (Game.s.combat.get("boss_beaten", {}) as Dictionary).duplicate(),
		"done": (Game.s.get("sites_done", {}) as Dictionary).duplicate(), "site": str(Game.s.get("at_site", "")), "stall": float(Game.s.stall)}
	Features.set_override("features", "seeded_world_map", true)
	Features.set_override("features", "road_events", false)
	Game.s.erase("world")
	Game.s.biome = 0
	Game.s.lap = 0
	Game.s.km = 0.0
	Game.s.stall = 0.0
	Game.s.traveling = true
	Game.s.vault_level = 1
	Game.s["at_site"] = ""
	Game.s.combat.boss_beaten = {}
	Game.s.sites_done = {}
	Game.s.hull = maxf(80.0, float(Game.s.hull))
	Game.s.res.power = 1000.0
	WorldMap.create("TRAVEL-1")
	get_tree().paused = true          # the real clock stops; the test drives Game._simulate itself
	var drive := func(sec: float, offline: bool = false):
		var n := int(ceil(sec / 60.0))
		for i in n:
			Game.s.res.power = 1000.0
			Game._simulate(60.0, offline)
	_check("world travel: no destination = the vehicle waits", Game.blocked_reason() == "เลือกปลายทางบนแผนที่" and not Game.is_moving())
	# a destination two stops away inside the first region, with a landmark on the way
	var rt := WorldMap.route("start", "depot", 1)
	_check("world travel: a route inside the first region", not rt.is_empty() and (rt.ids as Array).size() >= 2)
	var km0 := float(Game.s.stats.km_total)
	_check("world travel: choosing a stop alone doesn't move it", not WorldMap.driving() and is_equal_approx(float(Game.s.stats.km_total), km0))
	_check("world travel: drive commits the route", WorldMap.drive_to("depot") and WorldMap.driving() and Game.is_moving())
	var parks := 0
	for guard in 150:
		drive.call(600.0)
		if Expedition.at_site() != "":
			parks += 1
			Expedition.skip_site()
		if not WorldMap.driving():
			break
	_check("world travel: arrives at the destination and parks there", str(WorldMap.world().at) == "depot" and not WorldMap.driving()
		and Game.blocked_reason() == "เลือกปลายทางบนแผนที่")
	_check("world travel: each landmark on the way parks the vehicle once (%d)" % parks, parks == (rt.ids as Array).filter(func(id): return WorldMap.node(id).has("site")).size())
	_check("world travel: distance = the route, nothing doubled (%.2f vs %.2f km)" % [float(Game.s.stats.km_total) - km0, float(rt.km)],
		absf(float(Game.s.stats.km_total) - km0 - float(rt.km)) < 0.05)
	# reload mid-road: no free distance
	var back := WorldMap.route("depot", "start", 1)
	WorldMap.drive_to("start")
	Game._simulate(5.0, false)
	var mid := float(WorldMap.trip().get("prog", 0.0))
	Game.s.world = JSON.parse_string(JSON.stringify(Game.s.world))
	km0 = float(Game.s.stats.km_total) - mid
	for guard in 150:
		drive.call(600.0)
		if Expedition.at_site() != "":
			Expedition.skip_site()
		if not WorldMap.driving():
			break
	_check("world travel: a reload mid-road carries on from the same spot (%.2f km)" % (float(Game.s.stats.km_total) - km0), mid > 0.0
		and str(WorldMap.world().at) == "start" and absf(float(Game.s.stats.km_total) - km0 - float(back.km)) < 0.05)
	# the checkpoint: Vault level, then the warlord, then into the next region
	var j1 := str(Data.biome(1).id) + "_junction"
	_check("world travel: the next region is out of reach below its Vault level", not WorldMap.drive_to(j1) and WorldMap.drive_block(j1) != "")
	Game.s.vault_level = 2
	var far: Dictionary = (WorldMap.world().nodes as Array).filter(func(n): return int(n.biome) == 1)[0]
	_check("world travel: Vault 2 can route into the next region", WorldMap.drive_to(str(far.id)))
	for guard in 150:
		drive.call(600.0)
		if Expedition.at_site() != "":
			Expedition.skip_site()
		if Game.at_checkpoint() or not WorldMap.driving():
			break
	_check("world travel: the vehicle waits at the border road for the warlord", Game.at_checkpoint() and Game.at_checkpoint_spot() and int(Game.s.biome) == 0
		and Combat._next_req() == 2 and not Game.is_moving())
	_check("world travel: the warlord is due at the checkpoint", Combat.warlord_due() or Combat.warlord_cd > 0.0)
	var entered := [-1]
	var cb := func(i, _inst): entered[0] = i
	Game.biome_changed.connect(cb)
	Game.s.combat.boss_beaten["0"] = true
	for guard in 150:
		drive.call(600.0)
		if Expedition.at_site() != "":
			Expedition.skip_site()
		if not WorldMap.driving():
			break
	Game.biome_changed.disconnect(cb)
	_check("world travel: warlord beaten = across the border, into the next biome", not Game.at_checkpoint() and int(Game.s.biome) == 1 and entered[0] == 1
		and str(WorldMap.world().at) == str(far.id))
	# offline follows the same road to the same place
	Game.s.vault_level = 6
	for b in 6:
		Game.s.combat.boss_beaten[str(b)] = true
	var dest := "helios"
	var rt2 := WorldMap.route(WorldMap.here(), dest, 6)
	WorldMap.drive_to(dest)
	km0 = float(Game.s.stats.km_total)
	for guard in 150:
		drive.call(600.0, true)
		if not WorldMap.driving():
			break
	_check("world travel: offline reaches the same stop by the same road (%.2f vs %.2f km)" % [float(Game.s.stats.km_total) - km0, float(rt2.km)],
		str(WorldMap.world().at) == dest and absf(float(Game.s.stats.km_total) - km0 - float(rt2.km)) < 0.05 and Expedition.at_site() == "")
	_check("world travel: offline drives past landmarks and marks them, as on the old road", rt2.ids.filter(func(id): return WorldMap.node(id).has("site") and id != dest)
		.all(func(id): return Expedition.is_done(str(WorldMap.node(id).site))))
	# a new destination mid-road finishes the road first
	var nb: Dictionary = WorldMap.edges_of(dest)[0]
	var other: String = str(nb.c) if str(nb.a) == dest else str(nb.a)
	WorldMap.drive_to(other)
	Game._simulate(5.0, false)
	var on_road := str(WorldMap.trip().edges[0])
	WorldMap.drive_to(dest)
	_check("world travel: changing the destination mid-road keeps the road under the wheels", str(WorldMap.trip().edges[0]) == on_road
		and float(WorldMap.trip().prog) > 0.0)
	for guard in 150:
		drive.call(600.0)
		if not WorldMap.driving():
			break
	# the exit: lap + 1 in a new world
	var seed0 := str(WorldMap.world().seed)
	WorldMap.drive_to("world_exit")
	for guard in 150:
		drive.call(600.0)
		if Expedition.at_site() != "":
			Expedition.skip_site()
		if int(Game.s.lap) == 1:
			break
	_check("world travel: the world exit = lap + 1 in a new world, back at the start", int(Game.s.lap) == 1 and str(WorldMap.world().seed) != seed0
		and int(WorldMap.world().lap) == 1 and str(WorldMap.world().at) == "start" and int(Game.s.biome) == 0)
	get_tree().paused = false
	Features.set_override("features", "seeded_world_map", null)
	Features.set_override("features", "road_events", null)
	Game.s = snap
	Game.travel_changed.emit()
	Game.dwellers_changed.emit()
	Game.resources_changed.emit()
	Game.biome_changed.emit(int(Game.s.biome), true)
	await wait(0.3)
