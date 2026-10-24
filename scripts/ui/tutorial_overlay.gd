class_name TutorialOverlay
extends Control
## Draws the tutorial on top of the HUD: dims everything except the thing to touch, frames it with
## blinking pixel corner brackets and a bouncing arrow, and shows Sgt. Mark's radio card with the
## step text (typewriter), a step counter and Skip / Next. Never blocks input outside the card, so
## the player always taps the real button underneath.

const DIM := Color(0.02, 0.015, 0.01, 0.5)
const PAD := 3.0
const TYPE_CPS := 45.0

var hud: HUD
var main: Node
var _card: PanelContainer
var _head: Label
var _text: Label
var _hint: Label
var _bar: ProgressBar
var _next_btn: Button
var _skip_btn: Button
var _target := Rect2()
var _has_target := false
var _time := 0.0
var _chars := 0.0
var _shown_step := -2


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UIKit.card_style(Color(0.07, 0.065, 0.055, 0.97), UIKit.C_GOLD, 4))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.gui_input.connect(_on_card_input)
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
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING   # lines don't reflow while typing
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	_bar = UIKit.progress(UIKit.C_GOLD, 4)
	_bar.visible = false
	v.add_child(_bar)
	var row := UIKit.hbox(4)
	_hint = UIKit.label("", UIKit.FP, UIKit.C_GREEN, true)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_hint)
	_skip_btn = UIKit.button(Loc.t("ข้าม"), "gray")
	_skip_btn.custom_minimum_size = Vector2(40, 22)
	_skip_btn.tooltip_text = Loc.t("ข้ามบทแนะนำทั้งหมด (เปิดใหม่ได้ที่ Log)")
	_skip_btn.pressed.connect(Tutorial.skip)
	row.add_child(_skip_btn)
	_next_btn = UIKit.button(Loc.t("ต่อไป"), "green", "play")
	_next_btn.custom_minimum_size = Vector2(56, 22)
	_next_btn.pressed.connect(_on_next)
	row.add_child(_next_btn)
	v.add_child(row)
	Tutorial.step_changed.connect(func(_i): _shown_step = -2)
	visible = false


func _on_card_input(e: InputEvent) -> void:
	# tapping the card finishes the typewriter at once
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_chars = float(_text.text.length())


func _on_next() -> void:
	if _text.visible_characters >= 0 and _text.visible_characters < _text.text.length():
		_chars = float(_text.text.length())
		return
	Tutorial.next()


## true while the tutorial should be on screen (hidden behind unrelated pop-ups like road events)
func _should_show() -> bool:
	if hud == null or not Tutorial.active() or hud.title_screen.visible:
		return false
	var want: String = str(Tutorial.current().get("panel", ""))
	if hud.event_popup.is_open:
		return false
	for k in hud.panels:
		if hud.panels[k].is_open and k != want:
			return false
	if hud.room_closeup.is_open and want != "closeup":
		return false
	return true


func _process(d: float) -> void:
	var show := _should_show()
	if visible != show:
		visible = show
		_shown_step = -2
	if not show:
		return
	_time += d
	if _shown_step != Tutorial.step():
		_enter_step()
	if _text.visible_characters >= 0:
		_chars += d * TYPE_CPS
		_text.visible_characters = -1 if _chars >= _text.text.length() else int(_chars)
	_update_target()
	_update_bar()
	_place_card()
	queue_redraw()


func _enter_step() -> void:
	_shown_step = Tutorial.step()
	var st := Tutorial.current()
	var manual := bool(st.get("manual", false))
	_head.text = "SGT.MARK · TUTORIAL %d/%d" % [Tutorial.step() + 1, Tutorial.STEPS.size()]
	_text.text = Tutorial.text()
	_chars = 0.0
	_text.visible_characters = 0
	_next_btn.visible = manual
	_next_btn.text = Loc.t("เริ่มเลย") if st.id == "done" else Loc.t("ต่อไป")
	_skip_btn.visible = st.id != "done"
	_hint.text = "" if manual else "> DO IT NOW"
	_bar.visible = st.id == "construct"
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.2)


func _update_bar() -> void:
	if not _bar.visible:
		return
	var sl := Tutorial.constructing_slot()
	if sl < 0:
		return
	var b: Dictionary = Game.s.rooms[sl].get("build", {})
	var total := maxf(0.001, float(b.get("total", 1.0)))
	_bar.value = 1.0 - float(b.get("left", 0.0)) / total
	_hint.text = "%ds" % int(ceil(float(b.get("left", 0.0))))


