extends Node
## v4.4 — strangers at the door ("No, I'm Not a Human"-style). Rarely, a recruit offer is an exceptional
## survivor with high stats. Before they board, the player spends a few inspection points looking for tells
## (eyes, teeth, hands, forearm, bag, temperature, their story) and then lets them in, turns them away or
## shoots. Tells are circumstantial: the bad ones don't show every sign, honest people sometimes show one.
## Admitted bad apples hide a `secret` that goes off later: infected turn sick and spread it, mimics kill
## someone, thieves rob the larder and run, raiders sabotage the hull and let their gang strip the cargo.

signal queue_changed
signal revealed(name: String, kind: String, text: String)

const RARE_CHANCE := 0.06         # of every recruit offer
const VERY_RARE_CHANCE := 0.015
const MAX_QUEUE := 2
const WAIT_SEC := 600.0           # an unanswered stranger gives up and walks off (online time only)
const BASE_POINTS := 3

## what the stranger really is; human weight shrinks a little every lap (the road gets meaner)
const KINDS := {
	"human":    {"th": "มนุษย์ธรรมดา", "en": "HUMAN", "w": 55.0},
	"infected": {"th": "ผู้ติดเชื้อ", "en": "INFECTED", "w": 14.0},
	"mimic":    {"th": "ร่างเลียนแบบ", "en": "MIMIC", "w": 9.0},
	"thief":    {"th": "หัวขโมย", "en": "THIEF", "w": 13.0},
	"raider":   {"th": "สายลับโจร", "en": "RAIDER MOLE", "w": 9.0},
}
const GRADES := {
	"rare":      {"th": "หายาก", "en": "RARE", "lo": 7, "hi": 9, "lvl": 2, "traits": 2},
	"very_rare": {"th": "หายากมาก", "en": "VERY RARE", "lo": 9, "hi": 11, "lvl": 4, "traits": 3},
}
## checks: each costs 1 point. `signs` = possible results; the first one is the innocent look.
const CHECKS := {
	"eyes":  {"th": "ส่องตา", "en": "EYES", "icon": "eye", "signs": ["normal", "red", "glassy"]},
	"teeth": {"th": "ดูฟัน", "en": "TEETH", "icon": "meat", "signs": ["normal", "rot", "perfect"]},
	"hands": {"th": "ดูมือ/เล็บ", "en": "HANDS", "icon": "fist", "signs": ["normal", "veins", "spotless", "tattoo"]},
	"neck":  {"th": "ถลกแขนเสื้อ", "en": "FOREARM", "icon": "medkit", "signs": ["normal", "bite", "brand"]},
	"bag":   {"th": "ค้นกระเป๋า", "en": "BAG", "icon": "backpack", "signs": ["normal", "picks", "radio"]},
	"temp":  {"th": "วัดไข้", "en": "FEVER", "icon": "thermo", "signs": ["normal", "fever", "cold"]},
	"story": {"th": "ซักประวัติ", "en": "STORY", "icon": "chat", "signs": ["normal", "shaky"]},
}
## chance that each kind shows a given sign (anything not listed: never). Humans get innocent false alarms.
const TELLS := {
	"human":    {"red": 0.15, "rot": 0.12, "tattoo": 0.06, "fever": 0.08, "shaky": 0.15},
	"infected": {"red": 0.7, "rot": 0.5, "veins": 0.6, "bite": 0.75, "fever": 0.85, "shaky": 0.2},
	"mimic":    {"glassy": 0.6, "perfect": 0.7, "spotless": 0.6, "cold": 0.7, "shaky": 0.4},
	"thief":    {"picks": 0.8, "tattoo": 0.15, "shaky": 0.6},
	"raider":   {"tattoo": 0.55, "brand": 0.5, "radio": 0.7, "shaky": 0.5},
}
## what the field guide says each sign may mean (the player's reference card)
const SIGN_TEXT := {
	"normal": "ไม่มีอะไรผิดสังเกต",
	"red": "ตาแดงก่ำ เส้นเลือดปูด (ติดเชื้อ... หรือแค่อดนอน)",
	"glassy": "ตาวาวเหมือนกระจก สะท้อนไฟฉายกลับมา (ไม่ใช่ตาคน?)",
	"rot": "เหงือกดำ ฟันผุหลุด (ติดเชื้อ... หรือแค่ไม่มีหมอฟัน)",
	"perfect": "ฟันขาวเรียงสวยเกินไป... ในโลกแบบนี้เนี่ยนะ?",
	"veins": "เส้นเลือดดำเขียวลามจากข้อมือ (เชื้อลาม)",
	"spotless": "มือสะอาดเนียน ไม่มีหนังด้าน ไม่มีดินติดเล็บสักนิด",
	"tattoo": "รอยสักหัวกะโหลกกากบาทแดง (สัญลักษณ์แก๊งโจร... หรืออดีตไบเกอร์)",
	"bite": "ผ้าพันแผลชุ่มเลือด ใต้นั้นคือรอยกัด",
	"brand": "รอยเหล็กนาบตีตราของแก๊งโจร",
	"picks": "เหล็กสะเดาะกุญแจ บัตรประชาชนกับนาฬิกาของคนอื่นเต็มกระเป๋า",
	"radio": "วิทยุสื่อสารที่ยังเปิดอยู่ + แผนที่วงเส้นทางรถเรา",
	"fever": "ตัวร้อนจี๋ (ติดเชื้อ... หรือไข้หวัดธรรมดา)",
	"cold": "ตัวเย็นเฉียบ ผิดวิสัยคนเป็น",
	"shaky": "เรื่องเล่าไม่ปะติดปะต่อ ตอบวนไปมา หลบตา",
	"refused": "ไม่ยอมให้ตรวจ",
}
const STORIES_OK := [
	"\"ฉันเดินมาจากเมืองริมเขื่อน ครอบครัวไม่รอด... ขอแค่ที่นอนกับงานทำ\"",
	"\"เคยเป็นช่างในโรงงาน ซ่อมได้ทุกอย่างที่มีน็อต\"",
	"\"รถเสบียงฉันโดนปล้นเมื่อสามวันก่อน หนีมาได้คนเดียว\"",
	"\"ฉันได้ยินวิทยุพวกคุณ เลยเดินตามเสียงมา\"",
]
const STORIES_SHAKY := [
	"\"มาจาก... ทางเหนือ ไม่สิ ทางใต้ ช่างมันเถอะ ขอขึ้นรถก่อนได้ไหม\"",
	"\"ฉันอยู่คนเดียวมาตลอด... เอ่อ กับน้องชาย... เขาไปแล้ว\" (หลบตาตลอด)",
	"\"ถามเยอะจริง ฉันแค่อยากไปด้วย ฉันไม่มีอะไรจะเสีย\"",
	"\"ฉันจำไม่ได้ว่ามาจากไหน จำได้แค่ว่า... หิว\"",
]

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


