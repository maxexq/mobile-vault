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
## MV-170: chance that an ordinary (non-builder) recruit is one of the 20 named crew (tune crew.roster_chance),
## and how likely a cameo guest is next to an original (tune crew.cameo_weight; 1 = same weight)
const ROSTER_CHANCE := 0.35
const CAMEO_WEIGHT := 0.5
## mechanics know their way around a toolbox too
const MECHANIC_BUILD := 0.15
## named crew have fixed traits (fits their bios)
const FIXED := {"mark": ["brawler", "tough"], "leo": ["sharpshooter", "scavenger"], "ton": ["mechanic", "night_owl"],
	"bob": ["cook", "glutton"], "clara": ["healer", "cheerful"], "bruno": ["brawler", "light_eater"]}
## MV-516: with trait_roll_weights on, a recruit's traits are drawn by MV-497 tier (common .. legendary) instead of
## evenly; every trade-off has one flat weight, which keeps the share of recruits with a downside as before (~23 %).
## Tune crew.trait_weight.<tier> / crew.trait_weight.trade_off
const TIER_NAMES := ["common", "uncommon", "rare", "epic", "legendary"]
const TRAIT_WEIGHTS := [10.0, 7.0, 4.0, 2.0, 1.0]
const TRADE_OFF_WEIGHT := 5.0
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
		var t := _pick_trait(keys)
		if out.has(t):
			continue
		if TRAITS[t].get("bad", false) and out.size() == 0 and rng.randf() < 0.5:
			continue
		out.append(t)
	d["traits"] = out


## MV-483 / MV-497: the visual tier of each trait card (0 common .. 5 mythic). Explicit and approved only: nothing is
## inferred from item rarity, the bad flag, the size of a bonus or a roll. MV-497: a benefit's tier = how much it is
## worth to a run (narrow / situational = common .. whole-vehicle or loot-economy effects = legendary; mythic is kept
## for future unique traits); a trade-off's tier = how hard its cost bites (a crimson edge that grows with the risk).
## Switch trait_tiers off (or a trait not listed) = the quiet untiered card. Visual only: no stat, spawn or save uses it.
const TRAIT_TIERS := {
	# common: only in one biome / at night / a small build bonus
	"cold_blooded": 0, "night_owl": 0, "rad_proof": 0, "quick_hands": 0,
	# uncommon: one room +40-45 %, or halved upkeep for one survivor
	"cook": 1, "hydrologist": 1, "green_thumb": 1, "gunsmith": 1, "light_eater": 1,
	# rare: several rooms or a second effect, a sturdier body, better expedition loot, the rear-gunner bonus
	"mechanic": 2, "healer": 2, "tough": 2, "scavenger": 2, "brawler": 2,
	# epic: always-on combat power, three rooms + XP, faster construction, morale for the whole room (MV-127)
	"sharpshooter": 3, "genius": 3, "engineer": 3, "cheerful": 3,
	# legendary: cheaper rooms for the whole vehicle, better odds on every expedition and drop
	"architect": 4, "lucky": 4,
	# trade-offs: mild and avoidable (common), costly (uncommon), unavoidable every night, can break morale (rare)
	"grumpy": 0, "coward": 0, "glutton": 1, "clumsy": 1, "afraid_dark": 2,
}


func trait_tier(t: String) -> int:
	if not Features.on("trait_tiers"):
		return -1
	return int(TRAIT_TIERS.get(t, -1))


## MV-516: how likely trait t is to be drawn (relative). Uses TRAIT_TIERS directly, not trait_tier(): hiding the tier
## labels (trait_tiers off) doesn't change the odds. A trait without a tier draws like a common one
func trait_weight(t: String) -> float:
	if not Features.on("trait_roll_weights"):
		return 1.0
	if TRAITS[t].get("bad", false):
		return maxf(0.0, Features.num("crew.trait_weight.trade_off", TRADE_OFF_WEIGHT))
	var tier := clampi(int(TRAIT_TIERS.get(t, 0)), 0, TIER_NAMES.size() - 1)
	return maxf(0.0, Features.num("crew.trait_weight." + TIER_NAMES[tier], TRAIT_WEIGHTS[tier]))


