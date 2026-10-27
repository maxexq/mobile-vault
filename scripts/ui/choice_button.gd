class_name ChoiceButton
extends PanelContainer
## Decision button whose height follows its wrapped text (Thai title, pixel EN tag, cost/odds line).
## A plain Button can't grow with child labels, so the styled Button and the label stack are both
## children of this PanelContainer: the container fits every child to the tallest one's minimum size.

signal pressed

## UI px kept clear for the button frame around a thumbnail (add_thumb), so the art never covers the border line
const THUMB_INSET := 3   # the btn frame: dark, grey, dark line

var button: Button
var _text: VBoxContainer
var disabled := false:
	set(v):
		disabled = v
		if button:
			button.disabled = v
		modulate = Color(1, 1, 1, 0.55) if v else Color.WHITE


func _init(th: String, en: String, sub: String = "", color_key: String = "green") -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, UIKit.MIN_TOUCH)
	button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	UIKit.style_button(button, color_key)
	button.pressed.connect(func():
		UIKit.pop(self)
		pressed.emit())
	add_child(button)
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 8)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 4)
	add_child(m)
	var v := UIKit.vbox(1)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	_text = v
	var fc: Color = button.get_theme_color("font_color")
	var t := UIKit.wrap_label("> " + th, UIKit.FS, fc)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if en != "":
		var e := UIKit.wrap_label(en.to_upper(), UIKit.FP, Color(fc, 0.6))
		e.add_theme_font_override("font", UIKit.font_pixel)
		e.add_theme_font_size_override("font_size", UIKit.FP)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(e)
	if sub != "":
		var s := UIKit.wrap_label(sub, UIKit.FS_SMALL, Color(UIKit.C_WHITE, 0.75))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)


## one more wrapped line under the others (MV-557: a room's effect in the empty-slot build list)
func add_line(text: String, color: Color, size: int = UIKit.FS_SMALL) -> Label:
	var l := UIKit.wrap_label(text, size, color)
	l.horizontal_alignment = _text.get_child(0).horizontal_alignment
	_text.add_child(l)
	return l


## framed art flush with the left edge and as tall as the button (inside its frame); the text stack lines up left beside
## it (MV-557: room previews in the empty-slot build list). px = the art's smallest size; a taller row covers it.
func add_thumb(tex: Texture2D, px: Vector2) -> void:
	var m := _text.get_parent() as MarginContainer
	for side in ["left", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, THUMB_INSET)
	var h := UIKit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.remove_child(_text)
	m.add_child(h)
	# a 1 px amber frame, like the room shown above the close-up
	var f := PanelContainer.new()
	f.name = "ThumbFrame"
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.size_flags_vertical = Control.SIZE_FILL
	var sb := UIKit.card_style(Color.BLACK, UIKit.C_GOLD, 1)
	f.add_theme_stylebox_override("panel", sb)
	h.add_child(f)
	var r := UIKit.tex_rect(tex, px)
	r.name = "Thumb"
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.clip_contents = true
	f.add_child(r)
	var tm := MarginContainer.new()   # the text keeps the padding the art gave up
	tm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["top", "bottom"]:
		tm.add_theme_constant_override("margin_" + side, 4 - THUMB_INSET)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tm.add_child(_text)
	h.add_child(tm)
	for l in _text.get_children():
		if l is Label:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


## small badge in the top-left corner (e.g. the "new logbook entry" book)
func add_badge(tex: Texture2D, tip: String) -> void:
	var bk := TextureRect.new()
	bk.texture = tex
	bk.position = Vector2(3, 3)
	bk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bk.tooltip_text = tip
	button.add_child(bk)
