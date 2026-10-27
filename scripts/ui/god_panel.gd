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

const TABS := [["main", "ทั่วไป"], ["res", "ทรัพยากร"], ["veh", "รถ"], ["crew", "ลูกเรือ"], ["fight", "ต่อสู้"], ["world", "โลก"], ["feat", "ฟีเจอร์"], ["sys", "ระบบ"], ["sound", "เสียง"], ["icons", "Icons"], ["log", "LOG/เซฟ"]]
const SRC_TH := {"code": "ค่าในโค้ด", "default": "ค่าเริ่มต้น", "build": "บิลด์", "remote": "รีโมต", "mode": "โหมดเกม", "dev": "ผู้ทดสอบ"}


func _build() -> void:
	_tabs = UIKit.flow(3)
	body.add_child(_tabs)
	_list = make_list(4)
	Dev.changed.connect(func(): if is_open and tab == "main": refresh())
	Cloud.status_changed.connect(func(): if is_open and tab == "sys": refresh())
	Features.changed.connect(func(): if is_open and tab == "feat": refresh())
	Modes.changed.connect(func(): if is_open and tab == "sys": refresh())
	closed.connect(func(): if not Sound.preview.is_empty(): Dev.sound_preview("clear"))      # MV-538


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
		"sound": _tab_sound()
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
	_gear_slots_preview()
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


