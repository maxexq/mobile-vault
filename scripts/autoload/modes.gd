extends Node
## Game modes: the rule set a run is started with, locked in Game.s.mode = {id, diff, mut, ranked, started_at}.
## A mode is data only: feature switches go into the Features "mode" layer (after remote, before tester
## overrides) and every number is a multiplier read through mul(). Carried over to the next generation.
##  mode       standard (current game) · peaceful (no raids, checkpoints take a scrap toll, research ×0.5)
##  difficulty easy · normal · hard · nightmare (enemy HP/damage, threat, rations, offline cap, research)
##  mutators   extra rules on top of either mode, each one adds to the research multiplier

signal changed

const DEFAULT := {"id": "standard", "diff": "normal", "mut": []}
const TOLL_SHARE := 0.45      # peaceful checkpoint toll = this share of the scrap cap (always affordable)
const SALVAGE_MIN := 30.0     # peaceful: the idle squad scavenges one scrap cap (= the next Vault upgrade) per this many minutes

const MODES := {
	"standard": {"th": "เอาชีวิตรอด", "en": "SURVIVAL", "desc": "เกมเต็มรูปแบบ: ศัตรูบุก บอสด่านตรวจ การสำรวจ และการส่งต่อรุ่น", "ranked": true},
	"peaceful": {"th": "ขบวนสงบ", "en": "PEACEFUL", "desc": "ไม่มีศัตรูบุก ทีมป้องกันออกเก็บเศษเหล็กข้างทางแทน ด่านตรวจเก็บค่าผ่านทางแทนบอส · แต้มวิจัย ×0.5",
		"features": {"raids": false}, "legacy": 0.5, "ranked": false, "peaceful": true},
}
const DIFFS := {
	"easy": {"th": "ง่าย", "en": "EASY", "enemy_hp": 0.7, "enemy_dmg": 0.7, "threat": 0.75, "eat": 0.8, "legacy": 0.75},
	"normal": {"th": "ปกติ", "en": "NORMAL"},
	"hard": {"th": "ยาก", "en": "HARD", "enemy_hp": 1.35, "enemy_dmg": 1.25, "threat": 1.25, "eat": 1.15, "legacy": 1.4},
	"nightmare": {"th": "ฝันร้าย", "en": "NIGHTMARE", "enemy_hp": 1.8, "enemy_dmg": 1.5, "threat": 1.5, "eat": 1.3, "offline": 0.5, "legacy": 2.0},
}
## combat = only makes sense with enemies (hidden in peaceful); score = added to the research multiplier
const MUTATORS := {
	"fuel_scarce": {"th": "น้ำมันขาดแคลน", "desc": "ได้น้ำมันจากทุกทางครึ่งเดียว", "fuel_gain": 0.5, "score": 0.2},
	"lean_rations": {"th": "เสบียงฝืดเคือง", "desc": "ลูกเรือกินและดื่ม ×1.4", "eat": 1.4, "score": 0.15},
	"lone_road": {"th": "ถนนเปลี่ยว", "desc": "ไม่มีทีมสำรวจ จุดพิเศษ และคนแปลกหน้า",
		"features": {"expeditions": false, "encounters": false, "strangers": false}, "score": 0.2},
	"glass_cannon": {"th": "ตีแรงตัวบาง", "desc": "ทีมป้องกันดาเมจ ×2 แต่เลือด ×0.5", "hero_dmg": 2.0, "hero_hp": 0.5, "score": 0.15, "combat": true},
	"horde": {"th": "ฝูงคลั่ง", "desc": "ภัยสะสมเร็ว ×1.6 ศัตรูเลือด ×1.2", "threat": 1.6, "enemy_hp": 1.2, "score": 0.25, "combat": true},
}
const MUL_KEYS := ["enemy_hp", "enemy_dmg", "threat", "eat", "offline", "fuel_gain", "hero_dmg", "hero_hp"]

## the picker on the title screen leaves its choice here for Game.new_game()
var pending := {}
var _mul := {}


func _ready() -> void:
	Game.game_started.connect(apply)


# =================================================================== state
func m() -> Dictionary:
	if Game.s.is_empty():
		return DEFAULT
	return Game.s.get("mode", DEFAULT)


func id() -> String:
	return str(m().get("id", "standard"))


func diff() -> String:
	return str(m().get("diff", "normal"))


func mutators() -> Array:
	return m().get("mut", [])


func has_mut(k: String) -> bool:
	return mutators().has(k)


func peaceful() -> bool:
	return bool(MODES.get(id(), {}).get("peaceful", false))


## a run that could go on a leaderboard later: a ranked mode and never touched by GOD MODE
func ranked() -> bool:
	return bool(MODES.get(id(), {}).get("ranked", false)) and not bool(Game.s.get("stats", {}).get("cheated", false))


