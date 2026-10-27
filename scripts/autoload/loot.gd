extends Node
## Gear & loot: item bases, 6 rarities, random affixes, item level scaling,
## enhance (+N), synthesis (3 -> 1 next rarity), salvage, equipment stat totals.
## Items are plain Dictionaries so they save as JSON:
##   {uid, base, slot, rar, ilvl, plus, aff:[{k,v}], lock}

const RARITY := [
	{"id": "common", "th": "ทั่วไป", "en": "COMMON", "col": Color("b8bec9"), "mult": 1.00, "affixes": 0, "max_plus": 3, "w": 600},
	{"id": "uncommon", "th": "ดี", "en": "UNCOMMON", "col": Color("6be27d"), "mult": 1.25, "affixes": 1, "max_plus": 5, "w": 250},
	{"id": "rare", "th": "หายาก", "en": "RARE", "col": Color("6fc3ff"), "mult": 1.60, "affixes": 2, "max_plus": 7, "w": 100},
	{"id": "epic", "th": "มหากาพย์", "en": "EPIC", "col": Color("c77dff"), "mult": 2.10, "affixes": 3, "max_plus": 9, "w": 40},
	{"id": "legendary", "th": "ตำนาน", "en": "LEGENDARY", "col": Color("ffb347"), "mult": 2.80, "affixes": 3, "max_plus": 10, "w": 9},
	{"id": "mythic", "th": "ปฐมกาล", "en": "MYTHIC", "col": Color("ff5c7a"), "mult": 3.80, "affixes": 4, "max_plus": 12, "w": 1},
]

## Hero slots + vault (van) slots
const HERO_SLOTS := ["weapon", "armor", "helmet", "boots", "gadget", "backpack"]
const VAN_SLOTS := ["turret", "plating", "engine", "spikes"]
const SLOT_TH := {"weapon": "อาวุธ", "armor": "เกราะ", "helmet": "หมวก", "boots": "รองเท้า", "backpack": "กระเป๋า", "gadget": "แกดเจ็ต", "turret": "ป้อมปืน", "plating": "เกราะรถ", "engine": "เครื่องยนต์", "spikes": "หนามท้ายรถ"}
const SLOT_ICON := {"weapon": "rifle", "armor": "armor", "helmet": "hardhat", "boots": "boots", "backpack": "backpack", "gadget": "chip", "turret": "turret", "plating": "plates", "engine": "engine", "spikes": "spikes"}

