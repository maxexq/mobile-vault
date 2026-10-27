extends Node
## Idle auto-battle fought from the moving Mobile Vault.
## Enemies chase the van from behind (the right side of the screen) in waves. Threat (threat.gd) decides
## when a raid of waves comes; Settings "pacing" = classic keeps the old back-to-back waves.
## Squad (3 roles) + vault turret/spikes fight automatically; kills give XP, scrap and gear drops.
## Every 10th wave is a boss; each biome ends with a checkpoint WARLORD that must be beaten to move on.
## Pure simulation: the world view (combat_view.gd) only listens to the signals below.

signal wave_changed
signal enemy_spawned(e: Dictionary)
signal enemy_removed(id: int, killed: bool)
signal hit(kind: String, id: int, amount: float, crit: bool)        # kind: enemy | hero | van | heal
signal shot(from_kind: String, from_id: int, to_kind: String, to_id: int, style: String)
signal skill_cast(slot: int, skill: String)
signal loot_dropped(item: Dictionary, at: Vector2)
signal squad_wiped
signal heroes_changed
signal supply_found(kind: String, amount: float, at: Vector2)
signal boss_event(kind: String, e: Dictionary)   # enrage | armor_break | summon | burrow | erupt | explode | acid | solar
signal tagged_in(slot: int, did: int, out_did: int)   # the roof-deck reserve jumped in for a fallen defender
signal entrance(e: Dictionary)   # MV-387: a boss / warlord / elite just spawned (switch boss_intro)

const STEP := 0.1
## enemies scale a little faster than gear (Loot.ILVL_GROWTH = 1.12) -> pushing hits a wall,
## rarity / enhancement / levels push it further (Taskbar-Hero style farm vs push)
const HP_GROWTH := 1.17
const DMG_GROWTH := 1.145
const ROLES := [
	{"id": "gunner", "th": "มือปืนหลังคา", "en": "ROOF GUNNER", "stat": "agi", "pos": Vector2(300, 14), "unlock": 1,
		"skill": "ระดมยิง", "skill_desc": "ทุก 10 วิ ยิงรัว 5 นัด (70% ดาเมจ) ใส่ศัตรูแบบสุ่ม", "cd": 10.0},
	{"id": "bruiser", "th": "นักสู้ท้ายรถ", "en": "REAR BRUISER", "stat": "str", "pos": Vector2(346, 136), "unlock": 1,
		"skill": "กระแทกพื้น", "skill_desc": "ทุก 9 วิ ฟาดพื้น 150% ดาเมจใส่ศัตรูประชิด + มึน 1.5 วิ", "cd": 9.0},
	{"id": "medic", "th": "แพทย์สนาม", "en": "FIELD MEDIC", "stat": "int", "pos": Vector2(276, 14), "unlock": 2,
		"skill": "ปฐมพยาบาล", "skill_desc": "ทุก 12 วิ ฟื้นเลือดทุกคน 30% + ซ่อมตัวถัง · รักษาคนเจ็บหนักสุดทุก 3.5 วิ", "cd": 12.0},
]
const DECK_X := 350.0
const SPAWN_X := 610.0
const RANGE_SCALE := 0.75   # keeps the shoot-out inside the camera view
const MIN_ROOF_RANGE := 195.0
const BRUISER_THROW := 160.0
const GROUND_Y := 168.0
const MELEE_STOP := 368.0
const VAN_REAR := 354.0
const TURRET_POS := Vector2(330, 128)

