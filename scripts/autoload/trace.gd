extends Node
## Local event trace + state sampler (works offline, no server).
##  * entries: {t (unix), st (sec since session start), sid (session id), cat, msg, data}
##  * categories: session, save, build, vehicle, event, combat, crew, expedition, meta, toast, god, sample, error
##  * engine errors / warnings / script errors are captured with a Logger (OS.add_logger, Godot 4.5+)
##  * the last KEEP entries survive reloads (browser localStorage on web, user:// on desktop)
##  * export: JSON download on web (JavaScriptBridge.download_buffer) / file in user:// / clipboard
## Remote: Telemetry (MV-116) uploads these entries to Supabase public.logs while the player allows it
## (Settings "telemetry"). `sink_url` is an unused older hook for a third-party endpoint.

const KEY := "mobile_vault_trace_v1"
const FILE_PATH := "user://trace.json"
const MAX := 800
const KEEP := 400
const SAMPLE_SEC := 30.0
const VERSION := BuildInfo.GAME_VERSION

signal recorded(entry: Dictionary)   # every new entry (Analytics forwards errors, MV-423)

var session := ""
var entries: Array = []
var sink_url := ""
var _t0 := 0.0
var _sample_t := 10.0
var _persist_t := 0.0
var _dirty := false
var _mutex := Mutex.new()
var _pending: Array = []        # errors arriving from other threads
var _logger: _ErrLogger
var _last_boss_wave := -1


