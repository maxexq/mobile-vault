class_name GearSets
extends RefCounted
## MV-767 gear sets v1 (design MV-689, Gear Sets v1 artifact): 5 early-game sets of 4 pieces in the 6 hero slots, so
## 4+2 / 2+2+2 / 3+3 builds work. A set's bonus is the same at every rarity; 2 / 3 / 4 pieces worn by one crew member
## switch on its 2 / 3 / 4 lines (every line keeps the lower ones).
##   tinker   armor/helmet/gadget/backpack   room work: room output, room stat, Overtime
##   hunter   weapon/helmet/gadget/boots     damage / crit, Mark (every 5th shot crits, kill = attack speed)
##   titan    weapon/armor/helmet/gadget     boss: boss/elite damage, Armor break, Giant slayer
##   bulwark  armor/helmet/boots/backpack    tank: HP, DEF + melee reflect, Last stand
##   scav     weapon/gadget/boots/backpack   loot: supplies, drops + scrap, Lucky haul
## Pieces are ordinary Loot items (Loot.BASES "set_<set>_<slot>", "set": <set>) that never drop from the normal pool:
## each set drops from its own source (roll()), 15 % of that source's drops (tune sets.drop_pct) with a pity counter
## (sets.pity drops without one = the next is a set piece). Salvaging a set piece gives set parts of its set;
## sets.craft_cost parts craft a missing piece (craft_missing). Icons: 32 px PixelLab art in assets/gear64/icons.png
## (tools/gear64_import.py), shown through IconTex like icons v2.
## Switch gear_sets: off = no set drops, no bonuses (pieces already owned stay plain items with their base stats).

const ICONS_PNG := "res://assets/gear64/icons.png"
const DROP_PCT := 15.0
const PITY := 25.0
const CRAFT_COST := 30.0

const SETS := {
	"tinker": {"en": "TINKER CREW", "th": "ชุดช่างประจำรถ", "col": Color("e0a526"), "role": "งานในห้อง",
		"src": "ทำงานในห้องจนงานคราฟต์เสร็จ (ทุกห้อง)",
		"slots": ["armor", "helmet", "gadget", "backpack"],
		"bonus": ["ห้องที่ผู้สวมทำงานอยู่ ผลผลิต +10%", "ผู้สวมนับเป็นสเตตัสห้อง +3", "Overtime: ทำงานครบ 5 นาที ห้องผลิตโบนัสเท่าผลผลิต 1 นาที และงานคราฟต์ในห้องนั้นเร็วขึ้น 15%"]},
	"hunter": {"en": "RAIDER HUNTER", "th": "ชุดนักล่าโจร", "col": Color("c4453a"), "role": "ดาเมจ",
		"src": "ดรอปจากศัตรูปกติในคลื่น",
		"slots": ["weapon", "helmet", "gadget", "boots"],
		"bonus": ["ดาเมจ +10%", "โอกาสคริติคอล +6%, ดาเมจคริติคอล +20%", "Mark: ทุกการโจมตีครั้งที่ 5 คริติคอลแน่นอน, ฆ่าศัตรูได้ความเร็วโจมตี +5% นาน 5 วิ (ซ้อน 3)"]},
	"titan": {"en": "TITAN BREAKER", "th": "ชุดล้มยักษ์", "col": Color("9d5cff"), "role": "ตีบอส",
		"src": "ดรอปเฉพาะบอสและ Warlord",
		"slots": ["weapon", "armor", "helmet", "gadget"],
		"bonus": ["ดาเมจใส่บอส / Elite +15%", "Armor break: ตีบอสแต่ละครั้งลดเกราะบอส 1% (ซ้อน 15)", "Giant slayer: บอสใช้ท่า ผู้สวมได้ความเร็วโจมตี +25% นาน 8 วิ และโดนดาเมจจากบอส -30%"]},
	"bulwark": {"en": "RUST BULWARK", "th": "ชุดกำแพงสนิม", "col": Color("4f86b8"), "role": "ป้องกัน / แทงก์",
		"src": "ตั้งรับคลื่นโจมตีรถ (raid) จนจบ",
		"slots": ["armor", "helmet", "boots", "backpack"],
		"bonus": ["พลังชีวิต +15%", "ป้องกัน +8, สะท้อนดาเมจระยะประชิด 10%", "Last stand: เลือดต่ำกว่า 30% ได้เกราะ 25% ของเลือดสูงสุด (1 ครั้ง/คลื่น) และศัตรูหันมาตีผู้สวมก่อน"]},
	"scav": {"en": "SCAVENGER", "th": "ชุดนักคุ้ยซาก", "col": Color("7d9a4a"), "role": "หาของ / เสบียง",
		"src": "ดรอปจาก Expedition",
		"slots": ["weapon", "gadget", "boots", "backpack"],
		"bonus": ["หาเสบียงได้ +10%", "โอกาสดรอปของ +8%, เศษเหล็กจากศัตรู +10%", "Lucky haul: Expedition กลับเร็วขึ้น 20% และได้ของเพิ่ม 1 ชิ้น, ดรอปนับ pity เซ็ต 2 เท่า"]},
}
const ORDER := ["tinker", "hunter", "titan", "bulwark", "scav"]
## the drop source of each set (roll(source))
const SOURCE := {"work": "tinker", "kill": "hunter", "boss": "titan", "raid": "bulwark", "expedition": "scav"}

