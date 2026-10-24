extends Node
## Feature switches, per-event switches and balance numbers in one place, read in layers (later wins):
##  1. res://config/features.json           shipped defaults (exported into the pck)
##  2. res://config/features.<tag>.json     only when the export preset has that custom feature tag
##                                          (OS.has_feature, e.g. "demo" / "staging")
##  3. remote features.json                 web only: <page folder>/features.json on the same host (Vercel
##                                          serves web/features.json), cached in localStorage; a failed fetch
##                                          keeps the cache, no cache keeps layer 1-2
##  4. game mode                          Modes.apply(): the run's mode / mutators (Game.s.mode) switch systems off
##  5. tester overrides                     GOD MODE tab "ฟีเจอร์" (user://dev.cfg) or the page URL
##                                          ?ff=raids:off,event.raiders:off,tune.threat.rate_scale:1.5 (session only)
## The remote file can only switch off / re-time / re-weight / re-tune what the build already contains:
## unknown keys are ignored, numbers are clamped to TUNE, a broken file changes nothing. Switching a feature
## off hides it from play but never deletes save data; switching it back on brings everything back.
## Schema (every block optional):
##  {"min_game": "4.3", "max_game": "", "tz_hours": 7,
##   "features": {"raids": false},
##   "events": {"raiders": {"on": false}, "trader": {"weight": 2.0}, "gas_station": {"biomes": ["*"], "from": "2026-11-14", "to": "2026-11-16 23:59"}},
##   "tune": {"threat.rate_scale": 1.5}}
## Event dates are local time at tz_hours (default 7 = Thailand); "to" without a time means the end of that day.

signal changed

const DEFAULT_PATH := "res://config/features.json"
const BUILD_TAGS := ["demo", "staging"]
const CACHE_KEY := "mobile_vault_features_v1"
const CACHE_PATH := "user://features_remote.json"
const DEV_CFG := "user://dev.cfg"
const TIMEOUT_SEC := 10.0

## every switch the game knows; the remote file cannot invent new ones
const FEATURES := {
	"road_events": "อีเว้นต์สุ่มบนถนน",
	"raids": "ศัตรูบุกรถ (บอสด่านตรวจยังขวางทางเสมอ)",
	"encounters": "จุดพิเศษระหว่างสำรวจ",
	"strangers": "คนแปลกหน้าหน้าประตู (ตรวจคน)",
	"expeditions": "ส่งทีมสำรวจ",
	"roof_deck": "ดาดฟ้าพักทีมป้องกัน",
	"large_rooms": "ทุบผนังรวมห้องใหญ่",
	"tutorial": "บทสอนเกมใหม่",
	"cloud_save": "เซฟบนคลาวด์ (มีผลตอนเปิดเกมครั้งถัดไป)",
	"google_login": "ล็อกอิน / ผูกบัญชีด้วย Google (ปิด = เล่นแบบ Guest อย่างเดียว)",
	"modes": "เลือกโหมดตอนเริ่มเกมใหม่ (ปิด = เริ่มโหมดปกติเสมอ)",
	"channel_badge": "ป้าย ALPHA / BETA บนหน้าเริ่มเกมและหน้าเกี่ยวกับ",
}
## tune key: [min, max, label]; the code that reads one passes its own constant as the default
const TUNE := {
	"events.gap_min": [20.0, 1800.0, "อีเว้นต์ถนน: เว้นขั้นต่ำ (วิ)"],
	"events.gap_max": [20.0, 3600.0, "อีเว้นต์ถนน: เว้นสูงสุด (วิ)"],
	"threat.rate_scale": [0.0, 10.0, "ความเร็วการสะสมภัย"],
	"threat.roll_k": [0.0, 1.0, "โอกาสบุกต่อรอบ"],
	"threat.min_quiet": [5.0, 600.0, "เงียบขั้นต่ำหลังบุก (วิ)"],
	"encounter.base_chance": [0.0, 1.0, "โอกาสจุดพิเศษพื้นฐาน"],
	"encounter.danger_chance": [0.0, 0.2, "โอกาสจุดพิเศษต่อกะโหลก"],
	"inspection.rare_chance": [0.0, 1.0, "โอกาสคนแปลกหน้า (หายาก)"],
	"inspection.very_rare_chance": [0.0, 1.0, "โอกาสคนแปลกหน้า (หายากมาก)"],
}
const LAYERS := ["default", "build", "remote", "mode", "dev"]

