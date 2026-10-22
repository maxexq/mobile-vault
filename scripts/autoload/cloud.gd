extends Node
## Cloud save on Supabase (Auth + PostgREST RPC), called with HTTPRequest (no addon).
##  * local-first: Save (localStorage on web / user:// on desktop) stays what the game reads and writes;
##    this autoload mirrors it to the `saves` table and keeps working offline
##  * first run signs in anonymously (no sign-up screen); an existing local save is uploaded as rev 1
##  * every write goes through rpc_save, which only accepts it if the client saw the latest rev, so two
##    devices never overwrite each other silently: the player picks one (state CONFLICT)
##  * every reply carries server_time; now() uses it so offline progress follows the server clock
## Config: res://cloud_config.json {"url": "https://<ref>.supabase.co", "anon_key": "<anon/publishable key>"}.
## The file is git-ignored; without it the cloud is OFF and the game behaves exactly as before.
## Schema: supabase/migrations/0001_cloud_save.sql

signal status_changed
signal pulled      # a newer cloud save was written locally (title screen re-checks CONTINUE)
signal conflict    # the cloud holds progress from another device that this one has not seen

enum State { OFF, CONNECTING, OK, OFFLINE, CONFLICT }

const CONFIG_PATH := "res://cloud_config.json"
const AUTH_KEY := "mobile_vault_auth_v1"
const AUTH_PATH := "user://cloud_auth.json"
const META_KEY := "mobile_vault_cloud_v1"
const META_PATH := "user://cloud_meta.json"
const SCHEMA := 1
const UPLOAD_SEC := 60.0     # while playing, upload at most once a minute (local autosave stays at 15 s)
const RETRY_SEC := 30.0      # offline: try again this often
const TIMEOUT_SEC := 15.0

var state := State.OFF
var last_error := ""
var url := ""
var anon_key := ""
## access_token, refresh_token, expires_at (unix), user_id
var session := {}
## rev = cloud revision this device last saw; dirty = local save changed since; wiped = progress reset
## (an empty save is uploaded on purpose); device_id = random per browser
var meta := {"rev": 0, "dirty": false, "wiped": false, "device_id": ""}
## CONFLICT: what the cloud holds {rev, device_id, updated_at, data, settings}
var remote := {}
var last_sync_at := 0.0
## tests inject an object with handle(method: int, path: String, headers: PackedStringArray, body: String) -> {code, body}
var transport: Object = null

var _server_offset := 0.0
var _has_server_time := false
var _busy := false
var _t := 0.0
var _write_seq := 0
var _applying := false


func _ready() -> void:
	_load_meta()
	Save.written.connect(_on_local_written)
	Save.wiped.connect(_on_local_wiped)
	Save.flush_requested.connect(_on_flush)
	var args := OS.get_cmdline_user_args()
	# test runners wipe and rewrite the save; they must never touch a real cloud row
	for a in ["--autotest", "--migrate-test", "--balance"]:
		if a in args:
			return
	if _load_config():
		_start.call_deferred()


func enabled() -> bool:
	return state != State.OFF


## unix time, from the server clock once any reply has arrived
func now() -> float:
	return Time.get_unix_time_from_system() + (_server_offset if _has_server_time else 0.0)


func user_id() -> String:
	return str(session.get("user_id", ""))


func status_text() -> String:
	match state:
		State.OFF: return "ปิดอยู่ (เซฟเฉพาะในเครื่อง)"
		State.CONNECTING: return "กำลังเชื่อมต่อ..."
		State.OK: return "ซิงก์แล้ว" if not meta.dirty else "รอส่งขึ้นคลาวด์"
		State.OFFLINE: return "ออฟไลน์ เซฟในเครื่องไว้ก่อน" + ("" if last_error == "" else " (%s)" % last_error)
		State.CONFLICT: return "เซฟในคลาวด์มาจากอีกเครื่อง เลือกว่าจะใช้อันไหน"
	return ""


# ------------------------------------------------------------------ setup
func _load_config() -> bool:
	if not FileAccess.file_exists(CONFIG_PATH):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not d is Dictionary:
		push_warning("cloud_config.json is not a JSON object")
		return false
	return configure(str(d.get("url", "")), str(d.get("anon_key", "")))


func configure(project_url: String, key: String) -> bool:
	url = project_url.strip_edges().trim_suffix("/")
	anon_key = key.strip_edges()
	if not url.begins_with("https://") or anon_key == "":
		url = ""
		anon_key = ""
		return false
	return true


func _start() -> void:
	_load_session()
	if meta.device_id == "":
		meta.device_id = "%08x%08x" % [randi(), randi()]
		# first run with the cloud on: the save already in this browser is the one to upload
		meta.dirty = Save.has_save()
		_save_meta()
	_set_state(State.CONNECTING)
	await sync()


func _load_meta() -> void:
	var text := Save.read_key(META_KEY, META_PATH)
	var d = JSON.parse_string(text) if text != "" else null
	if d is Dictionary:
		meta.rev = int(d.get("rev", 0))
		meta.dirty = bool(d.get("dirty", false))
		meta.wiped = bool(d.get("wiped", false))
		meta.device_id = str(d.get("device_id", ""))


