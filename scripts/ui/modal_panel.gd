class_name ModalPanel
extends Control
## Base for every pop-up window: dimmed backdrop, riveted rusty-steel 9-slice frame, red title plate,
## header ("> TITLE" + Thai subtitle + [X]), responsive size, CRT "power-on" open animation.
## Subclasses override _build() and refresh().

signal closed

var dim: ColorRect
var box: PanelContainer
var header: HBoxContainer
var title_lbl: Label
var sub_lbl: Label
var body: VBoxContainer
var close_btn: Button
var max_size := Vector2(420, 640)
var frame_color := UIKit.C_LINE
var dim_alpha := 0.6
var is_open := false
var margin := 6
var centered := true        # MV-266: keep the window in the middle of the screen at its real size (the close-up docks)
var media: PanelContainer   # illustration frame built by the last media_layout()
## MV-482: the window is as tall as its content needs (up to the screen; the lists scroll beyond that), so there is no
## empty space under short content, and a later change of content height slides smoothly (FIT_TIME). A panel whose
## body is a canvas without a natural height (the map) sets fit_height = false and keeps the full height.
var fit_height := true
const MIN_H := 96.0
const FIT_TIME := 0.18
var _col: VBoxContainer     # the window's column: title plate, divider, body
var _fit_tw: Tween
var _fit_queued := false
var _opened_ms := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	dim = ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.01, dim_alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIKit.window_style())
	box.resized.connect(_recenter)
	add_child(box)
	var v := UIKit.vbox(4)
	box.add_child(v)
	_col = v
	v.minimum_size_changed.connect(_queue_fit)
	header = UIKit.hbox(4)
	var plate := PanelContainer.new()       # rust-red painted title plate
	plate.add_theme_stylebox_override("panel", UIKit.nine("title", 3, Vector4(5, 2, 3, 2)))
	plate.add_child(header)
	v.add_child(plate)
	var tv := UIKit.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tv)
	title_lbl = UIKit.label("", UIKit.FP, UIKit.C_GOLD, true)
	title_lbl.clip_text = true
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(title_lbl)
	sub_lbl = UIKit.label("", UIKit.FS_BIG, UIKit.C_WHITE)
	sub_lbl.clip_text = true
	sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(sub_lbl)
	close_btn = UIKit.button("", "gray", "close")
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(close)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(close_btn)
	v.add_child(UIKit.divider(UIKit.C_LINE_DIM))
	body = UIKit.vbox(4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	get_viewport().size_changed.connect(_layout)
	_build()
	_layout()


func _on_dim_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_on_backdrop_tap()


func _on_backdrop_tap() -> void:
	close()


func _layout() -> void:
	var vp := get_viewport_rect().size
	var sz := Vector2(minf(max_size.x, vp.x - margin * 2), max_height()).floor()
	if fit_height:
		sz.y = fit_target()
	if _fit_tw:
		_fit_tw.kill()
	box.custom_minimum_size = sz
	box.size = sz
	_recenter()


## the tallest the window may be on this screen
func max_height() -> float:
	return floorf(minf(max_size.y, get_viewport_rect().size.y - margin * 2))


## MV-482: what the content needs: the column's own minimum (a ScrollContainer only asks for a little) plus the full
## height of every scrolling list, plus the frame. Not box.get_combined_minimum_size(): that includes the size we set.
func natural_height() -> float:
	if _col == null:
		return max_height()
	var h := _col.get_combined_minimum_size().y + box.get_theme_stylebox("panel").get_minimum_size().y
	for sc in _col.find_children("*", "ScrollContainer", true, false):
		var inner := sc as ScrollContainer
		if inner.get_child_count() == 0 or _in_scroll(inner):
			continue
		var c := inner.get_child(0) as Control
		if c:
			h += maxf(0.0, c.get_combined_minimum_size().y - inner.get_combined_minimum_size().y)
	return h


## a list inside a ScrollContainer doesn't pass its size up, so each scrolling list is watched directly (once)
func _watch_scrolls() -> void:
	for sc in _col.find_children("*", "ScrollContainer", true, false):
		if sc.get_child_count() == 0:
			continue
		var c := sc.get_child(0) as Control
		if c and not c.minimum_size_changed.is_connected(_queue_fit):
			c.minimum_size_changed.connect(_queue_fit)


func _in_scroll(n: Node) -> bool:
	var p := n.get_parent()
	while p and p != box:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func fit_target() -> float:
	if not Features.on("window_fit"):
		return max_height()        # switch off: the full height, as before
	return floorf(clampf(natural_height(), minf(MIN_H, max_height()), max_height()))


## content changed size: fit the height at the end of the frame (several changes in one frame fit once)
func _queue_fit() -> void:
	if not fit_height or not is_open or _fit_queued:
		return
	_fit_queued = true
	_apply_fit.call_deferred()


func _apply_fit() -> void:
	_fit_queued = false
	if not fit_height or not is_open:
		return
	var want := fit_target()
	if absf(want - box.size.y) < 1.0:
		return
	if _fit_tw:
		_fit_tw.kill()
	# the first moments after opening (wrapped text still measuring itself) snap; later changes slide
	if Time.get_ticks_msec() - _opened_ms < 250 or not is_visible_in_tree():
		_set_h(want)
		return
	_fit_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fit_tw.tween_method(_set_h, box.size.y, want, FIT_TIME)


func _set_h(h: float) -> void:
	box.custom_minimum_size.y = floorf(h)
	box.size.y = floorf(h)
	_recenter()


## MV-266: place on the box's REAL size: content wider than max_size (the build menu's two columns) grows the box,
## and placing it by the requested size pushed it off to the right. Centred windows stay centred; docked ones
## (centered = false, e.g. the room close-up) keep their spot. Either way the window is kept inside the screen.
func _recenter() -> void:
	if box == null:
		return
	var vp := get_viewport_rect().size
	if centered:
		box.position = ((vp - box.size) * 0.5).floor()
	box.position = box.position.clamp(Vector2.ZERO, (vp - box.size).max(Vector2.ZERO)).floor()


## "EN TITLE / ไทย" -> pixel tag line + Thai heading
func set_title(t: String) -> void:
	var parts := t.split(" / ", false, 1)
	if parts.size() == 2:
		var a := parts[0]
		var b := parts[1]
		# whichever half is Latin goes to the pixel line
		if _is_latin(a):
			title_lbl.text = "> " + a.to_upper()
			sub_lbl.text = b
		else:
			title_lbl.text = "> " + b.to_upper()
			sub_lbl.text = a
	elif _is_latin(t):
		# an English title (MV-151) usually drops the Thai half: it is the pixel line, nothing below it
		title_lbl.text = "> " + t.to_upper()
		sub_lbl.text = ""
	else:
		title_lbl.text = "> TERMINAL"
		sub_lbl.text = t
	# "> SETTINGS" over "Settings" says the same thing twice in English
	if sub_lbl.text.to_upper() == title_lbl.text.trim_prefix("> "):
		sub_lbl.text = ""
	sub_lbl.visible = sub_lbl.text != ""


static func _is_latin(s: String) -> bool:
	for i in mini(s.length(), 6):
		if s.unicode_at(i) > 0x0E00:
			return false
	return true


func open() -> void:
	visible = true
	is_open = true
	add_to_group("modal_open")
	_opened_ms = Time.get_ticks_msec()
	Sound.ui("open")
	_layout()
	refresh()
	_watch_scrolls()
	_layout()        # MV-266 / MV-482: again with the new content (the first pass may have measured the last build)
	_queue_fit()     # and once more after this frame, when wrapped text knows its width
	# CRT power-on: the frame opens from a bright horizontal line
	box.modulate = Color(1.8, 2.0, 1.8, 0.0)
	dim.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(box, "modulate", Color.WHITE, 0.18)
	tw.tween_property(dim, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not is_open:
		return
	is_open = false
	remove_from_group("modal_open")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(box, "modulate:a", 0.0, 0.1)
	tw.tween_property(dim, "modulate:a", 0.0, 0.1)
	tw.chain().tween_callback(func():
		if is_open:
			return      # reopened during the 0.1 s fade-out (MV-515): don't hide the new window
		visible = false
		closed.emit())


func clear_body() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()


## a scrollable vertical list placed in the body (most panels use one)
func make_list(sep: int = 4) -> VBoxContainer:
	var sc := UIKit.scroll()
	body.add_child(sc)
	var l := UIKit.vbox(sep)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(l)
	return l


## illustration (pixel art) + scrolling text column for event-style terminals.
## Landscape screens get a wider window with the art at x2 beside the text; otherwise the art sits on top
## of the text (x2 when it fits) so the text column always spans the window and Thai lines can wrap.
func media_layout(tex: Texture2D, line: Color) -> VBoxContainer:
	var vp := get_viewport_rect().size
	var side := vp.x > vp.y and vp.x >= 560.0
	max_size.x = 640.0 if side else 420.0
	_layout()
	var inner := box.custom_minimum_size.x - 18.0
	# keep at least ~220 px for the text column beside the art
	var w := tex.get_size().x
	var k := 2 if (inner - w * 2.0 - 10.0 >= 220.0 if side else inner >= w * 2.0 + 2.0) else 1
	var sc := UIKit.scroll()
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var frame := media_frame(tex, line, k)
	media = frame
	if side:
		var h := UIKit.hbox(8)
		h.size_flags_vertical = Control.SIZE_EXPAND_FILL
		frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(frame)
		h.add_child(sc)
		body.add_child(h)
	else:
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(frame)
		body.add_child(sc)
	return v


## illustration (event art is 160x80) in a thin frame at integer scale k
static func media_frame(tex: Texture2D, line: Color, k: int) -> PanelContainer:
	var frame := UIKit.panel(Color("000000"), line)
	frame.get_theme_stylebox("panel").set_content_margin_all(1)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var img := TextureRect.new()
	img.texture = tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.custom_minimum_size = tex.get_size() * k
	img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(img)
	return frame


## virtual
func _build() -> void:
	pass


## virtual
func refresh() -> void:
	pass
