extends Node
## Cloud save on Supabase (Auth + PostgREST RPC), called with HTTPRequest (no addon).
##  * local-first: Save (localStorage on web / user:// on desktop) stays what the game reads and writes;
##    this autoload mirrors it to the `saves` table and keeps working offline
##  * first run signs in anonymously (no sign-up screen); an existing local save is uploaded as rev 1
##  * every write goes through rpc_save, which only accepts it if the client saw the latest rev, so two
##    devices never overwrite each other silently: the player picks one (state CONFLICT)
##  * every reply carries server_time; now() uses it so offline progress follows the server clock
##  * accounts: a guest (anonymous) can link Google so the same user id, and so the same save, follows
##    the player to other devices; "sign in with Google" on another device switches to that account.
##    Google uses Supabase's redirect (implicit) flow: the page leaves for Google and comes back with the
##    session in the URL fragment, which _start() reads. The title screen asks once per browser: play as
##    Guest (link Google later from Settings) or log in with Gmail (a browser with no progress signs
##    straight in and gets that account's save). A Google session the server refuses is never turned
##    into a guest quietly: need_login asks the player to log in again, the local save stays.
## Config: res://cloud_config.json {"url": "https://<ref>.supabase.co", "anon_key": "<anon/publishable key>",
##   "site_url": "<public game URL, used when the game runs inside a frame where Google refuses to sign in>"}.
## The file is git-ignored; without it the cloud is OFF and the game behaves exactly as before.
## Schema: supabase/migrations/0001_cloud_save.sql, 0002_schema_guard.sql, 0003_player_id.sql, 0006_anticheat.sql

signal status_changed
signal pulled      # a newer cloud save was written locally (title screen re-checks CONTINUE)
signal conflict    # the cloud holds progress from another device that this one has not seen
signal account_changed   # signed in / linked / signed out, or the account info was refreshed

enum State { OFF, CONNECTING, OK, OFFLINE, CONFLICT }

const CONFIG_PATH := "res://cloud_config.json"
const AUTH_KEY := "mobile_vault_auth_v1"
const AUTH_PATH := "user://cloud_auth.json"
const META_KEY := "mobile_vault_cloud_v1"
const META_PATH := "user://cloud_meta.json"
const SCHEMA := 2     # 2 = account envelope (Account); the server refuses writes from older clients
const UPLOAD_SEC := 60.0     # while playing, upload at most once a minute (local autosave stays at 15 s)
const RETRY_SEC := 30.0      # offline: try again this often
const TIMEOUT_SEC := 15.0
## player id alphabet: Crockford base32 with U for D, so nothing reads as 0 (O, D: the UI font draws 0 almost
## like D) or 1 (I, L). Support can normalise O/D -> 0 and I/L -> 1 when a player reads the id out.
const PID_CHARS := "0123456789ABCEFGHJKMNPQRSTUVWXYZ"

var state := State.OFF
var last_error := ""
var url := ""
var anon_key := ""
## access_token, refresh_token, expires_at (unix), user_id, email, anonymous (bool), provider
var session := {}
var site_url := ""
## last account problem to show the player (Thai), e.g. this Google account already has its own save
var auth_error := ""
## identity_already_exists after "link Google": the player can switch to that account instead
var link_taken := false
## tests replace this to see where the page would go instead of leaving it
var navigate_hook := Callable()
## rev = cloud revision this device last saw; dirty = local save changed since; wiped = progress reset
## (an empty save is uploaded on purpose); device_id = random per browser
## oauth = {mode: "link"|"signin", from: user id} while the page is away at Google
## chose = "" until the player picks Guest or Google on the title screen ("guest" / "google")
## log_t / log_k / log_notice = Telemetry's upload cursor (time + entries already sent at that time) and
## "privacy notice shown" (MV-116)
var meta := {"rev": 0, "dirty": false, "wiped": false, "device_id": "", "oauth": {}, "chose": ""}
## the Google session ended (refresh refused): wait for the player to log in again or pick Guest,
## instead of quietly turning this browser into a new guest
var need_login := false
## CONFLICT: what the cloud holds {rev, device_id, updated_at, data, settings}
var remote := {}
var last_sync_at := 0.0
## server time (unix) of the last save the cloud accepted for this account, 0 = not known yet. Caps the offline
## catch-up (Game.offline_elapsed), so editing saved_at in local storage can't buy extra time (MV-174).
var server_seen := 0.0
## the server refused the last write because it came too soon after the one before (0006_anticheat.sql)
var rate_limited := 0
## tests inject an object with handle(method: int, path: String, headers: PackedStringArray, body: String) -> {code, body}
var transport: Object = null

