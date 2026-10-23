extends Node
## Engine bay (v4.6): the engine itself, in its walk-in room inside the cab (Data.CAB_SLOT).
## The installed engine is the van_gear "engine" item (Loot base -> TYPES key); no item = the old diesel the
## vault came with, whose numbers equal the game before v4.6.
## While the engine runs it heats towards T* = ambient + P / k (P: engine x drive mode x load x weather,
## k: cooling, + crew); above REST_AT the auto-rest parks the vault until it cools to RESUME_AT, at 120 C the
## engine dies on its own and takes damage. It wears (condition) and burns oil while running; low condition
## costs power and starts breakdowns. Crew in the cab room cool it, top up coolant and repair it, and run
## the maintenance jobs ordered from the engine menu. Its noise feeds the threat director, its alternator
## powers the rooms, its tow factor feeds Haul.
## State: Game.s.engine (heat, cond, oil, coolant, mode, auto_rest, rest_at, resting, job) + Game.s.cab (room).

signal engine_changed

## size: 1 S, 2 M, 3 L (Data.VEHICLES max_engine). speed in %. fuel: x the drivetrain's fuel per minute for
## "fuel"; per minute for "scrap" / "power". db: noise. heat / wear: multipliers. alt: power per minute to rooms.
const TYPES := {
	"diesel4": {"th": "ดีเซลเก่า 4 สูบ", "en": "OLD-TIMER I4", "size": 1, "tow": 1.0, "speed": 0.0, "fuel_kind": "fuel", "fuel": 1.0,
		"db": 78.0, "heat": 1.0, "wear": 0.6, "alt": 5.0, "weight": 0.0, "desc": "ทนสุด ซ่อมง่าย กำลังน้อย"},
	"v8": {"th": "V8 เบนซินบล็อกใหญ่", "en": "BIG-BLOCK V8", "size": 2, "tow": 1.15, "speed": 15.0, "fuel_kind": "fuel", "fuel": 1.7,
		"db": 96.0, "heat": 1.6, "wear": 1.2, "alt": 6.0, "weight": 1.5, "desc": "เร็ว เสียงดังลั่น กินน้ำมันหนัก ร้อนเร็ว"},
	"turbo6": {"th": "ดีเซลเทอร์โบ 6 สูบ", "en": "TURBO DIESEL I6", "size": 2, "tow": 1.45, "speed": 8.0, "fuel_kind": "fuel", "fuel": 1.2,
		"db": 86.0, "heat": 1.3, "wear": 0.9, "alt": 7.0, "weight": 2.5, "desc": "แรงบิดสูง ลากพ่วงเก่ง ประหยัด"},
	"woodgas": {"th": "เตาแก๊สไม้", "en": "WOOD-GAS GASIFIER", "size": 1, "tow": 0.75, "speed": -20.0, "fuel_kind": "scrap", "fuel": 0.5,
		"db": 70.0, "heat": 0.8, "wear": 1.0, "alt": 3.0, "weight": 2.0, "smoke": true, "desc": "เผาเศษไม้/เศษเหล็กแทนน้ำมัน เงียบแต่ควันเห็นไกลตอนกลางวัน"},
	"electric": {"th": "มอเตอร์ไฟฟ้าดัดแปลง", "en": "EV CONVERSION", "size": 1, "tow": 0.8, "speed": -5.0, "fuel_kind": "power", "fuel": 6.0,
		"db": 52.0, "heat": 0.5, "wear": 0.3, "alt": 0.0, "weight": 3.0, "silent": true, "desc": "เงียบเกือบสนิท ใช้ไฟแทนน้ำมัน"},
	"hybrid": {"th": "ดีเซล-ไฟฟ้า", "en": "DIESEL-ELECTRIC", "size": 3, "tow": 1.3, "speed": 0.0, "fuel_kind": "fuel", "fuel": 0.9,
		"db": 82.0, "heat": 1.0, "wear": 0.8, "alt": 10.0, "weight": 5.0, "silent": true, "desc": "แบบหัวรถจักร สลับโหมดเงียบได้ จ่ายไฟมาก"},
	"turbine": {"th": "กังหันแก๊ส", "en": "GAS TURBINE", "size": 3, "tow": 2.0, "speed": 25.0, "fuel_kind": "fuel", "fuel": 2.6,
		"db": 108.0, "heat": 2.0, "wear": 1.4, "alt": 8.0, "weight": 2.0, "desc": "แรงที่สุด เสียงหวีดดังที่สุด กินน้ำมันมหาศาล"},
	"fusion": {"th": "เซลล์ฟิวชัน", "en": "FUSION CELL", "size": 1, "tow": 1.7, "speed": 12.0, "fuel_kind": "none", "fuel": 0.0,
		"db": 60.0, "heat": 1.2, "wear": 1.0, "alt": 20.0, "weight": 4.0, "desc": "ไม่ใช้น้ำมัน จ่ายไฟมหาศาล แต่ถ้าสภาพต่ำ รังสีจะรั่ว"},
}
const SIZE_TH := ["", "S", "M", "L"]
## biggest engine each cab takes
const MAX_SIZE := {"van": 2, "bus": 3, "rig": 3, "train": 3}