# =================================================================== state
func st() -> Dictionary:
	if not Game.s.has("insp"):
		Game.s["insp"] = {"queue": [], "stats": {"admitted": 0, "refused": 0, "shot": 0, "caught": 0, "wrong": 0, "next": 1}}
	return Game.s.insp


func queue() -> Array:
	return st().queue


func pending() -> bool:
	return not queue().is_empty()


func current() -> Dictionary:
	return queue()[0] if pending() else {}


# =================================================================== the recruit hook
## every way a stranger can join funnels through here (via Game.offer_recruit)
func roll_grade(bonus: float = 0.0) -> String:
	var r := rng.randf()
	var very := Features.num("inspection.very_rare_chance", VERY_RARE_CHANCE)
	if r < very * (1.0 + bonus):
		return "very_rare"
	if r < (very + Features.num("inspection.rare_chance", RARE_CHANCE)) * (1.0 + bonus):
		return "rare"
	return ""


func roll_kind() -> String:
	var lap := float(Game.s.get("lap", 0))
	var total := 0.0
	var ws := {}
	for k in KINDS:
		var w := float(KINDS[k].w)
		if k == "human":
			w = maxf(40.0, w - 3.0 * lap)
		ws[k] = w
		total += w
	var r := rng.randf() * total
	for k in ws:
		r -= float(ws[k])
		if r <= 0.0:
			return k
	return "human"