## mobs (stats at level 1). sprite: atlas prefix (en_x -> en_x_0/1) or dweller sheet
const MOBS := {
	"rad_rat": {"th": "หนูกลายพันธุ์", "sprite": "en_rat", "hp": 16.0, "dmg": 3.0, "spd": 40.0, "cd": 1.0, "kind": "melee"},
	"scav_raider": {"th": "โจรเก็บของเก่า", "sprite": "dw_raider_black", "hp": 28.0, "dmg": 4.0, "spd": 26.0, "cd": 1.6, "kind": "ranged", "range": 130.0},
	"rust_drone": {"th": "โดรนสนิม", "sprite": "en_drone", "hp": 15.0, "dmg": 3.5, "spd": 32.0, "cd": 1.4, "kind": "air", "range": 110.0},
	"scorpion": {"th": "แมงป่องยักษ์", "sprite": "en_scorpion", "hp": 26.0, "dmg": 4.5, "spd": 32.0, "cd": 1.1, "kind": "melee"},
	"sand_raider": {"th": "โจรทะเลทราย", "sprite": "dw_scav_red", "hp": 30.0, "dmg": 5.0, "spd": 26.0, "cd": 1.5, "kind": "ranged", "range": 140.0},
	"vulture": {"th": "แร้งกลายพันธุ์", "sprite": "en_vulture", "hp": 18.0, "dmg": 4.5, "spd": 44.0, "cd": 1.2, "kind": "air", "range": 50.0},
	"rad_wolf": {"th": "หมาป่ารังสี", "sprite": "en_wolf", "hp": 24.0, "dmg": 5.0, "spd": 50.0, "cd": 0.9, "kind": "melee"},
	"mutant_bug": {"th": "แมลงกลายพันธุ์", "sprite": "en_bug", "hp": 18.0, "dmg": 3.5, "spd": 36.0, "cd": 0.8, "kind": "melee"},
	"vine_crawler": {"th": "ซอมบี้เถาวัลย์", "sprite": "en_crawler", "hp": 40.0, "dmg": 5.0, "spd": 18.0, "cd": 1.7, "kind": "ranged", "range": 120.0},
	"frost_wolf": {"th": "หมาป่าน้ำแข็ง", "sprite": "en_wolf", "tint": "a9cde0", "hp": 28.0, "dmg": 6.0, "spd": 50.0, "cd": 0.9, "kind": "melee"},
	"ice_raider": {"th": "โจรน้ำแข็ง", "sprite": "dw_raider_gray", "tint": "b8d8f0", "hp": 34.0, "dmg": 6.0, "spd": 24.0, "cd": 1.5, "kind": "ranged", "range": 140.0},
	"yeti": {"th": "เยติกลายพันธุ์", "sprite": "en_yeti", "hp": 60.0, "dmg": 8.0, "spd": 20.0, "cd": 1.6, "kind": "melee"},
	"toxic_toad": {"th": "คางคกพิษ", "sprite": "en_toad", "hp": 34.0, "dmg": 6.0, "spd": 30.0, "cd": 1.1, "kind": "melee"},
	"mosquito": {"th": "ยุงยักษ์", "sprite": "en_mosquito", "hp": 16.0, "dmg": 5.0, "spd": 48.0, "cd": 0.8, "kind": "air", "range": 40.0},
	"bog_walker": {"th": "ซากเดินหนอง", "sprite": "en_bogwalker", "hp": 46.0, "dmg": 6.0, "spd": 18.0, "cd": 1.6, "kind": "ranged", "range": 120.0},
	"gang_scav": {"th": "แก๊งเมืองร้าง", "sprite": "dw_raider_red", "hp": 38.0, "dmg": 7.0, "spd": 26.0, "cd": 1.3, "kind": "ranged", "range": 150.0},
	"sentry_bot": {"th": "หุ่นยามติดปืน", "sprite": "en_sentry", "hp": 52.0, "dmg": 7.0, "spd": 20.0, "cd": 1.4, "kind": "ranged", "range": 160.0},
	"mutant_ape": {"th": "ลิงกลายพันธุ์", "sprite": "en_ape", "hp": 70.0, "dmg": 10.0, "spd": 34.0, "cd": 1.3, "kind": "melee"},
	# ---- mutations: appear further down the road and force a different loadout
	"runner": {"th": "ซอมบี้วิ่งเร็ว", "sprite": "en_runner", "hp": 18.0, "dmg": 4.0, "spd": 72.0, "cd": 0.7, "kind": "melee", "mutant": true},
	"spitter": {"th": "ซอมบี้พ่นกรด", "sprite": "en_spitter", "hp": 30.0, "dmg": 4.0, "spd": 22.0, "cd": 1.8, "kind": "ranged", "range": 150.0, "mech": ["acid"], "mutant": true},
	"bloater": {"th": "ซอมบี้บวมระเบิด", "sprite": "en_bloater", "hp": 55.0, "dmg": 3.0, "spd": 16.0, "cd": 2.0, "kind": "melee", "mech": ["explode"], "mutant": true},
	"screecher": {"th": "ซอมบี้ปีกหนัง", "sprite": "en_screecher", "hp": 22.0, "dmg": 4.0, "spd": 46.0, "cd": 1.2, "kind": "air", "range": 60.0, "mech": ["solar"], "mutant": true},
	"brute": {"th": "ซอมบี้เกราะกระดูก", "sprite": "en_brute", "hp": 90.0, "dmg": 9.0, "spd": 18.0, "cd": 1.7, "kind": "melee", "mech": ["armor"], "mutant": true},
}
## mutations that can replace normal mobs, per biome (chance grows with distance / laps)
const MUTANT_POOL := {
	"industrial": ["runner"], "desert": ["runner", "spitter"], "forest": ["spitter", "screecher", "runner"],
	"swamp": ["spitter", "bloater", "screecher"], "tundra": ["brute", "screecher", "bloater"],
	"metro": ["runner", "spitter", "bloater", "screecher", "brute"],
}
const BIOME_MOBS := {
	"industrial": ["rad_rat", "rad_rat", "scav_raider", "rust_drone"],
	"desert": ["scorpion", "scorpion", "sand_raider", "vulture"],
	"forest": ["rad_wolf", "mutant_bug", "mutant_bug", "vine_crawler"],
	"tundra": ["frost_wolf", "ice_raider", "yeti", "frost_wolf"],
	"swamp": ["toxic_toad", "mosquito", "bog_walker", "toxic_toad"],
	"metro": ["gang_scav", "sentry_bot", "mutant_ape", "gang_scav"],
}
## bosses have their own native-size sprites (no upscaling -> true pixel art)
## mech: enrage (<30% hp faster & harder) | armor (-50% dmg taken above 60% hp) | summon (calls adds) |
##       acid (corrodes the hull & armour) | solar (dives at the solar panels) | burrow (dives underground,
##       erupts under the rear deck) | revive (raises the fallen) | explode (blows up when it dies)
const BOSSES := {
	"industrial": {"th": "โกเลมขยะ", "en": "JUNK GOLEM", "base": "yeti", "sprite": "boss_golem", "kind": "melee", "mech": ["armor"]},
	"desert": {"th": "ราชันแมงป่อง", "en": "SCORPION KING", "base": "scorpion", "sprite": "boss_scorpion", "kind": "melee", "mech": ["enrage", "acid"]},
	"forest": {"th": "จ่าฝูงหมาป่ารังสี", "en": "ALPHA RAD-WOLF", "base": "rad_wolf", "sprite": "boss_wolf", "kind": "melee", "mech": ["summon", "enrage"]},
	"swamp": {"th": "ราชินีหนองพิษ", "en": "BOG QUEEN", "base": "bog_walker", "sprite": "boss_bogqueen", "kind": "ranged", "mech": ["acid", "summon"]},
	"tundra": {"th": "ไททันน้ำแข็ง", "en": "FROST TITAN", "base": "yeti", "sprite": "boss_titan", "kind": "melee", "mech": ["armor", "enrage"]},
	"metro": {"th": "ผู้คุมจักรกล OVERSEER", "en": "OVERSEER MECH", "base": "sentry_bot", "sprite": "boss_overseer", "kind": "ranged", "mech": ["armor", "summon", "enrage"]},
}
## roaming mutant bosses for the every-10th-wave fights (rotates; harder ones join further down the road)
const WAVE_BOSSES := {
	"acid_matron": {"th": "แม่พันธุ์กรด", "en": "ACID MATRON", "base": "bog_walker", "sprite": "boss_acid", "kind": "ranged", "mech": ["acid", "enrage"], "from": 0},
	"bloat_king": {"th": "ราชาบวมเน่า", "en": "BLOAT KING", "base": "yeti", "sprite": "boss_bloat", "kind": "melee", "mech": ["summon", "explode"], "from": 0},
	"sky_harpy": {"th": "ฮาร์ปี้ปีกหนัง", "en": "SKIN-WING HARPY", "base": "vulture", "sprite": "boss_harpy", "kind": "air", "mech": ["solar", "enrage"], "from": 1},
	"bone_hulk": {"th": "ยักษ์เกราะกระดูก", "en": "BONE HULK", "base": "mutant_ape", "sprite": "boss_hulk", "kind": "melee", "mech": ["armor", "enrage"], "from": 1},
	"drill_worm": {"th": "หนอนเจาะถนน", "en": "ROAD DRILLER", "base": "yeti", "sprite": "boss_worm", "kind": "melee", "mech": ["burrow"], "from": 2},
	"screamer": {"th": "ผู้กรีดร้อง", "en": "THE SCREAMER", "base": "vine_crawler", "sprite": "boss_screamer", "kind": "ranged", "mech": ["summon", "enrage"], "from": 2},
	"necro_priest": {"th": "นักบวชปลุกศพ", "en": "NECRO PRIEST", "base": "bog_walker", "sprite": "boss_priest", "kind": "ranged", "mech": ["revive", "acid"], "from": 3},
	"mech_spider": {"th": "แมงมุมจักรกล", "en": "MECH SPIDER", "base": "sentry_bot", "sprite": "boss_spider", "kind": "ranged", "mech": ["armor", "summon"], "from": 4},
}

var enemies: Array = []          # runtime enemy dicts
var heroes: Array = []           # runtime hero dicts, index = role slot
var turret := {"t": 0.0}
var wave_active := false
var wave_is_boss := false
var wave_is_warlord := false
var spawn_queue: Array = []
var gap_t := 2.0
var wave_t := 0.0
const WAVE_TIMEOUT := 90.0
const WARLORD_TIMEOUT := 120.0
var warlord_cd := 0.0
var _acc := 0.0
var _next_id := 1
var _kill_window: Array = []     # timestamps (sim seconds) of recent kills for kills/min
var _clock := 0.0
var rng := RandomNumberGenerator.new()
var dps_meter := 0.0
var _dmg_window: Array = []
## roof rest deck (Mods "roof_deck", reserve = Game.deck_dweller()): the reserve jumps in for the first
## squad member who falls in a wave and holds that slot until the wave ends (then the line-up is restored)
const DECK_TAG_DELAY := [0.0, 6.0, 4.0, 2.5]    # seconds after someone falls, per deck level
const DECK_TAG_HP := [0.0, 0.6, 0.8, 1.0]       # HP the reserve comes in with
const DECK_RESERVE_XP := 0.4                    # share of kill XP the reserve picks up while watching
var sub := {}          # role slot -> reserve dweller id (this wave only)
var sub_out := {}      # role slot -> the fallen defender resting on the deck
var tag_t := -1.0


func _ready() -> void:
	rng.randomize()
	Game.biome_changed.connect(func(_i, _inst): reset_wave(1))
	Game.squad_changed.connect(func():
		_end_subs(false)
		rebuild_heroes())
	(func(): Mods.mods_changed.connect(rebuild_heroes)).call_deferred()
	Game.gear_changed.connect(rebuild_heroes)
	Game.dwellers_changed.connect(rebuild_heroes)
	Game.game_started.connect(func():
		_clear_enemies()
		_end_subs(false)
		rebuild_heroes()
		gap_t = 2.0)


# =================================================================== state helpers
func cs() -> Dictionary:
	return Game.s.combat


func wave() -> int:
	return int(cs().wave)


func slots_unlocked() -> int:
	var n := 0
	for r in ROLES:
		if int(Game.s.vault_level) >= int(r.unlock):
			n += 1
	return n


