class_name LoreCrew
extends RefCounted
## MV-778: every crew member is a fixed lore character (switch lore_crew). Parames 2026-11-12: "no random people,
## follow each character's lore". The cast is the ref v3 crew that has in-game art (V3Art.CREW_IDS + Mali and PIM-3):
## each has one name, role, stats, traits (Crew.FIXED), bio + lines (Lore.BIOS / LINES_PERSONAL) and look (the v3
## character of the same id; `variant` = the old 14x20 sprite for the classic view). Nobody is rolled: the starting
## crew is fixed and every recruit is the next character in lore order who is not on board yet. Someone who died
## only comes back when everybody else is already aboard (the cast is small). A full cast = no recruit (offer_recruit
## returns {} and Game.recruit_fail says why). Old saves: the crew are renamed into the cast once (migrate).
## Dr. Ren: tune lore_crew.ren_start (0 = the guide/story voice, not a crew body; 1 = a 6th crew member in the cab at
## the start; 2 = takes Clara's starting slot and Clara joins first).

## id -> character. stats as they board (level 1 + lap like any recruit); act = when the lore brings them in
const CAST := {
	"ren": {"name": "หมอเร็น", "role": "ผู้เขียน TRIAGE-9 · เจ้าของรถพยาบาล", "str": 3, "int": 8, "agi": 4, "variant": "dw_medic_black", "act": 0},
	"clara": {"name": "พยาบาลคลารา", "role": "พยาบาลสนาม", "str": 3, "int": 7, "agi": 4, "variant": "dw_medic_red", "act": 1},
	"bit": {"name": "บิต", "role": "เด็กช่างทรานสปอนเดอร์", "str": 6, "int": 4, "agi": 3, "variant": "dw_jumpsuit_brown", "act": 1, "job": "builder"},
	"wan": {"name": "ป้าวรรณ", "role": "อดีตนายทะเบียน AURORA", "str": 3, "int": 4, "agi": 7, "variant": "dw_chef_gray", "act": 2},
	"tham": {"name": "ธรรม", "role": "ผู้หนีจากลัทธิไฟ · คนนำทางทุนดรา", "str": 4, "int": 3, "agi": 7, "variant": "dw_scav_black", "act": 2},
	"fah": {"name": "ฟ้า", "role": "นักบังคับโดรนหนีทัพ", "str": 7, "int": 3, "agi": 4, "variant": "dw_army_black", "act": 2},
	"ploy": {"name": "ยายพลอย", "role": "นักทำแผนที่เงา", "str": 2, "int": 6, "agi": 5, "variant": "dw_scav_gray", "act": 1},
	"noi": {"name": "น้อย", "role": "เด็กหนีพร้อมปลอกคอลงทะเบียน", "str": 4, "int": 3, "agi": 7, "variant": "dw_raider_blonde", "act": 2},
	"mali": {"name": "มะลิ", "role": "อดีตผู้ดูแลสัตว์สวนสัตว์", "str": 5, "int": 3, "agi": 6, "variant": "dw_scav_brown", "act": 2},
	"pim": {"name": "พิม", "role": "หุ่นพยาบาล AURORA (PIM-3)", "str": 5, "int": 7, "agi": 2, "variant": "dw_medic_gray", "act": 2},
	"sorn": {"name": "กัปตันศร", "role": "อดีตนักบินกระสวย HELIOS", "str": 4, "int": 6, "agi": 4, "variant": "dw_army_gray", "act": 3},
	"lin": {"name": "หลิน", "role": "นักร้องเลียนเสียง", "str": 2, "int": 5, "agi": 6, "variant": "dw_jumpsuit_red", "act": 3},
	"krai": {"name": "ไกร", "role": "แรงงานซ่อมกระจกที่หนีลงมาได้", "str": 8, "int": 3, "agi": 3, "variant": "dw_builder_brown", "act": 3},
}
## who joins next, in story order (Act 1 -> 3). The starting crew are skipped because they are already aboard.
const ORDER := ["ren", "clara", "bit", "ploy", "wan", "tham", "fah", "noi", "mali", "pim", "sorn", "lin", "krai"]
## the starting crew in the old five slots (same stats in the same jobs as Mark / Leo / Ton / Bob / Clara)
const START := {"loader": "fah", "gunner": "tham", "cab": "bit", "kitchen": "wan", "water": "clara"}
## old lore crew (and the MV-170 roster's best-stat fallback) -> who they become when an old save is migrated
const OLD_TO_NEW := {"mark": "fah", "leo": "tham", "ton": "bit", "bob": "wan", "clara": "clara", "bruno": "krai"}
const REN_START := 0     # tune lore_crew.ren_start


static func on() -> bool:
	return Features.on("lore_crew")


static func ren_start() -> int:
	return clampi(int(round(Features.num("lore_crew.ren_start", REN_START))), 0, 2)


## Ren is a crew member (can be recruited / is aboard) unless he is only the guide
static func ren_in_cast() -> bool:
	return ren_start() > 0