## build a stranger and put them at the door. kind/grade can be forced (tests, god mode).
func queue_candidate(source: String, grade: String = "rare", kind: String = "") -> Dictionary:
	if queue().size() >= MAX_QUEUE:
		return {}
	if grade == "" or not GRADES.has(grade):
		grade = "rare"
	if kind == "" or not KINDS.has(kind):
		kind = roll_kind()
	var g: Dictionary = GRADES[grade]
	var stats := {"str": rng.randi_range(4, 7), "int": rng.randi_range(4, 7), "agi": rng.randi_range(4, 7)}
	var best: String = ["str", "int", "agi"][rng.randi() % 3]
	stats[best] = rng.randi_range(int(g.lo), int(g.hi))
	var outfits: Array = Data.OUTFIT_FOR_STAT[best]
	var outfit: String = outfits[rng.randi() % outfits.size()]
	var good := Crew.TRAITS.keys().filter(func(t): return not Crew.TRAITS[t].get("bad", false))
	var traits := []
	while traits.size() < int(g.traits):
		var t: String = good[rng.randi() % good.size()]
		if not traits.has(t):
			traits.append(t)
	var stt := st()
	var c := {
		"cid": int(stt.stats.get("next", 1)), "source": source, "grade": grade, "kind": kind,
		"name": Data.TITLES.get(outfit, "") + Data.FIRST_NAMES[rng.randi() % Data.FIRST_NAMES.size()],
		"variant": "dw_%s_%s" % [outfit, Data.HAIRS[rng.randi() % Data.HAIRS.size()]],
		"str": stats.str, "int": stats.int, "agi": stats.agi, "best": best, "traits": traits,
		"lvl": 1 + int(Game.s.get("lap", 0)) + int(g.lvl),
		"skin": ["a", "b", "c"][rng.randi() % 3], "hair": rng.randi() % 4,
		"signs": _roll_signs(kind), "seen": {}, "points": points_budget(), "max_points": points_budget(), "wait": WAIT_SEC,
		"story": "",
	}
	c.story = (STORIES_SHAKY if c.signs.story == "shaky" else STORIES_OK)[rng.randi() % 4]
	stt.stats.next = int(stt.stats.get("next", 1)) + 1
	queue().append(c)
	Trace.rec("crew", "stranger at the door: %s (%s, %s)" % [c.name, grade, kind], {"src": source})
	Game.toast.emit("มีคนแปลกหน้าฝีมือดี [%s] มาขอขึ้นรถ — ตรวจให้ดีก่อนเปิดประตู!" % g.th, "warn")
	queue_changed.emit()
	return c


## one hidden result per check, decided up-front (so inspecting twice can't reroll)
func _roll_signs(kind: String) -> Dictionary:
	var tells: Dictionary = TELLS[kind]
	var out := {}
	for chk in CHECKS:
		out[chk] = "normal"
		var opts: Array = CHECKS[chk].signs
		for i in range(1, opts.size()):
			if rng.randf() < float(tells.get(opts[i], 0.0)):
				out[chk] = opts[i]
				break
	# a bad apple always leaves at least one real clue somewhere
	if kind != "human" and _tell_count(kind, out) == 0:
		var cand := []
		for chk in CHECKS:
			for sg in CHECKS[chk].signs:
				if tells.has(sg) and sg != "shaky":
					cand.append([chk, sg])
		var pick: Array = cand[rng.randi() % cand.size()]
		out[pick[0]] = pick[1]
	# shifty people may refuse a bag search (humans sometimes too: privacy is all they have left)
	var refuse := 0.45 if kind in ["thief", "raider"] else 0.12
	if rng.randf() < refuse:
		out["bag_refused"] = true
	return out


func _tell_count(kind: String, signs: Dictionary) -> int:
	var n := 0
	for chk in CHECKS:
		var sg := str(signs.get(chk, "normal"))
		if sg != "normal" and sg != "shaky" and TELLS[kind].has(sg):
			n += 1
	return n