## base stats at item level 1 (scaled by ilvl, rarity and +N)
## min_ilvl: earliest item level the base can drop at
const BASES := {
	# --- weapons: dmg per hit, aspd (hits/s), range px, melee bonus for bruisers, splash targets
	"pipe_pistol": {"slot": "weapon", "th": "ปืนท่อเหล็ก", "en": "Pipe Pistol", "icon": "pistol", "dmg": 6.0, "aspd": 1.2, "range": 200, "min_ilvl": 1},
	"pipe_wrench": {"slot": "weapon", "th": "ประแจยักษ์", "en": "Pipe Wrench", "icon": "wrench", "dmg": 9.0, "aspd": 1.0, "range": 40, "melee": true, "min_ilvl": 1},
	"hunting_rifle": {"slot": "weapon", "th": "ไรเฟิลล่าสัตว์", "en": "Hunting Rifle", "icon": "rifle", "dmg": 14.0, "aspd": 0.6, "range": 280, "crit": 6.0, "min_ilvl": 2},
	"shotgun": {"slot": "weapon", "th": "ลูกซองตัดสั้น", "en": "Sawed-off", "icon": "shotgun", "dmg": 10.0, "aspd": 0.8, "range": 150, "splash": 2, "min_ilvl": 3},
	"smg": {"slot": "weapon", "th": "ปืนกลมือ", "en": "SMG", "icon": "smg", "dmg": 4.0, "aspd": 2.6, "range": 190, "min_ilvl": 5},
	"sledgehammer": {"slot": "weapon", "th": "ค้อนปอนด์", "en": "Sledgehammer", "icon": "hammer", "dmg": 18.0, "aspd": 0.55, "range": 40, "melee": true, "splash": 3, "min_ilvl": 6},
	"assault_rifle": {"slot": "weapon", "th": "ปืนจู่โจม", "en": "Assault Rifle", "icon": "rifle", "dmg": 8.0, "aspd": 1.6, "range": 230, "min_ilvl": 8},
	"laser_rifle": {"slot": "weapon", "th": "ปืนเลเซอร์", "en": "Laser Rifle", "icon": "laser", "dmg": 13.0, "aspd": 1.25, "range": 270, "crit": 4.0, "min_ilvl": 16},
	# --- armor
	"leather_jacket": {"slot": "armor", "th": "แจ็กเก็ตหนัง", "en": "Leather Jacket", "icon": "jacket", "hp": 30.0, "def": 3.0, "min_ilvl": 1},
	"scrap_mail": {"slot": "armor", "th": "เกราะเศษเหล็ก", "en": "Scrap Mail", "icon": "mail", "hp": 45.0, "def": 6.0, "min_ilvl": 3},
	"riot_gear": {"slot": "armor", "th": "ชุดปราบจลาจล", "en": "Riot Gear", "icon": "riot", "hp": 60.0, "def": 9.0, "min_ilvl": 8},
	"power_frame": {"slot": "armor", "th": "โครงเกราะพลังงาน", "en": "Power Frame", "icon": "powerframe", "hp": 90.0, "def": 13.0, "min_ilvl": 18},
	# --- helmets
	"hard_hat": {"slot": "helmet", "th": "หมวกนิรภัยช่าง", "en": "Hard Hat", "icon": "hardhat", "hp": 12.0, "def": 2.0, "min_ilvl": 1},
	"gas_mask": {"slot": "helmet", "th": "หน้ากากกันแก๊ส", "en": "Gas Mask", "icon": "gasmask", "hp": 10.0, "def": 1.0, "regen": 0.4, "min_ilvl": 3},
	"combat_helmet": {"slot": "helmet", "th": "หมวกรบ", "en": "Combat Helmet", "icon": "helmet", "hp": 22.0, "def": 4.0, "min_ilvl": 8},
	"visor_helm": {"slot": "helmet", "th": "หมวกวิซเซอร์เล็งเป้า", "en": "Targeting Visor", "icon": "visor", "hp": 30.0, "def": 5.0, "crit": 4.0, "min_ilvl": 18},
	# --- boots
	"sneakers": {"slot": "boots", "th": "รองเท้าผ้าใบขาด", "en": "Worn Sneakers", "icon": "boots", "dodge": 4.0, "min_ilvl": 1},
	"work_boots": {"slot": "boots", "th": "รองเท้าบู๊ตช่าง", "en": "Work Boots", "icon": "workboots", "hp": 10.0, "def": 2.0, "dodge": 2.0, "min_ilvl": 2},
	"tactical_boots": {"slot": "boots", "th": "รองเท้ายุทธวิธี", "en": "Tactical Boots", "icon": "tacboots", "dodge": 6.0, "aspd_pct": 6.0, "min_ilvl": 8},
	"jet_boots": {"slot": "boots", "th": "รองเท้าไอพ่น", "en": "Jet Boots", "icon": "jetboots", "dodge": 10.0, "aspd_pct": 8.0, "min_ilvl": 20},
	# --- backpacks: better pack = more drops + more supplies scavenged from kills / expeditions
	"school_bag": {"slot": "backpack", "th": "กระเป๋านักเรียน", "en": "School Bag", "icon": "backpack", "loot": 5.0, "supply": 6.0, "min_ilvl": 1},
	"hiking_pack": {"slot": "backpack", "th": "เป้เดินป่า", "en": "Hiking Pack", "icon": "hikingpack", "loot": 8.0, "supply": 12.0, "min_ilvl": 4},
	"military_ruck": {"slot": "backpack", "th": "เป้ทหาร", "en": "Military Ruck", "icon": "ruck", "loot": 12.0, "supply": 16.0, "hp": 10.0, "min_ilvl": 10},
	"scav_frame": {"slot": "backpack", "th": "โครงเป้นักคุ้ยซาก", "en": "Scavenger Frame", "icon": "framepack", "loot": 18.0, "supply": 24.0, "min_ilvl": 20},
	# --- gadgets (small base, mostly affixes)
	"medkit_pouch": {"slot": "gadget", "th": "กระเป๋าพยาบาล", "en": "Medkit Pouch", "icon": "medkit", "regen": 1.5, "min_ilvl": 1},
	"targeting_chip": {"slot": "gadget", "th": "ชิปเล็งเป้า", "en": "Targeting Chip", "icon": "chip", "crit": 6.0, "min_ilvl": 1},
	"stim_injector": {"slot": "gadget", "th": "เข็มกระตุ้น", "en": "Stim Injector", "icon": "stimpack", "aspd_pct": 12.0, "min_ilvl": 2},
	"lucky_charm": {"slot": "gadget", "th": "เครื่องรางนำโชค", "en": "Lucky Charm", "icon": "charm", "loot": 10.0, "min_ilvl": 4},
	# --- vault: turret
	"mg_turret": {"slot": "turret", "th": "ป้อมปืนกล", "en": "MG Turret", "icon": "turret", "sprite": "mg", "dmg": 4.0, "aspd": 2.0, "range": 220, "min_ilvl": 1},
	"harpoon_gun": {"slot": "turret", "th": "ปืนฉมวก", "en": "Harpoon Gun", "icon": "harpoon", "sprite": "harpoon", "dmg": 15.0, "aspd": 0.5, "range": 260, "min_ilvl": 5},
	"flak_cannon": {"slot": "turret", "th": "ปืนต่อสู้อากาศยาน", "en": "Flak Cannon", "icon": "turret", "sprite": "flak", "dmg": 6.0, "aspd": 1.4, "range": 240, "splash": 2, "aa": true, "min_ilvl": 8},
	"tesla_coil": {"slot": "turret", "th": "ขดลวดเทสลา", "en": "Tesla Coil", "icon": "tesla", "sprite": "tesla", "dmg": 7.0, "aspd": 1.0, "range": 200, "splash": 3, "min_ilvl": 12},
	# --- vault: plating
	"scrap_plates": {"slot": "plating", "th": "แผ่นเหล็กปะ", "en": "Scrap Plates", "icon": "plates", "hull": 30.0, "def": 4.0, "min_ilvl": 1},
	"steel_plates": {"slot": "plating", "th": "เกราะเหล็กกล้า", "en": "Steel Plates", "icon": "plates", "hull": 50.0, "def": 8.0, "min_ilvl": 6},
	"reactive_armor": {"slot": "plating", "th": "เกราะปฏิกิริยา", "en": "Reactive Armor", "icon": "shield", "hull": 80.0, "def": 12.0, "min_ilvl": 15},
	# --- vault: engine
	# v4.6: an engine item IS the engine in the cab; "engine" = EngineBay.TYPES key (speed / power / noise /
	# heat... come from there, affixes still add on top)
	"rusty_v8": {"slot": "engine", "th": "เครื่อง V8 สนิมเขรอะ", "en": "Rusty V8", "icon": "engine", "engine": "v8", "min_ilvl": 1},
	"wood_gasifier": {"slot": "engine", "th": "เตาแก๊สไม้", "en": "Wood-gas Gasifier", "icon": "engine", "engine": "woodgas", "min_ilvl": 3},
	"ev_motor": {"slot": "engine", "th": "มอเตอร์ไฟฟ้าดัดแปลง", "en": "EV Conversion", "icon": "power", "engine": "electric", "min_ilvl": 4},
	"diesel_turbo": {"slot": "engine", "th": "ดีเซลเทอร์โบ", "en": "Diesel Turbo", "icon": "engine", "engine": "turbo6", "min_ilvl": 6},
	"diesel_electric": {"slot": "engine", "th": "ดีเซล-ไฟฟ้า", "en": "Diesel-Electric", "icon": "engine", "engine": "hybrid", "min_ilvl": 9},
	"gas_turbine": {"slot": "engine", "th": "กังหันแก๊ส", "en": "Gas Turbine", "icon": "engine", "engine": "turbine", "min_ilvl": 14},
	"fusion_cell": {"slot": "engine", "th": "เซลล์ฟิวชัน", "en": "Fusion Cell", "icon": "power", "engine": "fusion", "min_ilvl": 16},
	# --- vault: rear spikes (damage to enemies that reach the van)
	"spiked_bumper": {"slot": "spikes", "th": "กันชนหนาม", "en": "Spiked Bumper", "icon": "spikes", "thorns": 5.0, "min_ilvl": 1},
	"snow_plow": {"slot": "spikes", "th": "ใบมีดไถ", "en": "Plow Blade", "icon": "plow", "thorns": 8.0, "def": 3.0, "min_ilvl": 6},
	"saw_blades": {"slot": "spikes", "th": "ใบเลื่อยหมุน", "en": "Saw Blades", "icon": "saw", "thorns": 14.0, "min_ilvl": 14},
}

