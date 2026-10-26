extends Node
## GameAnalytics dashboards (MV-423) through its REST Collection API v2, no SDK or addon: sessions, map progression,
## a small fixed set of design events and errors, so retention / funnels / progression charts come for free.
## The Supabase player logs (Telemetry, MV-116) and the Discord error alerts (MV-171) stay as they are.
##  * keys: cloud_config.json "analytics": {"prod": {"game_key"}, "test": {...}}, picked by BuildInfo.cloud_project()
##    like the Supabase keys (players -> prod, staging / uat / previews -> test). No game key for this environment = off.
##  * the secret key is never in the build (MV-426: the repo is public and the build bundles cloud_config.json): on the
##    web the game posts to /api/ga on its own site (api/ga.mjs, a Vercel function), which signs with the secret from the
##    Vercel environment. A "secret_key" in a local cloud_config.json still signs here, for desktop tests only.
##  * privacy: same as the player logs: nothing before the one-time notice (Cloud.meta.log_notice), off when the
##    player turns telemetry off (Settings > ความเป็นส่วนตัว). The user id is a random id for this browser, not the
##    player id or the Supabase user.
##  * protocol: POST /v2/<game_key>/init once per session (server time + enabled), then batches of events to
##    /v2/<game_key>/events, Authorization = base64(HMAC-SHA256(secret_key, body)). Platform "webgl" on the web.
##    Kept small: well under GameAnalytics' 500 events per player per day; errors max 10 per launch (their rule).
##    An event stays in the queue until the server has answered for it: kept on a network failure or a 413 (the
##    batch size halves), dropped after any other answer (200, or 400 / 401: never resend bad data).
##  * offline: the queue is saved in this browser (mobile_vault_ga_queue_v1, user://ga_queue.json) whenever it
##    changes, so events from a trip without signal survive closing the tab and go up on the next start. At most
##    QUEUE_MAX events; when full, whole oldest sessions are dropped first (GameAnalytics' advice). Turning
##    telemetry off clears it.
## Switch game_analytics; tune analytics.flush_sec. GOD → ระบบ → GAMEANALYTICS. Autotest --only=analytics.

const HOST := "https://api.gameanalytics.com"
const FLUSH_SEC := 20.0
const QUEUE_MAX := 300
const BATCH_MAX := 100
const QUEUE_KEY := "mobile_vault_ga_queue_v1"
const QUEUE_PATH := "user://ga_queue.json"
const ERRORS_MAX := 10
const META_KEY := "mobile_vault_ga_v1"
const META_PATH := "user://ga.json"
## GameAnalytics' id parts: letters, digits, space and - _ . ( ) ! ?
const ID_OK := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_.()!?"

var game_key := ""
var secret_key := ""
var proxy := ""                 # MV-426: path of the signing function on the page's own site ("/api/ga")
var enabled := true             # the server's init answer can switch collection off
var queue: Array = []
var sent_total := 0
var last_error := ""
var errors_sent := 0
## tests: Callable(route: String, body: String, auth: String) -> int (HTTP code); set = no network at all
var transport: Callable
var _meta := {"uid": "", "sessions": 0}
var _session_id := ""
var _session_start := 0.0
var _ts_offset := 0.0
var _t := 0.0
var _busy := false
var _batch_max := BATCH_MAX
var _http: HTTPRequest
var _inflight: Array = []


func _ready() -> void:
	_load_keys()
	_load_meta()
	_load_queue()
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_done)
	Save.flush_requested.connect(_on_hide)
	Game.game_started.connect(func(): start_session())
	Game.biome_changed.connect(_on_biome)
	Game.vault_level_changed.connect(func(l): if Game.started: design("Vault:Level", float(l)))
	Game.event_triggered.connect(func(id): design("RoadEvent:" + id))
	Game.construction_finished.connect(_on_built)
	Expedition.expedition_finished.connect(func(r): design("Expedition:%s:%s" % ["Success" if r.get("ok", false) else "Fail", str(r.get("site", "unknown"))]))
	Combat.squad_wiped.connect(func(): design("Combat:SquadWiped", float(Combat.wave())))
	Meta.wrecked.connect(func(): design("Meta:Wrecked"))
	Meta.generation_started.connect(func(g): design("Meta:Generation", float(g)))
	Tutorial.finished.connect(func(skipped): design("Tutorial:" + ("Skipped" if skipped else "Completed")))
	Trace.recorded.connect(_on_trace)


# =================================================================== state
func configured() -> bool:
	return game_key != "" and (secret_key != "" or (proxy != "" and (OS.has_feature("web") or transport.is_valid())))


## how events get signed (GOD)
func mode() -> String:
	return "signed here (local secret)" if secret_key != "" else ("via %s" % proxy if proxy != "" else "-")


## the build, the keys, the server and the player allow it (the privacy notice may still be due)
func allowed() -> bool:
	return Features.on("game_analytics") and configured() and enabled and bool(Settings.get_value("telemetry")) \
		and (transport.is_valid() or not _is_test_run())


func active() -> bool:
	return allowed() and bool(Cloud.meta.get("log_notice", false))