## per layer: {"features": {k: bool}, "events": {id: {...}}, "tune": {k: float}, ...}
var layers := {"default": {}, "build": {}, "remote": {}, "mode": {}, "dev": {}}
var remote_status := "off"      # off | cached | loading | ok | failed | rejected
var remote_at := 0.0            # unix time of the remote copy in use
var remote_url := ""
## tests: fixed clock for event windows (0 = real time)
var now_override := 0.0
var _session_dev := {}          # ?ff= overrides: never written to dev.cfg


func _ready() -> void:
	layers.default = _read_json(DEFAULT_PATH)
	var b := {}
	for tag in BUILD_TAGS:
		if OS.has_feature(tag):
			b = _merge(b, _read_json("res://config/features.%s.json" % tag))
	layers.build = b
	if not _is_test_run():
		var text := Save.read_key(CACHE_KEY, CACHE_PATH)
		var cached = JSON.parse_string(text) if text != "" else null
		if cached is Dictionary and _accepts(cached.get("cfg", {})):
			layers.remote = _clean(cached.cfg)
			remote_at = float(cached.get("at", 0.0))
			remote_status = "cached"
	_load_dev()
	_read_url_overrides()
	if OS.has_feature("web") and not _is_test_run():
		fetch_remote.call_deferred()
	_trace.call_deferred("boot")


func _is_test_run() -> bool:
	var args := OS.get_cmdline_user_args()
	for a in ["--autotest", "--migrate-test", "--balance"]:
		if a in args:
			return true
	return false


# =================================================================== queries
func on(feature: String) -> bool:
	return bool(_value("features", feature, true))


func num(key: String, def: float) -> float:
	var v = _value("tune", key, null)
	if v == null or not TUNE.has(key):
		return def
	return clampf(float(v), float(TUNE[key][0]), float(TUNE[key][1]))


## the merged settings of one event (later layers override field by field)
func event_cfg(id: String) -> Dictionary:
	var out := {}
	for l in LAYERS:
		var e = _layer(l).get("events", {}).get(id)
		if e is Dictionary:
			out.merge(e, true)
	return out


## may this event show right now in this biome? base = it is in the biome's own list
func event_ok(id: String, biome: int, base: bool = true) -> bool:
	if not on("road_events"):
		return false
	var e := event_cfg(id)
	if not bool(e.get("on", true)):
		return false
	if e.has("biomes"):
		var bs: Array = e.biomes if e.biomes is Array else []
		if not (bs.has("*") or bs.has(str(Data.biome(biome).id)) or bs.has(biome) or bs.has(float(biome))):
			return false
	elif not base:
		return false
	var t := now()
	var tz := float(_value("", "tz_hours", 7.0))
	if e.has("from"):
		var a := parse_time(str(e.from), tz, false)
		if a < 0 or t < a:
			return false
	if e.has("to"):
		var z := parse_time(str(e.to), tz, true)
		if z < 0 or t > z:
			return false
	return true


func event_weight(id: String) -> float:
	return clampf(float(event_cfg(id).get("weight", 1.0)), 0.0, 10.0)


## the road-event pool of a biome: its own list plus events a config window adds, minus the ones switched off
func event_pool(biome: int, base: Array) -> Array:
	var pool := []
	for e in base:
		if Data.EVENTS.has(e) and not pool.has(e) and event_ok(e, biome, true) and event_weight(e) > 0.0:
			pool.append(e)
	for l in LAYERS:
		for id in _layer(l).get("events", {}):
			if Data.EVENTS.has(id) and not pool.has(id) and not base.has(id) and event_ok(id, biome, false) and event_weight(id) > 0.0:
				pool.append(id)
	return pool


func now() -> float:
	return now_override if now_override > 0.0 else Cloud.now()


## layer 4, owned by Modes (a run's mode is part of the save, not a tester override)
func set_mode_layer(d: Dictionary) -> void:
	layers.mode = _clean(d)
	changed.emit()


## where a value comes from: default | build | remote | mode | dev (the last layer that sets it)
func source(block: String, key: String) -> String:
	var src := "code"
	for l in LAYERS:
		var b = _layer(l).get(block, {})
		if b is Dictionary and b.has(key):
			src = l
	return src