## affix key -> [th label, min, max at ilvl 1, scales with ilvl?, allowed slots, percent?]
const AFFIXES := {
	"dmg": ["ดาเมจ", 4.0, 8.0, false, ["weapon", "gadget", "turret"], true],
	"aspd": ["ความเร็วโจมตี", 3.0, 8.0, false, ["weapon", "gadget", "turret"], true],
	"crit": ["โอกาสคริติคอล", 1.5, 4.0, false, ["weapon", "gadget", "armor", "helmet"], true],
	"dodge": ["หลบหลีก", 1.5, 4.0, false, ["boots", "gadget", "helmet"], true],
	"supply": ["หาเสบียงได้", 4.0, 10.0, false, ["backpack", "gadget"], true],
	"critd": ["ดาเมจคริติคอล", 10.0, 25.0, false, ["weapon", "gadget"], true],
	"hp": ["พลังชีวิต", 8.0, 16.0, true, ["armor", "gadget", "helmet", "boots", "backpack"], false],
	"def": ["ป้องกัน", 1.0, 3.0, true, ["armor", "plating", "spikes", "helmet", "boots"], false],
	"regen": ["ฟื้นฟู/วิ", 0.4, 1.0, true, ["armor", "gadget", "helmet"], false],
	"lifesteal": ["ดูดเลือด", 1.0, 3.0, false, ["weapon", "gadget"], true],
	"loot": ["โอกาสดรอปของ", 3.0, 8.0, false, ["gadget", "engine", "armor", "backpack"], true],
	"scrap": ["เศษเหล็กจากศัตรู", 4.0, 10.0, false, ["gadget", "engine", "spikes", "backpack"], true],
	"xp": ["ค่าประสบการณ์", 4.0, 10.0, false, ["gadget", "armor", "helmet"], true],
	"hull": ["ตัวถังสูงสุด", 6.0, 14.0, true, ["plating", "engine"], false],
	"speed": ["ความเร็วรถ", 2.0, 5.0, false, ["engine"], true],
	"thorns": ["ดาเมจสะท้อน", 1.0, 3.0, true, ["spikes", "plating"], false],
	"turret": ["ดาเมจป้อมปืน", 5.0, 12.0, false, ["turret", "engine"], true],
}

