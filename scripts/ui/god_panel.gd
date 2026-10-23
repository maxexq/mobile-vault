class_name GodPanel
extends ModalPanel
## Tester console ("GOD MODE"). Only reachable when Dev.unlocked. Every button calls a Dev.* action, so the
## same actions are scriptable from tools/autotest.gd and every use lands in the Trace log.
##  tabs: ทั่วไป (switches, speed, time, weather) · ทรัพยากร (+ไอเท็ม/เตาหลอม) · รถ (+ก่อสร้าง) · ลูกเรือ (+ช่าง/คนแปลกหน้า)
##        · ต่อสู้ (+ทีมป้องกัน) · โลก (+สำรับอีเว้นต์/จุดพิเศษ) · ระบบ (บทสอน, เวอร์ชัน, คลาวด์, ตั้งค่า) · LOG/เซฟ

var tab := "main"
var _tabs: HFlowContainer
var _list: VBoxContainer
var _log_cat := ""
var _save_box: TextEdit

const TABS := [["main", "ทั่วไป"], ["res", "ทรัพยากร"], ["veh", "รถ"], ["crew", "ลูกเรือ"], ["fight", "ต่อสู้"], ["world", "โลก"], ["sys", "ระบบ"], ["log", "LOG/เซฟ"]]


func _build() -> void:
	_tabs = UIKit.flow(3)
	body.add_child(_tabs)
	_list = make_list(4)
	Dev.changed.connect(func(): if is_open and tab == "main": refresh())
	Cloud.status_changed.connect(func(): if is_open and tab == "sys": refresh())


func refresh() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for t in TABS:
		var key: String = t[0]
		var b := UIKit.button(t[1], "yellow" if tab == key else "gray")
		b.pressed.connect(func():
			tab = key
			refresh())
		_tabs.add_child(b)
	set_title("GOD MODE / แผงผู้ทดสอบ · " + str(TABS.filter(func(x): return x[0] == tab)[0][1]))
	if not Game.started or Game.s.is_empty():
		_list.add_child(UIKit.wrap_label("เริ่มเกมก่อนแล้วค่อยเปิดแผงนี้", UIKit.FS, UIKit.C_TEXT))
		return
	match tab:
		"main": _tab_main()
		"res": _tab_res()
		"veh": _tab_vehicle()
		"crew": _tab_crew()
		"fight": _tab_fight()
		"world": _tab_world()
		"sys": _tab_sys()
		"log": _tab_log()


# ------------------------------------------------------------------ helpers
func _head(en: String, th: String) -> void:
	_list.add_child(UIKit.header(en, th))


func _row(buttons: Array, label: String = "") -> HFlowContainer:
	var f := UIKit.flow(3)
	if label != "":
		var l := UIKit.label(label, UIKit.FS_SMALL, UIKit.C_DIM)
		l.custom_minimum_size.x = 64
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.add_child(l)
	for b in buttons:
		f.add_child(b)
	_list.add_child(f)
	return f


## button that runs fn, then refreshes the panel (keep_open) or closes it to watch the result
func _b(text: String, fn: Callable, color: String = "gray", close_after: bool = false) -> Button:
	var b := UIKit.button(text, color)
	b.pressed.connect(func():
		fn.call()
		if close_after:
			close()
		else:
			refresh())
	return b


func _note(text: String) -> void:
	_list.add_child(UIKit.wrap_label(text, UIKit.FS_SMALL, UIKit.C_DIM))


