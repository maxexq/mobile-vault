extends Node
## Biomes & hazards: the road changes and the vault has to adapt.
##  COLD  (Frozen Highway, snow, desert nights) -> burns FUEL for heating; out of fuel = freezing
##  HEAT  (desert days)                         -> water use x1.5
##  SAND  (sandstorm)                           -> solar panels choke + get dirty, truck slows
##  RAD   (Toxic Bayou = radiation zone, hot spots elsewhere) -> survivors soak up rads
##  ACID / ASH (weather)                         -> hull corrosion / dirty panels
## Mods, traits, skills and rooms (refinery, medical, water) are the counter-play.

const HAZARDS := {
	"cold": {"th": "หนาวจัด", "en": "COLD", "icon": "snow", "col": "2858b8",
		"tip": "เผาเชื้อเพลิงเพื่อทำความร้อน · เชื้อเพลิงหมด = ผู้รอดชีวิตหนาวสั่น ผลิตลดลง เสียเลือด", "fix": "โรงกลั่นเชื้อเพลิง · ฉนวนกันหนาว · หม้อต้ม · ถังน้ำมันสำรอง · Trait ทนหนาว"},
	"heat": {"th": "ร้อนระอุ", "en": "HEAT", "icon": "thermo", "col": "e07010",
		"tip": "ทุกคนดื่มน้ำมากขึ้น 50%", "fix": "เครื่องกรองน้ำ · เครื่องรีไซเคิลน้ำ · ผ้าใบดักน้ำฝน"},
	"sand": {"th": "พายุทราย", "en": "SANDSTORM", "icon": "sand", "col": "a87840",
		"tip": "แผงโซลาร์แทบไม่ได้ไฟและสกปรกเร็ว · รถวิ่งช้า", "fix": "ฝาครอบโซลาร์ · ตีนตะขาบ · เครื่องปั่นไฟ (เผาเชื้อเพลิง)"},
	"rad": {"th": "เขตรังสี", "en": "RADIATION", "icon": "rad", "col": "4a8a10",
		"tip": "ผู้รอดชีวิตสะสมรังสี → เสียเลือดเรื่อยๆ", "fix": "แผ่นตะกั่ว · ระบบกรองอากาศ · ห้องพยาบาล · ยาต้านรังสี · Trait ทนรังสี"},
	"acid": {"th": "ฝนกรด", "en": "ACID", "icon": "acid", "col": "68a818",
		"tip": "ตัวถังถูกกัดกร่อนต่อเนื่อง", "fix": "แผ่นเกราะข้างรถ · ชิ้นส่วนเกราะ (Plating)"},
	"ash": {"th": "เถ้าถ่าน", "en": "ASHFALL", "icon": "ash", "col": "686878",
		"tip": "แผงโซลาร์สกปรกเร็ว · ความสุขลดลง", "fix": "ฝาครอบโซลาร์ · ระบบกรองอากาศ"},
}
## permanent biome hazards (level)
const BIOME := {"industrial": {}, "desert": {"heat": 1}, "forest": {}, "swamp": {"rad": 2}, "tundra": {"cold": 2}, "metro": {"rad": 1}}
## biomes with random radiation hot spots
const HOTSPOT_BIOMES := ["industrial", "desert", "forest", "metro"]
const FUEL_BASE_CAP := 60.0
const GEN_FUEL_TO_POWER := 4.0

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


func _st() -> Dictionary:
	if not Game.s.has("env"):
		Game.s["env"] = {"spot_t": 0.0, "spot_cd": 90.0, "freeze": 0.0}
	return Game.s.env


## {hazard_id: level 1..2}
func active() -> Dictionary:
	var out := {}
	if Game.s.is_empty():
		return out
	var b: String = Data.biome(int(Game.s.biome)).id
	for k in BIOME.get(b, {}):
		out[k] = BIOME[b][k]
	var w: String = Game.s.get("weather", "clear")
	match w:
		"snow":
			out["cold"] = maxi(int(out.get("cold", 0)), 1)
		"sandstorm":
			out["sand"] = 1
		"acid_rain":
			out["acid"] = 1
		"ashfall":
			out["ash"] = 1
	if b == "desert":
		if Game.is_night():
			out.erase("heat")
			out["cold"] = maxi(int(out.get("cold", 0)), 1)
	if b == "tundra" and Game.is_night():
		out["cold"] = 3
	if float(_st().get("spot_t", 0.0)) > 0.0:
		out["rad"] = maxi(int(out.get("rad", 0)), 1)
	return out


func level(h: String) -> int:
	return int(active().get(h, 0))


func in_hotspot() -> bool:
	return float(_st().get("spot_t", 0.0)) > 0.0


# ------------------------------------------------------------------ derived multipliers
func fuel_cap() -> float:
	return FUEL_BASE_CAP + 30.0 * int(Game.s.vault_level) + Mods.val("fuel_tanks")


func heating_fuel_pm() -> float:
	var c := level("cold")
	if c <= 0:
		return 0.0
	var present := 0
	for d in Game.s.dwellers:
		if not Game.is_away(d):
			present += 1
	return float(c) * (1.2 + 0.18 * present) * (1.0 - Mods.val("insulation"))


func freezing() -> bool:
	return level("cold") > 0 and float(Game.s.res.get("fuel", 0.0)) <= 0.05


## how hard the cold bites (0..1) after the boiler mod
func freeze_power() -> float:
	if not freezing():
		return 0.0
	return clampf(0.35 * level("cold") * (1.0 - Mods.val("heater")), 0.0, 1.0)


