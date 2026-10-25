extends Node
## Player logs in the cloud (MV-116): Trace entries (session, error, save, economy samples, progression, combat,
## crew, expeditions, god actions) go up in batches to public.logs (supabase/migrations/0004_logs.sql). The server
## stamps each row with the player id (MV-115), so the owner can follow one player or watch errors across all.
##  * offline queue = the Trace itself: everything newer than Cloud.meta.log_t is still to send. Trace keeps the
##    last 400 entries across reloads, so a phone that played offline sends them when it is back
##  * only while the cloud save is OK (signed in). A refused / failed batch is tried again later and never touches
##    the save sync state, so a server without rpc_log can't stop saves
##  * privacy: nothing is sent before the one-time notice (Cloud.meta.log_notice) has been shown in game; the player
##    can turn it off any time (Settings "telemetry", ตั้งค่า > ความเป็นส่วนตัว). Logging starts at the first session
##    it runs in: older local entries are never uploaded
## Switch cloud_logs; tune logs.flush_sec, logs.batch. GOD → ระบบ → CLOUD LOGS.

const FLUSH_SEC := 60.0
const BATCH := 100

var sending := false
var sent_total := 0
var last_sent_at := 0.0
var last_error := ""
var _t := 0.0


func _ready() -> void:
	Save.flush_requested.connect(flush)


## the player agreed (setting on), the build allows it and the cloud is signed in
func active() -> bool:
	return Features.on("cloud_logs") and bool(Settings.get_value("telemetry")) and Cloud.state == Cloud.State.OK


func _process(delta: float) -> void:
	if not active():
		return
	if not bool(Cloud.meta.get("log_notice", false)):
		_notice()
		return
	_t += delta
	if _t >= Features.num("logs.flush_sec", FLUSH_SEC):
		_t = 0.0
		flush()


## once per browser, in game where the player sees toasts
func _notice() -> void:
	if not Game.started:
		return
	Cloud.meta.log_notice = true
	Cloud._save_meta()
	Game.toast.emit("เกมส่งบันทึกการเล่นพร้อมไอดีผู้เล่นไปที่เซิร์ฟเวอร์ และสถิติการเล่นแบบไม่ระบุตัวตนไปที่ GameAnalytics เพื่อแก้บั๊กและปรับเกม ปิดได้ที่ ตั้งค่า > ความเป็นส่วนตัว", "info")
	Trace.rec("session", "log notice shown")


## unix time of the last entry the server has; the first time: this session's start (older entries stay local).
## Many entries share one time (same frame), so log_k counts how many with exactly log_t were already sent.
func cursor() -> float:
	if not Cloud.meta.has("log_t"):
		Cloud.meta.log_t = Trace._t0
		Cloud.meta.log_k = 0
		Cloud._save_meta()
	return float(Cloud.meta.log_t)


## entries still to send, oldest first (Trace appends in time order)
func pending() -> Array:
	var c := cursor()
	var k := int(Cloud.meta.get("log_k", 0))
	var seen := 0
	var out := []
	for e in Trace.entries:
		var t := float(e.get("t", 0.0))
		if t < c:
			continue
		if t == c:
			seen += 1
			if seen <= k:
				continue
		out.append(e)
	return out


## send the next batch; true = sent (or nothing to send)
func flush() -> bool:
	if sending or not active() or not bool(Cloud.meta.get("log_notice", false)):
		return false
	var q := pending()
	if q.is_empty():
		return true
	var batch := q.slice(0, maxi(1, int(Features.num("logs.batch", BATCH))))
	var last_t := float(batch[-1].t)
	var at_last := batch.filter(func(e): return float(e.t) == last_t).size()
	sending = true
	var r: Dictionary = await Cloud.post_logs(batch)
	sending = false
	if not bool(r.get("ok", false)):
		last_error = str(r.get("error", "ส่งไม่สำเร็จ"))
		return false
	Cloud.meta.log_k = (int(Cloud.meta.get("log_k", 0)) + at_last) if last_t == float(Cloud.meta.log_t) else at_last
	Cloud.meta.log_t = last_t
	Cloud._save_meta()
	sent_total += batch.size()
	last_sent_at = Cloud.now()
	last_error = ""
	return true