func _save_meta() -> void:
	Save.write_key(META_KEY, META_PATH, JSON.stringify(meta))


func _load_session() -> void:
	var text := Save.read_key(AUTH_KEY, AUTH_PATH)
	var d = JSON.parse_string(text) if text != "" else null
	session = d if d is Dictionary else {}


func _save_session() -> void:
	Save.write_key(AUTH_KEY, AUTH_PATH, JSON.stringify(session))


func _set_state(s: State, err: String = "") -> void:
	if s != state or err != last_error:
		Trace.rec("cloud", State.keys()[s].to_lower(), {"err": err} if err != "" else {})
	state = s
	last_error = err
	status_changed.emit()


# ------------------------------------------------------------------ local hooks
func _on_local_written() -> void:
	if _applying:
		return
	_write_seq += 1
	if not meta.dirty or meta.wiped:
		meta.dirty = true
		meta.wiped = false
		_save_meta()


func _on_local_wiped() -> void:
	_write_seq += 1
	meta.dirty = true
	meta.wiped = true
	_save_meta()


func _on_flush() -> void:
	# the tab is going away: one last try (the browser may cut it off; the next start catches up)
	if state == State.OK and meta.dirty and not _busy:
		upload()


func _process(delta: float) -> void:
	if state == State.OFF or state == State.CONNECTING or state == State.CONFLICT or _busy:
		return
	_t += delta
	if state == State.OFFLINE and _t >= RETRY_SEC:
		_t = 0.0
		sync()
	elif state == State.OK and meta.dirty and _t >= UPLOAD_SEC:
		_t = 0.0
		upload()


# ------------------------------------------------------------------ sync
## full round: sign in if needed, read the cloud row, then pull, upload or flag a conflict
func sync() -> void:
	if url == "" or _busy:
		return
	_busy = true
	await _sync()
	_busy = false


func _sync() -> void:
	if not await _ensure_session():
		return
	var r := await _rpc("rpc_load", {})
	if not r.ok:
		return
	var save = r.body.get("save")
	var rrev := int(save.get("rev", 0)) if save is Dictionary else 0
	var local_empty := not Save.has_save()
	if rrev == int(meta.rev):
		if meta.dirty:
			await _upload(false)
		else:
			_ok()
	elif rrev > int(meta.rev):
		# the cloud moved on (another device, or this browser lost its storage). Take it when nothing
		# here would be lost and no run is open; otherwise the player picks.
		if not Game.started and (not meta.dirty or (local_empty and not meta.wiped)):
			_pull(save)
		else:
			_flag_conflict(save)
	else:
		# the cloud is behind what this device saw (row deleted / new account): rebuild it from here
		meta.rev = rrev
		meta.dirty = meta.dirty or not local_empty
		_save_meta()
		if meta.dirty:
			await _upload(false)
		else:
			_ok()


## sends the local save; force = overwrite whatever the cloud holds (player chose this device)
func upload(force: bool = false) -> void:
	if url == "" or _busy:
		return
	_busy = true
	if await _ensure_session():
		await _upload(force)
	_busy = false


func _upload(force: bool) -> void:
	var seq := _write_seq
	var data := Save.read()
	if data.is_empty() and not meta.wiped and not force:
		# nothing to send and nothing was erased on purpose: never blank the cloud by accident
		meta.dirty = false
		_save_meta()
		_ok()
		return
	var r := await _rpc("rpc_save", {
		"p_base_rev": int(meta.rev), "p_data": data, "p_settings": Settings.v,
		"p_schema": SCHEMA, "p_game_version": BuildInfo.GAME_VERSION,
		"p_device_id": str(meta.device_id), "p_force": force,
	})
	if not r.ok:
		return
	if r.body.get("ok", false):
		meta.rev = int(r.body.get("rev", meta.rev))
		if seq == _write_seq:
			meta.dirty = false
			meta.wiped = false
		_save_meta()
		remote = {}
		Trace.rec("cloud", "uploaded", {"rev": meta.rev, "bytes": JSON.stringify(data).length()})
		_ok()
	elif r.body.get("conflict", false):
		# someone else wrote first: fetch what they wrote so the player can compare
		var l := await _rpc("rpc_load", {})
		if l.ok and l.body.get("save") is Dictionary:
			_flag_conflict(l.body.save)


func _ok() -> void:
	last_sync_at = now()
	_t = 0.0
	_set_state(State.OK)


func _pull(save: Dictionary) -> void:
	var data: Dictionary = save.get("data", {}) if save.get("data") is Dictionary else {}
	_applying = true
	if data.is_empty():
		Save.wipe()
	else:
		Save.write(data)
	_applying = false
	if save.get("settings") is Dictionary and not (save.settings as Dictionary).is_empty():
		Settings.apply_remote(save.settings)
	meta.rev = int(save.get("rev", 0))
	meta.dirty = false
	meta.wiped = false
	_save_meta()
	remote = {}
	Trace.rec("cloud", "pulled", {"rev": meta.rev, "from": str(save.get("device_id", ""))})
	_ok()
	pulled.emit()