# ------------------------------------------------------------------ tabs
func _tab_main() -> void:
	var cheated: bool = Game.s.stats.get("cheated", false)
	_note("ทุกการกดถูกบันทึกลง LOG · เซฟนี้%s" % (" ถูกทำเครื่องหมายว่า 'ใช้ god mode แล้ว'" if cheated else "ยังไม่เคยใช้ god mode"))
	_head("SWITCHES", "สวิตช์โกง (ไม่ถูกเซฟ รีเซ็ตทุกครั้งที่เปิดเกม)")
	for k in Dev.FLAGS:
		var key: String = k
		var on := Dev.on(key)
		var b := UIKit.button(("[ON] " if on else "[OFF] ") + str(Dev.FLAGS[k]), "green" if on else "gray")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): Dev.set_flag(key, not Dev.on(key)))
		_list.add_child(b)
	_head("SPEED", "ความเร็วเกม (จำลองทุกระบบเร็วขึ้น)")
	var sp := []
	for x in Dev.SPEEDS:
		var v: float = x
		sp.append(_b("x%s" % str(v).trim_suffix(".0"), func(): Dev.set_speed(v), "yellow" if Dev.speed == v else "gray"))
	_row(sp)
	_head("FAST-FORWARD", "ข้ามเวลา (จำลองแบบออฟไลน์)")
	_row([_b("+10 นาที", func(): Dev.fast_forward(600.0)), _b("+1 ชม.", func(): Dev.fast_forward(3600.0)), _b("+4 ชม.", func(): Dev.fast_forward(14400.0))])
	_head("TIME / WEATHER", "ช่วงเวลาและสภาพอากาศ")
	_row([_b("เช้า", func(): Dev.set_tod(0.3)), _b("เที่ยง", func(): Dev.set_tod(0.5)), _b("เย็น", func(): Dev.set_tod(0.7)), _b("กลางคืน", func(): Dev.set_tod(0.95))])
	var wb := []
	for w in Data.WEATHER:
		var wid: String = w
		wb.append(_b(str(Data.WEATHER[w].get("th", w)), func(): Dev.weather(wid), "yellow" if Game.s.weather == wid else "gray"))
	_row(wb)
	_head("OVERLAY", "ข้อมูลดีบักบนจอ")
	_row([_b("FPS/ดีบัก: " + ("เปิด" if Dev.overlay else "ปิด"), func(): Dev.set_overlay(not Dev.overlay), "green" if Dev.overlay else "gray"),
		_b("ซ่อนปุ่ม GOD", func(): Dev.lock(), "red", true)])


func _tab_res() -> void:
	_row([_b("เติมทุกอย่างเต็ม", func(): Dev.res_all(true), "green"), _b("ทุกอย่างเป็น 0", func(): Dev.res_all(false), "red")])
	_note("ทดสอบอดอยาก: กด 'เป็น 0' แล้วเร่งเวลา · ทดสอบแบตหมด: ไปแท็บรถ > ไฟดับ")
	_head("RESOURCES", "ปรับทีละอย่าง")
	for k in Game.s.res:
		var key: String = k
		var cur := float(Game.s.res[k])
		_row([_b("0", func(): Dev.res_set(key, 0.0)), _b("-100", func(): Dev.res_set(key, cur - 100.0)),
			_b("+100", func(): Dev.res_set(key, cur + 100.0)), _b("เต็ม", func(): Dev.res_set(key, Game.cap(key)), "green")],
			"%s %d/%d" % [Data.item_name(k), int(cur), int(Game.cap(k))])
	_head("ITEMS", "ไอเท็ม")
	_row([_b("ทุกชนิด +10", func(): Dev.items_all(10), "green"), _b("ทุกชนิด +100", func(): Dev.items_all(100), "green")])
	for k in Data.ITEMS:
		if not str(Data.ITEMS[k].kind) in ["use", "mat"]:
			continue
		var key: String = k
		var cur := int(Game.s.items.get(k, 0))
		_row([_b("0", func(): Dev.res_set(key, 0.0)), _b("+10", func(): Dev.res_set(key, cur + 10.0)), _b("+100", func(): Dev.res_set(key, cur + 100.0))],
			"%s %d" % [Data.item_name(k), cur])
	_head("FORGE", "อุปกรณ์และเตาหลอม (คลัง %d/%d)" % [Loot.stash().size(), Loot.STASH_CAP])
	_row([_b("ชุดทดสอบหลอม (3 ชิ้นทุกระดับ)", func(): Dev.forge_kit(), "green"), _b("ของที่สวมตีบวกสูงสุด", func(): Dev.gear_max_plus(), "yellow")])
	_row([_b("ล้างคลังอุปกรณ์", func(): Dev.stash_clear(), "red")])
	_note("ดรอปทีละระดับอยู่ที่แท็บต่อสู้ > LOOT · เปิดเตาหลอมจริงที่เมนู Loot > หลอม")
	_head("META", "ข้ามรอบ (prestige)")
	_row([_b("พิมพ์เขียวทั้งหมด", func(): Dev.all_blueprints(), "green"), _b("แต้มวิจัย +100", func(): Dev.legacy_add(100))],
		"มี %d แต้ม" % int(Meta.m().get("legacy", 0)))


