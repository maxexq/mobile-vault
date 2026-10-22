extends Node
## Dev-only balance sim: godot --headless --path . -- --balance [--minutes=N]
## Plays the game at max speed with a simple bot and prints a progression log.

var main: Node


func _ready() -> void:
	await get_tree().process_frame
	var minutes := 120
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			minutes = int(a.substr(10))
	# detach the visual layer: this sim runs many minutes per frame
	for sig in Combat.get_signal_list():
		for c in Combat.get_signal_connection_list(sig.name):
			if c.callable.get_object() == main.combat_view:
				Combat.disconnect(sig.name, c.callable)
	Save.wipe()
	Game.new_game()
	Tutorial.skip()
	Combat.rebuild_heroes()
	var drops := [0, 0, 0, 0, 0, 0]
	Combat.loot_dropped.connect(func(it, _at): drops[int(it.rar)] += 1)
	var wipes := [0]
	Combat.squad_wiped.connect(func(): wipes[0] += 1)
	var warlords := []
	var last_biome := 0
	var last_kills := 0
	var stall := 0
	var dumped := false
	for sec in minutes * 60:
		if sec % 60 == 0:
			await get_tree().process_frame
		Game._simulate(1.0, true)
		Game.active_event = ""
		for k in 10:
			Combat.tick(0.1)
		if sec % 30 == 0:
			Loot.auto_equip_squad()
			# bot: spend scrap like a player would
			if Game.s.vault_level < Data.MAX_VAULT_LEVEL and Game.s.res.scrap >= Game.vault_upgrade_cost():
				Game.upgrade_vault()
				print("[bal] %3dm vault -> Lv.%d" % [sec / 60, Game.s.vault_level])
				if Game.s.vault_level >= 2 and int(Game.s.squad[2]) < 0:
					for d in Game.s.dwellers:
						if Game.squad_role(d) < 0 and int(d.room) != Data.ENGINE_SLOT:
							Game.set_squad(2, int(d.id))
							break
			for it in Loot.stash():
				if Loot.can_enhance(it) == false:
					continue
			# enhance squad weapons when components allow
			for did in Game.s.squad:
				if int(did) >= 0:
					var w := Loot.equipped_on(Game.dweller_by_id(int(did)), "weapon")
					if not w.is_empty() and Loot.can_enhance(w) and Game.can_afford(Loot.enhance_cost(w)):
						Loot.enhance(w)
			Loot.salvage_bulk(0)
			for r in 3:
				while Loot.synth_candidates(r).size() >= 6:
					if Loot.synthesize(r).is_empty():
						break
		if OS.get_cmdline_user_args().has("--debug") and sec > 49 * 60 and sec % 20 == 0 and sec < 53 * 60:
			print("[dbg] %ds active=%s wave_active=%s q=%d en=%d gap=%.1f alive=%d heroes=%d warlord=%s cp=%s xs=%s" % [sec, Combat.active(), Combat.wave_active, Combat.spawn_queue.size(), Combat.enemies.size(), Combat.gap_t, Combat._alive_count(), Combat.heroes.size(), Combat.wave_is_warlord, Game.at_checkpoint(), Combat.enemies.map(func(e): return int(e.x))])
		if int(Game.s.combat.kills) == last_kills:
			stall += 1
		else:
			stall = 0
			last_kills = int(Game.s.combat.kills)
		if stall > 120 and not dumped:
			dumped = true
			print("[stall] %ds wave_active=%s q=%s en=%s gap=%.1f alive=%d warlord=%s cp=%s biome=%d km=%.2f hull=%.1f" % [sec, Combat.wave_active, Combat.spawn_queue, Combat.enemies.size(), Combat.gap_t, Combat._alive_count(), Combat.wave_is_warlord, Game.at_checkpoint(), Game.s.biome, Game.s.km, Game.s.hull])
			for e in Combat.enemies:
				print("[stall]   ", {"x": e.x, "y": e.y, "hp": e.hp, "max": e.max, "kind": e.kind, "stop": e.stop_x, "spd": e.spd, "stun": e.stun, "mob": e.mob})
			for h in Combat.heroes:
				if not h.is_empty():
					print("[stall]   hero ", h.slot, " alive ", h.alive, " hp ", h.hp, " range ", h.st.range, " dmg ", h.st.dmg, " aspd ", h.st.aspd)
		if Game.s.biome != last_biome:
			print("[bal] %3dm ENTER biome %d (%s) lap %d" % [sec / 60, Game.s.biome, Data.biome(Game.s.biome).id, Game.s.lap])
			last_biome = Game.s.biome
		if Combat.wave_is_warlord and (warlords.is_empty() or warlords[-1] != sec / 60):
			warlords.append(sec / 60)
		if sec % 600 == 0 or sec == minutes * 60 - 1:
			var sq := []
			for did in Game.s.squad:
				if int(did) >= 0:
					var d := Game.dweller_by_id(int(did))
					sq.append("%s L%d dps%.0f" % [d.name, d.lvl, Combat.hero_stats(d, Game.squad_role(d)).dps])
			print("[bal] %3dm wave %d (best %d) Lv%d | km %.1f biome %d %s | scrap %d comp %d | stash %d | %s | turretDPS %.0f | wipes %d | block '%s'" % [
				sec / 60, Combat.wave(), Game.s.combat.best, Combat.enemy_level(), Game.s.km, Game.s.biome, "CP" if Game.at_checkpoint() else "",
				Game.s.res.scrap, int(Game.s.items.get("components", 0)), Loot.stash().size(), ", ".join(sq), Combat.van_stats().turret_dps, wipes[0], Game.blocked_reason()])
	print("[bal] drops by rarity: ", drops, "  warlord minutes: ", warlords.slice(0, 20))
	print("[bal] boss_beaten: ", Game.s.combat.boss_beaten, " kills ", Game.s.combat.kills)
	get_tree().quit()