## MV-473: every rarity at every tile width with real icons, the empty / locked / +N / disabled states, and the
## presentation (switches / base / neon / aura / still) with frame stepping
func _gear_slots_preview() -> void:
	_head("EQUIPMENT SLOTS", "ช่องอุปกรณ์เหล็ก + แสงตามความหายาก (MV-473) · gear_slot_style %s · gear_slot_vfx %s · ตอนนี้ %s" % [
		"เปิด" if Features.on("gear_slot_style") else "ปิด", "เปิด" if Features.on("gear_slot_vfx") else "ปิด", GearFx.presentation()])
	var modes := []
	for m in [["", "ตามสวิตช์"], ["base", "ฐาน"], ["neon", "นีออน"], ["aura", "ออร่า"], ["still", "นิ่ง"]]:
		var mm: String = m[0]
		modes.append(_b(m[1], func(): Dev.gear_preview(mm), "yellow" if GearFx.preview == mm else "gray"))
	_row(modes, "แสดง")
	_row([_b("เฟรมถัดไป", func(): Dev.gear_step(), "green"), _b("เล่นต่อ", func(): Dev.gear_preview(GearFx.preview), "gray")],
		"เฟรม %d/16%s" % [GearFx.current_phase() + 1, " (หยุด)" if GearFx.paused_preview else ""])
	var slots := ["weapon", "armor", "helmet", "boots", "gadget", "backpack"]
	var grid := GridContainer.new()
	grid.name = "GearSlotGrid"
	grid.columns = GearFx.WIDTHS.size()
	grid.add_theme_constant_override("h_separation", UIKit.gear_gap(6))
	grid.add_theme_constant_override("v_separation", UIKit.gear_gap(6))
	for r in 6:
		for j in GearFx.WIDTHS.size():
			var w: int = GearFx.WIDTHS[j]
			grid.add_child(UIKit.gear_tile(Dev.gear_sample(r, slots[(r + j) % slots.size()], r if j % 2 == 0 else 0, r == 2), slots[(r + j) % slots.size()], w))
	for j in GearFx.WIDTHS.size():
		var w: int = GearFx.WIDTHS[j]
		var t := UIKit.gear_tile({} if j < 3 else Dev.gear_sample(j, slots[j]), slots[j], w)
		t.disabled = j >= 3
		grid.add_child(t)
	_list.add_child(UIKit.gear_pad(grid))
	_note("แถว: ทั่วไป · ดี · หายาก (ล็อก) · มหากาพย์ · ตำนาน · ปฐมกาล · ล่างสุด: ช่องว่าง 3 ขนาด + ปุ่มกดไม่ได้ · คอลัมน์ 28 / 30 / 32 / 36 / 40 px")


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
			[Vector2i(1280, 640), "แนวนอน 1280x640"], [Vector2i(1366, 1024), "แท็บเล็ต 1366x1024"],
			[Vector2i(768, 1024), "แท็บเล็ต 768x1024"], [Vector2i(1024, 768), "โน้ตบุ๊ก 1024x768"], [Vector2i(1366, 768), "โน้ตบุ๊ก 1366x768"],
			[Vector2i(2560, 1440), "จอใหญ่ 2560x1440"]]     # MV-266
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
	_head("ROOM EXPANSION", "ห้องใหม่ชุดขยาย (MV-428 / MV-429)")
	var regd: Array = RoomX.DEFS.keys() + RoomX.extra.keys()
	_note("สวิตช์ rooms_expansion %s · ลงทะเบียนแล้ว %d ห้อง · สร้างได้ตอนนี้ %d · งานค้าง %d · แอนิเมชัน: %s%s" % [
		"เปิด" if RoomX.on() else "ปิด", regd.size(), RoomX.buildable().size(), RoomX.jobs().size(),
		"สด" if RoomAnim.preview == "" else RoomAnim.preview, " (หยุดเฟรม)" if RoomAnim.paused_preview else ""])
	if not regd.is_empty():
		var rb := []
		for t in regd:
			var tt: String = t
			rb.append(_b(str(RoomX.room_def(tt).get("th", tt)), func(): Dev.rx_build(tt), "green"))
		_row(rb, "สร้างทันที")
	for k in RoomX.jobs():
		var j: Dictionary = RoomX.jobs()[k]
		var why := RoomX.paused_why(j)
		_note("งาน #%d %s · %s · %d%%%s%s" % [int(j.id), str(j.room), str(j.kind), int(RoomX.progress(j) * 100.0),
			" · เสร็จ รอรับ" if bool(j.done) else "", (" · หยุด: " + why) if why != "" and not bool(j.done) else ""])
	_row([_b("งานเสร็จทันที", func(): Dev.rx_finish_jobs(), "green"), _b("ยกเลิกงานทั้งหมด", func(): Dev.rx_drop_jobs(), "red")], "งาน")
	_note("โรงเตี๊ยม (MV-430): กินไปแล้ว %d มื้อ · ติดคูลดาวน์ %d คน · สายสัมพันธ์ %d คู่" % [int(Saloon.st().get("meals", 0)),
		(Saloon.st().get("cd", {}) as Dictionary).size(), (Saloon.st().get("bonds", {}) as Dictionary).size()])
	_row([_b("เริ่มมื้อเย็น", func(): Dev.saloon_supper(), "green"), _b("รับมื้อที่เสร็จ", func(): Dev.saloon_claim_all(), "yellow"),
		_b("ล้างคูลดาวน์", func(): Dev.saloon_clear_cd(), "gray")], "โรงเตี๊ยม")
	_row([_b("สด", func(): Dev.rx_anim_preview(""), "yellow" if RoomAnim.preview == "" else "gray"),
		_b("ท่าพัก", func(): Dev.rx_anim_preview("rest"), "yellow" if RoomAnim.preview == "rest" else "gray"),
		_b("ทำงาน", func(): Dev.rx_anim_preview("active"), "yellow" if RoomAnim.preview == "active" else "gray"),
		_b("เฟรมถัดไป", func(): Dev.rx_anim_step(), "green")], "แอนิเมชัน")
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
	var vv2 := Features.on("vault_upgrade_v2")
	_note("โครงรถ (MV-545) %s · ห้อง %d/%d (รถ %s %d ชั้น) · ห้องที่รอรถคันใหญ่ %d · ตัวถัง +%d · การผลิต ×%.2f" % ["แบบใหม่" if vv2 else "แบบเดิม",
		Game.vault_rooms_at(int(Game.s.vault_level)), Game.main_slots() - 1, Game.tier(), Game.floors(), Game.vault_banked_rooms(),
		roundi(Game.vault_hull_bonus()), Game.vault_prod_mult()])
	if int(Game.s.vault_level) < Data.MAX_VAULT_LEVEL:
		_note("การ์ดอัปเกรด: " + BuildPanel.vault_card_text(int(Game.s.vault_level), "", ""))
	_row([_b("แบบเดิม" if vv2 else "แบบใหม่", func(): Dev.vault_upgrade_v2(not vv2), "yellow" if vv2 else "gray")], "อัปเกรดโครงรถ")
	_row([_b("100%", func(): Dev.set_hull(1.0), "green"), _b("50%", func(): Dev.set_hull(0.5)), _b("10%", func(): Dev.set_hull(0.1)), _b("0", func(): Dev.set_hull(0.0), "red")],
		"ตัวถัง %d/%d" % [int(Game.s.hull), int(Game.hull_max())])
	var rv2 := Features.on("hull_repair_v2")
	var dc: Dictionary = Game.repair_discount()
	_note("ค่าซ่อม (MV-541) %s · %.3f เศษเหล็ก/HP · ส่วนลด %d%% (ลูกเรือ %d · ช่าง %d · skill %d · อู่ %d, สูงสุด %d) · ซ่อมเอง +%.1f HP/นาที · เต็ม %d · 25%% %d" % [
		"แบบใหม่" if rv2 else "แบบเดิม", Game.repair_rate(), roundi(float(dc.total) * 100.0), roundi(float(dc.crew) * 100.0),
		roundi(float(dc.mechanic) * 100.0), roundi(float(dc.skill) * 100.0), roundi(float(dc.bay) * 100.0),
		roundi(Features.num("repair.discount_cap", 0.4) * 100.0), Game.hull_regen_pm(), Game.repair_cost(), Game.repair_cost(0.25)])
	_row([_b("ซ่อม 25%", func(): Dev.repair(0.25), "green"), _b("ซ่อมเต็ม", func(): Dev.repair(1.0), "green"),
		_b("แบบใหม่" if not rv2 else "แบบเดิม", func(): Dev.hull_repair_v2(not rv2), "yellow" if rv2 else "gray")], "ซ่อมตัวถัง")
	_row([_b("ขั้น 1", func(): Dev.hull_warning_preview(1), "yellow"), _b("ขั้น 2", func(): Dev.hull_warning_preview(2), "red"),
		_b("ขั้น 3", func(): Dev.hull_warning_preview(3), "red"), _b("เคลียร์", func(): Dev.hull_warning_preview(0), "green")],
		"เตือนตัวถัง (MV-250) %s · เส้น %d/%d/%d%%" % ["เปิด" if Features.on("hull_warning") else "ปิด",
		int(HullAlert.line(1) * 100), int(HullAlert.line(2) * 100), int(HullAlert.line(3) * 100)])
	_row([_b("แหนบช่วงล่าง: " + ("เปิด" if Features.on("vehicle_detail") else "ปิด"), func(): Dev.vehicle_detail_switch(not Features.on("vehicle_detail")),
		"green" if Features.on("vehicle_detail") else "red")], "รายละเอียดรถ MV-388 (ล้อ/สนิม/แผ่นปะอบในภาพแล้ว)")
	_row([_b("หลังคาอบอุ่น: " + ("เปิด" if Features.on("cozy_roof") else "ปิด"), func(): Dev.cozy_roof_switch(not Features.on("cozy_roof")),
		"green" if Features.on("cozy_roof") else "red"), _b("ไม่มี", func(): Dev.roof_deck_preview(0), "gray"),
		_b("Lv1", func(): Dev.roof_deck_preview(1)), _b("Lv2", func(): Dev.roof_deck_preview(2)), _b("Lv3", func(): Dev.roof_deck_preview(3))],
		"หลังคา MV-462 · ดาดฟ้าพัก Lv%d" % Mods.level("roof_deck"))
	_row([_b("คนขับขยับ: " + ("เปิด" if Features.on("driver_cab") else "ปิด"), func(): Dev.driver_cab_switch(not Features.on("driver_cab")),
		"green" if Features.on("driver_cab") else "red"), _b("กะพริบตา", func(): Dev.driver_cab_preview("blink"), "gray", true),
		_b("ไฟหน้าปัด", func(): Dev.driver_cab_preview("lamp"), "gray", true), _b("จับพวงมาลัย", func(): Dev.driver_cab_preview("wheel"), "gray", true)],
		"ห้องคนขับ MV-519 (วิกเตอร์)")
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