func _tab_vehicle() -> void:
	_head("CHASSIS", "เปลี่ยนรถทันที (ห้องที่ยังพอดีอยู่ครบ)")
	var tb := []
	for t in Data.TIER_ORDER:
		var tid: String = t
		tb.append(_b(str(Data.VEHICLES[t].th), func(): Dev.set_tier(tid), "yellow" if Game.tier() == tid else "gray"))
	_row(tb)
	_row([_b("0", func(): Dev.set_trailers(0), "yellow" if Game.trailers() == 0 else "gray"), _b("1", func(): Dev.set_trailers(1), "yellow" if Game.trailers() == 1 else "gray"),
		_b("2", func(): Dev.set_trailers(2), "yellow" if Game.trailers() == 2 else "gray")], "โบกี้พ่วง")
	var vb := []
	for n in range(1, Data.MAX_VAULT_LEVEL + 1):
		var lv: int = n
		vb.append(_b(str(lv), func(): Dev.set_vault(lv), "yellow" if int(Game.s.vault_level) == lv else "gray"))
	_row(vb, "Vault Lv")
	_row([_b("100%", func(): Dev.set_hull(1.0), "green"), _b("50%", func(): Dev.set_hull(0.5)), _b("10%", func(): Dev.set_hull(0.1)), _b("0", func(): Dev.set_hull(0.0), "red")],
		"ตัวถัง %d/%d" % [int(Game.s.hull), int(Game.hull_max())])
	_head("ENGINE BAY", "ห้องเครื่อง · %s %d°C สภาพ %d%%" % [EngineBay.t().th, int(EngineBay.heat()), int(EngineBay.cond())])
	_row([_b("40°C", func(): Dev.engine_set("heat", 40.0), "green"), _b("100°C", func(): Dev.engine_set("heat", 100.0)), _b("115°C", func(): Dev.engine_set("heat", 115.0), "red")], "ความร้อน")
	_row([_b("100%", func(): Dev.engine_set("cond", 100.0), "green"), _b("30%", func(): Dev.engine_set("cond", 30.0)), _b("0", func(): Dev.engine_set("cond", 0.0), "red")], "สภาพ")
	_row([_b("น้ำมัน 100", func(): Dev.engine_set("oil", 100.0), "green"), _b("น้ำมัน 10", func(): Dev.engine_set("oil", 10.0)),
		_b("หม้อน้ำ 100", func(): Dev.engine_set("coolant", 100.0), "green"), _b("หม้อน้ำ 0", func(): Dev.engine_set("coolant", 0.0), "red")])
	_row([_b("เครื่องทุกแบบ", func(): Dev.engines_all(), "green"), _b("เครื่องดับ", func(): Dev.engine_breakdown(), "red"),
		_b("หยุดพัก" if EngineBay.resting() else "สั่งพัก", func(): Dev.engine_rest(not EngineBay.resting()), "yellow" if EngineBay.resting() else "gray"),
		_b("งานซ่อมเสร็จ", func(): Dev.engine_finish_job())])
	_head("ROOMS & MODS", "ห้องและมอด")
	_row([_b("สร้างห้องทุกช่องว่าง", func(): Dev.rooms_fill(), "green"), _b("ทุกห้อง Lv สูงสุด", func(): Dev.rooms_max())])
	_head("CONSTRUCTION", "งานก่อสร้าง (กำลังสร้าง %d ห้อง)" % Dev.constructing_count())
	var ib := Dev.on("instant_build")
	_row([_b("เสร็จทันที", func(): Dev.finish_construction(), "yellow"), _b("เร่ง 50%", func(): Dev.construction_progress(0.5)),
		_b(("[ON] " if ib else "[OFF] ") + "สร้างเสร็จทันทีเสมอ", func(): Dev.set_flag("instant_build", not Dev.on("instant_build")), "green" if ib else "gray")])
	_note("ช่างก่อสร้างและ trait ด้านช่าง: แท็บลูกเรือ > BUILDERS")
	_row([_b("มอดเต็มทุกตัว", func(): Dev.mods_all(true), "green"), _b("ถอดมอดทั้งหมด", func(): Dev.mods_all(false))])
	_note("น้ำหนักตอนนี้: " + Haul.status_text())
	_head("HAZARDS", "ทดสอบภัย")
	_row([_b("ไฟช็อต 1 ห้อง", func(): Dev.blackout(false), "gray", true), _b("แบตหมด (ไฟดับทั้งรถ)", func(): Dev.blackout(true), "gray", true)])
	_row([_b("กรดกัดเกราะ", func(): Dev.hazards("acid")), _b("โซลาร์เสียหาย", func(): Dev.hazards("solar")),
		_b("รังสี +40", func(): Dev.hazards("rads")), _b("ติดเชื้อ", func(): Dev.hazards("infect"))])


