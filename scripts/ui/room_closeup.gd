class_name RoomCloseup
extends ModalPanel
## Terminal panel shown while the camera is zoomed into a room (management mode).
## Workers (assign / move / remove), production, recipes with pixel progress bars, upgrade, demolish.
## Empty slots show a build list; locked slots explain the vault upgrade. Rooms under construction (v4.3) show
## the site: progress, time left, the builder crew (+ who speeds it up) and a components rush.
## LARGE ROOMS (v4.4): a "ขยายห้อง" section knocks the room through into a same-type neighbour (2-3 cells) or
## splits it back. focus_rect() tells the camera where on screen the zoomed room should sit.
## SALVAGERS' SALOON (MV-430): a "มื้อเย็นร่วมกัน" section picks one or two diners (mode "supper"), shows the meal's
## progress and hands out the finished supper (Saloon).

signal build_requested(slot: int, room_type: String)
signal focus_changed      # MV-482: the room's area moved (the panel's height changed): Main re-centres the camera

var slot := -1
var mode := "main"           # main | assign | supper
const PANEL_MIN_W := 280.0   # MV-266: landscape panel width the room leaves free at least
var _diners: Array = []      # MV-430: crew ids picked for the next supper (checked again when it starts)
var _rx_bar: ProgressBar
var _rx_lbl: Label
var _job_bar: ProgressBar
var _job_lbl: Label
var _site_bar: ProgressBar
var _site_lbl: Label
var _rush_btn: Button
var _content: VBoxContainer