func _pick_trait(keys: Array) -> String:
	if not Features.on("trait_roll_weights"):
		return keys[rng.randi() % keys.size()]
	var total := 0.0
	for t in keys:
		total += trait_weight(t)
	if total <= 0.0:
		return keys[rng.randi() % keys.size()]
	var r := rng.randf() * total
	for t in keys:
		r -= trait_weight(t)
		if r < 0.0:
			return t
	return keys[-1]


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
	return 0.6 * (0.7 + 0.06 * float(d.str)) * build_mult(d) * work_mult(d)


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
## `w`: the room's Game.room_workers() when the caller already has them (MV-562)
func room_mult(slot: int, w: Variant = null) -> float:
	var workers: Array = Game.room_workers(slot) if w == null else w
	if workers.is_empty():
		return 1.0
	var rt: String = Game.room(slot).type
	var m := 1.0
	var fits := 0
	var night := Game.is_night()
	var pair_div := float(Game.work_span(slot))
	# MV-562: each partner's pair bonus is looked up once, not once per other worker (same sums, same order)
	var cheer := []
	var mentor := []
	for o in workers:
		cheer.append(has(o, "cheerful"))
		mentor.append(Skills.val(o, "mentor"))
	for i in workers.size():
		var d: Dictionary = workers[i]
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
		for j in workers.size():
			if j != i:
				# pair bonuses are per seat pair: a large room's 6 crew don't stack them 5x
				if cheer[j]:
					m += 0.05 / pair_div
				m += float(mentor[j]) / pair_div
	if fits >= 2:
		m += DUO_BONUS
	if Game.s.has("meta"):
		m += 0.05 * Meta.perk("efficient")
	var dep := 0.0       # MV-127: a depressed worker puts in morale.work of their share
	for d in workers:
		dep += 1.0 - work_mult(d)
	return m * (1.0 - 0.3 * float(infected_count(workers) > 0) / float(workers.size())) * (1.0 - dep / float(workers.size()))


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
	if v2():
		_morale_v2_tick(d, dt, offline)
		return
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
			if v2() and str(d.get("mood", "")) == MOOD_BROKEN:
				leave_quietly(d)       # MV-127: no stealing
			else:
				desert(d)
	_deserters.clear()


func desert(d: Dictionary) -> void:
	Trace.rec("crew", "deserted: %s" % d.name, {"happy": snappedf(float(d.happy), 0.1)})
	var stolen := []
	for k in ["food", "water", "scrap", "meat"]:
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


# ------------------------------------------------------------------ MV-127 morale v2: Depressed → Broken → leaves
## Switch morale_v2 (off = the strike / desert rules above, unchanged). Stages come from happiness, with a gap before
## they clear: DEPRESSED below morale.depressed 35 (clears at 42): works at morale.work 70 % (room output share and
## build speed). BROKEN below morale.broken 20 for 90 s (clears at 30): reuses the strike flag (no work, the crying
## pose), moves to the first quarters (idle without one; their room is remembered and they go back when they
## recover and it has a seat), leaves the defence squad and refuses orders (Crew.refuses: room, squad, expedition,
## Saloon). Still Broken after morale.leave_sec 180 s (warned at 60 s): they leave the vehicle at NIGHT, taking only
## the gear they wear (no stealing). Desertion never happens offline, like before.
## TALK: a present, untroubled crew member (best INT first, not in the squad, not already talking, pair not on
## cooldown) talks a DEPRESSED / BROKEN one up: +morale.talk_gain 10 happiness (+0.5 per INT above 5, 8..15) right
## away; the talker stops working for morale.talk_sec 60 s; the pair waits morale.talk_cd 300 s. Saved: d.mood,
## d.mood_room, d.talk_t, Game.s.morale.talk_cd. GOD → ลูกเรือ. Autotest --only=morale.
const MOOD_OK := ""
const MOOD_DEPRESSED := "depressed"
const MOOD_BROKEN := "broken"
const MOOD_TH := {"": "ปกติ", "depressed": "หดหู่", "broken": "ใจสลาย"}


