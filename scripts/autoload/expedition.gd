extends Node
## Expedition teams: when the truck reaches a landmark it parks, a team (1-3 survivors) walks out with the
## supplies you pack, explores in idle time, and walks back — if they make it. Rewards: blueprints, rare
## gear, fuel, components; risks: injuries, infections, death.

signal site_reached(site_id: String)
signal expedition_started
signal expedition_finished(report: Dictionary)

const MAX_TEAM := 3
const MIN_TEAM := 2         # a scavenging squad is 2-3 survivors (1 if that is all you have)
const WALK_SEC := 7.0          # visual walk out / back inside the total duration
## landmarks along each biome (at = fraction of the biome length)
const SITES := {
	"market": {"biome": "industrial", "at": 0.2, "th": "ซูเปอร์มาร์เก็ตร้าง", "en": "DEAD SUPERMARKET", "sprite": "lm_market", "danger": 1, "min": 2.5,
		"goal": "กวาดอาหารกระป๋องและน้ำขวดจากชั้นวาง", "loot": {"res": {"food": 80, "water": 60, "scrap": 30}, "items": {"ammo": 4}, "gear": 1, "bp": ["bp_engine_tune"]}},
	"hospital": {"biome": "industrial", "at": 0.45, "th": "โรงพยาบาลร้าง", "en": "ABANDONED HOSPITAL", "sprite": "lm_hospital", "danger": 1, "min": 3.0,
		"goal": "ค้นหายาและเวชภัณฑ์ในตึกผู้ป่วยใน", "loot": {"res": {"scrap": 60}, "items": {"stimpack": 3, "antibiotics": 2}, "gear": 1, "bp": ["bp_air_filter"]}},
	"depot": {"biome": "industrial", "at": 0.85, "th": "คลังแสงทหาร", "en": "MILITARY DEPOT", "sprite": "lm_depot", "danger": 2, "min": 4.0,
		"goal": "เจาะคลังอาวุธที่ถูกปิดตาย", "loot": {"res": {"scrap": 90}, "items": {"ammo": 10, "components": 15}, "gear": 2, "rare": 1, "bp": ["bp_bus", "bp_roof_turret", "bp_workshop"]}},
	"gas_stop": {"biome": "desert", "at": 0.35, "th": "ปั๊มน้ำมันกลางทราย", "en": "DUNE GAS STOP", "sprite": "lm_gas", "danger": 2, "min": 3.5,
		"goal": "สูบน้ำมันที่เหลือในถังใต้ดิน", "loot": {"res": {"fuel": 120, "scrap": 40}, "items": {"components": 8}, "gear": 1, "bp": ["bp_refinery"]}},
	"sat_base": {"biome": "desert", "at": 0.8, "th": "สถานีจานดาวเทียม", "en": "SATELLITE ARRAY", "sprite": "lm_dish", "danger": 3, "min": 5.0,
		"goal": "ถอดแผงโซลาร์และวงจรจากจานยักษ์", "loot": {"res": {"scrap": 120, "power": 60}, "items": {"components": 25}, "gear": 1, "rare": 1, "bp": ["bp_solar_covers"], "lore": "signal"}},
	"ranger": {"biome": "forest", "at": 0.4, "th": "หอดูไฟป่า", "en": "RANGER TOWER", "sprite": "lm_tower", "danger": 3, "min": 4.0,
		"goal": "ค้นวิทยุและแผนที่ของเจ้าหน้าที่ป่า", "loot": {"res": {"food": 60, "water": 40, "scrap": 80}, "gear": 2, "recruit": 0.5, "bp": ["bp_heater"]}},
	"lab": {"biome": "forest", "at": 0.8, "th": "สถานีวิจัยใต้ร่มไม้", "en": "CANOPY LAB", "sprite": "lm_lab", "danger": 4, "min": 5.0,
		"goal": "กู้ข้อมูลวิจัยพืชกลายพันธุ์", "loot": {"res": {"scrap": 140}, "items": {"radaway": 3, "components": 25}, "gear": 2, "rare": 2, "bp": ["bp_repair_bay"]}},
	"chem_plant": {"biome": "swamp", "at": 0.4, "th": "โรงงานเคมีรั่ว", "en": "LEAKING CHEM PLANT", "sprite": "lm_chem", "danger": 5, "min": 5.0,
		"goal": "ปิดวาล์วที่รั่วและเก็บแผ่นตะกั่ว", "loot": {"res": {"scrap": 160, "fuel": 60}, "items": {"radaway": 4, "components": 30}, "gear": 2, "rare": 2, "bp": ["bp_rig", "bp_rad_shield"]}},
	"stilt_town": {"biome": "swamp", "at": 0.8, "th": "หมู่บ้านบนเสา", "en": "STILT VILLAGE", "sprite": "lm_stilt", "danger": 4, "min": 4.5,
		"goal": "ค้นหาผู้รอดชีวิตที่ติดอยู่", "loot": {"res": {"food": 90, "water": 90}, "items": {"antibiotics": 2}, "gear": 1, "recruit": 0.9}},
	"polar": {"biome": "tundra", "at": 0.4, "th": "สถานีวิจัยขั้วโลก", "en": "POLAR STATION", "sprite": "lm_polar", "danger": 6, "min": 6.0,
		"goal": "ขุดรถลุยหิมะที่จมอยู่ในโรงจอด", "loot": {"res": {"fuel": 150, "scrap": 200}, "items": {"components": 40}, "gear": 2, "rare": 2, "bp": ["bp_tracks", "bp_trailer"]}},
	"mine": {"biome": "tundra", "at": 0.8, "th": "เหมืองแร่ร้าง", "en": "FROZEN MINE", "sprite": "lm_mine", "danger": 6, "min": 6.0,
		"goal": "ขนแร่และชิ้นส่วนเครื่องจักรขึ้นมา", "loot": {"res": {"scrap": 320, "fuel": 80}, "items": {"components": 60}, "gear": 2, "rare": 3}},
	"mall": {"biome": "metro", "at": 0.35, "th": "ห้างสรรพสินค้ายักษ์", "en": "MEGA MALL", "sprite": "lm_mall", "danger": 6, "min": 6.0,
		"goal": "กวาดทุกอย่างที่ยังใช้ได้", "loot": {"res": {"food": 120, "water": 120, "scrap": 300}, "items": {"stimpack": 5, "antibiotics": 3}, "gear": 3, "rare": 2}},
	"helios": {"biome": "metro", "at": 0.8, "th": "หอคอย HELIOS", "en": "HELIOS SPIRE", "sprite": "lm_spire", "danger": 7, "min": 8.0,
		"goal": "ขึ้นไปถึงห้องควบคุมของ OVERSEER", "loot": {"res": {"scrap": 500, "power": 120}, "items": {"components": 90}, "gear": 3, "rare": 3, "bp": ["bp_train"], "lore": "overseer"}},
}
const SUPPLY_KEYS := ["food", "water", "stimpack", "ammo", "antibiotics"]

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