## MV-483: the twelve approved trait-card profiles on real traits, the unclassified fallbacks, a long text card, and
## the light live / still / off with frame stepping. Tiers here are a preview only (MV-497 decides the real ones).
func _trait_cards_preview() -> void:
	_head("TRAIT CARDS", "การ์ดนิสัย (MV-483)")
	_note("trait_card_style %s · trait_card_vfx %s · จัดระดับแล้ว %d นิสัย (MV-497)" % [
		"เปิด" if Features.on("trait_card_style") else "ปิด", "เปิด" if Features.on("trait_card_vfx") else "ปิด", Crew.TRAIT_TIERS.size()])
	var modes := []
	for m in [["", "สด"], ["still", "นิ่ง"], ["off", "ไม่มีแสง"]]:
		var mm: String = m[0]
		modes.append(_b(m[1], func(): Dev.trait_preview(mm), "yellow" if TraitFx.preview == mm else "gray"))
	modes.append(_b("เฟรมถัดไป", func(): Dev.trait_step(), "green"))
	var tiers_on := Features.on("trait_tiers")
	modes.append(_b("ระดับ: เปิด" if tiers_on else "ระดับ: ปิด", func(): Dev.trait_tiers(not tiers_on), "yellow" if tiers_on else "gray"))
	_row(modes, "แสง · เฟรม %d/16" % (TraitFx.current_phase() + 1))
	var g := GridContainer.new()
	g.name = "TraitCardPreview"
	g.columns = 2 if box.custom_minimum_size.x - 36.0 >= TraitCard.MIN_W * 2 + TraitCard.GAP else 1
	g.add_theme_constant_override("h_separation", TraitCard.GAP)
	g.add_theme_constant_override("v_separation", TraitCard.GAP)
	var items := []
	for r in 6:
		items.append(["cook", r])
		items.append(["glutton", r])
	items += [["cook", -1], ["glutton", -1], ["architect", 4], ["coward", -1]]
	for it in items:
		var c := TraitCard.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(c)
		c.setup(str(it[0]), int(it[1]))
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 6)
	m.add_child(g)
	_list.add_child(m)
	_note("ซ้าย: ข้อดี (พ่อครัว) ทั่วไป..ปฐมกาล · ขวา: ข้อเสีย (กินจุ) · แถวล่าง: ยังไม่จัดระดับ (สวิตช์ trait_tiers ปิด) และข้อความยาว")
	var by_tier := {}
	for t in Crew.TRAIT_TIERS:
		var k := "%s%s" % ["!" if Crew.TRAITS[t].get("bad", false) else "", Loot.RARITY[int(Crew.TRAIT_TIERS[t])].en]
		by_tier[k] = by_tier.get(k, []) + [str(Crew.TRAITS[t].en)]
	var lines := []
	for k in by_tier:
		lines.append("%s: %s" % [k, ", ".join(by_tier[k])])
	_note("ระดับนิสัย (MV-497, ! = ข้อเสีย) · " + " · ".join(lines))


