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
	await wait(1.2)
	await shot("title")
	main.hud.title_screen._go(true)
	await wait(2.5)
	await shot("main_industrial_rain")
	Combat.reset_wave(6)
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
	main.hud.panels.inventory.close()
	await wait(0.4)
	main.hud.open_loot_pick("weapon", int(Game.s.squad[0]))
	await wait(0.6)
	await shot("loot_pick_weapon")
	main.hud.panels.inventory.close()
	await wait(0.4)
	# room close-up
	main.open_closeup(4)
	await wait(1.0)
	await shot("closeup_kitchen")
	main.hud.room_closeup.close()
	await wait(0.8)
	main.open_closeup(6)
	await wait(1.0)
	await shot("closeup_empty_build")
	main.hud.room_closeup.close()
	await wait(0.6)
	# build hydroponics via placement
	Game.s.res.scrap = 600.0
	main._enter_placement("hydroponics")
	await wait(0.5)
	await shot("placement_mode")
	Game.build_room(6, "hydroponics")
	main._exit_placement()
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
	Game.start_craft(4, "cook_meal")
	main.open_closeup(4)
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
	var new_slot: int = Data.SLOT_UNLOCK_ORDER[Data.SLOTS_PER_LEVEL[1]]
	_check("new slot unlocked at Lv2", Game.is_slot_unlocked(new_slot) and Game.unlocked_slots().size() == Data.SLOTS_PER_LEVEL[2] + 1)
	_check("3 rooms per floor (12 slots)", Game.slot_count() == 12 and Game.s.rooms.size() == 12)
	_check("build quarters", Game.build_room(new_slot, "quarters") and Game.pop_cap() == Data.BASE_POP_CAP + 4)
	Game.s.res.scrap = 200.0
	_check("craft starts", Game.start_craft(Data.ENGINE_SLOT, "repair_hull"))
	Game.s.hull = 50.0
	for i in 200:
		Game._simulate(1.0, true)
	_check("craft finished -> hull repaired", Game.s.rooms[Data.ENGINE_SLOT].job.is_empty() and Game.s.hull >= 74.0)
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
	Combat.rebuild_heroes()
	for i in 600:
		Combat.tick(0.1)
	_check("combat kills enemies", int(Game.s.combat.kills) > 0)
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
	# --- v3 systems: mods on the truck, skill tree, hazards, expeditions, next generation
	Game.s.res.scrap = 99999.0
	Game.s.items.components = 9999
	Game.s.vault_level = 4
	for bp in ["bp_roof_turret", "bp_tracks", "bp_solar_covers", "bp_rad_shield", "bp_heater"]:
		Meta.add_blueprint(bp)
	var ok_all := true
	for id in ["spike_ram", "spike_ram", "spike_ram", "roof_turret", "roof_turret", "fuel_tanks", "fuel_tanks", "fuel_tanks",
			"tracks", "armor_plates", "armor_plates", "armor_plates", "solar_covers", "rad_shield", "rain_catcher", "heater"]:
		ok_all = Mods.install(id) and ok_all
	Mods.mods_changed.emit()
	_check("install exterior mods", ok_all and Mods.level("spike_ram") == 3 and Mods.level("tracks") == 1)
	_check("tracks replace rear wheels", main.vehicle.tracks.visible and not main.vehicle.wheels[1].visible)
	_check("fuel cap grows with tanks", Env.fuel_cap() > 60.0)
	var sk: Dictionary = Game.s.dwellers[0]
	sk.lvl = 8
	_check("skill learn", Skills.learn(sk, "c1") and Skills.rank(sk, "c1") == 1)
	_check("traits rolled", Crew.traits(sk).size() >= 1)
	Game.s.biome = 4
	Game.s.tod = 0.9
	_check("tundra night needs heating fuel", Env.heating_fuel_pm() > 0.0)
	Game.s.biome = 0
	Game.s.tod = 0.4
	Game.s.weather = "clear"
	Game.weather_changed.emit("clear")
	main.pan_x = 0.0
	Expedition.skip_site()
	for k in main.hud.panels:
		if main.hud.panels[k].is_open:
			main.hud.panels[k].close()
	await wait(1.5)
	await shot("mods_on_truck")
	main.hud.open_panel("garage")
	await wait(0.6)
	await shot("panel_garage")
	main.hud.panels.garage.close()
	main.hud.open_skills(int(sk.id))
	await wait(0.6)
	await shot("panel_skills")
	main.hud.panels.skills.close()
	await wait(0.3)
	# expedition at the abandoned hospital
	Combat.reset_wave(1)
	Expedition.arrive("hospital")
	await wait(2.6)
	main.hud.open_expedition("hospital")
	await wait(0.6)
	await shot("expedition_plan")
	var team_ids := []
	for dd in Game.s.dwellers:
		if not Game.is_away(dd) and team_ids.size() < 2:
			team_ids.append(int(dd.id))
	var started := Expedition.start("hospital", team_ids, {"food": 10, "water": 10, "stimpack": 1, "ammo": 0, "antibiotics": 0})
	_check("expedition start", started and Expedition.active())
	main.hud.panels.expedition.close()
	await wait(2.2)
	await shot("expedition_walkout")
	await wait(4.0)
	Game.s.exp.start = float(Game.s.exp.start) - 99999.0
	Expedition.tick(false)
	_check("expedition finished", not Expedition.active())
	await wait(1.6)
	await shot("expedition_return")
	if main.hud.panels.expedition.is_open:
		main.hud.panels.expedition.close()
	Expedition.skip_site()
	# next generation with a bigger chassis
	Meta.m().legacy = 999
	Meta.add_blueprint("bp_chassis2")
	_check("buy chassis MK-II", Meta.buy("chassis2"))
	Meta.next_generation([int(Game.s.dwellers[0].id)])
	await wait(1.5)
	_check("gen 2: 5 floors / 15 rooms", Meta.floors() == 5 and Game.slot_count() == 15 and Game.s.rooms.size() == 15 and main.vehicle.room_views.size() == 15)
	await shot("gen2_truck")
	Meta.m().legacy = 9999
	Meta.add_blueprint("bp_chassis3")
	Meta.buy("chassis3")
	Meta.next_generation([int(Game.s.dwellers[0].id)])
	await wait(1.5)
	_check("gen 3: 6 floors / 18 rooms", Meta.floors() == 6 and Game.s.rooms.size() == 18)
	Game.s.vault_level = 6
	Game.vault_level_changed.emit(6)
	await wait(1.0)
	await shot("gen3_truck")
	main.pan_y = main.pan_y_max
	main.camera.position = main.cam_home + Vector2(0, -main.pan_y)
	await wait(0.6)
	await shot("gen3_truck_look_up")
	main.pan_y = 0.0
	print("[autotest] v3 checks done: %d failed total" % _fails)
	# portrait phone
	get_window().size = Vector2i(780, 1688)
	await wait(1.5)
	await shot("portrait")
	main.open_closeup(5)
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
	print("[autotest] DONE")
	get_tree().quit()