class _ErrLogger extends Logger:
	var sink: Callable

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var kind: String = ["error", "warning", "script", "shader"][clampi(error_type, 0, 3)]
		sink.call(kind, "%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_unix_time_from_system()
	session = "%08x" % (hash([_t0, randi()]) & 0x7fffffff)
	_restore()
	_logger = _ErrLogger.new()
	_logger.sink = _push_pending
	OS.add_logger(_logger)
	var vp := DisplayServer.window_get_size()
	rec("session", "start", {"v": VERSION, "os": OS.get_name(), "web": OS.has_feature("web"),
		"debug": OS.is_debug_build(), "screen": "%dx%d" % [vp.x, vp.y], "locale": OS.get_locale(), "env": BuildInfo.env()})
	Save.flush_requested.connect(persist)
	_hook.call_deferred()


func _exit_tree() -> void:
	if _logger:
		OS.remove_logger(_logger)


## thread-safe: errors can arrive from any thread
func _push_pending(kind: String, text: String) -> void:
	_mutex.lock()
	if _pending.size() < 50:
		_pending.append([kind, text])
	_mutex.unlock()


func rec(cat: String, msg: String, data: Dictionary = {}) -> void:
	var e := {"t": snappedf(Time.get_unix_time_from_system(), 0.01), "st": snappedf(Time.get_unix_time_from_system() - _t0, 0.1),
		"sid": session, "cat": cat, "msg": msg}
	if not data.is_empty():
		e["data"] = data
	entries.append(e)
	recorded.emit(e)
	if cat != "sample" and cat != "error":
		print("[trace] %s %s %s" % [cat, msg, JSON.stringify(data) if not data.is_empty() else ""])
	if entries.size() > MAX:
		entries = entries.slice(entries.size() - MAX)
	_dirty = true


func _hook() -> void:
	Game.game_started.connect(func(): rec("save", "game started", _summary()))
	Game.event_triggered.connect(func(id): rec("event", "triggered " + id, {"km": snappedf(float(Game.s.km), 0.01)}))
	Game.vault_level_changed.connect(func(l): if Game.started: rec("vehicle", "vault level %d" % l))
	Game.biome_changed.connect(func(i, instant): if not instant: rec("meta", "biome %d %s" % [i, Data.biome(i).id]))
	Game.toast.connect(func(text, kind): if kind in ["bad", "warn"]: rec("toast", text, {"kind": kind}))
	Combat.squad_wiped.connect(func(): rec("combat", "squad wiped", {"wave": Combat.wave(), "lvl": Combat.enemy_level()}))
	Combat.boss_event.connect(func(kind, e): if kind in ["enrage", "armor_break", "summon", "revive", "burrow"]: rec("combat", "boss %s: %s" % [kind, str(e.get("name", ""))]))
	Combat.wave_changed.connect(_on_wave)
	Combat.enemy_removed.connect(_on_enemy_removed)
	Expedition.expedition_started.connect(func():
		var e := Expedition.state()
		rec("expedition", "start " + str(e.site), {"team": e.team, "dur": int(float(e.dur)), "chance": snappedf(Expedition.success_chance(str(e.site), Expedition.team(), e.sup), 0.01)}))
	Expedition.expedition_finished.connect(func(r): rec("expedition", "finish %s ok=%s" % [str(r.get("site", "")), str(r.get("ok", false))], {"loot": str(r.get("loot", "")), "dead": r.get("dead", [])}))
	Meta.wrecked.connect(func(): rec("meta", "vehicle wrecked", _summary()))
	Meta.generation_started.connect(func(g): rec("meta", "generation %d (%s)" % [g, Game.tier()]))
	Cloud.account_changed.connect(_on_account)
	_on_account()


var _boss_ids := {}
var _pid := ""


## log which player this session belongs to (MV-115), once per id: sign-in, Google link, account switch
func _on_account() -> void:
	var pid := Cloud.player_id()
	if pid != "" and pid != _pid:
		_pid = pid
		rec("session", "player", {"pid": pid})


func _on_wave() -> void:
	if not Game.started:
		return
	if Combat.wave_active and (Combat.wave_is_boss or Combat.wave_is_warlord) and Combat.wave() != _last_boss_wave:
		_last_boss_wave = Combat.wave()
		rec("combat", "boss wave %d%s" % [Combat.wave(), " (warlord)" if Combat.wave_is_warlord else ""], {"lvl": Combat.enemy_level(), "dps": int(Combat.squad_dps())})


func _on_enemy_removed(id: int, killed: bool) -> void:
	if not killed:
		return
	# bosses are remembered while alive (see _process), so their deaths can be logged by name
	if _boss_ids.has(id):
		rec("combat", "boss down: %s" % _boss_ids[id], {"wave": Combat.wave()})
		_boss_ids.erase(id)


func _summary() -> Dictionary:
	if Game.s.is_empty():
		return {}
	return {"tier": Game.tier(), "gen": Meta.generation(), "biome": int(Game.s.biome), "lap": int(Game.s.get("lap", 0)),
		"km": snappedf(float(Game.s.km), 0.01), "vault": int(Game.s.vault_level), "crew": Game.s.dwellers.size(),
		"wave": Combat.wave(), "cheated": bool(Game.s.stats.get("cheated", false))}


func _process(delta: float) -> void:
	if not _pending.is_empty():
		_mutex.lock()
		var p := _pending.duplicate()
		_pending.clear()
		_mutex.unlock()
		for it in p:
			rec("error", str(it[1]), {"kind": it[0]})
	var real := delta / maxf(0.01, Engine.time_scale)
	# remember bosses on the field so their deaths can be logged by name
	if Game.started and not Game.s.is_empty():
		var b := Combat.current_boss()
		if not b.is_empty() and not _boss_ids.has(int(b.id)):
			_boss_ids[int(b.id)] = str(b.name)
		_sample_t -= real
		if _sample_t <= 0.0:
			_sample_t = SAMPLE_SEC
			_sample()
	_persist_t -= real
	if _persist_t <= 0.0:
		_persist_t = 15.0
		if _dirty:
			persist()


func _sample() -> void:
	var r: Dictionary = Game.s.res
	rec("sample", "state", {"fps": Engine.get_frames_per_second(), "x": Engine.time_scale,
		"food": int(r.food), "water": int(r.water), "power": int(r.power), "scrap": int(r.scrap), "fuel": int(r.get("fuel", 0)), "crops": int(r.get("crops", 0)), "meat": int(r.get("meat", 0)),
		"hull": int(Game.s.hull), "km": snappedf(float(Game.s.km), 0.01), "biome": int(Game.s.biome), "wave": Combat.wave(),
		"enemies": Combat.enemies.size(), "crew": Game.s.dwellers.size(), "happy": int(Game.avg_happiness()),
		"weight": int(Haul.load_ratio() * 100.0), "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))})


# ------------------------------------------------------------------ persistence / export
func persist() -> void:
	_dirty = false
	var text := JSON.stringify(entries.slice(maxi(0, entries.size() - KEEP)))
	Save.write_key(KEY, FILE_PATH, text)


func _restore() -> void:
	var text := Save.read_key(KEY, FILE_PATH)
	if text.is_empty():
		return
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		entries = parsed


func clear() -> void:
	entries.clear()
	rec("session", "log cleared")
	persist()


func filtered(cat: String = "", errors_only: bool = false) -> Array:
	var out := []
	for e in entries:
		if errors_only and str(e.cat) != "error":
			continue
		if cat != "" and str(e.cat) != cat:
			continue
		out.append(e)
	return out


func export_text() -> String:
	return JSON.stringify({"game": "mobile_vault", "v": VERSION, "session": session, "player": Cloud.player_id(), "exported": Time.get_datetime_string_from_system(true),
		"summary": _summary(), "dev": {"flags": Dev.flags, "speed": Dev.speed}, "features": Features.snapshot(), "entries": entries}, " ")


## web: browser download (must be called from a button press); desktop: user://trace_<time>.json
func download() -> String:
	var name := "mobile_vault_trace_%s.json" % Time.get_datetime_string_from_system(true).replace(":", "-")
	var text := export_text()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), name, "application/json")
		return name
	var path := "user://" + name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(text)
	return ProjectSettings.globalize_path(path)


static func fmt_entry(e: Dictionary) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60      # local wall-clock time
	var dt := Time.get_datetime_dict_from_unix_time(int(float(e.t)) + bias)
	var line := "%02d:%02d:%02d [%s] %s" % [dt.hour, dt.minute, dt.second, str(e.cat), str(e.msg)]
	if e.has("data"):
		line += "  " + JSON.stringify(e.data)
	return line
