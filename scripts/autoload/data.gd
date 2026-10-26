extends Node
## Static game design data: rooms, items, biomes, weather, random events.
## Everything that a designer would tune lives here (no logic).

const ROOMS_PER_FLOOR := 3
## v4 slot layout: slot = floor * 3 + column (bottom floor first) on the main body, then 6 slots per trailer.
## Slot 0 (bottom floor, right behind the cab) is always open. Before v4.6 it held the engine room; since then
## the engine room lives in the cab (CAB_SLOT, outside the room grid: Game.room(CAB_SLOT) is Game.s.cab).
const ENGINE_SLOT := 0
const CAB_SLOT := 99
const CAB_WORKERS := 2
const SLOT_COUNT := 12            # rig body, kept for tools / tests
const MAX_TRAILERS := 2
const TRAILER_FLOORS := 2
const TRAILER_SLOTS := 6
const MAX_SLOTS := 24             # 4-floor body + 2 trailers
## v3 -> v4 save migration: old slot index -> (column, floor)
const V3_SLOT_CELL := [[0, 2], [1, 2], [0, 3], [1, 3], [0, 1], [1, 1], [1, 0], [0, 0], [2, 0], [2, 1], [2, 2], [2, 3],
	[0, 4], [1, 4], [2, 4], [0, 5], [1, 5], [2, 5]]
## Prestige vehicle ladder. Geometry must match tools/art/vehicles.py.
##  weight / engine: tons vs. engine capacity (Haul autoload); hull: bonus hull points.
##  cab: the engine room inside the cab's bottom floor [x, y, w, h] (tools/art/engine_bay.py CAB).
const TIER_ORDER := ["van", "bus", "rig", "train"]
const VEHICLES := {
	"van": {"th": "รถตู้แคมป์ปิ้ง", "en": "CAMPER VAN", "floors": 2, "weight": 18.0, "engine": 40.0, "hull": 0.0,
		"wheels": [[26, 284], [214, 284]], "rail": false, "headlight": [0, 213], "chimney": [250, 272], "trailer": "trailer",
		"names": ["SCRAPPY", "LITTLE ROAMER"], "cab": [2, 204, 31, 58]},
	"bus": {"th": "รถบัสหุ้มเหล็ก", "en": "ARMORED BUS", "floors": 3, "weight": 28.0, "engine": 62.0, "hull": 40.0,
		"wheels": [[34, 284], [214, 284]], "rail": false, "headlight": [0, 224], "chimney": [250, 272], "trailer": "trailer",
		"names": ["BIG YELLOW", "ROUTE 66"], "cab": [2, 216, 32, 46]},
	"rig": {"th": "รถพ่วง 18 ล้อ", "en": "18-WHEELER RIG", "floors": 4, "weight": 40.0, "engine": 90.0, "hull": 80.0,
		"wheels": [[22, 284], [182, 284], [222, 284]], "rail": false, "headlight": [0, 230], "chimney": [33, 144], "trailer": "trailer",
		"names": ["MAMMOTH-7", "MAMMOTH-8", "BEHEMOTH-1"], "cab": [2, 222, 33, 41]},
	"train": {"th": "รถไฟหุ้มเกราะ", "en": "ARMORED TRAIN", "floors": 4, "weight": 60.0, "engine": 140.0, "hull": 160.0,
		"wheels": [], "rail": true, "headlight": [6, 164], "chimney": [29, 14], "trailer": "wagon",
		"names": ["LEVIATHAN", "LEVIATHAN-II", "ARK"], "cab": [3, 196, 35, 66]},
}
const TRAILER_COST := [{"scrap": 2500, "components": 120}, {"scrap": 4500, "components": 220}]
const SLOTS_PER_LEVEL := [0, 3, 5, 6, 8, 10, 11]
const MAX_VAULT_LEVEL := 6
const VAULT_UPGRADE_COST := [0, 500, 1300, 2600, 4200, 6500, 0]   # cost to go from level i -> i+1
const SCRAP_CAP := [0, 800, 1500, 2800, 4500, 7000, 9000]   # cost to go from level i -> i+1
const ROOM_MAX_LEVEL := 3
const ROOM_WORKERS := 2
const DAY_LENGTH_SEC := 360.0       # one in-game day (sunrise -> sunrise)
const BASE_TRAVEL_KMPM := 0.10      # km per real minute at speed factor 1.0 (~ 35 km/h on the gauge)
const TRAVEL_POWER_PM := 2.4        # battery used per minute while driving
const DWELLER_FOOD_PM := 0.30
const DWELLER_WATER_PM := 0.30
const BASE_POP_CAP := 6
const OFFLINE_CAP_SEC := 4 * 3600

const STAT_NAMES := {"str": "STR", "int": "INT", "agi": "AGI"}

