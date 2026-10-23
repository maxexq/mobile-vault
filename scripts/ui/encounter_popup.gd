class_name EncounterPopup
extends ModalPanel
## Expedition special-encounter terminal (v4.4): radio call from the team inside the site — 160x80
## illustration at x2, who is out there, the choices with their odds/costs, then the outcome.
## Unlike road events it can be closed ("decide later"): the team keeps waiting until it walks back.

var _t := 0.0
var _alarm: StyleBoxFlat
var _result := {}
var _outcome_col = null   # frame colour once the outcome is shown


func _build() -> void:
	frame_color = UIKit.C_GOLD
	_alarm = UIKit.card_style(Color("14100af4"), UIKit.C_GOLD, 6)
	_alarm.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", _alarm)
	title_lbl.add_theme_color_override("font_color", UIKit.C_GOLD)
	Encounter.encounter_ready.connect(func(_id):
		if is_open:
			refresh())


func show_encounter() -> void:
	_result = {}
	_outcome_col = null
	open()


func _process(delta: float) -> void:
	if not is_open:
		return
	_t += delta
	if _outcome_col != null:
		var bad: bool = _outcome_col == UIKit.C_RED
		_alarm.border_color = _outcome_col if int(_t * (6.0 if bad else 1.5)) % 2 == 0 else UIKit.C_LINE_DARK
	else:
		_alarm.border_color = UIKit.C_GOLD if int(_t * 3.0) % 2 == 0 else UIKit.C_ORANGE


func refresh() -> void:
	clear_body()
	if not _result.is_empty():
		_build_result()
		return
	if not Encounter.pending():
		close.call_deferred()
		return
	var ev := Encounter.def(Encounter.current_id())
	set_title("RADIO: %s / %s" % [ev.en, ev.th])
	var v := media_layout(load("res://assets/events/%s.png" % ev.image), UIKit.C_GOLD)
	var site_th: String = Expedition.site_def(str(Expedition.state().site)).th
	v.add_child(UIKit.label("จุดพิเศษใน %s" % site_th, UIKit.FS_SMALL, UIKit.C_GOLD))
	v.add_child(UIKit.wrap_label(ev.desc, UIKit.FS, UIKit.C_TEXT))
	var team := UIKit.flow(3)
	for d in Expedition.team():
		var who := UIKit.hbox(2)
		team.add_child(who)
		who.add_child(UIKit.portrait(d.variant))
		var hp_col := UIKit.C_GREEN if float(d.hp) > float(d.max_hp) * 0.4 else UIKit.C_RED
		who.add_child(UIKit.label("%s %d%%" % [d.name, int(100.0 * float(d.hp) / float(d.max_hp))], UIKit.FS_SMALL, hp_col))
	v.add_child(team)
	var choices: Array = ev.choices
	for i in choices.size():
		v.add_child(_choice_button(choices[i], i))
	var tl := Expedition.time_left()
	v.add_child(UIKit.wrap_label("ถ้าไม่สั่งภายใน %d:%02d (ก่อนทีมกลับ) ทีมจะเลือก \"%s\" เอง" % [int(tl) / 60, int(tl) % 60, choices[-1].th], UIKit.FS_SMALL, UIKit.C_DIM))
	var later := UIKit.button("ตัดสินใจทีหลัง", "gray")
	later.pressed.connect(close)
	v.add_child(later)


func _choice_button(ch: Dictionary, i: int) -> ChoiceButton:
	var b := ChoiceButton.new(ch.th, ch.en, Encounter.choice_sub(ch), ch.get("color", "green"))
	b.disabled = Encounter.blocked(ch) != ""
	b.pressed.connect(func(): choose(i))
	return b


func choose(i: int) -> void:
	var before := _snapshot()
	var id := Encounter.current_id()
	var res := Encounter.choose(i)
	if Encounter.pending() or (str(res.text) == "" and not res.ok):
		if str(res.text) != "":
			Game.toast.emit(res.text, "warn")
		return
	_result = res.duplicate()
	_result["id"] = id
	_result.merge(_changes(before, _snapshot()))
	refresh()
	if not res.ok:
		get_tree().call_group("shake", "shake", 4.0)


## what the radio call can change: the haul waiting to come home, team supplies, the return timer, the team
func _snapshot() -> Dictionary:
	var enc := Encounter.state()
	var e := Expedition.state()
	var team := {}
	for d in Expedition.team():
		team[int(d.id)] = {"hp": float(d.hp), "inf": float(d.get("infection", 0.0))}
	return {"bonus": (enc.get("bonus", {}) as Dictionary).duplicate(), "recruits": int(enc.get("recruits", 0)),
		"lose": float(enc.get("lose", 0.0)), "sup": (e.get("sup", {}) as Dictionary).duplicate(),
		"dur": float(e.get("dur", 0.0)), "team": team}


