class_name RoomPager
extends Control
## MV-768 UI v5 (switch ui_v5, portrait): the main screen's lower half. One v3 room at 2x under the road view with
## its name, level and crew on top; swipe left / right (or the < > buttons) for the next room, tap the room or
## "เปิดห้อง" for the usual close-up. The cells are RoomV3Cell like the v3 interior (crew at 2/3); only the room on
## screen and its two neighbours run their animation, so the strip costs about three rooms per frame.

signal room_requested(slot: int)
signal room_changed(slot: int)

const K := 2.0                # whole-number scale: 1 room px = 2 design px
const STEP := 152.0           # 144 px room + 8 px wall between rooms
const HEAD_H := 22.0
const BAR_H := 28.0
const SWIPE := 40.0           # design px of drag that turns the page
const H := HEAD_H + 96.0 * K + BAR_H + 4.0

var idx := 0                  # index into slots of the room on screen
var slots: Array = []         # room anchors (an annex shows as its room), front to back, bottom floor first
var cells := {}               # index -> RoomV3Cell
var view: Control
var world: Node2D
var head: HBoxContainer
var bar: HBoxContainer
var name_lbl: Label
var lvl_lbl: Label
var crew_lbl: Label
var page_lbl: Label
var prev_btn: Button
var next_btn: Button
var open_btn: Button
var _shape := ""
var _press := Vector2.ZERO
var _down := false
var _drag := false
var _x0 := 0.0
var _tw: Tween
var _tick := 0.0


