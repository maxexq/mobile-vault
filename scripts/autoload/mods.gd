extends Node
## Vehicle customisation: external mods (drawn on the truck) and internal mods.
## Some need a blueprint found on expeditions; blueprints survive into the next generation (Meta).

signal mods_changed

const MODS := {
	# ---------------- external (visible on the truck)
	"spike_ram": {"side": "ext", "th": "กันชนหนาม", "en": "SPIKED RAM", "icon": "spikes", "max": 3, "bp": "",
		"cost": [{"scrap": 120, "components": 5}, {"scrap": 300, "components": 15}, {"scrap": 650, "components": 35}],
		"desc": "ลดความเสียหายเวลาชน/พุ่งฝ่า 25%/ระดับ · ศัตรูประชิดโดนหนาม", "per": 0.25},
	"roof_turret": {"side": "ext", "th": "ป้อมปืนอัตโนมัติบนหลังคา", "en": "ROOF AUTO-TURRET", "icon": "turret", "max": 3, "bp": "bp_roof_turret",
		"cost": [{"scrap": 300, "components": 20}, {"scrap": 700, "components": 40}, {"scrap": 1400, "components": 80}],
		"desc": "ป้อมปืนที่ 2 ยิงร่วมกับป้อมหลัก (40/70/100% ของดาเมจป้อม)", "per": 0.3},
	"fuel_tanks": {"side": "ext", "th": "ถังน้ำมันสำรอง", "en": "SPARE FUEL TANKS", "icon": "fuel", "max": 3, "bp": "",
		"cost": [{"scrap": 100}, {"scrap": 260, "components": 8}, {"scrap": 520, "components": 20}],
		"desc": "ความจุเชื้อเพลิง +60/ระดับ", "per": 60.0},
	"tracks": {"side": "ext", "th": "ตีนตะขาบลุยหิมะ", "en": "SNOW TRACKS", "icon": "hull", "max": 1, "bp": "bp_tracks",
		"cost": [{"scrap": 900, "components": 40}],
		"desc": "หิมะ/ทราย/โคลนไม่ทำให้รถช้าลง · ทุ่งน้ำแข็งเร็วขึ้น 20%", "per": 1.0},
	"armor_plates": {"side": "ext", "th": "แผ่นเกราะข้างรถ", "en": "ARMOR PLATES", "icon": "plates", "max": 3, "bp": "",
		"cost": [{"scrap": 200, "components": 10}, {"scrap": 450, "components": 25}, {"scrap": 900, "components": 50}],
		"desc": "ตัวถังสูงสุด +40/ระดับ · ฝนกรดกัดน้อยลง 25%/ระดับ", "per": 40.0},
	"solar_covers": {"side": "ext", "th": "ฝาครอบแผงโซลาร์", "en": "SOLAR SHUTTERS", "icon": "sun", "max": 1, "bp": "bp_solar_covers",
		"cost": [{"scrap": 350, "components": 15}],
		"desc": "พายุทราย/เถ้าไม่ทำให้แผงสกปรก · ไฟจากโซลาร์ในพายุ +60%", "per": 1.0},
	"rad_shield": {"side": "ext", "th": "แผ่นตะกั่วกันรังสี", "en": "LEAD SHIELDING", "icon": "rad", "max": 2, "bp": "bp_rad_shield",
		"cost": [{"scrap": 500, "components": 25}, {"scrap": 1100, "components": 60}],
		"desc": "รังสีเข้ารถลดลง 35%/ระดับ", "per": 0.35},
	"rain_catcher": {"side": "ext", "th": "ผ้าใบดักน้ำฝน", "en": "RAIN CATCHER", "icon": "water", "max": 2, "bp": "",
		"cost": [{"scrap": 90}, {"scrap": 240, "components": 6}],
		"desc": "เก็บน้ำฝน +75%/ระดับ", "per": 0.75},
	# ---------------- internal
	"insulation": {"side": "int", "th": "ฉนวนกันหนาว", "en": "INSULATION", "icon": "snow", "max": 3, "bp": "",
		"cost": [{"scrap": 150, "components": 5}, {"scrap": 380, "components": 18}, {"scrap": 800, "components": 40}],
		"desc": "ใช้เชื้อเพลิงทำความร้อน -25%/ระดับ", "per": 0.25},
	"heater": {"side": "int", "th": "หม้อต้มทำความร้อน", "en": "BOILER HEATER", "icon": "fuel", "max": 2, "bp": "bp_heater",
		"cost": [{"scrap": 400, "components": 20}, {"scrap": 900, "components": 45}],
		"desc": "ความหนาวกระทบผู้รอดชีวิตน้อยลง 40%/ระดับ แม้เชื้อเพลิงหมด", "per": 0.4},
	"air_filter": {"side": "int", "th": "ระบบกรองอากาศ", "en": "AIR FILTERS", "icon": "fog", "max": 2, "bp": "bp_air_filter",
		"cost": [{"scrap": 300, "components": 15}, {"scrap": 700, "components": 35}],
		"desc": "รังสี/สปอร์/เถ้า ลดลง 25%/ระดับ · ความสุข +5", "per": 0.25},
	"storage_racks": {"side": "int", "th": "ชั้นเก็บของ", "en": "STORAGE RACKS", "icon": "chest", "max": 3, "bp": "",
		"cost": [{"scrap": 160}, {"scrap": 400, "components": 10}, {"scrap": 850, "components": 30}],
		"desc": "ความจุอาหาร/น้ำ/ไฟ +25%/ระดับ", "per": 0.25},
	"repair_bay": {"side": "int", "th": "อู่ซ่อมในรถ", "en": "REPAIR BAY", "icon": "wrench", "max": 2, "bp": "bp_repair_bay",
		"cost": [{"scrap": 450, "components": 25}, {"scrap": 1000, "components": 55}],
		"desc": "ตัวถังฟื้นฟู +3/นาที/ระดับ (ไม่ต้องมีคนในห้องเครื่อง)", "per": 3.0},
	"water_recycler": {"side": "int", "th": "เครื่องรีไซเคิลน้ำ", "en": "WATER RECYCLER", "icon": "water", "max": 2, "bp": "",
		"cost": [{"scrap": 200, "components": 8}, {"scrap": 500, "components": 25}],
		"desc": "ใช้น้ำ -20%/ระดับ (ช่วยมากในทะเลทราย)", "per": 0.2},
}
const BLUEPRINT_TH := {
	"bp_roof_turret": "แบบป้อมปืนหลังคา", "bp_tracks": "แบบตีนตะขาบ", "bp_solar_covers": "แบบฝาครอบโซลาร์",
	"bp_rad_shield": "แบบแผ่นตะกั่ว", "bp_heater": "แบบหม้อต้มทำความร้อน", "bp_air_filter": "แบบระบบกรองอากาศ",
	"bp_repair_bay": "แบบอู่ซ่อม", "bp_refinery": "แบบโรงกลั่นเชื้อเพลิง", "bp_workshop": "แบบโรงช่าง",
	"bp_chassis2": "แบบแชสซี MK-II (5 ชั้น)", "bp_chassis3": "แบบแชสซี MK-III (6 ชั้น)",
}