func _build() -> void:
	centered = false        # docks beside the zoomed room (_layout)
	dim_alpha = 0.0
	dim.color = Color(0, 0, 0, 0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content = make_list(4)
	Game.rooms_changed.connect(_maybe_refresh)
	Game.dwellers_changed.connect(_maybe_refresh)
	Game.resources_changed.connect(_update_buttons)
	RoomX.job_done.connect(func(_j): _maybe_refresh())         # MV-430: a supper ends while the room is open
	RoomX.job_dropped.connect(func(_j, _why): _maybe_refresh())


func _portrait() -> bool:
	var vp := get_viewport_rect().size
	return vp.y >= vp.x


## MV-482: the zoomed room's area. Portrait: everything between the visible top bar and the panel, which docks at the
## bottom at its content height, so the room sits centred in the free space and nothing covers it. Landscape: the left
## part of the screen, beside the panel (MV-266: on a narrow screen the room gives up width so the panel fits).
func focus_rect() -> Rect2:
	var vp := get_viewport_rect().size
	if _portrait():
		var top := _top_y()
		var bottom := box.position.y - 4.0 if is_open and box != null and box.size.y > 0.0 else top + _room_h()
		return Rect2(8, top, vp.x - 16, maxf(_room_h(), bottom - top))
	var need := maxf(PANEL_MIN_W, _content_min_w())
	return Rect2(4, 4, floorf(minf(vp.x * 0.46, vp.x - need - 12.0)), vp.y - 8)


## where the room area starts: under the HUD's top bar (only the resource row shows during a close-up)
func _top_y() -> float:
	var hud := get_parent() as HUD
	if hud and hud._top and hud._top.visible:
		return floorf(hud._top.position.y + hud._top.size.y + 4.0)
	return 26.0


## the portrait zoom (whole number, 2-3 as before) and the room height it needs, frame included
func _room_zoom() -> int:
	var vp := get_viewport_rect().size
	return clampi(int(minf((vp.x - 16.0) / float(Vehicle.ROOM_SIZE.x), vp.y * 0.3 / float(Vehicle.ROOM_SIZE.y))), 2, 3)


func _room_h() -> float:
	return float(Vehicle.ROOM_SIZE.y * _room_zoom()) + 12.0


## the width the panel's content needs (not the box's own custom minimum, which _layout sets from the focus rect)
func _content_min_w() -> float:
	if box == null or box.get_child_count() == 0:
		return 0.0
	return (box.get_child(0) as Control).get_combined_minimum_size().x + box.get_theme_stylebox("panel").get_minimum_size().x


## the panel is never taller than what leaves the whole zoomed room visible
func max_height() -> float:
	var vp := get_viewport_rect().size
	if _portrait():
		return floorf(vp.y - _top_y() - _room_h() - 8.0)
	return floorf(vp.y - 8.0)


func _layout() -> void:
	var vp := get_viewport_rect().size
	var w := vp.x - 8.0 if _portrait() else vp.x - focus_rect().end.x - 8.0
	if _fit_tw:
		_fit_tw.kill()
	var sz := Vector2(w, fit_target()).floor()
	box.custom_minimum_size = sz
	box.size = sz
	_recenter()


## docked: portrait at the bottom, landscape on the right and vertically centred; kept inside the screen
func _recenter() -> void:
	if box == null:
		return
	var vp := get_viewport_rect().size
	if _portrait():
		box.position = Vector2(4, floorf(vp.y - box.size.y - 4.0))
	else:
		box.position = Vector2(floorf(focus_rect().end.x + 4.0), floorf((vp.y - box.size.y) * 0.5))
	box.position = box.position.clamp(Vector2.ZERO, (vp - box.size).max(Vector2.ZERO)).floor()
	focus_changed.emit()


func open_slot(s: int) -> void:
	slot = Game.room_anchor(s)
	mode = "main"
	_diners.clear()
	open()


func _maybe_refresh() -> void:
	if is_open:
		refresh()


func refresh() -> void:
	if slot < 0:
		return
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_job_bar = null
	_site_bar = null
	_rush_btn = null
	_rx_bar = null
	var r: Dictionary = Game.s.rooms[slot]
	if not Game.is_slot_unlocked(slot):
		_build_locked()
		return
	if r.type == "empty":
		_build_empty()
		return
	var def := Data.room_def(r.type)
	var span := Game.room_span(slot)
	set_title("%s LV%d%s / %s%s" % [def.en, r.level, (" x%d" % span) if span > 1 else "", def.th, (Loc.t(" ใหญ่ %d ช่อง") % span) if span > 1 else ""])
	if mode == "assign":
		_build_assign(def)
		return
	if mode == "supper" and str(r.type) == Saloon.TYPE and not Game.is_constructing(slot):
		_build_supper_pick()
		return
	if Game.is_site(slot):
		set_title(Loc.t("BUILDING %s / กำลังสร้าง%s") % [def.en, def.th])
		_build_site(r, def)
		_build_workers(def)
		var cancel := UIKit.button(Loc.t("ยกเลิกการก่อสร้าง (คืนเศษเหล็กครึ่งหนึ่ง)"), "red", "close")
		cancel.name = "CancelConstructionButton"
		cancel.pressed.connect(_request_demolish)
		_content.add_child(cancel)
		return
	if Game.is_constructing(slot):
		_build_site(r, def)
	_build_workers(def)
	_build_production(r, def)
	if str(r.type) == Saloon.TYPE:
		_build_saloon()
	_build_recipes(r, def)
	_build_upgrade(r, def)
	_build_large(r, def)


# ------------------------------------------------------------------ sections
func _section(en: String, th: String = "") -> void:
	_content.add_child(UIKit.header(en, th))


func _build_site(r: Dictionary, def: Dictionary) -> void:
	var up := not Game.is_site(slot)
	var merging := Game.is_merging(slot)
	_section("CONSTRUCTION", (Loc.t("ทุบผนังรวมเป็น %d ช่อง") % Game.room_span(slot)) if merging else (Loc.t("อัปเกรดเป็น Lv.%d") % (int(r.level) + 1) if up else Loc.t("งานก่อสร้าง")))
	var p := UIKit.panel(Color("1a140c"), UIKit.C_GOLD)
	var v := UIKit.vbox(2)
	p.add_child(v)
	_site_bar = UIKit.progress(UIKit.C_GOLD, 10)
	_site_bar.custom_minimum_size.y = 10
	_site_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_site_lbl = UIKit.label("", UIKit.FP, UIKit.C_WHITE, true)
	_site_lbl.add_theme_constant_override("outline_size", 2)
	_site_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_site_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_site_bar.add_child(_site_lbl)
	v.add_child(_site_bar)
	var crew := Game.site_crew(slot)
	var tip := (Loc.t("ห้องยังทำงานแบบแยกห้อง โบนัสห้องใหญ่เริ่มเมื่อเสร็จ") if merging else Loc.t("ห้องยังทำงานตามปกติระหว่างอัปเกรด")) if up else Loc.t("ห้องจะเริ่มทำงานเมื่อสร้างเสร็จ")
	if crew.is_empty():
		tip += Loc.t(" · ยังไม่มีช่าง งานเดินช้ามาก ส่งคนมาช่วยสิ!")
	v.add_child(UIKit.wrap_label(tip, UIKit.FS_SMALL, UIKit.C_DIM if not crew.is_empty() else UIKit.C_RED))
	for d in crew:
		var tags := Crew.build_tags(d)
		v.add_child(UIKit.wrap_label("%s  x%.2f%s" % [d.name, Crew.build_mult(d), ("  · " + tags) if tags != "" else ""], UIKit.FS_SMALL, UIKit.C_GOLD))
	_rush_btn = UIKit.button("", "yellow", "cog")
	_rush_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rush_btn.pressed.connect(func(): Game.rush_build(slot))
	v.add_child(_rush_btn)
	_content.add_child(p)
	_update_site()


func _update_site() -> void:
	if _site_bar == null or not is_instance_valid(_site_bar) or not Game.is_constructing(slot):
		return
	var pr := Game.build_progress(slot)
	_site_bar.value = pr
	_site_lbl.text = "%d%%  %s  x%.1f" % [int(pr * 100.0), Game.fmt_time(Game.build_left_sec(slot)), Game.build_speed(slot)]
	_site_lbl.size = _site_bar.size
	_site_lbl.position = Vector2(0, 1)
	var rc := Game.rush_cost(slot)
	_rush_btn.text = Loc.t("เสร็จทันที (%d ชิ้นส่วน)") % rc
	_rush_btn.disabled = not Game.can_afford({"components": rc})


func _build_workers(def: Dictionary) -> void:
	var site := Game.is_site(slot)
	var workers := Game.site_crew(slot) if site else Game.room_workers(slot)
	var st: String = "str" if site else def.get("stat", "str")
	if site:
		_section("BUILDERS %d/%d · STR" % [workers.size(), Game.room_capacity(slot)], Loc.t("ทีมช่าง"))
	else:
		_section("WORKERS %d/%d · %s" % [workers.size(), Game.room_capacity(slot), st.to_upper()], Loc.t("ผู้ทำงาน"))
	for d in workers:
		var card := UIKit.panel()
		var h := UIKit.hbox(4)
		card.add_child(h)
		h.add_child(UIKit.portrait(d.variant))
		var v := UIKit.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var role_tag: String = (" · " + Crew.ROLES[Crew.role(d)].th) if Crew.ROLES.has(Crew.role(d)) else ""
		v.add_child(UIKit.label("%s  Lv.%d%s" % [d.name, d.lvl, role_tag], UIKit.FS_SMALL))
		v.add_child(UIKit.stat_bar(st, int(d[st]), UIKit.best_stats(d).has(st)))
		h.add_child(v)
		var did: int = d.id
		var mv := UIKit.button(Loc.t("ย้าย"), "blue")
		mv.pressed.connect(func(): _open_dweller(did))
		h.add_child(mv)
		var rm := UIKit.button("", "gray", "close")
		rm.tooltip_text = Loc.t("ถอดออก")
		rm.pressed.connect(func(): Game.assign(Game.dweller_by_id(did), -1))
		h.add_child(rm)
		_content.add_child(card)
	if workers.size() < Game.room_capacity(slot):
		var add := UIKit.button(Loc.t("+ ส่งช่างมาช่วยสร้าง") if site else Loc.t("+ เพิ่มคนทำงาน"), "green", "people")
		add.pressed.connect(func():
			mode = "assign"
			refresh())
		_content.add_child(add)


func _build_assign(def: Dictionary) -> void:
	if Game.is_constructing(slot):
		_build_assign_builders()
		return
	var st: String = def.get("stat", "str")
	var back := UIKit.button(Loc.t("< กลับ"), "gray")
	back.pressed.connect(func():
		mode = "main"
		refresh())
	_content.add_child(back)
	_section("SELECT · SORT %s" % st.to_upper(), Loc.t("เลือกลูกเรือ"))
	var list: Array = []
	for d in Game.s.dwellers:
		if not Game.is_away(d) and int(d.room) != slot:
			list.append(d)
	list.sort_custom(func(a, b): return int(a[st]) > int(b[st]))
	if list.is_empty():
		_content.add_child(UIKit.wrap_label(Loc.t("ไม่มีลูกเรือว่าง (ทุกคนทำงานอยู่ที่นี่หรือออกสำรวจ)")))
	for d in list:
		var where: String = Loc.t("ว่าง") if int(d.room) < 0 else Data.room_def(Game.room(int(d.room)).type).th
		if Game.squad_role(d) >= 0:
			where = Combat.ROLES[Game.squad_role(d)].th
		var b := _row_button(d, "%s  %s%d  (%s)" % [d.name, st.to_upper(), d[st], where], "gray" if int(d.room) >= 0 else "green")
		var did: int = d.id
		b.pressed.connect(func():
			if Game.assign(Game.dweller_by_id(did), slot):
				mode = "main"
				refresh())
		_content.add_child(b)


## picking crew for a building site: fastest builders first
func _build_assign_builders() -> void:
	var back := UIKit.button(Loc.t("< กลับ"), "gray")
	back.pressed.connect(func():
		mode = "main"
		refresh())
	_content.add_child(back)
	_section("SELECT · SORT BUILD SPEED", Loc.t("เลือกช่าง (เร็วสุดก่อน)"))
	var list: Array = []
	for d in Game.s.dwellers:
		if not Game.is_away(d) and int(d.room) != slot:
			list.append(d)
	list.sort_custom(func(a, b): return Crew.build_speed(a) > Crew.build_speed(b))
	if list.is_empty():
		_content.add_child(UIKit.wrap_label(Loc.t("ไม่มีลูกเรือว่าง (ทุกคนทำงานอยู่ที่นี่หรือออกสำรวจ)")))
	for d in list:
		var where: String = Loc.t("ว่าง") if int(d.room) < 0 else Data.room_def(Game.room(int(d.room)).type).th
		if Game.squad_role(d) >= 0:
			where = Combat.ROLES[Game.squad_role(d)].th
		var tags := Crew.build_tags(d)
		var b := _row_button(d, Loc.t("%s  ช่าง x%.1f%s  (%s)") % [d.name, Crew.build_speed(d) / 0.6, (" " + tags) if tags != "" else "", where],
			"yellow" if Crew.is_builder(d) else ("gray" if int(d.room) >= 0 else "green"))
		var did: int = d.id
		b.pressed.connect(func():
			if Game.assign(Game.dweller_by_id(did), slot):
				mode = "main"
				refresh())
		_content.add_child(b)


func _row_button(d: Dictionary, text: String, color: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 28)
	b.focus_mode = Control.FOCUS_NONE
	UIKit.style_button(b, color)
	var h := UIKit.hbox(4)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 3
	h.offset_top = 3
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pt := UIKit.tex_rect(Atlas.tex("pt_" + d.variant), Vector2(20, 20))
	h.add_child(pt)
	var l := UIKit.label(text, UIKit.FS_SMALL)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	b.add_child(h)
	return b


func _build_production(r: Dictionary, def: Dictionary) -> void:
	var rate := Game.room_rate_pm(slot)
	var txt := ""
	for k in rate:
		txt += Loc.t("+%.1f %s/นาที  ") % [rate[k], Data.item_name(k)]
	if txt == "" and not def.produce.is_empty():
		txt = Loc.t("ไม่มีคนทำงาน — หยุดผลิต")
	# MV-247: what the room uses up to make it
	var ins := Game.room_inputs_pm(slot, rate)
	var use_txt := ""
	for k in ins:
		use_txt += Loc.t("-%.1f %s/นาที  ") % [ins[k], Loc.t("พืชผล/เนื้อ") if k == "raw" else Data.item_name(k)]
	var eff := UIKit.panel()
	var v := UIKit.vbox(1)
	eff.add_child(v)
	var raw := Data.raw_food()
	v.add_child(UIKit.label("EFFECT: " + str(def.get("raw_effect_en", def.effect_en) if raw else def.effect_en), UIKit.FP, UIKit.C_GREEN, true))
	v.add_child(UIKit.wrap_label(Data.room_effect(r.type), UIKit.FS_SMALL, UIKit.C_DIM))
	if txt != "":
		v.add_child(UIKit.wrap_label(txt, UIKit.FS_SMALL, UIKit.C_TEXT))
	if use_txt != "":
		v.add_child(UIKit.wrap_label(Loc.t("ใช้ ") + use_txt, UIKit.FS_SMALL, UIKit.C_DIM))
	if ins.has("raw") and Game.raw_stock() < 1.0:
		v.add_child(UIKit.wrap_label(Loc.t("พืชผลและเนื้อหมด! ครัวหยุดทำอาหาร — ปลูกพืชในห้องปลูกพืช หรือล่าสัตว์กลายพันธุ์"), UIKit.FS_SMALL, UIKit.C_RED))
	elif ins.has("water") and float(Game.s.res.water) < 1.0:
		v.add_child(UIKit.wrap_label(Loc.t("น้ำหมด! ห้องนี้หยุดผลิต"), UIKit.FS_SMALL, UIKit.C_RED))
	var syn := Crew.synergy_text(slot)
	var cm := Crew.room_mult(slot)
	if syn != "" or absf(cm - 1.0) > 0.01:
		v.add_child(UIKit.wrap_label(Loc.t("โบนัสทีม x%.2f %s") % [cm, ("· " + syn) if syn != "" else ""], UIKit.FS_SMALL, UIKit.C_GOLD))
	for e in Synergy.effects(slot):
		var good := float(e.mult) + float(e.happy) > 0.0
		v.add_child(UIKit.wrap_label(Loc.t("%s ติด%s: %s") % ["▲" if good else "▼", Data.room_def(str(e.type)).th, e.th], UIKit.FS_SMALL, UIKit.C_GREEN if good else UIKit.C_RED))
	if Game.room_dark(slot):
		v.add_child(UIKit.wrap_label(Loc.t("ไฟดับ! ห้องมืดสนิท ผลิตได้น้อยลง — ช่างเครื่องซ่อมได้เร็วขึ้น") if not Game.blackout() else Loc.t("แบตเตอรี่หมด! ทั้งรถมืด"), UIKit.FS_SMALL, UIKit.C_RED))
	for d in Game.room_occupants(slot):
		if Crew.is_broken(d):
			v.add_child(UIKit.wrap_label(Loc.t("%s ใจสลาย นั่งร้องไห้ (ความสุข %d) · แตะชื่อในเมนูลูกเรือเพื่อคุยปลอบใจ") % [d.name, int(d.happy)], UIKit.FS_SMALL, UIKit.C_RED))
		elif d.get("strike", false):
			v.add_child(UIKit.wrap_label(Loc.t("%s ประท้วงหยุดงาน (ความสุข %d)") % [d.name, int(d.happy)], UIKit.FS_SMALL, UIKit.C_RED))
	if Env.prod_mult() < 0.99:
		v.add_child(UIKit.wrap_label(Loc.t("หนาวจัด! ผลิตได้ x%.2f (ต้องการเชื้อเพลิง)") % Env.prod_mult(), UIKit.FS_SMALL, UIKit.C_RED))
	if def.get("weather_crop", false):
		v.add_child(UIKit.label(Loc.t("สภาพอากาศ: %s (x%.2f)") % [Game.weather_def().th, Game.weather_def().crop], UIKit.FS_SMALL, UIKit.C_BLUE))
	_content.add_child(eff)


## MV-430: the shared supper (running / waiting to be claimed / pick the diners) and the crew's bonds
func _build_saloon() -> void:
	_section("SHARED SUPPER", Loc.t("มื้อเย็นร่วมกัน"))
	var p := UIKit.panel(Color("1a140c"), UIKit.C_GOLD)
	var v := UIKit.vbox(2)
	p.add_child(v)
	var j := Saloon.supper(slot)
	if not j.is_empty() and not bool(j.done):
		var names := []
		for did in Saloon.diners(j):
			var d := Game.dweller_by_id(did)
			if not d.is_empty() and int(d.room) == slot:
				names.append(str(d.name))
		v.add_child(UIKit.wrap_label(Loc.t("กำลังกินมื้อเย็น: %s") % (" & ".join(names) if not names.is_empty() else "-"), UIKit.FS_SMALL, UIKit.C_TEXT))
		_rx_bar = UIKit.progress(UIKit.C_GOLD, 10)
		_rx_bar.custom_minimum_size.y = 10
		_rx_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rx_lbl = UIKit.label("", UIKit.FP, UIKit.C_WHITE, true)
		_rx_lbl.add_theme_constant_override("outline_size", 2)
		_rx_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		_rx_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rx_bar.add_child(_rx_lbl)
		v.add_child(_rx_bar)
		v.add_child(UIKit.wrap_label(Loc.t("คนที่นั่งกินพักงานของตัวเองไว้ กินเสร็จแล้วจะกลับไปทำงานที่เดิม · ย้ายใครออกกลางคัน คนนั้นไม่ได้ความสุข"), UIKit.FS_SMALL, UIKit.C_DIM))
	elif not j.is_empty():
		v.add_child(UIKit.wrap_label(Loc.t("มื้อเย็นเสร็จแล้ว ทุกคนกลับไปทำงาน เหลือแค่นั่งคุยกันอีกนิด"), UIKit.FS_SMALL, UIKit.C_GREEN))
		var b := UIKit.button(Loc.t("นั่งคุยกันต่อ (รับความสุข)"), "green", "happy")
		b.name = "SupperClaimButton"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var jid := int(j.id)
		b.pressed.connect(func():
			Saloon.claim(jid)
			refresh())
		v.add_child(b)
	else:
		v.add_child(UIKit.wrap_label(Loc.t("ชวน 1–2 คนมานั่งกินด้วยกัน: ใช้ %s · %s · ความสุข +%d ต่อคน · ระหว่างกินไม่ได้ทำงาน") % [
			Game.cost_text(Saloon.cost()), Game.fmt_time(Saloon.duration(slot)), int(Saloon.happy_gain())], UIKit.FS_SMALL, UIKit.C_TEXT))
		if not RoomX.on():
			v.add_child(UIKit.wrap_label(Loc.t("ระบบห้องใหม่ปิดอยู่"), UIKit.FS_SMALL, UIKit.C_RED))
		var b := UIKit.button(Loc.t("เลือกคนร่วมโต๊ะ"), "yellow", "people")
		b.name = "SupperPickButton"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not RoomX.on() or Game.is_constructing(slot)
		b.pressed.connect(func():
			mode = "supper"
			refresh())
		v.add_child(b)
	var bl := _bond_lines()
	if not bl.is_empty():
		v.add_child(UIKit.label(Loc.t("สายสัมพันธ์บนรถ"), UIKit.FS_SMALL, UIKit.C_GOLD))
		for t in bl:
			v.add_child(UIKit.wrap_label(t, UIKit.FS_SMALL, UIKit.C_DIM))
	_content.add_child(p)
	_update_saloon()


## the three strongest bonds between crew who are still aboard
func _bond_lines() -> Array:
	var all := []
	var b: Dictionary = Saloon.st().get("bonds", {})
	for k in b:
		var ids := str(k).split("|")
		if ids.size() != 2:
			continue
		var a := Game.dweller_by_id(int(ids[0]))
		var c := Game.dweller_by_id(int(ids[1]))
		if a.is_empty() or c.is_empty():
			continue
		all.append([int(b[k]), "%s & %s" % [a.name, c.name]])
	all.sort_custom(func(x, y): return int(x[0]) > int(y[0]))
	var out := []
	for e in all.slice(0, 3):
		out.append(Loc.t("%s · กินด้วยกัน %d มื้อ") % [e[1], e[0]])
	return out


## picking the diners: tap to seat / unseat (two at most), then start
func _build_supper_pick() -> void:
	var back := UIKit.button(Loc.t("< กลับ"), "gray")
	back.pressed.connect(func():
		mode = "main"
		refresh())
	_content.add_child(back)
	_section("SUPPER · PICK 1-2", Loc.t("เลือกคนร่วมโต๊ะ"))
	var list: Array = []
	for d in Game.s.dwellers:
		if not Game.is_away(d):
			list.append(d)
	list.sort_custom(func(a, b): return float(a.happy) < float(b.happy))
	for d in list:
		var did := int(d.id)
		var picked := _diners.has(did)
		var why := Saloon.diner_block(d)
		var where: String = Loc.t("ว่าง") if int(d.room) < 0 else Data.room_def(Game.room(int(d.room)).type).th
		var b := _row_button(d, Loc.t("%s  ความสุข %d  (%s)") % [d.name, int(d.happy), Loc.t(why) if why != "" else where],
			"green" if picked else ("gray" if why != "" else "blue"))
		b.disabled = why != "" and not picked
		b.pressed.connect(func():
			if _diners.has(did):
				_diners.erase(did)
			else:
				_diners.append(did)
				while _diners.size() > 2:
					_diners.pop_front()
			refresh())
		_content.add_child(b)
	var why := Saloon.start_block(slot, _diners)
	if not _diners.is_empty() and why != "":
		_content.add_child(UIKit.wrap_label(Loc.t(why), UIKit.FS_SMALL, UIKit.C_RED))
	var go := UIKit.button(Loc.t("เริ่มมื้อเย็น %d คน (%s)") % [_diners.size(), Game.cost_text(Saloon.cost())], "green", "happy")
	go.name = "SupperStartButton"
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.set_meta("cost", Saloon.cost())
	go.set_meta("busy", _diners.is_empty())
	go.pressed.connect(func():
		if not Saloon.start(slot, _diners).is_empty():
			_diners.clear()
			mode = "main"
			refresh())
	_content.add_child(go)
	_update_buttons()


func _update_saloon() -> void:
	if _rx_bar == null or not is_instance_valid(_rx_bar):
		return
	var j := Saloon.supper(slot)
	if j.is_empty():
		return
	_rx_bar.value = RoomX.progress(j)
	var why := RoomX.paused_why(j)
	_rx_lbl.text = "%d%%  %s" % [int(RoomX.progress(j) * 100.0), Game.fmt_time(float(j.left)) if why == "" else "PAUSED"]
	_rx_lbl.size = _rx_bar.size
	_rx_lbl.position = Vector2(0, 1)


func _build_recipes(r: Dictionary, def: Dictionary) -> void:
	var recs: Array = Data.recipes(r.type)
	if recs.is_empty():
		return
	_section("CRAFTING", Loc.t("การผลิต"))
	for rec in recs:
		var active: bool = not r.job.is_empty() and r.job.id == rec.id
		var p := UIKit.panel(UIKit.C_BG2, UIKit.C_LINE if active else UIKit.C_LINE_DARK)
		var v := UIKit.vbox(2)
		p.add_child(v)
		var h := UIKit.hbox(4)
		v.add_child(h)
		h.add_child(UIKit.icon_rect(Data.item_icon(rec.out.keys()[0]), 16))
		var outs := []
		for k in rec.out:
			outs.append("%s x%d" % [Data.item_name(k), rec.out[k]])
		var lv := UIKit.vbox(0)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.add_child(UIKit.label(rec.th, UIKit.FS_SMALL, UIKit.C_TEXT))
		lv.add_child(UIKit.wrap_label("%s → %s" % [Game.cost_text(rec.cost), ", ".join(outs)], UIKit.FS_SMALL, UIKit.C_DIM))
		h.add_child(lv)
		if active:
			_job_bar = UIKit.progress(UIKit.C_GREEN, 10)
			_job_bar.custom_minimum_size.y = 10
			_job_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_job_lbl = UIKit.label("", UIKit.FP, UIKit.C_WHITE, true)
			_job_lbl.add_theme_constant_override("outline_size", 2)
			_job_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			_job_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_job_bar.add_child(_job_lbl)
			v.add_child(_job_bar)
		else:
			var b := UIKit.button(Loc.t("ผลิต"), "green", "gear")
			b.set_meta("cost", rec.cost)
			b.set_meta("busy", not r.job.is_empty())
			var rid: String = rec.id
			b.pressed.connect(func(): Game.start_craft(slot, rid))
			h.add_child(b)
		_content.add_child(p)
	_update_buttons()


func _build_upgrade(r: Dictionary, def: Dictionary) -> void:
	_section("UPGRADE", Loc.t("อัปเกรด"))
	var h := UIKit.hbox(4)
	if Game.is_constructing(slot):
		h.add_child(UIKit.label(Loc.t("กำลังอัปเกรดอยู่ (ดูด้านบน)"), UIKit.FS_SMALL, UIKit.C_GOLD))
	elif int(r.level) < Data.ROOM_MAX_LEVEL:
		var c: int = Game.upgrade_cost(slot)
		var b := UIKit.button(Loc.t("อัปเกรด Lv.%d  (%d เศษเหล็ก · %s)") % [int(r.level) + 1, c, Game.fmt_time(Game.upgrade_time(int(r.level) + 1, Game.room_span(slot)))], "yellow", "wrench")
		b.set_meta("cost", {"scrap": c})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): Game.upgrade_room(slot))
		h.add_child(b)
	else:
		h.add_child(UIKit.label(Loc.t("ห้องเลเวลสูงสุดแล้ว (MAX)"), UIKit.FS_SMALL, UIKit.C_GOLD))
	var short := Game.beds_short(slot)       # MV-420: tearing down these quarters would leave crew without a bed
	if r.type != "engine":
		var d := UIKit.button(Loc.t("รื้อ"), "red", "close")
		d.name = "DemolishButton"
		d.disabled = short >= 0
		d.pressed.connect(_request_demolish)
		h.add_child(d)
	_content.add_child(h)
	if short >= 0:
		_content.add_child(UIKit.wrap_label(Game.beds_short_text(short), UIKit.FS_SMALL, UIKit.C_GOLD))
	_update_buttons()