static func is_cast(id: String) -> bool:
	return CAST.has(id) and (id != "ren" or ren_in_cast())


## the cast id of a dweller ("" = not a lore character)
static func id_of(d: Dictionary) -> String:
	var k := str(d.get("lore", ""))
	return k if CAST.has(k) else ""


static func name_of(id: String) -> String:
	return str(CAST.get(id, {}).get("name", id))


static func aboard() -> Dictionary:
	var out := {}
	for d in Game.s.dwellers:
		var k := id_of(d)
		if k != "":
			out[k] = true
	return out


static func fallen() -> Dictionary:
	var out := {}
	for m in Game.s.get("memorial", []):
		var k := str(m.get("lore", ""))
		if k == "":
			for id in CAST:
				if str(CAST[id].name) == str(m.get("name", "")):
					k = id
		if k != "":
			out[k] = true
	return out


## the next character to join, "" = the whole cast is aboard. Story order; the fallen only when nobody else is left.
static func next_id() -> String:
	var on_board := aboard()
	var dead := fallen()
	for pass_ in 2:
		for id in ORDER:
			if not is_cast(id) or on_board.has(id):
				continue
			if pass_ == 0 and dead.has(id):
				continue
			return id
	return ""


## add one cast member to the vehicle (the dweller fields the lore fixes); room/lvl from p
static func spawn(id: String, p: Dictionary = {}) -> Dictionary:
	var c: Dictionary = CAST[id]
	var q := {"name": c.name, "lore": id, "variant": c.variant, "str": c.str, "int": c.int, "agi": c.agi,
		"role": str(c.get("job", ""))}
	q.merge(p, true)
	return Game._add_dweller(q)


## the starting crew of a new game (replaces Mark / Leo / Ton / Bob / Clara). Returns {loader, gunner} for the squad.
static func start_crew(water_slot: int) -> Dictionary:
	var ids := START.duplicate()
	if ren_start() == 2:
		ids.water = "ren"
	var loader := spawn(ids.loader, {"room": -1, "lvl": 3})
	var gunner := spawn(ids.gunner, {"room": -1, "lvl": 2})
	spawn(ids.cab, {"room": Data.CAB_SLOT, "lvl": 1})
	spawn(ids.kitchen, {"room": 1, "lvl": 2})
	spawn(ids.water, {"room": water_slot, "lvl": 2})
	if ren_start() == 1:
		spawn("ren", {"room": -1, "lvl": 2})
	return {"loader": loader, "gunner": gunner}


## best stat of a cast entry (decides which room a recruit walks to, like any recruit)
static func best_stat(id: String) -> String:
	var c: Dictionary = CAST[id]
	var best := "str"
	for st in ["str", "int", "agi"]:
		if int(c[st]) > int(c[best]):
			best = st
	return best


## old saves: turn every crew member into a cast character once (name, look, traits; stats, level, gear and skills
## stay theirs). Known old lore crew map by OLD_TO_NEW, everybody else gets the next free character whose best
## stat matches theirs, then any free one. People beyond the cast size keep their old identity. Returns how many
## were renamed. `force` = run again even if this save was migrated already (GOD MODE).
static func migrate(force: bool = false) -> int:
	if not on() or (int(Game.s.get("lore_crew", 0)) >= 1 and not force):
		return 0
	Game.s["lore_crew"] = 1
	var taken := {}
	var todo := []
	for d in Game.s.dwellers:
		var k := id_of(d)
		if k != "" and is_cast(k) and not taken.has(k) and str(d.name) == name_of(k):
			taken[k] = true      # already a cast member with the right name
			continue
		todo.append(d)
	var left := []
	for d in todo:
		var want := str(OLD_TO_NEW.get(str(d.get("lore", "")), ""))
		if want != "" and not taken.has(want) and is_cast(want):
			_become(d, want)
			taken[want] = true
		else:
			left.append(d)
	var n := todo.size() - left.size()
	for d in left:
		var pick := ""
		var best := _best_of(d)
		for pass_ in 2:
			for id in ORDER:
				if is_cast(id) and not taken.has(id) and (pass_ == 1 or best_stat(id) == best):
					pick = id
					break
			if pick != "":
				break
		if pick == "":
			continue
		_become(d, pick)
		taken[pick] = true
		n += 1
	if n > 0:
		Game.dwellers_changed.emit()
	return n


static func _best_of(d: Dictionary) -> String:
	var best := "str"
	for st in ["str", "int", "agi"]:
		if float(d.get(st, 0)) > float(d.get(best, 0)):
			best = st
	return best


static func _become(d: Dictionary, id: String) -> void:
	var c: Dictionary = CAST[id]
	d.name = c.name
	d.lore = id
	d.variant = c.variant
	d.traits = (Crew.FIXED.get(id, []) as Array).duplicate()
	if str(c.get("job", "")) == "builder":
		d.role = "builder"
