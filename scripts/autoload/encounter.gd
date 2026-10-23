extends Node
## Rare special encounters inside an expedition site (v4.4). When a team heads out there is a small chance
## (more in dangerous sites) that, somewhere in the middle of the trip, they stumble on something worth a
## decision: a survivor hiding in the ruins (take them aboard?), a sealed safe under rubble (worth the risk?).
## The player answers from a pop-up; the expedition clock keeps running, and if nobody answers before the
## team walks back (or the game is closed) the team plays it safe and picks the last ("leave it") choice.
## Effects land at once on the team (injuries, infections, supplies spent, extra time) and the rewards
## (refugees, bonus loot) come home with them in Expedition.finish().
##
## State lives inside the expedition: Game.s.exp.enc = {id, at, st: "wait"|"open"|"done", ...}.
## Game.s.enc_recent remembers the last few encounters so the same one never shows up back-to-back.

signal encounter_ready(id: String)
signal encounter_resolved(id: String, result: Dictionary)

const BASE_CHANCE := 0.14         # per expedition, before site danger
const DANGER_CHANCE := 0.015      # + per danger skull (danger 7 -> ~24.5%)
const RECENT := 3                 # how many past encounters are excluded from the next roll
const AT_RANGE := Vector2(0.3, 0.65)   # when in the trip it happens (fraction of the duration)

