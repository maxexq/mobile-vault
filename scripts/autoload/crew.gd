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
	"brawler":    {"th": "นักบู๊", "en": "BRAWLER", "icon": "fist", "rooms": [], "aff": 0.0, "desc": "ถ้าเป็นนักสู้ท้ายรถ: HP/ดาเมจ +25%"},
	"tough":      {"th": "ทรหด", "en": "TOUGH", "icon": "hull", "rooms": [], "aff": 0.0, "desc": "HP +30% · ติดเชื้อยากขึ้น 50%"},
	# survival quirks
	"light_eater": {"th": "กินน้อย", "en": "LIGHT EATER", "icon": "food", "rooms": [], "aff": 0.0, "desc": "กินอาหาร/น้ำ -50%"},
	"glutton":    {"th": "กินจุ", "en": "GLUTTON", "icon": "meat", "rooms": [], "aff": 0.0, "bad": true, "desc": "กินอาหาร +60% (แต่อารมณ์ดีง่าย ความสุข +5)"},
	"cold_blooded": {"th": "ทนหนาว", "en": "COLD-PROOF", "icon": "snow", "rooms": [], "aff": 0.0, "desc": "ไม่เป็นอะไรเมื่อหนาวจัด"},
	"rad_proof":  {"th": "ทนรังสี", "en": "RAD-PROOF", "icon": "rad", "rooms": [], "aff": 0.0, "desc": "รับรังสี -60%"},
	"night_owl":  {"th": "คนนอนดึก", "en": "NIGHT OWL", "icon": "moon", "rooms": [], "aff": 0.0, "desc": "ผลิต +30% ตอนกลางคืน"},
	"scavenger":  {"th": "นักคุ้ยซาก", "en": "SCAVENGER", "icon": "explore", "rooms": [], "aff": 0.0, "desc": "ของจากการสำรวจ +30%"},
	"lucky":      {"th": "ดวงดี", "en": "LUCKY", "icon": "xp", "rooms": [], "aff": 0.0, "desc": "สำรวจสำเร็จ +10% · ดรอปของ +10%"},
	"cheerful":   {"th": "ร่าเริง", "en": "CHEERFUL", "icon": "happy", "rooms": [], "aff": 0.0, "desc": "เพื่อนร่วมห้องมีความสุข +10 และผลิต +5%"},
	"grumpy":     {"th": "ขี้บ่น", "en": "GRUMPY", "icon": "sad", "rooms": [], "aff": 0.0, "bad": true, "desc": "ผลิตเอง +15% แต่เพื่อนร่วมห้องความสุข -8"},
	"afraid_dark": {"th": "กลัวความมืด", "en": "FEARS THE DARK", "icon": "moon", "rooms": [], "aff": 0.0, "bad": true, "desc": "ไฟดับ/กลางคืน ความสุขลดหนัก (-16)"},
	"coward":     {"th": "ขี้ขลาด", "en": "COWARD", "icon": "flee", "rooms": [], "aff": 0.0, "bad": true, "desc": "สำรวจเสี่ยงขึ้น 30% แต่ทำงานในรถ +10%"},
	# construction (v4.3) — "build" = extra construction speed while working a building site
	"engineer":   {"th": "วิศวกร", "en": "ENGINEER", "icon": "gear", "rooms": ["workshop"], "aff": 0.2, "build": 0.4, "desc": "ก่อสร้าง/อัปเกรดเร็วขึ้น 40% · โรงช่าง +20%"},
	"quick_hands": {"th": "มือไว", "en": "QUICK HANDS", "icon": "hammer", "rooms": [], "aff": 0.0, "build": 0.25, "desc": "ก่อสร้าง/อัปเกรดเร็วขึ้น 25%"},
	"architect":  {"th": "สถาปนิก", "en": "ARCHITECT", "icon": "int", "rooms": [], "aff": 0.0, "desc": "ออกแบบประหยัดวัสดุ: ค่าสร้าง/อัปเกรดห้อง -15% (มีคนเดียวก็พอ)"},
	"clumsy":     {"th": "ซุ่มซ่าม", "en": "CLUMSY", "icon": "sad", "rooms": [], "aff": 0.0, "bad": true, "build": -0.3, "desc": "ก่อสร้างช้าลง 30% (ค้อนชอบหล่นใส่เท้า)"},
}
## roles: what a refugee did before the fall. Builders (ช่างก่อสร้าง) put rooms up twice as fast.
const ROLES := {
	"builder": {"th": "ช่างก่อสร้าง", "en": "BUILDER", "icon": "hammer", "build": 1.0, "desc": "สร้าง/อัปเกรดห้องเร็วขึ้น 100% · ได้ XP จากงานก่อสร้าง +50%"},
}
const BUILDER_CHANCE := 0.25
## mechanics know their way around a toolbox too
const MECHANIC_BUILD := 0.15
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