const LEGEND_NAMES := {
	"weapon": ["ปืนลูกซองของยายไหม", "เหล็กพิฆาตจ่ามาร์ค", "สายฟ้าแห่งทุ่งร้าง"],
	"armor": ["เสื้อเกราะหนังจระเข้", "เสื้อคลุมตะกั่วกันรังสี"],
	"gadget": ["นาฬิกาพกไม่มีเข็ม", "เหรียญนำทางของคนขับรุ่นแรก"],
	"turret": ["เจ้าแมวคำราม", "ป้อมปืนเทวดา"],
	"plating": ["กระดองเต่ายักษ์"],
	"engine": ["หัวใจรถไฟสายสุดท้าย"],
	"spikes": ["ฟันมังกรเหล็ก"],
}

const ILVL_GROWTH := 1.12
const STASH_CAP := 60
## MV-47 bad-luck protection (switch loot_pity): random drops count in Game.s.pity; after this many drops
## without one, the next drop is at least Epic / Legendary (tune loot.pity_epic / loot.pity_legend)
const PITY_EPIC := 40.0
const PITY_LEGEND := 150.0

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


func rarity(r: int) -> Dictionary:
	return RARITY[clampi(r, 0, RARITY.size() - 1)]


func base(item: Dictionary) -> Dictionary:
	return BASES.get(item.get("base", ""), {})


func scale(item: Dictionary) -> float:
	return pow(ILVL_GROWTH, float(item.ilvl) - 1.0) * float(rarity(int(item.rar)).mult) * (1.0 + 0.10 * float(item.plus))


