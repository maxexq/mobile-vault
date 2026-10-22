class_name EventPopup
extends ModalPanel
## Random-event decision terminal (blinking red alarm frame, 160x80 illustration shown at x2,
## danger skulls, choices, defender selection for fights, outcome + logbook unlocks).

var event_id := ""
var _choice := -1
var _selected: Array = []
var _t := 0.0
var _alarm: StyleBoxFlat
var _outcome_ok := -1   # -1 deciding, 0 failed, 1 survived

## fired when the outcome screen opens (hook for a good/bad stinger once sfx exist)
signal outcome_shown(ok: bool)


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
	_outcome_ok = -1
	_choice = -1
	_selected = []
	open()


func _process(delta: float) -> void:
	if not is_open:
		return
	_t += delta
	match _outcome_ok:
		1: _alarm.border_color = UIKit.C_GREEN if int(_t * 1.5) % 2 == 0 else UIKit.C_LINE
		0: _alarm.border_color = UIKit.C_RED if int(_t * 6.0) % 2 == 0 else Color("3a0c08")
		_: _alarm.border_color = UIKit.C_RED if int(_t * 4.0) % 2 == 0 else UIKit.C_GOLD


func refresh() -> void:
	clear_body()
	var ev: Dictionary = Data.EVENTS[event_id]
	set_title("ALERT: %s / %s" % [ev.en, ev.th])
	var v := media_layout(load("res://assets/events/%s.png" % ev.image), UIKit.C_GOLD)
	v.add_child(UIKit.wrap_label(ev.desc, UIKit.FS, UIKit.C_TEXT))
	var dh := UIKit.hbox(3)
	var danger := Game.event_danger(event_id)
	var dtxt: String = ["ปลอดภัย", "ต่ำ", "ปานกลาง", "สูง", "สูงมาก", "อันตรายถึงชีวิต", "หายนะ"][clampi(danger, 0, 6)]
	var dl := UIKit.label("DANGER", UIKit.FP, UIKit.C_RED, true)
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dh.add_child(dl)
	if danger > 0:
		dh.add_child(UIKit.skulls(danger))
	var dt := UIKit.wrap_label(dtxt, UIKit.FS_SMALL, UIKit.C_RED)
	dt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dh.add_child(dt)
	v.add_child(dh)
	if _choice < 0:
		for i in ev.choices.size():
			v.add_child(_choice_button(ev.choices[i], i))
	else:
		_build_defenders(v, ev.choices[_choice])


