extends RefCounted
## MV-550: Common +0 gear at biome-entry item level, level-5 ordinary crew, no traits/skills,
## no turret, no cheats, no travel/event income. Includes weapon-only and unarmed controls.

func prepare(biome: int, lap: int, profile: String, seed_value: int) -> void:
	load("res://tools/roaming_boss_bench.gd").new().prepare(seed_value)
	Game.s.biome = biome
	Game.s.lap = lap
	Game.s.vault_level = mini(6, biome + 2)
	Game.s.mods = {}
	Game.s.van_gear = {"turret": null, "plating": null, "engine": null, "spikes": null}
	Game.s.hull = Game.hull_max()
	Game.s.gear = []
	for role in Game.s.squad.size():
		var d := Game.dweller_by_id(int(Game.s.squad[role]))
		d.lvl = 5
		d.str = 4
		d.agi = 4
		d.int = 4
		d.traits = []
		d.skills = {}
		d.max_hp = 100.0
		d.hp = 100.0
		d.gear = {}
		if profile == "unarmed":
			continue
		var bases := ["pipe_wrench" if role == 1 else "pipe_pistol"]
		if profile == "common":
			bases.append_array(["leather_jacket", "hard_hat", "work_boots", "medkit_pouch", "school_bag"])
		for base_id in bases:
			var slot: String = Loot.BASES[base_id].slot
			d.gear[slot] = {"uid": int(Game.s.next_uid), "base": base_id, "slot": slot, "rar": 0, "ilvl": Combat.biome_base_level(), "plus": 0, "aff": [], "lock": false}
			Game.s.next_uid = int(Game.s.next_uid) + 1
	Combat.cs().wave = 1
	Combat.cs().push = false
	Combat.heroes = []
	Combat.rebuild_heroes()
	Threat.reset()


func fight(biome: int, lap: int, profile: String, seed_value: int, enabled: bool) -> Dictionary:
	prepare(biome, lap, profile, seed_value)
	Features.layers.dev.features["warlord_progression"] = enabled
	var metrics := {"falls": 0, "hero_min": 1.0, "hull_min": float(Game.s.hull), "adds": 0}
	var on_hit := func(kind: String, slot: int, _amount: float, _crit: bool):
		if kind == "hero":
			var hero: Dictionary = Combat.heroes[slot]
			metrics.hero_min = minf(float(metrics.hero_min), maxf(0.0, float(hero.hp) / float(hero.max)))
			if float(hero.hp) <= 0.0: metrics.falls += 1
		elif kind == "van": metrics.hull_min = minf(float(metrics.hull_min), float(Game.s.hull))
	var on_spawn := func(e: Dictionary):
		if bool(e.get("warlord_add", false)): metrics.adds += 1
	Combat.hit.connect(on_hit)
	Combat.enemy_spawned.connect(on_spawn)
	Combat.debug_spawn([{"t": 0.0, "boss": "warlord", "lvl": Combat.warlord_level()}], true)
	Combat.tick(0.1)
	var boss: Dictionary = Combat.enemies[0]
	var elapsed := 0.1
	while Combat.wave_active and elapsed < Combat.WARLORD_TIMEOUT + 1.0 and float(Game.s.hull) > 0.0:
		Game._simulate(0.1, true)
		Combat.tick(0.1)
		elapsed += 0.1
	Combat.hit.disconnect(on_hit)
	Combat.enemy_spawned.disconnect(on_spawn)
	metrics.merge({"biome": biome, "lap": lap, "profile": profile, "seed": seed_value, "enabled": enabled,
		"seconds": snappedf(elapsed, 0.1), "killed": float(boss.hp) <= 0.0,
		"gate_open": Combat.boss_beaten(biome), "boss_hp": float(boss.max), "boss_dmg": float(boss.dmg),
		"hull_max": Game.hull_max(), "scrap": float(Game.s.res.scrap), "drops": Loot.stash().size()})
	return metrics