# ------------------------------------------------------------------ ROOMS
## produce: units per minute at level 1 with an average worker (stat 5)
const ROOMS := {
	"quarters": {
		"th": "ห้องพัก", "en": "LIVING QUARTERS", "cost": 100, "unlock": 1, "stat": "agi",
		"produce": {}, "power": 0.3,
		"effect_th": "+4 เตียงต่อเลเวล · ความสุข +", "effect_en": "+BEDS / +HAPPINESS",
		"recipes": [],
	},
	"kitchen": {
		"th": "ห้องครัว & เสบียง", "en": "KITCHEN & PANTRY", "cost": 120, "unlock": 1, "stat": "agi",
		"produce": {"food": 5.0}, "power": 0.5, "cook": true,
		"effect_th": "ผลิตอาหาร · เพิ่มความอิ่ม", "effect_en": "+FOOD",
		"raw_effect_th": "ปรุงพืชผล/เนื้อ + น้ำ เป็นอาหาร", "raw_effect_en": "COOKS CROPS / MEAT + WATER INTO FOOD",
		"recipes": [
			{"id": "cook_meal", "th": "ปรุงอาหาร", "en": "COOK MEAL", "cost": {"scrap": 12}, "raw_th": "ต้มผักหม้อใหญ่", "raw_en": "VEGETABLE STEW", "raw_cost": {"crops": 14, "water": 6}, "time": 60.0, "out": {"food": 30}},
			{"id": "grill_meat", "th": "ย่างเนื้อ", "en": "GRILL MEAT", "raw": true, "cost": {"meat": 10, "water": 4}, "time": 60.0, "out": {"food": 30}},
			{"id": "preserve", "th": "ถนอมอาหาร", "en": "PRESERVE FOOD", "cost": {"scrap": 18, "food": 10}, "raw_th": "รมควันเนื้อ", "raw_en": "SMOKE MEAT", "raw_cost": {"meat": 12, "fuel": 4}, "time": 90.0, "out": {"dried_meat": 2}},
		],
	},
	"hydroponics": {
		"th": "ห้องปลูกพืช", "en": "HYDROPONICS", "cost": 180, "unlock": 1, "stat": "agi",
		"produce": {"food": 4.0}, "raw_produce": {"crops": 4.0}, "power": 0.6, "weather_crop": true,
		"effect_th": "ปลูกผัก (ฝนตก = โตเร็วขึ้น)", "effect_en": "FOOD (RAIN BOOSTS GROWTH)",
		"raw_effect_th": "ปลูกพืชผลด้วยน้ำ (ฝนตก = โตเร็วขึ้น)", "raw_effect_en": "GROWS CROPS FROM WATER (RAIN BOOSTS)",
		"recipes": [
			{"id": "seed_batch", "th": "เพาะต้นกล้า", "en": "PLANT SEEDS", "cost": {"scrap": 8, "water": 10}, "raw_cost": {"water": 12, "power": 6}, "time": 120.0, "out": {"food": 45}, "raw_out": {"crops": 40}},
		],
	},
	"water": {
		"th": "เครื่องกรองน้ำ", "en": "WATER PURIFIER", "cost": 120, "unlock": 1, "stat": "int",
		"produce": {"water": 5.0}, "power": 0.6,
		"effect_th": "ผลิตน้ำดื่มสะอาด", "effect_en": "+CLEAN WATER",
		"recipes": [
			{"id": "purify", "th": "กรองน้ำด่วน", "en": "FLASH PURIFY", "cost": {"scrap": 10, "power": 8}, "time": 60.0, "out": {"water": 30}},
		],
	},
	"medical": {
		"th": "ห้องแล็บ & พยาบาล", "en": "MEDICAL LAB", "cost": 150, "unlock": 1, "stat": "int",
		"produce": {}, "power": 0.5, "heal": 2.0,
		"effect_th": "ฟื้นฟูเลือดทุกคน · กันรังสี", "effect_en": "+HEALTH / +RAD RESISTANCE",
		"recipes": [
			{"id": "stimpack", "th": "ผลิตสติมแพ็ก", "en": "CRAFT STIMPACK", "cost": {"scrap": 15}, "raw_cost": {"components": 2, "water": 5}, "time": 90.0, "out": {"stimpack": 1}},
			{"id": "radaway", "th": "ผลิตยาต้านรังสี", "en": "CRAFT RADAWAY", "cost": {"scrap": 20}, "raw_cost": {"components": 2, "crops": 8, "water": 8}, "time": 120.0, "out": {"radaway": 1}},
			{"id": "antibiotics", "th": "ผลิตยาปฏิชีวนะ", "en": "CRAFT ANTIBIOTICS", "cost": {"scrap": 18, "water": 10}, "raw_th": "เพาะเชื้อยาปฏิชีวนะ", "raw_cost": {"crops": 10, "water": 10, "power": 6}, "time": 110.0, "out": {"antibiotics": 1}},
		],
	},
	"armory": {
		"th": "ห้องอาวุธ & ยุทโธปกรณ์", "en": "ARMORY", "cost": 200, "unlock": 2, "stat": "str",
		"produce": {}, "power": 0.5, "combat": 2,
		"effect_th": "+พลังต่อสู้ทีม / +ป้องกันรถ", "effect_en": "+COMBAT DAMAGE / +DEFENSE",
		"recipes": [
			{"id": "weapon", "th": "ประดิษฐ์อาวุธ", "en": "CRAFT WEAPON", "cost": {"scrap": 25}, "time": 150.0, "out": {"_weapon": 1}},
			{"id": "armor", "th": "ประกอบเกราะ", "en": "CRAFT ARMOR", "cost": {"scrap": 30}, "time": 180.0, "out": {"_armor": 1}},
			{"id": "ammo", "th": "ผลิตกระสุน", "en": "MANUFACTURE AMMO", "cost": {"scrap": 10}, "time": 60.0, "out": {"ammo": 5}},
			{"id": "vanpart", "th": "ผลิตชิ้นส่วนรถ", "en": "BUILD VAULT PART", "cost": {"scrap": 40, "components": 10}, "time": 200.0, "out": {"_vanpart": 1}},
		],
	},
	"science": {
		"th": "ห้องวิจัยวิทยาศาสตร์", "en": "SCIENCE LAB", "cost": 250, "unlock": 2, "stat": "int",
		"produce": {}, "power": 0.8, "boost": 0.06,
		"effect_th": "ทุกห้องผลิต +6% ต่อเลเวล", "effect_en": "+PRODUCTION (ALL ROOMS)",
		"recipes": [
			{"id": "refine", "th": "รีไซเคิลเศษเหล็ก", "en": "REFINE SCRAP", "raw": false, "cost": {"power": 20}, "time": 90.0, "out": {"scrap": 18}},
			{"id": "lab_meat", "th": "เพาะเนื้อสังเคราะห์", "en": "GROW LAB MEAT", "raw": true, "cost": {"crops": 12, "water": 8, "power": 12}, "time": 90.0, "out": {"meat": 10}},
			{"id": "radaway_sci", "th": "สังเคราะห์ยาต้านรังสี", "en": "SYNTH RADAWAY", "cost": {"scrap": 14, "water": 10}, "raw_cost": {"components": 2, "water": 10}, "time": 100.0, "out": {"radaway": 1}},
		],
	},
	"radio": {
		"th": "ห้องวิทยุสื่อสาร", "en": "RADIO ROOM", "cost": 200, "unlock": 3, "stat": "int",
		"produce": {}, "power": 0.7, "recruit": true,
		"effect_th": "ดึงดูดผู้รอดชีวิต · เตือนภัยล่วงหน้า", "effect_en": "RECRUIT SURVIVORS / EARLY WARNING",
		"recipes": [
			{"id": "broadcast", "th": "กระจายเสียงขอความช่วยเหลือ", "en": "BROADCAST SOS", "cost": {"power": 15}, "time": 120.0, "out": {"_recruit": 1}},
		],
	},
	"refinery": {
		"th": "โรงกลั่นเชื้อเพลิง", "en": "FUEL REFINERY", "cost": 160, "unlock": 2, "stat": "str",
		"produce": {"fuel": 3.0}, "power": 0.6,
		"effect_th": "ผลิตเชื้อเพลิง (ทำความร้อน/เครื่องปั่นไฟสำรอง)", "effect_en": "+FUEL FOR HEAT & GENERATOR",
		"recipes": [
			{"id": "biofuel", "th": "หมักไบโอดีเซล", "en": "BREW BIOFUEL", "cost": {"food": 20, "scrap": 10}, "raw_cost": {"crops": 20, "water": 8}, "time": 90.0, "out": {"fuel": 30}},
			{"id": "crack_oil", "th": "กลั่นน้ำมันจากซาก", "en": "CRACK SCRAP OIL", "cost": {"scrap": 30, "power": 15}, "time": 120.0, "out": {"fuel": 40}},
		],
	},
	"workshop": {
		"th": "โรงช่างประจำรถ", "en": "WORKSHOP", "cost": 220, "unlock": 2, "stat": "int", "bp": "bp_workshop",
		"produce": {}, "power": 0.6,
		"effect_th": "ผลิตชิ้นส่วน · ช่วยซ่อมตัวถัง", "effect_en": "+COMPONENTS / +HULL REPAIR",
		"recipes": [
			{"id": "salvage_parts", "th": "แยกชิ้นส่วนจากเศษเหล็ก", "en": "SALVAGE PARTS", "cost": {"scrap": 40}, "time": 100.0, "out": {"components": 6}},
			{"id": "patch_kit", "th": "ทำแผ่นปะตัวถัง", "en": "HULL PATCH KIT", "cost": {"scrap": 25}, "time": 60.0, "out": {"_hull": 35}},
		],
	},
	## v4.4: the 2nd / 3rd cell of a large room (the room's data lives on its left-most cell, see Game.room_anchor)
	"annex": {
		"th": "ส่วนขยายห้อง", "en": "ANNEX", "cost": 0, "unlock": 99, "stat": "",
		"produce": {}, "power": 0.0,
		"effect_th": "ส่วนหนึ่งของห้องขนาดใหญ่", "effect_en": "PART OF A LARGE ROOM",
		"recipes": [],
	},
	"engine": {
		"th": "ห้องเครื่องยนต์", "en": "ENGINE / GENERATOR", "cost": 0, "unlock": 99, "stat": "str",
		"produce": {}, "power": 0.0,
		"effect_th": "ห้องเครื่องหน้ารถ · ลูกเรือระบายความร้อนและซ่อมเครื่อง", "effect_en": "ENGINE BAY / KEEPS THE ENGINE ALIVE",
		"recipes": [],
	},
}
const BUILDABLE := ["quarters", "kitchen", "water", "hydroponics", "medical", "refinery", "workshop", "armory", "science", "radio"]
const ROOM_UPGRADE_COST := [0, 0, 150, 300]   # cost to reach level index
## v4.3 construction: building / upgrading a room takes time. Progress is in "work seconds"; the site advances
## at BUILD_IDLE_SPEED with nobody on it, and every crew member assigned to the room adds Crew.build_speed(d).
const BUILD_BASE_SEC := 40.0
const BUILD_SEC_PER_SCRAP := 0.35
const UPGRADE_SEC := [0, 0, 150.0, 300.0]     # work seconds to reach level index
const BUILD_IDLE_SPEED := 0.5
const RUSH_SEC_PER_COMPONENT := 15.0          # 1 component skips this many work seconds
## v4.4 large rooms: two or three rooms of the same type and level side by side on one floor (same unit) can be
## knocked through into one big room (Fallout-Shelter style). The left-most cell keeps the room, the others turn
## into "annex" cells. A span-n room takes n x ROOM_WORKERS crew and works like n rooms x SPAN_EFFICIENCY[n]
## (shared machines, no walls in the way); it only gets the bonus once the knock-through is finished.
const MERGEABLE := ["quarters", "kitchen", "water", "hydroponics", "medical", "refinery", "workshop", "armory", "science", "radio"]
const MAX_SPAN := 3
const SPAN_EFFICIENCY := [1.0, 1.0, 1.10, 1.25]
const MERGE_SCRAP_MULT := 0.6        # x room cost x level x (span - 1)
const MERGE_COMPONENTS := 6          # x (span - 1)
const MERGE_BASE_SEC := 45.0
const MERGE_SEC_PER_LEVEL := 35.0    # x level x (span - 1)
const SPAN_UPGRADE_DISCOUNT := 0.8   # a large room upgrades for span x 80% of the single-room price
const SPAN_UPGRADE_TIME := 0.5       # +50% upgrade work per extra cell
const SPAN_POWER_MULT := 0.9         # power use per cell of a large room