## knock through into a same-type neighbour (or split a large room back into single rooms)
func _build_large(r: Dictionary, def: Dictionary) -> void:
	if not str(r.type) in Data.MERGEABLE:
		return
	var span := Game.room_span(slot)
	_section("LARGE ROOM x%d" % span, Loc.t("ขยายห้อง (รวมห้องติดกัน)"))
	var p := UIKit.panel()
	var v := UIKit.vbox(2)
	p.add_child(v)
	if span > 1:
		v.add_child(UIKit.wrap_label(Loc.t("ห้องใหญ่ %d ช่อง: คนทำงาน %d ที่ · ผลงานเท่ากับ %.2f ห้อง (โบนัส +%d%%) · ใช้ไฟ -%d%%") % [span, Game.room_capacity(slot),
			Game.room_scale(slot), int(round((Game.span_efficiency(slot) - 1.0) * 100.0)), int(round((1.0 - Data.SPAN_POWER_MULT) * 100.0))], UIKit.FS_SMALL, UIKit.C_GREEN))
	else:
		v.add_child(UIKit.wrap_label(Loc.t("สร้างห้องชนิดเดียวกัน เลเวลเท่ากันไว้ติดกันบนชั้นเดียวกัน แล้วทุบผนังรวมเป็นห้องใหญ่ 2–3 ช่อง: 2 ช่อง +10%, 3 ช่อง +25%"), UIKit.FS_SMALL, UIKit.C_DIM))
	var cells := Game.room_cells(slot)
	var shown := false
	for c in [int(cells[0]) - 1, int(cells[-1]) + 1]:
		if c < 0 or c >= Game.s.rooms.size() or Game.slot_unit(c) != Game.slot_unit(slot) or Game.slot_cell(c).y != Game.slot_cell(slot).y:
			continue
		var o := Game.room_anchor(c)
		if str(Game.s.rooms[o].type) != str(r.type):
			continue
		shown = true
		var side := Loc.t("ซ้าย") if c < slot else Loc.t("ขวา")
		var why := Game.merge_block(slot, o)
		if why != "":
			v.add_child(UIKit.wrap_label(Loc.t("รวมกับห้อง%sไม่ได้: %s") % [side, why], UIKit.FS_SMALL, UIKit.C_RED))
			continue
		var cost := Game.merge_cost(slot, o)
		var n := Game.room_span(slot) + Game.room_span(o)
		var b := UIKit.button(Loc.t("รวมกับห้อง%s → %d ช่อง  (%s · %s)") % [side, n, Game.cost_text(cost), Game.fmt_time(Game.merge_time(slot, o))], "yellow", "hammer")
		b.set_meta("cost", cost)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var oo: int = o
		b.pressed.connect(func():
			if Game.merge_rooms(slot, oo):
				slot = Game.room_anchor(slot)
				refresh())
		v.add_child(b)
	if not shown and span < Data.MAX_SPAN:
		v.add_child(UIKit.wrap_label(Loc.t("ยังไม่มี%sอยู่ติดกัน") % def.th, UIKit.FS_SMALL, UIKit.C_DIM))
	if span > 1 and not Game.is_constructing(slot):
		var sp := UIKit.button(Loc.t("แยกกลับเป็น %d ห้อง (ฟรี · ไม่คืนวัสดุ)") % span, "gray", "close")
		sp.name = "SplitButton"
		var short := Game.beds_short(slot, Game.split_beds(slot))
		sp.disabled = short >= 0
		if short >= 0:
			v.add_child(UIKit.wrap_label(Game.beds_short_text(short), UIKit.FS_SMALL, UIKit.C_GOLD))
		sp.pressed.connect(_request_split)
		v.add_child(sp)
	_content.add_child(p)
	_update_buttons()