# ------------------------------------------------------------------ route / landmarks
func site_km(id: String) -> float:
	var s: Dictionary = SITES[id]
	for i in Data.BIOMES.size():
		if Data.BIOMES[i].id == s.biome:
			return Data.biome_start_km(i) + float(Data.BIOMES[i].length) * float(s.at)
	return 0.0


func done_key(id: String) -> String:
	return "%d:%s" % [int(Game.s.get("lap", 0)), id]


func is_done(id: String) -> bool:
	return Game.s.get("sites_done", {}).has(done_key(id))


func mark_done(id: String) -> void:
	if not Game.s.has("sites_done"):
		Game.s["sites_done"] = {}
	Game.s.sites_done[done_key(id)] = true


## next unvisited landmark crossed when moving from km0 to km1 (or "")
func crossed(km0: float, km1: float) -> String:
	for id in SITES:
		var k := site_km(id)
		if k > km0 and k <= km1 and not is_done(id):
			return id
	return ""


func biome_sites(biome_index: int) -> Array:
	var b: String = Data.biome(biome_index).id
	var out := []
	for id in SITES:
		if SITES[id].biome == b:
			out.append(id)
	return out


func at_site() -> String:
	return str(Game.s.get("at_site", ""))


func arrive(id: String) -> void:
	Game.s["at_site"] = id
	Game.s.km = site_km(id)
	site_reached.emit(id)
	Game.travel_changed.emit()


func skip_site() -> void:
	var id := at_site()
	if id != "":
		mark_done(id)
	Game.s["at_site"] = ""
	Game.travel_changed.emit()


## generic scavenging around the current spot (no landmark needed)
func scav_def() -> Dictionary:
	var b: Dictionary = Data.biome(int(Game.s.biome))
	return {"th": "สำรวจรอบๆ " + b.th, "en": "SCAVENGE AREA", "sprite": "", "danger": maxi(1, int(b.danger) - 1), "min": 2.5,
		"goal": "ค้นซากรถและบ้านร้างข้างทาง", "loot": {"res": {"scrap": 30 + 15 * int(b.danger), "food": 15, "water": 15, "fuel": 10}, "gear": 1}}