func _tab_crew() -> void:
	_trait_cards_preview()
	_row([_b("+1 คน", func(): Dev.recruit(1), "green"), _b("+3 คน", func(): Dev.recruit(3), "green"), _b("รักษาทุกคน", func(): Dev.heal_all())])
	_row([_b("สุข 100", func(): Dev.happy_all(100.0)), _b("สุข 20", func(): Dev.happy_all(20.0)), _b("สุข 0", func(): Dev.happy_all(0.0), "red")], "ทุกคน")
	_row([_b("หมา", func(): Dev.add_pet("dog")), _b("แมว", func(): Dev.add_pet("cat")), _b("ไก่", func(): Dev.add_pet("hen")), _b("ล้าง", func(): Dev.clear_pets())],
		"สัตว์เลี้ยง %d" % (Game.s.get("pets", []) as Array).size())
	_head("BARKS", "พูดตามสถานการณ์ (MV-427)")
	var m = get_tree().current_scene
	_note("สวิตช์ barks %s · เว้นซ้ำ %.0f วิ · ล่าสุด: %s" % ["เปิด" if Features.on("barks") else "ปิด", Features.num("barks.cooldown", 12.0),
		str(m.chatter.last_bark).replace("|", ": ") if m and m.get("chatter") and str(m.chatter.last_bark) != "" else "-"])
	var bk := [_b("สุ่ม", func(): Dev.bark(), "green")]
	for k in Lore.BARKS:
		var kk: String = k
		bk.append(_b(kk, func(): Dev.bark(kk), "gray"))
	_row(bk)
	_head("BUILDERS", "ช่างก่อสร้าง (หมวกเหลือง) + trait ด้านช่าง")
	var bb := [_b("ช่างธรรมดา", func(): Dev.spawn_builder(""), "green")]
	for t in ["engineer", "quick_hands", "architect", "clumsy"]:
		var tid: String = t
		bb.append(_b("ช่าง+" + str(Crew.TRAITS[t].th), func(): Dev.spawn_builder(tid), "red" if Crew.TRAITS[t].get("bad", false) else "gray"))
	_row(bb)
	_trait_odds()
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
	_note("โบกรถ (MV-244): สวิตช์ stop_for_strangers %s · %s · สร้างคนแปลกหน้าตอนรถวิ่ง = รถจอดและเปิดหน้าต่างตรวจเอง" % [
		"เปิด" if Features.on("stop_for_strangers") else "ปิด", "รถจอดรับคนอยู่" if Inspection.halting() else "ไม่ได้จอดรับใคร"])
	_head("CREW", "ทีละคน")
	if Crew.v2():
		_row([_b("ล้างคูลดาวน์คุยปลอบใจ", func(): Dev.talk_reset())], "ขวัญ v2 (MV-127)")
	for d in Game.s.dwellers:
		var dd: Dictionary = d
		var tags := []
		if Game.is_away(dd):
			tags.append("ออกสำรวจ")
		if Crew.is_striking(dd):
			tags.append("ประท้วง")
		if Crew.mood(dd) != "":
			tags.append(str(Crew.MOOD_TH[Crew.mood(dd)]))
		if Crew.busy(dd):
			tags.append("กำลังคุยปลอบใจ")
		_list.add_child(UIKit.label("%s Lv%d · HP %d · สุข %d %s" % [dd.name, dd.lvl, int(dd.hp), int(dd.happy), " · ".join(tags)], UIKit.FS_SMALL, UIKit.C_TEXT))
		var tl := []
		for t in Crew.traits(dd):
			tl.append(str(Crew.TRAITS.get(t, {}).get("th", t)))
		_note(("[ช่าง] " if Crew.is_builder(dd) else "") + ", ".join(tl))
		_row([_b("+5 Lv", func(): Dev.level_up(dd, 5)), _b("ประท้วง", func(): Dev.force_strike(dd)), _b("หนีทันที", func(): Dev.desert_now(dd), "red"),
			_b("ตาย", func(): Dev.kill(dd), "red")])
		_row([_b("เลิกเป็นช่าง" if Crew.is_builder(dd) else "เป็นช่าง", func(): Dev.toggle_builder(dd), "yellow" if Crew.is_builder(dd) else "gray"),
			_b("สุ่ม trait ใหม่", func(): Dev.reroll_traits(dd))])
		if Crew.v2():
			_row([_b("ปกติ", func(): Dev.mood_force(dd, ""), "green"), _b("หดหู่", func(): Dev.mood_force(dd, "depressed"), "yellow"),
				_b("ใจสลาย", func(): Dev.mood_force(dd, "broken"), "red"), _b("ลงรถคืนนี้", func(): Dev.mood_force(dd, "leaving"), "red"),
				_b("คุยปลอบใจ", func(): Crew.talk(int(dd.id)), "blue")], "ขวัญ (MV-127)")


