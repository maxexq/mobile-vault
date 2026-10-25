extends Node
## Room expansion foundation (MV-428 epic, MV-429): the shared plumbing for the ten optional new rooms (Salvagers'
## Saloon, Scout Dispatch, Decontamination Bay, Companion Den, Drone Dock, Battery Reserve, Stormwatch Station,
## Barter Counter, Training Cage, Relic & Memory Room). Each room ships in its own PR (gameplay + 64x52 background +
## one micro-animation) and registers itself in DEFS below; this file never adds a room by itself.
##  * registry: DEFS[type] uses the same fields as Data.ROOMS (th / en / cost / unlock / stat / power / effect / recipes)
##    plus "anims" (RoomAnim strips) and "art" (atlas key, default "room_<type>"). Data.room_def() and
##    Data.buildable() fall back to it, so the build menu, close-up, construction (levels 1..3) and the two-worker
##    cap work unchanged. New rooms are single-cell: never add them to Data.MERGEABLE without wide art and a
##    reviewed wide-job rule.
##  * one saved namespace Game.s.rx {v, seq, jobs: {id: job}}: no new localStorage keys. Account-persistent keepsakes
##    (Relic room) go through the existing account envelope only.
##  * jobs: one per room. start_job() checks and pays in one step; a job stores its room type, slot, cost, seed,
##    remaining time, done and claimed flags. It runs only while the room is still that type, finished building and
##    lit; it is dropped (no refund, no reward) when the room is demolished or changed. claim() hands the job out
##    exactly once (repeated taps and double callbacks get nothing). Offline time is the game's capped catch-up, and a
##    finished job waits to be claimed, so nothing pays out on its own.
##  * switch rooms_expansion off: new rooms leave the build menu, jobs and their clocks freeze where they are (no
##    hidden catch-up when it comes back on), saved rooms and keepsakes stay.
## GOD → รถ → ROOM EXPANSION. Autotest --only=rooms_x. Style: docs/art/room-style-reference.md.

signal job_started(job: Dictionary)
signal job_done(job: Dictionary)
signal job_claimed(job: Dictionary)
signal job_dropped(job: Dictionary, why: String)

const VERSION := 1
## the ten approved rooms register here, one PR each (MV-430..MV-439)
const DEFS := {}

## tests and GOD previews add rooms at run time (never saved, never in a real build menu unless asked)
var extra := {}


func on() -> bool:
	return Features.on("rooms_expansion")


# =================================================================== registry
func room_def(t: String) -> Dictionary:
	if DEFS.has(t):
		return DEFS[t]
	return extra.get(t, {})


func is_rx(t: String) -> bool:
	return DEFS.has(t) or extra.has(t)


## expansion rooms that can be built now: the switch is on, the room's own switch (if any) is on, its art exists
func buildable() -> Array:
	if not on():
		return []
	var out := []
	for t in DEFS.keys() + extra.keys():
		var d := room_def(t)
		if bool(d.get("hidden", false)):
			continue
		if str(d.get("feature", "")) != "" and not Features.on(str(d.feature)):
			continue
		if not Atlas.has(art_key(t)):
			continue
		out.append(t)
	return out


func art_key(t: String) -> String:
	return str(room_def(t).get("art", "room_" + t))


## the RoomAnim strips of a room type: [{prefix, count, fps, loop, rest, x, y, active}]
func anims(t: String) -> Array:
	return room_def(t).get("anims", [])


# =================================================================== saved state
func st() -> Dictionary:
	if Game.s.is_empty():
		return {}
	if not (Game.s.get("rx") is Dictionary):
		Game.s["rx"] = {"v": VERSION, "seq": 1, "jobs": {}}
	var r: Dictionary = Game.s.rx
	r.merge({"v": VERSION, "seq": 1, "jobs": {}}, false)
	return r


func jobs() -> Dictionary:
	var r := st()
	return r.get("jobs", {}) if not r.is_empty() else {}


## the job in this room ({} = none); JSON turns ids and slots into floats, so compare as int
func job_in(slot: int) -> Dictionary:
	for k in jobs():
		var j: Dictionary = jobs()[k]
		if int(j.slot) == slot and not bool(j.claimed):
			return j
	return {}


func job(id: int) -> Dictionary:
	return jobs().get(str(id), {})