func prod_mult() -> float:
	return 1.0 - 0.5 * freeze_power()


func water_mult() -> float:
	var m := 1.0 + 0.5 * level("heat")
	return m * (1.0 - Mods.val("water_recycler"))


func solar_mult() -> float:
	if level("sand") > 0 or level("ash") > 0:
		return 1.6 if Mods.level("solar_covers") > 0 else 1.0
	return 1.0


func dirt_pm() -> float:
	if Mods.level("solar_covers") > 0:
		return 0.0
	return 0.05 * level("sand") + 0.03 * level("ash")


func speed_mult() -> float:
	var m := 1.0
	var w: Dictionary = Game.weather_def()
	if Mods.level("tracks") > 0:
		# tracks ignore snow / sand / mud slow-downs
		m *= maxf(1.0, 0.95 / maxf(float(w.speed), 0.05))
		if Data.biome(int(Game.s.biome)).id == "tundra":
			m *= 1.2
	if freeze_power() > 0.0:
		m *= 0.8
	return m


func rad_pm(d: Dictionary) -> float:
	var r := level("rad")
	if r <= 0:
		return 0.0
	var v := 1.5 * r * (1.0 - Mods.val("rad_shield")) * (1.0 - Mods.val("air_filter"))
	if Crew.has(d, "rad_proof"):
		v *= 0.4
	v *= 1.0 - minf(0.75, Skills.val(d, "radres"))
	return maxf(0.0, v)


func happy_mod(d: Dictionary) -> float:
	var h := 0.0
	var fp := freeze_power()
	if fp > 0.0 and not Crew.has(d, "cold_blooded"):
		h -= 30.0 * fp
	if level("heat") > 0:
		h -= 4.0
	if level("ash") > 0 or level("rad") > 0:
		h -= 4.0 * (1.0 - Mods.val("air_filter"))
	h += 5.0 * Mods.level("air_filter")
	return h


func acid_hull_pm() -> float:
	var w: Dictionary = Game.weather_def()
	if not w.has("hull_pm"):
		return 0.0
	var resist := clampf(float(Combat.van_stats().def) / 40.0 + 0.25 * Mods.level("armor_plates"), 0.0, 0.9)
	return float(w.hull_pm) * (1.0 - resist)


# ------------------------------------------------------------------ simulation step (called by Game)
func tick(dt: float, offline: bool) -> void:
	var m := dt / 60.0
	var st := _st()
	var b: String = Data.biome(int(Game.s.biome)).id
	# radiation hot spots drift past while driving
	if float(st.spot_t) > 0.0:
		st.spot_t = maxf(0.0, float(st.spot_t) - dt)
		if st.spot_t <= 0.0 and not offline:
			Game.toast.emit("พ้นจุดรังสีรั่วไหลแล้ว", "good")
	elif HOTSPOT_BIOMES.has(b) and Game.is_moving():
		st.spot_cd = float(st.spot_cd) - dt
		if st.spot_cd <= 0.0:
			st.spot_cd = rng.randf_range(150.0, 320.0)
			st.spot_t = rng.randf_range(40.0, 90.0)
			if not offline:
				Game.toast.emit("เข้าสู่จุดรังสีรั่วไหล! ผู้รอดชีวิตกำลังสะสมรังสี", "warn")
	# heating
	var fuel_use := heating_fuel_pm() * m
	if fuel_use > 0.0:
		Game._add_res("fuel", -fuel_use)
	# backup generator burns fuel when the battery runs dry (sandstorm nights!)
	var cap_p := Game.cap("power")
	if float(Game.s.res.power) < cap_p * 0.1 and float(Game.s.res.get("fuel", 0.0)) > 1.0 and Game.s.get("generator", true):
		var burn := minf(2.5 * m, float(Game.s.res.fuel))
		Game._add_res("fuel", -burn)
		Game._add_res("power", burn * GEN_FUEL_TO_POWER)
	# panel dirt
	Game.s.solar.dirt = clampf(float(Game.s.solar.dirt) + dirt_pm() * m, 0.0, 1.0)
	# acid
	var ah := acid_hull_pm()
	if ah > 0.0:
		Game.s.hull = maxf(0.0, float(Game.s.hull) - ah * m)
	# survivors
	var fp := freeze_power()
	for d in Game.s.dwellers:
		if Game.is_away(d):
			continue
		var r := rad_pm(d)
		if r > 0.0:
			d.rads = minf(100.0, float(d.rads) + r * m)
		if fp > 0.0 and not Crew.has(d, "cold_blooded"):
			d.hp = maxf(1.0, float(d.hp) - 1.5 * fp * m)
	if fp > 0.0 and not offline:
		st.freeze = float(st.get("freeze", 0.0)) + dt
		if float(st.freeze) > 45.0:
			st.freeze = 0.0
			Game.toast.emit("เชื้อเพลิงหมด! ทุกคนหนาวสั่น — ผลิตเชื้อเพลิงที่โรงกลั่นหรือหาจากการสำรวจ", "bad")


## lines for the hazard panel: [{id, th, lvl, tip, fix, col, icon}]
func report() -> Array:
	var out := []
	var a := active()
	for k in a:
		var h: Dictionary = HAZARDS[k]
		out.append({"id": k, "th": h.th, "en": h.en, "lvl": a[k], "tip": h.tip, "fix": h.fix, "col": h.col, "icon": h.icon})
	return out