func level(id: String) -> int:
	if Game.s.is_empty():
		return 0
	return int(Game.s.get("mods", {}).get(id, 0))


func val(id: String) -> float:
	return float(MODS[id].per) * level(id)


func has_bp(bp: String) -> bool:
	return bp == "" or Meta.has_blueprint(bp)


func next_cost(id: String) -> Dictionary:
	var lv := level(id)
	var arr: Array = MODS[id].cost
	return arr[lv] if lv < arr.size() else {}


func can_install(id: String) -> bool:
	var d: Dictionary = MODS[id]
	return level(id) < int(d.max) and has_bp(d.bp) and Game.can_afford(next_cost(id))


func install(id: String) -> bool:
	var d: Dictionary = MODS[id]
	if level(id) >= int(d.max):
		return false
	if not has_bp(d.bp):
		Game.toast.emit("ต้องมี %s (หาได้จากการสำรวจสถานที่สำคัญ)" % BLUEPRINT_TH.get(d.bp, d.bp), "warn")
		return false
	if not Game.pay(next_cost(id)):
		return false
	if not Game.s.has("mods"):
		Game.s["mods"] = {}
	Game.s.mods[id] = level(id) + 1
	Game.toast.emit("ติดตั้ง %s Lv.%d แล้ว!" % [d.th, level(id)], "good")
	if id == "armor_plates":
		Game.s.hull = minf(Game.hull_max(), float(Game.s.hull) + float(d.per))
	mods_changed.emit()
	Game.resources_changed.emit()
	Game.travel_changed.emit()
	return true