func status() -> String:
	if not Features.on("game_analytics"):
		return "switch off"
	if not configured():
		return "no keys for %s" % BuildInfo.cloud_project() if game_key == "" else "no signer (desktop without a local secret)"
	if not enabled:
		return "disabled by server"
	if not bool(Settings.get_value("telemetry")):
		return "player opted out"
	if not bool(Cloud.meta.get("log_notice", false)):
		return "waiting for the privacy notice"
	return "on"


func _is_test_run() -> bool:
	var args := OS.get_cmdline_user_args()
	return "--autotest" in args or "--balance" in args or "--migrate-test" in args


func _load_keys() -> void:
	game_key = ""
	secret_key = ""
	proxy = ""
	if not FileAccess.file_exists(Cloud.CONFIG_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(Cloud.CONFIG_PATH))
	if not (d is Dictionary) or not (d.get("analytics") is Dictionary):
		return
	var k = d.analytics.get(BuildInfo.cloud_project())
	if k is Dictionary:
		set_keys(str(k.get("game_key", "")), str(k.get("secret_key", "")), str(k.get("proxy", "/api/ga")))


func set_keys(gk: String, sk: String, px: String = "/api/ga") -> void:
	game_key = gk.strip_edges()
	secret_key = sk.strip_edges()
	proxy = px.strip_edges()


func _load_meta() -> void:
	var text := Save.read_key(META_KEY, META_PATH)
	var d = JSON.parse_string(text) if text != "" else null
	if d is Dictionary:
		_meta.uid = str(d.get("uid", ""))
		_meta.sessions = int(d.get("sessions", 0))
	if _meta.uid == "":
		_meta.uid = uuid()
		Save.write_key(META_KEY, META_PATH, JSON.stringify(_meta))


func uuid() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


# =================================================================== events
## one GameAnalytics session per visible stretch of play: starts with the game (or when the tab comes back after a
## session_end), ends when the page is hidden
func start_session() -> void:
	if not active() or _session_id != "":
		return
	_session_id = uuid()
	_session_start = Time.get_unix_time_from_system()
	_meta.sessions = int(_meta.sessions) + 1
	Save.write_key(META_KEY, META_PATH, JSON.stringify(_meta))
	_init_request()
	_add({"category": "user"})


func end_session() -> void:
	if _session_id == "":
		return
	_add({"category": "session_end", "length": clampi(int(Time.get_unix_time_from_system() - _session_start), 0, 172800)})
	flush()
	_session_id = ""


## a design event: up to 5 parts joined by ':', each cleaned to GameAnalytics' allowed characters
func design(event_id: String, value: float = NAN) -> void:
	var ev := {"category": "design", "event_id": clean_id(event_id, 5)}
	if not is_nan(value):
		ev["value"] = value
	_add(ev)


## status Start / Complete / Fail, 1-3 levels ("Map:desert")
func progression(status: String, levels: String) -> void:
	_add({"category": "progression", "event_id": status + ":" + clean_id(levels, 3)})


func error(severity: String, message: String) -> void:
	if errors_sent >= ERRORS_MAX:
		return
	errors_sent += 1
	_add({"category": "error", "severity": severity, "message": message.left(8192)})


static func clean_id(id: String, max_parts: int) -> String:
	var parts := []
	for p in id.split(":", false):
		var s := ""
		for ch in p:
			s += ch if ID_OK.contains(ch) else "_"
		s = s.strip_edges().left(64)
		parts.append(s if s != "" else "unknown")
	if parts.is_empty():
		parts.append("unknown")
	return ":".join(parts.slice(0, max_parts))


func _on_biome(i: int, instant: bool) -> void:
	if instant or not Game.started:
		return
	if i > 0:
		progression("Complete", "Map:" + str(Data.biome(i - 1).id))
	progression("Start", "Map:" + str(Data.biome(i).id))


func _on_built(slot: int, kind: String) -> void:
	var r := Game.room(slot)
	if r.is_empty():
		return
	if kind == "build":
		design("Room:Built:" + str(r.type))
	else:
		design("Room:Upgraded:" + str(r.type), float(r.get("level", 1)))


func _on_trace(e: Dictionary) -> void:
	if str(e.get("cat", "")) == "error" and not str(e.get("msg", "")).contains("GOD test error"):
		error("error", str(e.get("msg", "")))


func _on_hide() -> void:
	end_session()


## shared annotations GameAnalytics wants on every event
func _annotations() -> Dictionary:
	var web := OS.has_feature("web")
	return {"v": 2, "user_id": str(_meta.uid), "session_id": _session_id, "session_num": maxi(1, int(_meta.sessions)),
		"sdk_version": "rest api v2", "platform": "webgl" if web else "windows", "os_version": "webgl 1.0" if web else "windows 10",
		"manufacturer": "unknown", "device": "unknown", "build": BuildInfo.GAME_VERSION.left(32),
		"client_ts": int(Time.get_unix_time_from_system() + _ts_offset), "custom_01": BuildInfo.env()}


func _add(ev: Dictionary) -> void:
	if not active():
		return
	if _session_id == "" and ev.category != "user":
		start_session()
	var full := _annotations()
	full.merge(ev, true)
	queue.append(full)
	_trim()
	_persist()