## stat value of the item's BASE stat (scaled)
func base_stat(item: Dictionary, key: String) -> float:
	var b := base(item)
	if not b.has(key):
		return 0.0
	match key:
		"aspd", "range", "splash", "aspd_pct", "crit", "loot", "speed", "dodge", "supply":
			return float(b[key])   # non-scaling base attributes
	return float(b[key]) * scale(item)


func item_name(item: Dictionary) -> String:
	if item.has("name"):
		return item.name
	return base(item).get("th", "?")


func item_icon(item: Dictionary) -> String:
	return base(item).get("icon", "gear")


func rar_color(item: Dictionary) -> Color:
	return rarity(int(item.rar)).col


# ------------------------------------------------------------------ generation
func roll_rarity(luck_pct: float = 0.0, min_rar: int = 0) -> int:
	var total := 0.0
	var weights := []
	for i in RARITY.size():
		var w := float(RARITY[i].w)
		if i >= 2:
			w *= 1.0 + luck_pct / 100.0 * float(i)
		if i < min_rar:
			w = 0.0
		weights.append(w)
		total += w
	var pick := rng.randf() * total
	for i in weights.size():
		pick -= weights[i]
		if pick <= 0.0:
			return i
	return min_rar


func roll_item(slot: String, ilvl: int, rar: int, base_id: String = "") -> Dictionary:
	ilvl = maxi(1, ilvl)
	if base_id == "":
		var pool := []
		for k in BASES:
			if BASES[k].slot == slot and int(BASES[k].min_ilvl) <= ilvl:
				pool.append(k)
		if pool.is_empty():
			for k in BASES:
				if BASES[k].slot == slot:
					pool.append(k)
		base_id = pool[rng.randi() % pool.size()]
	var item := {"uid": _next_uid(), "base": base_id, "slot": BASES[base_id].slot, "rar": rar, "ilvl": ilvl, "plus": 0, "aff": [], "lock": false}
	var count: int = RARITY[rar].affixes
	var allowed := []
	for k in AFFIXES:
		if (AFFIXES[k][4] as Array).has(item.slot):
			allowed.append(k)
	allowed.shuffle()
	for i in mini(count, allowed.size()):
		item.aff.append({"k": allowed[i], "v": _roll_affix(allowed[i], ilvl, rar)})
	if rar >= 4 and rng.randf() < 0.5:
		var names: Array = LEGEND_NAMES.get(item.slot, [])
		if not names.is_empty():
			item["name"] = names[rng.randi() % names.size()]
	return item


## counts_pity = false for tester drops, so GOD MODE doesn't move the player's guarantee
func roll_random(ilvl: int, luck_pct: float = 0.0, min_rar: int = 0, van_chance: float = 0.3, counts_pity: bool = true) -> Dictionary:
	var slots: Array = VAN_SLOTS if rng.randf() < van_chance else HERO_SLOTS
	var rar := drop_rarity(luck_pct, min_rar) if counts_pity else roll_rarity(luck_pct, min_rar)
	return roll_item(slots[rng.randi() % slots.size()], ilvl, rar)


# ------------------------------------------------------------------ pity (MV-47)
## {"epic": drops since the last Epic+, "legend": drops since the last Legendary+}
func pity() -> Dictionary:
	if not (Game.s.get("pity") is Dictionary):
		Game.s["pity"] = {}
	Game.s.pity.merge({"epic": 0, "legend": 0}, false)
	return Game.s.pity


## drops per guarantee: rar 3 = Epic+, 4 = Legendary+
func pity_need(rar: int) -> int:
	if rar >= 4:
		return int(Features.num("loot.pity_legend", PITY_LEGEND))
	return int(Features.num("loot.pity_epic", PITY_EPIC))


## drops left until the guarantee (1 = the next drop)
func pity_left(rar: int) -> int:
	return maxi(1, pity_need(rar) - int(pity().get("legend" if rar >= 4 else "epic", 0)))


