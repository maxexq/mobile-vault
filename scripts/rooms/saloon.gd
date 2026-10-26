class_name Saloon
extends RefCounted
## Salvagers' Saloon (MV-430, first room of the MV-428 expansion on the MV-429 foundation): spend surplus food on a
## shared supper. The player seats one or two present crew; they leave their own work for the meal (moved into the
## Saloon, their old room remembered), food and water are paid once and a RoomX job runs (saloon.sec). When it ends
## the diners go straight back to the room they came from (if it still has space, else they idle) and start a
## cooldown shared by every Saloon. Claiming the finished supper gives each diner who really sat it out +8 happiness
## (cap 100), records one bond between the pair (Game.s.rx.saloon.bonds) and they say a short conversation.
## Lv.2 / Lv.3 only make the meal shorter (saloon.level_speed), never bigger, so upgrading can't farm happiness.
##  * the job is RoomX's (pay once, pause when dark / building, freeze with rooms_expansion off, claim once, dropped on
##    demolition). This file only seats, releases and rewards the diners; RoomX calls on_done / on_drop / tick.
##  * stale diners: someone moved elsewhere or sent out during the meal is not rewarded; a demolished Saloon sends
##    its diners back to work with nothing (no refund). Squad members and anyone away can't be seated.
##  * no new meter, no romance, no permanent stats: happiness still drifts back to its usual target.
## Tunables saloon.*; GOD → รถ → ROOM EXPANSION; autotest --only=saloon. Art: room_salvagers_saloon + steam strip.

const TYPE := "salvagers_saloon"
const KIND := "supper"

## what the friends say once the meal is over: [first diner, second diner] (Thai is the key, English in i18n/en.json)
const TALK := [
	["จำตอนที่เราเจอกันครั้งแรกได้ไหม", "จำได้สิ ตอนนั้นนายยังกลัวหมาอยู่เลย"],
	["ซุปวันนี้รสชาติเหมือนบ้านเลยนะ", "บ้านไหน บ้านเราไม่มีแล้วนี่"],
	["ถ้าโลกกลับมาเหมือนเดิม นายจะทำอะไรก่อน", "นอนให้เต็มอิ่มสักสามวัน"],
	["ขอบใจนะที่คราวก่อนช่วยลากฉันกลับมา", "ไม่ต้องหรอก คราวหน้าตานายลากฉันบ้าง"],
	["เพลงที่ฮัมเมื่อกี้ชื่ออะไร", "จำไม่ได้แล้ว รู้แค่ว่าแม่ชอบร้อง"],
	["กินช้า ๆ ก็ได้ คืนนี้ไม่มีใครรีบ", "แปลกดีนะ ไม่ได้นั่งกินแบบนี้มานานแล้ว"],
	["เศษเหล็กกองนั้นนายเก็บมาคนเดียวเหรอ", "ครึ่งเดียว อีกครึ่งมันวิ่งหนีไป"],
	["พรุ่งนี้ทางข้างหน้าจะเป็นยังไงนะ", "เหมือนทุกวันแหละ ไปด้วยกันก็พอ"],
]
## one diner on their own
const SOLO := [
	"นั่งกินเงียบ ๆ คนเดียวก็ดีเหมือนกัน",
	"ข้าวร้อน ๆ สักจาน ทำให้ลืมเรื่องข้างนอกได้แป๊บนึง",
	"พรุ่งนี้ชวนใครมานั่งด้วยดีกว่า",
]


static func on() -> bool:
	return RoomX.on()


static func cost() -> Dictionary:
	return {"food": Features.num("saloon.food", 8.0), "water": Features.num("saloon.water", 4.0)}


## how long a supper takes; a better Saloon (Lv.2 / Lv.3) serves it faster (saloon.level_speed per level)
static func duration(slot: int = -1) -> float:
	var lv := int(Game.room(slot).get("level", 1)) if slot >= 0 and Game.has_room(slot) else 1
	return Features.num("saloon.sec", 90.0) * maxf(0.2, 1.0 - Features.num("saloon.level_speed", 0.15) * float(lv - 1))


static func happy_gain() -> float:
	return Features.num("saloon.happy", 8.0)


static func cooldown() -> float:
	return Features.num("saloon.cooldown", 180.0)