func biome_id() -> String:
	return Data.biome(Game.s.biome).id


const BIOME_LEVEL_STEP := 20
const LAP_LEVEL_STEP := 80
const WARLORD_OFFSET := 28


func biome_base_level() -> int:
	return 1 + int(Game.s.biome) * BIOME_LEVEL_STEP + int(Game.s.lap) * LAP_LEVEL_STEP


func enemy_level(w: int = -1) -> int:
	if w < 0:
		w = wave()
	return biome_base_level() + (w - 1) / 2


func warlord_level() -> int:
	return biome_base_level() + WARLORD_OFFSET


## armour value that halves damage at a given enemy level (grows like gear does)
func def_k(lvl: float) -> float:
	return 12.0 * pow(Loot.ILVL_GROWTH, lvl - 1.0)


func boss_beaten(biome: int) -> bool:
	return bool(cs().boss_beaten.get(str(biome), false))


func is_boss_wave(w: int) -> bool:
	return w % 10 == 0


func active() -> bool:
	return Game.started and Game.closeup_slot < 0 and Game.active_event == "" and _has_squad()


func _has_squad() -> bool:
	for did in Game.s.squad:
		if int(did) >= 0:
			return true
	return false


func kills_per_min() -> float:
	return float(cs().get("kpm", 0.0))


# =================================================================== hero stats
func hero_stats(d: Dictionary, role_idx: int) -> Dictionary:
	var role: Dictionary = ROLES[role_idx]
	var main := float(d.get(role.stat, 5))
	var lvl := float(d.lvl)
	var w := Loot.equipped_on(d, "weapon")
	var a := Loot.equipped_on(d, "armor")
	var g := Loot.equipped_on(d, "gadget")
	var hm := Loot.equipped_on(d, "helmet")
	var bt := Loot.equipped_on(d, "boots")
	var bp := Loot.equipped_on(d, "backpack")
	var items := [w, a, g, hm, bt, bp]
	var st := {"dmg": 3.0, "aspd": 1.0, "range": 140.0, "splash": 1, "melee": false}
	if not w.is_empty():
		var b := Loot.base(w)
		st.dmg = Loot.base_stat(w, "dmg")
		st.aspd = float(b.get("aspd", 1.0))
		st.range = float(b.get("range", 180)) * RANGE_SCALE
		st.splash = int(b.get("splash", 1))
		st.melee = bool(b.get("melee", false))
	if role.id == "bruiser":
		st.range = 46.0
		st.dmg *= 1.4 if st.melee else 1.0
	elif st.melee:
		st.dmg *= 0.6
	if role.id != "bruiser":
		st.range = maxf(st.range, MIN_ROOF_RANGE)   # roof crew can always reach anything shooting at the van
	st.dmg *= (1.0 + 0.06 * main + 0.015 * (lvl - 1.0)) * (1.0 + Loot.sum_key(items, "dmg") / 100.0)
	var aspd_pct := Loot.sum_key(items, "aspd") + (float(Loot.base(g).get("aspd_pct", 0.0)) if not g.is_empty() else 0.0)
	st.aspd *= 1.0 + aspd_pct / 100.0
	st.crit = 5.0 + float(d.agi) * 0.6 + Loot.sum_key(items, "crit") + Loot.base_stat(w, "crit") + Loot.base_stat(g, "crit") + Loot.base_stat(hm, "crit")
	st.critd = 150.0 + Loot.sum_key(items, "critd")
	st.hp = (70.0 + 6.0 * (lvl - 1.0) + 8.0 * float(d.str) + Loot.base_stat(a, "hp") + Loot.base_stat(hm, "hp") + Loot.base_stat(bt, "hp") + Loot.base_stat(bp, "hp") + Loot.sum_key(items, "hp")) * (1.5 if role.id == "bruiser" else 1.0)
	st.def = (Loot.base_stat(a, "def") + Loot.base_stat(hm, "def") + Loot.base_stat(bt, "def") + Loot.sum_key(items, "def") + float(d.str) * 0.4) * (1.3 if role.id == "bruiser" else 1.0)
	st.dodge = minf(45.0, float(d.agi) * 0.5 + Loot.base_stat(bt, "dodge") + Loot.sum_key(items, "dodge"))
	st.supply = Loot.base_stat(bp, "supply") + Loot.sum_key(items, "supply")
	st.regen = 0.3 + Loot.base_stat(g, "regen") + Loot.sum_key(items, "regen")
	st.lifesteal = Loot.sum_key(items, "lifesteal")
	st.loot = Loot.sum_key(items, "loot") + Loot.base_stat(g, "loot") + Loot.base_stat(bp, "loot")
	st.aspd *= 1.0 + Loot.base_stat(bt, "aspd_pct") / 100.0
	st.scrap = Loot.sum_key(items, "scrap")
	st.xp = Loot.sum_key(items, "xp")
	st.heal = (6.0 + float(d.int) * 2.2 + lvl) * (1.0 + 0.04 * float(d.int)) if role.id == "medic" else 0.0
	# --- traits & skill tree
	var brawl: bool = Crew.has(d, "brawler") and role.id == "bruiser"
	st.dmg *= (1.0 + Skills.val(d, "dmg")) * (1.2 if Crew.has(d, "sharpshooter") else 1.0) * (1.25 if brawl else 1.0)
	if Crew.is_infected(d):
		st.dmg *= 0.8
	st.crit += 10.0 if Crew.has(d, "sharpshooter") else 0.0
	st.hp *= (1.0 + Skills.val(d, "hp")) * (1.3 if Crew.has(d, "tough") else 1.0) * (1.25 if brawl else 1.0)
	st.aspd *= 1.0 + Skills.val(d, "aspd")
	st.dodge = minf(50.0, st.dodge + Skills.val(d, "dodge"))
	st.heal *= (1.25 if Crew.has(d, "healer") else 1.0) * (1.0 + Skills.val(d, "medic"))
	st.signature = Skills.rank(d, "c5") > 0
	st.dmg *= Modes.mul("hero_dmg")     # mutators (glass cannon)
	st.hp *= Modes.mul("hero_hp")
	_deck_cover(st, d, role_idx)
	st.dps = st.dmg * st.aspd * (1.0 + st.crit / 100.0 * (st.critd - 100.0) / 100.0) * (1.0 + 0.5 * (st.splash - 1))
	return st


## the roof crew (gunner + medic) fight from the roof deck: shade / sandbags / lookout
func _deck_cover(st: Dictionary, d: Dictionary, role_idx: int) -> void:
	var lv := Mods.level("roof_deck")
	if lv <= 0 or ROLES[role_idx].id == "bruiser" or Game.s.is_empty():
		return
	if Game.squad_role(d) != role_idx and not Game.is_deck(d):
		return
	st.regen = float(st.regen) + 0.3 * lv
	if lv >= 2:
		st.def = float(st.def) * 1.15
		st.dodge = minf(50.0, float(st.dodge) + 3.0)
	if lv >= 3:
		st.range = float(st.range) * 1.1
		st.crit = float(st.crit) + 5.0
	st.dps = st.dmg * st.aspd * (1.0 + st.crit / 100.0 * (st.critd - 100.0) / 100.0) * (1.0 + 0.5 * (st.splash - 1))