## drive modes: speed, fuel, noise (dB), heat, wear
const MODES := {
	"silent": {"th": "เงียบ", "speed": 0.8, "fuel": 0.0, "db": -27.0, "heat": 0.5, "wear": 0.8},
	"eco": {"th": "ประหยัด", "speed": 0.75, "fuel": 0.7, "db": -8.0, "heat": 0.6, "wear": 0.7},
	"normal": {"th": "ปกติ", "speed": 1.0, "fuel": 1.0, "db": 0.0, "heat": 1.0, "wear": 1.0},
	"boost": {"th": "เร่ง", "speed": 1.25, "fuel": 1.6, "db": 6.0, "heat": 1.8, "wear": 1.5},
}
const MODE_ORDER := ["silent", "eco", "normal", "boost"]
const SILENT_POWER_PM := 4.0     # diesel-electric silent running drains the battery

## air temperature per biome (day / night)
const AMBIENT := {"industrial": [25.0, 15.0], "desert": [45.0, 0.0], "forest": [22.0, 14.0], "swamp": [30.0, 24.0],
	"tundra": [-15.0, -25.0], "metro": [28.0, 18.0]}
const WEATHER_HEAT := {"sandstorm": 1.2, "rain": 0.85, "storm": 0.85, "snow": 0.7}

const HOT := 95.0
const VERY_HOT := 110.0
const STALL_AT := 120.0
const RESUME_AT := 80.0
const REST_DEFAULT := 110.0
const P_SCALE := 6.0             # heat added per minute at heat 1.0
const K_BASE := 0.10             # cooling per minute per degree above ambient
const WEAR_PM := 0.03            # condition % per running minute at wear 1.0
const OIL_PM := 0.15             # oil % per running minute
const CREW_FIX_PM := 0.05        # condition % per minute per crew member (x STR/5), parked
const BREAK_BELOW := 35.0
const BREAK_PM := 0.03           # breakdown chance per running minute below BREAK_BELOW
const OFFLINE_FLOOR := 25.0
const COOLANT_TOPUP_WATER := 12.0

## maintenance jobs ordered from the menu. time = work seconds (crew speed it up), park = holds the vault
const JOBS := {
	"oil": {"th": "เปลี่ยนน้ำมันเครื่อง", "cost": {"scrap": 15, "fuel": 5}, "time": 30.0, "park": true},
	"tune": {"th": "เช็กระยะ", "cost": {"scrap": 40, "components": 3}, "time": 60.0, "park": false},
	"overhaul": {"th": "ยกเครื่อง", "cost": {"scrap": 200, "components": 20}, "time": 600.0, "park": true},
	"coolant": {"th": "เติมน้ำหล่อเย็น", "cost": {"water": 12}, "time": 10.0, "park": false},
	"bay": {"th": "อัปเกรดห้องเครื่อง", "cost": {}, "time": 120.0, "park": false},
}