func _tab_crew() -> void:
	_row([_b("+1 คน", func(): Dev.recruit(1), "green"), _b("+3 คน", func(): Dev.recruit(3), "green"), _b("รักษาทุกคน", func(): Dev.heal_all())])
	_row([_b("สุข 100", func(): Dev.happy_all(100.0)), _b("สุข 20", func(): Dev.happy_all(20.0)), _b("สุข 0", func(): Dev.happy_all(0.0), "red")], "ทุกคน")
	_row([_b("หมา", func(): Dev.add_pet("dog")), _b("แมว", func(): Dev.add_pet("cat")), _b("ไก่", func(): Dev.add_pet("hen")), _b("ล้าง", func(): Dev.clear_pets())],
		"สัตว์เลี้ยง %d" % (Game.s.get("pets", []) as Array).size())
	_head("BUILDERS", "ช่างก่อสร้าง (หมวกเหลือง) + trait ด้านช่าง")
	var bb := [_b("ช่างธรรมดา", func(): Dev.spawn_builder(""), "green")]
	for t in ["engineer", "quick_hands", "architect", "clumsy"]:
		var tid: String = t
		bb.append(_b("ช่าง+" + str(Crew.TRAITS[t].th), func(): Dev.spawn_builder(tid), "red" if Crew.TRAITS[t].get("bad", false) else "gray"))
	_row(bb)
	_head("STRANGERS", "คนแปลกหน้ารอตรวจที่ประตู (คิว %d/%d)" % [Inspection.queue().size(), Inspection.MAX_QUEUE])
	for g in Inspection.GRADES:
		var gid: String = g
		var sb := [_b("สุ่ม", func(): Dev.stranger("", gid))]
		for k in Inspection.KINDS:
			var kid: String = k
			sb.append(_b(str(Inspection.KINDS[k].th), func(): Dev.stranger(kid, gid), "green" if k == "human" else "red"))
		_row(sb, str(Inspection.GRADES[g].th))
	_row([_b("ล้างคิว", func(): Dev.stranger_clear(), "red")])
	_head("CREW", "ทีละคน")
	for d in Game.s.dwellers:
		var dd: Dictionary = d
		var tags := []
		if Game.is_away(dd):
			tags.append("ออกสำรวจ")
		if Crew.is_striking(dd):
			tags.append("ประท้วง")
		_list.add_child(UIKit.label("%s Lv%d · HP %d · สุข %d %s" % [dd.name, dd.lvl, int(dd.hp), int(dd.happy), " · ".join(tags)], UIKit.FS_SMALL, UIKit.C_TEXT))
		var tl := []
		for t in Crew.traits(dd):
			tl.append(str(Crew.TRAITS.get(t, {}).get("th", t)))
		_note(("[ช่าง] " if Crew.is_builder(dd) else "") + ", ".join(tl))
		_row([_b("+5 Lv", func(): Dev.level_up(dd, 5)), _b("ประท้วง", func(): Dev.force_strike(dd)), _b("หนีทันที", func(): Dev.desert_now(dd), "red"),
			_b("ตาย", func(): Dev.kill(dd), "red")])
		_row([_b("เลิกเป็นช่าง" if Crew.is_builder(dd) else "เป็นช่าง", func(): Dev.toggle_builder(dd), "yellow" if Crew.is_builder(dd) else "gray"),
			_b("สุ่ม trait ใหม่", func(): Dev.reroll_traits(dd))])


