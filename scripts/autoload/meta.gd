extends Node
## Prestige / meta-progression: "The Next Generation".
## When the truck is wrecked (hull 0 for 2 minutes) or the player retires it after the first warlord,
## the whole crew (MV-559), part of the resources and every blueprint return to build a new vehicle.
## Genetic-research points (stored as "legacy") buy permanent perks; vehicle blueprints + research unlock the
## next vehicle tier: camper van -> armoured bus -> 18-wheeler rig -> armoured train. Every rebirth is told as a
## short story (a radio SOS from the wreck, handing the blueprints to Command...).

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
	"tier_bus": {"th": "รถบัสหุ้มเหล็ก", "en": "ARMORED BUS", "icon": "hull", "max": 1, "cost": [8], "bp": "bp_bus", "desc": "รุ่นถัดไปออกเดินทางด้วยรถบัส 3 ชั้น (9 ห้อง) · ต้องมีพิมพ์เขียว"},
	"tier_rig": {"th": "รถพ่วง 18 ล้อ", "en": "18-WHEELER RIG", "icon": "hull", "max": 1, "cost": [16], "bp": "bp_rig", "req": "tier_bus", "desc": "รถบรรทุก 4 ชั้น (12 ห้อง) เครื่องแรง · ต้องมีพิมพ์เขียว"},
	"tier_train": {"th": "รถไฟหุ้มเกราะ", "en": "ARMORED TRAIN", "icon": "hull", "max": 1, "cost": [30], "bp": "bp_train", "req": "tier_rig", "desc": "หัวรถจักรหุ้มเกราะ 4 ชั้น วิ่งบนราง ลากโบกี้ได้ · ต้องมีพิมพ์เขียว"},
}
const TIER_PERK := {"bus": "tier_bus", "rig": "tier_rig", "train": "tier_train"}
const RESEARCH_TH := "แต้มวิจัยพันธุกรรม"
## rebirth stories: picked by how the run ended
const STORIES := {
	"wreck": {"title": "สัญญาณสุดท้าย", "en": "LAST TRANSMISSION", "img": "story_sos",
		"text": "%s พังยับเยินกลางถนน แต่ก่อนไฟจะดับ วิทยุยังส่งสัญญาณขอความช่วยเหลือออกไปได้ทัน... ฮ.กู้ภัยของศูนย์บัญชาการลงจอดตอนรุ่งสาง รับผู้รอดชีวิตและพิมพ์เขียวทุกแผ่นกลับไปที่ฐาน"},
	"retire": {"title": "ส่งมอบพิมพ์เขียว", "en": "BLUEPRINT HANDOVER", "img": "story_command",
		"text": "%s พาทุกคนมาถึงศูนย์บัญชาการได้สำเร็จ ข้อมูลเส้นทาง ตัวอย่างพันธุกรรมของสิ่งกลายพันธุ์ และพิมพ์เขียวทั้งหมดถูกส่งมอบให้ทีมวิจัย ช่างเริ่มประกอบพาหนะคันใหม่ที่ใหญ่กว่าเดิมทันที"},
	"lap": {"title": "เกินขอบแผนที่", "en": "BEYOND THE MAP", "img": "story_command",
		"text": "%s วิ่งครบเส้นทางทั้งสายและกลับมาพร้อมแผนที่ที่ไม่มีใครเคยเห็น ศูนย์บัญชาการตั้งชื่อเส้นทางนี้ตามชื่อรถของคุณ"},
}


func m() -> Dictionary:
	if Game.s.is_empty():
		return {}
	if not Game.s.has("meta"):
		Game.s["meta"] = {"gen": 1, "legacy": 0, "perks": {}, "blueprints": [], "best_km": 0.0}
	return Game.s.meta


func generation() -> int:
	return int(m().get("gen", 1))


func vehicle_name() -> String:
	var names: Array = Game.vehicle_def().get("names", ["MAMMOTH-7"])
	return str(names[(generation() - 1) % names.size()]) if not Game.s.is_empty() else "MAMMOTH-7"


## best vehicle tier the research has unlocked (the next generation builds this)
func best_tier() -> String:
	var best := "van"
	for t in Data.TIER_ORDER:
		if t == "van" or perk(TIER_PERK[t]) > 0:
			best = t
	return best


func tier_unlocked(t: String) -> bool:
	return t == "van" or perk(TIER_PERK.get(t, "")) > 0


func perk(id: String) -> int:
	if Game.s.is_empty():
		return 0
	return int(m().get("perks", {}).get(id, 0))


func floors() -> int:
	return Game.floors() if not Game.s.is_empty() else 4


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
	p *= Modes.legacy_mult()     # difficulty / mutators pay more, peaceful less
	return maxi(1, int(p))


## MV-559: the transfer authority is the live roster, never the UI's old limited selection.
func all_crew_on() -> bool:
	return Features.on("nextgen_all_crew")


func all_crew_ids() -> Array:
	var ids := []
	for d in Game.s.get("dwellers", []):
		ids.append(int(d.id))
	return ids


func carry_slots() -> int:
	return all_crew_ids().size() if all_crew_on() else 2 + perk("veterans")


func carry_level_keep() -> float:
	if all_crew_on():
		return 1.0
	return [0.5, 0.7, 0.9][clampi(perk("training"), 0, 2)]


func carry_res_ratio() -> float:
	return 0.25


func perk_cost(id: String) -> int:
	var p: Dictionary = PERKS[id]
	var lv := perk(id)
	return int(p.cost[lv]) if lv < p.cost.size() else 0


func can_buy(id: String, legacy: int) -> bool:
	if all_crew_on() and id in ["veterans", "training"]:
		return false
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


