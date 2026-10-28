extends Node
## Player-facing history belongs to the run save, separate from diagnostic Trace.
signal changed
signal status_changed

const RESOURCE_KEYS := ["food", "water", "power", "scrap", "fuel", "crops", "meat"]
const CATEGORIES := {"loot": "สิ่งของ", "resources": "ทรัพยากร", "crew": "ลูกเรือ", "event": "เหตุการณ์"}
var _crew := {}
var _supplies := {}
var _low := {}
var _elapsed := 0.0


func _ready() -> void:
	Game.game_started.connect(_start)
	# Inspection personalizes a recruit after recruit_random emits; observe the final identity.
	Game.dwellers_changed.connect(func(): _scan_crew.call_deferred())
	Game.toast.connect(_toast)
	Game.construction_finished.connect(func(slot, kind):
		if Game.started:
			var r: Dictionary = Game.room(slot)
			record("event", "%s%s · ห้อง %d" % ["สร้างเสร็จ: " if kind == "build" else "อัปเกรดเสร็จ: ", Data.room_def(r.type).get("th", r.type), slot + 1]))
	Game.event_triggered.connect(func(id): record("event", "พบเหตุการณ์: " + str(Data.EVENTS.get(id, {}).get("th", id))))
	Game.biome_changed.connect(func(index, instant):
		if not instant: record("event", "เดินทางถึง " + str(Data.biome(index).th)))
	Expedition.expedition_finished.connect(func(report):
		record("event", "สำรวจ %s · %s\n%s" % [Expedition.site_def(str(report.site)).th, "สำเร็จ" if report.get("ok", false) else "ล้มเหลว", str(report.get("loot", ""))], "good" if report.get("ok", false) else "bad"))
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.ignore_time_scale = true
	timer.autostart = true
	timer.timeout.connect(sample)
	add_child(timer)


func enabled() -> bool:
	return Features.on("activity_log") and Game.started and not Game.s.is_empty()


func limit() -> int:
	return int(Features.num("activity.keep", 300.0))


func entries(category: String = "", warnings_only: bool = false) -> Array:
	var out: Array = []
	for e in Game.s.get("activity_log", []):
		if not e is Dictionary:
			continue
		if category != "" and str(e.get("cat", "")) != category:
			continue
		if warnings_only and str(e.get("kind", "info")) not in ["warn", "bad"]:
			continue
		out.append(e)
	return out


func record(category: String, text: String, kind: String = "info", data: Dictionary = {}, event_name: String = "") -> void:
	if not enabled():
		return
	if not Game.s.get("activity_log", []) is Array:
		Game.s["activity_log"] = []
	if not Game.s.has("activity_log"):
		Game.s["activity_log"] = []
	var rows: Array = Game.s.activity_log
	rows.append({"t": Time.get_unix_time_from_system(), "cat": category, "text": text,
		"kind": kind, "km": float(Game.s.get("km", 0)), "data": data.duplicate(true)})
	if rows.size() > limit():
		Game.s.activity_log = rows.slice(rows.size() - limit())
	# Reuse Telemetry's authenticated, opt-in, offline queue. No Sentry credentials on clients.
	if Features.on("activity_cloud") and Features.on("cloud_logs") and bool(Settings.get_value("telemetry")):
		Trace.rec("activity", event_name if event_name != "" else "activity." + category,
			{"text": text.left(1000), "category": category, "kind": kind, "km": float(Game.s.get("km", 0)),
			"generation": Meta.generation(), "environment": BuildInfo.env(), "detail": data.duplicate(true)})
	changed.emit()


func _start() -> void:
	_crew.clear()
	_low.clear()
	_supplies = supplies()
	_elapsed = 0.0
	for d in Game.s.dwellers:
		_crew[int(d.id)] = _crew_state(d)
	if not Game.s.has("activity_log"):
		record("event", "เริ่มบันทึกกิจกรรม · ลูกเรือ %d คน" % Game.s.dwellers.size())
	status_changed.emit()


func supplies() -> Dictionary:
	var out := {}
	for key in RESOURCE_KEYS:
		out[key] = float(Game.s.get("res", {}).get(key, 0))
	for key in Game.s.get("items", {}):
		out[key] = float(Game.s.items[key])
	return out


func _crew_state(d: Dictionary) -> Dictionary:
	return {"name": str(d.name), "stress": float(d.get("happy", 75)) < Features.num("activity.stress", 35.0),
		"strike": bool(d.get("strike", false)), "infection": Crew.is_infected(d)}