func has_dev_overrides() -> bool:
	for blk in ["features", "events", "tune"]:
		if not (_layer("dev").get(blk, {}) as Dictionary).is_empty():
			return true
	return false


## "YYYY-MM-DD" or "YYYY-MM-DD HH:MM[:SS]" (or with a T) at UTC+tz -> unix time; -1 when malformed.
## Time.get_unix_time_from_datetime_string reads the text as UTC, so the zone offset is applied here.
func parse_time(text: String, tz_hours: float, end_of_day: bool) -> float:
	var re := RegEx.create_from_string("^(\\d{4}-\\d{2}-\\d{2})(?:[T ](\\d{2}):(\\d{2})(?::(\\d{2}))?)?$")
	var m := re.search(text.strip_edges())
	if m == null:
		return -1.0
	var hms := "00:00:00"
	var has_time := m.get_string(2) != ""
	if has_time:
		hms = "%s:%s:%s" % [m.get_string(2), m.get_string(3), m.get_string(4) if m.get_string(4) != "" else "00"]
	var t := float(Time.get_unix_time_from_datetime_string(m.get_string(1) + "T" + hms))
	if end_of_day and not has_time:
		t += 86399.0
	return t - tz_hours * 3600.0


# =================================================================== layers
func _layer(l: String) -> Dictionary:
	if l == "dev":
		return _merge(layers.dev, _session_dev)
	return layers[l]


func _value(block: String, key: String, def: Variant) -> Variant:
	var v = def
	for l in LAYERS:
		var b = _layer(l) if block == "" else _layer(l).get(block, {})
		if b is Dictionary and b.has(key):
			v = b[key]
	return v


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		push_warning("%s is not a JSON object" % path)
		return {}
	return _clean(d)


## keep only what the game understands, with the right types
func _clean(d: Dictionary) -> Dictionary:
	var out := {}
	if d.get("features") is Dictionary:
		var f := {}
		for k in d.features:
			if FEATURES.has(k) and d.features[k] is bool:
				f[k] = d.features[k]
		out.features = f
	if d.get("events") is Dictionary:
		var ev := {}
		for id in d.events:
			var e = d.events[id]
			if not (Data.EVENTS.has(id) and e is Dictionary):
				continue
			var c := {}
			if e.get("on") is bool:
				c.on = e.on
			if e.get("weight") is float or e.get("weight") is int:
				c.weight = clampf(float(e.weight), 0.0, 10.0)
			if e.get("biomes") is Array:
				c.biomes = e.biomes
			for k in ["from", "to"]:
				if e.get(k) is String and parse_time(e[k], 0.0, false) >= 0.0:
					c[k] = e[k]
			ev[id] = c
		out.events = ev
	if d.get("tune") is Dictionary:
		var t := {}
		for k in d.tune:
			if TUNE.has(k) and (d.tune[k] is float or d.tune[k] is int):
				t[k] = clampf(float(d.tune[k]), float(TUNE[k][0]), float(TUNE[k][1]))
		out.tune = t
	if d.get("tz_hours") is float or d.get("tz_hours") is int:
		out.tz_hours = clampf(float(d.tz_hours), -12.0, 14.0)
	return out


func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for blk in b:
		if b[blk] is Dictionary and out.get(blk) is Dictionary:
			for k in b[blk]:
				if b[blk][k] is Dictionary and out[blk].get(k) is Dictionary:
					out[blk][k] = (out[blk][k] as Dictionary).merged(b[blk][k], true)
				else:
					out[blk][k] = b[blk][k]
		else:
			out[blk] = b[blk]
	return out


## the remote file names the game versions it is meant for
func _accepts(d) -> bool:
	if not d is Dictionary:
		return false
	var v := BuildInfo.GAME_VERSION
	if d.get("min_game") is String and d.min_game != "" and BuildInfo.ver_cmp(v, d.min_game) < 0:
		return false
	if d.get("max_game") is String and d.max_game != "" and BuildInfo.ver_cmp(v, d.max_game) > 0:
		return false
	return true


