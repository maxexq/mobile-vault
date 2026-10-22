class_name EncounterPopup
extends ModalPanel
## Expedition special-encounter terminal (v4.4): radio call from the team inside the site — 160x80
## illustration at x2, who is out there, the choices with their odds/costs, then the outcome.
## Unlike road events it can be closed ("decide later"): the team keeps waiting until it walks back.

var _t := 0.0
var _alarm: StyleBoxFlat
var _result := {}


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
	open()


func _process(delta: float) -> void:
	if not is_open:
		return
	_t += delta
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
	var res := Encounter.choose(i)
	if Encounter.pending() or (str(res.text) == "" and not res.ok):
		if str(res.text) != "":
			Game.toast.emit(res.text, "warn")
		return
	_result = res
	refresh()
	if not res.ok:
		get_tree().call_group("shake", "shake", 4.0)


func _build_result() -> void:
	set_title("RADIO / ผลการตัดสินใจ")
	var v := UIKit.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(v)
	var l := UIKit.wrap_label(str(_result.text), UIKit.FS_BIG, UIKit.C_GREEN if _result.ok else UIKit.C_RED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.add_child(UIKit.wrap_label("ของที่ได้และผู้รอดชีวิตจะกลับมาพร้อมทีมสำรวจ", UIKit.FS_SMALL, UIKit.C_DIM))
	var ok := UIKit.button("ตกลง  CONTINUE", "green", "play")
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(close)
	v.add_child(ok)