func van_stats() -> Dictionary:
	var t := Loot.van_equipped("turret")
	var p := Loot.van_equipped("plating")
	var e := Loot.van_equipped("engine")
	var k := Loot.van_equipped("spikes")
	var items := [t, p, e, k]
	var v := {"hull": 0.0, "def": 0.0, "speed": 0.0, "power": 0.0, "thorns": 0.0, "turret_dmg": 0.0, "turret_aspd": 0.0, "turret_range": 0.0, "turret_splash": 1, "loot": 0.0, "scrap": 0.0}
	v.hull = Loot.base_stat(p, "hull") + Loot.sum_key(items, "hull")
	v.def = Loot.base_stat(p, "def") + Loot.base_stat(k, "def") + Loot.sum_key(items, "def")
	v.speed = Loot.base_stat(e, "speed") + Loot.sum_key(items, "speed")
	v.power = Loot.base_stat(e, "power")
	v.thorns = Loot.base_stat(k, "thorns") + Loot.sum_key(items, "thorns")
	v.loot = Loot.sum_key(items, "loot")
	v.scrap = Loot.sum_key(items, "scrap")
	if not t.is_empty():
		var b := Loot.base(t)
		v.turret_dmg = Loot.base_stat(t, "dmg") * (1.0 + (Loot.sum_key(items, "turret") + Loot.sum_key([t], "dmg")) / 100.0)
		v.turret_aspd = float(b.get("aspd", 1.0)) * (1.0 + Loot.sum_key([t], "aspd") / 100.0)
		v.turret_range = float(b.get("range", 200)) * RANGE_SCALE
		v.turret_splash = int(b.get("splash", 1))
		v.aa = bool(b.get("aa", false))
	var ram := Mods.level("spike_ram")
	v.thorns = (v.thorns + 2.0 * ram * pow(1.12, maxf(0.0, enemy_level() - 1.0) * 0.5)) * (1.0 + 0.4 * ram)
	v.roof = [0.0, 0.4, 0.7, 1.0][clampi(Mods.level("roof_turret"), 0, 3)]
	if t.is_empty() and v.roof > 0.0:
		# a bare roof turret still plinks away
		v.turret_dmg = 4.0 * pow(1.12, enemy_level() - 1.0)
		v.turret_aspd = 1.2
		v.turret_range = 220.0 * RANGE_SCALE
		v.roof = 1.0
	if float(Game.s.get("corrode", 0.0)) > 0.0:
		v.def *= 0.6       # acid eats the armour
	v.turret_dps = v.turret_dmg * v.turret_aspd * (1.0 + 0.5 * (v.turret_splash - 1)) * (1.0 + (v.roof if not t.is_empty() else 0.0))
	return v


## single number used by random-event fights and exploring
func hero_power(d: Dictionary) -> float:
	var st := hero_stats(d, 1 if float(d.str) >= float(d.agi) else 0)
	return (st.dps * 0.9 + st.hp / 12.0 + st.def * 0.5) * (float(d.hp) / float(d.max_hp) * 0.5 + 0.5)


func squad_dps() -> float:
	var t := 0.0
	for i in heroes.size():
		var h: Dictionary = heroes[i]
		if not h.is_empty():
			t += float(h.st.dps)
	return t + float(van_stats().turret_dps)


func rebuild_heroes() -> void:
	if Game.s.is_empty():
		return
	var old := heroes
	heroes = []
	for i in ROLES.size():
		var did := slot_did(i)
		if did < 0 or i >= slots_unlocked():
			heroes.append({})
			continue
		var d := Game.dweller_by_id(did)
		if d.is_empty() or Game.is_away(d):
			heroes.append({})
			continue
		var st := hero_stats(d, i)
		var prev: Dictionary = old[i] if i < old.size() else {}
		var h := {"slot": i, "did": did, "st": st, "max": st.hp, "hp": st.hp, "atk_t": rng.randf_range(0.0, 0.5), "skill_t": float(ROLES[i].cd) * 0.6, "heal_t": 3.5, "alive": true, "sub": sub.has(i)}
		if not prev.is_empty() and int(prev.did) == did:
			h.hp = clampf(float(prev.hp) / maxf(1.0, float(prev.max)) * st.hp, 0.0, st.hp)
			h.alive = prev.alive
			h.atk_t = prev.atk_t
			h.skill_t = prev.skill_t
		heroes.append(h)
	heroes_changed.emit()


## who fights in a role slot right now (the deck reserve while subbing in)
func slot_did(i: int) -> int:
	if sub.has(i):
		return int(sub[i])
	return int(Game.s.squad[i]) if i < Game.s.squad.size() else -1


## the reserve can still come down this wave
func _tag_ready() -> bool:
	return wave_active and sub.is_empty() and not Game.deck_dweller().is_empty()


func _tick_tag_in(dt: float) -> void:
	if not _tag_ready():
		tag_t = -1.0
		return
	var fallen := -1
	for i in heroes.size():
		if not heroes[i].is_empty() and not heroes[i].alive:
			fallen = i
			break
	if fallen < 0:
		tag_t = -1.0
		return
	var lv := clampi(Mods.level("roof_deck"), 1, 3)
	if tag_t < 0.0:
		tag_t = DECK_TAG_DELAY[lv]
		return
	tag_t -= dt
	if tag_t > 0.0:
		return
	tag_t = -1.0
	var rd := Game.deck_dweller()
	var out := int(heroes[fallen].did)
	sub[fallen] = int(rd.id)
	sub_out[fallen] = out
	var st := hero_stats(rd, fallen)
	var hp: float = float(st.hp) * DECK_TAG_HP[lv] * clampf(float(rd.hp) / maxf(1.0, float(rd.max_hp)), 0.3, 1.0)
	heroes[fallen] = {"slot": fallen, "did": int(rd.id), "st": st, "max": st.hp, "hp": hp, "atk_t": 0.4,
		"skill_t": float(ROLES[fallen].cd) * 0.5, "heal_t": 2.0, "alive": true, "sub": true}
	var od := Game.dweller_by_id(out)
	Game.toast.emit("%s กระโดดลงจากดาดฟ้ามาแทน %s!" % [rd.name, od.get("name", "?")], "good")
	Trace.rec("combat", "deck tag-in", {"slot": fallen, "in": int(rd.id), "out": out, "wave": wave()})
	tagged_in.emit(fallen, int(rd.id), out)
	heroes_changed.emit()


## wave over: the reserve climbs back up, the original line-up returns (rested)
func _end_subs(rebuild: bool = true) -> void:
	tag_t = -1.0
	if sub.is_empty():
		return
	sub.clear()
	sub_out.clear()
	if rebuild:
		rebuild_heroes()


func hero_pos(slot: int) -> Vector2:
	return ROLES[slot].pos


# =================================================================== waves
func reset_wave(w: int) -> void:
	if Game.s.is_empty():
		return
	cs().wave = maxi(1, w)
	_clear_enemies()
	_end_subs()
	gap_t = 2.0
	wave_changed.emit()


func set_push(on: bool) -> void:
	cs().push = on
	wave_changed.emit()


func challenge_warlord() -> void:
	if not Game.at_checkpoint() or boss_beaten(int(Game.s.biome)) or Modes.peaceful():
		return
	_clear_enemies()
	warlord_cd = 0.0
	gap_t = 0.5
	cs()["warlord_next"] = true
	wave_changed.emit()


## tester tool: replace whatever is on the road with exactly these spawns
func debug_spawn(queue: Array, boss: bool) -> void:
	_clear_enemies()
	spawn_queue = queue.duplicate(true)
	wave_active = true
	wave_is_boss = boss
	wave_is_warlord = false
	for q in queue:
		if str(q.get("boss", "")) == "warlord":
			wave_is_warlord = true
	wave_t = 0.0
	wave_changed.emit()


func _clear_enemies() -> void:
	for e in enemies:
		enemy_removed.emit(int(e.id), false)
	enemies.clear()
	spawn_queue.clear()
	wave_active = false
	_end_subs()     # the wave is gone (warlord challenge, debug spawns): the reserve climbs back up