# ------------------------------------------------------------------ ITEMS
const ITEMS := {
	"stimpack": {"th": "สติมแพ็ก", "en": "Stimpack", "icon": "stimpack", "kind": "use", "desc": "ฟื้นเลือด 50%"},
	"radaway": {"th": "ยาต้านรังสี", "en": "RadAway", "icon": "radaway", "kind": "use", "desc": "ล้างรังสี"},
	"ammo": {"th": "กระสุน", "en": "Ammo", "icon": "ammo", "kind": "mat", "desc": "+พลังต่อสู้เมื่อมีติดตัว"},
	"dried_meat": {"th": "เนื้อแห้ง", "en": "Dried Meat", "icon": "meat", "kind": "use", "desc": "+40 อาหาร เมื่อใช้"},
	"antibiotics": {"th": "ยาปฏิชีวนะ", "en": "Antibiotics", "icon": "pill", "kind": "use", "desc": "รักษาการติดเชื้อ"},
	"components": {"th": "ชิ้นส่วน", "en": "Components", "icon": "cog", "kind": "mat", "desc": "ได้จากการแยกอุปกรณ์ ใช้ตีบวก"},
	"pipe_pistol": {"th": "ปืนท่อเหล็ก", "en": "Pipe Pistol", "icon": "pistol", "kind": "weapon", "dmg": 3},
	"hunting_rifle": {"th": "ไรเฟิลล่าสัตว์", "en": "Hunting Rifle", "icon": "rifle", "kind": "weapon", "dmg": 6},
	"assault_rifle": {"th": "ปืนจู่โจม", "en": "Assault Rifle", "icon": "rifle", "kind": "weapon", "dmg": 9},
	"leather_armor": {"th": "เกราะหนัง", "en": "Leather Armor", "icon": "armor", "kind": "armor", "def": 2},
	"combat_armor": {"th": "เกราะรบ", "en": "Combat Armor", "icon": "armor", "kind": "armor", "def": 4},
}
const WEAPON_POOL := ["pipe_pistol", "pipe_pistol", "hunting_rifle", "hunting_rifle", "assault_rifle"]
const ARMOR_POOL := ["leather_armor", "leather_armor", "combat_armor"]