var rng := RandomNumberGenerator.new()
var _break_t := 0.0


func _ready() -> void:
	rng.randomize()


# ------------------------------------------------------------------ state
func st() -> Dictionary:
	if Game.s.is_empty():
		return {}
	if not Game.s.has("engine"):
		Game.s["engine"] = default_state()
	return Game.s.engine


static func default_state() -> Dictionary:
	return {"heat": 40.0, "cond": 100.0, "oil": 100.0, "coolant": 100.0, "mode": "normal", "auto_rest": true,
		"rest_at": REST_DEFAULT, "resting": false, "job": {}}


## the installed engine's type key
func type_id() -> String:
	if Game.s.is_empty():
		return "diesel4"
	return type_of(Loot.van_equipped("engine"))


func type_of(item: Dictionary) -> String:
	if item.is_empty():
		return "diesel4"
	return str(Loot.base(item).get("engine", "diesel4"))


func t() -> Dictionary:
	return TYPES.get(type_id(), TYPES.diesel4)


func size_of(item: Dictionary) -> int:
	return int(TYPES.get(type_of(item), TYPES.diesel4).size)


func fits(item: Dictionary) -> bool:
	return size_of(item) <= int(MAX_SIZE.get(Game.tier(), 3))


## [[label, value], ...] for item tooltips
func describe_type(id: String) -> Array:
	var d: Dictionary = TYPES.get(id, TYPES.diesel4)
	var fuel := ""
	match str(d.fuel_kind):
		"fuel": fuel = "น้ำมัน x%.1f" % float(d.fuel)
		"scrap": fuel = "เศษเหล็ก %.1f/นาที" % float(d.fuel)
		"power": fuel = "ไฟ %.0f/นาที" % float(d.fuel)
		_: fuel = "ไม่ใช้"
	return [["เครื่องยนต์", "%s (ขนาด %s)" % [d.th, SIZE_TH[int(d.size)]]], ["แรงลาก", "x%.2f" % float(d.tow)],
		["ความเร็ว", "%+d%%" % int(d.speed)], ["เชื้อเพลิง", fuel], ["เสียง", "%d dB" % int(d.db)],
		["ความร้อน", "x%.1f" % float(d.heat)], ["ไฟให้ห้อง", "%+.0f/นาที" % float(d.alt)]]


func mode() -> String:
	var m := str(st().get("mode", "normal"))
	if m == "silent" and not t().get("silent", false):
		return "normal"
	return m if MODES.has(m) else "normal"


func set_mode(m: String) -> void:
	if not MODES.has(m) or (m == "silent" and not t().get("silent", false)):
		return
	st().mode = m
	engine_changed.emit()


func heat() -> float:
	return float(st().get("heat", 40.0))


func cond() -> float:
	return float(st().get("cond", 100.0))


func level() -> int:
	return int(Game.room(Data.CAB_SLOT).get("level", 1))


func crew() -> Array:
	return Game.room_workers(Data.CAB_SLOT)


## the vault is parked to let the engine cool down
func resting() -> bool:
	return bool(st().get("resting", false))


## a parked job (oil change, overhaul) holds the vault
func job_holds() -> bool:
	var j: Dictionary = st().get("job", {})
	return not j.is_empty() and bool(JOBS.get(str(j.id), {}).get("park", false))


func seized() -> bool:
	return cond() <= 0.0


func state_key() -> String:
	if seized() or (cond() < BREAK_BELOW and float(Game.s.get("stall", 0.0)) > 0.0):
		return "broken"
	if heat() >= VERY_HOT:
		return "hot"
	return "run" if Game.is_moving() else "idle"