func _start_wave() -> void:
	var w := wave()
	var mobs: Array = BIOME_MOBS.get(biome_id(), BIOME_MOBS.industrial)
	spawn_queue.clear()
	wave_is_warlord = false
	wave_is_boss = false
	var lvl := enemy_level()
	if warlord_due():
		cs().warlord_next = false
		wave_is_warlord = true
		lvl = warlord_level()
		spawn_queue.append({"t": 0.5, "boss": "warlord", "lvl": lvl})
		for i in 3:
			spawn_queue.append({"t": 1.5 + i * 1.2, "mob": mobs[rng.randi() % mobs.size()], "lvl": lvl - 2})
		Game.toast.emit("บอสด่านตรวจปรากฏตัว: %s!" % BOSSES[biome_id()].th, "bad")
	elif is_boss_wave(w):
		wave_is_boss = true
		var bid := pick_wave_boss(w)
		spawn_queue.append({"t": 0.5, "boss": "boss", "boss_id": bid, "lvl": lvl})
		Game.toast.emit("บอสกลายพันธุ์: %s!" % boss_def(bid).th, "bad")
		for i in 2:
			spawn_queue.append({"t": 1.2 + i * 1.2, "mob": mobs[rng.randi() % mobs.size()], "lvl": lvl})
	else:
		var n := 3 + mini(4, w / 4)
		for i in n:
			spawn_queue.append({"t": 0.4 + i * 1.1 + rng.randf_range(0.0, 0.5), "mob": mobs[rng.randi() % mobs.size()], "lvl": lvl, "elite": rng.randf() < 0.08 + 0.002 * w})
	wave_active = true
	wave_t = 0.0
	wave_changed.emit()


## the checkpoint warlord shows up on the next wave (challenged, or the vault is ready to move on)
func warlord_due() -> bool:
	if Modes.peaceful():
		return false     # peaceful runs pay a toll at the checkpoint instead (Modes.tick)
	return cs().get("warlord_next", false) or (Game.at_checkpoint() and int(Game.s.vault_level) >= _next_req() and not boss_beaten(int(Game.s.biome)) and warlord_cd <= 0.0)


## every boss wave brings a different boss: biome champion + the roaming mutants unlocked by distance
func pick_wave_boss(w: int) -> String:
	var pool := [biome_id()]
	var depth := int(Game.s.biome) + 3 * int(Game.s.get("lap", 0))
	for id in WAVE_BOSSES:
		if depth >= int(WAVE_BOSSES[id].from):
			pool.append(id)
	return pool[(w / 10 + int(Game.s.biome) * 3) % pool.size()]


func boss_def(id: String) -> Dictionary:
	if WAVE_BOSSES.has(id):
		return WAVE_BOSSES[id]
	return BOSSES.get(id, BOSSES.industrial)


func mutation_chance() -> float:
	var depth := float(Game.s.biome) + 3.0 * float(Game.s.get("lap", 0))
	return clampf(0.06 + 0.07 * depth + 0.004 * wave(), 0.0, 0.55)


func _next_req() -> int:
	if Game.map_mode():
		return WorldMap.gate_ahead()      # MV-130: the border road ahead on the world map
	if int(Game.s.biome) >= Data.BIOMES.size() - 1:
		return 0
	return int(Data.biome(int(Game.s.biome) + 1).req)


func _spawn(q: Dictionary) -> void:
	var e := {"id": _next_id, "lvl": int(q.lvl), "stun": 0.0, "atk_t": 0.8, "boss": false, "warlord": false, "elite": bool(q.get("elite", false)), "scale": 1.0, "tint": ""}
	_next_id += 1
	var def: Dictionary
	var mult_hp := 1.0
	var mult_dmg := 1.0
	if q.has("boss"):
		var bd: Dictionary = boss_def(str(q.get("boss_id", biome_id())))
		def = MOBS[bd.base]
		e.boss = true
		e.warlord = q.boss == "warlord"
		mult_hp = 26.0 if e.warlord else 12.0
		mult_dmg = 3.2 if e.warlord else 2.4
		if roaming_boss_balanced(e):
			mult_hp = Features.num("boss.wave_hp", 8.0)
			mult_dmg = Features.num("boss.wave_damage", 1.6)
		e.tint = ""
		e.name = ("บอสด่านตรวจ: " if e.warlord else "") + bd.th
		e.mob = bd.base
		e.boss_sprite = bd.sprite
		e.en = bd.en
		e.mech = (bd.get("mech", []) as Array).duplicate()
		e.mech_t = 4.0
		if bd.get("kind", "") == "air":
			e.boss_air = true
	else:
		var mob_id: String = q.mob
		if not q.has("no_mutate") and rng.randf() < mutation_chance():
			var mp: Array = MUTANT_POOL.get(biome_id(), [])
			if not mp.is_empty():
				mob_id = mp[rng.randi() % mp.size()]
		def = MOBS[mob_id]
		e.mob = mob_id
		e.mech = (def.get("mech", []) as Array).duplicate()
		e.mutant = def.get("mutant", false)
		e.name = def.th
		e.tint = def.get("tint", "")
		if e.elite:
			mult_hp = 2.6
			mult_dmg = 1.5
			e.tint = "ffd56b"
	var L := float(e.lvl)
	# MV-550: checkpoint fights grow with gear, without the +28 reward-level power spike.
	# Summons inherit the encounter tag so ordinary mob growth cannot recreate the wall.
	e["warlord_add"] = bool(q.get("warlord_add", false))
	var hp_growth := HP_GROWTH
	var dmg_growth := DMG_GROWTH
	var combat_level := L
	if warlord_balanced(e):
		combat_level = maxf(1.0, L - WARLORD_OFFSET)
		hp_growth = Loot.ILVL_GROWTH
		dmg_growth = Loot.ILVL_GROWTH
		mult_hp = Features.num("warlord.hp", 6.0) if e.warlord else Features.num("warlord.add_hp", 1.0)
		mult_dmg = Features.num("warlord.damage", 0.6)
	e.max = float(def.hp) * pow(hp_growth, combat_level - 1.0) * mult_hp * Modes.mul("enemy_hp")
	e.hp = e.max
	e.dmg = float(def.dmg) * pow(dmg_growth, combat_level - 1.0) * mult_dmg * Modes.mul("enemy_dmg")
	e.spd = float(def.spd) * (0.7 if e.boss else 1.0) * rng.randf_range(0.9, 1.1)
	e.cd = float(def.cd) * (1.3 if e.boss else 1.0)
	e.kind = "air" if e.get("boss_air", false) else def.kind
	e.range = float(def.get("range", 0.0)) * RANGE_SCALE
	e.sprite = e.get("boss_sprite", def.sprite)
	e.x = SPAWN_X + rng.randf_range(0, 30)
	e.y = GROUND_Y if e.kind != "air" else rng.randf_range(62.0, 96.0)
	if e.kind == "ranged":
		e.stop_x = DECK_X + e.range * rng.randf_range(0.7, 0.95)
	elif e.kind == "air":
		e.stop_x = 316.0 + maxf(e.range, 30.0) * rng.randf_range(0.6, 0.9)
	else:
		e.stop_x = MELEE_STOP + rng.randf_range(0, 10)
	enemies.append(e)
	enemy_spawned.emit(e)
	if (e.boss or e.elite) and Features.on("boss_intro"):
		entrance.emit(e)


# =================================================================== main loop
func _process(delta: float) -> void:
	if not active():
		return
	_acc = minf(_acc + delta, 1.0)
	while _acc >= STEP:
		_acc -= STEP
		tick(STEP)