func role(d: Dictionary) -> String:
	return str(d.get("role", ""))


func is_builder(d: Dictionary) -> bool:
	return role(d) == "builder"


## construction multiplier of one person (1.0 = an average pair of hands)
func build_mult(d: Dictionary) -> float:
	var m := 1.0 + float(ROLES.get(role(d), {}).get("build", 0.0))
	for t in traits(d):
		m += float(TRAITS[t].get("build", 0.0))
	if has(d, "mechanic"):
		m += MECHANIC_BUILD
	return maxf(0.2, m)


## work seconds this person adds per real second on a building site (STR helps carry beams)
func build_speed(d: Dictionary) -> float:
	return 0.6 * (0.7 + 0.06 * float(d.str)) * build_mult(d)


## the cheapest-build discount: one architect anywhere on board is enough
func build_cost_mult() -> float:
	for d in Game.s.dwellers:
		if has(d, "architect") and not Game.is_away(d):
			return 0.85
	return 1.0


## short "ช่างก่อสร้าง · วิศวกร" tag for cards
func build_tags(d: Dictionary) -> String:
	var parts := []
	if ROLES.has(role(d)):
		parts.append(ROLES[role(d)].th)
	for t in traits(d):
		if TRAITS[t].has("build") or t == "architect":
			parts.append(TRAITS[t].th)
	return " · ".join(parts)


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
	var rt: String = Game.room(slot).type
	var m := 1.0
	var fits := 0
	var night := Game.is_night()
	var pair_div := float(Game.work_span(slot))
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
				# pair bonuses are per seat pair: a large room's 6 crew don't stack them 5x
				if has(o, "cheerful"):
					m += 0.05 / pair_div
				m += Skills.val(o, "mentor") / pair_div
	if fits >= 2:
		m += DUO_BONUS
	if Game.s.has("meta"):
		m += 0.05 * Meta.perk("efficient")
	return m * (1.0 - 0.3 * float(infected_count(workers) > 0) / float(workers.size()))


func synergy_text(slot: int) -> String:
	var workers := Game.room_workers(slot)
	if workers.is_empty():
		return ""
	var rt: String = Game.room(slot).type
	var parts := []
	var fits := 0
	for d in workers:
		for t in traits(d):
			if (TRAITS[t].rooms as Array).has(rt):
				parts.append("%s %s" % [d.name, TRAITS[t].th])
				fits += 1
	if fits >= 2:
		parts.append("ทีมเวิร์ก +%d%%" % int(DUO_BONUS * 100))
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


# ------------------------------------------------------------------ morale: strike -> steal & desert
const STRIKE_AT := 22.0       # happiness below this for 90 s -> strike (stops working)
const STRIKE_END := 38.0      # back to work above this
const DESERT_AT := 10.0       # striking and below this for 3 min (warned at 1 min) -> steals and runs
var _deserters: Array = []


