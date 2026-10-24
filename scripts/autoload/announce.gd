extends Node
## MV-188: news and "new version" notices for players who are already in the game, shown by the Marquee strip
## (scripts/ui/marquee.gd) at the top of the screen. Each message scrolls across announce.loops times (default 3)
## and then hides. Two sources:
##  1. the "announce" list of features.json (Features.announcements()): the remote file, so a message needs no
##     redeploy; from/to windows work like events. Each id shows once per browser (seen ids + when, in
##     localStorage), or again every "repeat_hours" hours when the message sets it.
##  2. web/version.json, written by tools/stamp_build.sh at every web export: a newer "built" than this build's
##     own stamp means a new deploy is live -> the "new version" notice; tapping the strip saves and reloads.
## While playing on the web both files are fetched again every announce.poll_min minutes and when the tab gets the
## focus back (at most once a minute), so a player who never reloads still hears about it. Switch: announce.

signal queued      # a message was added; the strip picks it up with take()

const SEEN_KEY := "mobile_vault_announce_seen_v1"
const SEEN_PATH := "user://announce_seen.json"
const SEEN_MAX := 100
const VERSION_FILE := "version.json"
const LOOPS := 3.0
const SPEED := 40.0
const POLL_MIN := 5.0
const FOCUS_GAP_SEC := 60.0
const TIMEOUT_SEC := 10.0

var queue: Array = []          # [{id, text, loops, kind: "info" | "update"}]
var current: Dictionary = {}   # the message on the strip now ({} = none)
var seen: Dictionary = {}      # id -> unix time it was last shown in this browser
var latest: Dictionary = {}    # last version.json read: {version, built, commit}
var reload_hook: Callable      # tests replace the page reload
var _last_poll := 0.0
var _timer: Timer
var _on_visible_js: JavaScriptObject   # kept alive: the page's visibilitychange listener


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _test_run():
		var d = JSON.parse_string(Save.read_key(SEEN_KEY, SEEN_PATH)) if Save.read_key(SEEN_KEY, SEEN_PATH) != "" else null
		if d is Dictionary:
			seen = d
		elif d is Array:      # the first build stored ids only
			for id in d:
				seen[str(id)] = 0.0
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(poll)
	add_child(_timer)
	Features.changed.connect(_on_features_changed)
	_on_features_changed.call_deferred()
	if OS.has_feature("web") and not _test_run():
		# the tab coming back to the front (phone unlocked, app switched back) checks at once
		_on_visible_js = JavaScriptBridge.create_callback(_on_visibility)
		JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _on_visible_js)
		get_tree().create_timer(30.0).timeout.connect(poll)


func _on_features_changed() -> void:
	_timer.wait_time = Features.num("announce.poll_min", POLL_MIN) * 60.0
	if OS.has_feature("web") and not _test_run() and Features.on("announce"):
		if _timer.is_stopped():
			_timer.start()
	elif not _timer.is_stopped():
		_timer.stop()
	collect()


## queue the features.json messages that are open now and not yet shown in this browser
func collect() -> void:
	if not Features.on("announce"):
		return
	for a in Features.announcements():
		if has_id(a.id) or not due(a):
			continue
		var txt: String = a.text_en if Loc.lang() == "en" and a.has("text_en") else a.text
		push(txt, a.id, int(a.get("loops", -1)))


## not shown yet, or shown at least repeat_hours ago
func due(a: Dictionary) -> bool:
	if not seen.has(a.id):
		return true
	var h := float(a.get("repeat_hours", 0.0))
	return h > 0.0 and Time.get_unix_time_from_system() - float(seen[a.id]) >= h * 3600.0


## add a message (also used by GOD MODE and the tests); id "" = never remembered as seen
func push(text: String, id: String = "", loops: int = -1, kind: String = "info") -> void:
	queue.append({"id": id, "text": text, "loops": loops, "kind": kind})
	queued.emit()


