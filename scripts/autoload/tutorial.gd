extends Node
## First-run guided tutorial. Sgt. Mark walks a new Overseer through the core loop one step at a
## time: read resources -> tap a room -> build a room -> wait for the build crew -> crew -> combat ->
## travel. Each step either waits for "ต่อไป" (manual) or advances by itself once the player has
## done the thing (checked a few times a second, so it works whichever UI path the player takes).
## State lives in Game.s.tutorial = {"step": int, "done": bool} and is saved with the game.
## Timed construction (Game.is_constructing / rooms[i].build) is duck-typed: the "wait for the
## build" step only appears when that system exists and a build is actually running.

signal step_changed(index: int)
signal finished(skipped: bool)

## target kinds the overlay knows how to frame:
##   none | res | world_slot:<n> | world_build | world_constructing | closeup | tool:<key> | panel:<key> | combat | travel
const STEPS := [
	{"id": "welcome", "manual": true, "target": "none",
		"text": "ยินดีต้อนรับครับ ผู้บัญชาการ! ผมจ่ามาร์ค นี่คือ MAMMOTH-7 รถหุ้มเกราะคันสุดท้ายที่ยังวิ่งได้ งานของคุณคือพาทุกคนบนรถให้รอด"},
	{"id": "resources", "manual": true, "target": "res",
		"text": "แถบบนสุดคือเสบียง: ไฟ น้ำ อาหาร น้ำมัน และเศษเหล็ก ตัวเลขเป็นสีแดงเมื่อใกล้หมด ห้ามให้อะไรหมดเด็ดขาด"},
	{"id": "tap_room", "target": "world_slot:1",
		"text": "ห้องในรถคือหัวใจของการเอาตัวรอด ลองแตะที่ห้องครัวเพื่อซูมเข้าไปดู"},
	{"id": "closeup", "target": "closeup", "panel": "closeup",
		"text": "นี่คือหน้าจัดการห้อง ดูคนทำงาน ผลผลิต และสั่งผลิตของได้ เสร็จแล้วแตะนอกห้องเพื่อซูมออก"},
	{"id": "open_build", "target": "tool:build",
		"text": "รถยังมีช่องว่าง มาสร้างห้องเพิ่มกัน แตะปุ่ม Build"},
	{"id": "pick_room", "target": "panel:build", "panel": "build",
		"text": "เลือกห้องที่อยากได้แล้วกด สร้าง แนะนำ ห้องพัก จะได้มีเตียงรับคนเพิ่ม"},
	{"id": "place_room", "target": "world_build",
		"text": "แตะช่องว่างที่กะพริบในรถ เพื่อเลือกตำแหน่งสร้างห้อง"},
	{"id": "construct", "target": "world_constructing", "optional": true,
		"text": "ทีมช่างกำลังก่อสร้าง ห้องจะใช้งานได้เมื่อเสร็จ ลูกเรือที่เป็นช่างก่อสร้าง หรือมีนิสัยสายช่าง จะสร้างได้เร็วกว่าคนอื่น"},
	{"id": "crew", "target": "tool:dwellers",
		"text": "ต่อไปมาดูลูกเรือ แตะปุ่ม Crew"},
	{"id": "crew_info", "manual": true, "target": "panel:dwellers", "panel": "dwellers",
		"text": "ลูกเรือแต่ละคนมี STR INT AGI จัดคนเข้าห้องที่ใช้ค่าสถานะตรงกันจะผลิตได้ไวขึ้น คนว่างงานจะเดินเล่นเปล่าๆ"},
	{"id": "combat", "manual": true, "target": "combat",
		"text": "ศัตรูจะบุกรถเป็นระลอก ทีมป้องกัน 3 คนสู้ให้อัตโนมัติ PUSH คือชนะแล้วขึ้นเวฟถัดไป FARM คือวนเวฟเดิมเก็บของ"},
	{"id": "travel", "manual": true, "target": "travel",
		"text": "แถบล่างคุมการเดินทาง หยุดหรือออกรถ ดูระยะทาง และ HULL (ตัวถัง) ถ้าตัวถังเป็นศูนย์นานเกินไป รถจะพังและการเดินทางรอบนี้จะจบลง"},
	{"id": "done", "manual": true, "target": "none",
		"text": "เท่านี้ก็พร้อมแล้ว รถวิ่งต่อเองแม้คุณปิดเกม กลับมาเช็กเสบียงบ่อยๆ ล่ะ ขอให้รอดนะครับ ผู้บัญชาการ!"},
]
const BUILDER_TEXT := " ตอนนี้ %s เป็นช่างของเรา"
const START_SCRAP := 120.0

var hud: Node            # set by main: HUD (panels, room_closeup, any_modal_open)
var main: Node           # set by main: placement state (_placing)
var _t := 0.0
var _built0 := -1        # rooms built when the build steps began


func _ready() -> void:
	Game.game_started.connect(_on_game_started)