## inspection points: base 3, +1 a staffed medical room (thermometer, gloves), +1 a healer aboard
func points_budget() -> int:
	var p := BASE_POINTS
	for i in Game.s.rooms.size():
		if Game.s.rooms[i].type == "medical" and not Game.is_site(i) and not Game.room_workers(i).is_empty():
			p += 1
			break
	for d in Game.s.dwellers:
		if Crew.has(d, "healer") and not Game.is_away(d):
			p += 1
			break
	return p


# =================================================================== player actions
func can_check(c: Dictionary, chk: String) -> bool:
	return int(c.points) > 0 and not (c.seen as Dictionary).has(chk) and CHECKS.has(chk)


## spend a point, returns the sign seen ("refused" if they won't let you look)
func check(c: Dictionary, chk: String) -> String:
	if not can_check(c, chk):
		return str(c.seen.get(chk, ""))
	c.points = int(c.points) - 1
	var sg := str(c.signs.get(chk, "normal"))
	if chk == "bag" and c.signs.get("bag_refused", false):
		sg = "refused"
	c.seen[chk] = sg
	Trace.rec("crew", "inspect %s: %s -> %s" % [c.name, chk, sg])
	queue_changed.emit()
	return sg


func temp_reading(c: Dictionary) -> float:
	var base := 36.6 + 0.1 * float(int(c.cid) % 5)
	match str(c.signs.get("temp", "normal")):
		"fever": return snappedf(38.6 + 0.2 * float(int(c.cid) % 6), 0.1)
		"cold": return snappedf(33.4 + 0.2 * float(int(c.cid) % 4), 0.1)
	return snappedf(base, 0.1)


func eye_overlay(c: Dictionary) -> String:
	# the first look through the peephole already shows the eyes, faintly
	var e := str(c.signs.get("eyes", "normal"))
	return e if e in ["red", "glassy"] else "normal"


func detail_image(chk: String, sg: String) -> String:
	if sg == "refused":
		return "res://assets/inspect/d_refused.png"
	if chk == "temp":
		return "res://assets/inspect/d_temp.png"
	if chk == "story":
		return ""
	return "res://assets/inspect/d_%s_%s.png" % [chk, sg]


## suspicious signs the player has actually seen (UI hint, not the truth)
func red_flags(c: Dictionary) -> int:
	var n := 0
	for chk in c.seen:
		if str(c.seen[chk]) != "normal":
			n += 1
	return n


## let them in. Returns the new dweller (the secret travels with them).
func admit(c: Dictionary) -> Dictionary:
	if not queue().has(c):
		return {}
	if Game.s.dwellers.size() >= Game.pop_cap():
		Game.toast.emit("ที่พักเต็ม! สร้าง/อัปเกรดห้องพักก่อนรับคนเพิ่ม", "warn")
		return {}
	queue().erase(c)
	var d := Game.recruit_random()
	d.name = c.name
	d.variant = c.variant
	d.str = c.str
	d["int"] = c.int
	d.agi = c.agi
	d.lvl = c.lvl
	d.traits = (c.traits as Array).duplicate()
	d.role = ""
	d.max_hp = 90.0 + 5.0 * float(d.lvl)
	d.hp = d.max_hp
	d["elite"] = c.grade
	if str(c.kind) != "human":
		d["secret"] = {"kind": c.kind, "t": _fuse(str(c.kind))}
	st().stats.admitted = int(st().stats.admitted) + 1
	Trace.rec("crew", "admitted %s (%s)" % [c.name, c.kind], {"grade": c.grade})
	Game.toast.emit("%s ขึ้นรถแล้ว (STR %d / INT %d / AGI %d)" % [c.name, c.str, c.int, c.agi], "good")
	queue_changed.emit()
	Game.dwellers_changed.emit()
	return d


func _fuse(kind: String) -> float:
	match kind:
		"infected": return rng.randf_range(90.0, 200.0)
		"mimic": return rng.randf_range(150.0, 360.0)
		"thief": return rng.randf_range(120.0, 300.0)
	return rng.randf_range(150.0, 330.0)


func refuse(c: Dictionary) -> String:
	if not queue().has(c):
		return ""
	queue().erase(c)
	st().stats.refused = int(st().stats.refused) + 1
	Trace.rec("crew", "turned away %s (%s)" % [c.name, c.kind])
	queue_changed.emit()
	return "คุณปิดประตูใส่ %s เขาเดินหายไปในความมืด... จะไม่มีวันรู้เลยว่าเขาเป็นใคร" % c.name


