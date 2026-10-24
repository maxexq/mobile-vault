class_name TipCard
extends Control
## Contextual tip (MV-150): the first time a system's window opens, Sgt. Mark's radio card explains it once
## (Tutorial.TIPS). It sits at the bottom of the screen over the window, only the card takes taps, and
## "เข้าใจแล้ว" marks the tip seen. Hidden while the first-run tutorial runs or when tips are off.

var hud: HUD
var key := ""            # tip on screen ("" = none)
var _card: PanelContainer
var _head: Label
var _text: Label
var _ok: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UIKit.card_style(Color(0.07, 0.065, 0.055, 0.97), UIKit.C_GOLD, 4))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	var h := UIKit.hbox(5)
	_card.add_child(h)
	var pv := UIKit.vbox(1)
	pv.add_child(UIKit.portrait("dw_army_brown", true))
	var radio := UIKit.label("CH.7", UIKit.FP, UIKit.C_GREEN, true)
	radio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(radio)
	h.add_child(pv)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_head = UIKit.label("", UIKit.FP, UIKit.C_GOLD, true)
	v.add_child(_head)
	_text = UIKit.label("", UIKit.FS_SMALL, UIKit.C_TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	_ok = UIKit.button(Loc.t("เข้าใจแล้ว"), "yellow")
	_ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	_ok.pressed.connect(dismiss)
	v.add_child(_ok)


## systems whose window is on screen now: HUD panels, the room close-up, road events, special encounters
func open_keys() -> Array:
	var out := []
	if hud == null:
		return out
	for k in hud.panels:
		if hud.panels[k].is_open:
			out.append(k)
	if hud.event_popup.is_open:
		out.append("event")
	if hud.encounter_popup.is_open:
		out.append("encounter")
	return out


func _process(_d: float) -> void:
	var want := Tutorial.pending_tip(open_keys())
	if want != key:
		key = want
		if key != "":
			_head.text = "SGT.MARK · TIP"
			_text.text = Tutorial.tip_text(key)
			_ok.text = Loc.t("เข้าใจแล้ว")
			_card.modulate.a = 0.0
			create_tween().tween_property(_card, "modulate:a", 1.0, 0.2)
	visible = key != ""
	if visible:
		_place()


func dismiss() -> void:
	if key != "":
		Tutorial.mark_tip(key)
	key = ""
	visible = false


func _place() -> void:
	var w := minf(340.0, size.x - 8.0)
	_text.custom_minimum_size.x = w - 70.0
	_card.custom_minimum_size.x = w
	_card.reset_size()
	_card.position = Vector2(floorf((size.x - _card.size.x) * 0.5), floorf(size.y - _card.size.y - 4.0))