# ------------------------------------------------------------------ effects
func ambient() -> float:
	if Game.s.is_empty():
		return 20.0
	var a: Array = AMBIENT.get(str(Data.biome(int(Game.s.biome)).id), [25.0, 15.0])
	return float(a[1]) if Game.is_night() else float(a[0])


## heat added per minute while running
func heat_in() -> float:
	var load := clampf(Haul.load_ratio(), 0.0, 2.0)
	var over := maxf(0.0, Haul.load_ratio() - 1.0)
	return P_SCALE * float(t().heat) * float(MODES[mode()].heat) * (0.7 + 0.5 * load) * (1.0 + over) \
		* float(WEATHER_HEAT.get(str(Game.s.get("weather", "clear")), 1.0))


## cooling per minute per degree above ambient
func cooling() -> float:
	var k := K_BASE * (1.0 + 0.15 * crew().size())
	if float(st().get("coolant", 100.0)) <= 0.0:
		k *= 0.5
	return k


## where the temperature settles while driving like this
func settle_temp() -> float:
	return ambient() + heat_in() / maxf(cooling(), 0.001)


func speed_mult() -> float:
	if Game.s.is_empty():
		return 1.0
	var m := (1.0 + float(t().speed) / 100.0) * float(MODES[mode()].speed)
	if cond() < 60.0:
		m *= 0.9
	if heat() >= VERY_HOT:
		m *= 0.7
	if seized():
		m *= 0.3
	return m


## tow factor x the vehicle's engine capacity (Haul)
func tow_mult() -> float:
	var m := float(t().tow)
	if cond() < 60.0:
		m *= 0.9
	if heat() >= VERY_HOT:
		m *= 0.7
	return m


func weight() -> float:
	return float(t().weight)


## engine noise in dB right now
func db() -> float:
	var d := float(t().db) + float(MODES[mode()].db)
	if cond() < 60.0:
		d += 3.0
	if Haul.load_ratio() > 1.0:
		d += 4.0
	return maxf(30.0, d)


## multiplier on the threat director's engine term (the old diesel = 1.0)
func noise_mult() -> float:
	return maxf(0.0, db() - 45.0) / 33.0


## extra threat per minute from a gasifier's smoke plume by day
func smoke_pm() -> float:
	return 1.0 if t().get("smoke", false) and Game.is_moving() and not Game.is_night() else 0.0


## alternator: power per minute to the rooms while the engine runs
func power_pm() -> float:
	if not Game.is_moving():
		return 0.0
	return float(t().alt) * (1.0 + 0.25 * float(level() - 1)) * (0.6 + 0.4 * cond() / 100.0)


## what the engine burns per minute while driving: {"fuel": x} / {"scrap": x} / {"power": x}
func burn_pm() -> Dictionary:
	var kind := str(t().fuel_kind)
	var md: Dictionary = MODES[mode()]
	if mode() == "silent":
		return {"power": SILENT_POWER_PM if type_id() == "hybrid" else float(t().fuel) * 0.8}
	match kind:
		"fuel":
			return {"fuel": Haul.fuel_pm() * float(t().fuel) * float(md.fuel)}
		"scrap":
			var f := 0.75 if str(Data.biome(int(Game.s.biome)).id) == "forest" else 1.0
			return {"scrap": float(t().fuel) * f * float(md.fuel)}
		"power":
			var cold := 1.4 if ambient() < 0.0 else 1.0
			return {"power": float(t().fuel) * cold * float(md.fuel)}
	return {}


## nothing left to burn: the vault crawls
func starved() -> bool:
	if Game.s.is_empty():
		return false
	var b := burn_pm()
	for k in b:
		if float(Game.s.res.get(k, 0.0)) <= 0.0:
			return true
	return false