static var _icons: Texture2D
static var _icon_cache := {}


static func on() -> bool:
	return Features.on("gear_sets")


static func set_of(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	return str(Loot.base(item).get("set", ""))


static func base_id(set_id: String, slot: String) -> String:
	return "set_%s_%s" % [set_id, slot]


static func color(set_id: String) -> Color:
	return SETS.get(set_id, {}).get("col", Color.WHITE)


## {set id: pieces worn} for one crew member
static func counts(d: Dictionary) -> Dictionary:
	var out := {}
	if d.is_empty():
		return out
	for slot in Loot.HERO_SLOTS:
		var s := set_of(Loot.equipped_on(d, slot))
		if s != "":
			out[s] = int(out.get(s, 0)) + 1
	return out


## pieces of set_id worn by d (0 while the switch is off, so every bonus check is one call)
static func worn(d: Dictionary, set_id: String) -> int:
	if not on():
		return 0
	return int(counts(d).get(set_id, 0))


static func has(d: Dictionary, set_id: String, n: int) -> bool:
	return worn(d, set_id) >= n


## the 2 / 3 / 4-piece stat lines, applied to Combat.hero_stats; the 4-piece specials only set flags, Combat reads them
static func apply_hero(st: Dictionary, d: Dictionary) -> void:
	if not on():
		return
	var c := counts(d)
	var n := int(c.get("hunter", 0))
	if n >= 2:
		st.dmg = float(st.dmg) * 1.10
	if n >= 3:
		st.crit = float(st.crit) + 6.0
		st.critd = float(st.critd) + 20.0
	if n >= 4:
		st.set_mark = true
	n = int(c.get("titan", 0))
	if n >= 2:
		st.set_boss_dmg = 0.15
	if n >= 3:
		st.set_armor_break = true
	if n >= 4:
		st.set_slayer = true
	n = int(c.get("bulwark", 0))
	if n >= 2:
		st.hp = float(st.hp) * 1.15
	if n >= 3:
		st.def = float(st.def) + 8.0
		st.set_reflect = 0.10
	if n >= 4:
		st.set_last_stand = true
	n = int(c.get("scav", 0))
	if n >= 2:
		st.supply = float(st.supply) + 10.0
	if n >= 3:
		st.loot = float(st.loot) + 8.0
		st.scrap = float(st.scrap) + 10.0
	if n >= 4:
		st.set_lucky = true


# ------------------------------------------------------------------ tinker (room work)
## production multiplier of a room: +10 % per worker wearing 2+ tinker pieces
static func room_mult(workers: Array) -> float:
	if not on():
		return 1.0
	var m := 1.0
	for d in workers:
		if has(d, "tinker", 2):
			m += 0.10
	return m


## room stat a worker adds on top of their own (3 tinker pieces)
static func room_stat_bonus(d: Dictionary) -> float:
	return 3.0 if has(d, "tinker", 3) else 0.0


## craft speed multiplier: x1.15 when a worker wears the full tinker set
static func craft_mult(workers: Array) -> float:
	for d in workers:
		if has(d, "tinker", 4):
			return 1.15
	return 1.0


## Overtime: whole minutes of the room's output earned as a bonus this step (every 5 minutes a full-set worker works)
static func overtime_minutes(workers: Array, dt: float) -> float:
	if not on():
		return 0.0
	var bonus := 0.0
	for d in workers:
		if not has(d, "tinker", 4):
			continue
		var t := float(d.get("set_ot", 0.0)) + dt
		while t >= 300.0:
			t -= 300.0
			bonus += 1.0
		d["set_ot"] = t
	return bonus


# ------------------------------------------------------------------ scav (expeditions)
static func team_lucky(team: Array) -> bool:
	for d in team:
		if d is Dictionary and has(d, "scav", 4):
			return true
	return false


# ------------------------------------------------------------------ drops
## set_pity: {set id: drops from its source without a set piece}
static func pity() -> Dictionary:
	if not (Game.s.get("set_pity") is Dictionary):
		Game.s["set_pity"] = {}
	return Game.s.set_pity


## parts: {set id: set parts}
static func parts() -> Dictionary:
	if not (Game.s.get("set_parts") is Dictionary):
		Game.s["set_parts"] = {}
	return Game.s.set_parts


static func parts_of(set_id: String) -> int:
	return int(parts().get(set_id, 0))


## one drop from a source ("work" / "kill" / "boss" / "raid" / "expedition"): a set piece of that source's set, or {}.
## Counts the set's pity; a crew member with the full scav set on the squad makes every drop count twice.
static func roll(source: String, ilvl: int, min_rar: int = 0, luck: float = 0.0) -> Dictionary:
	if not on() or not SOURCE.has(source) or Game.s.is_empty():
		return {}
	var sid: String = SOURCE[source]
	var p := pity()
	var need := int(Features.num("sets.pity", PITY))
	var hit := Loot.rng.randf() * 100.0 < Features.num("sets.drop_pct", DROP_PCT) or int(p.get(sid, 0)) + 1 >= need
	if not hit:
		p[sid] = int(p.get(sid, 0)) + (2 if squad_lucky() else 1)
		return {}
	p[sid] = 0
	var slots: Array = SETS[sid].slots
	var slot: String = slots[Loot.rng.randi() % slots.size()]
	var it := Loot.roll_item(slot, ilvl, Loot.drop_rarity(luck, min_rar), base_id(sid, slot))
	Trace.rec("loot", "set_drop", {"set": sid, "slot": slot, "rar": int(it.rar), "src": source})
	return it


static func squad_lucky() -> bool:
	for did in Game.s.get("squad", []):
		if int(did) >= 0 and has(Game.dweller_by_id(int(did)), "scav", 4):
			return true
	return false


## a set piece drop with its toast; returns whether it was kept
static func give(it: Dictionary) -> bool:
	if it.is_empty():
		return false
	var kept := Loot.add_to_stash(it)
	if kept:
		var s: Dictionary = SETS[set_of(it)]
		Game.toast.emit(Loc.t("ได้ชิ้นเซ็ต %s: %s") % [s.en, Loot.item_name(it)], "good")
		Game.gear_changed.emit()
	return kept


## parts a salvaged set piece gives
static func salvage_parts(item: Dictionary) -> int:
	return 3 + 2 * int(item.get("rar", 0))


static func on_salvage(item: Dictionary) -> void:
	var sid := set_of(item)
	if sid == "" or Game.s.is_empty():
		return
	parts()[sid] = parts_of(sid) + salvage_parts(item)


## every piece of the set the player has (stash + worn by anyone): {slot: true}
static func owned(set_id: String) -> Dictionary:
	var out := {}
	var all: Array = (Game.s.get("gear", []) as Array).duplicate()
	for d in Game.s.get("dwellers", []):
		for slot in Loot.HERO_SLOTS:
			all.append(Loot.equipped_on(d, slot))
	for it in all:
		if it is Dictionary and set_of(it) == set_id:
			out[str(it.slot)] = true
	return out


static func craft_cost() -> int:
	return int(Features.num("sets.craft_cost", CRAFT_COST))


static func can_craft(set_id: String) -> bool:
	return on() and SETS.has(set_id) and parts_of(set_id) >= craft_cost() and Loot.stash().size() < Loot.STASH_CAP


## spend the parts on a piece the player doesn't have yet (any piece once the set is complete), uncommon or better
static func craft_missing(set_id: String) -> Dictionary:
	if not can_craft(set_id):
		return {}
	var have := owned(set_id)
	var miss: Array = (SETS[set_id].slots as Array).filter(func(s): return not have.has(s))
	if miss.is_empty():
		miss = SETS[set_id].slots
	var slot: String = miss[Loot.rng.randi() % miss.size()]
	parts()[set_id] = parts_of(set_id) - craft_cost()
	var it := Loot.roll_item(slot, Combat.enemy_level(), Loot.roll_rarity(0.0, 1), base_id(set_id, slot))
	Loot.stash().append(it)
	Game.gear_changed.emit()
	Game.resources_changed.emit()
	return it


# ------------------------------------------------------------------ art
## the 32 px icon of a set piece as an IconTex (reports 16x16 like icons v2, draws all 32 px)
static func icon(piece: String) -> Texture2D:
	if _icon_cache.has(piece):
		return _icon_cache[piece]
	var i := ICON_ORDER.find(piece)
	if i < 0:
		return null
	if _icons == null:
		_icons = load(ICONS_PNG)
	var at := AtlasTexture.new()
	at.atlas = _icons
	at.region = Rect2(32 * i, 0, 32, 32)
	at.filter_clip = true
	var t := IconTex.new(at)
	_icon_cache[piece] = t
	return t


## order of assets/gear64/icons.png (tools/gear64_import.py = designs/gear-sets/build.py PICKS)
const ICON_ORDER := ["tinker_armor", "tinker_helmet", "tinker_gadget", "tinker_backpack",
	"hunter_weapon", "hunter_helmet", "hunter_gadget", "hunter_boots",
	"titan_weapon", "titan_armor", "titan_helmet", "titan_gadget",
	"bulwark_armor", "bulwark_helmet", "bulwark_boots", "bulwark_backpack",
	"scav_weapon", "scav_gadget", "scav_boots", "scav_backpack"]


## one line per bonus tier for the UI: [[pieces, text, active], ...]
static func bonus_rows(set_id: String, worn_n: int) -> Array:
	var out := []
	var b: Array = SETS[set_id].bonus
	for i in b.size():
		out.append([i + 2, Loc.t(b[i]), on() and worn_n >= i + 2])
	return out
