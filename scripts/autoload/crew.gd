extends Node
## Survivors as people, not just numbers: traits (room affinity, combat, survival quirks), room synergies,
## injuries / infections, deaths and the memorial wall.

const TRAITS := {
	# room specialists  (rooms: production x(1+aff) when working there)
	"mechanic":   {"th": "ช่างเครื่อง", "en": "MECHANIC", "icon": "wrench", "rooms": ["engine", "refinery", "workshop"], "aff": 0.4, "desc": "ห้องเครื่อง/โรงกลั่น/โรงช่าง +40% · ซ่อมตัวถังเร็วขึ้น"},
	"cook":       {"th": "พ่อครัว", "en": "COOK", "icon": "food", "rooms": ["kitchen"], "aff": 0.4, "desc": "ห้องครัว +40%"},
	"green_thumb": {"th": "มือเย็น", "en": "GREEN THUMB", "icon": "seed", "rooms": ["hydroponics"], "aff": 0.45, "desc": "ห้องปลูกพืช +45%"},
	"healer":     {"th": "หมอประจำรถ", "en": "HEALER", "icon": "medkit", "rooms": ["medical"], "aff": 0.4, "desc": "ห้องพยาบาล +40% · ฮีลแรงขึ้น 25%"},
	"hydrologist": {"th": "นักกรองน้ำ", "en": "HYDROLOGIST", "icon": "water", "rooms": ["water"], "aff": 0.4, "desc": "เครื่องกรองน้ำ +40%"},
	"genius":     {"th": "อัจฉริยะ", "en": "GENIUS", "icon": "int", "rooms": ["science", "radio", "workshop"], "aff": 0.35, "desc": "ห้องวิจัย/วิทยุ/โรงช่าง +35% · XP +20%"},
	"gunsmith":   {"th": "ช่างปืน", "en": "GUNSMITH", "icon": "rifle", "rooms": ["armory"], "aff": 0.45, "desc": "ห้องอาวุธ +45%"},
	# combat
	"sharpshooter": {"th": "แม่นปืน", "en": "SHARPSHOOTER", "icon": "rifle", "rooms": [], "aff": 0.0, "desc": "ดาเมจ +20% · คริติคอล +10%"},
	"brawler":    {"th": "นักบู๊", "en": "BRAWLER", "icon": "fist", "rooms": [], "aff": 0.0, "desc": "เป็นนักสู้ท้ายรถ: HP/ดาเมจ +25%"},
	"tough":      {"th": "ทรหด", "en": "TOUGH", "icon": "hull", "rooms": [], "aff": 0.0, "desc": "HP +30% · ติดเชื้อยากขึ้น 50%"},
	# survival quirks
	"light_eater": {"th": "กินน้อย", "en": "LIGHT EATER", "icon": "food", "rooms": [], "aff": 0.0, "desc": "กินอาหาร/น้ำ -50%"},
	"glutton":    {"th": "กินจุ", "en": "GLUTTON", "icon": "meat", "rooms": [], "aff": 0.0, "bad": true, "desc": "กินอาหาร +60% (แต่มีความสุขง่าย +5)"},
	"cold_blooded": {"th": "ทนหนาว", "en": "COLD-PROOF", "icon": "snow", "rooms": [], "aff": 0.0, "desc": "ไม่เป็นอะไรเมื่อหนาวจัด"},
	"rad_proof":  {"th": "ทนรังสี", "en": "RAD-PROOF", "icon": "rad", "rooms": [], "aff": 0.0, "desc": "รับรังสี -60%"},
	"night_owl":  {"th": "นกฮูก", "en": "NIGHT OWL", "icon": "moon", "rooms": [], "aff": 0.0, "desc": "ผลิต +30% ตอนกลางคืน"},
	"scavenger":  {"th": "นักคุ้ยซาก", "en": "SCAVENGER", "icon": "explore", "rooms": [], "aff": 0.0, "desc": "ของจากการสำรวจ +30%"},
	"lucky":      {"th": "ดวงดี", "en": "LUCKY", "icon": "xp", "rooms": [], "aff": 0.0, "desc": "สำรวจสำเร็จ +10% · ดรอปของ +10%"},
	"cheerful":   {"th": "ร่าเริง", "en": "CHEERFUL", "icon": "happy", "rooms": [], "aff": 0.0, "desc": "เพื่อนร่วมห้องมีความสุข +10 และผลิต +5%"},
	"grumpy":     {"th": "ขี้บ่น", "en": "GRUMPY", "icon": "sad", "rooms": [], "aff": 0.0, "bad": true, "desc": "ผลิตเอง +15% แต่เพื่อนร่วมห้องความสุข -8"},
	"coward":     {"th": "ขี้ขลาด", "en": "COWARD", "icon": "flee", "rooms": [], "aff": 0.0, "bad": true, "desc": "สำรวจเสี่ยงขึ้น 30% แต่ทำงานในรถ +10%"},
}
## named crew have fixed traits (fits their bios)
const FIXED := {"mark": ["brawler", "tough"], "leo": ["sharpshooter", "scavenger"], "ton": ["mechanic", "night_owl"],
	"bob": ["cook", "glutton"], "clara": ["healer", "cheerful"], "bruno": ["brawler", "light_eater"]}
