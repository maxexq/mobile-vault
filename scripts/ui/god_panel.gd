class_name GodPanel
extends ModalPanel
## Tester console ("GOD MODE"). Only reachable when Dev.unlocked. Every button calls a Dev.* action, so the
## same actions are scriptable from tools/autotest.gd and every use lands in the Trace log.
##  tabs: ทั่วไป (switches, speed, time, weather) · ทรัพยากร (+ไอเท็ม/เตาหลอม) · รถ (+ก่อสร้าง) · ลูกเรือ (+ช่าง/คนแปลกหน้า)
##        · ต่อสู้ (+ทีมป้องกัน) · โลก (+สำรับอีเว้นต์/จุดพิเศษ) · ฟีเจอร์ (เปิด/ปิดระบบ, อีเว้นต์, ตัวเลข) · ระบบ (บทสอน, เวอร์ชัน, คลาวด์, ตั้งค่า) · LOG/เซฟ

var tab := "main"
var _tabs: HFlowContainer
var _list: VBoxContainer
var _log_cat := ""
var _save_box: TextEdit
var _crew_anim := "idle"       # MV-170 roster preview: animation every preview sprite plays

const TABS := [["main", "ทั่วไป"], ["res", "ทรัพยากร"], ["veh", "รถ"], ["crew", "ลูกเรือ"], ["fight", "ต่อสู้"], ["world", "โลก"], ["feat", "ฟีเจอร์"], ["sys", "ระบบ"], ["icons", "Icons"], ["log", "LOG/เซฟ"]]
const SRC_TH := {"code": "ค่าในโค้ด", "default": "ค่าเริ่มต้น", "build": "บิลด์", "remote": "รีโมต", "mode": "โหมดเกม", "dev": "ผู้ทดสอบ"}