func blocked_reason() -> String:
	if resting():
		return "พักเครื่อง %d°C" % int(heat())
	if job_holds():
		return "ช่างกำลัง%s" % str(JOBS[str(st().job.id)].th)
	return ""


# ------------------------------------------------------------------ simulation
## called every sim step from Game._simulate (dt seconds, m = dt / 60). `running` = the vault is driving.
func tick(dt: float, m: float, running: bool, offline: bool) -> void:
	var e := st()
	if e.is_empty():
		return
	var amb := ambient()
	var h := heat()
	if running:
		h += (heat_in() - cooling() * (h - amb)) * m
		var wear := WEAR_PM * float(t().wear) * float(MODES[mode()].wear)
		if h >= HOT:
			wear *= 1.5
		if float(e.oil) < 20.0:
			wear *= 2.0
		wear *= 1.0 + 3.0 * maxf(0.0, Haul.load_ratio() - 1.0)
		e.cond = maxf(OFFLINE_FLOOR if offline else 0.0, float(e.cond) - wear * m) if float(e.cond) > 0.0 else 0.0
		e.oil = maxf(0.0, float(e.oil) - OIL_PM * (0.5 + 0.5 * float(t().wear)) * m)
		if h >= VERY_HOT:
			e.coolant = maxf(0.0, float(e.coolant) - 2.0 * m)
		_breakdowns(m, offline)
		if mode() == "silent" and float(Game.s.res.power) < Game.cap("power") * 0.3:
			e.mode = "normal"
			if not offline:
				Game.toast.emit("แบตต่ำ: กลับไปใช้เครื่องดีเซล", "warn")
	else:
		h -= cooling() * 1.5 * (h - amb) * m
	# auto-rest / forced stop
	if not bool(e.resting):
		if h >= STALL_AT:
			e.resting = true
			e.cond = maxf(OFFLINE_FLOOR if offline else 0.0, float(e.cond) - 5.0)
			e.coolant = maxf(0.0, float(e.coolant) - 20.0)
			Game._add_res("water", -5.0)
			if not offline:
				Game.toast.emit("เครื่องร้อนจัดจนดับ! จอดพักจนเย็น สภาพเครื่อง -5%", "warn")
			Trace.rec("engine", "overheat stall", {"type": type_id(), "heat": int(h)})
			_changed()
		elif running and (bool(e.auto_rest) or offline) and h >= float(e.rest_at):
			e.resting = true
			if not offline:
				Game.toast.emit("เครื่องร้อน %d°C จอดพักเครื่องอัตโนมัติ" % int(h), "warn")
			_changed()
	elif h <= RESUME_AT:
		e.resting = false
		if not offline:
			Game.toast.emit("เครื่องเย็นลงแล้ว ออกเดินทางต่อ", "good")
		_changed()
	e.heat = clampf(h, amb, 130.0)
	_crew_work(m, running, offline)
	_tick_job(dt, offline)


func _breakdowns(m: float, offline: bool) -> void:
	if offline or cond() >= BREAK_BELOW or float(Game.s.stall) > 0.0:
		return
	if rng.randf() < BREAK_PM * m:
		Game.s.stall = 45.0
		Game.toast.emit("เครื่องดับกลางทาง! สภาพเครื่องต่ำ รอช่างซ่อม 45 วินาที", "warn")
		Trace.rec("engine", "breakdown", {"cond": int(cond())})
		_changed()


## crew in the cab room: repair a little, top up coolant from the water tank
func _crew_work(m: float, running: bool, offline: bool) -> void:
	var e := st()
	var fix := 0.0
	for d in crew():
		var k := float(d.str) / 5.0 * (1.4 if Crew.has(d, "mechanic") else 1.0) * (1.0 + Skills.val(d, "repair") * 0.25)
		fix += CREW_FIX_PM * k
	if fix > 0.0 and float(e.cond) > 0.0:
		e.cond = minf(100.0, float(e.cond) + fix * (0.35 if running else 1.0) * m)
	if not crew().is_empty() and float(e.coolant) < 60.0 and float(Game.s.res.water) >= COOLANT_TOPUP_WATER:
		Game._add_res("water", -COOLANT_TOPUP_WATER)
		e.coolant = 100.0
		if not offline:
			Game.toast.emit("ช่างเติมน้ำหล่อเย็นแล้ว (-%d น้ำ)" % int(COOLANT_TOPUP_WATER), "good")