func stressed() -> Array:
	var out: Array = []
	for d in Game.s.get("dwellers", []):
		if _crew_state(d).stress or bool(d.get("strike", false)):
			out.append(d)
	return out


func _scan_crew() -> void:
	if not enabled():
		return
	var current := {}
	for d in Game.s.dwellers:
		var id := int(d.id)
		var state := _crew_state(d)
		current[id] = state
		if not _crew.has(id):
			record("crew", "%s ขึ้นรถ · Lv.%d" % [d.name, int(d.lvl)], "good", {"crew_id": id}, "crew.arrived")
		var old: Dictionary = _crew.get(id, {"stress": false, "strike": false, "infection": false})
		if state.stress != old.stress:
			record("crew", "%s %s · ขวัญกำลังใจ %d/100" % [d.name, "กำลังเครียด" if state.stress else "คลายเครียดแล้ว", int(d.happy)], "warn" if state.stress else "good", {"crew_id": id, "happiness": int(d.happy)}, "crew.stressed" if state.stress else "crew.recovered")
		if state.strike != old.strike:
			record("crew", "%s %s" % [d.name, "ประท้วงหยุดงาน" if state.strike else "กลับมาทำงานแล้ว"], "bad" if state.strike else "good")
		if state.infection != old.infection:
			record("crew", "%s %s" % [d.name, "ติดเชื้อ ต้องรักษา" if state.infection else "หายจากการติดเชื้อแล้ว"], "bad" if state.infection else "good")
	for id in _crew:
		if not current.has(id):
			record("crew", "%s ไม่อยู่บนรถแล้ว" % _crew[id].name, "warn")
	_crew = current


func sample() -> void:
	if not enabled():
		# Rebase while disabled so reenabling never replays hidden activity.
		_supplies = supplies()
		_crew.clear()
		for d in Game.s.get("dwellers", []):
			_crew[int(d.id)] = _crew_state(d)
		_low.clear()
		_elapsed = 0.0
		return
	_scan_crew()
	for key in ["food", "water", "power", "fuel"]:
		var value := float(Game.s.res.get(key, 0))
		var is_low := value <= Game.cap(key) * 0.1
		if is_low and not _low.get(key, false):
			record("resources", "%sใกล้หมด · เหลือ %d" % [Data.item_name(key), int(value)], "bad")
		elif not is_low and _low.get(key, false):
			record("resources", "%sพ้นระดับวิกฤต · มี %d" % [Data.item_name(key), int(value)], "good")
		_low[key] = is_low
	_elapsed += 1.0
	if _elapsed >= Features.num("activity.resource_interval", 30.0):
		flush_resources()
	status_changed.emit()


func flush_resources() -> void:
	if not enabled():
		return
	var now := supplies()
	var parts: Array[String] = []
	var delta := {}
	for key in now:
		var amount := int(floorf(float(now[key]))) - int(floorf(float(_supplies.get(key, 0))))
		if amount != 0:
			parts.append("%s %s%d" % [Data.item_name(key), "+" if amount > 0 else "", amount])
			delta[key] = amount
	if not parts.is_empty():
		record("resources", "ทรัพยากรสุทธิ: " + " · ".join(parts), "info", delta, "resources.changed")
	_supplies = now
	_elapsed = 0.0


func loot_received(item: Dictionary, salvaged: bool = false) -> void:
	var text := "%s: %s · %s · Lv.%d" % ["ย่อยของ" if salvaged else "ได้รับของ", Loot.item_name(item), Loot.rarity(int(item.rar)).th, int(item.ilvl)]
	record("loot", text, "info" if salvaged else "good", {"base": item.base, "rar": int(item.rar), "salvaged": salvaged, "item_level": int(item.ilvl)}, "loot.salvaged" if salvaged else "loot.received")


func _toast(text: String, kind: String) -> void:
	# Other gameplay outcomes already have Thai player-facing messages (combat, expeditions,
	# inspection, deaths, weather, crafting). Never expose diagnostic or account Trace data.
	if text.begins_with("ยินดีต้อนรับ") or text.begins_with("เปิดโหมดผู้ทดสอบ") or text.begins_with("ทีมสำรวจกลับมาแล้ว!") or text.begins_with("ภารกิจล้มเหลว..."):
		return
	record("event", text, kind)