## cleaned copy of a choice; unknown ids fall back, combat-only mutators are dropped in peaceful
func make(mode_id: String, diff_id: String = "normal", muts: Array = []) -> Dictionary:
	var mid := mode_id if MODES.has(mode_id) else "standard"
	var did := diff_id if DIFFS.has(diff_id) else "normal"
	var mu := []
	for k in MUTATORS:
		if muts.has(k) and not (bool(MODES[mid].get("peaceful", false)) and bool(MUTATORS[k].get("combat", false))):
			mu.append(k)
	return {"id": mid, "diff": did, "mut": mu}


## the mode for a brand new run: the picker's choice, once
func take_pending() -> Dictionary:
	var p := pending if not pending.is_empty() else DEFAULT
	pending = {}
	var out := make(str(p.get("id", "standard")), str(p.get("diff", "normal")), p.get("mut", []))
	out.started_at = Cloud.now()
	return out


## switch the running game (GOD MODE only: Dev.mode_set marks the save as cheated)
func set_mode(mode: Dictionary) -> void:
	var keep := float(m().get("started_at", Cloud.now()))
	Game.s.mode = make(str(mode.get("id", "standard")), str(mode.get("diff", "normal")), mode.get("mut", []))
	Game.s.mode.started_at = keep
	apply()


# =================================================================== effects
func apply() -> void:
	_mul = _calc_mul(m())
	Features.set_mode_layer({"features": _calc_features(m())})
	Trace.rec("meta", "mode", {"id": id(), "diff": diff(), "mut": mutators(), "ranked": ranked()})
	changed.emit()


func mul(key: String) -> float:
	return float(_mul.get(key, 1.0))


func _calc_mul(md: Dictionary) -> Dictionary:
	var out := {}
	var parts := [DIFFS.get(str(md.get("diff", "normal")), {})]
	for k in md.get("mut", []):
		parts.append(MUTATORS.get(k, {}))
	for p in parts:
		for k in MUL_KEYS:
			if p.has(k):
				out[k] = float(out.get(k, 1.0)) * float(p[k])
	return out


func _calc_features(md: Dictionary) -> Dictionary:
	var f := {}
	f.merge(MODES.get(str(md.get("id", "standard")), {}).get("features", {}), true)
	for k in md.get("mut", []):
		f.merge(MUTATORS.get(k, {}).get("features", {}), true)
	return f


## research points (prestige) multiplier: mode × difficulty × (1 + mutator bonuses)
func legacy_mult(md: Dictionary = {}) -> float:
	if md.is_empty():
		md = m()
	var x := float(MODES.get(str(md.get("id", "standard")), {}).get("legacy", 1.0))
	x *= float(DIFFS.get(str(md.get("diff", "normal")), {}).get("legacy", 1.0))
	var bonus := 0.0
	for k in md.get("mut", []):
		bonus += float(MUTATORS.get(k, {}).get("score", 0.0))
	return x * (1.0 + bonus)


func label(md: Dictionary = {}) -> String:
	if md.is_empty():
		md = m()
	var t := "%s · %s" % [MODES.get(str(md.get("id", "")), MODES.standard).th, DIFFS.get(str(md.get("diff", "")), DIFFS.normal).th]
	var mu: Array = md.get("mut", [])
	if not mu.is_empty():
		t += " · " + ", ".join(mu.map(func(k): return str(MUTATORS.get(k, {}).get("th", k))))
	return t


# =================================================================== peaceful checkpoints
func toll() -> int:
	return int(round(Game.cap("scrap") * TOLL_SHARE))


## the vault waits at the checkpoint until the toll is affordable, then pays it on its own
func toll_due() -> bool:
	if not peaceful() or Game.s.is_empty():
		return false
	var b := int(Game.s.biome)
	if Combat.boss_beaten(b) or float(Game.s.km) < Game.biome_end_km() - 0.001:
		return false
	return b >= Data.BIOMES.size() - 1 or int(Game.s.vault_level) >= int(Data.biome(b + 1).req)


## scrap per minute the squad brings in on a peaceful run (no fights = no kill scrap); 0 without a squad
func salvage_pm() -> float:
	if not peaceful() or Game.s.is_empty() or not Combat._has_squad():
		return 0.0
	return Game.cap("scrap") / SALVAGE_MIN * (1.0 + 0.5 * float(Game.s.get("lap", 0)))


func tick(dt: float, offline: bool) -> void:
	var sv := salvage_pm()
	if sv > 0.0:
		Game._add_res("scrap", sv * dt / 60.0)
	if not toll_due():
		return
	var c := toll()
	if float(Game.s.res.scrap) < c:
		return
	Game._add_res("scrap", -c)
	Combat.cs().boss_beaten[str(Game.s.biome)] = true
	Trace.rec("meta", "toll paid", {"biome": int(Game.s.biome), "scrap": c})
	if not offline:
		Game.toast.emit(Loc.t("จ่ายค่าผ่านทาง %d เศษเหล็ก ด่านตรวจเปิดทางให้แล้ว") % c, "biome")
	Game.travel_changed.emit()