func _tab_fight() -> void:
	var w := Combat.wave()
	_row([_b("1", func(): Dev.wave_set(1)), _b("-10", func(): Dev.wave_set(w - 10)), _b("-1", func(): Dev.wave_set(w - 1)),
		_b("+1", func(): Dev.wave_set(w + 1)), _b("+10", func(): Dev.wave_set(w + 10))], "เวฟ %d" % w)
	_row([_b("ฆ่าศัตรูทั้งหมด", func(): Dev.kill_enemies(), "red", true), _b("รักษาทีมรบ", func(): Dev.heal_all())])
	_row([_b("ให้ถูกบุกเลย", func(): Dev.force_raid(), "red"), _b("ภัย 0", func(): Dev.threat_set(0.0)), _b("ภัย 90", func(): Dev.threat_set(90.0))],
		"ภัยคุกคาม %d%% · %s" % [int(Threat.threat()), "คลาสสิก" if Threat.classic() else Threat.PHASE_TH.get(Threat.phase, "")])
	var names := []
	for i in (Game.s.squad as Array).size():
		var sd := Game.dweller_by_id(int(Game.s.squad[i]))
		names.append("-" if sd.is_empty() else str(sd.name))
	_head("SQUAD", "ทีมป้องกัน %s (ปลดล็อก %d ช่อง · DPS %d)" % [" / ".join(names), Combat.slots_unlocked(), int(Combat.squad_dps())])
	_row([_b("จัดทีมอัตโนมัติ", func(): Dev.squad_auto(), "green"), _b("ใส่อุปกรณ์ดีสุด", func(): Dev.squad_gear()), _b("ถอดทั้งทีม", func(): Dev.squad_clear(), "red")])
	_head("BOSSES", "เรียกบอส (ปิดแผงเพื่อดูศึก)")
	var bb := [_b("บอสด่าน: " + str(Combat.BOSSES[Combat.biome_id()].th), func(): Dev.spawn_boss("warlord"), "red", true)]
	for id in Combat.WAVE_BOSSES:
		var bid: String = id
		bb.append(_b(str(Combat.WAVE_BOSSES[id].th), func(): Dev.spawn_boss(bid), "gray", true))
	_row(bb)
	_head("MOBS", "เรียกศัตรูทีละชนิด ×3")
	var mb := []
	for id in Combat.MOBS:
		var mid: String = id
		mb.append(_b(str(Combat.MOBS[id].th), func(): Dev.spawn_mob(mid, 3), "yellow" if Combat.MOBS[id].get("mutant", false) else "gray", true))
	_row(mb)
	_head("LOOT", "ดรอปไอเท็มเข้าคลัง ×3")
	var lb := []
	for r in 6:
		var rr: int = r
		var b := _b(str(Loot.rarity(rr).th), func(): Dev.drop_gear(rr, 3))
		b.add_theme_color_override("font_color", Loot.rarity(rr).col)
		lb.append(b)
	_row(lb)