## choice keys: th/en/sub/color, need_sup {k:n} (spent from the packed supplies), need_room (refugee needs a
## bunk), risk {base, stat} (odds; no risk = always ok), time (extra seconds), ok / fail effect dicts.
## effect keys: text, recruit, recruit_infect (infection on the refugee), bonus {res/items/_gear/_gear_rare}
## (scaled by site danger), injure [lo, hi] (fraction of max HP on the one who did it), infect, lose (share
## of the site loot dropped).
const ENCOUNTERS := {
	"survivor": {"th": "ผู้รอดชีวิตหลบซ่อน", "en": "HIDDEN SURVIVOR", "image": "enc_survivor", "weight": 3, "min_danger": 0,
		"desc": "ไฟฉายส่องไปเจอใครบางคนหมอบอยู่หลังโต๊ะคว่ำ ผอมโซแต่ยังมีแรง เขาขอร้องให้พาไปด้วย",
		"choices": [
			{"th": "ชวนขึ้นรถ", "en": "INVITE", "color": "green", "need_room": true, "risk": {"base": 0.75, "stat": "int"},
				"ok": {"text": "เขาเดินตามทีมมาอย่างว่าง่าย — ได้ลูกเรือใหม่!", "recruit": 1},
				"fail": {"text": "เขาตามมาด้วย... แต่ซ่อนแผลติดเชื้อไว้ใต้เสื้อ", "recruit": 1, "recruit_infect": 45.0}},
			{"th": "แบ่งเสบียงให้", "en": "SHARE FOOD", "color": "yellow", "need_sup": {"food": 10, "water": 10},
				"ok": {"text": "เขาขอบคุณแล้วบอกทางไปห้องเก็บของลับ", "bonus": {"scrap": 30, "components": 4}}},
			{"th": "ปล่อยไว้", "en": "LEAVE", "color": "gray", "ok": {"text": "ทีมเดินผ่านไปเงียบๆ"}},
		]},
	"wounded": {"th": "คนแปลกหน้าบาดเจ็บ", "en": "WOUNDED STRANGER", "image": "enc_wounded", "weight": 2, "min_danger": 0,
		"desc": "ชายในชุดโจรนั่งพิงกำแพงเลือดไหลไม่หยุด เป้สนามวางอยู่ข้างตัว เขายังหายใจอยู่",
		"choices": [
			{"th": "ใช้สติมแพ็กรักษา", "en": "PATCH HIM UP", "color": "green", "need_sup": {"stimpack": 1}, "need_room": true,
				"ok": {"text": "แผลหยุดไหล เขาขอติดตามมาตอบแทนบุญคุณ", "recruit": 1}},
			{"th": "ค้นเป้ของเขา", "en": "TAKE HIS PACK", "color": "red", "risk": {"base": 0.7, "stat": "power"},
				"ok": {"text": "ได้กระสุนและชิ้นส่วนจากเป้มา", "bonus": {"ammo": 4, "components": 6}},
				"fail": {"text": "เขายังมีแรงชักมีดฟันสวน!", "bonus": {"ammo": 2}, "injure": [0.2, 0.4]}},
			{"th": "เดินผ่านไป", "en": "WALK AWAY", "color": "gray", "ok": {"text": "ทีมปล่อยเขาไว้กับความมืด"}},
		]},
	"cry": {"th": "เสียงร้องขอความช่วยเหลือ", "en": "CRY FOR HELP", "image": "enc_cry", "weight": 2, "min_danger": 2,
		"desc": "มีเสียงตะโกนจากห้องที่ไฟฉุกเฉินสีแดงยังกะพริบ คำว่า HELP ถูกป้ายไว้บนผนัง... หรืออาจเป็นกับดัก",
		"choices": [
			{"th": "รีบเข้าไปช่วย", "en": "RUSH IN", "color": "red", "need_room": true, "risk": {"base": 0.55, "stat": "power"},
				"ok": {"text": "เป็นผู้รอดชีวิตจริงๆ เขาพาเสบียงที่ตุนไว้มาด้วย", "recruit": 1, "bonus": {"food": 25, "water": 25}},
				"fail": {"text": "กับดักโจร! ทีมโดนซุ่มโจมตีและถูกปล้นของไปส่วนหนึ่ง", "injure": [0.3, 0.55], "lose": 0.3}},
			{"th": "ยิงข่มขวัญก่อนเข้า", "en": "WARNING SHOTS", "color": "yellow", "need_sup": {"ammo": 5}, "need_room": true, "risk": {"base": 0.8, "stat": "power"},
				"ok": {"text": "โจรที่ซุ่มอยู่หนีไป เหลือแต่ตัวประกันที่ขอบคุณทีม", "recruit": 1},
				"fail": {"text": "เงาในห้องวิ่งหนีหายไปในความมืด ไม่มีใครอยู่ที่นั่นแล้ว"}},
			{"th": "ไม่สนใจ", "en": "IGNORE", "color": "gray", "ok": {"text": "ทีมเลี่ยงไปอีกทาง เสียงร้องค่อยๆ เงียบลง"}},
		]},
	"vault": {"th": "ตู้เซฟใต้ซากตึก", "en": "BURIED SAFE", "image": "enc_vault", "weight": 3, "min_danger": 0,
		"desc": "ตู้นิรภัยเหล็กจมอยู่ใต้แผ่นปูนที่ถล่มลงมา เหล็กเส้นยื่นออกมาทุกทิศ ข้างในน่าจะมีของดี",
		"choices": [
			{"th": "งัดเลย", "en": "PRY IT OPEN", "color": "red", "time": 60, "risk": {"base": 0.5, "stat": "str"},
				"ok": {"text": "ประตูตู้เปิดออก — ของหายากอยู่ข้างใน!", "bonus": {"_gear_rare": 1, "components": 8}},
				"fail": {"text": "แผ่นปูนถล่มทับคนที่งัด!", "injure": [0.3, 0.6]}},
			{"th": "ใช้กระสุนยิงกลอน", "en": "SHOOT THE LOCK", "color": "yellow", "time": 30, "need_sup": {"ammo": 6}, "risk": {"base": 0.8, "stat": "power"},
				"ok": {"text": "กลอนแตก ได้ของในตู้มา", "bonus": {"_gear": 1, "components": 6}},
				"fail": {"text": "กระสุนแฉลบโดนคนในทีม", "injure": [0.15, 0.3]}},
			{"th": "ปล่อยไว้", "en": "LEAVE IT", "color": "gray", "ok": {"text": "ไม่คุ้มเสี่ยง ทีมเดินต่อ"}},
		]},
	"floor": {"th": "ลังเสบียงบนพื้นที่กำลังถล่ม", "en": "SAGGING FLOOR", "image": "enc_floor", "weight": 3, "min_danger": 0,
		"desc": "ลังเสบียงหลายใบวางค้างอยู่บนพื้นชั้นบนที่แอ่นลงมา ฝุ่นร่วงทุกครั้งที่มีคนขยับ",
		"choices": [
			{"th": "ส่งคนที่คล่องที่สุดขึ้นไป", "en": "SEND THE NIMBLEST", "color": "red", "time": 45, "risk": {"base": 0.55, "stat": "agi"},
				"ok": {"text": "ปีนขึ้นไปหย่อนลังลงมาได้ครบ!", "bonus": {"food": 40, "water": 40, "scrap": 40}},
				"fail": {"text": "พื้นทรุด! ตกลงมาโดนเหล็กขึ้นสนิม", "injure": [0.35, 0.6], "infect": 20.0}},
			{"th": "ปล่อยไว้", "en": "LEAVE IT", "color": "gray", "ok": {"text": "ทีมถอยออกมาก่อนพื้นจะพัง"}},
		]},
	"toxic": {"th": "คลังยาในห้องปนเปื้อน", "en": "TOXIC PHARMACY", "image": "enc_toxic", "weight": 2, "min_danger": 2,
		"desc": "ลังเวชภัณฑ์วางอยู่หลังถังสารเคมีที่รั่ว ไอสีเขียวลอยคลุ้งทั้งห้อง",
		"choices": [
			{"th": "กลั้นหายใจบุกเข้าไป", "en": "HOLD BREATH", "color": "red", "risk": {"base": 0.5, "stat": "int"},
				"ok": {"text": "คว้าลังยาออกมาได้โดยไม่สูดไอพิษ", "bonus": {"stimpack": 2, "antibiotics": 2, "radaway": 1}},
				"fail": {"text": "สูดไอพิษเข้าไปเต็มปอด แต่ก็คว้ายามาได้บ้าง", "bonus": {"stimpack": 1}, "infect": 40.0}},
			{"th": "กินยาปฏิชีวนะกันไว้ก่อน", "en": "DOSE UP FIRST", "color": "yellow", "need_sup": {"antibiotics": 1},
				"ok": {"text": "ยาออกฤทธิ์ทัน ทีมขนยาออกมาได้หมด", "bonus": {"stimpack": 2, "antibiotics": 1, "radaway": 1}}},
			{"th": "ปล่อยไว้", "en": "LEAVE IT", "color": "gray", "ok": {"text": "ทีมปิดประตูห้องแล้วเดินต่อ"}},
		]},
}

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