func _on_game_started() -> void:
	if not Game.s.has("tutorial"):
		# saves from before the tutorial existed (or later generations) skip it
		var fresh: bool = float(Game.s.get("stats", {}).get("km_total", 0.0)) < 0.05 and not Game.s.has("meta")
		Game.s["tutorial"] = {"step": 0, "done": not fresh or not Features.on("tutorial")}
	_built0 = -1
	step_changed.emit(step())


func state() -> Dictionary:
	if Game.s.is_empty():
		return {"step": 0, "done": true}
	return Game.s.get("tutorial", {"step": 0, "done": true})


func active() -> bool:
	return Game.started and not bool(state().get("done", true))


func step() -> int:
	return int(state().get("step", 0))


func current() -> Dictionary:
	return STEPS[clampi(step(), 0, STEPS.size() - 1)] if active() else {}


func step_id() -> String:
	return str(current().get("id", ""))


func index_of(id: String) -> int:
	for i in STEPS.size():
		if STEPS[i].id == id:
			return i
	return -1


## text for the current step, with live details (e.g. the crew's builders)
func text() -> String:
	var st := current()
	if st.is_empty():
		return ""
	var t: String = Loc.t(st.text)
	if st.id == "construct":
		var names := builder_names()
		if not names.is_empty():
			t += Loc.t(BUILDER_TEXT) % ", ".join(names)
	return t


func builder_names() -> Array:
	var out := []
	for d in Game.s.get("dwellers", []):
		if str(d.get("role", "")) == "builder":
			out.append(str(d.name))
	return out


func restart() -> void:
	if Game.s.is_empty():
		return
	Game.s["tutorial"] = {"step": 0, "done": false}
	_built0 = -1
	Trace.rec("tutorial", "restart")
	step_changed.emit(0)


func skip() -> void:
	if not active():
		return
	Trace.rec("tutorial", "skipped at %s" % step_id())
	_finish(true)


## the "ต่อไป" button (manual steps only)
func next() -> void:
	if active() and bool(current().get("manual", false)):
		_advance()


func goto(id: String) -> void:
	var i := index_of(id)
	if i < 0 or not active():
		return
	Game.s.tutorial.step = i
	_on_enter()
	step_changed.emit(i)


func _advance() -> void:
	var i := step() + 1
	if i >= STEPS.size():
		_finish(false)
		return
	Game.s.tutorial.step = i
	_on_enter()
	if active() and step() == i:
		step_changed.emit(i)


func _finish(skipped: bool) -> void:
	Game.s.tutorial.done = true
	Game.s.tutorial.step = STEPS.size()
	if not skipped:
		Trace.rec("tutorial", "completed")
	step_changed.emit(-1)
	finished.emit(skipped)


## side effects / skips when a step begins
func _on_enter() -> void:
	match step_id():
		"open_build":
			if _built0 < 0:
				_built0 = built_count()
			# make sure the lesson can be afforded
			if float(Game.s.res.scrap) < START_SCRAP:
				Game.s.res.scrap = START_SCRAP
				Game.resources_changed.emit()
			if free_slot() < 0:
				goto("crew")      # nowhere to build: skip the build lesson
		"construct":
			if constructing_slot() < 0:
				_advance()


# ------------------------------------------------------------------ world queries
func built_count() -> int:
	var n := 0
	for r in Game.s.rooms:
		if str(r.type) != "empty":
			n += 1
	return n


func free_slot() -> int:
	for sl in Game.unlocked_slots():
		if str(Game.s.rooms[sl].type) == "empty":
			return int(sl)
	return -1


func construction_supported() -> bool:
	return Game.has_method("is_constructing")


func constructing_slot() -> int:
	if not construction_supported():
		return -1
	for i in Game.s.rooms.size():
		if Game.call("is_constructing", i):
			return i
	return -1


func placing() -> bool:
	return main != null and str(main.get("_placing")) != ""


func panel_open(key: String) -> bool:
	if hud == null:
		return false
	if key == "closeup":
		return hud.room_closeup.is_open
	return hud.panels.has(key) and hud.panels[key].is_open


# ------------------------------------------------------------------ auto-advance
func _process(d: float) -> void:
	if not active():
		return
	_t -= d
	if _t > 0.0:
		return
	_t = 0.2
	check()


## evaluate the current step's goal once (also called directly by the autotest)
func check() -> void:
	if not active():
		return
	match step_id():
		"tap_room":
			if Game.closeup_slot >= 0:
				_advance()
		"closeup":
			if Game.closeup_slot < 0:
				_advance()
		"open_build":
			if built_count() > _built0:
				goto("construct")
			elif panel_open("build"):
				_advance()
			elif placing():
				goto("place_room")
		"pick_room":
			if built_count() > _built0:
				goto("construct")
			elif placing():
				_advance()
			elif not panel_open("build"):
				goto("open_build")
		"place_room":
			if built_count() > _built0:
				_advance()
			elif not placing():
				goto("open_build")
		"construct":
			if constructing_slot() < 0:
				_advance()
		"crew":
			if panel_open("dwellers"):
				_advance()
		"crew_info":
			if not panel_open("dwellers"):
				_advance()