func _build() -> void:
	_tabs = UIKit.flow(3)
	body.add_child(_tabs)
	_list = make_list(4)
	Dev.changed.connect(func(): if is_open and tab == "main": refresh())
	Cloud.status_changed.connect(func(): if is_open and tab == "sys": refresh())
	Features.changed.connect(func(): if is_open and tab == "feat": refresh())
	Modes.changed.connect(func(): if is_open and tab == "sys": refresh())


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
		"feat": _tab_features()
		"sys": _tab_sys()
		"icons": _tab_icons()
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
func _tab_icons() -> void:
	_head("ICON ATLAS", "16x16 / 1x / 2x / 3x")
	var sizes := []
	for scale in [1, 2, 3]:
		var picked: int = scale
		sizes.append(_b("%dx (%d px)" % [picked, picked * 16], func(): Dev.icon_preview(picked), "yellow" if Dev.icon_scale == picked else "gray"))
	_row(sizes)
	var names: Array[String] = []
	for key in Atlas.regions:
		if str(key).begins_with("ic_"):
			names.append(str(key).trim_prefix("ic_"))
	names.sort()
	_note("%d icons / nearest filtering / integer scale" % names.size())
	var grid := GridContainer.new()
	grid.name = "IconGrid"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 8)
	_list.add_child(grid)
	for key in names:
		var cell := VBoxContainer.new()
		cell.name = "ic_" + key
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		var icon := UIKit.icon_rect(key, Dev.icon_scale * 16)
		icon.name = "Icon"
		cell.add_child(icon)
		var label := UIKit.label(key, 9, UIKit.C_DIM)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(label)


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
	_head("SCREEN", "ขนาดจอ")
	_note(Dev.view_info())
	if not OS.has_feature("web"):
		var sizes := [[Vector2i(720, 1280), "มือถือ 720x1280"], [Vector2i(780, 1688), "มือถือ 780x1688"], [Vector2i(1170, 2532), "iPhone 1170x2532"],
			[Vector2i(1280, 640), "แนวนอน 1280x640"], [Vector2i(1366, 1024), "แท็บเล็ต 1366x1024"]]
		var sb := []
		for it in sizes:
			var sz: Vector2i = it[0]
			sb.append(_b(it[1], func(): Dev.window_preset(sz), "gray", true))
		_row(sb, "จำลองจอ")
	_head("SHAKE", "จอสั่น · แรง x%.2f (tune fx.shake) · %s" % [Features.num("fx.shake", 0.5), "เปิด" if bool(Settings.get_value("shake")) else "ปิดในตั้งค่า"])
	_row([_b("สั่นเบา", func(): Dev.shake_test(2.0)), _b("สั่นแรงสุด", func(): Dev.shake_test(6.0), "red")], "ทดสอบ")
	_note("รถสั่น x%.2f (tune fx.engine_shake) · %s" % [Features.num("fx.engine_shake", Vehicle.ENGINE_SHAKE), "เปิด" if bool(Settings.get_value("car_shake")) else "ปิดในตั้งค่า"])
	_row([_b("รถสั่น x1 (แบบเดิม)", func(): Dev.engine_shake(1.0)), _b("x0.5", func(): Dev.engine_shake(0.5)), _b("ค่าเริ่มต้น", func(): Dev.engine_shake(-1.0), "gray")], "รถสั่น")
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
	_head("RAW FOOD", "พืชผลและเนื้อ (MV-247, สวิตช์ raw_food %s)" % ("เปิด" if Data.raw_food() else "ปิด"))
	_row([_b("หมดคลัง (ครัวหยุด)", func(): Dev.raw_food("empty"), "red"), _b("พืช+เนื้อ 100", func(): Dev.raw_food("stock"), "green"),
		_b("ฝูงสัตว์ให้ล่า", func(): Dev.raw_food("hunt"), "yellow")])
	_note("ครัวใช้พืชผล/เนื้อ + น้ำทำอาหาร · ห้องปลูกพืชได้พืชผล · ฆ่าสัตว์กลายพันธุ์ได้เนื้อ (คน ซอมบี้ หุ่นยนต์ไม่ได้)")
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
	_row([_b("แหนบช่วงล่าง: " + ("เปิด" if Features.on("vehicle_detail") else "ปิด"), func(): Dev.vehicle_detail_switch(not Features.on("vehicle_detail")),
		"green" if Features.on("vehicle_detail") else "red")], "รายละเอียดรถ MV-388 (ล้อ/สนิม/แผ่นปะอบในภาพแล้ว)")
	_head("ENGINE BAY", "ห้องเครื่อง · %s %d°C สภาพ %d%%" % [EngineBay.t().th, int(EngineBay.heat()), int(EngineBay.cond())])
	_row([_b("ระบบห้องเครื่อง: " + ("เปิด" if EngineBay.on() else "ปิด (ดีเซลเดิม)"), func(): Dev.engine_bay_switch(not EngineBay.on()),
		"green" if EngineBay.on() else "red", true)], "สวิตช์")
	_row([_b("ห้องเครื่องมีชีวิต: " + ("เปิด" if Features.on("vehicle_ambience") else "ปิด"), func(): Dev.vehicle_ambience_switch(not Features.on("vehicle_ambience")),
		"green" if Features.on("vehicle_ambience") else "red"), _b("ไอร้อนพุ่ง 1 ครั้ง", func(): Dev.vent_preview(), "gray", true)],
		"MV-388 พัดลม/ท่อ/ไอร้อน (ไอร้อนแบบใหม่ขึ้นเฉพาะ 115°C)")
	_row([_b("ควันท่อ", func(): Dev.vehicle_fx_preview("puff"), "gray", true), _b("หยดฝน (ต้องฝนตก)", func(): Dev.vehicle_fx_preview("drip"), "gray", true),
		_b("บังโคลนสะบัด", func(): Dev.vehicle_fx_preview("flap"), "gray", true)], "MV-388 ธง/โซ่/บังโคลน/ควัน/หยดฝน")
	_row([_b("40°C", func(): Dev.engine_set("heat", 40.0), "green"), _b("100°C", func(): Dev.engine_set("heat", 100.0)), _b("115°C", func(): Dev.engine_set("heat", 115.0), "red")], "ความร้อน")
	_row([_b("100%", func(): Dev.engine_set("cond", 100.0), "green"), _b("30%", func(): Dev.engine_set("cond", 30.0)), _b("0", func(): Dev.engine_set("cond", 0.0), "red")], "สภาพ")
	_row([_b("น้ำมัน 100", func(): Dev.engine_set("oil", 100.0), "green"), _b("น้ำมัน 10", func(): Dev.engine_set("oil", 10.0)),
		_b("หม้อน้ำ 100", func(): Dev.engine_set("coolant", 100.0), "green"), _b("หม้อน้ำ 0", func(): Dev.engine_set("coolant", 0.0), "red")])
	_row([_b("เครื่องทุกแบบ", func(): Dev.engines_all(), "green"), _b("เครื่องดับ", func(): Dev.engine_breakdown(), "red"),
		_b("หยุดพัก" if EngineBay.resting() else "สั่งพัก", func(): Dev.engine_rest(not EngineBay.resting()), "yellow" if EngineBay.resting() else "gray"),
		_b("งานซ่อมเสร็จ", func(): Dev.engine_finish_job())])
	_head("ROOMS & MODS", "ห้องและมอด")
	_row([_b("สร้างห้องทุกช่องว่าง", func(): Dev.rooms_fill(), "green"), _b("ทุกห้อง Lv สูงสุด", func(): Dev.rooms_max())])
	_row([_b("ไฟทุกห้องกะพริบ", func(): Dev.lamps_flicker(), "gray", true)], "แสง/อนิเมชันห้อง")
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
	_crew_roster()
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