# ------------------------------------------------------------------ state
func state() -> Dictionary:
	if not Expedition.active():
		return {}
	return Expedition.state().get("enc", {})


## an encounter is showing and waits for the player's call
func pending() -> bool:
	return str(state().get("st", "")) == "open"


func current_id() -> String:
	return str(state().get("id", ""))


func def(id: String) -> Dictionary:
	return ENCOUNTERS.get(id, {})


func chance_for(site_id: String) -> float:
	return Features.num("encounter.base_chance", BASE_CHANCE) + Features.num("encounter.danger_chance", DANGER_CHANCE) * float(Expedition.site_def(site_id).danger)


func recent() -> Array:
	return Game.s.get("enc_recent", [])


## weighted pick, never one of the last RECENT encounters
func pick(danger: int) -> String:
	var pool := []
	var total := 0.0
	for id in ENCOUNTERS:
		var d: Dictionary = ENCOUNTERS[id]
		if danger < int(d.min_danger) or recent().has(id):
			continue
		pool.append(id)
		total += float(d.weight)
	if pool.is_empty():
		return ""
	var r := rng.randf() * total
	for id in pool:
		r -= float(ENCOUNTERS[id].weight)
		if r <= 0.0:
			return id
	return pool[-1]


## called from Expedition.start(): maybe schedule an encounter somewhere in the middle of the trip
func roll(force_id: String = "") -> void:
	if not Expedition.active():
		return
	var e := Expedition.state()
	var id := force_id
	if id == "":
		if not Features.on("encounters") or rng.randf() >= chance_for(str(e.site)):
			return
		id = pick(int(Expedition.site_def(str(e.site)).danger))
		if id == "":
			return
	var at := float(e.start) + float(e.dur) * rng.randf_range(AT_RANGE.x, AT_RANGE.y)
	e["enc"] = {"id": id, "at": at, "st": "wait"}


## dev / autotest: put an encounter on the active expedition right now
func trigger_now(id: String) -> void:
	if not Expedition.active() or not ENCOUNTERS.has(id):
		return
	roll(id)
	Expedition.state().enc.at = Time.get_unix_time_from_system()
	tick(false)