func has_id(id: String) -> bool:
	if str(current.get("id", "")) == id:
		return true
	for m in queue:
		if str(m.id) == id:
			return true
	return false


## the strip takes the next message (an update notice goes first); {} when nothing waits or the switch is off
func take() -> Dictionary:
	if queue.is_empty() or not Features.on("announce"):
		return {}
	var i := 0
	for j in queue.size():
		if queue[j].kind == "update":
			i = j
			break
	current = queue.pop_at(i)
	if str(current.id) != "":
		seen[current.id] = Time.get_unix_time_from_system()
		while seen.size() > SEEN_MAX:
			seen.erase(seen.keys()[0])
		if not _test_run():
			Save.write_key(SEEN_KEY, SEEN_PATH, JSON.stringify(seen))
	Trace.rec("announce", "show %s" % (current.id if str(current.id) != "" else current.text.left(40)))
	return current


func finish() -> void:
	current = {}


func loops_for(m: Dictionary) -> int:
	return int(m.loops) if int(m.get("loops", -1)) > 0 else int(Features.num("announce.loops", LOOPS))


func speed() -> float:
	return Features.num("announce.speed", SPEED)


# ------------------------------------------------------------------ new version
## a version.json body: queue the notice when it names a newer build than this one; true when queued.
## A build without a stamp (editor, plain checkout = "dev") never asks for a reload.
func check_version(d) -> bool:
	if not d is Dictionary or not d.get("built") is String:
		return false
	latest = d
	var mine := str(BuildInfo.stamp().get("built", ""))
	var theirs := str(d.built)
	if mine == "" or theirs == "" or theirs <= mine or not Features.on("announce"):
		return false
	var id := "build:" + theirs
	if seen.has(id) or has_id(id):
		return false
	push_update(str(d.get("version", "")), id)
	return true


## the "new version" notice (GOD MODE shows it with id "" so it can be shown again)
func push_update(version: String, id: String = "") -> void:
	var txt := Loc.t("มีเวอร์ชันใหม่%s แล้ว! แตะแถบนี้หรือรีโหลดหน้าเว็บเพื่ออัปเดต (เซฟเกมให้อัตโนมัติ)") % ((" v" + version) if version != "" else "")
	push(txt, id, -1, "update")


## tap on an update notice: save, then reload the page so the browser fetches the new build
func reload_page() -> void:
	Trace.rec("announce", "reload for new version")
	Game.save_game()
	if reload_hook.is_valid():
		reload_hook.call()
	elif OS.has_feature("web"):
		JavaScriptBridge.eval("location.reload()", true)


# ------------------------------------------------------------------ polling (web only)
func poll() -> void:
	if not OS.has_feature("web") or _test_run() or not Features.on("announce"):
		return
	_last_poll = Time.get_ticks_msec() / 1000.0
	Features.fetch_remote()     # emits changed -> collect()
	var base = JavaScriptBridge.eval("location.origin + location.pathname.replace(/[^/]*$/, '')", true)
	if base == null or not str(base).begins_with("http"):
		return
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT_SEC
	add_child(req)
	# the query string skips any stale HTTP cache between deploys
	if req.request(str(base) + VERSION_FILE + "?t=%d" % int(Time.get_unix_time_from_system())) != OK:
		req.queue_free()
		return
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[0]) == HTTPRequest.RESULT_SUCCESS and int(res[1]) == 200:
		check_version(JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8()))


func _on_visibility(_args: Array) -> void:
	var hidden = JavaScriptBridge.eval("document.hidden", true)
	if not bool(hidden) and Time.get_ticks_msec() / 1000.0 - _last_poll > FOCUS_GAP_SEC:
		poll()


func _test_run() -> bool:
	var args := OS.get_cmdline_user_args()
	for a in ["--autotest", "--migrate-test", "--balance"]:
		if a in args:
			return true
	return false