var _server_offset := 0.0
var _has_server_time := false
var _busy := false
var _t := 0.0
var _write_seq := 0
var _applying := false
var _refreshing := false
var _user_checked := false
signal _refresh_done


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
	# remote kill switch: Features reads its cached remote file before this runs, so it bites on the next boot
	if not Features.on("cloud_save"):
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


## short public player id (MV-115) the player can read out or copy for support: the first 48 bits of the
## auth user id in base32 (PID_CHARS), "XXXXX-XXXXX". Same on every device, kept when a guest links Google;
## supabase/migrations/0003_player_id.sql computes the same value (public.player_id) for lookups.
static func short_id(uid: String) -> String:
	var hex := uid.replace("-", "").left(12)
	if hex.length() < 12 or not hex.is_valid_hex_number():
		return ""
	var n := hex.hex_to_int()
	var out := ""
	for i in 10:
		out = PID_CHARS[n & 31] + out
		n >>= 5
	return out.left(5) + "-" + out.right(5)


## "" without an account or with the player_id switch off
func player_id() -> String:
	return short_id(user_id()) if Features.on("player_id") else ""


func status_text() -> String:
	match state:
		State.OFF: return Loc.t("ปิดอยู่ (เซฟเฉพาะในเครื่อง)")
		State.CONNECTING: return Loc.t("กำลังเชื่อมต่อ...")
		State.OK: return Loc.t("ซิงก์แล้ว") if not meta.dirty else Loc.t("รอส่งขึ้นคลาวด์")
		State.OFFLINE: return Loc.t("ออฟไลน์ เซฟในเครื่องไว้ก่อน") + ("" if last_error == "" else " (%s)" % last_error)
		State.CONFLICT: return Loc.t("เซฟในคลาวด์มาจากอีกเครื่อง เลือกว่าจะใช้อันไหน")
	return ""


# ------------------------------------------------------------------ setup
func _load_config() -> bool:
	if not FileAccess.file_exists(CONFIG_PATH):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not d is Dictionary:
		push_warning("cloud_config.json is not a JSON object")
		return false
	var c := pick_config(d, BuildInfo.cloud_project())
	if c.is_empty():
		push_warning("cloud_config.json has no keys for the \"%s\" project: cloud off in %s" % [BuildInfo.cloud_project(), BuildInfo.env()])
		return false
	site_url = str(c.get("site_url", "")).strip_edges()
	return configure(str(c.get("url", "")), str(c.get("anon_key", "")))


## MV-112: {"projects": {"prod": {url, anon_key, site_url}, "test": {...}}} -> the section for this environment's
## project. The old flat file holds only the production keys, so it counts for "prod" only: staging / uat / PR
## previews / desktop then run without a cloud instead of writing test saves into the players' project. {} = none
static func pick_config(d: Dictionary, project: String) -> Dictionary:
	if d.get("projects") is Dictionary:
		var p = d.projects.get(project)
		return p if p is Dictionary else {}
	return d if project == "prod" else {}


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
	if OS.has_feature("web") and transport == null:
		await _take_oauth_return(str(JavaScriptBridge.eval("location.hash.substring(1) + '&' + location.search.substring(1)", true)))
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
		meta.oauth = d.get("oauth", {}) if d.get("oauth") is Dictionary else {}
		meta.chose = str(d.get("chose", ""))
		# player logs (Telemetry, MV-116): last uploaded entry time, privacy notice shown
		if d.has("log_t"):
			meta.log_t = float(d.log_t)
			meta.log_k = int(d.get("log_k", 0))
		meta.log_notice = bool(d.get("log_notice", false))


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
	if _applying:
		return
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
	if not _user_checked:
		await _check_user()
	var r := await _rpc("rpc_load", {})
	if not r.ok:
		return
	var save = r.body.get("save")
	var rrev := int(save.get("rev", 0)) if save is Dictionary else 0
	server_seen = float(save.get("updated_at", 0.0)) if save is Dictionary and save.get("updated_at") != null else 0.0
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
		server_seen = float(r.body.get("server_time", server_seen))
		if seq == _write_seq:
			meta.dirty = false
			meta.wiped = false
		_save_meta()
		remote = {}
		Trace.rec("cloud", "uploaded", {"rev": meta.rev, "bytes": JSON.stringify(data).length()})
		_ok()
	elif r.body.get("rate_limited", false):
		# too soon after the last accepted write: stay dirty, the next upload round sends it (nothing is lost)
		rate_limited += 1
		Trace.rec("cloud", "rate limited", {"retry_after": r.body.get("retry_after", 0)})
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
	# Supabase rotates refresh tokens: two refreshes with the same token can revoke the session,
	# so a second caller waits for the one already in flight
	if _refreshing:
		await _refresh_done
		return session.get("access_token", "") != ""
	_refreshing = true
	var ok := await _renew_session()
	_refreshing = false
	_refresh_done.emit()
	return ok