# ------------------------------------------------------------------ WEATHER
const WEATHER := {
	"clear":     {"th": "ท้องฟ้าแจ่มใส", "en": "CLEAR", "icon": "sun", "solar": 1.00, "crop": 1.00, "water": 0.0, "speed": 1.00, "dirt": 0.0, "tint": Color(1, 1, 1)},
	"overcast":  {"th": "ฟ้าครึ้ม", "en": "OVERCAST", "icon": "fog", "solar": 0.60, "crop": 1.05, "water": 0.0, "speed": 1.00, "dirt": 0.0, "tint": Color(0.85, 0.86, 0.9)},
	"rain":      {"th": "ฝนตก", "en": "RAIN", "icon": "rain", "solar": 0.35, "crop": 1.50, "water": 3.0, "speed": 0.90, "dirt": -0.02, "tint": Color(0.70, 0.76, 0.86)},
	"storm":     {"th": "พายุฝนฟ้าคะนอง", "en": "THUNDERSTORM", "icon": "storm", "solar": 0.15, "crop": 1.30, "water": 5.0, "speed": 0.75, "dirt": -0.03, "tint": Color(0.55, 0.60, 0.72)},
	"sandstorm": {"th": "พายุทราย", "en": "SANDSTORM", "icon": "sand", "solar": 0.30, "crop": 0.60, "water": -0.5, "speed": 0.60, "dirt": 0.05, "tint": Color(1.0, 0.82, 0.6)},
	"snow":      {"th": "หิมะตก", "en": "SNOWFALL", "icon": "snow", "solar": 0.45, "crop": 0.50, "water": 1.0, "speed": 0.70, "dirt": 0.0, "tint": Color(0.86, 0.9, 1.0)},
	"fog":       {"th": "หมอกหนา", "en": "FOG", "icon": "fog", "solar": 0.50, "crop": 1.10, "water": 0.5, "speed": 0.85, "dirt": 0.0, "tint": Color(0.8, 0.85, 0.85)},
	"acid_rain": {"th": "ฝนกรด", "en": "ACID RAIN", "icon": "acid", "solar": 0.30, "crop": 1.30, "water": 1.0, "speed": 0.85, "dirt": 0.02, "hull_pm": 1.2, "tint": Color(0.72, 0.86, 0.62)},
	"ashfall":   {"th": "เถ้าถ่านโปรยปราย", "en": "ASHFALL", "icon": "ash", "solar": 0.40, "crop": 0.80, "water": 0.0, "speed": 0.85, "dirt": 0.04, "tint": Color(0.78, 0.74, 0.76)},
}

# ------------------------------------------------------------------ BIOMES
const BIOMES := [
	{
		"id": "industrial", "th": "ซากนิคมอุตสาหกรรม", "en": "INDUSTRIAL RUINS", "length": 4.0, "req": 1,
		"scrap_pm": 3.0, "danger": 1,
		"weather": {"clear": 3, "overcast": 3, "rain": 3, "storm": 1, "fog": 1},
		"events": ["raiders", "cache", "survivor", "radstorm", "bugs", "trader", "gas_station", "stray_dog", "stray_cat", "signal"],
	},
	{
		"id": "desert", "th": "ทะเลทรายแก้ว", "en": "GLASS DESERT", "length": 6.0, "req": 2,
		"scrap_pm": 4.5, "danger": 2,
		"weather": {"clear": 5, "sandstorm": 3, "overcast": 1},
		"events": ["raiders", "cache", "sandstorm", "wolves", "trader", "survivor", "gas_station", "gambler", "plane_wreck"],
	},
	{
		"id": "forest", "th": "ป่ารกร้าง", "en": "OVERGROWN FOREST", "length": 8.0, "req": 3,
		"scrap_pm": 6.0, "danger": 3,
		"weather": {"rain": 4, "storm": 2, "fog": 2, "overcast": 2, "clear": 1},
		"events": ["wolves", "bridge", "bugs", "survivor", "raiders", "cache", "cultists", "stray_dog", "mutant_hen", "bunker"],
	},
	{
		"id": "swamp", "th": "หนองน้ำพิษ", "en": "TOXIC BAYOU", "length": 9.0, "req": 4,
		"scrap_pm": 7.0, "danger": 4,
		"weather": {"acid_rain": 4, "fog": 3, "rain": 2, "overcast": 1},
		"events": ["acid_flood", "bugs", "cultists", "plane_wreck", "survivor", "stray_dog", "stray_cat", "mutant_hen", "signal", "gambler"],
	},
	{
		"id": "tundra", "th": "ทางหลวงน้ำแข็ง", "en": "FROZEN HIGHWAY", "length": 10.0, "req": 5,
		"scrap_pm": 8.0, "danger": 5,
		"weather": {"snow": 5, "overcast": 2, "clear": 2, "fog": 1},
		"events": ["frozen", "wolves", "raiders", "bunker", "trader", "survivor", "plane_wreck", "signal"],
	},
	{
		"id": "metro", "th": "มหานครแห่งสัญญาณ", "en": "SIGNAL METROPOLIS", "length": 12.0, "req": 6,
		"scrap_pm": 10.0, "danger": 6,
		"weather": {"ashfall": 4, "clear": 2, "storm": 2, "overcast": 2},
		"events": ["rogue_bot", "cultists", "bunker", "raiders", "trader", "signal", "gambler", "survivor"],
	},
]