# =================================================================== saved state (Game.s.rx.saloon)
static func st() -> Dictionary:
	var r := RoomX.st()
	if r.is_empty():
		return {}
	if not (r.get("saloon") is Dictionary):
		r["saloon"] = {}
	var s: Dictionary = r.saloon
	s.merge({"cd": {}, "bonds": {}, "meals": 0}, false)
	return s


## seconds before this crew member can sit down to another supper (0 = now), in any Saloon
static func cd_left(did: int) -> float:
	var s := st()
	return float((s.get("cd", {}) as Dictionary).get(str(did), 0.0)) if not s.is_empty() else 0.0


static func bond_key(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]


static func bonds(a: int, b: int) -> int:
	var s := st()
	return int((s.get("bonds", {}) as Dictionary).get(bond_key(a, b), 0)) if not s.is_empty() else 0


## the supper running in a Saloon ({} = none) and its diner ids as ints (JSON brings them back as floats)
static func supper(slot: int) -> Dictionary:
	var j := RoomX.job_in(slot)
	return j if str(j.get("kind", "")) == KIND else {}


static func diners(j: Dictionary) -> Array:
	var out := []
	for x in (j.get("data", {}) as Dictionary).get("diners", []):
		out.append(int(x))
	return out


## is this person sitting at a supper that hasn't ended yet (any Saloon)
static func at_table(did: int) -> bool:
	for k in RoomX.jobs():
		var j: Dictionary = RoomX.jobs()[k]
		if str(j.kind) == KIND and not bool(j.done) and diners(j).has(did):
			var d := Game.dweller_by_id(did)
			if not d.is_empty() and int(d.room) == int(j.slot):
				return true
	return false


# =================================================================== start
## why this crew member can't be seated at this Saloon ("" = they can)
static func diner_block(d: Dictionary) -> String:
	if d.is_empty():
		return "ไม่พบลูกเรือ"
	if Game.is_away(d):
		return "ไม่อยู่บนรถ"
	if Game.squad_role(d) >= 0:
		return "อยู่ทีมป้องกันรถ"
	if at_table(int(d.id)):
		return "นั่งกินอยู่อีกโต๊ะ"
	var cd := cd_left(int(d.id))
	if cd > 0.0:
		return Loc.t("เพิ่งกินไป อีก %s") % Game.fmt_time(cd)
	return ""


## why a supper with these crew can't start right now ("" = it can)
static func start_block(slot: int, ids: Array) -> String:
	var why := RoomX.start_block(slot, cost())
	if why != "":
		return why
	if str(Game.room(slot).type) != TYPE:
		return "ห้องนี้ไม่ใช่โรงเตี๊ยม"
	var seen := {}
	for x in ids:
		seen[int(x)] = true
	if seen.is_empty():
		return "เลือกคนร่วมโต๊ะก่อน"
	if seen.size() > 2:
		return "นั่งได้โต๊ะละ 2 คน"
	for did in seen:
		var b := diner_block(Game.dweller_by_id(did))
		if b != "":
			return b
	# the Saloon's own staff who aren't eating keep their seats: everyone has to fit the room
	var others := 0
	for d in Game.room_occupants(slot):
		if not seen.has(int(d.id)):
			others += 1
	if others + seen.size() > Game.room_capacity(slot):
		return "โต๊ะเต็ม (ถอดคนทำงานในห้องนี้ออกก่อน)"
	return ""


## seat the diners and start the meal (checks and pays once); returns the job or {}
static func start(slot: int, ids: Array) -> Dictionary:
	var why := start_block(slot, ids)
	if why != "":
		Game.toast.emit(Loc.t(why), "warn")
		return {}
	var picked := []
	var from := {}
	for x in ids:
		if not picked.has(int(x)):
			picked.append(int(x))
	for did in picked:
		from[str(did)] = int(Game.dweller_by_id(did).room)
	var j := RoomX.start_job(slot, KIND, duration(slot), cost(), {"diners": picked, "from": from})
	if j.is_empty():
		return {}
	for did in picked:
		Game.dweller_by_id(did).room = slot
	Game.dwellers_changed.emit()
	Game.rooms_changed.emit()
	return j


