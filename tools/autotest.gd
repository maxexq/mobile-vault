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
	main.hud.title_screen._settings_btn.pressed.emit()
	await wait(0.6)
	_check("settings: title menu button opens it", main.hud.settings_panel.is_open and main.hud.settings_panel.visible)
	await shot("title_settings")
	main.hud.settings_panel.close()
	await wait(0.3)
	main.hud.title_screen._go(true)
	await wait(2.5)
	await _tutorial_test()
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
	# the explorer is back with the new assault rifle: put them on the gun so ranged / flying enemies die too
	Game.set_squad(0, int(d.id))
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
	# room synergy: engine (slot 0) next to quarters (slot 1) = noise; engine next to workshop = faster repairs
	Game.s.rooms[1].type = "quarters"
	var noisy := Synergy.happy_mod(1)
	Game.s.rooms[1].type = "workshop"
	Meta.add_blueprint("bp_workshop")
	_check("synergy: engine noise next to quarters", noisy < 0.0)
	_check("synergy: engine + workshop repairs +15%", Synergy.repair_bonus() > 1.1)
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
	var this_session := Trace.entries.filter(func(e): return str(e.sid) == Trace.session)
	var errs := this_session.filter(func(e): return str(e.cat) == "error")
	print("[autotest] trace entries this session: %d, errors: %d" % [this_session.size(), errs.size()])
	for e in errs:
		print("[autotest] trace error: ", Trace.fmt_entry(e))
	print("[autotest] v3/v4 checks done: %d failed total" % _fails)
	# portrait phone
	get_window().size = Vector2i(780, 1688)
	await wait(1.5)
	await shot("portrait")
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
	await _settings_test()
	_event_variety_test()
	print("[autotest] DONE")
	get_tree().quit()


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
	_check("tutorial: progress saved", bool(Save.read().get("tutorial", {}).get("done", false)))
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
	_check("about: version rows", BuildInfo.rows().size() >= 8 and BuildInfo.as_text().contains("Mobile Vault v" + BuildInfo.GAME_VERSION))
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
