class_name Marquee
extends Control
## MV-188: the announcement strip across the top of the screen (title screen and in game). Takes messages from
## the Announce autoload one at a time, scrolls each from the right edge to the left announce.loops times and hides.
## A "NEWS" / "UPDATE" tag sits at the left; an update notice can be tapped to save and reload the page.
## Lives in its own CanvasLayer above the HUD (main.gd) so open panels never cover it.

const H := 14
const TAG_W := 40

var msg: Dictionary = {}
var loops_done := 0
var x := 0.0
var _strip: Panel
var _clip: Control
var _label: Label
var _tag: Label


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_strip = Panel.new()
	_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_strip.offset_bottom = H
	_strip.add_theme_stylebox_override("panel", _style())
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.gui_input.connect(_on_strip_input)
	add_child(_strip)
	_tag = UIKit.label("NEWS", UIKit.FP, UIKit.C_BG, true)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag.position = Vector2(0, 0)
	_tag.size = Vector2(TAG_W, H - 1)
	_strip.add_child(_tag)
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clip.offset_left = TAG_W + 2
	_clip.offset_bottom = -1
	_strip.add_child(_clip)
	_label = UIKit.label("", UIKit.FS_SMALL, UIKit.C_GOLD)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_clip.add_child(_label)
	visible = false
	Announce.queued.connect(_next)
	Features.changed.connect(_on_features_changed)
	_next.call_deferred()


## switch off: hide now (the queue waits); back on: show what waits
func _on_features_changed() -> void:
	if not Features.on("announce"):
		if not msg.is_empty():
			_stop()
	elif msg.is_empty():
		_next()


func _style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UIKit.C_BG, 0.92)
	sb.border_color = UIKit.C_LINE
	sb.border_width_bottom = 1
	return sb


func _tag_style(update: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIKit.C_GREEN if update else UIKit.C_GOLD
	return sb


func _next() -> void:
	if not msg.is_empty():
		return
	msg = Announce.take()
	if msg.is_empty():
		return
	var update: bool = msg.kind == "update"
	_tag.text = "UPDATE" if update else "NEWS"
	_tag.add_theme_stylebox_override("normal", _tag_style(update))
	_label.text = str(msg.text)
	_label.add_theme_color_override("font_color", UIKit.C_GREEN if update else UIKit.C_GOLD)
	_label.size = Vector2(_label.get_minimum_size().x, H - 1)
	_strip.mouse_filter = Control.MOUSE_FILTER_STOP if update else Control.MOUSE_FILTER_IGNORE
	loops_done = 0
	x = _width()
	_label.position = Vector2(roundf(x), 0)
	visible = true


## width of the scrolling area (the clip is not laid out yet on the first frame)
func _width() -> float:
	return maxf(_clip.size.x, get_viewport_rect().size.x - TAG_W - 2)


func _process(delta: float) -> void:
	if msg.is_empty():
		return
	x -= Announce.speed() * delta
	if x < -_label.size.x:
		loops_done += 1
		if loops_done >= Announce.loops_for(msg):
			_stop()
			return
		x = _width()
	_label.position.x = roundf(x)     # whole pixels: stays on the pixel grid


## end the current message (also when the switch goes off) and start the next one
func _stop() -> void:
	msg = {}
	visible = false
	Announce.finish()
	_next.call_deferred()


func _on_strip_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
	if tap and not msg.is_empty() and msg.kind == "update":
		accept_event()
		Announce.reload_page()