# =================================================================== remote (layer 3)
## apply a downloaded config (also the test entry point); returns false when it was refused
func apply_remote(d, at: float = -1.0) -> bool:
	if not d is Dictionary:
		remote_status = "failed"
		changed.emit()
		return false
	if not _accepts(d):
		remote_status = "rejected"
		layers.remote = {}
		changed.emit()
		return false
	layers.remote = _clean(d)
	remote_at = Time.get_unix_time_from_system() if at < 0.0 else at
	remote_status = "ok"
	if not _is_test_run():
		Save.write_key(CACHE_KEY, CACHE_PATH, JSON.stringify({"at": remote_at, "cfg": d}))
	changed.emit()
	_trace("remote")
	return true


func clear_remote() -> void:
	layers.remote = {}
	remote_status = "off"
	Save.write_key(CACHE_KEY, CACHE_PATH, "")
	changed.emit()


func fetch_remote() -> void:
	if not OS.has_feature("web"):
		return
	var base = JavaScriptBridge.eval("location.origin + location.pathname.replace(/[^/]*$/, '')", true)
	if base == null or not str(base).begins_with("http"):
		return
	remote_url = str(base) + "features.json"
	remote_status = "loading"
	changed.emit()
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT_SEC
	add_child(req)
	# the query string skips any stale HTTP cache between deploys
	if req.request(remote_url + "?t=%d" % int(Time.get_unix_time_from_system())) != OK:
		req.queue_free()
		remote_status = "failed"
		changed.emit()
		return
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		remote_status = "failed" if layers.remote.is_empty() else "cached"
		changed.emit()
		return
	var raw: PackedByteArray = res[3]
	apply_remote(JSON.parse_string(raw.get_string_from_utf8()))


# =================================================================== tester overrides (layer 5)
func _load_dev() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(DEV_CFG) == OK:
		var d = cfg.get_value("features", "overrides", {})
		layers.dev = _clean(d) if d is Dictionary else {}


func _save_dev() -> void:
	var cfg := ConfigFile.new()
	cfg.load(DEV_CFG)     # keep Dev's own [dev] section
	cfg.set_value("features", "overrides", layers.dev)
	cfg.save(DEV_CFG)


## block = "features" | "tune" | "events" (value = the event's field dict); value null removes the override
func set_override(block: String, key: String, value: Variant) -> void:
	var d: Dictionary = layers.dev
	if not d.has(block):
		d[block] = {}
	if value == null:
		d[block].erase(key)
		_session_dev.get(block, {}).erase(key)
	else:
		d[block][key] = value
	layers.dev = _clean(d)
	_save_dev()
	changed.emit()


func set_event_on(id: String, v: bool) -> void:
	var e: Dictionary = (layers.dev.get("events", {}) as Dictionary).get(id, {}).duplicate()
	e.on = v
	set_override("events", id, e)


func clear_overrides() -> void:
	layers.dev = {}
	_session_dev = {}
	_save_dev()
	changed.emit()


## ?ff=raids:off,road_events:on,event.raiders:off,tune.threat.rate_scale:1.5
func _read_url_overrides() -> void:
	if not OS.has_feature("web"):
		return
	var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('ff') || ''", true)
	if q == null or str(q) == "":
		return
	parse_overrides(str(q))


func parse_overrides(text: String) -> void:
	var d := {}
	for part in text.split(",", false):
		var kv := part.split(":")
		if kv.size() != 2:
			continue
		var k := kv[0].strip_edges()
		var v := kv[1].strip_edges().to_lower()
		var b := v in ["on", "1", "true"]
		var blk := "events" if k.begins_with("event.") else ("tune" if k.begins_with("tune.") else "features")
		if not d.has(blk):
			d[blk] = {}
		if blk == "events":
			d[blk][k.trim_prefix("event.")] = {"on": b}
		elif blk == "tune":
			d[blk][k.trim_prefix("tune.")] = v.to_float()
		else:
			d[blk][k] = b
	_session_dev = _clean(d)
	changed.emit()


# =================================================================== trace
func snapshot() -> Dictionary:
	var off := []
	for k in FEATURES:
		if not on(k):
			off.append(k)
	var ev_off := []
	for id in Data.EVENTS:
		if not bool(event_cfg(id).get("on", true)):
			ev_off.append(id)
	var tune := {}
	for k in TUNE:
		if _value("tune", k, null) != null:
			tune[k] = num(k, 0.0)
	return {"off": off, "events_off": ev_off, "tune": tune, "remote": remote_status, "dev": has_dev_overrides()}


func _trace(why: String) -> void:
	Trace.rec("features", why, snapshot())