## rarity of a random drop (kills, raids, expeditions, rewards) with the guarantee applied
func drop_rarity(luck_pct: float = 0.0, min_rar: int = 0) -> int:
	var r := roll_rarity(luck_pct, min_rar)
	if not Features.on("loot_pity"):
		return r
	var p := pity()
	var forced := -1
	if r < 4 and pity_left(4) <= 1:
		forced = 4
	elif r < 3 and pity_left(3) <= 1:
		forced = 3
	if forced >= 0:
		r = roll_rarity(luck_pct, forced)
		Trace.rec("loot", "pity", {"min": forced, "rar": r, "epic": int(p.epic), "legend": int(p.legend)})
	p.epic = 0 if r >= 3 else int(p.epic) + 1
	p.legend = 0 if r >= 4 else int(p.legend) + 1
	return r


func _roll_affix(k: String, ilvl: int, rar: int) -> float:
	var a: Array = AFFIXES[k]
	var v := rng.randf_range(float(a[1]), float(a[2])) * (1.0 + 0.15 * rar)
	if a[3]:
		v *= pow(ILVL_GROWTH, float(ilvl) - 1.0)
	return snappedf(v, 0.1)


func _next_uid() -> int:
	if Game.s.is_empty():
		return rng.randi()
	var u := int(Game.s.get("next_uid", 1))
	Game.s.next_uid = u + 1
	return u


# ------------------------------------------------------------------ stats
## total of an affix/base key across a set of items
func sum_key(items: Array, key: String) -> float:
	var t := 0.0
	for it in items:
		if it == null or (it is Dictionary and it.is_empty()):
			continue
		for a in it.aff:
			if a.k == key:
				t += float(a.v) * (1.0 + 0.05 * float(it.plus))
	return t


func describe(item: Dictionary) -> Array:
	## returns [[label, value_text, key], ...] for UI (special rows have no key)
	var out := []
	var b := base(item)
	for key in ["dmg", "aspd", "range", "splash", "hp", "def", "regen", "crit", "aspd_pct", "dodge", "loot", "supply", "hull", "speed", "power", "thorns"]:
		if not b.has(key):
			continue
		var v := base_stat(item, key)
		match key:
			"dmg": out.append(["ดาเมจ", "%.1f" % v])
			"aspd": out.append(["โจมตี/วิ", "%.2f" % v])
			"range": out.append(["ระยะ", "ประชิด" if b.get("melee", false) else str(int(v))])
			"splash": out.append(["โดนพร้อมกัน", "%d เป้า" % int(v)])
			"hp": out.append(["พลังชีวิต", "+%d" % int(v)])
			"def": out.append(["ป้องกัน", "+%.1f" % v])
			"regen": out.append(["ฟื้นฟู", "+%.1f/วิ" % v])
			"crit": out.append(["คริติคอล", "+%.1f%%" % v])
			"aspd_pct": out.append(["ความเร็วโจมตี", "+%d%%" % int(v)])
			"loot": out.append(["โอกาสดรอปของ", "+%d%%" % int(v)])
			"supply": out.append(["หาเสบียงได้", "+%d%%" % int(v)])
			"dodge": out.append(["หลบหลีก", "+%d%%" % int(v)])
			"hull": out.append(["ตัวถัง", "+%d" % int(v)])
			"speed": out.append(["ความเร็วรถ", "+%d%%" % int(v)])
			"power": out.append(["ผลิตไฟ", "+%.1f/นาที" % v])
			"thorns": out.append(["ดาเมจสะท้อน", "%.1f/วิ" % v])
		out[-1].append(key)   # MV-552: row[2] = stat key, so the detail window can compare it
	if b.get("melee", false):
		out.append(["พิเศษ", "นักสู้ท้ายรถ +40% / คนอื่น -40%"])
	if b.has("engine"):
		out.append_array(EngineBay.describe_type(str(b.engine)))
	return out


func affix_text(a: Dictionary, plus: int = 0) -> String:
	var def: Array = AFFIXES.get(a.k, ["?", 0, 0, false, [], false])
	var v := float(a.v) * (1.0 + 0.05 * plus)
	return ("+%.1f%% %s" % [v, def[0]]) if def[5] else ("+%.1f %s" % [v, def[0]])


