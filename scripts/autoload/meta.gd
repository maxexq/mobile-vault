extends Node
## Prestige / meta-progression: "The Next Generation".
## When the truck is wrecked (hull 0 for 2 minutes) or the player retires it after the first warlord,
## part of the crew, resources and every blueprint escape to build a new, bigger vehicle.
## Legacy points buy permanent perks; blueprints unlock the MK-II / MK-III chassis (5 / 6 floors).

signal wrecked
signal generation_started(gen: int)

const WRECK_SEC := 120.0
const PERKS := {
	"head_start": {"th": "เสบียงตั้งต้น", "en": "HEAD START", "icon": "scrap", "max": 3, "cost": [3, 6, 10], "desc": "เริ่มรอบใหม่ด้วยเศษเหล็ก +250 และชิ้นส่วน +20 ต่อระดับ"},
	"efficient": {"th": "วิศวกรรมรุ่นใหม่", "en": "EFFICIENCY", "icon": "gear", "max": 5, "cost": [4, 6, 9, 13, 18], "desc": "ทุกห้องผลิต +5% ต่อระดับ"},
	"quick_frame": {"th": "โครงสำเร็จรูป", "en": "PREFAB FRAME", "icon": "up", "max": 3, "cost": [5, 9, 14], "desc": "ค่าอัปเกรด Vault -10% ต่อระดับ"},
	"early_rooms": {"th": "แบบห้องสะสม", "en": "ROOM ARCHIVE", "icon": "hammer", "max": 1, "cost": [8], "desc": "ห้องทุกประเภทปลดล็อกเร็วขึ้น 1 เลเวล (ห้องอาวุธ/วิจัยตั้งแต่ Lv.1)"},
	"veterans": {"th": "ทหารผ่านศึก", "en": "VETERANS", "icon": "people", "max": 2, "cost": [6, 12], "desc": "พาผู้รอดชีวิตหนีได้เพิ่ม +1 คน/ระดับ"},
	"training": {"th": "ถ่ายทอดประสบการณ์", "en": "TRAINING", "icon": "xp", "max": 2, "cost": [6, 12], "desc": "ผู้รอดชีวิตที่พามาเก็บเลเวลได้ 50% → 70% → 90%"},
	"skill_spark": {"th": "ประกายแห่งทักษะ", "en": "SKILL SPARK", "icon": "int", "max": 2, "cost": [7, 14], "desc": "ทุกคนได้แต้มสกิล +2 ต่อระดับ"},
	"chassis2": {"th": "แชสซี MK-II", "en": "CHASSIS MK-II", "icon": "hull", "max": 1, "cost": [12], "bp": "bp_chassis2", "desc": "รถคันใหม่สูง 5 ชั้น (15 ห้อง) · ต้องมีพิมพ์เขียว"},
	"chassis3": {"th": "แชสซี MK-III", "en": "CHASSIS MK-III", "icon": "hull", "max": 1, "cost": [25], "bp": "bp_chassis3", "req": "chassis2", "desc": "รถคันใหม่สูง 6 ชั้น (18 ห้อง) · ต้องมีพิมพ์เขียว"},
}
const VEHICLE_NAMES := ["MAMMOTH-7", "MAMMOTH-8", "BEHEMOTH-1", "BEHEMOTH-2", "LEVIATHAN", "LEVIATHAN-II", "ARK", "ARK-II"]


func m() -> Dictionary:
	if Game.s.is_empty():
		return {}
	if not Game.s.has("meta"):
		Game.s["meta"] = {"gen": 1, "legacy": 0, "perks": {}, "blueprints": [], "best_km": 0.0}
	return Game.s.meta


func generation() -> int:
	return int(m().get("gen", 1))


func vehicle_name() -> String:
	return VEHICLE_NAMES[clampi(generation() - 1, 0, VEHICLE_NAMES.size() - 1)]


func perk(id: String) -> int:
	if Game.s.is_empty():
		return 0
	return int(m().get("perks", {}).get(id, 0))


func chassis() -> int:
	if perk("chassis3") > 0:
		return 3
	if perk("chassis2") > 0:
		return 2
	return 1


func floors() -> int:
	return 3 + int(Game.s.get("chassis", 1)) if not Game.s.is_empty() else 4


func has_blueprint(bp: String) -> bool:
	return (m().get("blueprints", []) as Array).has(bp)


func add_blueprint(bp: String) -> void:
	if not has_blueprint(bp):
		m().blueprints.append(bp)


# ------------------------------------------------------------------ retire / wreck
func can_retire() -> bool:
	return Combat.boss_beaten(0) or int(Game.s.get("lap", 0)) > 0 or generation() > 1 and float(Game.s.stats.km_total) > 6.0


func is_wrecked() -> bool:
	return bool(Game.s.get("wrecked", false))