func _renew_session() -> bool:
	if session.get("refresh_token", "") != "":
		var r := await _call(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token",
			{"refresh_token": session.refresh_token}, false)
		if r.code == 200 and r.body is Dictionary:
			_take_session(r.body)
			return true
		if r.code == 0 or r.code >= 500 or r.code == 429:
			_set_state(State.OFFLINE, r_error(r))
			return false
		Trace.rec("cloud", "session lost", {"code": r.code, "guest": is_guest()})
		if not is_guest():
			# a Google account: keep the local save and ask the player to log in again
			_lose_google_session()
			return false
		# a guest whose token was refused (user removed): fall through to a fresh anonymous account
	if need_login:
		return false
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


func _lose_google_session() -> void:
	# user_id stays: logging in to the same Google account again keeps this device's rev (no conflict)
	session = {"user_id": user_id(), "email": str(session.get("email", "")), "anonymous": true}
	_save_session()
	meta.chose = ""
	_save_meta()
	need_login = true
	auth_error = Loc.t("เซสชัน Google หมดอายุ ล็อกอินด้วย Gmail อีกครั้ง (เซฟในเครื่องยังอยู่)")
	_set_state(State.OFFLINE, Loc.t("ต้องล็อกอินใหม่"))
	account_changed.emit()


## once per start: who this stored session belongs to now (the account may have been linked to Google
## from another page, e.g. the artifact view opened the game in a new tab)
func _check_user() -> void:
	var u := await _call(HTTPClient.METHOD_GET, "/auth/v1/user", {}, true)
	if u.code == 200 and u.body is Dictionary:
		_user_checked = true
		var was_guest := is_guest()
		_take_user(u.body)
		_save_session()
		if was_guest and not is_guest() and meta.chose == "":
			meta.chose = "google"
			_save_meta()


func _take_session(b: Dictionary) -> void:
	var exp := float(b.get("expires_at", 0))
	if exp <= 0.0:
		exp = now() + float(b.get("expires_in", 3600))
	var keep := session.duplicate()
	session = {
		"access_token": str(b.get("access_token", "")),
		"refresh_token": str(b.get("refresh_token", "")),
		"expires_at": exp,
		"user_id": str(keep.get("user_id", "")),
		"email": str(keep.get("email", "")),
		"anonymous": bool(keep.get("anonymous", true)),
		"provider": str(keep.get("provider", "")),
	}
	if b.get("user") is Dictionary:
		_take_user(b.user)
	_save_session()


## GoTrue user object -> id / email / anonymous / provider in the session
func _take_user(u: Dictionary) -> void:
	session.user_id = str(u.get("id", session.get("user_id", "")))
	session.email = str(u.get("email", "")) if u.get("email") != null else ""
	session.anonymous = bool(u.get("is_anonymous", session.email == ""))
	var am = u.get("app_metadata", {})
	var provs: Array = am.get("providers", []) if am is Dictionary and am.get("providers") is Array else []
	session.provider = "google" if provs.has("google") else str(am.get("provider", "") if am is Dictionary else "")
	account_changed.emit()


func r_error(r: Dictionary) -> String:
	if r.code == 0:
		return str(r.error)
	if r.body is Dictionary:
		for k in ["msg", "message", "error_description", "error"]:
			if r.body.has(k):
				return "%d %s" % [r.code, str(r.body[k])]
	return "HTTP %d" % r.code


# ------------------------------------------------------------------ accounts
func is_guest() -> bool:
	return bool(session.get("anonymous", true))


## title screen: show "play as Guest / log in with Gmail" instead of the menu
func needs_choice() -> bool:
	if url == "" or state == State.OFF:
		return false
	if need_login:
		return true
	return Features.on("google_login") and is_guest() and str(meta.get("chose", "")) == ""