## two workers in the same room whose traits both fit it -> teamwork bonus
const DUO_BONUS := 0.15

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


func roll_traits(d: Dictionary) -> void:
	var k := str(d.get("lore", ""))
	if FIXED.has(k):
		d["traits"] = (FIXED[k] as Array).duplicate()
		return
	var keys := TRAITS.keys()
	var out := []
	var n := 2 if rng.randf() < 0.65 else 1
	while out.size() < n:
		var t: String = keys[rng.randi() % keys.size()]
		if out.has(t):
			continue
		if TRAITS[t].get("bad", false) and out.size() == 0 and rng.randf() < 0.5:
			continue
		out.append(t)
	d["traits"] = out


func traits(d: Dictionary) -> Array:
	if not d.has("traits"):
		roll_traits(d)
	return d.traits


func has(d: Dictionary, t: String) -> bool:
	return traits(d).has(t)


func affinity(d: Dictionary, room_type: String) -> float:
	var a := 0.0
	for t in traits(d):
		if (TRAITS[t].rooms as Array).has(room_type):
			a += float(TRAITS[t].aff)
	return a * (2.0 if Skills.rank(d, "p5") > 0 else 1.0)


## production multiplier for a room from its workers' traits, synergies and skills
func room_mult(slot: int) -> float:
	var workers := Game.room_workers(slot)
	if workers.is_empty():
		return 1.0
	var rt: String = Game.s.rooms[slot].type
	var m := 1.0
	var fits := 0
	var night := Game.is_night()
	for d in workers:
		var a := affinity(d, rt)
		if a > 0.0:
			fits += 1
		m += a / float(workers.size())
		if has(d, "grumpy"):
			m += 0.15 / float(workers.size())
		if has(d, "coward"):
			m += 0.10 / float(workers.size())
		if night and has(d, "night_owl"):
			m += 0.30 / float(workers.size())
		m += Skills.val(d, "prod") / float(workers.size())
		for o in workers:
			if o != d:
				if has(o, "cheerful"):
					m += 0.05
				m += Skills.val(o, "mentor")
	if fits >= 2:
		m += DUO_BONUS
	if Game.s.has("meta"):
		m += 0.05 * Meta.perk("efficient")
	return m * (1.0 - 0.3 * float(infected_count(workers) > 0) / float(workers.size()))


func synergy_text(slot: int) -> String:
	var workers := Game.room_workers(slot)
	if workers.is_empty():
		return ""
	var rt: String = Game.s.rooms[slot].type
	var parts := []
	var fits := 0
	for d in workers:
		for t in traits(d):
			if (TRAITS[t].rooms as Array).has(rt):
				parts.append("%s %s" % [d.name, TRAITS[t].th])
				fits += 1
	if fits >= 2:
		parts.append("ทีมเวิร์ค +%d%%" % int(DUO_BONUS * 100))
	return " · ".join(parts)


func food_mult(d: Dictionary) -> float:
	var m := 1.0
	if has(d, "light_eater"):
		m *= 0.5
	if has(d, "glutton"):
		m *= 1.6
	m *= 1.0 - Skills.val(d, "stomach")
	return m


func happy_aura(d: Dictionary) -> float:
	## happiness modifier from roommates + own quirks
	var h := 0.0
	if has(d, "glutton"):
		h += 5.0
	var slot := int(d.room)
	if slot < 0:
		return h
	for o in Game.room_workers(slot):
		if o == d:
			continue
		if has(o, "cheerful"):
			h += 10.0
		if has(o, "grumpy"):
			h -= 8.0
	return h


# ------------------------------------------------------------------ status: injury / infection
func is_infected(d: Dictionary) -> bool:
	return float(d.get("infection", 0.0)) > 0.0


func infected_count(arr: Array) -> int:
	var n := 0
	for d in arr:
		if is_infected(d):
			n += 1
	return n


func infect(d: Dictionary, amount: float) -> void:
	d["infection"] = minf(100.0, float(d.get("infection", 0.0)) + amount)


## per-minute tick for one present dweller; returns true if something changed visibly
func tick(d: Dictionary, m: float, medical_power: float) -> void:
	var inf := float(d.get("infection", 0.0))
	if inf > 0.0:
		d.hp = maxf(1.0, float(d.hp) - 0.04 * inf * m)
		var cure := (0.6 + medical_power * 1.2) * (1.0 + Skills.val(d, "medic"))
		d.infection = maxf(0.0, inf - cure * m)


func cure(d: Dictionary) -> void:
	d.infection = 0.0


# ------------------------------------------------------------------ death & memorial
func kill(d: Dictionary, cause: String) -> void:
	for slot in Loot.HERO_SLOTS:
		var it := Loot.equipped_on(d, slot)
		if not it.is_empty():
			Loot.add_to_stash(it)
	var role := Game.squad_role(d)
	if role >= 0:
		Game.s.squad[role] = -1
	if not Game.s.has("memorial"):
		Game.s["memorial"] = []
	Game.s.memorial.append({"name": d.name, "lvl": d.lvl, "cause": cause, "km": snappedf(float(Game.s.stats.km_total), 0.1),
		"gen": Meta.generation(), "variant": d.variant})
	Game.s.dwellers.erase(d)
	Game.dwellers_changed.emit()
	Game.squad_changed.emit()
	Game.rooms_changed.emit()