func site_def(id: String) -> Dictionary:
	return SITES[id] if SITES.has(id) else scav_def()


# ------------------------------------------------------------------ expedition state
func active() -> bool:
	return Game.s.has("exp") and not (Game.s.exp as Dictionary).is_empty()


func state() -> Dictionary:
	return Game.s.get("exp", {})


func duration_sec(id: String) -> float:
	return float(site_def(id).min) * 60.0 * (1.0 + 0.1 * int(Game.s.get("lap", 0)))


func progress() -> float:
	if not active():
		return 0.0
	var e := state()
	return clampf((Time.get_unix_time_from_system() - float(e.start)) / float(e.dur), 0.0, 1.0)


func time_left() -> float:
	if not active():
		return 0.0
	var e := state()
	return maxf(0.0, float(e.start) + float(e.dur) - Time.get_unix_time_from_system())


func team() -> Array:
	var out := []
	for id in state().get("team", []):
		var d := Game.dweller_by_id(int(id))
		if not d.is_empty():
			out.append(d)
	return out


## recommended packs per member for the trip
func need_supplies(id: String, n: int) -> Dictionary:
	var mins := duration_sec(id) / 60.0
	return {"food": ceilf(mins * 1.5 * n), "water": ceilf(mins * 1.5 * n)}


func team_power(members: Array, sup: Dictionary) -> float:
	var p := Game.armory_bonus() * 0.5
	for d in members:
		p += Combat.hero_power(d)
	p += float(sup.get("ammo", 0)) * 1.2 + float(sup.get("stimpack", 0)) * 2.0
	return p


func danger_need(id: String) -> float:
	return 8.0 + float(site_def(id).danger) * 7.0 * (1.0 + 0.2 * int(Game.s.get("lap", 0)))


func success_chance(id: String, members: Array, sup: Dictionary) -> float:
	if members.is_empty():
		return 0.0
	var ratio := team_power(members, sup) / danger_need(id)
	var c := 0.2 + 0.55 * ratio
	var need := need_supplies(id, members.size())
	var fed := minf(float(sup.get("food", 0)) / maxf(1.0, need.food), float(sup.get("water", 0)) / maxf(1.0, need.water))
	c -= 0.3 * (1.0 - clampf(fed, 0.0, 1.0))
	for d in members:
		if Crew.has(d, "lucky"):
			c += 0.1
		if Crew.has(d, "coward"):
			c -= 0.08
		c += 0.2 * Skills.val(d, "survivor") / members.size()
	return clampf(c, 0.05, 0.97)


func min_team() -> int:
	var avail := 0
	for d in Game.s.dwellers:
		if not Game.is_away(d):
			avail += 1
	return clampi(avail - 1, 1, MIN_TEAM)     # never strip the truck completely


func start(id: String, ids: Array, sup: Dictionary) -> bool:
	if active() or ids.size() < min_team():
		return false
	var cost := {}
	for k in sup:
		if int(sup[k]) > 0:
			cost[k] = int(sup[k])
	if not cost.is_empty() and not Game.pay(cost):
		return false
	var dur := duration_sec(id)
	var now := Time.get_unix_time_from_system()
	for did in ids:
		var d := Game.dweller_by_id(int(did))
		if d.is_empty():
			continue
		d.away_until = now + dur
		d["exp"] = true
		d.room = -1
		var role := Game.squad_role(d)
		if role >= 0:
			Game.s.squad[role] = -1
	Game.s["exp"] = {"site": id, "team": ids.duplicate(), "sup": sup.duplicate(), "start": now, "dur": dur, "log": [], "seed": randi()}
	Game.toast.emit("ทีมสำรวจออกเดินทางไป %s — รถจอดรอจนกว่าทีมจะกลับ" % site_def(id).th, "info")
	expedition_started.emit()
	Game.squad_changed.emit()
	Game.dwellers_changed.emit()
	Game.rooms_changed.emit()
	Game.travel_changed.emit()
	return true


## called every simulation step; resolves when the timer runs out (also offline)
func tick(offline: bool) -> void:
	if not active():
		return
	if Time.get_unix_time_from_system() >= float(state().start) + float(state().dur):
		finish(offline)