func tick(dt: float) -> void:
	_clock += dt
	warlord_cd = maxf(0.0, warlord_cd - dt)
	if heroes.is_empty() or heroes.size() != ROLES.size():
		rebuild_heroes()
	# --- wave flow: classic = back-to-back waves, otherwise the threat director decides
	var raid_wave := Threat.tick(dt)
	if not wave_active:
		if Threat.classic():
			gap_t -= dt
			if gap_t <= 0.0 and (Features.on("raids") or warlord_due()):
				_start_wave()
		elif raid_wave:
			_start_wave()
	for q in spawn_queue.duplicate():
		q.t = float(q.t) - dt
		if q.t <= 0.0:
			spawn_queue.erase(q)
			_spawn(q)
	var bruiser_alive := _alive(1)
	var vs := van_stats()
	# --- boss / mutant mechanics
	_tick_mechanics(dt)
	# --- enemies move & attack
	for e in enemies:
		if e.get("burrowed", false):
			continue
		if e.stun > 0.0:
			e.stun = float(e.stun) - dt
			continue
		var stop: float = e.stop_x
		if e.kind == "melee" and not bruiser_alive:
			stop = VAN_REAR + 2.0
		if e.x > stop:
			e.x = maxf(stop, float(e.x) - float(e.spd) * dt)
			continue
		e.atk_t = float(e.atk_t) - dt
		if e.atk_t > 0.0:
			continue
		e.atk_t = float(e.cd)
		var mech: Array = e.get("mech", [])
		if mech.has("solar") and rng.randf() < 0.55:
			# skin-wings dive at the solar array on the roof
			shot.emit("enemy", int(e.id), "solar", -1, "enemy")
			Game.damage_solar(0.03 if e.boss else 0.012)
			boss_event.emit("solar", e)
			continue
		var target := _enemy_target(e, bruiser_alive)
		if e.kind != "melee":
			shot.emit("enemy", int(e.id), "hero" if target >= 0 else "van", target, "acid" if mech.has("acid") else "enemy")
		if mech.has("acid"):
			Game.corrode(6.0 if e.boss else 3.0)
		if target >= 0:
			_damage_hero(target, float(e.dmg), e)
		else:
			_damage_van(e, float(e.dmg) * 0.35, false, float(vs.def))
		# thorns: melee contact with the van's spikes / bruiser parry
	if float(vs.thorns) > 0.0:
		for e in enemies:
			if e.kind == "melee" and float(e.x) <= MELEE_STOP + 12.0:
				_damage_enemy(e, float(vs.thorns) * dt, false, -1, false)
	# --- heroes
	for i in heroes.size():
		var h: Dictionary = heroes[i]
		if h.is_empty() or not h.alive:
			continue
		var st: Dictionary = h.st
		h.hp = minf(float(h.max), float(h.hp) + float(st.regen) * dt)
		h.atk_t = float(h.atk_t) - dt
		if h.atk_t <= 0.0:
			var targets := _targets_in_range(i, float(st.range), int(st.splash))
			var mult := 1.0
			if targets.is_empty() and ROLES[i].id == "bruiser":
				# nothing in melee reach: hurl something at the closest shooter
				targets = _targets_from(DECK_X, BRUISER_THROW, 1, false)
				mult = 0.5
			if not targets.is_empty():
				h.atk_t = 1.0 / maxf(0.2, float(st.aspd))
				for e in targets:
					_hero_hit(i, e, mult)
		# skills
		h.skill_t = float(h.skill_t) - dt
		if h.skill_t <= 0.0:
			if _cast_skill(i):
				h.skill_t = float(ROLES[i].cd) * (0.8 if h.st.get("signature", false) else 1.0)
			else:
				h.skill_t = 0.5
		# medic pulse heal
		if ROLES[i].id == "medic":
			h.heal_t = float(h.heal_t) - dt
			if h.heal_t <= 0.0:
				h.heal_t = 3.5
				var low := _lowest_hero()
				if low >= 0:
					_heal_hero(low, float(st.heal))
	# --- turret
	if float(vs.turret_dps) > 0.0:
		turret.t = float(turret.t) - dt
		if turret.t <= 0.0:
			var tt := _targets_from(TURRET_POS.x, float(vs.turret_range), int(vs.turret_splash), true)
			if bool(vs.get("aa", false)):
				var air := tt.filter(func(x): return x.kind == "air")
				var air_all := enemies.filter(func(x): return x.kind == "air" and float(x.x) - TURRET_POS.x <= float(vs.turret_range) * 1.3)
				if not air_all.is_empty():
					tt = air_all.slice(0, int(vs.turret_splash))
				elif not air.is_empty():
					tt = air
			if not tt.is_empty():
				turret.t = 1.0 / maxf(0.2, float(vs.turret_aspd))
				var has_main := not Loot.van_equipped("turret").is_empty()
				for e in tt:
					var crit := rng.randf() < 0.05
					if has_main:
						shot.emit("turret", 0, "enemy", int(e.id), "turret")
						_damage_enemy(e, float(vs.turret_dmg) * (1.5 if crit else 1.0) * (2.0 if bool(vs.get("aa", false)) and e.kind == "air" else 1.0), crit, -1, true)
					if float(vs.roof) > 0.0 and is_instance_valid(self) and float(e.hp) > 0.0:
						shot.emit("roof", 0, "enemy", int(e.id), "turret")
						_damage_enemy(e, float(vs.turret_dmg) * float(vs.roof), false, -1, true)
	# --- cleanup deaths
	for e in enemies.duplicate():
		if float(e.hp) <= 0.0:
			_on_kill(e)
	# --- wave end / wipe / timeout
	if wave_active:
		wave_t += dt
	if wave_active and spawn_queue.is_empty() and enemies.is_empty():
		_on_wave_cleared()
	else:
		_tick_tag_in(dt)
		# a reserve still waiting on the roof deck keeps the fight going
		if _squad_count() > 0 and _alive_count() == 0 and not _tag_ready():
			_on_wipe()
		elif wave_active and wave_t > (WARLORD_TIMEOUT if wave_is_warlord else WAVE_TIMEOUT):
			_on_wipe(true)
	# dps meter (5 s window)
	while not _dmg_window.is_empty() and _clock - float(_dmg_window[0][0]) > 5.0:
		_dmg_window.pop_front()
	var tot := 0.0
	for p in _dmg_window:
		tot += float(p[1])
	dps_meter = tot / 5.0


# =================================================================== boss / mutant mechanics
func _tick_mechanics(dt: float) -> void:
	for e in enemies.duplicate():
		var mech: Array = e.get("mech", [])
		if mech.is_empty() or not e.boss:
			continue
		var frac := float(e.hp) / maxf(1.0, float(e.max))
		if mech.has("enrage") and frac < 0.3 and not e.get("enraged", false):
			e.enraged = true
			e.spd = float(e.spd) * 1.35
			e.cd = float(e.cd) * 0.65
			e.dmg = float(e.dmg) * 1.25
			boss_event.emit("enrage", e)
			Game.toast.emit("%s คลั่ง! โจมตีเร็วและแรงขึ้น" % e.name, "bad")
		e.mech_t = float(e.get("mech_t", 4.0)) - dt
		if e.get("burrowed", false):
			e.burrow_t = float(e.burrow_t) - dt
			if e.burrow_t <= 0.0:
				e.burrowed = false
				e.x = MELEE_STOP + 4.0
				boss_event.emit("erupt", e)
				if _alive(1):
					_damage_hero(1, float(e.dmg) * 1.6, e)
				_damage_van(e, float(e.dmg) * 0.6, true)
			continue
		if e.mech_t > 0.0:
			continue
		e.mech_t = 9.0 if not e.get("enraged", false) else 6.0
		var mobs: Array = BIOME_MOBS.get(biome_id(), BIOME_MOBS.industrial)
		if mech.has("summon") and enemies.size() < 9:
			for i in 2:
				spawn_queue.append({"t": 0.2 + i * 0.4, "mob": mobs[rng.randi() % mobs.size()], "lvl": maxi(1, int(e.lvl) - 2), "warlord_add": bool(e.get("warlord", false))})
			boss_event.emit("summon", e)
		if mech.has("revive") and enemies.size() < 9:
			spawn_queue.append({"t": 0.3, "mob": mobs[rng.randi() % mobs.size()], "lvl": int(e.lvl), "elite": true, "no_mutate": true})
			boss_event.emit("revive", e)
		if mech.has("burrow") and frac > 0.05:
			e.burrowed = true
			e.burrow_t = 2.6
			boss_event.emit("burrow", e)