## called every simulation step from Expedition.tick()
func tick(offline: bool) -> void:
	var enc := state()
	if enc.is_empty() or str(enc.st) != "wait":
		return
	if Time.get_unix_time_from_system() < float(enc.at):
		return
	enc.st = "open"
	_remember(str(enc.id))
	Trace.rec("expedition", "encounter %s" % enc.id, {"site": str(Expedition.state().site), "offline": offline})
	if not offline:
		Game.toast.emit("ทีมสำรวจเจอจุดพิเศษ: %s — รอคำสั่ง!" % def(str(enc.id)).th, "warn")
	encounter_ready.emit(str(enc.id))
	Game.travel_changed.emit()


func _remember(id: String) -> void:
	var r: Array = recent().duplicate()
	r.append(id)
	while r.size() > RECENT:
		r.pop_front()
	Game.s["enc_recent"] = r


# ------------------------------------------------------------------ choices
## the team member who does the job: best at the stat (random-ish tie break), alive and still out
func doer(stat: String) -> Dictionary:
	var best := {}
	var bv := -INF
	for d in Expedition.team():
		var v := Combat.hero_power(d) if stat == "power" else float(d.get(stat, 0))
		v += rng.randf() * 0.01
		if v > bv:
			bv = v
			best = d
	return best


func room_free() -> bool:
	return Game.s.dwellers.size() + int(state().get("recruits", 0)) < Game.pop_cap()


## "" if the choice can be taken, else why not (Thai)
func blocked(ch: Dictionary) -> String:
	var sup: Dictionary = Expedition.state().get("sup", {})
	for k in ch.get("need_sup", {}):
		if int(sup.get(k, 0)) < int(ch.need_sup[k]):
			return "ทีมไม่ได้พก %s %d" % [Data.item_name(k), int(ch.need_sup[k])]
	if ch.get("need_room", false) and not room_free():
		return "ห้องพักบนรถเต็ม"
	return ""


func odds(ch: Dictionary) -> float:
	if not ch.has("risk"):
		return 1.0
	var e := Expedition.state()
	var members := Expedition.team()
	var ratio := clampf(Expedition.team_power(members, e.get("sup", {})) / Expedition.danger_need(str(e.site)), 0.0, 2.0)
	var c := float(ch.risk.base) + 0.2 * (ratio - 1.0)
	var st := str(ch.risk.stat)
	if st != "power":
		var d := doer(st)
		if not d.is_empty():
			c += 0.04 * (float(d.get(st, 4)) - 4.0)
	for d in members:
		if Crew.has(d, "lucky"):
			c += 0.08
	return clampf(c, 0.1, 0.92)


## one-line summary of what the choice costs / risks, for the button
func choice_sub(ch: Dictionary) -> String:
	var parts := []
	var nb := blocked(ch)
	if nb != "":
		return nb
	for k in ch.get("need_sup", {}):
		parts.append("ใช้ %s %d" % [Data.item_name(k), int(ch.need_sup[k])])
	if ch.has("risk"):
		parts.append("สำเร็จ ~%d%%" % int(odds(ch) * 100.0))
		var f: Dictionary = ch.get("fail", {})
		if f.has("injure"):
			parts.append("พลาด = บาดเจ็บ")
		elif f.has("infect"):
			parts.append("พลาด = ติดเชื้อ")
	if int(ch.get("time", 0)) > 0:
		parts.append("+%d วิ" % int(ch.time))
	if ch.get("need_room", false):
		parts.append("ใช้ที่พัก 1")
	return " · ".join(parts)


func _scale() -> float:
	var danger := float(Expedition.site_def(str(Expedition.state().site)).danger)
	return (1.0 + 0.35 * danger) * (1.0 + 0.15 * int(Game.s.get("lap", 0)))