## rough single-number score to compare items of the same slot
func power_score(item: Dictionary) -> float:
	if item.is_empty():
		return 0.0
	var s := scale(item)
	var b := base(item)
	var score := 0.0
	match item.slot:
		"weapon", "turret":
			score = float(b.get("dmg", 0)) * float(b.get("aspd", 1)) * s * (1.0 + 0.5 * (float(b.get("splash", 1)) - 1.0))
		"armor", "helmet", "boots":
			score = (float(b.get("hp", 0)) * 0.4 + float(b.get("def", 0)) * 3.0 + float(b.get("dodge", 0)) * 2.0 + float(b.get("crit", 0)) * 2.0) * s
		"backpack":
			score = (float(b.get("loot", 0)) + float(b.get("supply", 0))) * s
		"plating":
			score = (float(b.get("hull", 0)) * 0.3 + float(b.get("def", 0)) * 3.0) * s
		"spikes":
			score = float(b.get("thorns", 0)) * s * 2.0
		_:
			score = 8.0 * s
	return score * (1.0 + 0.12 * item.aff.size())


# ------------------------------------------------------------------ economy actions
func stash() -> Array:
	return Game.s.gear


func add_to_stash(item: Dictionary) -> bool:
	var st := stash()
	var thr := int(Game.s.combat.get("auto_salvage", -1))
	if int(item.rar) <= thr:
		_give_salvage(item)
		return false
	if st.size() >= STASH_CAP:
		# auto-salvage the weakest unlocked item to make room
		var worst := -1
		for i in st.size():
			if not st[i].lock and (worst < 0 or int(st[i].rar) < int(st[worst].rar)):
				worst = i
		if worst < 0 or int(st[worst].rar) > int(item.rar):
			_give_salvage(item)
			return false
		_give_salvage(st[worst])
		st.remove_at(worst)
	st.append(item)
	return true


func salvage_value(item: Dictionary) -> Dictionary:
	var r := int(item.rar)
	return {"components": (r + 1) * (r + 1) + int(item.plus) * (r + 1), "scrap": 2 * (r + 1) + int(item.ilvl) / 2}


func _give_salvage(item: Dictionary) -> void:
	var v := salvage_value(item)
	Game.add_item("components", int(v.components))
	Game._add_res("scrap", float(v.scrap))


func salvage(uid: int) -> Dictionary:
	var st := stash()
	for i in st.size():
		if int(st[i].uid) == uid:
			if st[i].lock:
				return {}
			var v := salvage_value(st[i])
			_give_salvage(st[i])
			st.remove_at(i)
			Game.resources_changed.emit()
			Game.gear_changed.emit()
			return v
	return {}


func salvage_bulk(max_rar: int, selected_ids: Array = []) -> Dictionary:
	var st := stash()
	var total := {"components": 0, "scrap": 0, "count": 0}
	for i in range(st.size() - 1, -1, -1):
		# MV-422: a confirmation only authorizes the items shown, not later drops.
		if not selected_ids.is_empty() and not selected_ids.has(int(st[i].uid)):
			continue
		if int(st[i].rar) <= max_rar and not st[i].lock:
			var v := salvage_value(st[i])
			total.components += int(v.components)
			total.scrap += int(v.scrap)
			total.count += 1
			_give_salvage(st[i])
			st.remove_at(i)
	Game.resources_changed.emit()
	Game.gear_changed.emit()
	return total


func enhance_cost(item: Dictionary) -> Dictionary:
	var p := int(item.plus) + 1
	var r := int(item.rar) + 1
	return {"components": p * r * 3, "scrap": p * r * 10}


func can_enhance(item: Dictionary) -> bool:
	return int(item.plus) < int(rarity(int(item.rar)).max_plus)


func enhance(item: Dictionary) -> bool:
	if not can_enhance(item):
		return false
	if not Game.pay(enhance_cost(item)):
		return false
	item.plus = int(item.plus) + 1
	Game.gear_changed.emit()
	return true


func synth_candidates(rar: int) -> Array:
	var out := []
	for it in stash():
		if int(it.rar) == rar and not it.lock:
			out.append(it)
	out.sort_custom(func(a, b): return power_score(a) < power_score(b))
	return out


func synth_cost(rar: int) -> Dictionary:
	return {"components": 15 * (rar + 1)}