## MV-170: every named crew sprite (any animation) + portrait, and a button that boards that one
func _crew_roster() -> void:
	_head("CREW ROSTER", "ลูกเรือมีชื่อ 20 คน · สวิตช์ %s · โอกาส %d%%" % ["เปิด" if Features.on("crew_roster_20") else "ปิด",
		roundi(Features.num("crew.roster_chance", Crew.ROSTER_CHANCE) * 100.0)])
	var ab := []
	for a in Atlas.DW_FRAMES:
		var an: String = a
		ab.append(_b(an, func(): _crew_anim = an, "yellow" if an == _crew_anim else "gray"))
	_row(ab, "ท่า")
	_row([_b("ขึ้นรถครบทุกคน", func(): Dev.spawn_roster_all(), "green"), _b("โอกาส 100%", func(): Dev.roster_chance(1.0)),
		_b("โอกาส 0%", func(): Dev.roster_chance(0.0)), _b("โอกาสค่าเดิม", func(): Dev.roster_chance(-1.0))])
	var grid := UIKit.flow(3)
	grid.name = "RosterGrid"
	for id in Data.CREW_ROSTER:
		var rid: String = id
		var r: Dictionary = Data.CREW_ROSTER[rid]
		var cell := VBoxContainer.new()
		cell.name = "crew_" + rid
		cell.add_theme_constant_override("separation", 1)
		var top := HBoxContainer.new()
		var stage := Control.new()
		stage.custom_minimum_size = Vector2(Atlas.DW_W * 2, Atlas.DW_H * 2)
		var spr := AnimatedSprite2D.new()
		spr.name = "Sprite"
		spr.sprite_frames = Atlas.dweller_frames("dw_crew_" + rid)
		spr.centered = false
		spr.scale = Vector2(2, 2)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		stage.add_child(spr)
		spr.play(_crew_anim)
		top.add_child(stage)
		top.add_child(UIKit.tex_rect(Atlas.tex("pt_dw_crew_" + rid), Vector2(20, 20)))
		cell.add_child(top)
		cell.add_child(UIKit.label(("★ " if r.cameo else "") + str(r.name), UIKit.FS_SMALL, UIKit.C_TEXT))
		cell.add_child(_b("ขึ้นรถ", func(): Dev.spawn_roster(rid), "green"))
		grid.add_child(cell)
	_list.add_child(grid)


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
	_row([_b("วอร์ลอร์ด", func(): Dev.entrance_preview("warlord"), "red", true), _b("บอส", func(): Dev.entrance_preview("boss"), "yellow", true),
		_b("อีลิท", func(): Dev.entrance_preview("elite"), "gray", true), _b("เรียกอีลิท ×3", func(): Dev.spawn_elites(3), "gray", true)],
		"เปิดตัวบอส (MV-387)%s" % ("" if Features.on("boss_intro") else " · ปิดอยู่"))
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
	_row([_b("ดรอปถัดไปได้มหากาพย์+", func(): Dev.pity_next(3), "yellow"), _b("ดรอปถัดไปได้ตำนาน+", func(): Dev.pity_next(4), "yellow"),
		_b("รีเซ็ตตัวนับ", func(): Dev.pity_reset())],
		"การันตี (MV-47) อีก %d / %d ดรอป%s" % [Loot.pity_left(3), Loot.pity_left(4), "" if Features.on("loot_pity") else " · ปิดอยู่"])