## resolves the open encounter with choice i; returns {"ok":bool, "text":String} (ok=false + empty text if refused)
func choose(i: int, auto: bool = false) -> Dictionary:
	var enc := state()
	if enc.is_empty() or str(enc.st) == "done":
		return {"ok": false, "text": ""}
	var d := def(str(enc.id))
	var choices: Array = d.choices
	i = clampi(i, 0, choices.size() - 1)
	var ch: Dictionary = choices[i]
	if blocked(ch) != "":
		if not auto:
			return {"ok": false, "text": blocked(ch)}
		i = choices.size() - 1
		ch = choices[i]
	var e := Expedition.state()
	for k in ch.get("need_sup", {}):
		e.sup[k] = int(e.sup.get(k, 0)) - int(ch.need_sup[k])
	if int(ch.get("time", 0)) > 0:
		e.dur = float(e.dur) + float(ch.time)
	var ok := rng.randf() < odds(ch)
	var fx: Dictionary = ch.ok if ok or not ch.has("fail") else ch.fail
	var text: String = fx.get("text", "")
	var who := doer(str(ch.get("risk", {}).get("stat", "power")))
	if fx.has("injure") and not who.is_empty():
		var dmg := float(who.max_hp) * rng.randf_range(float(fx.injure[0]), float(fx.injure[1]))
		who.hp = maxf(1.0, float(who.hp) - dmg)
		text += " (%s HP -%d)" % [who.name, int(dmg)]
	if fx.has("infect") and not who.is_empty():
		Crew.infect(who, float(fx.infect))
		text += " (%s ติดเชื้อ)" % who.name
	var bonus: Dictionary = enc.get("bonus", {})
	var k_scale := _scale()
	for k in fx.get("bonus", {}):
		var n := float(fx.bonus[k])
		if not str(k).begins_with("_") and not k in ["stimpack", "antibiotics", "radaway", "ammo"]:
			n *= k_scale
		bonus[k] = int(bonus.get(k, 0)) + int(round(n))
	enc["bonus"] = bonus
	enc["recruits"] = int(enc.get("recruits", 0)) + int(fx.get("recruit", 0))
	if fx.has("recruit_infect"):
		enc["recruit_infect"] = float(fx.recruit_infect)
	enc["lose"] = clampf(float(enc.get("lose", 0.0)) + float(fx.get("lose", 0.0)), 0.0, 0.9)
	enc["choice"] = i
	enc["ok"] = ok
	enc["text"] = ("ทีมตัดสินใจเอง: %s — " % ch.th if auto else "") + text
	enc.st = "done"
	Trace.rec("expedition", "encounter %s -> %s %s" % [enc.id, ch.en, "ok" if ok else "fail"], {"auto": auto})
	var res := {"ok": ok or not ch.has("fail"), "text": text}
	encounter_resolved.emit(str(enc.id), res)
	Game.dwellers_changed.emit()
	Game.travel_changed.emit()
	return res


# ------------------------------------------------------------------ expedition hooks
## Expedition.finish(): an unanswered encounter is settled by the team (safe last choice); one that was
## still scheduled never happened
func settle() -> void:
	var enc := state()
	if enc.is_empty():
		return
	if str(enc.st) == "open":
		choose((def(str(enc.id)).choices as Array).size() - 1, true)


## multiplier on the site loot (an ambush can cost part of it)
func loot_factor() -> float:
	return 1.0 - float(state().get("lose", 0.0))


## Expedition.finish(): hand out what the encounter earned; returns extra text for the loot line
func apply(rep: Dictionary, survivors: int) -> String:
	var enc := state()
	if enc.is_empty() or str(enc.st) != "done":
		return ""
	rep["enc"] = {"id": str(enc.id), "text": str(enc.text)}
	rep.lines.append("จุดพิเศษ — %s: %s" % [def(str(enc.id)).th, str(enc.text)])
	if survivors <= 0:
		return ""
	var got := ""
	var bonus: Dictionary = enc.get("bonus", {})
	if not bonus.is_empty():
		got += ", " + Game.give_rewards(bonus)
	for i in int(enc.get("recruits", 0)):
		if Game.s.dwellers.size() >= Game.pop_cap():
			rep.lines.append("ไม่มีที่ว่างบนรถ ผู้รอดชีวิตจึงแยกทางไป")
			break
		var nd := Game.offer_recruit("exp_special", 1.0)
		if nd.is_empty():
			got += ", คนแปลกหน้าฝีมือดีรอตรวจที่ประตู"
			continue
		if float(enc.get("recruit_infect", 0.0)) > 0.0:
			Crew.infect(nd, float(enc.recruit_infect))
		got += ", ผู้รอดชีวิต " + str(nd.name)
	return got