func _tab_world() -> void:
	var bb := []
	for i in Data.BIOMES.size():
		var bi: int = i
		bb.append(_b(str(Data.BIOMES[i].th), func(): Dev.goto_biome(bi), "yellow" if int(Game.s.biome) == bi else "gray"))
	_row(bb)
	_row([_b("ไปด่านตรวจ", func(): Dev.goto_checkpoint()), _b("ผ่านบอสด่านนี้", func(): Dev.beat_warlord()), _b("รอบ +1", func(): Dev.lap_add())],
		"รอบ %d · %.1f กม." % [int(Game.s.get("lap", 0)) + 1, float(Game.s.km)])
	_head("EVENTS", "เรียกอีเว้นต์บนถนน")
	var bag: Array = Game.s.get("ev_bag", []) if int(Game.s.get("ev_bag_biome", -1)) == int(Game.s.biome) else []
	_note("สำรับด่านนี้เหลือ %d ใบ · ล่าสุด: %s" % [bag.size(), ", ".join(Game.s.get("ev_recent", []).map(func(e): return str(Data.EVENTS.get(e, {}).get("th", e))))])
	_row([_b("จั่วใบถัดไป", func(): Dev.event_draw(), "yellow", true), _b("สับสำรับใหม่", func(): Dev.event_deck_reset())])
	var eb := []
	for id in Data.EVENTS:
		var eid: String = id
		eb.append(_b(str(Data.EVENTS[id].get("th", id)), func(): Dev.event(eid), "gray", true))
	_row(eb)
	_head("EXPEDITION", "จุดสำรวจ")
	if Expedition.active():
		_row([_b("จบการสำรวจทันที", func(): Dev.finish_expedition(), "green")])
	if not Expedition.active() or Encounter.state().is_empty() or str(Encounter.state().get("st", "")) == "wait":
		var encb := []
		for id in Encounter.ENCOUNTERS:
			var nid: String = id
			encb.append(_b(str(Encounter.ENCOUNTERS[id].th), func(): Dev.encounter_anywhere(nid), "gray", true))
		_row(encb, "จุดพิเศษ")
		_note("ถ้ายังไม่มีทีมสำรวจ จะส่งทีมคุ้ยซากฟรีให้ก่อน · ห้ามซ้ำ 3 ครั้งล่าสุด: %s" % ", ".join(Encounter.recent().map(func(e): return str(Encounter.def(str(e)).get("th", e)))))
		_row([_b("ล้างประวัติจุดพิเศษ", func(): Dev.encounter_recent_clear())])
	if not Expedition.active():
		var sb := []
		for id in Expedition.SITES:
			var sid: String = id
			sb.append(_b(str(Expedition.SITES[id].th), func(): Dev.arrive(sid), "gray", true))
		_row(sb)
	_head("PRESTIGE", "รุ่นต่อไป")
	var nextgen := UIKit.button("เปิดหน้ารุ่นต่อไป", "yellow")
	nextgen.pressed.connect(_open_nextgen)
	_row([nextgen, _b("รถพังใน 3 วิ", func(): Dev.force_wreck(), "red", true)])


func _tab_sys() -> void:
	_head("VERSION", "เวอร์ชัน")
	for r in BuildInfo.rows().slice(0, 5):
		_note("%s: %s" % [r[0], r[1]])
	var cp := UIKit.button("คัดลอกข้อมูลเวอร์ชัน", "gray")
	cp.pressed.connect(func():
		DisplayServer.clipboard_set(BuildInfo.as_text())
		Game.toast.emit("คัดลอกข้อมูลเวอร์ชันแล้ว", "info"))
	_row([cp])
	_head("TUTORIAL", "บทสอนเล่น")
	var tst := Tutorial.state()
	_note("สถานะ: " + ("กำลังสอน ขั้น %d/%d (%s)" % [Tutorial.step() + 1, Tutorial.STEPS.size(), Tutorial.step_id()] if Tutorial.active()
		else ("จบแล้ว" if bool(tst.get("done", true)) else "ยังไม่เริ่ม")))
	_row([_b("เล่นใหม่ตั้งแต่ต้น", func(): Dev.tutorial_restart(), "green", true), _b("ข้ามบทสอน", func(): Dev.tutorial_skip(), "red")])
	var sb := []
	for st in Tutorial.STEPS:
		var sid: String = st.id
		sb.append(_b(sid, func(): Dev.tutorial_goto(sid), "yellow" if Tutorial.active() and Tutorial.step_id() == sid else "gray", true))
	_row(sb, "ไปขั้น")
	_head("CLOUD SAVE", "เซฟคลาวด์")
	_note("สถานะ: %s · rev %d%s" % [Cloud.status_text(), int(Cloud.meta.get("rev", 0)), "" if Cloud.user_id() == "" else " · " + Cloud.user_id().substr(0, 8)])
	if Cloud.enabled():
		_row([_b("ซิงก์ตอนนี้", func(): Dev.cloud_sync(), "green"), _b("บังคับอัปโหลด", func(): Dev.cloud_force_upload(), "yellow"),
			_b("ลืมการเชื่อมต่อ", func(): Dev.cloud_forget(), "red")])
		if Cloud.state == Cloud.State.CONFLICT:
			_row([_b("ใช้เซฟคลาวด์", func(): Cloud.use_cloud(), "yellow", true), _b("ใช้เซฟเครื่องนี้", func(): Cloud.use_local())], "ชนกัน")
	else:
		_note("บิลด์นี้ไม่มี cloud_config.json จึงเซฟเฉพาะในเครื่อง")
	_head("SETTINGS", "การตั้งค่า")
	_note("ขนาดเซฟ %.1f KB · FPS %s · ภาษา %s" % [Settings.save_size_bytes() / 1024.0, str(Settings.get_value("fps")), str(Settings.get_value("lang"))])
	_row([_b("คืนค่าเริ่มต้น", Dev.settings_reset)])