func _request_demolish() -> void:
	var target := slot
	var room: Dictionary = Game.s.rooms[target]
	var site := Game.is_site(target)
	var level := int(room.level)
	var span := Game.room_span(target)
	var title := Loc.t("ยกเลิกการก่อสร้าง") if site else Loc.t("รื้อห้อง")
	var refund := float(Data.room_def(room.type).cost) * 0.5 * span
	var detail := Loc.t("%s Lv.%d · %d ช่อง\nห้องและงานที่กำลังทำจะหายไป ลูกเรือจะว่างงาน ได้เศษเหล็กคืน %.1f ย้อนคืนไม่ได้") % [Data.room_def(room.type).th, level, span, refund]
	ConfirmPanel.ask(self, title, detail, title, func():
		Game.demolish_room(target)
		refresh(), func(): return slot == target and target < Game.s.rooms.size() and is_same(Game.s.rooms[target], room) and Game.is_site(target) == site and int(room.level) == level and Game.room_span(target) == span)


func _request_split() -> void:
	var target := slot
	var room: Dictionary = Game.s.rooms[target]
	var span := Game.room_span(target)
	ConfirmPanel.ask(self, Loc.t("แยกห้องใหญ่"), Loc.t("%s Lv.%d จะแยกเป็น %d ห้อง โบนัสห้องใหญ่จะหายไป ไม่มีวัสดุคืน") % [Data.room_def(room.type).th, int(room.level), span], Loc.t("ยืนยันแยกห้อง"), func():
		Game.split_room(target)
		refresh(), func(): return slot == target and target < Game.s.rooms.size() and is_same(Game.s.rooms[target], room) and Game.room_span(target) == span)