## MV-170: every named crew sprite (any animation) + portrait, and a button that boards that one
## MV-516: the trait roll weights, and the shares from rolling 1000 made-up recruits
func _trait_odds() -> void:
	var on := Features.on("trait_roll_weights")
	_head("TRAIT ODDS", "โอกาสสุ่มนิสัย (MV-516) · %s" % ("ตามระดับ" if on else "เท่ากันทุกนิสัย"))
	var w := []
	for i in Crew.TIER_NAMES.size():
		w.append("%s %s" % [Loot.RARITY[i].en, Features.num("crew.trait_weight." + Crew.TIER_NAMES[i], Crew.TRAIT_WEIGHTS[i])])
	w.append("ข้อเสีย %s" % Features.num("crew.trait_weight.trade_off", Crew.TRADE_OFF_WEIGHT))
	_note("น้ำหนัก: " + " · ".join(w))
	var r: Dictionary = Dev.last_trait_roll
	if not r.is_empty():
		var parts := []
		for i in Crew.TIER_NAMES.size():
			parts.append("%s %.1f%%" % [Loot.RARITY[i].en, float(r[Crew.TIER_NAMES[i]])])
		parts.append("ข้อเสีย %.1f%%" % float(r.bad))
		_note("สุ่ม %d คน มีนิสัยระดับนั้นอย่างน้อย 1: %s" % [int(r.n), " · ".join(parts)])
	_row([_b("สุ่มทดสอบ 1000 คน", func(): Dev.trait_roll_test(1000), "green")], "ไม่เพิ่มคนจริง")


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
	_row([_b("บอสเวฟ: สมดุลใหม่", func(): Dev.roaming_boss_preview(true), "green", true), _b("บอสเวฟ: สมดุลเดิม", func(): Dev.roaming_boss_preview(false), "gray", true)])
	var wave_balance := Features.on("roaming_boss_balance")
	_note("สมดุลบอสเวฟ (MV-544) %s · HP ×%.1f / ดาเมจ ×%.1f · %s" % ["เปิด" if wave_balance else "ปิด", Features.num("boss.wave_hp", 8.0) if wave_balance else 12.0, Features.num("boss.wave_damage", 1.6) if wave_balance else 2.4, ("ความเสียหายรถต่อครั้ง ≤%d%% หลังคิดเกราะ" % int(round(Features.num("boss.hull_hit_cap", 0.12) * 100.0))) if wave_balance else "ความเสียหายพิเศษแบบเดิม"])
	var bb := [_b("บอสด่าน: " + str(Combat.BOSSES[Combat.biome_id()].th), func(): Dev.spawn_boss("warlord"), "red", true)]
	for id in Combat.WAVE_BOSSES:
		var bid: String = id
		bb.append(_b(str(Combat.WAVE_BOSSES[id].th), func(): Dev.spawn_boss(bid), "gray", true))
	_row(bb)
	_row([_b("วอร์ลอร์ด", func(): Dev.entrance_preview("warlord"), "red", true), _b("บอส", func(): Dev.entrance_preview("boss"), "yellow", true),
		_b("อีลิท", func(): Dev.entrance_preview("elite"), "gray", true), _b("เรียกอีลิท ×3", func(): Dev.spawn_elites(3), "gray", true)],
		"เปิดตัวบอส (MV-387)%s" % ("" if Features.on("boss_intro") else " · ปิดอยู่"))
	_row([_b("เทียบขนาด", func(): Dev.enemy_size_preview("lineup"), "yellow", true), _b("ธรรมดา", func(): Dev.enemy_size_preview("normal"), "gray", true),
		_b("อีลิท", func(): Dev.enemy_size_preview("elite"), "gray", true), _b("บอส", func(): Dev.enemy_size_preview("boss"), "gray", true),
		_b("วอร์ลอร์ด", func(): Dev.enemy_size_preview("warlord"), "red", true)],
		"ขนาดมอนสเตอร์ (MV-517) x%d / x%d / x%d / x%d%s" % [int(Features.num("enemy_size.normal", CombatView.ENEMY_SCALE.normal)),
		int(Features.num("enemy_size.elite", CombatView.ENEMY_SCALE.elite)), int(Features.num("enemy_size.boss", CombatView.ENEMY_SCALE.boss)),
		int(Features.num("enemy_size.warlord", CombatView.ENEMY_SCALE.warlord)), "" if Features.on("enemy_size") else " · ปิดอยู่"])
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
	_head("WORLD MAP", "แผนที่โลก (MV-500)")
	_note("ระยะที่ 1: สร้างและเก็บโลกเท่านั้น ยังไม่มีหน้าจอแผนที่")
	_note(WorldMap.summary())
	var wm := WorldMap.world()
	if not wm.is_empty():
		var order := []
		for reg in wm.regions:
			order.append("%s(Vault %d)" % [str(reg.id), int(reg.req)])
		_note("ลำดับพื้นที่: " + " → ".join(order))
		var rt := WorldMap.route("start", "helios", Data.MAX_VAULT_LEVEL)
		_note("เส้นทางทดสอบ start → helios: %s" % (("%.1f กม. ผ่าน %d จุด" % [float(rt.km), (rt.ids as Array).size()]) if not rt.is_empty() else "ไปไม่ถึง"))
	# MV-514: a new world replaces this one (its roads and visited stops): the MV-422 confirmation, like any destructive action
	_row([_b("โลกใหม่", func(): ConfirmPanel.ask(self, "โลกใหม่", "โลกนี้ (ถนน จุดที่ไปแล้ว ทริปที่ขับอยู่) จะถูกแทนด้วยโลกใหม่จาก seed สุ่ม ย้อนคืนไม่ได้ รถจะถูกวางไว้ในพื้นที่ปัจจุบัน",
		"ยืนยันโลกใหม่", func(): Dev.world_new()), "yellow"), _b("ตรวจ seed", func(): Dev.world_verify(), "green")], "โลก")
	var lb := []
	for i in Data.BIOMES.size():
		var bi: int = i
		lb.append(_b(str(i + 1), func(): Dev.world_legacy("mid", bi), "yellow" if int(Game.s.biome) == bi else "gray"))
	_row(lb, "เซฟเก่า")
	_row([_b("ที่ด่าน", func(): Dev.world_legacy("checkpoint", int(Game.s.biome))), _b("จอดที่จุดสำคัญ", func(): Dev.world_legacy("site", int(Game.s.biome))),
		_b("สำรวจแล้ว", func(): Dev.world_legacy("done", int(Game.s.biome))), _b("รอบ+1", func(): Dev.world_legacy("lap", int(Game.s.biome)))], "เซฟเก่า")
	_row([_b("ย้ายซ้ำ (ต้องไม่เปลี่ยน)", func(): Dev.world_reconcile(), "green"),
		_b("แผนที่: " + ("เปิด" if Features.on("seeded_world_map") else "ปิด"), func(): Dev.feature_set("seeded_world_map", not Features.on("seeded_world_map")),
		"green" if Features.on("seeded_world_map") else "red")], "MV-514")
	_row([_b("เปิดแผนที่ (TEST-515)", func(): Dev.world_screen(), "green", true)], "หน้าจอ")
	_row([_b("ถึงปลายทางตอนออฟไลน์", func(): Dev.world_arrive_offline(), "yellow")],
		"MV-542 %s · รอเลือกปลายทาง %s" % ["เปิด" if Features.on("drive_help") else "ปิด", "ใช่" if Game.needs_destination() else "ไม่"])
	if not wm.is_empty():
		var t := WorldMap.trip()
		if t.is_empty():
			_note("ไม่ได้ขับ · อยู่ที่ %s%s" % [WorldMap.here(), " · ด่านตรวจ" if Game.at_checkpoint() else ""])
		else:
			var e := WorldMap.edge(str(t.edges[int(t.i)]))
			_note("ขับไป %s · ถนน %d/%d (%s) %.2f/%.1f กม.%s" % [str(t.dest), int(t.i) + 1, (t.edges as Array).size(), str(e.id), float(t.prog),
				float(e.km), " · รอที่ด่านตรวจ" if Game.at_checkpoint() else ""])
		_row([_b("ไปแลนด์มาร์กถัดไป", func(): Dev.world_drive("next"), "green"), _b("ไปทางออก", func(): Dev.world_drive("exit"), "yellow")], "ขับ")
		_row([_b("จบถนนนี้", func(): Dev.world_finish_road()), _b("ออฟไลน์ 10 นาที", func(): Dev.world_offline(10.0)),
			_b("ยกเลิก", func(): Dev.world_cancel(), "red")], "ทดสอบ")
	_note("โลกใหม่ = สุ่ม seed ใหม่แทนโลกนี้ · ตรวจ seed = สร้างซ้ำจาก seed ที่เก็บไว้แล้วเทียบว่าตรงกัน")
	_head("INDUSTRIAL SKY", "ฉากนิคมอุตสาหกรรมใหม่ (MV-369) ตามเวลาในเกม")
	_row([_b("รุ่งเช้า", func(): Dev.background_preview(0.25)), _b("กลางวัน", func(): Dev.background_preview(0.5)), _b("พระอาทิตย์ตก", func(): Dev.background_preview(0.75)), _b("กลางคืน", func(): Dev.background_preview(0.0))])
	_row([_b("ฉากใหม่", func(): Dev.feature_set("industrial_parallax", true), "green"), _b("ฉากเดิม", func(): Dev.feature_set("industrial_parallax", false), "gray")])
	_head("GLASS DESERT", "ทะเลทรายแก้ว (MV-539) ตามเวลาในเกม")
	_row([_b("เช้า", func(): Dev.desert_background_preview(0.25)), _b("เที่ยง", func(): Dev.desert_background_preview(0.5)), _b("เย็น", func(): Dev.desert_background_preview(0.75)), _b("คืน", func(): Dev.desert_background_preview(0.0))])
	_row([_b("ทะเลทรายใหม่", func(): Dev.feature_set("desert_parallax", true), "green"), _b("ทะเลทรายเดิม", func(): Dev.feature_set("desert_parallax", false), "gray")])
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
	_note("ห้ามหนีตอนรถออกตัวไม่ได้ (MV-243): สวิตช์ flee_guard %s · ตอนนี้: %s" % ["เปิด" if Features.on("flee_guard") else "ปิด",
		Game.drive_block() if Game.drive_block() != "" else "รถออกตัวได้"])
	_row([_b("หมาป่าตอนรถจอดรอ 45 วิ", func(): Dev.event_flee_stuck(), "red", true)], "หนีไม่ได้")
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
	var smooth := Features.on("smooth_ui_text")
	_head("UI TEXT", "ตัวอักษร (MV-540)")
	_row([_b("ขอบเรียบ", func(): Dev.ui_text_preview(true), "yellow" if smooth else "gray"),
		_b("ขอบพิกเซลเดิม", func(): Dev.ui_text_preview(false), "gray" if smooth else "yellow")])
	var wm := not Features.on("window_still")
	_head("WINDOWS", "หน้าต่าง (MV-537) · ตอนนี้%s" % ("เลื่อนนุ่มตามเนื้อหา" if wm else "อยู่นิ่ง ขอบบนไม่ขยับ"))
	_row([_b("อยู่นิ่ง", func(): Dev.window_motion(false), "gray" if wm else "yellow"),
		_b("เลื่อนนุ่ม (แบบเดิม)", func(): Dev.window_motion(true), "yellow" if wm else "gray")], "เมื่อเนื้อหาเปลี่ยนความสูง")
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