# =================================================================== end (RoomX calls these)
## the meal is over: note who really sat it out, send everyone back to work, start their cooldowns
static func on_done(j: Dictionary, offline: bool) -> void:
	var ate := []
	for did in diners(j):
		var d := Game.dweller_by_id(did)
		if d.is_empty() or Game.is_away(d) or int(d.room) != int(j.slot):
			continue     # moved elsewhere / sent out during the meal: no reward
		ate.append(did)
		(st().cd as Dictionary)[str(did)] = cooldown()
	j.data["ate"] = ate
	_release(j, false)
	if not offline:
		Game.toast.emit(Loc.t("มื้อเย็นที่โรงเตี๊ยมเสร็จแล้ว แตะห้องเพื่อนั่งคุยกันต่อ"), "good")


## the Saloon was demolished / changed (or GOD dropped the job): diners go back to work, nothing is paid out
static func on_drop(j: Dictionary) -> void:
	if not bool(j.done):
		_release(j, true)


## every Saloon's cooldowns run on the game clock (frozen with rooms_expansion off, like the jobs)
static func tick(dt: float) -> void:
	var s := st()
	if s.is_empty():
		return
	var cd: Dictionary = s.cd
	for k in cd.keys():
		cd[k] = float(cd[k]) - dt
		if float(cd[k]) <= 0.0:
			cd.erase(k)


## diners still seated go back to the room they came from when it still has room for them, else they idle
static func _release(j: Dictionary, gone: bool) -> void:
	var slot := int(j.slot)
	var from: Dictionary = (j.get("data", {}) as Dictionary).get("from", {})
	var moved := false
	for did in diners(j):
		var d := Game.dweller_by_id(did)
		if d.is_empty() or Game.is_away(d):
			continue
		if int(d.room) != slot and not (gone and int(d.room) == -1):
			continue     # already somewhere else: leave them be
		var back := int(from.get(str(did), -1))
		d.room = back if back != slot and _has_space(back) else -1
		moved = true
	if moved:
		Game.dwellers_changed.emit()
		Game.rooms_changed.emit()


static func _has_space(slot: int) -> bool:
	if slot < 0 or slot >= Game.s.rooms.size() or not Game.is_slot_unlocked(slot) or Game.is_annex(slot):
		return false
	if str(Game.room(slot).type) in ["empty", "locked"]:
		return false
	var crew := Game.site_crew(slot) if Game.is_site(slot) else Game.room_workers(slot)
	return crew.size() < Game.room_capacity(slot)


# =================================================================== claim
## hand out a finished supper once: happiness for whoever ate, one bond for a pair, and their conversation.
## Returns [[did, line], ...] (empty when there was nothing to claim).
static func claim(id: int) -> Array:
	var j := RoomX.claim(id)
	if j.is_empty() or str(j.kind) != KIND:
		return []
	var ate := []
	for x in (j.data as Dictionary).get("ate", []):
		if not Game.dweller_by_id(int(x)).is_empty():
			ate.append(int(x))
	for did in ate:
		var d := Game.dweller_by_id(did)
		d.happy = minf(100.0, float(d.happy) + happy_gain())
	var s := st()
	s.meals = int(s.meals) + 1
	var lines := []
	var seed := absi(int(j.seed))
	if ate.size() >= 2:
		var k := bond_key(ate[0], ate[1])
		s.bonds[k] = int((s.bonds as Dictionary).get(k, 0)) + 1
		var pair: Array = TALK[seed % TALK.size()]
		lines = [[ate[0], Loc.t(pair[0])], [ate[1], Loc.t(pair[1])]]
	elif ate.size() == 1:
		lines = [[ate[0], Loc.t(SOLO[seed % SOLO.size()])]]
	if not ate.is_empty():
		var names := []
		for did in ate:
			names.append(str(Game.dweller_by_id(did).name))
		Game.toast.emit(Loc.t("%s อิ่มท้อง ความสุข +%d") % [" & ".join(names), int(happy_gain())], "good")
	Trace.rec("rooms", "saloon supper claimed", {"ate": ate.size(), "slot": int(j.slot)})
	Game.dwellers_changed.emit()
	if not lines.is_empty():
		RoomX.talk.emit(lines)
	return lines