# ------------------------------------------------------------------ RANDOM EVENTS
## choice.action: fight | flee | pay | ram | loot | recruit | trade | shelter | push | repair | detour | ignore | gift
##                 | check (stat test: stat, dc, reward / fail) | gamble | adopt
## any choice may carry "lore": id -> unlocks a logbook entry
## optional "result": first line of the outcome text, "stamp": [EN, TH] on the outcome picture
## (defaults per action in EventPopup.STAMPS), for choices where the generic wording would not fit
const EVENTS := {
	"bunker": {
		"th": "บังเกอร์ทหารที่ถูกปิดตาย", "en": "SEALED MILITARY BUNKER", "image": "bunker", "danger": 2,
		"desc": "ประตูเหล็กหนาครึ่งเมตรโผล่ออกมาจากเนินดิน ตราประทับของกองพัน 'สุริยะ-9' ยังเห็นชัด แผงกุญแจอิเล็กทรอนิกส์ยังมีไฟกะพริบอยู่...",
		"choices": [
			{"action": "check", "stat": "int", "dc": 7, "th": "แฮ็กแผงประตู", "en": "HACK THE KEYPAD", "sub": "INT สูง = สำเร็จง่าย · ได้อุปกรณ์หายาก", "color": "green", "reward": {"_gear_rare": 1, "scrap": 40}, "fail": {"hp": 15}, "lore": "bunker_log"},
			{"action": "pay", "cost": {"power": 30}, "th": "อัดไฟเกินพิกัดใส่ประตู", "en": "OVERLOAD THE DOOR", "sub": "ใช้ไฟ 30 · ได้ของแน่นอน", "color": "yellow", "reward": {"_gear": 1, "ammo": 6},
				"result": "อัดไฟเข้าแผงจนกลอนไหม้ ประตูเหล็กค่อย ๆ แง้มออก", "stamp": ["OPENED", "ประตูเปิดแล้ว"]},
			{"action": "ignore", "th": "ไม่ยุ่งกับของทหาร", "en": "LEAVE IT", "sub": "", "color": "gray"},
		],
	},
	"signal": {
		"th": "สัญญาณวิทยุลึกลับ", "en": "THE SIGNAL", "image": "signal", "danger": 0,
		"desc": "วิทยุในห้องคนขับดังขึ้นเอง เสียงผู้หญิงซ้ำประโยคเดิม: ...นครแสงสุดท้าย... มีน้ำสะอาด... มีเมล็ดพันธุ์... มุ่งหน้าตะวันออก... ตามด้วยพิกัดชุดใหม่",
		"choices": [
			{"action": "shelter", "time": 20.0, "th": "จอดฟังและจดพิกัด", "en": "LISTEN & LOG IT", "sub": "หยุด 20 วิ · ปลดล็อกบันทึก", "color": "green", "lore": "signal", "reward": {"scrap": 20},
				"result": "จดพิกัดไว้ครบ เสียงผู้หญิงยังพูดประโยคเดิมวนอยู่อย่างนั้น", "stamp": ["LOGGED", "จดพิกัดแล้ว"]},
			{"action": "ignore", "th": "ปิดวิทยุ ขับต่อ", "en": "TURN IT OFF", "sub": "", "color": "gray"},
		],
	},
	"stray_dog": {
		"th": "หมาหลงข้างทาง", "en": "A STRAY DOG", "image": "dog", "danger": 0,
		"desc": "หมาพันธุ์ผสมขนยุ่งวิ่งตามรถมาหลายกิโล ลิ้นห้อย หางกระดิก มันดูหิวแต่ไม่ดุร้ายเลย",
		"choices": [
			{"action": "adopt", "pet": {"kind": "dog", "name": "ข้าวตัง"}, "cost": {"food": 10}, "th": "รับเลี้ยง ตั้งชื่อว่า ข้าวตัง", "en": "ADOPT IT", "sub": "-10 อาหาร · ทุกคนมีความสุข +15 · มันจะวิ่งเล่นทั่วรถ", "color": "green", "lore": "khaotang"},
			{"action": "gift", "cost": {"food": 5}, "th": "โยนเนื้อแห้งให้", "en": "TOSS SOME FOOD", "sub": "-5 อาหาร · ความสุข +", "color": "yellow",
				"result": "มันงับเนื้อแห้งแล้วกระดิกหาง ก่อนวิ่งหายเข้าพุ่มไม้ข้างทาง ทุกคนยิ้มออก (+ความสุข)", "stamp": ["GOOD BOY", "ใจดีจัง"]},
			{"action": "ignore", "th": "ปล่อยมันไป", "en": "LEAVE IT BE", "sub": "ความสุขลด", "color": "gray", "happy": -6},
		],
	},
	"stray_cat": {
		"th": "แมวในซากรถ", "en": "A CAT IN THE WRECK", "image": "cat", "danger": 0,
		"desc": "เสียงร้องแหลม ๆ ดังจากใต้ซากรถเก๋ง แมวส้มผอมโซมองรถบ้านด้วยตาวาว มันคาบหนูกลายพันธุ์ตัวหนึ่งไว้ในปาก",
		"choices": [
			{"action": "adopt", "pet": {"kind": "cat", "name": "ส้มจี๊ด"}, "cost": {"food": 6}, "th": "อุ้มขึ้นรถ ตั้งชื่อ ส้มจี๊ด", "en": "TAKE IT ALONG", "sub": "-6 อาหาร · ความสุข + · จับหนู อาหารเสียน้อยลง", "color": "green"},
			{"action": "ignore", "th": "ปล่อยไว้ตรงนั้น", "en": "LEAVE IT", "sub": "", "color": "gray"},
		],
	},
	"mutant_hen": {
		"th": "ไก่สองหัว", "en": "TWO-HEADED HEN", "image": "hen", "danger": 0,
		"desc": "ไก่ตัวหนึ่งมีสองหัว ยืนจิกเมล็ดพืชอยู่กลางถนนอย่างไม่สนโลก ข้าง ๆ มีไข่สามฟองที่ดูปกติดี",
		"choices": [
			{"action": "adopt", "pet": {"kind": "hen", "name": "ไข่ดาว"}, "cost": {"food": 4}, "th": "จับขึ้นรถ ตั้งชื่อ ไข่ดาว", "en": "ADOPT THE HEN", "sub": "-4 อาหาร · ออกไข่ อาหาร +0.6/นาที", "color": "green"},
			{"action": "shelter", "time": 5.0, "reward": {"food": 15}, "th": "เก็บแค่ไข่", "en": "JUST THE EGGS", "sub": "อาหาร +15", "color": "yellow",
				"result": "เก็บไข่มาได้ ไก่สองหัวจ้องตามรถไปไม่วางตา", "stamp": ["EGGS", "ได้ไข่มา"]},
		],
	},
	"cultists": {
		"th": "ลัทธิเปลวสุริยะขวางทาง", "en": "EMBER CULT", "image": "cult", "danger": 4,
		"desc": "คนห่มผ้าแดงยืนเรียงแถวกลางถนน ใบหน้าเต็มไปด้วยแผลไหม้ พวกเขาสวดสรรเสริญวงแหวนสุริยะ และเรียกร้องเครื่องบูชา",
		"choices": [
			{"action": "pay", "cost": {"food": 25, "water": 25}, "th": "ถวายเสบียง", "en": "MAKE AN OFFERING", "sub": "-25 อาหาร -25 น้ำ", "color": "yellow", "lore": "ember_cult",
				"result": "พวกเขารับเสบียงไป สวดอะไรบางอย่างใส่รถ แล้วแยกแถวให้ผ่าน", "stamp": ["OFFERED", "ถวายแล้ว"]},
			{"action": "check", "stat": "agi", "dc": 7, "th": "แอบอ้อมผ่านซอย", "en": "SNEAK AROUND", "sub": "AGI สูง = รอด · พลาด = ตัวถังเสียหาย", "color": "green", "reward": {"scrap": 15}, "fail": {"hull": 18}},
			{"action": "fight", "th": "ฝ่าแนวด้วยกำลัง", "en": "BREAK THROUGH", "sub": "เลือกผู้ป้องกันสูงสุด 2 คน", "color": "red", "reward": {"scrap": 50, "_gear": 1}},
		],
	},
	"gas_station": {
		"th": "ปั๊มน้ำมันร้าง", "en": "ABANDONED GAS STATION", "image": "gas", "danger": 1,
		"desc": "ป้ายปั๊มเก่าเอียงกระเท่เร่ ถังใต้ดินอาจยังมีเชื้อเพลิงเหลือ ส่วนมินิมาร์ทข้างๆ ถูกรื้อไปครึ่งหนึ่ง",
		"choices": [
			{"action": "check", "stat": "str", "dc": 6, "th": "สูบเชื้อเพลิงจากถัง", "en": "SIPHON THE TANKS", "sub": "+60 ไฟฟ้า (เติมเครื่องปั่นไฟ) · พลาด = ไฟลุก ตัวถังเสียหาย", "color": "yellow", "reward": {"power": 60}, "fail": {"hull": 15}},
			{"action": "loot", "th": "ค้นมินิมาร์ท", "en": "RAID THE SHOP", "sub": "อาหารกระป๋อง + น้ำ", "color": "green", "reward": {"food": 30, "water": 25}},
			{"action": "ignore", "th": "ขับผ่าน", "en": "DRIVE ON", "sub": "", "color": "gray"},
		],
	},
	"gambler": {
		"th": "นักพนันแห่งทุ่งร้าง", "en": "WASTELAND GAMBLER", "image": "gambler", "danger": 0,
		"desc": "ชายใส่แว่นดำนั่งบนลังไม้ข้างทาง ถือลูกเต๋าสามลูก \"แทงสักตาไหมเพื่อน? ชนะได้สองเท่าครึ่ง แพ้ก็แค่เศษเหล็ก\"",
		"choices": [
			{"action": "gamble", "cost": {"scrap": 60}, "th": "แทง 60 เศษเหล็ก", "en": "BET 60 SCRAP", "sub": "45% ได้ 150 · 55% เสียหมด", "color": "yellow", "lore": "gambler"},
			{"action": "ignore", "th": "ไม่เล่นด้วย", "en": "NO THANKS", "sub": "", "color": "gray"},
		],
	},
	"plane_wreck": {
		"th": "ซากเครื่องบินขนส่ง", "en": "CARGO PLANE WRECK", "image": "plane", "danger": 2,
		"desc": "เครื่องบินขนส่งทหารหักเป็นสองท่อนอยู่กลางทุ่ง ห้องสัมภาระยังปิดสนิท แต่มีเสียงอะไรบางอย่างเคลื่อนไหวอยู่ข้างใน",
		"choices": [
			{"action": "check", "stat": "agi", "dc": 6, "th": "ปีนเข้าห้องสัมภาระ", "en": "SEARCH THE CARGO", "sub": "AGI สูง = ปลอดภัย · ได้อุปกรณ์", "color": "green", "reward": {"_gear_rare": 1, "stimpack": 1}, "fail": {"hp": 20}, "lore": "helios"},
			{"action": "ignore", "th": "ไม่เสี่ยง", "en": "LEAVE IT", "sub": "", "color": "gray"},
		],
	},
	"acid_flood": {
		"th": "น้ำท่วมกรดทะลักข้ามถนน", "en": "ACID FLOOD", "image": "acid", "danger": 3,
		"desc": "น้ำสีเขียวเรืองแสงไหลบ่าข้ามถนน ยางรถเริ่มมีควันขึ้นแค่จอดใกล้ๆ",
		"choices": [
			{"action": "shelter", "time": 40.0, "th": "รอน้ำลด", "en": "WAIT IT OUT", "sub": "หยุดรถ 40 วินาที", "color": "green"},
			{"action": "push", "th": "ลุยข้ามไปเลย", "en": "FORD IT", "sub": "ตัวถังเสียหาย · ทุกคนได้รับรังสี", "color": "red"},
		],
	},
	"rogue_bot": {
		"th": "หุ่นยนต์รักษาความปลอดภัยคลั่ง", "en": "ROGUE SECURITY BOT", "image": "robot", "danger": 5,
		"desc": "หุ่นยนต์สูงสามเมตรยืนขวางแยก ลำโพงตะโกนซ้ำ ๆ \"พลเมือง โปรดแสดงบัตรประจำตัว\" ปืนกลบนไหล่หมุนมาทางรถบ้าน",
		"choices": [
			{"action": "check", "stat": "int", "dc": 8, "th": "เจาะระบบปิดเครื่อง", "en": "HACK & SHUT DOWN", "sub": "INT สูง · ได้ชิ้นส่วนรถ", "color": "green", "reward": {"_vanpart": 1, "components": 15}, "fail": {"hull": 25}, "lore": "overseer"},
			{"action": "fight", "th": "ทำลายมัน", "en": "DESTROY IT", "sub": "เลือกผู้ป้องกันสูงสุด 2 คน", "color": "red", "reward": {"components": 25, "scrap": 70}},
		],
	},
	"wolves": {
		"th": "หมาป่ากลายพันธุ์รังสีล้อมรถ!", "en": "RAD-WOLVES AMBUSH!", "image": "wolves", "danger": 3,
		"desc": "ฝูงหมาป่ากลายพันธุ์หิวกระหายกำลังโจมตีรถบ้าน พยายามพังประตูและทำร้ายผู้คน! ต้องรีบส่งคนออกไปขับไล่ก่อนรถจะเสียหาย",
		"choices": [
			{"action": "fight", "th": "ส่งทีมออกไปรบ!", "en": "FIGHT THEM OFF!", "sub": "เลือกผู้ป้องกันสูงสุด 2 คน", "color": "red", "reward": {"food": 25, "scrap": 20}},
			{"action": "flee", "th": "เร่งเครื่องหนี", "en": "SPEED UP & FLEE", "sub": "เสียไฟ 20% · เสี่ยงโดนโจมตีท้ายรถ", "color": "gray"},
		],
	},
	"raiders": {
		"th": "ด่านปิดกั้นของกลุ่มโจร!", "en": "RAIDER ROADBLOCK", "image": "raiders", "danger": 4,
		"desc": "โจรท้องถิ่นลากซากรถมาขวางถนนไว้ทั้งเส้น อาวุธครบมือ เรียกเสบียงเป็นค่าผ่านทาง ไม่จ่ายก็เตรียมโดนปล้น!",
		"choices": [
			{"action": "pay", "th": "เจรจาต่อรอง", "en": "BARGAIN", "sub": "ให้คนที่ INT สูงสุดไปต่อรอง (50 เศษเหล็ก)", "color": "yellow", "cost": {"scrap": 50}, "stat_discount": "int"},
			{"action": "fight", "th": "ส่งทีมปะทะ", "en": "CLEAR THE ROAD!", "sub": "ส่งคนออกไปเคลียร์ทาง", "color": "red", "reward": {"scrap": 60, "_weapon": 1}},
			{"action": "ram", "th": "ฝ่าด่าน", "en": "RAM THROUGH", "sub": "เร่งเครื่องชน! เสี่ยงตัวถังเสียหาย", "color": "orange"},
		],
	},
	"cache": {
		"th": "พบคลังเสบียงทิ้งร้าง", "en": "ABANDONED SUPPLY CACHE", "image": "cache", "danger": 1,
		"desc": "เรดาร์ตรวจพบลังเสบียงทหารเก่าข้างทาง อาจมีของมีค่า... หรือกับดัก",
		"choices": [
			{"action": "loot", "th": "ส่งคนลงไปค้น", "en": "SEARCH IT", "sub": "AGI สูง = ปลดกับดักได้ดี", "color": "green", "reward": {"scrap": 45, "stimpack": 1, "ammo": 6}},
			{"action": "ignore", "th": "ขับผ่านไป", "en": "DRIVE ON", "sub": "ไม่เสี่ยง", "color": "gray"},
		],
	},
	"survivor": {
		"th": "ผู้รอดชีวิตโบกมือขอความช่วยเหลือ", "en": "LONE SURVIVOR", "image": "survivor", "danger": 1,
		"desc": "คนผอมโซคนหนึ่งยืนโบกมืออยู่ข้างทาง ขอติดรถไปด้วยและบอกว่าทำงานได้ทุกอย่าง",
		"choices": [
			{"action": "recruit", "th": "รับขึ้นรถ", "en": "WELCOME ABOARD", "sub": "+1 ลูกเรือ (ต้องมีเตียงว่าง)", "color": "green"},
			{"action": "gift", "th": "ให้เสบียงแล้วไปต่อ", "en": "GIVE SUPPLIES", "sub": "-15 อาหาร -15 น้ำ · ความสุข +", "color": "yellow", "cost": {"food": 15, "water": 15}},
			{"action": "ignore", "th": "ไม่จอด", "en": "KEEP DRIVING", "sub": "ความสุขลดเล็กน้อย", "color": "gray", "happy": -5},
		],
	},
	"radstorm": {
		"th": "พายุรังสีกำลังเข้า!", "en": "RADIATION STORM", "image": "radstorm", "danger": 3,
		"desc": "เมฆสีเขียวเรืองแสงก่อตัวบนขอบฟ้า เครื่องวัดไกเกอร์ดังไม่หยุด",
		"choices": [
			{"action": "shelter", "th": "จอดหลบพายุ", "en": "TAKE SHELTER", "sub": "หยุดรถ 45 วินาที ปลอดภัย", "color": "green", "time": 45.0},
			{"action": "push", "th": "ฝ่าพายุไปเลย", "en": "PUSH THROUGH", "sub": "ทุกคนได้รับรังสี · ตัวถังเสียหาย", "color": "red"},
		],
	},
	"bridge": {
		"th": "สะพานข้ามลำธารพังถล่ม", "en": "BROKEN BRIDGE", "image": "bridge", "danger": 2,
		"desc": "สะพานคอนกรีตข้างหน้าขาดกลาง รถบ้านข้ามไม่ได้",
		"choices": [
			{"action": "repair", "th": "ซ่อมสะพาน", "en": "REPAIR BRIDGE", "sub": "ใช้ 40 เศษเหล็ก (STR ช่วยลดต้นทุน)", "color": "yellow", "cost": {"scrap": 40}, "stat_discount": "str"},
			{"action": "detour", "th": "อ้อมทางป่า", "en": "TAKE DETOUR", "sub": "เสียไฟ 25 · หยุด 30 วินาที", "color": "gray", "cost": {"power": 25}, "time": 30.0},
		],
	},
	"bugs": {
		"th": "แมลงยักษ์กลายพันธุ์!", "en": "MUTANT BUG SWARM", "image": "bugs", "danger": 2,
		"desc": "แมลงขนาดเท่าสุนัขคลานออกมาจากซากเครื่องจักร พวกมันชอบกัดสายไฟ!",
		"choices": [
			{"action": "fight", "th": "กำจัดให้หมด", "en": "EXTERMINATE", "sub": "เลือกผู้ป้องกันสูงสุด 2 คน", "color": "red", "reward": {"food": 20, "scrap": 15}},
			{"action": "flee", "th": "เร่งเครื่องหนี", "en": "OUTRUN THEM", "sub": "เสียไฟ 20%", "color": "gray"},
		],
	},
	"trader": {
		"th": "กองคาราวานพ่อค้า", "en": "TRADER CARAVAN", "image": "trader", "danger": 0,
		"desc": "พ่อค้าเร่กับเกวียนบรรทุกของโบกมือทัก \"มีอะไรมาแลกไหม เพื่อน?\"",
		"choices": [
			{"action": "trade", "th": "แลกอาหารเป็นเศษเหล็ก", "en": "SELL FOOD", "sub": "-30 อาหาร → +60 เศษเหล็ก", "color": "yellow", "cost": {"food": 30}, "reward": {"scrap": 60}},
			{"action": "trade", "th": "ซื้อยารักษา", "en": "BUY MEDS", "sub": "-40 เศษเหล็ก → สติมแพ็ก x2", "color": "green", "cost": {"scrap": 40}, "reward": {"stimpack": 2}},
			{"action": "ignore", "th": "ขอบคุณ ไม่เป็นไร", "en": "NO THANKS", "sub": "", "color": "gray"},
		],
	},
	"sandstorm": {
		"th": "กำแพงพายุทรายถาโถม!", "en": "SANDSTORM WALL", "image": "sandstorm", "danger": 2,
		"desc": "พายุทรายสูงเท่าตึกกำลังพุ่งเข้าหา แผงโซลาร์จะถูกฝุ่นเกาะหนา",
		"choices": [
			{"action": "shelter", "th": "ปิดแผงและจอดรอ", "en": "BATTEN DOWN", "sub": "หยุดรถ 40 วินาที", "color": "green", "time": 40.0},
			{"action": "push", "th": "ฝ่าพายุ", "en": "DRIVE THROUGH", "sub": "ตัวถังเสียหาย · แผงสกปรกหนัก", "color": "red", "dirt": 0.5},
		],
	},
	"frozen": {
		"th": "ถนนเป็นน้ำแข็งลื่น", "en": "BLACK ICE", "image": "frozen", "danger": 2,
		"desc": "ถนนข้างหน้าเคลือบน้ำแข็งบางใส รถหนักแบบนี้อาจไถลตกข้างทาง",
		"choices": [
			{"action": "detour", "th": "ขับช้าๆ อย่างระวัง", "en": "CREEP ALONG", "sub": "เสียไฟ 15 · หยุด 25 วินาที", "color": "green", "cost": {"power": 15}, "time": 25.0,
				"result": "ค่อย ๆ ไถลผ่านช่วงน้ำแข็งไปได้ ไม่มีใครเจ็บ", "stamp": ["SAFE", "ผ่านมาได้"]},
			{"action": "ram", "th": "ลุยด้วยความเร็ว", "en": "FULL SPEED", "sub": "เสี่ยงตัวถังเสียหาย", "color": "red"},
		],
	},
}