func _open_nextgen() -> void:
	close()
	(get_parent() as HUD).open_nextgen(false)


func _tab_log() -> void:
	var cats := ["", "error", "god", "build", "event", "combat", "crew", "expedition", "vehicle", "meta", "save", "toast", "sample", "session"]
	var cb := []
	for c in cats:
		var cc: String = c
		cb.append(_b("ทั้งหมด" if c == "" else c, func(): _log_cat = cc, "yellow" if _log_cat == cc else "gray"))
	_row(cb)
	var rows := Trace.filtered(_log_cat)
	var errs := Trace.filtered("error").size()
	_note("session %s · %d รายการ (ข้อผิดพลาด %d) · เก็บล่าสุด %d รายการไว้ในเครื่อง" % [Trace.session, Trace.entries.size(), errs, Trace.KEEP])
	var dl := UIKit.button("ดาวน์โหลด JSON", "green")
	dl.pressed.connect(func(): Game.toast.emit("บันทึก: " + Trace.download(), "info"))
	var cp := UIKit.button("คัดลอก", "gray")
	cp.pressed.connect(_copy_log)
	_row([dl, cp, _b("ล้าง log", func(): Trace.clear(), "red")])
	var box := UIKit.panel(Color("0c0c0e"), UIKit.C_LINE_DARK)
	var v := UIKit.vbox(1)
	box.add_child(v)
	for i in range(rows.size() - 1, maxi(-1, rows.size() - 61), -1):
		var e: Dictionary = rows[i]
		var col := UIKit.C_DIM
		match str(e.cat):
			"error": col = UIKit.C_RED
			"god": col = UIKit.C_GREEN
			"combat": col = UIKit.C_ORANGE
			"crew", "toast": col = UIKit.C_GOLD
		var l := UIKit.label(Trace.fmt_entry(e), UIKit.FS_SMALL, col)
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(l)
	_list.add_child(box)
	_head("SAVE", "เซฟ (ส่งให้ผู้ทดสอบคนอื่นเพื่อทำซ้ำบั๊ก)")
	_save_box = TextEdit.new()
	_save_box.custom_minimum_size = Vector2(0, 70)
	_save_box.placeholder_text = "วาง JSON เซฟตรงนี้แล้วกด 'โหลดจากกล่อง'"
	_save_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_list.add_child(_save_box)
	var ex := UIKit.button("ส่งออกเซฟ", "gray")
	ex.pressed.connect(_export_save)
	var im := UIKit.button("โหลดจากกล่อง", "yellow")
	im.pressed.connect(_import_save)
	var sv := UIKit.button("เซฟตอนนี้", "green")
	sv.pressed.connect(_save_now)
	_row([ex, im, sv])


func _copy_log() -> void:
	DisplayServer.clipboard_set(Trace.export_text())
	Game.toast.emit("คัดลอก log แล้ว", "info")


func _export_save() -> void:
	var t := Dev.export_save()
	_save_box.text = t
	DisplayServer.clipboard_set(t)
	Game.toast.emit("คัดลอกเซฟแล้ว (%d ตัวอักษร)" % t.length(), "info")


func _import_save() -> void:
	if Dev.import_save(_save_box.text):
		Game.toast.emit("โหลดเซฟแล้ว", "good")
		close()
	else:
		Game.toast.emit("JSON เซฟไม่ถูกต้อง", "warn")


func _save_now() -> void:
	Game.save_game()
	Trace.rec("save", "manual save")
	Game.toast.emit("เซฟแล้ว", "good")