## MV-536: listen to every biome bed, weather layer and effect group without changing the run
func _tab_sound() -> void:
	_head("SOUND", "เสียง (MV-536)")
	var amb := "เปิด" if Sound.ambience_on() else "ปิด"
	var fx := "เปิด" if Sound.sfx_on() else "ปิด"
	_note("สวิตช์ audio_ambience: %s · audio_sfx: %s · audio_bgm: %s · แตะจอแล้ว: %s · พื้นที่ตอนนี้: %s · อากาศ: %s · เสียงล่าสุด: %s" % [
		amb, fx, "เปิด" if Sound.bgm_on() else "ปิด", "ใช่" if Sound.unlocked else "ยัง", Sound.want_bed(), Sound.want_weather() if Sound.want_weather() != "" else "-", Sound.last_sfx if Sound.last_sfx != "" else "-"])
	var beds := []
	for b in Data.BIOMES:
		var id: String = b.id
		beds.append(_b(id, func(): Dev.sound_preview("bed", id), "yellow" if Sound.preview.get("bed", "") == id and not Sound.preview.has("weather") else "gray"))
	_row(beds, "พื้นที่")
	var ws := []
	for w in Sound.WEATHER_SOUNDS:
		var id: String = w
		ws.append(_b(id, func(): Dev.sound_preview("weather", id), "yellow" if Sound.preview.get("weather", "") == id else "gray"))
	_row(ws, "อากาศ")
	var gs := []
	for g in Sound.GROUPS:
		var id: String = g
		gs.append(_b(id, func(): Dev.sound_preview("group", id)))
	_row(gs, "เอฟเฟกต์")
	_row([_b("เพลงหน้าแรก (โลไฟ)", func(): Dev.sound_preview("bgm"), "yellow" if Sound.preview.has("bgm") else "gray"),
		_b(("ปิด" if Sound.bgm_on() else "เปิด") + "เพลง", func(): Dev.feature_set("audio_bgm", not Sound.bgm_on()))], "เพลง")
	_row([_b("กลับเสียงตามเกม", func(): Dev.sound_preview("clear"), "green"),
		_b(("ปิด" if Sound.ambience_on() else "เปิด") + "เสียงบรรยากาศ", func(): Dev.feature_set("audio_ambience", not Sound.ambience_on())),
		_b(("ปิด" if Sound.sfx_on() else "เปิด") + "เสียงเอฟเฟกต์", func(): Dev.feature_set("audio_sfx", not Sound.sfx_on()))])
	_note("ปุ่มพื้นที่/อากาศเล่นวนจนกด กลับเสียงตามเกม (ฟังอย่างเดียว เซฟไม่ถูกทำเครื่องหมายโกง) · ปรับดังเบาใน ตั้งค่า > เสียง")


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