## the player picked Guest: keep playing on this browser's anonymous account (made now if needed)
func play_as_guest() -> void:
	auth_error = ""
	link_taken = false
	meta.chose = "guest"
	_save_meta()
	var was_lost := need_login
	need_login = false
	account_changed.emit()
	if was_lost or session.get("refresh_token", "") == "":
		await sync()


func account_text() -> String:
	if user_id() == "":
		return "-"
	if is_guest():
		return "Guest · " + user_id().left(8)
	return "Google · " + str(session.get("email", ""))


## Google sign-in needs a top-level page (Google refuses to run inside a frame such as the artifact view)
func can_google() -> bool:
	if url == "" or not Features.on("google_login"):
		return false
	if transport != null:
		return true
	return OS.has_feature("web") and not _in_frame()


func _in_frame() -> bool:
	return bool(JavaScriptBridge.eval("window.top !== window.self", true))


## where Google sends the player back: this page without query/fragment
func _return_url() -> String:
	if OS.has_feature("web") and transport == null:
		return str(JavaScriptBridge.eval("location.origin + location.pathname", true))
	return site_url if site_url != "" else "https://test.invalid/"


## guest -> link Google to this account (same user id, the save stays); otherwise sign in with Google.
## switch = true: sign in to the Google account even while a guest (the one that already has a save).
## The page leaves for Google; the result is read by _start() when it comes back.
func sign_in_google(switch: bool = false) -> void:
	auth_error = ""
	link_taken = false
	if url == "":
		return
	if not can_google():
		if site_url != "":
			OS.shell_open(site_url)
		auth_error = Loc.t("เปิดเกมในแท็บใหม่ก่อนแล้วค่อยล็อกอิน Google")
		account_changed.emit()
		return
	if Game.started:
		Game.save_game()
	var back := _return_url().uri_encode()
	var go := ""
	# link the guest only when it has progress to keep; a fresh browser signs straight in, so a returning
	# player gets their account's save instead of "this Google account is already used"
	var link := is_guest() and user_id() != "" and not switch and not need_login and (Save.has_save() or int(meta.rev) > 0)
	if link and not await _ensure_session():
		auth_error = Loc.t("ต่อคลาวด์ไม่ได้ ลองใหม่ตอนออนไลน์")
		account_changed.emit()
		return
	if link:
		# Supabase "manual linking": returns the Google URL for adding an identity to this user
		var r := await _call(HTTPClient.METHOD_GET, "/auth/v1/user/identities/authorize?provider=google&skip_http_redirect=true&redirect_to=" + back, {}, true)
		if r.code != 200 or not r.body is Dictionary or str(r.body.get("url", "")) == "":
			auth_error = Loc.t("ผูก Google ไม่สำเร็จ (%s)") % r_error(r)
			Trace.rec("cloud", "link failed", {"err": r_error(r)})
			account_changed.emit()
			return
		go = str(r.body.url)
		meta.oauth = {"mode": "link", "from": user_id()}
	else:
		go = url + "/auth/v1/authorize?provider=google&redirect_to=" + back
		meta.oauth = {"mode": "signin", "from": user_id()}
	# one last upload so nothing is lost while the page is away
	if meta.dirty and state == State.OK:
		await upload()
	_save_meta()
	Trace.rec("cloud", "google " + str(meta.oauth.mode))
	_navigate(go)


func _navigate(to: String) -> void:
	if navigate_hook.is_valid():
		navigate_hook.call(to)
	elif OS.has_feature("web"):
		JavaScriptBridge.eval("location.assign(%s)" % JSON.stringify(to), true)
	else:
		OS.shell_open(to)