func _build_empty() -> void:
	set_title(Loc.t("EMPTY SLOT / ช่องว่าง — เลือกห้องที่จะสร้าง"))
	_section("SCRAP %d" % int(Game.s.res.scrap), Loc.t("วัสดุ"))
	for t in Data.buildable():
		var def := Data.room_def(t)
		var ul := Game.room_unlock_level(t)
		var locked := ul > int(Game.s.vault_level)
		var cost_line := ((Loc.t("ต้องการ Vault Lv.%d") % ul) if ul < 99 else Loc.t("ต้องมีพิมพ์เขียว")) if locked else (Loc.t("%d เศษเหล็ก · %s") % [Game.build_cost(t), Game.fmt_time(Game.build_time(t))])
		var tt: String = t
		if Features.on("build_room_effects"):
			# MV-557: a ChoiceButton grows with the wrapped effect line (a plain Button can't)
			var cb := ChoiceButton.new(def.th, "", "", "gray" if locked else "green")
			cb.add_line(Data.room_effect(t), UIKit.C_GOLD).name = "Effect"
			cb.add_line(cost_line, Color(UIKit.C_WHITE, 0.7))
			cb.add_thumb(Atlas.sub("room_" + t, Rect2(0, 0, 64, 52)), Vector2(64, 52))
			cb.disabled = locked or float(Game.s.res.scrap) < float(Game.build_cost(t))
			cb.set_meta("room_type", t)
			cb.pressed.connect(func():
				if Game.build_room(slot, tt):
					refresh())
			_content.add_child(cb)
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 34)
		b.focus_mode = Control.FOCUS_NONE
		UIKit.style_button(b, "gray" if locked else "green")
		var h := UIKit.hbox(4)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 3
		h.offset_top = 3
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 40x26 crop of the room art (no scaling)
		h.add_child(UIKit.tex_rect(Atlas.sub("room_" + t, Rect2(20, 20, 40, 26)), Vector2(40, 26)))
		var v := UIKit.vbox(0)
		v.add_child(UIKit.label(def.th, UIKit.FS_SMALL))
		v.add_child(UIKit.label(cost_line, UIKit.FS_SMALL, UIKit.C_DIM))
		h.add_child(v)
		b.add_child(h)
		b.disabled = locked or float(Game.s.res.scrap) < float(Game.build_cost(t))
		b.pressed.connect(func():
			if Game.build_room(slot, tt):
				refresh())
		_content.add_child(b)