func finish(offline: bool) -> Dictionary:
	var e := state()
	var id: String = e.site
	var def := site_def(id)
	var members := team()
	var sup: Dictionary = e.sup
	var chance := success_chance(id, members, sup)
	var ok := rng.randf() < chance
	var ratio := team_power(members, sup) / danger_need(id)
	var rep := {"site": id, "ok": ok, "chance": chance, "lines": [], "dead": [], "loot": ""}
	# ---- casualties
	for d in members:
		d.away_until = 0.0
		d.erase("exp")
		var stim := float(sup.get("stimpack", 0)) / maxf(1.0, members.size())
		var inj := clampf((0.45 if not ok else 0.25) - 0.15 * ratio - 0.12 * stim, 0.03, 0.7)
		var inf_c := clampf(0.04 * float(def.danger) * (1.6 if not ok else 1.0) - 0.15 * float(sup.get("antibiotics", 0)), 0.0, 0.6)
		if Crew.has(d, "tough"):
			inf_c *= 0.5
		inf_c *= 1.0 - minf(0.6, Skills.val(d, "medic"))
		var death := 0.0
		if not ok:
			death = clampf(0.22 - 0.12 * ratio, 0.02, 0.3)
			if Crew.has(d, "coward"):
				death *= 1.3
			if Skills.rank(d, "s5") > 0:
				death *= 0.4
			if float(d.hp) < float(d.max_hp) * 0.35:
				death *= 1.5
		if rng.randf() < death:
			rep.dead.append(d.name)
			rep.lines.append("%s ไม่ได้กลับมา..." % d.name)
			Crew.kill(d, "สำรวจ " + str(def.th))
			continue
		if rng.randf() < inj:
			var dmg := float(d.max_hp) * rng.randf_range(0.25, 0.6)
			d.hp = maxf(1.0, float(d.hp) - dmg)
			rep.lines.append("%s บาดเจ็บ (HP -%d)" % [d.name, int(dmg)])
		if rng.randf() < inf_c:
			Crew.infect(d, rng.randf_range(30.0, 70.0))
			rep.lines.append("%s ติดเชื้อ! (รักษาที่ห้องพยาบาล/ยาปฏิชีวนะ)" % d.name)
		Game.give_xp(d, 10.0 + 8.0 * float(def.danger), "", offline)
	# ---- loot
	var loot: Dictionary = def.loot
	var mult := (1.0 if ok else 0.3) * (1.0 + 0.15 * int(Game.s.get("lap", 0)))
	for d in members:
		if Crew.has(d, "scavenger"):
			mult += 0.3 / members.size()
		mult += Skills.val(d, "scav") / members.size()
		var bp := Loot.equipped_on(d, "backpack")
		mult += (Loot.base_stat(bp, "supply") + Loot.sum_key([bp], "supply")) / 300.0
	var rew := {}
	for k in loot.get("res", {}):
		rew[k] = int(float(loot.res[k]) * mult)
	for k in loot.get("items", {}):
		var n := int(round(float(loot.items[k]) * mult))
		if n > 0:
			rew[k] = n
	var got := Game.give_rewards(rew)
	var gear_n := int(loot.get("gear", 0)) if ok else 0
	for i in gear_n:
		var it := Loot.roll_random(Combat.enemy_level(), 20.0, int(loot.get("rare", 0)))
		Loot.add_to_stash(it)
		got += ", %s [%s]" % [Loot.item_name(it), Loot.rarity(int(it.rar)).th]
	if gear_n > 0:
		Game.gear_changed.emit()
	if ok:
		for b in loot.get("bp", []):
			if not Meta.has_blueprint(b):
				Meta.add_blueprint(b)
				got += ", พิมพ์เขียว: " + Mods.BLUEPRINT_TH.get(b, b)
				break   # one new blueprint per trip
		if rng.randf() < float(loot.get("recruit", 0.0)) and Game.s.dwellers.size() < Game.pop_cap():
			var nd := Game.recruit_random()
			got += ", ผู้รอดชีวิต " + nd.name
		if loot.has("lore") and Lore.unlock(str(loot.lore)):
			got += ", บันทึกใหม่"
	rep.loot = got
	if SITES.has(id):
		mark_done(id)
		Game.s["at_site"] = ""
	Game.s.exp = {}
	Game.s.stats["expeditions"] = int(Game.s.stats.get("expeditions", 0)) + 1
	if not offline:
		Game.toast.emit(("ทีมสำรวจกลับมาแล้ว! " if ok else "ภารกิจล้มเหลว... ") + got, "good" if ok else "bad")
	expedition_finished.emit(rep)
	Game.dwellers_changed.emit()
	Game.rooms_changed.emit()
	Game.travel_changed.emit()
	return rep