## merge the 3 weakest unlocked items of a rarity into 1 item of the next rarity
func synthesize(rar: int) -> Dictionary:
	if rar >= RARITY.size() - 1:
		return {}
	var c := synth_candidates(rar)
	if c.size() < 3:
		return {}
	if not Game.pay(synth_cost(rar)):
		return {}
	var used: Array = c.slice(0, 3)
	var ilvl := 0
	for it in used:
		ilvl = maxi(ilvl, int(it.ilvl))
		stash().erase(it)
	var slot: String = used[rng.randi() % 3].slot
	var out := roll_item(slot, ilvl, rar + 1)
	stash().append(out)
	Game.gear_changed.emit()
	return out


# ------------------------------------------------------------------ equipping
func equipped_on(d: Dictionary, slot: String) -> Dictionary:
	var g: Dictionary = d.get("gear", {})
	var it = g.get(slot)
	return it if it is Dictionary else {}


func van_equipped(slot: String) -> Dictionary:
	var it = Game.s.van_gear.get(slot)
	return it if it is Dictionary else {}


func equip_from_stash(uid: int, d: Dictionary = {}) -> bool:
	var st := stash()
	for i in st.size():
		if int(st[i].uid) != uid:
			continue
		var item: Dictionary = st[i]
		var slot: String = item.slot
		if slot == "engine" and not EngineBay.fits(item):
			Game.toast.emit("เครื่องนี้ใหญ่เกินห้องเครื่องของ%s (ต้องการช่องขนาด %s)" % [Game.vehicle_def().th, EngineBay.SIZE_TH[EngineBay.size_of(item)]], "warn")
			return false
		st.remove_at(i)
		if VAN_SLOTS.has(slot):
			var old := van_equipped(slot)
			Game.s.van_gear[slot] = item
			if not old.is_empty():
				st.append(old)
		else:
			if d.is_empty():
				st.append(item)
				return false
			if not d.has("gear"):
				d["gear"] = {}
			var old2 := equipped_on(d, slot)
			d.gear[slot] = item
			if not old2.is_empty():
				st.append(old2)
		Game.gear_changed.emit()
		if slot == "engine":
			EngineBay.engine_changed.emit()
		return true
	return false


func unequip(d: Dictionary, slot: String) -> void:
	var it := equipped_on(d, slot) if not d.is_empty() else van_equipped(slot)
	if it.is_empty():
		return
	if d.is_empty():
		Game.s.van_gear[slot] = null
	else:
		d.gear[slot] = null
	stash().append(it)
	Game.gear_changed.emit()


## score adjusted for the squad role (melee weapons belong on the rear bruiser)
func role_score(item: Dictionary, role: int) -> float:
	var sc := power_score(item)
	if not item.is_empty() and item.slot == "weapon" and role >= 0:
		var melee := bool(base(item).get("melee", false))
		if role == 1:
			sc *= 1.4 if melee else 0.8
		elif melee:
			sc *= 0.5
	return sc


## best stash item for a slot that beats what's equipped
func best_for(slot: String, current: Dictionary, role: int = -1) -> Dictionary:
	var best := {}
	var best_score := role_score(current, role)
	for it in stash():
		if it.slot == slot and role_score(it, role) > best_score:
			best = it
			best_score = role_score(it, role)
	return best


## MV-547: one survivor, stash only; never borrow another survivor's or the vehicle's gear.
func auto_equip_dweller(did: int) -> int:
	if not Features.on("individual_auto_equip"):
		return 0
	var d := Game.dweller_by_id(did)
	if d.is_empty():
		return 0
	var role := Game.squad_role(d)
	var n := 0
	for slot in HERO_SLOTS:
		var best := best_for(slot, equipped_on(d, slot), role)
		if not best.is_empty() and equip_from_stash(int(best.uid), d):
			n += 1
	return n


func auto_equip_squad() -> int:
	var n := 0
	for role in Game.s.squad.size():
		var did := int(Game.s.squad[role])
		if did < 0:
			continue
		var d := Game.dweller_by_id(did)
		for slot in HERO_SLOTS:
			var b := best_for(slot, equipped_on(d, slot), role)
			if not b.is_empty() and equip_from_stash(int(b.uid), d):
				n += 1
	for slot in VAN_SLOTS:
		if slot == "engine":
			continue     # an engine is a trade-off (noise / heat / fuel), picked in the engine menu
		var b2 := best_for(slot, van_equipped(slot))
		if not b2.is_empty() and equip_from_stash(int(b2.uid)):
			n += 1
	return n