# ------------------------------------------------------------------ NAMES
const FIRST_NAMES := ["มาร์ค", "คลารา", "บ็อบ", "แซลลี่", "ลีโอ", "อาร์โล", "นิค", "เมย์", "ต้น", "ฝน", "จิน", "ไอซ์", "ปอ", "โจ", "แพร", "เบน", "ซาร่า", "กัส", "ลิลลี่", "ภู", "อิง", "ท็อป", "เรย์", "มีน"]
const TITLES := {"army": "จ่า", "lab": "ดร.", "chef": "เชฟ", "medic": "พยาบาล", "scav": "", "jumpsuit": "", "raider": "", "builder": "ช่าง"}
const OUTFIT_FOR_STAT := {"str": ["army", "scav"], "int": ["lab", "medic", "jumpsuit"], "agi": ["chef", "scav", "jumpsuit"]}
const HAIRS := ["brown", "black", "blonde", "red", "gray"]
## MV-170 named crew (Features "crew_roster_20"): sprite dw_crew_<id> + pt_dw_crew_<id> from tools/art/chars.py CREW.
## stat = the best stat they show up with (decides their room like any recruit); cameo = visual guest only
const CREW_ROSTER := {
	"max": {"name": "แม็กซ์", "role": "นักเดินทางถนนร้าง", "stat": "agi", "cameo": true},
	"rick": {"name": "ริก", "role": "อดีตนายอำเภอ", "stat": "str", "cameo": true},
	"ellie": {"name": "เอลลี่", "role": "หน่วยสอดแนม", "stat": "agi", "cameo": true},
	"jill": {"name": "นีออน", "role": "หน่วยกู้ภัย", "stat": "str", "cameo": true},
	"leon": {"name": "เจฟ", "role": "อดีตตำรวจ", "stat": "str", "cameo": true},
	"niran": {"name": "นิรันดร์", "role": "นักนำทาง", "stat": "agi", "cameo": false},
	"mali": {"name": "มะลิ", "role": "หมอสนาม", "stat": "int", "cameo": false},
	"boon": {"name": "บุญ", "role": "ช่างเครื่องดีเซล", "stat": "int", "cameo": false},
	"dao": {"name": "ดาว", "role": "พนักงานวิทยุ", "stat": "int", "cameo": false},
	"lek": {"name": "เล็ก", "role": "แม่ครัวแคมป์", "stat": "agi", "cameo": false},
	"arun": {"name": "อรุณ", "role": "นักประดาน้ำกู้ซาก", "stat": "str", "cameo": false},
	"ploy": {"name": "พลอย", "role": "นักพฤกษศาสตร์", "stat": "int", "cameo": false},
	"somchai": {"name": "สมชาย", "role": "ช่างเชื่อม", "stat": "str", "cameo": false},
	"mae": {"name": "แม่เม", "role": "ผู้ดูแลเสบียง", "stat": "agi", "cameo": false},
	"ken": {"name": "เคน", "role": "ยามห้องนิรภัย", "stat": "str", "cameo": false},
	"nok": {"name": "นก", "role": "นักวิ่งส่งของ", "stat": "agi", "cameo": false},
	"isha": {"name": "อิชา", "role": "นักวิทยาศาสตร์แล็บ", "stat": "int", "cameo": false},
	"tomas": {"name": "โทมัส", "role": "วิศวกรระบบน้ำ", "stat": "int", "cameo": false},
	"june": {"name": "จูน", "role": "ช่างไฟฟ้า", "stat": "int", "cameo": false},
	"viktor": {"name": "วิกเตอร์", "role": "คนขับรถหน้าหนาว", "stat": "str", "cameo": false},
}


