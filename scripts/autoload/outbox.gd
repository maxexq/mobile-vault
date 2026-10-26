extends Node
## Server outbox (MV-424): every request to our server (Supabase: sign-in, cloud save, player logs) goes through one
## lane, so a browser never floods the server and phones that lost it together don't all come back at once.
##  * one request at a time per lane; waiting callers go by priority (sign-in, then the save, then logs), oldest first
##  * no answer, 429 or 5xx = the server is down or struggling: the lane is held for an exponential backoff with
##    jitter (base * 2^(fails - 1), capped at max, then a random 50-100 % of it). A Retry-After header wins when it is
##    longer. Any other answer (2xx, 4xx) means the server is up and clears the hold.
##  * a held lane stops the automatic traffic: Cloud's upload round and offline retry, Telemetry's batches and the last
##    try when the tab hides. What the player or GOD asks for directly ("ซิงก์ตอนนี้", "ส่ง log ตอนนี้") still goes.
##  * nothing is stored here: the data waits where it already lives (the local save + Cloud.meta.dirty, the Trace +
##    the log cursor), so a held lane loses nothing and an upload always carries the newest save, never a stale copy.
## Switch server_outbox (off = every call goes straight out with the old fixed 30 s retry); tune outbox.base_sec,
## outbox.max_sec. GOD → ระบบ → OUTBOX. Autotest --only=outbox.

signal _released

enum Prio { AUTH = 0, SAVE = 1, LOGS = 2 }

const SUPABASE := "supabase"
const BASE_SEC := 30.0
const MAX_SEC := 600.0

## tests: Callable() -> float in [0, 1) for the jitter; unset = randf()
var rng: Callable
var _lanes := {}
var _seq := 0


func on() -> bool:
	return Features.on("server_outbox")


func lane(name: String) -> Dictionary:
	if not _lanes.has(name):
		_lanes[name] = {"busy": false, "waiting": [], "fails": 0, "hold_until": 0, "ok": 0, "holds": 0, "last_code": -1}
	return _lanes[name]


## the lane is not held: automatic traffic may go
func open(name: String) -> bool:
	return not on() or Time.get_ticks_msec() >= int(lane(name).hold_until)


## seconds until the hold ends (0 = open)
func hold_left(name: String) -> float:
	return maxf(0.0, float(int(lane(name).hold_until) - Time.get_ticks_msec()) / 1000.0)


func base_sec() -> float:
	return Features.num("outbox.base_sec", BASE_SEC)


func max_sec() -> float:
	return maxf(base_sec(), Features.num("outbox.max_sec", MAX_SEC))


## the hold after this many failures in a row: doubles each time up to max, then a random 50-100 % of it
func backoff(fails: int) -> float:
	var full := minf(max_sec(), base_sec() * pow(2.0, maxi(0, fails - 1)))
	return full * (0.5 + 0.5 * (float(rng.call()) if rng.is_valid() else randf()))


## Retry-After in seconds (the HTTP-date form is ignored: 0)
static func retry_after(headers: PackedStringArray) -> float:
	for h in headers:
		if h.to_lower().begins_with("retry-after:"):
			var v: String = h.substr(12).strip_edges()
			return maxf(0.0, v.to_float()) if v.is_valid_float() or v.is_valid_int() else 0.0
	return 0.0


# =================================================================== the lane
## wait for the lane; pair every acquire with a release
func acquire(name: String, prio: int) -> void:
	if not on():
		return
	var l := lane(name)
	if not l.busy and l.waiting.is_empty():
		l.busy = true
		return
	_seq += 1
	var ticket := [prio, _seq]
	l.waiting.append(ticket)
	while l.busy or _first(l) != ticket:
		await _released
	l.waiting.erase(ticket)
	l.busy = true


func release(name: String) -> void:
	lane(name).busy = false
	_released.emit()


func _first(l: Dictionary) -> Array:
	var best: Array = []
	for t in l.waiting:
		if best.is_empty() or int(t[0]) < int(best[0]) or (int(t[0]) == int(best[0]) and int(t[1]) < int(best[1])):
			best = t
	return best


## what the server answered (code 0 = no answer); retry_sec from the Retry-After header
func report(name: String, code: int, retry_sec: float = 0.0) -> void:
	var l := lane(name)
	l.last_code = code
	if code == 0 or code == 429 or code >= 500:
		l.fails = int(l.fails) + 1
		var wait := maxf(backoff(int(l.fails)), minf(retry_sec, max_sec()))
		l.hold_until = Time.get_ticks_msec() + int(wait * 1000.0)
		l.holds = int(l.holds) + 1
		Trace.rec("cloud", "outbox hold", {"lane": name, "code": code, "fails": l.fails, "sec": snappedf(wait, 0.1)})
		return
	if int(l.fails) > 0:
		Trace.rec("cloud", "outbox open", {"lane": name, "code": code, "after": l.fails})
	l.fails = 0
	l.hold_until = 0
	l.ok = int(l.ok) + 1


## clears the hold and the failure count (GOD, tests)
func reset(name: String) -> void:
	var l := lane(name)
	l.fails = 0
	l.hold_until = 0