# ------------------------------------------------------------------ target framing
func _update_target() -> void:
	var t: String = str(Tutorial.current().get("target", "none"))
	_has_target = false
	var c: Control = null
	if t == "res":
		c = hud._res_row
	elif t == "combat":
		c = hud._combat_box
	elif t == "travel":
		c = hud._travel
	elif t.begins_with("tool:"):
		c = hud._tool_buttons.get(t.substr(5))
	elif t.begins_with("panel:"):
		var p: ModalPanel = hud.panels.get(t.substr(6))
		if p != null and p.is_open:
			c = p.box
	elif t.begins_with("world_slot:"):
		_frame_slot(int(t.substr(11)))
		return
	elif t == "world_build":
		_frame_slot(Tutorial.free_slot())
		return
	elif t == "world_constructing":
		_frame_slot(Tutorial.constructing_slot())
		return
	if c != null and c.is_visible_in_tree():
		_target = c.get_global_rect().grow(PAD)
		_has_target = true


func _frame_slot(slot: int) -> void:
	if slot < 0 or main == null or main.vehicle == null:
		return
	var r: Rect2 = main.vehicle.slot_global_rect(slot)
	var a: Vector2 = main.world_to_screen(r.position)
	var b: Vector2 = main.world_to_screen(r.end)
	_target = Rect2(a.floor(), (b - a).ceil()).grow(PAD)
	_has_target = true


## keep the card away from the thing it points at: top when the target is low, otherwise bottom
func _place_card() -> void:
	var vp := size
	var w := minf(340.0, vp.x - 8.0)
	_text.custom_minimum_size.x = w - 70.0
	_card.custom_minimum_size.x = w
	_card.reset_size()
	var x := floorf((vp.x - _card.size.x) * 0.5)
	var top_y: float = hud._top.position.y + hud._top.size.y + 26.0 if hud._top.visible else 6.0
	var bottom_y := vp.y - _card.size.y - 48.0
	var st := Tutorial.current()
	var y := bottom_y
	if str(st.get("panel", "")).length() > 0 and st.panel != "closeup":
		y = vp.y - _card.size.y - 4.0     # inside a window: hug the screen bottom
	elif st.get("panel", "") == "closeup" or (_has_target and _target.get_center().y > vp.y * 0.5):
		y = top_y
	elif not _has_target:
		y = floorf((vp.y - _card.size.y) * 0.45)
	_card.position = Vector2(x, floorf(clampf(y, 2.0, vp.y - _card.size.y - 2.0)))


func _draw() -> void:
	if not _has_target:
		return
	var r := Rect2(_target.position.floor(), _target.size.floor())
	# dim everything around the target (4 rects; input still passes through)
	if not bool(Tutorial.current().get("manual", false)) or Tutorial.step_id() in ["resources", "combat", "travel"]:
		var vp := size
		draw_rect(Rect2(0, 0, vp.x, r.position.y), DIM)
		draw_rect(Rect2(0, r.end.y, vp.x, vp.y - r.end.y), DIM)
		draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), DIM)
		draw_rect(Rect2(r.end.x, r.position.y, vp.x - r.end.x, r.size.y), DIM)
	# blinking corner brackets, pulsing out by one pixel
	var blink := fmod(_time, 0.8) < 0.55
	var col := UIKit.C_GOLD if blink else UIKit.C_ORANGE
	var o := 1.0 if fmod(_time, 0.5) < 0.25 else 0.0
	var a := r.position - Vector2(o, o)
	var b := r.end + Vector2(o, o)
	var L := floorf(minf(8.0, minf(r.size.x, r.size.y) * 0.4))
	var bars := [Rect2(a.x, a.y, L, 2), Rect2(a.x, a.y, 2, L), Rect2(b.x - L, a.y, L, 2), Rect2(b.x - 2, a.y, 2, L),
		Rect2(a.x, b.y - 2, L, 2), Rect2(a.x, b.y - L, 2, L), Rect2(b.x - L, b.y - 2, L, 2), Rect2(b.x - 2, b.y - L, 2, L)]
	for br in bars:
		draw_rect((br as Rect2).grow(1), Color.BLACK)
	for br in bars:
		draw_rect(br, col)
	# bouncing pixel arrow, above the target (below it when the target hugs the top)
	if not bool(Tutorial.current().get("manual", false)):
		var bounce := floorf(absf(sin(_time * 6.0)) * 3.0)
		var cx := floorf(r.get_center().x)
		if r.position.y > 24.0:
			var ty := r.position.y - 4.0 - bounce
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, ty - 6), Vector2(cx + 6, ty - 6), Vector2(cx + 0.5, ty)]), Color.BLACK)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 3, ty - 5), Vector2(cx + 4, ty - 5), Vector2(cx + 0.5, ty - 1)]), UIKit.C_GOLD)
		else:
			var by := r.end.y + 4.0 + bounce
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, by + 6), Vector2(cx + 6, by + 6), Vector2(cx + 0.5, by)]), Color.BLACK)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 3, by + 5), Vector2(cx + 4, by + 5), Vector2(cx + 0.5, by + 1)]), UIKit.C_GOLD)
