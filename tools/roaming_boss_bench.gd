extends RefCounted
## MV-544: fixed Desert fixture, no save I/O, cheats, enhancements, affixes or travel income.

const DESERT_BOSSES := ["acid_matron", "bloat_king", "sky_harpy", "bone_hulk"]


func prepare(seed_value: int = 544) -> void:
	Combat._clear_enemies()
	Account.a = {}
	Game.rng.seed = seed_value
	Game.setup_default_state()
	Account.attach(Game.s)
	Game.s.biome = 1
	Game.s.vault_level = 6
	Game.s.tier = "bus"
	while Game.s.rooms.size() < Game.slot_count():
		Game.s.rooms.append({"type": "empty", "level": 1, "job": {}, "build": {}})
	Game.s.traveling = false
	Game.s.weather = "clear"
	Game.s.weather_t = 10000.0
	Game.s.event_t = 10000.0
	Game.s.res.scrap = 0.0
	Game.started = true
	Game.active_event = ""
	Game.closeup_slot = -1
	Game.s.squad = [int(Game.s.dwellers[1].id), int(Game.s.dwellers[0].id), int(Game.s.dwellers[4].id)]
	Loot.rng.seed = seed_value
	for did in Game.s.squad:
		var d := Game.dweller_by_id(int(did))
		d.lvl = 20
		d.gear = {}
		for slot in Loot.HERO_SLOTS:
			var base_id := "pipe_wrench" if did == Game.s.squad[1] else "hunting_rifle"
			if slot != "weapon":
				base_id = first_base(slot)
			d.gear[slot] = item(slot, base_id)
	Game.s.van_gear.turret = item("turret", "mg_turret")
	Game.s.van_gear.plating = item("plating", first_base("plating"))
	Game.s.hull = Game.hull_max()
	Combat.rng.seed = seed_value
	Combat.heroes = []
	Combat.turret = {"t": 0.0}
	Combat._acc = 0.0
	Combat._clock = 0.0
	Combat._kill_window = []
	Combat.cs().wave = 10
	Combat.cs().push = false
	Combat.rebuild_heroes()
	Threat.reset()


func first_base(slot: String) -> String:
	for key in Loot.BASES:
		if Loot.BASES[key].slot == slot and int(Loot.BASES[key].min_ilvl) <= 20:
			return key
	return ""


func item(slot: String, base_id: String) -> Dictionary:
	var out := Loot.roll_item(slot, 20, 2, base_id)
	out.aff = []
	return out


func spawn(id: String, level: int = 25, warlord: bool = false) -> Dictionary:
	Combat._clear_enemies()
	Combat._spawn({"boss": "warlord" if warlord else "boss", "boss_id": id, "lvl": level})
	return Combat.enemies[0]


func fight(id: String, seed_value: int, balanced: bool) -> Dictionary:
	prepare(seed_value)
	Features.layers.dev.features["roaming_boss_balance"] = balanced
	Combat.debug_spawn([{"t": 0.0, "boss": "boss", "boss_id": id, "lvl": 25}], true)
	Combat.tick(0.1)
	var boss: Dictionary = Combat.enemies[0]
	var elapsed := 0.1
	var hull_min := float(Game.s.hull)
	while Combat.wave_active and elapsed < 100.0:
		Game._simulate(0.1, true)
		Combat.tick(0.1)
		elapsed += 0.1
		hull_min = minf(hull_min, float(Game.s.hull))
	return {"enabled": balanced, "boss": id, "seed": seed_value, "seconds": snappedf(elapsed, 0.1), "killed": float(boss.hp) <= 0.0,
		"boss_hp": float(boss.max), "boss_dmg": float(boss.dmg), "hull_max": Game.hull_max(), "hull_min": hull_min,
		"repair": Game.repair_cost(), "scrap": float(Game.s.res.scrap), "dps": Combat.squad_dps()}