# =================================================================== jobs
## why a job can't start in this room right now ("" = it can)
func start_block(slot: int, cost: Dictionary = {}) -> String:
	if not on():
		return "ระบบห้องใหม่ปิดอยู่"
	if not Game.has_room(slot):
		return "ไม่มีห้องนี้"
	var t := str(Game.room(slot).type)
	if not is_rx(t):
		return "ห้องนี้ไม่ใช่ห้องใหม่"
	if Game.is_constructing(slot):
		return "ห้องยังสร้างไม่เสร็จ"
	if not job_in(slot).is_empty():
		return "ห้องนี้มีงานค้างอยู่"
	if not cost.is_empty() and not Game.can_afford(cost):
		return "ทรัพยากรไม่พอ (%s)" % Game.cost_text(cost)
	return ""


## start a job (checks and pays in one step); kind = what the room does, sec = work time, data = room-specific
## targets (crew / item ids are stored as ints). Returns the job, or {} when it can't start.
func start_job(slot: int, kind: String, sec: float, cost: Dictionary = {}, data: Dictionary = {}) -> Dictionary:
	if start_block(slot, cost) != "":
		return {}
	if not cost.is_empty() and not Game.pay(cost):
		return {}
	var r := st()
	var id := int(r.seq)
	r.seq = id + 1
	var j := {"id": id, "slot": slot, "room": str(Game.room(slot).type), "kind": kind, "cost": cost.duplicate(true),
		"total": maxf(0.0, sec), "left": maxf(0.0, sec), "seed": randi(), "data": data.duplicate(true), "done": sec <= 0.0,
		"claimed": false}
	r.jobs[str(id)] = j
	Trace.rec("rooms", "rx job start %s %s" % [j.room, kind], {"slot": slot, "sec": snappedf(sec, 0.1)})
	job_started.emit(j)
	if bool(j.done):
		job_done.emit(j)
	return j


## hand out a finished job exactly once: {} if it isn't done, is already claimed, or the room is gone
func claim(id: int) -> Dictionary:
	var j := job(id)
	if j.is_empty() or not bool(j.done) or bool(j.claimed) or not on():
		return {}
	j.claimed = true
	jobs().erase(str(id))
	Trace.rec("rooms", "rx job claim %s %s" % [j.room, j.kind], {"slot": int(j.slot)})
	job_claimed.emit(j)
	return j


## why a job is not counting down right now ("" = it is)
func paused_why(j: Dictionary) -> String:
	if not on():
		return "off"
	var slot := int(j.slot)
	if not Game.has_room(slot) or str(Game.room(slot).type) != str(j.room):
		return "gone"
	if Game.is_constructing(slot):
		return "building"
	if Game.room_dark(slot):
		return "dark"
	return ""


func tick(dt: float, _offline: bool) -> void:
	if Game.s.is_empty() or not (Game.s.get("rx") is Dictionary) or not on():
		return      # switch off: every job and its clock stays where it is
	for k in jobs().keys():
		var j: Dictionary = jobs()[k]
		var why := paused_why(j)
		if why == "gone":
			drop(int(j.id), "room gone")
			continue
		if why != "" or bool(j.done):
			continue
		j.left = maxf(0.0, float(j.left) - dt)
		if float(j.left) <= 0.0:
			j.done = true
			Trace.rec("rooms", "rx job done %s %s" % [j.room, j.kind], {"slot": int(j.slot)})
			job_done.emit(j)


## drop a job without reward (the room was demolished / changed, or GOD)
func drop(id: int, why: String) -> void:
	var j := job(id)
	if j.is_empty():
		return
	jobs().erase(str(id))
	Trace.rec("rooms", "rx job dropped %s %s" % [j.room, j.kind], {"why": why})
	job_dropped.emit(j, why)


## 0..1 progress of a job (1 = done)
func progress(j: Dictionary) -> float:
	if j.is_empty() or float(j.total) <= 0.0:
		return 1.0
	return clampf(1.0 - float(j.left) / float(j.total), 0.0, 1.0)


# =================================================================== activity (drives RoomAnim)
## is this room doing its thing right now: a job running (not paused), and lit
func active(slot: int, what: String = "job") -> bool:
	if not on() or not Game.has_room(slot) or Game.room_dark(slot) or Game.is_constructing(slot):
		return false
	match what:
		"job":
			var j := job_in(slot)
			return not j.is_empty() and not bool(j.done) and paused_why(j) == ""
		"powered":
			return true
		"staffed":
			return Game.s.dwellers.any(func(d): return int(d.get("room", -1)) == slot and not Game.is_away(d))
	return false