## shoot at the door: right call = their stuff, wrong call = the whole crew saw you kill an innocent
func shoot(c: Dictionary) -> String:
	if not queue().has(c):
		return ""
	queue().erase(c)
	st().stats.shot = int(st().stats.shot) + 1
	var txt := ""
	match str(c.kind):
		"human":
			st().stats.wrong = int(st().stats.wrong) + 1
			for d in Game.s.dwellers:
				d.happy = maxf(0.0, float(d.happy) - 20.0)
			if not Game.s.has("memorial"):
				Game.s["memorial"] = []
			Game.s.memorial.append({"name": c.name, "lvl": c.lvl, "cause": "ถูกเรายิงที่ประตู (เป็นคนธรรมดา)",
				"km": snappedf(float(Game.s.stats.km_total), 0.1), "gen": Meta.generation(), "variant": c.variant})
			txt = "%s ล้มลง... ในกระเป๋ามีแค่รูปถ่ายครอบครัว เขาเป็นคนธรรมดา ทุกคนในรถเงียบกริบ (ความสุข -20)" % c.name
		"infected":
			st().stats.caught = int(st().stats.caught) + 1
			txt = "%s ล้มลง เลือดดำข้นไหลจากแผลกัด เชื้อไม่ได้ขึ้นรถ\nได้รับ: %s" % [c.name, Game.give_rewards({"antibiotics": 1})]
		"mimic":
			st().stats.caught = int(st().stats.caught) + 1
			txt = "ร่างของ %s บิดเบี้ยวกลับเป็นก้อนเนื้อเทาซีด ไม่ใช่คนจริงๆ\nได้รับ: %s" % [c.name, Game.give_rewards({"components": 6, "scrap": 40})]
		"thief":
			st().stats.caught = int(st().stats.caught) + 1
			txt = "กระเป๋าของ %s เต็มไปด้วยของที่ขโมยมา\nได้รับ: %s" % [c.name, Game.give_rewards({"scrap": 60, "stimpack": 1})]
		_:
			st().stats.caught = int(st().stats.caught) + 1
			txt = "วิทยุของ %s ยังเปิดอยู่ แก๊งปลายสายเงียบไปเลย\nได้รับ: %s" % [c.name, Game.give_rewards({"ammo": 6, "scrap": 30})]
	Trace.rec("crew", "shot %s at the door (%s)" % [c.name, c.kind])
	queue_changed.emit()
	return txt


# =================================================================== ticking
var _reveal: Array = []


func tick(dt: float, offline: bool) -> void:
	if not Game.s.has("insp"):
		return
	if not offline:
		for c in queue().duplicate():
			c.wait = float(c.wait) - dt
			if float(c.wait) <= 0.0:
				queue().erase(c)
				Game.toast.emit("%s รอไม่ไหว เดินจากไปแล้ว" % c.name, "info")
				queue_changed.emit()
	for d in Game.s.dwellers:
		if not d.has("secret") or Game.is_away(d):
			continue
		d.secret.t = float(d.secret.t) - dt
		if float(d.secret.t) <= 0.0 and not _reveal.has(d):
			_reveal.append(d)
	for d in _reveal:
		if Game.s.dwellers.has(d) and d.has("secret"):
			_go_off(d, offline)
	_reveal.clear()