func _ready() -> void:
	name = "RoomPager"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.05, 0.047, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var line := ColorRect.new()
	line.color = UIKit.C_LINE_DIM
	line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	line.offset_bottom = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	head = UIKit.hbox(4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	name_lbl = UIKit.label("", UIKit.FS_BIG, UIKit.C_WHITE)
	name_lbl.clip_text = true
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lvl_lbl = UIKit.label("", UIKit.FP, UIKit.C_GOLD, true)
	lvl_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(lvl_lbl)
	head.add_child(name_lbl)
	head.add_child(UIKit.icon_rect("people", 16))
	crew_lbl = UIKit.label("0", UIKit.FP, UIKit.C_TEXT, true)
	crew_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(crew_lbl)
	view = Control.new()
	view.name = "PagerView"
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.gui_input.connect(_on_input)
	add_child(view)
	world = Node2D.new()
	world.scale = Vector2.ONE * K
	view.add_child(world)
	bar = UIKit.hbox(4)
	add_child(bar)
	prev_btn = UIKit.button("<", "gray")
	prev_btn.custom_minimum_size = Vector2(40, BAR_H)
	prev_btn.pressed.connect(func(): go(idx - 1))
	bar.add_child(prev_btn)
	page_lbl = UIKit.label("", UIKit.FP, UIKit.C_DIM, true)
	page_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(page_lbl)
	next_btn = UIKit.button(">", "gray")
	next_btn.custom_minimum_size = Vector2(40, BAR_H)
	next_btn.pressed.connect(func(): go(idx + 1))
	bar.add_child(next_btn)
	open_btn = UIKit.button(Loc.t("เปิดห้อง"), "yellow")
	open_btn.name = "PagerOpenRoom"
	open_btn.custom_minimum_size = Vector2(96, BAR_H)
	open_btn.pressed.connect(func(): open_current())
	bar.add_child(open_btn)
	resized.connect(_layout)
	visibility_changed.connect(_refresh_shown)
	Game.rooms_changed.connect(_refresh_shown)
	Game.dwellers_changed.connect(_refresh_shown)


func _refresh_shown() -> void:
	if visible:
		refresh()


func _layout() -> void:
	head.position = Vector2(6, 2)
	head.size = Vector2(size.x - 12, HEAD_H - 2)
	view.position = Vector2(0, HEAD_H)
	view.size = Vector2(size.x, 96.0 * K)
	bar.position = Vector2(4, HEAD_H + 96.0 * K + 2)
	bar.size = Vector2(size.x - 8, BAR_H)
	_place(false)


## the room currently on screen (a slot id), -1 before the first refresh
func current_slot() -> int:
	return int(slots[idx]) if idx >= 0 and idx < slots.size() else -1


func refresh() -> void:
	if Game.s.is_empty() or not V3Art.ok():
		return
	var list: Array = []
	for s in Game.slot_count():
		if Game.room_anchor(s) == s:
			list.append(s)
	var shape := "%s/%s" % [str(list), Game.tier()]
	if shape != _shape:
		var keep := current_slot()
		_shape = shape
		slots = list
		for c in cells.values():
			c.queue_free()
		cells.clear()
		for i in slots.size():
			var c := RoomV3Cell.new()
			c.slot = int(slots[i])
			c.position = Vector2(float(i) * STEP, 0.0)
			world.add_child(c)
			cells[i] = c
		idx = maxi(0, slots.find(keep)) if keep >= 0 else 0
		_place(false)
	for i in cells:
		if absi(int(i) - idx) <= 1:
			(cells[i] as RoomV3Cell).refresh()
	_update_head()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		for i in cells:
			if absi(int(i) - idx) <= 1:
				(cells[i] as RoomV3Cell).refresh()
		_update_head()


## turn to page i (clamped); the strip slides there
func go(i: int, anim: bool = true) -> void:
	if slots.is_empty():
		return
	var n := clampi(i, 0, slots.size() - 1)
	var changed := n != idx
	idx = n
	_place(anim)
	if changed:
		Sound.ui("tab")
		for c in cells:
			if absi(int(c) - idx) <= 1:
				(cells[c] as RoomV3Cell).refresh()
		room_changed.emit(current_slot())
	_update_head()


## show the room that holds this slot (an annex cell shows its room)
func show_slot(slot: int, anim: bool = false) -> bool:
	var i := slots.find(Game.room_anchor(slot))
	if i < 0:
		return false
	go(i, anim)
	return true


func open_current() -> void:
	var s := current_slot()
	if s >= 0 and Game.is_slot_unlocked(s):
		room_requested.emit(s)


func _target_x() -> float:
	return roundf(size.x * 0.5 - (float(idx) * STEP + V3Art.CELL.x * 0.5) * K)


func _place(anim: bool) -> void:
	if world == null:
		return
	if _tw:
		_tw.kill()
	var x := _target_x()
	if anim and is_inside_tree():
		_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tw.tween_property(world, "position:x", x, 0.18)
	else:
		world.position = Vector2(x, 0.0)
	for i in cells:
		(cells[i] as Node).process_mode = Node.PROCESS_MODE_INHERIT if absi(int(i) - idx) <= 1 else Node.PROCESS_MODE_DISABLED
		(cells[i] as Node2D).visible = absi(int(i) - idx) <= 2


func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_down = true
			_drag = false
			_press = mb.position
			_x0 = world.position.x
			if _tw:
				_tw.kill()
		elif _down:
			_down = false
			var dx := mb.position.x - _press.x
			if _drag:
				go(idx + (1 if dx < -SWIPE else (-1 if dx > SWIPE else 0)))
			else:
				_place(false)
				open_current()
		view.accept_event()
	elif e is InputEventMouseMotion and _down:
		var dx := (e as InputEventMouseMotion).position.x - _press.x
		if absf(dx) > 6.0:
			_drag = true
		if _drag:
			world.position.x = roundf(_x0 + dx)
		view.accept_event()


func _update_head() -> void:
	if not cells.has(idx):
		name_lbl.text = ""
		return
	var c: RoomV3Cell = cells[idx]
	var t := Loc.t("ห้องล็อก") if c.kind == "locked" else (Loc.t("ช่องว่าง") if c.kind == "empty" else str(Data.room_def(c.room_type).get("th", c.room_type)))
	if c.kind == "site":
		t += " · " + Loc.t("กำลังสร้าง %d%%") % int(Game.build_progress(c.slot) * 100.0)
	if c.dark:
		t += " · " + Loc.t("ไฟดับ")
	if name_lbl.text != t:
		name_lbl.text = t
		name_lbl.add_theme_color_override("font_color", UIKit.C_RED if c.dark else UIKit.C_WHITE)
	var lv := "L%d" % clampi(c.level, 1, 3) if c.kind == "v3" or c.kind == "fallback" else ""
	if lvl_lbl.text != lv:
		lvl_lbl.text = lv
	lvl_lbl.visible = lv != ""
	var crew := str(c.actors.size())
	if crew_lbl.text != crew:
		crew_lbl.text = crew
	var pg := "%d/%d" % [idx + 1, slots.size()]
	if page_lbl.text != pg:
		page_lbl.text = pg
	prev_btn.disabled = idx <= 0
	next_btn.disabled = idx >= slots.size() - 1
	open_btn.disabled = c.kind == "locked"