func _flag_conflict(save: Dictionary) -> void:
	remote = save
	Trace.rec("cloud", "conflict", {"local_rev": meta.rev, "cloud_rev": int(save.get("rev", 0))})
	_set_state(State.CONFLICT)
	conflict.emit()


## CONFLICT: take the cloud save (restarts into it when a run is open)
func use_cloud() -> void:
	if remote.is_empty():
		return
	var was_running := Game.started
	Game.started = false        # stop autosave from writing the old run over it
	_pull(remote)
	if was_running:
		Settings._restart()


## CONFLICT: keep this device's save and overwrite the cloud
func use_local() -> void:
	if Game.started:
		Game.save_game()
	await upload(true)


# ------------------------------------------------------------------ auth
func _ensure_session() -> bool:
	if session.get("access_token", "") != "" and now() < float(session.get("expires_at", 0)) - 60.0:
		return true
	if session.get("refresh_token", "") != "":
		var r := await _call(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token",
			{"refresh_token": session.refresh_token}, false)
		if r.code == 200 and r.body is Dictionary:
			_take_session(r.body)
			return true
		if r.code == 0:
			_set_state(State.OFFLINE, r.error)
			return false
		# refresh token rejected (expired / user removed): fall through to a fresh anonymous account
		Trace.rec("cloud", "session lost", {"code": r.code})
	# anonymous sign-in (Supabase: POST /auth/v1/signup with no email or phone)
	var s := await _call(HTTPClient.METHOD_POST, "/auth/v1/signup", {"data": {}}, false)
	if s.code == 200 and s.body is Dictionary and s.body.has("access_token"):
		var fresh: bool = user_id() != str(s.body.get("user", {}).get("id", ""))
		_take_session(s.body)
		if fresh:
			# new account: its cloud row is empty, so whatever is local goes up as rev 1
			meta.rev = 0
			meta.dirty = Save.has_save()
			_save_meta()
		Trace.rec("cloud", "signed in", {"user": user_id().left(8)})
		return true
	_set_state(State.OFFLINE, r_error(s))
	return false


func _take_session(b: Dictionary) -> void:
	var exp := float(b.get("expires_at", 0))
	if exp <= 0.0:
		exp = now() + float(b.get("expires_in", 3600))
	session = {
		"access_token": str(b.get("access_token", "")),
		"refresh_token": str(b.get("refresh_token", "")),
		"expires_at": exp,
		"user_id": str(b.get("user", {}).get("id", session.get("user_id", ""))),
	}
	_save_session()


func r_error(r: Dictionary) -> String:
	if r.code == 0:
		return str(r.error)
	if r.body is Dictionary:
		for k in ["msg", "message", "error_description", "error"]:
			if r.body.has(k):
				return "%d %s" % [r.code, str(r.body[k])]
	return "HTTP %d" % r.code


# ------------------------------------------------------------------ http
## POST /rest/v1/rpc/<fn>; returns {ok, body}. A stale token is refreshed and the call retried once.
func _rpc(fn: String, args: Dictionary) -> Dictionary:
	var r := await _call(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + fn, args, true)
	if r.code == 401:
		session.erase("access_token")
		if not await _ensure_session():
			return {"ok": false}
		r = await _call(HTTPClient.METHOD_POST, "/rest/v1/rpc/" + fn, args, true)
	if r.code == 200 and r.body is Dictionary:
		if r.body.has("server_time"):
			_server_offset = float(r.body.server_time) - Time.get_unix_time_from_system()
			_has_server_time = true
		return {"ok": true, "body": r.body}
	_set_state(State.OFFLINE, r_error(r))
	return {"ok": false}


## one HTTP request; returns {code (0 = no answer), body (parsed JSON or null), error}
func _call(method: int, path: String, body: Dictionary, auth: bool) -> Dictionary:
	var headers := PackedStringArray(["apikey: " + anon_key, "Content-Type: application/json"])
	if auth:
		headers.append("Authorization: Bearer " + str(session.get("access_token", "")))
	var text := JSON.stringify(body)
	if transport != null:
		return await transport.handle(method, path, headers, text)
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT_SEC
	add_child(req)
	var err := req.request(url + path, headers, method, text)
	if err != OK:
		req.queue_free()
		return {"code": 0, "body": null, "error": "request error %d" % err}
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"code": 0, "body": null, "error": "network %d" % int(res[0])}
	var raw: PackedByteArray = res[3]
	var parsed = JSON.parse_string(raw.get_string_from_utf8()) if raw.size() > 0 else null
	return {"code": int(res[1]), "body": parsed, "error": ""}


# ------------------------------------------------------------------ tests
## autotest: point at a fake server and start like a real boot (no config file needed)
func start_for_test(fake: Object) -> void:
	transport = fake
	url = "https://test.invalid"
	anon_key = "test"
	await _start()