func wreck_time_left() -> float:
	return maxf(0.0, WRECK_SEC - float(Game.s.get("wreck_t", 0.0)))


func tick(dt: float, offline: bool) -> void:
	if is_wrecked():
		return
	if float(Game.s.hull) <= 0.0:
		if offline:
			return    # never lose the truck while the player is away
		var before := float(Game.s.get("wreck_t", 0.0))
		Game.s["wreck_t"] = before + dt
		if int(before / 30.0) != int(float(Game.s.wreck_t) / 30.0):
			Game.toast.emit("ตัวถังพัง! ซ่อมภายใน %d วินาที ไม่งั้นรถจะพังถาวร" % int(wreck_time_left()), "bad")
		if float(Game.s.wreck_t) >= WRECK_SEC:
			Game.s["wrecked"] = true
			Game.s.traveling = false
			wrecked.emit()
	elif float(Game.s.get("wreck_t", 0.0)) > 0.0:
		Game.s.wreck_t = 0.0


func legacy_earned() -> int:
	var s := Game.s
	var bosses := (s.combat.get("boss_beaten", {}) as Dictionary).size()
	var p := float(s.stats.km_total) * 0.6 + bosses * 4.0 + int(s.get("lap", 0)) * 15.0 + int(s.vault_level) * 2.0
	p += int(s.stats.get("expeditions", 0)) * 1.0
	return maxi(1, int(p))


func carry_slots() -> int:
	return 2 + perk("veterans")


func carry_level_keep() -> float:
	return [0.5, 0.7, 0.9][clampi(perk("training"), 0, 2)]


func carry_res_ratio() -> float:
	return 0.25


func perk_cost(id: String) -> int:
	var p: Dictionary = PERKS[id]
	var lv := perk(id)
	return int(p.cost[lv]) if lv < p.cost.size() else 0


func can_buy(id: String, legacy: int) -> bool:
	var p: Dictionary = PERKS[id]
	if perk(id) >= int(p.max):
		return false
	if p.has("bp") and not has_blueprint(p.bp):
		return false
	if p.has("req") and perk(p.req) <= 0:
		return false
	return legacy >= perk_cost(id)


func buy(id: String) -> bool:
	var mm := m()
	if not can_buy(id, int(mm.legacy)):
		return false
	mm.legacy = int(mm.legacy) - perk_cost(id)
	mm.perks[id] = perk(id) + 1
	return true


## bank this run's legacy (once) — called when the Next Generation screen opens
func bank_legacy() -> int:
	if Game.s.get("legacy_banked", false):
		return 0
	var e := legacy_earned()
	m().legacy = int(m().legacy) + e
	m().best_km = maxf(float(m().get("best_km", 0.0)), float(Game.s.stats.km_total))
	Game.s["legacy_banked"] = true
	return e


## build the next vehicle. carry_ids = survivors who escape
func next_generation(carry_ids: Array) -> void:
	var old := Game.s
	var meta: Dictionary = (old.meta as Dictionary).duplicate(true)
	meta.gen = int(meta.gen) + 1
	var carried := []
	for did in carry_ids.slice(0, carry_slots()):
		for d in old.dwellers:
			if int(d.id) == int(did):
				carried.append((d as Dictionary).duplicate(true))
	var res_scrap := float(old.res.scrap) * carry_res_ratio()
	var comps := int(float(old.items.get("components", 0)) * carry_res_ratio())
	var memorial: Array = old.get("memorial", [])
	# --- fresh state with the meta carried over
	Game.s = {"meta": meta, "chassis": 1}
	Game.s.chassis = chassis()
	Game.setup_default_state(true)
	Game.s.meta = meta
	Game.s.memorial = memorial
	var hs := perk("head_start")
	Game.s.res.scrap = minf(Game.cap("scrap"), float(Game.s.res.scrap) + res_scrap + 250.0 * hs)
	Game.s.items["components"] = int(Game.s.items.get("components", 0)) + comps + 20 * hs
	for d in carried:
		var keep := carry_level_keep()
		var nd := Game._add_dweller({"name": d.name, "lore": d.get("lore", ""), "variant": d.variant, "str": d.str, "int": d.int, "agi": d.agi,
			"lvl": maxi(1, int(round(float(d.lvl) * keep)))})
		nd.traits = d.get("traits", [])
		var w: Variant = d.get("gear", {}).get("weapon")
		if w is Dictionary:
			nd.gear["weapon"] = w
		nd["veteran"] = int(d.get("veteran", 0)) + 1
	Game.started = true
	Game.save_game()
	Game.game_started.emit()
	Game._emit_all(true)
	Mods.mods_changed.emit()
	generation_started.emit(int(meta.gen))
	Game.toast.emit("รุ่นที่ %d: %s ออกเดินทาง!" % [int(meta.gen), vehicle_name()], "biome")