func v2() -> bool:
	return Features.on("morale_v2")


func mood(d: Dictionary) -> String:
	return str(d.get("mood", "")) if v2() else MOOD_OK


func is_depressed(d: Dictionary) -> bool:
	return mood(d) == MOOD_DEPRESSED


func is_broken(d: Dictionary) -> bool:
	return mood(d) == MOOD_BROKEN


## a Broken crew member won't take orders (room, squad, expedition, Saloon)
func refuses(d: Dictionary) -> bool:
	return is_broken(d)


func refuse_toast(d: Dictionary) -> void:
	Game.toast.emit(Loc.t("%s ใจสลาย ไม่รับคำสั่ง ลองหาคนไปคุยปลอบใจ") % d.name, "warn")


## share of normal work a crew member puts in (room output, building)
func work_mult(d: Dictionary) -> float:
	return Features.num("morale.work", 0.7) if is_depressed(d) else 1.0


## talking someone up: they are off work for a minute
func busy(d: Dictionary) -> bool:
	return v2() and float(d.get("talk_t", 0.0)) > 0.0


func _morale_v2_tick(d: Dictionary, dt: float, offline: bool) -> void:
	var h := float(d.happy)
	var m := str(d.get("mood", ""))
	if m != MOOD_BROKEN:
		if h < Features.num("morale.broken", 20.0):
			d["strike_t"] = float(d.get("strike_t", 0.0)) + dt
			if float(d.strike_t) >= 90.0:
				_set_broken(d, offline)
				return
		else:
			d["strike_t"] = maxf(0.0, float(d.get("strike_t", 0.0)) - dt)
		var dep := h < Features.num("morale.depressed", 35.0) or (m == MOOD_DEPRESSED and h < Features.num("morale.depressed_clear", 42.0))
		if dep and m != MOOD_DEPRESSED:
			d["mood"] = MOOD_DEPRESSED
			Trace.rec("crew", "depressed: %s" % d.name, {"happy": snappedf(h, 0.1)})
			if not offline:
				Game.toast.emit(Loc.t("%s หดหู่ ทำงานช้าลง (คุยปลอบใจ ห้องพัก อาหาร ช่วยได้)") % d.name, "warn")
			Game.dwellers_changed.emit()
		elif not dep and m == MOOD_DEPRESSED:
			d["mood"] = MOOD_OK
			if not offline:
				Game.toast.emit(Loc.t("%s ดีขึ้นแล้ว กลับมาทำงานเต็มที่") % d.name, "good")
			Game.dwellers_changed.emit()
		return
	# BROKEN
	if h >= Features.num("morale.broken_clear", 30.0):
		_clear_broken(d, offline)
		return
	if offline:
		return
	d["desert_t"] = float(d.get("desert_t", 0.0)) + dt
	var leave := Features.num("morale.leave_sec", 180.0)
	if float(d.desert_t) >= leave / 3.0 and not d.get("desert_warn", false):
		d["desert_warn"] = true
		Game.toast.emit(Loc.t("%s เก็บของใส่เป้... คืนนี้อาจลงจากรถไป! รีบคุยปลอบใจ") % d.name, "bad")
	if float(d.desert_t) >= leave and Game.is_night() and not _deserters.has(d):
		_deserters.append(d)


func _set_broken(d: Dictionary, offline: bool) -> void:
	d["mood"] = MOOD_BROKEN
	d["strike"] = true
	d["desert_t"] = 0.0
	d.erase("desert_warn")
	d["mood_room"] = int(d.room)
	var r := Game.squad_role(d)
	if r >= 0:
		Game.s.squad[r] = -1
		Game.squad_changed.emit()
	var q := _quarters_for(d)
	d.room = q
	Trace.rec("crew", "broken: %s" % d.name, {"happy": snappedf(float(d.happy), 0.1), "squad": r})
	if not offline:
		Game.toast.emit(Loc.t("%s ใจสลาย นั่งร้องไห้ในห้องพัก ไม่ทำงาน ไม่รับคำสั่ง") % d.name if q >= 0 else Loc.t("%s ใจสลาย นั่งร้องไห้ ไม่ทำงาน ไม่รับคำสั่ง") % d.name, "bad")
	Game.dwellers_changed.emit()
	Game.rooms_changed.emit()