## the secret comes out
func _go_off(d: Dictionary, offline: bool) -> void:
	var kind := str(d.secret.kind)
	d.erase("secret")
	var txt := ""
	match kind:
		"infected":
			Crew.infect(d, 65.0)
			var mates: Array = Game.s.dwellers.filter(func(o): return o != d and not Game.is_away(o) and int(o.room) == int(d.room) and int(d.room) >= 0)
			if mates.is_empty():
				mates = Game.s.dwellers.filter(func(o): return o != d and not Game.is_away(o))
			var victim := ""
			if not mates.is_empty() and rng.randf() < 0.6:
				var m: Dictionary = mates[rng.randi() % mates.size()]
				var res := 0.5 if Crew.has(m, "tough") else 1.0
				Crew.infect(m, 40.0 * res)
				victim = m.name
			txt = "%s ไข้ขึ้นสูง ไอเป็นเลือด เขาปิดแผลกัดไว้ตั้งแต่แรก!" % d.name
			if victim != "":
				txt += " เชื้อลามไปถึง %s แล้ว (ใช้ยาปฏิชีวนะ/ห้องพยาบาล)" % victim
		"mimic":
			var others: Array = Game.s.dwellers.filter(func(o): return o != d and not Game.is_away(o))
			# a strong bruiser on the rear deck may get to it first
			var guard: Dictionary = Game.dweller_by_id(int(Game.s.squad[1])) if Game.s.squad.size() > 1 and int(Game.s.squad[1]) >= 0 else {}
			if not guard.is_empty() and rng.randf() < clampf(0.15 + 0.05 * float(guard.str), 0.0, 0.8):
				guard.hp = maxf(5.0, float(guard.hp) - 35.0)
				txt = "%s ฉีกหน้ากากผิวหนังออกกลางดึก! %s สู้กลับทันจนมันหนีลงจากรถไป (บาดเจ็บหนัก)" % [d.name, guard.name]
			elif not others.is_empty():
				var v: Dictionary = others[rng.randi() % others.size()]
				txt = "%s ไม่ใช่มนุษย์! กลางดึกมันลากตัว %s หายไปในความมืด..." % [d.name, v.name]
				Crew.kill(v, "ถูกร่างเลียนแบบ (%s) จับไป" % d.name)
			else:
				txt = "%s ไม่ใช่มนุษย์! มันหนีลงจากรถไปในความมืด" % d.name
			_remove(d)
		"thief":
			var stolen := []
			for k in ["food", "water", "scrap", "fuel"]:
				var amt := floorf(float(Game.s.res.get(k, 0.0)) * rng.randf_range(0.2, 0.35))
				if amt >= 1.0:
					Game.s.res[k] = float(Game.s.res[k]) - amt
					stolen.append("%s %d" % [Data.item_name(k), int(amt)])
			for it in ["stimpack", "antibiotics", "components"]:
				var n := int(ceilf(float(Game.s.items.get(it, 0)) * 0.3))
				if n > 0:
					Game.s.items[it] = int(Game.s.items[it]) - n
					stolen.append("%s %d" % [Data.item_name(it), n])
			txt = "%s หายไปตอนรุ่งสาง พร้อมกับ %s!" % [d.name, ", ".join(stolen) if not stolen.is_empty() else "ของเล็กน้อย"]
			_remove(d)
		_:
			Game.s.hull = maxf(1.0, float(Game.s.hull) - 30.0)
			var scrap := floorf(float(Game.s.res.scrap) * 0.3)
			Game.s.res.scrap = float(Game.s.res.scrap) - scrap
			var hurt := []
			for o in Game.s.dwellers.filter(func(o): return o != d and not Game.is_away(o)).slice(0, 2):
				o.hp = maxf(5.0, float(o.hp) - 25.0)
				hurt.append(o.name)
			txt = "%s เปิดประตูท้ายให้แก๊งโจรกลางดึก! ตัวถัง -30, เศษเหล็กถูกขนไป %d" % [d.name, int(scrap)]
			if not hurt.is_empty():
				txt += ", %s บาดเจ็บ" % ", ".join(hurt)
			_remove(d)
			Game.travel_changed.emit()
	if not Game.s.has("insp_log"):
		Game.s["insp_log"] = []
	Game.s.insp_log.append({"name": d.name, "kind": kind, "text": txt, "km": snappedf(float(Game.s.stats.km_total), 0.1)})
	Trace.rec("crew", "secret revealed: %s (%s)" % [d.name, kind])
	Game.toast.emit(txt, "bad")
	revealed.emit(str(d.name), kind, txt)
	Game.dwellers_changed.emit()
	Game.resources_changed.emit()


func _remove(d: Dictionary) -> void:
	var role := Game.squad_role(d)
	if role >= 0:
		Game.s.squad[role] = -1
	Game.s.dwellers.erase(d)
	Game.squad_changed.emit()
	Game.rooms_changed.emit()