func room_def(t: String) -> Dictionary:
	return ROOMS.get(t, {})


# ------------------------------------------------------------------ MV-247: raw food (crops + meat)
## meat per kill (before level / elite / boss multipliers) for the mutated animals; people, zombies and
## machines give none
const MEAT_MOBS := {
	"rad_rat": 0.5, "scorpion": 0.8, "vulture": 0.6, "rad_wolf": 1.0, "mutant_bug": 0.4,
	"frost_wolf": 1.0, "yeti": 1.6, "toxic_toad": 0.6, "mosquito": 0.2, "mutant_ape": 1.4,
}
const MEAT_PER_KILL := 0.6       # x the table above (boss x12, elite x3)
const RAW_KEYS := ["crops", "meat"]
const COOK_YIELD := 1.5         # food per unit of crops / meat the kitchen cooks
const COOK_WATER := 0.2         # water per unit of food the kitchen cooks
const CROP_WATER := 0.25        # water per unit of crops hydroponics grows
const START_RAW := {"crops": 40.0, "meat": 20.0}


func raw_food() -> bool:
	return Features.on("raw_food")


## a room's recipes as the player sees them: with raw food on, each recipe uses its raw_* cost / output / name
## and the raw-only ones appear; with it off, the old scrap recipes (MV-247)
func recipes(room_type: String) -> Array:
	var on := raw_food()
	var out := []
	for rec in room_def(room_type).get("recipes", []):
		if rec.has("raw") and bool(rec.raw) != on:
			continue
		if not on:
			out.append(rec)
			continue
		var r: Dictionary = rec.duplicate()
		for k in ["cost", "out", "th", "en"]:
			if rec.has("raw_" + k):
				r[k] = rec["raw_" + k]
		out.append(r)
	return out