func _tab_world() -> void:
	_head("INDUSTRIAL SKY", "ฉากนิคมอุตสาหกรรมใหม่ (MV-369) ตามเวลาในเกม")
	_row([_b("รุ่งเช้า", func(): Dev.background_preview(0.25)), _b("กลางวัน", func(): Dev.background_preview(0.5)), _b("พระอาทิตย์ตก", func(): Dev.background_preview(0.75)), _b("กลางคืน", func(): Dev.background_preview(0.0))])
	_row([_b("ฉากใหม่", func(): Dev.feature_set("industrial_parallax", true), "green"), _b("ฉากเดิม", func(): Dev.feature_set("industrial_parallax", false), "gray")])
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
	_note("จับเวลาตัดสินใจ: %s · ตั้งค่า %s · x%.2f" % ["เปิด" if Features.on("event_timer") else "ปิด", str(Settings.get_value("event_timer")), Features.num("events.decide_scale", 1.0)])
	_row([_b("อีเว้นต์สุ่ม หมดเวลาใน 2 วิ", func(): Dev.event_quick_timeout(), "red", true)], "จับเวลา")
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
	_head("ACCOUNT", "ไอดีถาวร")
	_note("รุ่นที่ %d · ความยาก %s · บันทึก %d · อนุสรณ์ %d%s" % [Meta.generation(), str(Modes.DIFFS.get(Account.diff(), {}).get("th", Account.diff())),
		Account.a.get("lore", []).size(), Account.a.get("memorial", []).size(), " · มาจากเซฟเก่า" if Account.a.has("legacy_mode") else ""])
	_row([_b("จำลองเซฟเก่า v1 แล้วย้ายเข้าไอดี", Dev.account_v1_reload, "yellow", true)])
	_head("GAME MODE", "กฎของรถคันนี้ (ไว้ทดสอบอีเว้นท์ · เปลี่ยน = ไม่นับอันดับ)")
	_note("ตอนนี้: %s · แต้มวิจัย ×%.2f · %s" % [Modes.label(), Modes.legacy_mult(), "นับอันดับได้" if Modes.ranked() else "ไม่นับอันดับ"])
	var mb := []
	for k in Modes.MODES:
		var mid: String = k
		mb.append(_b(str(Modes.MODES[k].th), func(): Dev.mode_set(mid), "yellow" if Modes.id() == mid else "gray"))
	_row(mb, "โหมด")
	var db := []
	for k in Modes.DIFFS:
		var did: String = k
		db.append(_b(str(Modes.DIFFS[k].th), func(): Dev.mode_set("", did), "yellow" if Modes.diff() == did else "gray"))
	_row(db, "ความยาก")
	var xb := []
	for k in Modes.MUTATORS:
		var key: String = k
		xb.append(_b(str(Modes.MUTATORS[k].th), func(): Dev.mode_set("", "", key), "green" if Modes.has_mut(key) else "gray"))
	_row(xb, "ตัวแปร")
	if Modes.peaceful():
		_row([_b("ไปด่านตรวจ + เงินค่าผ่านทาง", Dev.mode_toll_test, "yellow", true)])
	_head("VERSION", "เวอร์ชัน")
	for r in BuildInfo.rows().slice(0, 5):
		_note("%s: %s" % [r[0], r[1]])
	var chb := []
	for ch in BuildInfo.CHANNELS:
		var cid: String = ch
		chb.append(_b(cid, func(): Dev.channel_preview(cid), "yellow" if BuildInfo.channel_preview == cid else "gray"))
	chb.append(_b("ของจริง", func(): Dev.channel_preview(""), "green" if BuildInfo.channel_preview == "" else "gray"))
	_row(chb, "ดูป้ายช่อง")
	_note("สภาพแวดล้อม: %s · เซิร์ฟเวอร์ %s · ไฟล์ตั้งค่ารีโมต %s%s" % [BuildInfo.env().to_upper(), BuildInfo.cloud_project(),
		Features.remote_files(BuildInfo.env())[0], (" · " + BuildInfo.page_host()) if BuildInfo.page_host() != "" else ""])
	var eb := []
	for e in BuildInfo.ENVS:
		var eid: String = e
		eb.append(_b(eid, func(): Dev.env_preview(eid), "yellow" if BuildInfo.env_preview == eid else "gray"))
	eb.append(_b("ของจริง", func(): Dev.env_preview(""), "green" if BuildInfo.env_preview == "" else "gray"))
	_row(eb, "ดูป้าย env")
	_note("ภาษา: %s · แปลอังกฤษแล้ว %d / %d ข้อความ (สวิตช์ english %s)" % [Loc.lang().to_upper(), Loc.translation.get_message_count(),
		Loc.translation.get_message_count() + Loc.missing, "เปิด" if Features.on("english") else "ปิด"])
	_row([_b("ไทย", func(): Dev.lang_set("th"), "yellow" if Loc.lang() == "th" else "gray"),
		_b("English", func(): Dev.lang_set("en"), "yellow" if Loc.lang() == "en" else "gray")], "ภาษา")
	_head("ANNOUNCE", "แถบประกาศตัวอักษรวิ่งบนจอ (MV-188)")
	var ver := Announce.latest
	_note("ข้อความจาก features.json ที่เปิดอยู่ %d · เห็นแล้ว %d · รอคิว %d · version.json ล่าสุด: %s" % [Features.announcements().size(),
		Announce.seen.size(), Announce.queue.size(), ("v%s · %s" % [ver.get("version", "?"), ver.get("built", "?")]) if not ver.is_empty() else "ยังไม่ได้อ่าน"])
	_row([_b("ประกาศทดสอบ", func(): Dev.announce_test(), "green", true), _b("แจ้งเวอร์ชันใหม่", func(): Dev.announce_update_test(), "yellow", true),
		_b("เช็กตอนนี้", func(): Dev.announce_poll(), "gray"), _b("ลืมที่เคยเห็น", func(): Dev.announce_forget_seen(), "gray")])
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
	var tips_seen: Array = Tutorial.state().get("tips", [])
	_note("คำแนะนำครั้งแรก: เห็นแล้ว %d / %d%s" % [tips_seen.size(), Tutorial.TIPS.size(), "" if Tutorial.tips_on() or Tutorial.active() else " (ปิดอยู่)"])
	var tip_btns := [_b("รีเซ็ตคำแนะนำ", func(): Dev.tips_reset(), "yellow", true)]
	for k in Tutorial.TIPS:
		var tk: String = k
		tip_btns.append(_b(tk, func(): Dev.tip_show(tk), "green" if tips_seen.has(tk) else "gray"))
	_row(tip_btns, "คำแนะนำ")
	_head("CLOUD SAVE", "เซฟคลาวด์")
	_note("สถานะ: %s · rev %d%s" % [Cloud.status_text(), int(Cloud.meta.get("rev", 0)), "" if Cloud.user_id() == "" else " · " + Cloud.user_id().substr(0, 8)])
	_note("ไอดีผู้เล่น: " + (Cloud.player_id() if Cloud.player_id() != "" else ("- (สวิตช์ player_id ปิดอยู่)" if not Features.on("player_id") else "- (ยังไม่มีบัญชี)")))
	if Cloud.user_id() != "":
		_row([_b("คัดลอกไอดีผู้เล่น + user id", func(): Dev.player_id_copy(), "gray", true)], "ไอดี")
	if Cloud.enabled():
		_row([_b("ซิงก์ตอนนี้", func(): Dev.cloud_sync(), "green"), _b("บังคับอัปโหลด", func(): Dev.cloud_force_upload(), "yellow"),
			_b("ลืมการเชื่อมต่อ", func(): Dev.cloud_forget(), "red")])
		_row([_b("รีเฟรชหน้าเว็บ", func(): Dev.reload_page(), "gray", true)], "รีเฟรช")
		if Cloud.state == Cloud.State.CONFLICT:
			_row([_b("ใช้เซฟคลาวด์", func(): Cloud.use_cloud(), "yellow", true), _b("ใช้เซฟเครื่องนี้", func(): Cloud.use_local())], "ชนกัน")
	else:
		_note("บิลด์นี้ไม่มี cloud_config.json จึงเซฟเฉพาะในเครื่อง")
	_head("CLOUD LOGS", "log บนเซิร์ฟเวอร์")
	var why := "" if Telemetry.active() else (" · ไม่ทำงาน: " + ("สวิตช์ cloud_logs ปิด" if not Features.on("cloud_logs")
		else ("ผู้เล่นปิดในตั้งค่า" if not bool(Settings.get_value("telemetry")) else "คลาวด์ยังไม่ได้เชื่อมต่อ")))
	_note("ค้างส่ง %d · ส่งแล้ว %d%s%s%s" % [Telemetry.pending().size(), Telemetry.sent_total,
		" · ล่าสุด " + Time.get_datetime_string_from_unix_time(int(Telemetry.last_sent_at + 7 * 3600), true) if Telemetry.last_sent_at > 0.0 else "",
		"" if bool(Cloud.meta.get("log_notice", false)) else " · ยังไม่แสดงประกาศ", why])
	if Telemetry.last_error != "":
		_note("ผิดพลาดล่าสุด: " + Telemetry.last_error)
	_row([_b("ส่ง log ตอนนี้", func(): Dev.logs_flush(), "green"), _b("ส่ง error ทดสอบ", func(): Dev.logs_test_error(), "yellow")])
	_head("GAMEANALYTICS", "สถิติบน GameAnalytics (MV-423)")
	_note("สถานะ: %s · โปรเจกต์ %s · เซ็นโดย %s · คิว %d · ส่งแล้ว %d · error ที่ส่งรอบนี้ %d/%d%s" % [Analytics.status(), BuildInfo.cloud_project(), Analytics.mode(),
		Analytics.queue.size(), Analytics.sent_total, Analytics.errors_sent, Analytics.ERRORS_MAX,
		"" if Analytics.last_error == "" else " · ผิดพลาดล่าสุด: " + Analytics.last_error])
	_row([_b("ส่ง event ทดสอบ (Test:GodMode)", func(): Dev.ga_test_event(), "green")])
	_head("OUTBOX", "คิวส่งขึ้นเซิร์ฟเวอร์ (MV-424)")
	var ob: Dictionary = Outbox.lane(Outbox.SUPABASE)
	_note("%s · ล้มเหลวติดกัน %d · รอคิว %d · ผ่าน %d · พักไปแล้ว %d ครั้ง · คำตอบล่าสุด %s%s" % [
		"เปิด" if Outbox.open(Outbox.SUPABASE) else "พักอยู่อีก %d วิ" % ceili(Outbox.hold_left(Outbox.SUPABASE)),
		int(ob.fails), (ob.waiting as Array).size(), int(ob.ok), int(ob.holds),
		"-" if int(ob.last_code) < 0 else ("ไม่ตอบ" if int(ob.last_code) == 0 else str(ob.last_code)),
		"" if Outbox.on() else " · สวิตช์ server_outbox ปิด (ส่งตรงแบบเดิม)"])
	_row([_b("จำลองเซิร์ฟเวอร์ล่ม (503)", func(): Dev.outbox_fail(), "yellow"), _b("เปิดคิวตอนนี้", func(): Dev.outbox_open(), "green")])
	_head("ANTI-CHEAT", "กันโกง (MV-174)")
	var seen := "ยังไม่รู้ (คลาวด์ยังไม่ตอบ)" if Cloud.server_seen <= 0.0 else Time.get_datetime_string_from_unix_time(int(Cloud.server_seen + 7 * 3600), true)
	_note("เซิร์ฟเวอร์รับเซฟล่าสุด: %s · เวลาจำลองสะสม %.1f ชม. · ถูกจำกัดความถี่ %d ครั้ง%s" % [seen,
		float(Account.a.get("life", {}).get("sim_sec", 0.0)) / 3600.0, Cloud.rate_limited, "" if Features.on("anticheat") else " · สวิตช์ anticheat ปิด"])
	_row([_b("ทดสอบโกงเวลา (saved_at -4 ชม.)", func(): Dev.anticheat_time_test(), "yellow", true)])
	if Cloud.enabled():
		_row([_b("อัปโหลดซ้อน 2 ครั้ง (ทดสอบจำกัดความถี่)", func(): Dev.anticheat_rate_test(), "yellow", true)])
	_head("SETTINGS", "การตั้งค่า")
	_note("ขนาดเซฟ %.1f KB · FPS %s · ภาษา %s" % [Settings.save_size_bytes() / 1024.0, str(Settings.get_value("fps")), str(Settings.get_value("lang"))])
	_row([_b("คืนค่าเริ่มต้น", Dev.settings_reset)])
	_row([_b("ทดสอบหน้าต่างยืนยัน", Dev.confirm_preview, "red", true)])