func _choice_button(ch: Dictionary, i: int) -> ChoiceButton:
	var b := ChoiceButton.new(ch.th, ch.en, ch.get("sub", ""), ch.get("color", "green"))
	if ch.has("lore") and not Lore.is_unlocked(str(ch.lore)):
		b.add_badge(Atlas.icon("book"), "ปลดล็อกบันทึกใหม่")
	if ch.has("cost"):
		b.disabled = not Game.can_afford(ch.cost)
	b.pressed.connect(func():
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
	var before := _snapshot()
	var res := Game.resolve_event(event_id, i, _selected)
	if not res.ok and Game.active_event != "":
		Game.toast.emit(res.text, "warn")
		return
	_show_outcome(res, _changes(before, _snapshot()))


## everything an event can touch, so the outcome screen can show what actually changed
func _snapshot() -> Dictionary:
	var crew := {}
	for d in Game.s.dwellers:
		crew[int(d.id)] = {"hp": float(d.hp), "rads": float(d.rads), "happy": float(d.happy), "xp": float(d.xp)}
	return {"res": (Game.s.res as Dictionary).duplicate(), "items": (Game.s.items as Dictionary).duplicate(),
		"hull": float(Game.s.hull), "gear": Loot.stash().size(), "stall": float(Game.s.stall), "crew": crew}


func _changes(a: Dictionary, b: Dictionary) -> Dictionary:
	var rows := []
	for k in b.res:
		var dv := int(round(float(b.res[k]) - float(a.res.get(k, 0.0))))
		if dv != 0:
			rows.append({"icon": Data.item_icon(k), "name": Data.item_name(k), "n": dv})
	var keys: Array = (a.items as Dictionary).keys()
	for k in b.items:
		if not keys.has(k):
			keys.append(k)
	for k in keys:
		var dv := int(b.items.get(k, 0)) - int(a.items.get(k, 0))
		if dv != 0:
			rows.append({"icon": Data.item_icon(str(k)), "name": Data.item_name(str(k)), "n": dv})
	if int(b.gear) > int(a.gear):
		rows.append({"icon": "chest", "name": "อุปกรณ์ใหม่", "n": int(b.gear) - int(a.gear)})
	var hd := int(round(float(b.hull) - float(a.hull)))
	if hd != 0:
		rows.append({"icon": "hull", "name": "ตัวถัง", "n": hd, "suffix": "%"})
	if float(b.stall) > float(a.stall) + 0.5:
		rows.append({"icon": "pause", "name": "จอดรอ", "n": int(b.stall), "suffix": " วิ", "neutral": true})
	var crew := []
	for d in Game.s.dwellers:
		var id := int(d.id)
		var tags := []
		if not (a.crew as Dictionary).has(id):
			tags.append(["NEW", UIKit.C_GOLD])
		else:
			var o: Dictionary = a.crew[id]
			var c: Dictionary = b.crew[id]
			var dhp := int(round(c.hp - o.hp))
			if dhp != 0:
				tags.append(["%+d HP" % dhp, UIKit.C_GREEN if dhp > 0 else UIKit.C_RED])
			var drad := int(round(c.rads - o.rads))
			if drad > 0:
				tags.append(["+%d RAD" % drad, UIKit.C_ORANGE])
			var dxp := int(round(c.xp - o.xp))
			if dxp > 0:
				tags.append(["+%d XP" % dxp, UIKit.C_BLUE])
			var dh := int(round(c.happy - o.happy))
			if dh != 0:
				tags.append(["%+d :)" % dh, UIKit.C_GREEN if dh > 0 else UIKit.C_RED])
		if not tags.is_empty():
			crew.append({"d": d, "tags": tags})
	return {"rows": rows, "crew": crew}


func _show_outcome(res: Dictionary, ch: Dictionary) -> void:
	_outcome_ok = 1 if res.ok else 0
	clear_body()
	set_title("OUTCOME / ผลลัพธ์")
	var col := UIKit.C_GREEN if res.ok else UIKit.C_RED
	var ev: Dictionary = Data.EVENTS[event_id]
	var v := media_layout(load("res://assets/events/%s.png" % ev.image), col)
	_stamp(media, res.ok)
	var l := UIKit.wrap_label(res.text, UIKit.FS_BIG, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var delay := 0.35
	if not ch.rows.is_empty():
		v.add_child(UIKit.header("CHANGES", "ทรัพยากรที่เปลี่ยนไป", col))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 3)
		v.add_child(grid)
		for r in ch.rows:
			grid.add_child(_change_row(r, delay))
			delay += 0.09
	if not ch.crew.is_empty():
		v.add_child(UIKit.header("CREW", "ลูกเรือที่ได้รับผล", col))
		var fl := UIKit.flow(4)
		v.add_child(fl)
		for c in ch.crew.slice(0, 8):
			fl.add_child(_crew_chip(c.d, c.tags, delay))
			delay += 0.07
		if ch.crew.size() > 8:
			fl.add_child(UIKit.label("+%d คน" % (ch.crew.size() - 8), UIKit.FS_SMALL, UIKit.C_DIM))
	var ok := UIKit.button("ตกลง  CONTINUE", "green" if res.ok else "red", "play")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.custom_minimum_size.y = 32
	ok.pressed.connect(close)
	v.add_child(ok)
	_fade_in(ok, delay)
	outcome_shown.emit(res.ok)
	if not res.ok:
		get_tree().call_group("shake", "shake", 6.0)


## "CLEARED" / "FAILED" stamp slammed over the illustration; failure tints the art red
func _stamp(frame: PanelContainer, ok: bool) -> void:
	var img: Control = frame.get_child(0)
	img.modulate = Color(1, 1, 1) if ok else Color(1.0, 0.45, 0.4)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(cc)
	var st := PanelContainer.new()
	var sb := UIKit.card_style(Color(0, 0, 0, 0.72), UIKit.C_GREEN if ok else UIKit.C_RED, 4)
	sb.set_border_width_all(2)
	st.add_theme_stylebox_override("panel", sb)
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sv := UIKit.vbox(0)
	st.add_child(sv)
	var t := UIKit.label("SURVIVED" if ok else "FAILED", 18, UIKit.C_GREEN if ok else UIKit.C_RED, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(t)
	var th := UIKit.label("รอดมาได้" if ok else "พลาดท่า", UIKit.FS_SMALL, UIKit.C_WHITE)
	th.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(th)
	cc.add_child(st)
	st.modulate = Color(3, 3, 3, 0)
	var tw := st.create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(st, "modulate", Color.WHITE, 0.16)
	if not ok:
		tw.tween_property(img, "modulate", Color(1.4, 0.5, 0.45), 0.06)
		tw.tween_property(img, "modulate", Color(1.0, 0.45, 0.4), 0.2)


## icon + name + count-up delta (green gain, red loss)
func _change_row(r: Dictionary, delay: float) -> Control:
	var p := UIKit.panel(UIKit.C_BG2, UIKit.C_LINE_DARK)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UIKit.hbox(4)
	p.add_child(h)
	var ic := UIKit.icon_rect(str(r.icon), 16)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var nm := UIKit.wrap_label(str(r.name), UIKit.FS_SMALL, UIKit.C_TEXT)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(nm)
	var n := int(r.n)
	var sfx: String = r.get("suffix", "")
	var c := UIKit.C_GOLD if r.get("neutral", false) else (UIKit.C_GREEN if n > 0 else UIKit.C_RED)
	var num := UIKit.label("+0" + sfx, UIKit.FS, c)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(num)
	var neutral: bool = r.get("neutral", false)
	var tw := _fade_in(p, delay)
	tw.tween_method(func(x: float):
		num.text = ("%d" % int(round(x)) if neutral else "%+d" % int(round(x))) + sfx, 0.0, float(n), 0.45)
	return p


func _crew_chip(d: Dictionary, tags: Array, delay: float) -> Control:
	var p := UIKit.panel(UIKit.C_BG2, UIKit.C_LINE_DARK)
	var h := UIKit.hbox(3)
	p.add_child(h)
	h.add_child(UIKit.portrait(d.variant))
	var info := UIKit.vbox(0)
	h.add_child(info)
	info.add_child(UIKit.label(str(d.name), UIKit.FS_SMALL, UIKit.C_WHITE))
	var tl := UIKit.hbox(3)
	info.add_child(tl)
	for t in tags:
		tl.add_child(UIKit.label(t[0], UIKit.FP, t[1], true))
	_fade_in(p, delay)
	return p


func _fade_in(c: Control, delay: float) -> Tween:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 1.0, 0.12)
	return tw