func room_produce(t: String) -> Dictionary:
	var def := room_def(t)
	return def.get("raw_produce", def.get("produce", {})) if raw_food() else def.get("produce", {})


func room_effect(t: String) -> String:
	var def := room_def(t)
	return str(def.get("raw_effect_th", def.get("effect_th", ""))) if raw_food() else str(def.get("effect_th", ""))


func biome(i: int) -> Dictionary:
	return BIOMES[clampi(i, 0, BIOMES.size() - 1)]


func biome_start_km(i: int) -> float:
	var s := 0.0
	for k in range(i):
		s += BIOMES[k]["length"]
	return s


func total_route_km() -> float:
	return biome_start_km(BIOMES.size())


func item_name(id: String) -> String:
	if ITEMS.has(id):
		return ITEMS[id]["th"]
	match id:
		"food": return "อาหาร"
		"water": return "น้ำ"
		"power": return "ไฟ"
		"scrap": return "เศษเหล็ก"
		"fuel": return "เชื้อเพลิง"
		"crops": return "พืชผล"
		"meat": return "เนื้อสด"
		"_weapon": return "อาวุธสุ่ม"
		"_vanpart": return "ชิ้นส่วนรถสุ่ม"
		"_gear": return "อุปกรณ์สุ่ม"
		"_gear_rare": return "อุปกรณ์หายาก"
		"_armor": return "เกราะสุ่ม"
		"_hull": return "ซ่อมตัวถัง"
		"_recruit": return "ผู้รอดชีวิต"
	return id


func item_icon(id: String) -> String:
	if ITEMS.has(id):
		return ITEMS[id]["icon"]
	match id:
		"food": return "food"
		"water": return "water"
		"power": return "power"
		"scrap": return "scrap"
		"fuel": return "fuel"
		"crops": return "seed"
		"meat": return "meat"
		"_weapon": return "rifle"
		"_vanpart": return "engine"
		"_gear", "_gear_rare": return "chest"
		"_armor": return "armor"
		"_hull": return "hull"
		"_recruit": return "people"
	return "gear"