func _build_locked() -> void:
	set_title(Loc.t("LOCKED / ชั้นที่ยังปิดตาย"))
	_content.add_child(UIKit.wrap_label(Loc.t("ชั้นนี้ยังถูกเชื่อมปิด ต้องอัปเกรดโครงรถ (Mobile Vault) เพื่อเปิดพื้นที่เพิ่ม"), UIKit.FS, UIKit.C_TEXT))
	if int(Game.s.vault_level) < Data.MAX_VAULT_LEVEL:
		var c := Game.vault_upgrade_cost()
		var b := UIKit.button(Loc.t("อัปเกรด VAULT → Lv.%d (%d เศษเหล็ก)") % [int(Game.s.vault_level) + 1, c], "yellow", "up")
		b.set_meta("cost", {"scrap": c})
		b.pressed.connect(func():
			if Game.upgrade_vault():
				refresh())
		_content.add_child(b)
	_update_buttons()


func _open_dweller(did: int) -> void:
	var hud := get_parent() as HUD
	close()
	await get_tree().create_timer(0.15).timeout
	hud.open_panel("dwellers")
	(hud.panels.dwellers as DwellersPanel).manage(did)


func _update_buttons() -> void:
	if not is_open:
		return
	for b in _content.find_children("*", "Button", true, false):
		if b.has_meta("cost"):
			b.disabled = not Game.can_afford(b.get_meta("cost")) or b.get_meta("busy", false)


func _process(_d: float) -> void:
	if not is_open or slot < 0:
		return
	_update_site()
	_update_saloon()
	if _job_bar == null or not is_instance_valid(_job_bar):
		return
	var r: Dictionary = Game.s.rooms[slot]
	if r.job.is_empty():
		return
	var p := float(r.job.progress) / float(r.job.total)
	_job_bar.value = p
	var sp := Game.craft_speed(slot)
	var left := (float(r.job.total) - float(r.job.progress)) / maxf(sp, 0.01)
	_job_lbl.text = "%d%% %dM%02dS" % [int(p * 100), int(left) / 60, int(left) % 60] if sp > 0.0 else "%d%% PAUSED" % int(p * 100)
	_job_lbl.size = _job_bar.size
	_job_lbl.position = Vector2(0, 1)
