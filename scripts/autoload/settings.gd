extends Node
## Player preferences (not progress): audio, language, display / performance, feel, camera.
## Stored apart from the save so a reset, an imported save or a new generation keeps them:
## web -> localStorage["mobile_vault_settings_v1"], desktop -> user://settings.json.
## Also owns the save-file tools of the Settings window: export / import / wipe.

signal changed(key: String)
signal import_failed(reason: String)
signal import_ready(text: String)

const KEY := "mobile_vault_settings_v1"
const FILE_PATH := "user://settings.json"
const IMPORT_PATH := "user://import_save.json"     # desktop import source
const BUSES := ["Music", "Ambience", "SFX", "UI"]     # MV-536: Sound plays beds on Ambience, effects on SFX, taps on UI
## [id, name shown in its own language]; English is offered while the Features switch "english" is on (MV-151)
const LANGS := [["th", "ไทย"], ["en", "English"]]
const DEFAULTS := {
	"master": 0.8, "music": 0.7, "ambience": 0.7, "sfx": 0.8, "ui": 0.6, "mute": false,
	"lang": "th",
	"ui_scale": "auto",      # auto (largest whole scale) | small (one step smaller: more room)
	"zoom": "auto",          # camera default: auto | wide | normal
	"crt": true,             # CRT scanlines / vignette overlay
	"fx_gpu": true,          # GPU particles (pretty) / CPU (weak phones)
	"fps": 60,               # 60 | 30 (battery saver) | 120 (high refresh screens, MV-113)
	"fullscreen": false,
	"shake": true,
	"car_shake": true,       # the vehicle body rumbles with the engine and bumps on the road (MV-176)
	"gore": true,
	"vibrate": true,
	"pacing": "threat",      # threat (enemies come in raids drawn by noise / light) | classic (back-to-back waves)
	"tips": true,            # Sgt. Mark explains each system the first time its window opens (MV-150)
	"event_timer": "normal",  # road events: normal | long (x2 time) | off (no timer) (MV-134)
	"telemetry": true,       # send play logs with the player id to the game's server (Telemetry, MV-116); opt-out
}

const FPS_CHOICES := [30, 60, 120]    # MV-113: the frame-rate cap a player can pick

var v: Dictionary = DEFAULTS.duplicate()
var _import_poll := false


func _ready() -> void:
	_ensure_buses()
	_load()
	for k in v:
		# browsers only allow fullscreen from a tap, so the web build starts windowed
		if k == "fullscreen" and OS.has_feature("web"):
			continue
		_apply(k)


func _ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


func _load() -> void:
	var text := Save.read_key(KEY, FILE_PATH)
	if text == "":
		return
	var d = JSON.parse_string(text)
	if d is Dictionary:
		_merge(d)


## copies known keys from `d` into v, with the same type checks as loading from storage
func _merge(d: Dictionary) -> void:
	for k in DEFAULTS:
		if not d.has(k):
			continue
		var def = DEFAULTS[k]
		if def is int and (d[k] is float or d[k] is int):     # JSON numbers come back as float
			v[k] = int(d[k])
		elif def is float and (d[k] is float or d[k] is int):
			v[k] = clampf(float(d[k]), 0.0, 1.0)
		elif typeof(d[k]) == typeof(def):
			v[k] = d[k]
	v.fps = int(v.fps) if int(v.fps) in FPS_CHOICES else 60
	if not v.ui_scale in ["auto", "small"]:
		v.ui_scale = "auto"
	if not v.zoom in ["auto", "wide", "normal"]:
		v.zoom = "auto"
	if not v.pacing in ["threat", "classic"]:
		v.pacing = "threat"


## settings that came with a cloud save from another device
func apply_remote(d: Dictionary) -> void:
	var before := v.duplicate()
	_merge(d)
	for k in v:
		if v[k] != before[k]:
			if not (k == "fullscreen" and OS.has_feature("web")):
				_apply(k)
			changed.emit(k)
	persist()


func persist() -> void:
	Save.write_key(KEY, FILE_PATH, JSON.stringify(v))


func get_value(k: String) -> Variant:
	return v.get(k, DEFAULTS.get(k))


func set_value(k: String, value: Variant) -> void:
	if not DEFAULTS.has(k) or v.get(k) == value:
		return
	v[k] = value
	_apply(k)
	persist()
	Trace.rec("settings", k, {"v": value})
	changed.emit(k)


func reset_defaults() -> void:
	for k in DEFAULTS:
		set_value(k, DEFAULTS[k])