func _clear_broken(d: Dictionary, offline: bool) -> void:
	d["mood"] = MOOD_DEPRESSED
	d["strike"] = false
	d["strike_t"] = 0.0
	d["desert_t"] = 0.0
	d.erase("desert_warn")
	var back := int(d.get("mood_room", -1))
	d.erase("mood_room")
	d.room = back if _has_seat(back, d) else -1
	Trace.rec("crew", "recovered from broken: %s" % d.name, {"back": int(d.room)})
	if not offline:
		Game.toast.emit(Loc.t("%s ตั้งสติได้แล้ว กลับไปทำงาน (ยังหดหู่อยู่)") % d.name, "good")
	Game.dwellers_changed.emit()
	Game.rooms_changed.emit()


## the first finished quarters (Broken crew don't take a work seat there), or -1
func _quarters_for(_d: Dictionary) -> int:
	for i in Game.s.rooms.size():
		if str(Game.s.rooms[i].type) == "quarters" and Game.is_slot_unlocked(i) and not Game.is_site(i):
			return i
	return -1


func _has_seat(slot: int, d: Dictionary) -> bool:
	if slot < 0 or slot >= Game.s.rooms.size() or not Game.is_slot_unlocked(slot) or Game.is_annex(slot):
		return false
	if str(Game.room(slot).type) in ["empty", "locked"]:
		return false
	var crew := Game.site_crew(slot) if Game.is_site(slot) else Game.room_workers(slot)
	crew = crew.filter(func(o): return o != d)
	return crew.size() < Game.room_capacity(slot)


## leaving at night after being Broken too long: only the gear they wear goes with them
func leave_quietly(d: Dictionary) -> void:
	Trace.rec("crew", "left (broken): %s" % d.name, {"happy": snappedf(float(d.happy), 0.1)})
	var role := Game.squad_role(d)
	if role >= 0:
		Game.s.squad[role] = -1
	if not Game.s.has("deserters"):
		Game.s["deserters"] = []
	Game.s.deserters.append({"name": d.name, "lvl": d.lvl, "km": snappedf(float(Game.s.stats.km_total), 0.1), "stole": ""})
	Game.s.dwellers.erase(d)
	Game.toast.emit(Loc.t("%s ลงจากรถไปในความมืดตอนกลางคืน และไม่กลับมาอีก") % d.name, "bad")
	Game.dwellers_changed.emit()
	Game.squad_changed.emit()
	Game.rooms_changed.emit()


# --- talk
func _talk_store() -> Dictionary:
	if not (Game.s.get("morale") is Dictionary):
		Game.s["morale"] = {}
	var m: Dictionary = Game.s.morale
	if not (m.get("talk_cd") is Dictionary):
		m["talk_cd"] = {}
	return m.talk_cd


func talk_key(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]


func talk_cd_left(a: int, b: int) -> float:
	return float(_talk_store().get(talk_key(a, b), 0.0))


func talk_gain(talker: Dictionary) -> float:
	var g := Features.num("morale.talk_gain", 10.0)
	return clampf(g + 0.5 * (float(talker.get("int", 5)) - 5.0), g * 0.8, g * 1.5)


## why this person can't talk the other up right now ("" = they can)
func talker_block(talker: Dictionary, target: Dictionary) -> String:
	if talker.is_empty() or talker == target or int(talker.id) == int(target.id):
		return "ไม่มีคนคุย"
	if Game.is_away(talker):
		return "ไม่อยู่บนรถ"
	if mood(talker) != MOOD_OK:
		return "ตัวเองก็ยังไม่ไหว"
	if Game.squad_role(talker) >= 0:
		return "อยู่ทีมป้องกันรถ"
	if busy(talker):
		return "กำลังคุยกับคนอื่นอยู่"
	var cd := talk_cd_left(int(talker.id), int(target.id))
	if cd > 0.0:
		return Loc.t("เพิ่งคุยกันไป อีก %s") % Game.fmt_time(cd)
	return ""


