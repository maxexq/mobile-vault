extends Node
var main: Node
func _ready() -> void:
	await get_tree().process_frame
	var ok := Game.load_game()
	print("[mig] loaded=", ok, " biome=", Game.s.biome, " km=", Game.s.km, " boss=", Game.s.combat.boss_beaten, " squad=", Game.s.squad, " stash=", Loot.stash().size(), " dwellers=", Game.s.dwellers.size(), " lore=", Lore.count_open())
	var d: Dictionary = Game.s.dwellers[0]
	print("[mig] bio=", Lore.bio(d).role, " gear keys=", d.gear.keys(), " helmet=", Loot.equipped_on(d, "helmet"))
	print("[mig] v4: tier=", Game.tier(), " trailers=", Game.trailers(), " pets=", Game.s.get("pets"), " types=", Game.s.rooms.map(func(r): return r.type))
	print("[mig] v3: rooms=", Game.s.rooms.size(), "/", Game.slot_count(), " fuel=", Game.s.res.get("fuel", -1), " mods=", Game.s.get("mods"), " traits=", Crew.traits(d), " skills=", d.get("skills"))
	for i in 60:
		Game._simulate(1.0, true)
	for i in 300:
		Combat.tick(0.1)
	print("[mig] kills after 30s: ", Game.s.combat.kills, " wave ", Combat.wave())
	get_tree().quit()