func morale_tick(d: Dictionary, dt: float, offline: bool) -> void:
	var h := float(d.happy)
	if not d.get("strike", false):
		if h < STRIKE_AT:
			d["strike_t"] = float(d.get("strike_t", 0.0)) + dt
			if float(d.strike_t) >= 90.0:
				d["strike"] = true
				d["desert_t"] = 0.0
				Trace.rec("crew", "strike: %s" % d.name, {"happy": snappedf(h, 0.1)})
				if not offline:
					Game.toast.emit("%s ประท้วงหยุดงาน! ขวัญกำลังใจต่ำ (อาหาร/ห้องพัก/งานที่ถนัด/ยา ช่วยได้)" % d.name, "bad")
				Game.dwellers_changed.emit()
		else:
			d["strike_t"] = maxf(0.0, float(d.get("strike_t", 0.0)) - dt)
		return
	if h >= STRIKE_END:
		d["strike"] = false
		d["strike_t"] = 0.0
		d["desert_t"] = 0.0
		d.erase("desert_warn")
		if not offline:
			Game.toast.emit("%s ใจเย็นลงแล้ว เลิกประท้วงกลับมาทำงาน" % d.name, "good")
		Game.dwellers_changed.emit()
		return
	if h < DESERT_AT and not offline:
		d["desert_t"] = float(d.get("desert_t", 0.0)) + dt
		if float(d.desert_t) >= 60.0 and not d.get("desert_warn", false):
			d["desert_warn"] = true
			Game.toast.emit("%s แอบเก็บของใส่เป้... กำลังจะหนี! รีบทำให้มีความสุขขึ้น" % d.name, "bad")
		if float(d.desert_t) >= 180.0 and not _deserters.has(d):
			_deserters.append(d)
	else:
		d["desert_t"] = maxf(0.0, float(d.get("desert_t", 0.0)) - dt * 0.5)


func is_striking(d: Dictionary) -> bool:
	return d.get("strike", false)


## called by Game after the dweller loop (never remove while iterating)
func flush_deserters() -> void:
	for d in _deserters:
		if Game.s.dwellers.has(d):
			desert(d)
	_deserters.clear()


func desert(d: Dictionary) -> void:
	Trace.rec("crew", "deserted: %s" % d.name, {"happy": snappedf(float(d.happy), 0.1)})
	var stolen := []
	for k in ["food", "water", "scrap"]:
		var amt := floorf(float(Game.s.res[k]) * 0.12)
		if amt >= 1.0:
			Game.s.res[k] = float(Game.s.res[k]) - amt
			stolen.append("%s %d" % [Data.item_name(k), int(amt)])
	var comps := int(float(Game.s.items.get("components", 0)) * 0.1)
	if comps > 0:
		Game.s.items.components = int(Game.s.items.components) - comps
		stolen.append("ชิ้นส่วน %d" % comps)
	if int(Game.s.items.get("stimpack", 0)) > 0:
		Game.s.items.stimpack = int(Game.s.items.stimpack) - 1
		stolen.append("สติมแพ็ก 1")
	var role := Game.squad_role(d)
	if role >= 0:
		Game.s.squad[role] = -1
	if not Game.s.has("deserters"):
		Game.s["deserters"] = []
	Game.s.deserters.append({"name": d.name, "lvl": d.lvl, "km": snappedf(float(Game.s.stats.km_total), 0.1), "stole": ", ".join(stolen)})
	Game.s.dwellers.erase(d)     # leaves with the gear on their back
	Game.toast.emit("%s ขโมย %s แล้วหนีลงจากรถไปในความมืด!" % [d.name, ", ".join(stolen) if not stolen.is_empty() else "ของเล็กน้อย"], "bad")
	Game.dwellers_changed.emit()
	Game.squad_changed.emit()
	Game.rooms_changed.emit()
	Game.resources_changed.emit()


func cure(d: Dictionary) -> void:
	d.infection = 0.0


# ------------------------------------------------------------------ death & memorial
func kill(d: Dictionary, cause: String) -> void:
	if Dev.on("invincible") and cause != "ทดสอบระบบ":
		d.hp = d.max_hp
		return
	Trace.rec("crew", "died: %s (%s)" % [d.name, cause], {"lvl": d.lvl})
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