# ------------------------------------------------------------------ jobs
func job_cost(id: String) -> Dictionary:
	if id == "bay":
		var lv := level()
		return {} if lv >= Data.ROOM_MAX_LEVEL else {"scrap": int(Data.ROOM_UPGRADE_COST[lv + 1])}
	return JOBS[id].cost


func job_time(id: String) -> float:
	return float(JOBS[id].time) * (float(level()) if id == "bay" else 1.0)


## why a job can't start now ("" = it can)
func job_block(id: String) -> String:
	if not JOBS.has(id):
		return "?"
	if not (st().get("job", {}) as Dictionary).is_empty():
		return "มีงานค้างอยู่"
	if id == "bay" and level() >= Data.ROOM_MAX_LEVEL:
		return "เลเวลสูงสุดแล้ว"
	if id == "oil" and float(st().oil) >= 99.0:
		return "น้ำมันเครื่องยังเต็ม"
	if id == "coolant" and float(st().coolant) >= 99.0:
		return "หม้อน้ำยังเต็ม"
	if id in ["tune", "overhaul"] and cond() >= 99.5:
		return "เครื่องสภาพดีอยู่แล้ว"
	if not Game.can_afford(job_cost(id)):
		return "ของไม่พอ"
	return ""


func start_job(id: String) -> bool:
	if job_block(id) != "":
		return false
	Game.pay(job_cost(id))
	st().job = {"id": id, "left": job_time(id), "total": job_time(id)}
	Trace.rec("engine", "job " + id, {})
	_changed()
	return true


func job_speed() -> float:
	var sp := 0.5
	for d in crew():
		sp += 0.5 * float(d.str) / 5.0 * (1.4 if Crew.has(d, "mechanic") else 1.0)
	return sp


func job_left_sec() -> float:
	var j: Dictionary = st().get("job", {})
	return 0.0 if j.is_empty() else float(j.left) / job_speed()


func _tick_job(dt: float, offline: bool) -> void:
	var e := st()
	var j: Dictionary = e.get("job", {})
	if j.is_empty():
		return
	j.left = float(j.left) - dt * job_speed()
	if float(j.left) > 0.0:
		return
	var id := str(j.id)
	e.job = {}
	match id:
		"oil":
			e.oil = 100.0
		"tune":
			e.cond = minf(100.0, maxf(1.0, float(e.cond)) + 20.0)
		"overhaul":
			e.cond = 100.0
			e.oil = 100.0
		"coolant":
			e.coolant = 100.0
		"bay":
			Game.s.cab.level = mini(Data.ROOM_MAX_LEVEL, level() + 1)
	if not offline:
		Game.toast.emit("%s เสร็จแล้ว" % str(JOBS[id].th), "good")
	_changed()


func _changed() -> void:
	engine_changed.emit()
	Game.travel_changed.emit()
	Game.rooms_changed.emit()


# ------------------------------------------------------------------ swapping
## installed + stash engines that fit this cab
func owned_engines() -> Array:
	var out := []
	var cur := Loot.van_equipped("engine")
	if not cur.is_empty():
		out.append(cur)
	for it in Loot.stash():
		if str(it.slot) == "engine":
			out.append(it)
	return out


## the old diesel goes back in when the installed engine is taken out
func uninstall() -> bool:
	if Loot.van_equipped("engine").is_empty():
		return false
	Loot.unequip({}, "engine")
	_changed()
	return true