func _tab_features() -> void:
	var st := {"off": "ปิด (เว็บเท่านั้น)", "cached": "ใช้แคช", "loading": "กำลังโหลด", "ok": "โหลดแล้ว", "failed": "โหลดไม่ได้", "rejected": "ไม่ใช่ของเวอร์ชันนี้"}
	var at := "" if Features.remote_at <= 0.0 or not Features.remote_status in ["ok", "cached"] else " · " + Time.get_datetime_string_from_unix_time(int(Features.remote_at + 7 * 3600), true) + " (เวลาไทย)"
	_note("ลำดับ: ค่าเริ่มต้น (config/features.json) → บิลด์ → รีโมต (features.json บนเว็บ) → โหมดเกม → ผู้ทดสอบ (ตรงนี้ / ?ff=) · รีโมต: %s%s" % [st.get(Features.remote_status, Features.remote_status), at])
	_row([_b("ล้างค่าผู้ทดสอบทั้งหมด", Dev.features_reset, "red"), _b("โหลดรีโมตใหม่", Dev.features_refetch, "yellow")])
	_head("FEATURES", "เปิด/ปิดระบบ (กดเพื่อสลับ · ค้างไว้ในเครื่องนี้จนกว่าจะล้าง)")
	for k in Features.FEATURES:
		var key: String = k
		var on := Features.on(key)
		var src := Features.source("features", key)
		var b := _b(("[ON] " if on else "[OFF] ") + str(Features.FEATURES[k]) + " · " + str(SRC_TH.get(src, src)),
			func(): Dev.feature_set(key, not Features.on(key)), "green" if on else "red")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(b)
	_head("ROAD EVENTS", "อีเว้นต์บนถนนรายตัว (* = อยู่ในไบโอมนี้ · เขียว = เปิด)")
	var here: Array = Data.biome(int(Game.s.biome)).events
	var ok_now := Features.event_pool(int(Game.s.biome), here)
	_note("ไบโอมนี้สุ่มได้ %d อีเว้นต์: %s" % [ok_now.size(), ", ".join(ok_now)])
	var eb := []
	for id in Data.EVENTS:
		var eid: String = id
		var cfg := Features.event_cfg(eid)
		var on := bool(cfg.get("on", true))
		var w := Features.event_weight(eid)
		var txt := ("* " if here.has(eid) else "") + eid + ("" if w == 1.0 else " x%s" % str(w)) + ("" if not (cfg.has("from") or cfg.has("to")) else " [วันที่]")
		eb.append(_b(txt, func(): Dev.event_set(eid, not bool(Features.event_cfg(eid).get("on", true))), "green" if on else "red"))
	_row(eb)
	_head("TUNE", "ตัวเลขบาลานซ์ (ค่าที่ใช้อยู่ · ที่มา)")
	for k in Features.TUNE:
		var key: String = k
		var spec: Array = Features.TUNE[k]
		var src := Features.source("tune", key)
		var cur = Features.num(key, -1.0) if src != "code" else null
		var lbl := "%s: %s · %s" % [spec[2], "ค่าในโค้ด" if cur == null else str(snappedf(cur, 0.001)), SRC_TH.get(src, src)]
		_list.add_child(UIKit.wrap_label(lbl, UIKit.FS_SMALL, UIKit.C_TEXT))
		var base: float = cur if cur != null else _tune_code_default(key)
		_row([_b("÷2", func(): Dev.tune_set(key, base * 0.5)), _b("×2", func(): Dev.tune_set(key, base * 2.0)),
			_b("ค่าเดิม", func(): Dev.tune_set(key, null))])


## the constant a tune key replaces, so the ÷2 / ×2 buttons start from the real number
func _tune_code_default(key: String) -> float:
	match key:
		"events.gap_min": return Game.EVENT_GAP.x
		"events.gap_max": return Game.EVENT_GAP.y
		"threat.rate_scale": return Threat.RATE_SCALE
		"threat.roll_k": return Threat.ROLL_K
		"threat.min_quiet": return Threat.MIN_QUIET
		"encounter.base_chance": return Encounter.BASE_CHANCE
		"encounter.danger_chance": return Encounter.DANGER_CHANCE
		"inspection.rare_chance": return Inspection.RARE_CHANCE
		"inspection.very_rare_chance": return Inspection.VERY_RARE_CHANCE
		"ambience.flicker": return RoomAmbience.FLICKER_PM
		"crew.roster_chance": return Crew.ROSTER_CHANCE
		"crew.cameo_weight": return Crew.CAMEO_WEIGHT
	return 1.0


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