func _apply(k: String) -> void:
	match k:
		"master", "music", "ambience", "sfx", "ui", "mute":
			_apply_audio()
		"lang":
			pass      # Loc (MV-151) sets the locale: it also checks the "english" switch
		"fx_gpu":
			FX.use_gpu = bool(v.fx_gpu)
		"fps":
			Engine.max_fps = int(v.fps)
		"fullscreen":
			var want := DisplayServer.WINDOW_MODE_FULLSCREEN if v.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
			if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != want:
				DisplayServer.window_set_mode(want)


func _apply_audio() -> void:
	AudioServer.set_bus_volume_linear(0, float(v.master))
	AudioServer.set_bus_mute(0, bool(v.mute))
	for b in BUSES:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.set_bus_volume_linear(i, float(v[b.to_lower()]))


## short buzz for big hits (web: navigator.vibrate; ignored where unsupported)
func buzz(ms: int = 40) -> void:
	if bool(v.vibrate):
		Input.vibrate_handheld(ms)


# ------------------------------------------------------------------ save tools
func save_size_bytes() -> int:
	return JSON.stringify(Game.s).length() if not Game.s.is_empty() else 0


## web: browser download (call from a button press); desktop: user://mobile_vault_save_<time>.json
func export_save() -> String:
	Game.save_game()
	var d := Save.read()
	if d.is_empty():
		return ""
	d["exported"] = {"v": BuildInfo.GAME_VERSION, "build": BuildInfo.commit_short(), "at": Time.get_datetime_string_from_system(true)}
	var name := "mobile_vault_save_%s.json" % Time.get_datetime_string_from_system(true).replace(":", "-")
	var text := JSON.stringify(d)
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), name, "application/json")
		return name
	var path := "user://" + name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	return ProjectSettings.globalize_path(path)


## checks a save file's text; returns "" when it can be loaded, else a Thai reason
func validate_save(text: String) -> String:
	var j := JSON.new()      # JSON.parse() reports errors quietly, unlike JSON.parse_string()
	if j.parse(text) != OK or not j.data is Dictionary:
		return "ไฟล์ไม่ใช่เซฟของ Apocarlypse (อ่าน JSON ไม่ได้)"
	var d: Dictionary = Account.vehicle_of(j.data)     # v2 envelope or an old one-run save
	if not d.has("rooms") or not d.has("res") or not d.has("dwellers"):
		return "ไฟล์นี้ไม่มีข้อมูลรถหรือลูกเรือ"
	return ""


## replaces the current save with `text` (already validated) and restarts into it
func apply_import(text: String) -> bool:
	if validate_save(text) != "":
		return false
	var d: Dictionary = JSON.parse_string(text)
	d.erase("exported")
	Game.started = false        # stop autosave from writing the old run over the import
	Save.write(d)
	Trace.rec("save", "imported", {"bytes": text.length()})
	_restart()
	return true


## web: opens the browser file picker (call from a button press); desktop: reads user://import_save.json
func begin_import() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""(function(){window.__mv_import=null;var i=document.createElement('input');
i.type='file';i.accept='.json,application/json';i.onchange=function(){var f=i.files&&i.files[0];if(!f)return;
var r=new FileReader();r.onload=function(){window.__mv_import=String(r.result);};r.readAsText(f);};i.click();})()""", true)
		_import_poll = true
		return
	if not FileAccess.file_exists(IMPORT_PATH):
		import_failed.emit("วางไฟล์เซฟไว้ที่ %s ก่อน" % ProjectSettings.globalize_path(IMPORT_PATH))
		return
	_finish_import(FileAccess.get_file_as_string(IMPORT_PATH))


func _process(_d: float) -> void:
	if not _import_poll or Engine.get_process_frames() % 10 != 0:
		return
	var r = JavaScriptBridge.eval("window.__mv_import", true)
	if r == null:
		return
	_import_poll = false
	JavaScriptBridge.eval("window.__mv_import=null", true)
	_finish_import(str(r))


func _finish_import(text: String) -> void:
	var why := validate_save(text)
	if why != "":
		import_failed.emit(why)
		return
	if Features.on("confirm_actions"):
		import_ready.emit(text)
	else:
		apply_import(text)


## erases progress (settings stay) and goes back to the title screen
func reset_progress(restart: bool = true) -> void:
	Trace.rec("save", "progress reset")
	# keep Game.s until the reload so the scene still has a world to draw for the last frames;
	# started = false stops the simulation and autosave from writing it back
	Game.started = false
	Save.wipe()
	if restart:
		_restart()


func _restart() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("location.reload()", true)
	else:
		get_tree().reload_current_scene.call_deferred()