## the best person to talk this one up (highest INT among those who can), {} = nobody
func best_talker(target: Dictionary) -> Dictionary:
	var best := {}
	for o in Game.s.dwellers:
		if talker_block(o, target) != "":
			continue
		if best.is_empty() or int(o.int) > int(best.int):
			best = o
	return best


## why nobody can talk this one up ("" = someone can)
func talk_block(target: Dictionary) -> String:
	if not v2():
		return "ระบบขวัญกำลังใจใหม่ปิดอยู่"
	if target.is_empty() or Game.is_away(target):
		return "ไม่อยู่บนรถ"
	if mood(target) == MOOD_OK:
		return "ไม่ได้หดหู่"
	if best_talker(target).is_empty():
		return "ไม่มีใครว่างคุยด้วย"
	return ""


## talk them up: returns the happiness gained (0 = nobody could)
func talk(target_id: int) -> float:
	var target := Game.dweller_by_id(target_id)
	if talk_block(target) != "":
		return 0.0
	var talker := best_talker(target)
	var gain := talk_gain(talker)
	target.happy = minf(100.0, float(target.happy) + gain)
	talker["talk_t"] = Features.num("morale.talk_sec", 60.0)
	_talk_store()[talk_key(int(talker.id), target_id)] = Features.num("morale.talk_cd", 300.0)
	Trace.rec("crew", "talk: %s -> %s" % [talker.name, target.name], {"gain": snappedf(gain, 0.1)})
	Game.toast.emit(Loc.t("%s นั่งคุยกับ %s ความสุข +%d (%s พักงาน %s)") % [talker.name, target.name, int(gain), talker.name,
		Game.fmt_time(Features.num("morale.talk_sec", 60.0))], "good")
	Game.dwellers_changed.emit()
	Game.rooms_changed.emit()
	return gain


## talk timers and pair cooldowns (game clock; frozen with morale_v2 off)
func morale_v2_global_tick(dt: float) -> void:
	if not v2() or Game.s.is_empty():
		return
	var freed := false
	for d in Game.s.dwellers:
		if float(d.get("talk_t", 0.0)) > 0.0:
			d.talk_t = maxf(0.0, float(d.talk_t) - dt)
			freed = freed or float(d.talk_t) <= 0.0
	var cd := _talk_store()
	for k in cd.keys():
		cd[k] = float(cd[k]) - dt
		if float(cd[k]) <= 0.0:
			cd.erase(k)
	if freed:
		Game.rooms_changed.emit()


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


# ------------------------------------------------------------------ MV-170 named crew roster
static func is_roster(variant: String) -> bool:
	return variant.begins_with("dw_crew_")


## a named crew member who is not on board yet, preferring those whose best stat matches ("" = none left)
func roster_pick(best: String, rng: RandomNumberGenerator) -> String:
	var aboard := {}
	for d in Game.s.dwellers:
		aboard[str(d.variant)] = true
	var cameo_w := Features.num("crew.cameo_weight", CAMEO_WEIGHT)
	for pass_ in 2:
		var ids := []
		var weights := []
		var total := 0.0
		for id in Data.CREW_ROSTER:
			var r: Dictionary = Data.CREW_ROSTER[id]
			if aboard.has("dw_crew_" + str(id)) or (pass_ == 0 and r.stat != best):
				continue
			var w := cameo_w if r.cameo else 1.0
			if w <= 0.0:
				continue
			ids.append(id)
			weights.append(w)
			total += w
		if total <= 0.0:
			continue
		var x := rng.randf() * total
		for i in ids.size():
			x -= float(weights[i])
			if x < 0.0:
				return str(ids[i])
		return str(ids[-1])
	return ""