## reads "#access_token=...&refresh_token=..." or "error=...&error_code=..." after Google sent the player back
func _take_oauth_return(params: String) -> void:
	var p := {}
	for kv in params.split("&", false):
		var i := kv.find("=")
		if i > 0:
			p[kv.left(i)] = kv.substr(i + 1).uri_decode().replace("+", " ")
	var pending: Dictionary = meta.get("oauth", {})
	if not p.has("access_token") and not p.has("error") and not p.has("error_code"):
		return
	if OS.has_feature("web") and transport == null:
		JavaScriptBridge.eval("history.replaceState(null, '', location.origin + location.pathname)", true)
	meta.oauth = {}
	_save_meta()
	if not p.has("access_token"):
		var code := str(p.get("error_code", p.get("error", "")))
		link_taken = code == "identity_already_exists"
		auth_error = (Loc.t("บัญชี Google นี้มีเซฟของตัวเองอยู่แล้ว กด \"สลับไปบัญชี Google\" เพื่อใช้บัญชีนั้นแทน") if link_taken
			else Loc.t("ล็อกอิน Google ไม่สำเร็จ (%s)") % str(p.get("error_description", code)))
		Trace.rec("cloud", "google failed", {"code": code})
		account_changed.emit()
		return
	var before := user_id()
	_take_session({"access_token": p.access_token, "refresh_token": p.get("refresh_token", ""),
		"expires_at": float(p.get("expires_at", 0)), "expires_in": float(p.get("expires_in", 3600))})
	var claims := _jwt_claims(str(p.access_token))
	session.user_id = str(claims.get("sub", session.user_id))
	session.anonymous = bool(claims.get("is_anonymous", false))
	var u := await _call(HTTPClient.METHOD_GET, "/auth/v1/user", {}, true)
	if u.code == 200 and u.body is Dictionary:
		_take_user(u.body)
	_save_session()
	_user_checked = true
	need_login = false
	meta.chose = "google"
	_save_meta()
	Trace.rec("cloud", "google ok", {"mode": str(pending.get("mode", "")), "same_user": user_id() == before})
	if user_id() != before:
		# another account (Google sign-in on this device): its save is the cloud row; what is local here
		# belongs to the old account, so the sync compares them (CONFLICT when both have progress)
		meta.rev = 0
		meta.dirty = Save.has_save()
		meta.wiped = false
		_save_meta()
	account_changed.emit()


## payload of a JWT (no signature check: only used to know which account this device is now on)
func _jwt_claims(token: String) -> Dictionary:
	var parts := token.split(".")
	if parts.size() < 2:
		return {}
	var b64 := parts[1].replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var d = JSON.parse_string(Marshalls.base64_to_utf8(b64))
	return d if d is Dictionary else {}


## after identity_already_exists: sign in to that Google account instead (its save wins unless the player picks)
func switch_to_google() -> void:
	await sign_in_google(true)


## Google account -> back to a fresh guest. The save is uploaded first; if that fails nothing changes.
## The local copy is removed (it lives in the Google account) so the new guest starts clean.
func sign_out() -> bool:
	auth_error = ""
	if is_guest():
		return false
	if Game.started:
		Game.save_game()
	if meta.dirty:
		await upload()
		if meta.dirty:
			auth_error = Loc.t("ยังส่งเซฟขึ้นคลาวด์ไม่ได้ ลองใหม่ตอนออนไลน์")
			account_changed.emit()
			return false
	await _call(HTTPClient.METHOD_POST, "/auth/v1/logout?scope=local", {}, true)
	Trace.rec("cloud", "signed out")
	var was_running := Game.started
	Game.started = false
	_applying = true
	Save.wipe()
	_applying = false
	session = {}
	_save_session()
	meta.rev = 0
	meta.dirty = false
	meta.wiped = false
	meta.chose = ""
	_save_meta()
	account_changed.emit()
	if was_running:
		Settings._restart()
	else:
		pulled.emit()
		await sync()
	return true


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
	var text := "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
	if transport != null:
		return await transport.handle(method, path, headers, text)
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT_SEC
	# on web the browser's fetch() already decodes gzip; skip Godot's own gzip step
	req.accept_gzip = false
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


## MV-116: one batch of Trace entries into public.logs (rpc_log, 0004_logs.sql). Uses _call, not _rpc: a failed
## or refused batch must never mark the save sync OFFLINE. {ok, error}
func post_logs(events: Array) -> Dictionary:
	if state != State.OK or str(session.get("access_token", "")) == "":
		return {"ok": false, "error": Loc.t("ยังไม่ได้เชื่อมต่อ")}
	var r := await _call(HTTPClient.METHOD_POST, "/rest/v1/rpc/rpc_log", {"p_events": events, "p_version": BuildInfo.GAME_VERSION}, true)
	if r.code == 200 and r.body is Dictionary and bool(r.body.get("ok", false)):
		return {"ok": true}
	if r.code == 200 and r.body is Dictionary:
		return {"ok": false, "error": str(r.body.get("error", Loc.t("ถูกปฏิเสธ")))}
	return {"ok": false, "error": r_error(r)}


# ------------------------------------------------------------------ tests
## autotest: point at a fake server and start like a real boot (no config file needed)
func start_for_test(fake: Object) -> void:
	transport = fake
	url = "https://test.invalid"
	anon_key = "test"
	await _start()