## over the cap: drop the oldest session's events as a whole (a single huge session loses its oldest events)
func _trim() -> void:
	while queue.size() > QUEUE_MAX:
		var oldest := str(queue[0].get("session_id", ""))
		var rest := queue.filter(func(e): return str(e.get("session_id", "")) != oldest)
		if rest.is_empty():
			queue.pop_front()
		else:
			queue = rest


# =================================================================== offline queue
func _persist() -> void:
	Save.write_key(QUEUE_KEY, QUEUE_PATH, JSON.stringify(queue))


func _load_queue() -> void:
	var text := Save.read_key(QUEUE_KEY, QUEUE_PATH)
	var d = JSON.parse_string(text) if text != "" else null
	queue = []
	if d is Array:
		for e in d:
			if e is Dictionary and e.has("category"):
				# JSON gives floats back; GameAnalytics wants whole numbers here
				for k in ["v", "session_num", "client_ts", "length", "attempt_num", "score"]:
					if e.has(k):
						e[k] = int(e[k])
				queue.append(e)
	_trim()


func clear_queue() -> void:
	queue.clear()
	_persist()


# =================================================================== transport
func _process(delta: float) -> void:
	if not allowed():
		if not queue.is_empty() and not bool(Settings.get_value("telemetry")):
			clear_queue()        # the player opted out: nothing waiting to go up either
		return
	if not bool(Cloud.meta.get("log_notice", false)):
		Telemetry._notice()      # the same one-time notice as the player logs, also when the cloud is off
		return
	if Game.started and _session_id == "":
		start_session()          # the tab came back after a session_end
	_t += delta
	if _t >= Features.num("analytics.flush_sec", FLUSH_SEC):
		_t = 0.0
		flush()


static func hmac_auth(body: String, key: String) -> String:
	return Marshalls.raw_to_base64(Crypto.new().hmac_digest(HashingContext.HASH_SHA256, key.to_utf8_buffer(), body.to_utf8_buffer()))


func _init_request() -> void:
	var body := JSON.stringify({"platform": _annotations().platform, "os_version": _annotations().os_version,
		"sdk_version": "rest api v2", "build": BuildInfo.GAME_VERSION.left(32), "user_id": str(_meta.uid), "random_salt": randi()})
	_send("init", body, [])


## sends the oldest events as one batch (one request at a time); they leave the queue only once answered
func flush() -> void:
	if queue.is_empty() or not configured() or not active():
		return
	if _busy and not transport.is_valid():
		return
	var batch := queue.slice(0, mini(queue.size(), _batch_max))
	_send("events", JSON.stringify(batch), batch)


## MV-426: without a local secret the body goes unsigned to the signing function on this site (auth = "")
func _send(route: String, body: String, batch: Array) -> void:
	var auth := hmac_auth(body, secret_key) if secret_key != "" else ""
	if transport.is_valid():
		_result(route, int(transport.call(route, body, auth)), "", batch)
		return
	if _busy:
		return
	_busy = true
	_inflight = [route, batch]
	var headers := PackedStringArray(["Content-Type: application/json"])
	var target := "%s/v2/%s/%s" % [HOST, game_key, route]
	if auth != "":
		headers.append("Authorization: " + auth)
	else:
		target = "%s%s?route=%s&game=%s" % [_origin(), proxy, route, game_key.uri_encode()]
	var err := _http.request(target, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_busy = false
		_result(route, 0, "request error %d" % err, batch)


func _origin() -> String:
	return str(JavaScriptBridge.eval("location.origin", true)) if OS.has_feature("web") else ""


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var route: String = _inflight[0] if _inflight.size() > 0 else ""
	var batch: Array = _inflight[1] if _inflight.size() > 1 else []
	_inflight = []
	_result(route, code if result == HTTPRequest.RESULT_SUCCESS else 0, body.get_string_from_utf8().left(300), batch)


## code 0 = no answer (offline), 429 / 5xx (GameAnalytics or the signing function struggling, 502 = unreachable) or 413:
## the batch stays queued (smaller next time on 413). 200 / 400 / 401 / 403 ...: done
func _result(route: String, code: int, text: String, batch: Array) -> void:
	if route == "init":
		var d = JSON.parse_string(text) if text != "" else null
		if code in [200, 201] and d is Dictionary:
			_ts_offset = float(d.get("server_ts", Time.get_unix_time_from_system())) - Time.get_unix_time_from_system()
			enabled = bool(d.get("enabled", true))
		elif code != 0:
			last_error = "init %d" % code
		return
	if code == 0 or code == 413 or code == 429 or code >= 500:
		last_error = "offline" if code == 0 else ("413 too large" if code == 413 else "server %d" % code)
		if code == 413:
			_batch_max = maxi(5, _batch_max / 2)
		return
	queue = queue.filter(func(e): return not batch.any(func(b): return is_same(b, e)))
	_persist()
	if code == 200:
		sent_total += batch.size()
		last_error = ""
		_batch_max = BATCH_MAX
	else:
		last_error = "%d %s" % [code, text.left(120)]