func _explode(e: Dictionary) -> void:
	boss_event.emit("explode", e)
	var power := float(e.dmg) * (5.0 if e.boss else 3.0)
	if float(e.x) <= MELEE_STOP + 40.0:
		if _alive(1):
			_damage_hero(1, power, e)
		_damage_van(e, power * 0.3, true)
	for o in enemies:
		if absf(float(o.x) - float(e.x)) < 40.0:
			_damage_enemy(o, power * 0.5, false, -1, true)


## the strongest living boss (for the boss HP bar)
func current_boss() -> Dictionary:
	for e in enemies:
		if e.boss:
			return e
	return {}


func _alive(slot: int) -> bool:
	return slot < heroes.size() and not heroes[slot].is_empty() and heroes[slot].alive


func _squad_count() -> int:
	var n := 0
	for h in heroes:
		if not h.is_empty():
			n += 1
	return n


func _alive_count() -> int:
	var n := 0
	for h in heroes:
		if not h.is_empty() and h.alive:
			n += 1
	return n


## MV-550: only checkpoint bosses and their explicitly tagged summons use progression balance.
func warlord_balanced(e: Dictionary) -> bool:
	return Features.on("warlord_progression") and (bool(e.get("warlord", false)) or bool(e.get("warlord_add", false)))


## MV-544: roaming bosses have their own independent rules.
func roaming_boss_balanced(e: Dictionary) -> bool:
	return Features.on("roaming_boss_balance") and bool(e.get("boss", false)) and not bool(e.get("warlord", false))


## Ordinary attacks already used vehicle defense. Balanced boss bursts now use it too,
## and no single hit can erase more than the configured share of the vehicle's max hull.
## Basic attacks pass their cached defense so acid keeps its original corrosion timing.
func van_hit_damage(e: Dictionary, raw: float, special: bool = false, defense: float = -1.0) -> float:
	var checkpoint := warlord_balanced(e)
	var balanced := roaming_boss_balanced(e)
	if special and not balanced and not checkpoint:
		return raw
	defense = float(van_stats().def) if defense < 0.0 else defense
	var red := defense / (defense + def_k(float(e.lvl)))
	var damage := raw * (1.0 - red)
	if checkpoint:
		damage = minf(damage, Game.hull_max() * Features.num("warlord.hull_hit_cap", 0.01))
	elif balanced:
		damage = minf(damage, Game.hull_max() * Features.num("boss.hull_hit_cap", 0.12))
	return damage


func _damage_van(e: Dictionary, raw: float, special: bool = false, defense: float = -1.0) -> void:
	var damage := van_hit_damage(e, raw, special, defense)
	Game.s.hull = maxf(0.0, float(Game.s.hull) - damage)
	hit.emit("van", -1, damage, special)


func _enemy_target(e: Dictionary, bruiser_alive: bool) -> int:
	if e.kind == "melee":
		return 1 if bruiser_alive else -1
	var pool := []
	for i in heroes.size():
		if _alive(i):
			pool.append(i)
	if pool.is_empty():
		return -1
	if e.kind == "air":
		var roof := pool.filter(func(i): return i != 1)
		if not roof.is_empty() and rng.randf() < 0.7:
			return roof[rng.randi() % roof.size()]
	if bruiser_alive and rng.randf() < 0.5:
		return 1
	if rng.randf() < 0.2:
		return -1   # stray shots hit the van
	return pool[rng.randi() % pool.size()]


func _targets_in_range(slot: int, rng_px: float, n: int) -> Array:
	var origin := hero_pos(slot)
	if ROLES[slot].id == "bruiser":
		var out := []
		for e in enemies:
			if e.kind != "air" and float(e.x) <= DECK_X + rng_px + 20.0:
				out.append(e)
		out.sort_custom(func(a, b): return float(a.x) < float(b.x))
		return out.slice(0, n)
	return _targets_from(origin.x, rng_px, n, false)


func _targets_from(x0: float, rng_px: float, n: int, _any: bool) -> Array:
	var out := []
	for e in enemies:
		if float(e.x) - x0 <= rng_px and float(e.x) < SPAWN_X - 10.0:
			out.append(e)
	out.sort_custom(func(a, b): return float(a.x) < float(b.x))
	return out.slice(0, n)


func _hero_hit(slot: int, e: Dictionary, mult: float) -> void:
	var st: Dictionary = heroes[slot].st
	var crit := rng.randf() * 100.0 < float(st.crit)
	var dmg := float(st.dmg) * mult * (float(st.critd) / 100.0 if crit else 1.0)
	shot.emit("hero", slot, "enemy", int(e.id), "melee" if ROLES[slot].id == "bruiser" else "bullet")
	_damage_enemy(e, dmg, crit, slot, true)
	if float(st.lifesteal) > 0.0:
		_heal_hero(slot, dmg * float(st.lifesteal) / 100.0, false)


func _damage_enemy(e: Dictionary, dmg: float, crit: bool, _slot: int, show: bool) -> void:
	if e.get("burrowed", false):
		return
	if Dev.on("one_hit"):
		dmg = maxf(dmg, float(e.max) * 3.0)
	if (e.get("mech", []) as Array).has("armor") and float(e.hp) > float(e.max) * 0.6:
		dmg *= 0.5
		if float(e.hp) - dmg <= float(e.max) * 0.6:
			boss_event.emit("armor_break", e)
	e.hp = float(e.hp) - dmg
	_dmg_window.append([_clock, dmg])
	if show:
		hit.emit("enemy", int(e.id), dmg, crit)


func _damage_hero(slot: int, raw: float, source: Dictionary = {}) -> void:
	var h: Dictionary = heroes[slot]
	if Dev.on("invincible"):
		hit.emit("hero", slot, 0.0, false)
		return
	var st: Dictionary = h.st
	if rng.randf() * 100.0 < float(st.get("dodge", 0.0)):
		hit.emit("dodge", slot, 0.0, false)
		return
	var lvl := float(enemy_level()) if not wave_is_warlord else float(warlord_level())
	var red := float(st.def) / (float(st.def) + def_k(lvl))
	var dmg := raw * (1.0 - red)
	if warlord_balanced(source):
		dmg = minf(dmg, float(h.max) * Features.num("warlord.hero_hit_cap", 0.02))
	h.hp = float(h.hp) - dmg
	hit.emit("hero", slot, dmg, false)
	if float(h.hp) <= 0.0:
		h.hp = 0.0
		h.alive = false
		heroes_changed.emit()


func _heal_hero(slot: int, amt: float, show: bool = true) -> void:
	var h: Dictionary = heroes[slot]
	if h.is_empty() or not h.alive:
		return
	h.hp = minf(float(h.max), float(h.hp) + amt)
	if show:
		hit.emit("heal", slot, amt, false)


func _lowest_hero() -> int:
	var best := -1
	var best_p := 0.98
	for i in heroes.size():
		if _alive(i):
			var p := float(heroes[i].hp) / float(heroes[i].max)
			if p < best_p:
				best_p = p
				best = i
	return best


func _cast_skill(slot: int) -> bool:
	var st: Dictionary = heroes[slot].st
	var pw := 1.4 if st.get("signature", false) else 1.0
	match ROLES[slot].id:
		"gunner":
			var pool := _targets_from(hero_pos(slot).x, float(st.range), 99, false)
			if pool.is_empty():
				return false
			skill_cast.emit(slot, "volley")
			for k in 5:
				_hero_hit(slot, pool[rng.randi() % pool.size()], 0.7 * pw)
			return true
		"bruiser":
			var near := []
			for e in enemies:
				if e.kind != "air" and float(e.x) <= DECK_X + 90.0:
					near.append(e)
			if near.is_empty():
				return false
			skill_cast.emit(slot, "slam")
			for e in near:
				_hero_hit(slot, e, 1.5 * pw)
				e.stun = 1.5
			return true
		"medic":
			if _lowest_hero() < 0 and float(Game.s.hull) >= Game.hull_max():
				return false
			skill_cast.emit(slot, "patch")
			for i in heroes.size():
				if _alive(i):
					_heal_hero(i, float(heroes[i].max) * 0.3 * pw)
			Game.s.hull = minf(Game.hull_max(), float(Game.s.hull) + 2.0 + float(st.heal) * 0.1)
			return true
	return false