func _changes(a: Dictionary, b: Dictionary) -> Dictionary:
	var rows := []
	for k in b.bonus:
		var dv := int(b.bonus[k]) - int(a.bonus.get(k, 0))
		if dv != 0:
			rows.append({"icon": Data.item_icon(str(k)), "name": Data.item_name(str(k)), "n": dv})
	if int(b.recruits) > int(a.recruits):
		rows.append({"icon": "people", "name": "ผู้รอดชีวิตตามมา", "n": int(b.recruits) - int(a.recruits)})
	for k in a.sup:
		var dv := int(b.sup.get(k, 0)) - int(a.sup[k])
		if dv != 0:
			rows.append({"icon": Data.item_icon(str(k)), "name": "เสบียงทีม: " + Data.item_name(str(k)), "n": dv})
	var dl := int(round((float(b.lose) - float(a.lose)) * 100.0))
	if dl > 0:
		rows.append({"icon": "backpack", "name": "ของจากจุดสำรวจ", "n": -dl, "suffix": "%"})
	if float(b.dur) > float(a.dur) + 0.5:
		rows.append({"icon": "pause", "name": "ทีมกลับช้าลง", "n": int(b.dur - a.dur), "suffix": " วิ", "neutral": true})
	var crew := []
	for d in Expedition.team():
		var o: Dictionary = a.team.get(int(d.id), {})
		if o.is_empty():
			continue
		var tags := []
		var dhp := int(round(float(d.hp) - float(o.hp)))
		if dhp != 0:
			tags.append(["%+d HP" % dhp, UIKit.C_GREEN if dhp > 0 else UIKit.C_RED])
		var dinf := int(round(float(d.get("infection", 0.0)) - float(o.inf)))
		if dinf > 0:
			tags.append(["+%d INF" % dinf, UIKit.C_ORANGE])
		if not tags.is_empty():
			crew.append({"d": d, "tags": tags})
	return {"rows": rows, "crew": crew}


func _build_result() -> void:
	set_title("RADIO / ผลการตัดสินใจ")
	var ok: bool = _result.ok
	var quiet: bool = ok and (_result.get("rows", []) as Array).is_empty() and (_result.get("crew", []) as Array).is_empty()
	var col := UIKit.C_RED if not ok else (UIKit.C_GOLD if quiet else UIKit.C_GREEN)
	_outcome_col = col
	var ev := Encounter.def(str(_result.get("id", Encounter.current_id())))
	var v := media_layout(load("res://assets/events/%s.png" % ev.image), col)
	OutcomeKit.stamp(media, "MAYDAY" if not ok else ("ROGER" if quiet else "MISSION SUCCESS"),
		"ทีมเจอปัญหา" if not ok else ("รับทราบ" if quiet else "ภารกิจสำเร็จ"), col, not ok)
	_static(media.get_child(0))
	# the team's report comes in over the radio, typed out letter by letter
	var rx := UIKit.hbox(4)
	rx.alignment = BoxContainer.ALIGNMENT_CENTER
	var dot := UIKit.label("RX", UIKit.FP, col, true)
	rx.add_child(dot)
	rx.add_child(UIKit.label("ทีมรายงานกลับมาทางวิทยุ", UIKit.FS_SMALL, Color(col, 0.8)))
	v.add_child(rx)
	var blink := dot.create_tween().set_loops(6)
	blink.tween_property(dot, "modulate:a", 0.2, 0.18)
	blink.tween_property(dot, "modulate:a", 1.0, 0.18)
	var l := UIKit.wrap_label("\"%s\"" % str(_result.text), UIKit.FS_BIG, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.visible_ratio = 0.0
	v.add_child(l)
	l.create_tween().tween_property(l, "visible_ratio", 1.0, clampf(str(_result.text).length() * 0.025, 0.4, 1.4))
	var delay := OutcomeKit.lists(v, _result.get("rows", []), _result.get("crew", []), col, "ของที่ทีมจะขนกลับมา", 0.6)
	var tl := Expedition.time_left()
	var note := UIKit.wrap_label("ของที่ได้และผู้รอดชีวิตจะกลับมาพร้อมทีมสำรวจ · อีก %d:%02d" % [int(tl) / 60, int(tl) % 60], UIKit.FS_SMALL, UIKit.C_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	OutcomeKit.fade_in(note, delay)
	var btn := UIKit.button("ตกลง  CONTINUE", "red" if not ok else "green", "play")
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size.y = 32
	btn.pressed.connect(close)
	v.add_child(btn)
	OutcomeKit.fade_in(btn, delay)


## radio static: the picture flickers in like a weak transmission
func _static(img: Control) -> void:
	var base := img.modulate
	var tw := img.create_tween()
	for k in 4:
		tw.tween_property(img, "modulate", Color(base, 0.25), 0.04)
		tw.tween_property(img, "modulate", base, 0.06)
