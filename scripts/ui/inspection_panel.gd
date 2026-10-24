class_name InspectionPanel
extends ModalPanel
## v4.4 stranger at the door: flashlit close-up portrait, limited inspection points, magnified details,
## the field guide, then the call — let them in, turn them away, or shoot.

var _last_check := ""
var _outcome := ""
var _guide := false


func _build() -> void:
	max_size = Vector2(440, 680)
	Inspection.queue_changed.connect(func():
		if is_open and _outcome == "":
			refresh())


func open_door() -> void:
	_last_check = ""
	_outcome = ""
	_guide = false
	open()


func refresh() -> void:
	clear_body()
	set_title(Loc.t("STRANGER / คนแปลกหน้าที่ประตู"))
	if _outcome != "":
		_show_outcome()
		return
	var c := Inspection.current()
	if c.is_empty():
		var l := UIKit.wrap_label(Loc.t("ไม่มีใครเคาะประตู... ตอนนี้"), UIKit.FS, UIKit.C_DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(l)
		return
	var list := make_list(4)
	var wide := get_viewport_rect().size.x >= 520.0
	var top := BoxContainer.new()
	top.vertical = false
	top.add_theme_constant_override("separation", 6)
	list.add_child(top)
	top.add_child(_portrait(c, 2 if get_viewport_rect().size.x >= 300.0 else 1))
	var info := UIKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	var g: Dictionary = Inspection.GRADES[c.grade]
	info.add_child(UIKit.label(str(c.name), UIKit.FS_BIG, UIKit.C_WHITE))
	info.add_child(UIKit.label("%s · %s  Lv%d" % [g.en, g.th, int(c.lvl)], UIKit.FS_SMALL, UIKit.C_GOLD if c.grade == "rare" else UIKit.C_ORANGE))
	for stt in ["str", "int", "agi"]:
		info.add_child(UIKit.stat_bar(stt, int(c[stt])))
	var tr := []
	for t in c.traits:
		tr.append(Crew.TRAITS[t].th)
	info.add_child(UIKit.wrap_label(Loc.t("นิสัย: ") + ", ".join(tr), UIKit.FS_SMALL, UIKit.C_GREEN))
	var pts := UIKit.hbox(2)
	pts.add_child(UIKit.label("CHECKS", UIKit.FP, UIKit.C_DIM, true))
	for i in int(c.get("max_points", c.points)):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(6, 6)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = UIKit.C_GOLD if i < int(c.points) else UIKit.C_LINE_DARK
		pts.add_child(dot)
	info.add_child(pts)
	info.add_child(UIKit.label(Loc.t("รอได้อีก %s") % Game.fmt_time(float(c.wait)), UIKit.FS_SMALL, UIKit.C_DIM))
	if Inspection.queue().size() > 1:
		info.add_child(UIKit.label(Loc.t("+%d คนรอคิว") % (Inspection.queue().size() - 1), UIKit.FS_SMALL, UIKit.C_DIM))
	# magnified detail of the last check
	if _last_check != "" and (c.seen as Dictionary).has(_last_check):
		list.add_child(_detail(c, _last_check))
	else:
		list.add_child(UIKit.wrap_label(Loc.t("ส่องไฟฉายผ่านช่องประตู... เลือกจุดที่จะตรวจ (ตรวจได้ไม่ครบทุกจุด เลือกให้ดี)"), UIKit.FS_SMALL, UIKit.C_DIM))
	# check buttons
	list.add_child(UIKit.header("INSPECT", Loc.t("ตรวจร่างกาย (ใช้ 1 แต้ม)")))
	var grid := GridContainer.new()
	grid.columns = 4 if wide else 2
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	list.add_child(grid)
	for chk in Inspection.CHECKS:
		grid.add_child(_check_button(c, chk))
	# notes
	var notes := []
	for chk in c.seen:
		var sg := str(c.seen[chk])
		notes.append("%s %s: %s" % ["!" if sg != "normal" else "-", Inspection.CHECKS[chk].th, _sign_text(c, chk, sg)])
	if not notes.is_empty():
		list.add_child(UIKit.header("NOTES", Loc.t("สิ่งที่สังเกตได้")))
		for n in notes:
			list.add_child(UIKit.wrap_label(n, UIKit.FS_SMALL, UIKit.C_ORANGE if n.begins_with("!") else UIKit.C_TEXT))
	var gb := UIKit.button(Loc.t("คู่มือสังเกตสัญญาณ") if not _guide else Loc.t("ซ่อนคู่มือ"), "gray", "book")
	gb.pressed.connect(func():
		_guide = not _guide
		refresh())
	list.add_child(gb)
	if _guide:
		for k in Inspection.SIGN_TEXT:
			if k != "normal":
				list.add_child(UIKit.wrap_label("• " + Inspection.SIGN_TEXT[k], UIKit.FS_SMALL, UIKit.C_DIM))
		list.add_child(UIKit.wrap_label(Loc.t("สัญญาณเป็นแค่หลักฐานแวดล้อม: คนดีก็อาจมี 1 อย่าง คนร้ายก็ไม่ได้มีครบทุกอย่าง"), UIKit.FS_SMALL, UIKit.C_GOLD))
	# the call
	list.add_child(UIKit.divider(UIKit.C_LINE_DIM))
	var hb := UIKit.hbox(3)
	var full: bool = Game.s.dwellers.size() >= Game.pop_cap()
	var admit := UIKit.button(Loc.t("รับขึ้นรถ") if not full else Loc.t("ที่พักเต็ม"), "green", "people")
	admit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	admit.disabled = full
	admit.pressed.connect(func():
		var d := Inspection.admit(c)
		if not d.is_empty():
			_outcome = Loc.t("%s ก้าวขึ้นรถมาพร้อมรอยยิ้ม... หวังว่าคุณจะคิดถูก") % d.name
			refresh())
	hb.add_child(admit)
	var no := UIKit.button(Loc.t("ไล่ไป"), "gray", "close")
	no.pressed.connect(func():
		_outcome = Inspection.refuse(c)
		refresh())
	hb.add_child(no)
	var shoot := UIKit.button(Loc.t("ยิง"), "red", "shotgun")
	shoot.pressed.connect(func():
		_outcome = Inspection.shoot(c)
		get_tree().call_group("shake", "shake", 4.0)
		refresh())
	hb.add_child(shoot)
	list.add_child(hb)


func _portrait(c: Dictionary, k: int) -> Control:
	var frame := UIKit.panel(Color("000000"), UIKit.C_LINE)
	frame.get_theme_stylebox("panel").set_content_margin_all(1)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(64 * k, 80 * k)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(holder)
	for layer in ["door", "face_%s" % c.skin, "hair_%d" % int(c.hair), "eyes_%s" % Inspection.eye_overlay(c)]:
		var t := TextureRect.new()
		t.texture = load("res://assets/inspect/%s.png" % layer)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(t)
	return frame


func _detail(c: Dictionary, chk: String) -> Control:
	var sg := str(c.seen[chk])
	var v := UIKit.vbox(2)
	var path := Inspection.detail_image(chk, sg)
	if path != "":
		var k := 2 if get_viewport_rect().size.x >= 230.0 else 1
		var fr := UIKit.panel(Color("000000"), UIKit.C_GOLD if sg == "normal" else UIKit.C_RED)
		fr.get_theme_stylebox("panel").set_content_margin_all(1)
		fr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var img := TextureRect.new()
		img.texture = load(path)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.custom_minimum_size = Vector2(96 * k, 48 * k)
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fr.add_child(img)
		v.add_child(fr)
	var l := UIKit.wrap_label(_sign_text(c, chk, sg), UIKit.FS, UIKit.C_TEXT if sg == "normal" else UIKit.C_ORANGE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v


func _sign_text(c: Dictionary, chk: String, sg: String) -> String:
	if chk == "temp":
		return "%.1f°C — %s" % [Inspection.temp_reading(c), Inspection.SIGN_TEXT[sg]]
	if chk == "story":
		return "%s — %s" % [c.story, Inspection.SIGN_TEXT[sg]]
	return Inspection.SIGN_TEXT.get(sg, sg)


func _check_button(c: Dictionary, chk: String) -> Button:
	var def: Dictionary = Inspection.CHECKS[chk]
	var seen := (c.seen as Dictionary).has(chk)
	var sg := str(c.seen.get(chk, ""))
	var col := "yellow"
	if seen:
		col = "gray" if sg == "normal" else "red"
	var b := UIKit.button(def.th + ((Loc.t(": ปกติ") if sg == "normal" else ": !") if seen else ""), col, def.icon)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not seen and not Inspection.can_check(c, chk)
	b.pressed.connect(func():
		if not seen:
			Inspection.check(c, chk)
		_last_check = chk
		refresh())
	return b


func _show_outcome() -> void:
	var v := UIKit.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(v)
	var l := UIKit.wrap_label(_outcome, UIKit.FS_BIG, UIKit.C_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var hb := UIKit.hbox(4)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	if Inspection.pending():
		var nx := UIKit.button(Loc.t("คนต่อไป"), "yellow", "people")
		nx.pressed.connect(func():
			_outcome = ""
			_last_check = ""
			refresh())
		hb.add_child(nx)
	var ok := UIKit.button(Loc.t("ปิดประตู"), "green", "play")
	ok.pressed.connect(close)
	hb.add_child(ok)
	v.add_child(hb)