# =================================================================== rewards
func _on_kill(e: Dictionary) -> void:
	enemies.erase(e)
	if (e.get("mech", []) as Array).has("explode"):
		_explode(e)
	var L := float(e.lvl)
	var bonus_xp := 0.0
	var bonus_scrap := 0.0
	var luck := 0.0
	var supply := 0.0
	for h in heroes:
		if not h.is_empty():
			bonus_xp += float(h.st.xp)
			bonus_scrap += float(h.st.scrap)
			luck += float(h.st.loot)
			supply += float(h.st.get("supply", 0.0))
	var vs := van_stats()
	bonus_scrap += float(vs.scrap)
	luck += float(vs.loot)
	var mult := (12.0 if e.boss else (3.0 if e.elite else 1.0)) * Threat.reward_mult()
	var xp := (2.0 + L * 0.25) * mult * (1.0 + bonus_xp / 100.0)
	var scrap := (0.3 + L * 0.12) * mult * (1.0 + bonus_scrap / 100.0)
	for h in heroes:
		if not h.is_empty() and h.alive:
			var d := Game.dweller_by_id(int(h.did))
			if not d.is_empty():
				Game.give_xp(d, xp, ROLES[int(h.slot)].stat)
	var rd := Game.deck_dweller()
	if not rd.is_empty() and sub.is_empty():
		Game.give_xp(rd, xp * DECK_RESERVE_XP, Game._best_stat(rd))
	Game._add_res("scrap", scrap)
	Threat.on_kill(scrap)
	# MV-247: mutated animals are hunted for meat (people, zombies and machines give none)
	if Data.raw_food() and Data.MEAT_MOBS.has(str(e.get("mob", ""))):
		# no level / raid-pay scaling: hunting should keep a small crew fed, not fill the pantry (~1.5 meat/min)
		var meat := float(Data.MEAT_MOBS[str(e.mob)]) * Data.MEAT_PER_KILL * (12.0 if e.boss else (3.0 if e.elite else 1.0)) * Features.num("food.meat_kill", 1.0)
		Game._add_res("meat", meat)
		if e.boss or e.elite or rng.randf() < 0.25:
			supply_found.emit("meat", meat, Vector2(float(e.x), float(e.y)))
	# backpacks: chance to scavenge food / water from every kill
	if supply > 0.0 and rng.randf() < minf(0.85, supply / 100.0 * 0.5 + (0.5 if e.boss else 0.0)):
		var kind := "food" if rng.randf() < 0.5 else "water"
		var amt := 2.0 + L * 0.15
		Game._add_res(kind, amt)
		supply_found.emit(kind, amt, Vector2(float(e.x), float(e.y)))
	cs().kills = int(cs().get("kills", 0)) + 1
	_kill_window.append(_clock)
	while not _kill_window.is_empty() and _clock - float(_kill_window[0]) > 120.0:
		_kill_window.pop_front()
	cs().kpm = float(_kill_window.size()) / maxf(1.0, minf(2.0, _clock / 60.0))
	enemy_removed.emit(int(e.id), true)
	# ---- drops
	var at := Vector2(float(e.x), float(e.y))
	var drops := 0
	var min_rar := 0
	if e.warlord:
		drops = 3
		min_rar = 2
	elif e.boss:
		drops = 2
		min_rar = 2
	else:
		var chance := (0.30 if e.elite else 0.065) * (1.0 + luck / 100.0) * Threat.reward_mult()
		if rng.randf() < chance:
			drops = 1
			min_rar = 1 if e.elite else 0
	for k in drops:
		var item := Loot.roll_random(int(L), luck, min_rar)
		var kept := Loot.add_to_stash(item)
		loot_dropped.emit(item, at)
		if kept and int(item.rar) >= 3:
			Game.toast.emit("ดรอป %s! %s Lv.%d" % [Loot.rarity(int(item.rar)).en, Loot.item_name(item), item.ilvl], "biome")
	if drops > 0:
		Game.gear_changed.emit()
	if e.boss and rng.randf() < 0.35 and Game.s.dwellers.size() < Game.pop_cap():
		var nd := Game.offer_recruit("boss", 1.0)
		if not nd.is_empty():
			Game.toast.emit("ช่วยเชลยจากบอสได้! %s ขึ้นรถมาร่วมทาง" % nd.name, "good")
	Game.resources_changed.emit()


func _on_wave_cleared() -> void:
	wave_active = false
	gap_t = 1.8
	var w := wave()
	if wave_is_warlord:
		cs().boss_beaten[str(int(Game.s.biome))] = true    # biome is a float after a save load
		Game.toast.emit("ปราบบอสด่านตรวจสำเร็จ! เส้นทางเปิดแล้ว", "biome")
		Game.travel_changed.emit()
	elif wave_is_boss:
		Game.toast.emit("ล้มบอสเวฟ %d ได้!" % w, "good")
	if not wave_is_warlord and bool(cs().push):
		cs().wave = w + 1
		cs().best = maxi(int(cs().get("best", 1)), w + 1)
	Threat.on_wave_cleared()
	_end_subs()
	# survivors patch up, the fallen get back on their feet
	for h in heroes:
		if h.is_empty():
			continue
		if not h.alive:
			h.alive = true
			h.hp = float(h.max) * 0.4
		else:
			h.hp = minf(float(h.max), float(h.hp) + float(h.max) * 0.15)
	heroes_changed.emit()
	wave_changed.emit()


func _on_wipe(timeout: bool = false) -> void:
	squad_wiped.emit()
	if wave_is_warlord:
		warlord_cd = 45.0
		Game.toast.emit(("หมดเวลา! " if timeout else "") + "ทีมพ่ายแพ้ต่อบอสด่านตรวจ — ฟาร์มของให้แกร่งขึ้นแล้วท้าใหม่", "bad")
	else:
		Game.toast.emit("หมดเวลาเวฟ! ศัตรูแข็งเกินไป ถอยกลับ 3 เวฟ" if timeout else "ทีมป้องกันล้มทั้งหมด! ถอยกลับ 3 เวฟ", "bad")
		if bool(cs().push):
			cs().wave = maxi(1, wave() - 3)
	_clear_enemies()
	Threat.on_wipe()
	_end_subs()
	gap_t = 6.0
	for h in heroes:
		if not h.is_empty():
			h.alive = true
			h.hp = float(h.max) * 0.5
	heroes_changed.emit()
	wave_changed.emit()


## idle rewards while the game was closed: XP + scrap only (no gear), like TBH.
## Threat pacing pays the expected raids instead (Threat.offline_kpm)
func offline_rewards(sec: float) -> Dictionary:
	if Game.s.is_empty() or not _has_squad():
		return {}
	var kpm := minf(kills_per_min(), 30.0)
	if kpm <= 0.0:
		kpm = 4.0
	kpm = Threat.offline_kpm(kpm)
	var kills := int(kpm * sec / 60.0 * 0.5)
	if kills <= 0:
		return {}
	var L := float(enemy_level())
	var xp := (2.0 + L * 0.25) * kills
	var scrap := (0.3 + L * 0.12) * kills
	for i in Game.s.squad.size():
		var did := int(Game.s.squad[i])
		if did >= 0:
			var d := Game.dweller_by_id(did)
			if not d.is_empty():
				Game.give_xp(d, xp, ROLES[i].stat, true)
	var rd := Game.deck_dweller()
	if not rd.is_empty():
		Game.give_xp(rd, xp * DECK_RESERVE_XP, Game._best_stat(rd), true)
	Game._add_res("scrap", scrap)
	return {"kills": kills, "scrap": int(scrap), "xp": int(xp)}
