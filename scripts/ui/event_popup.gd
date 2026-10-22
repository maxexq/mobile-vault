class_name EventPopup
extends ModalPanel
## Random-event decision terminal (blinking red alarm frame, 160x80 illustration shown at x2,
## danger skulls, choices, defender selection for fights, outcome + logbook unlocks).

var event_id := ""
var _choice := -1
var _selected: Array = []
var _t := 0.0
var _alarm: StyleBoxFlat


func _build() -> void:
	frame_color = UIKit.C_RED
	_alarm = UIKit.card_style(Color("160a08f4"), UIKit.C_RED, 6)
	_alarm.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", _alarm)
	title_lbl.add_theme_color_override("font_color", UIKit.C_RED)
	close_btn.visible = false


func _on_backdrop_tap() -> void:
	pass   # events must be answered


func show_event(id: String) -> void:
	event_id = id
	_choice = -1
	_selected = []
	open()


func _process(delta: float) -> void:
	if not is_open:
		return
	_t += delta
	_alarm.border_color = UIKit.C_RED if int(_t * 4.0) % 2 == 0 else UIKit.C_GOLD


func refresh() -> void:
	clear_body()
	var ev: Dictionary = Data.EVENTS[event_id]
	set_title("ALERT: %s / %s" % [ev.en, ev.th])
	var wide := get_viewport_rect().size.x >= 520.0
	var h := BoxContainer.new()
	h.vertical = not wide
	h.add_theme_constant_override("separation", 6)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(h)
	var img_frame := UIKit.panel(Color("000000"), UIKit.C_GOLD)
	img_frame.get_theme_stylebox("panel").set_content_margin_all(1)
	img_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	img_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var tex: Texture2D = load("res://assets/events/%s.png" % ev.image)
	var avail := get_viewport_rect().size.x - 30.0
	var k := 2 if avail >= 320.0 else 1
	var img := TextureRect.new()
	img.texture = tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.custom_minimum_size = Vector2(160 * k, 80 * k)
	img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	img_frame.add_child(img)
	h.add_child(img_frame)
	var sc := UIKit.scroll()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(sc)
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	v.add_child(UIKit.wrap_label(ev.desc, UIKit.FS, UIKit.C_TEXT))
	var dh := UIKit.hbox(3)
	var danger := Game.event_danger(event_id)
	var dtxt: String = ["ปลอดภัย", "ต่ำ", "ปานกลาง", "สูง", "สูงมาก", "อันตรายถึงชีวิต", "หายนะ"][clampi(danger, 0, 6)]
	dh.add_child(UIKit.label("DANGER", UIKit.FP, UIKit.C_RED, true))
	if danger > 0:
		dh.add_child(UIKit.skulls(danger))
	dh.add_child(UIKit.label(dtxt, UIKit.FS_SMALL, UIKit.C_RED))
	v.add_child(dh)
	if _choice < 0:
		for i in ev.choices.size():
			v.add_child(_choice_button(ev.choices[i], i))
	else:
		_build_defenders(v, ev.choices[_choice])


func _choice_button(ch: Dictionary, i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 36)
	b.focus_mode = Control.FOCUS_NONE
	UIKit.style_button(b, ch.get("color", "green"))
	var vv := UIKit.vbox(0)
	vv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vv.alignment = BoxContainer.ALIGNMENT_CENTER
	vv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIKit.label("> %s  %s" % [ch.th, ch.en], UIKit.FS, UIKit.C_WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vv.add_child(l)
	if ch.get("sub", "") != "":
		var s := UIKit.label(ch.sub, UIKit.FS_SMALL, Color(UIKit.C_WHITE, 0.75))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vv.add_child(s)
	b.add_child(vv)
	if ch.has("lore") and not Lore.is_unlocked(str(ch.lore)):
		var bk := TextureRect.new()
		bk.texture = Atlas.icon("book")
		bk.position = Vector2(3, 3)
		bk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bk.tooltip_text = "ปลดล็อกบันทึกใหม่"
		b.add_child(bk)
	if ch.has("cost"):
		b.disabled = not Game.can_afford(ch.cost)
	b.pressed.connect(func():
		UIKit.pop(b)
		if ch.action == "fight":
			_choice = i
			refresh()
		else:
			_resolve(i))
	return b


func _build_defenders(v: VBoxContainer, _ch: Dictionary) -> void:
	v.add_child(UIKit.header("DEFENDERS", "เลือกคนออกไปจัดการ (สูงสุด 2)"))
	var list: Array = []
	for d in Game.s.dwellers:
		if not Game.is_away(d):
			list.append(d)
	list.sort_custom(func(a, b): return Game.dweller_power(a) > Game.dweller_power(b))
	for d in list:
		var did: int = d.id
		var sel := _selected.has(did)
		var row := UIKit.panel(UIKit.C_BG2, UIKit.C_GREEN if sel else UIKit.C_LINE_DARK)
		var h := UIKit.hbox(4)
		row.add_child(h)
		h.add_child(UIKit.portrait(d.variant))
		var info := UIKit.vbox(1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.label("%s Lv%d  พลัง %.0f" % [d.name, d.lvl, Game.dweller_power(d)], UIKit.FS_SMALL))
		var hp := UIKit.progress(UIKit.C_RED, 3)
		hp.value = float(d.hp) / float(d.max_hp)
		info.add_child(hp)
		h.add_child(info)
		var b := UIKit.button("เลือก" if not sel else "ยกเลิก", "green" if not sel else "gray")
		b.disabled = not sel and _selected.size() >= 2
		b.pressed.connect(func():
			if _selected.has(did):
				_selected.erase(did)
			elif _selected.size() < 2:
				_selected.append(did)
			refresh())
		h.add_child(b)
		v.add_child(row)
	var total := Game.armory_bonus()
	for did in _selected:
		total += Game.dweller_power(Game.dweller_by_id(did))
	var need := 8.0 + Game.event_danger(event_id) * 6.0
	v.add_child(UIKit.wrap_label("พลังทีม %.0f vs อันตราย ~%.0f (ห้องอาวุธ +%.0f)" % [total, need, Game.armory_bonus()], UIKit.FS_SMALL, UIKit.C_GREEN if total >= need else UIKit.C_ORANGE))
	var hb := UIKit.hbox(4)
	var back := UIKit.button("< กลับ", "gray")
	back.pressed.connect(func():
		_choice = -1
		refresh())
	hb.add_child(back)
	var go := UIKit.button("ส่งทีมออกไปรบ!", "red", "skull")
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.disabled = _selected.is_empty()
	go.pressed.connect(func(): _resolve(_choice))
	hb.add_child(go)
	v.add_child(hb)


func _resolve(i: int) -> void:
	var res := Game.resolve_event(event_id, i, _selected)
	if not res.ok and Game.active_event != "":
		Game.toast.emit(res.text, "warn")
		return
	clear_body()
	set_title("OUTCOME / ผลลัพธ์")
	var v := UIKit.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(v)
	var l := UIKit.wrap_label(res.text, UIKit.FS_BIG, UIKit.C_GREEN if res.ok else UIKit.C_RED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var ok := UIKit.button("ตกลง  CONTINUE", "green", "play")
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(close)
	v.add_child(ok)
	if not res.ok:
		get_tree().call_group("shake", "shake", 6.0)