## Refund the actual paid ranks, then erase them: reopening/reloading cannot pay twice.
func retired_research_refund() -> int:
	if not all_crew_on():
		return 0
	var total := 0
	for id in ["veterans", "training"]:
		for rank in clampi(perk(id), 0, int(PERKS[id].max)):
			total += int(PERKS[id].cost[rank])
	return total


func refund_retired_research() -> int:
	if not all_crew_on():
		return 0
	var refund := retired_research_refund()
	var mm := m()
	mm.legacy = int(mm.get("legacy", 0)) + refund
	for id in ["veterans", "training"]:
		(mm.get("perks", {}) as Dictionary).erase(id)
	return refund


## bank this run's legacy (once) — called when the Next Generation screen opens
func bank_legacy() -> int:
	if Game.s.get("legacy_banked", false):
		return 0
	var e := legacy_earned()
	m().legacy = int(m().legacy) + e
	m().best_km = maxf(float(m().get("best_km", 0.0)), float(Game.s.stats.km_total))
	Game.s["legacy_banked"] = true
	return e


func story_key() -> String:
	if is_wrecked():
		return "wreck"
	if int(Game.s.get("lap", 0)) > 0:
		return "lap"
	return "retire"


## build the next vehicle. carry_ids = survivors who escape, tier_id = vehicle to build ("" = best unlocked)
func next_generation(carry_ids: Array, tier_id: String = "") -> void:
	if all_crew_on():
		Game._flush_sim() # finish the old vehicle tick before capturing its crew/progress
	refund_retired_research()
	var old := Game.s
	var whole_crew := all_crew_on()
	Account.collect(old)
	var meta: Dictionary = (old.meta as Dictionary).duplicate(true)
	meta.gen = int(meta.gen) + 1
	var carried := []
	if whole_crew:
		carried = (old.dwellers as Array).duplicate(true)
	else:
		for did in carry_ids.slice(0, carry_slots()):
			for d in old.dwellers:
				if int(d.id) == int(did):
					carried.append((d as Dictionary).duplicate(true))
	var res_scrap := float(old.res.scrap) * carry_res_ratio()
	var comps := int(float(old.items.get("components", 0)) * carry_res_ratio())
	# --- fresh state with the meta carried over
	var tid := tier_id if tier_id != "" and tier_unlocked(tier_id) else best_tier()
	Game.s = {"meta": meta, "tier": tid}
	Game.setup_default_state(true, not whole_crew or carried.is_empty())
	# the account (research, perks, blueprints, logbook, memorial, tutorial) carries on as it is
	Account.a.meta = meta
	Account.attach(Game.s)
	Game.s.mode = Account.main_mode()
	var hs := perk("head_start")
	Game.s.res.scrap = minf(Game.cap("scrap"), float(Game.s.res.scrap) + res_scrap + 250.0 * hs)
	Game.s.items["components"] = int(Game.s.items.get("components", 0)) + comps + 20 * hs
	if whole_crew and not carried.is_empty():
		_restore_whole_crew(carried, old)
	for d in ([] if whole_crew else carried):
		var keep := carry_level_keep()
		var nd := Game._add_dweller({"name": d.name, "lore": d.get("lore", ""), "variant": d.variant, "str": d.str, "int": d.int, "agi": d.agi,
			"lvl": maxi(1, int(round(float(d.lvl) * keep)))})
		nd.traits = d.get("traits", [])
		nd["role"] = d.get("role", "")
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


## Keep character/item identities and progress; only assignments and recovery state belong to the old vehicle.
func _restore_whole_crew(carried: Array, old: Dictionary) -> void:
	Crew._deserters.clear()
	Game.s.dwellers = carried
	Game.s.next_id = maxi(1, int(old.get("next_id", 1)))
	Game.s.next_uid = maxi(int(Game.s.next_uid), int(old.get("next_uid", 1)))
	var seats := {Data.CAB_SLOT: 0, 1: 0, 2: 0}
	for d in carried:
		d.id = int(d.id)
		Game.s.next_id = maxi(int(Game.s.next_id), int(d.id) + 1)
		var previous_room := int(d.get("room", -1))
		d.room = -1
		d.away_until = 0.0
		d.hp = float(d.max_hp)
		d.rads = 0.0
		d.infection = 0.0
		d.happy = 75.0
		for key in ["talk_t", "mood_room", "talk_room", "strike", "strike_t", "mood", "desert_t", "desert_warn"]:
			d.erase(key)
		d["veteran"] = int(d.get("veteran", 0)) + 1
		for item in (d.get("gear", {}) as Dictionary).values():
			if item is Dictionary:
				Game.s.next_uid = maxi(int(Game.s.next_uid), int(item.get("uid", 0)) + 1)
		var room_type := ""
		if previous_room == Data.CAB_SLOT:
			room_type = "engine"
		elif previous_room >= 0 and previous_room < old.rooms.size():
			room_type = str(old.rooms[previous_room].type)
		var target := int({"engine": Data.CAB_SLOT, "kitchen": 1, "water": 2}.get(room_type, -1))
		if target >= 0 and int(seats[target]) < (Data.CAB_WORKERS if target == Data.CAB_SLOT else Data.ROOM_WORKERS):
			d.room = target
			seats[target] = int(seats[target]) + 1
	# The new stock turret must not reuse an equipped survivor item's preserved UID.
	var turret: Variant = Game.s.van_gear.get("turret")
	if turret is Dictionary:
		turret.uid = int(Game.s.next_uid)
		Game.s.next_uid = int(Game.s.next_uid) + 1
	for role in mini(3, (old.get("squad", []) as Array).size()):
		var did := int(old.squad[role])
		var d := Game.dweller_by_id(did)
		if not d.is_empty():
			d.room = -1
			Game.s.squad[role] = did
