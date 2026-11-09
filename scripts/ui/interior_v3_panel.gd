class_name InteriorV3Panel
extends ModalPanel
## MV-711: the vehicle's inside drawn with the new art (switch rooms_v3): every cell as a v3 room (144x96,
## L1-L3 by room level, idle micro-animations, red emergency lamp in a power-out), I-beam walls between rooms, the
## ladder shaft at the rear, trailers behind the main body, and the ref v3 crew walking and working at 2/3 scale.
## Tap a room: its name, level and the object under the finger (hotspots format 2) show in the bar below, and
## "เปิดห้อง" opens the usual room close-up. The outside world keeps the old vehicle until the v3 shells exist
## (MV-602), so this view is where the new rooms and crew live for now. Drag to scroll, -/+ to zoom.
## MV-715 (switch ambulance_v3): the first vehicle (van) is Dr. Ren's welded ambulance here: the approved PixelLab
## shell for its 1-5 floors (assets/vehicles/ambulance_v3/shell_f<n>.png, cab at the front, roof garden, wheels
## per weight) is drawn over the cells, which sit in its cut-out windows (shell.json).

signal room_requested(slot: int)

const FRAME := 8.0
const WALL := 8.0
const SHAFT := 16.0
const SLAB := 8.0
const UNIT_GAP := 24.0
const ZOOMS := [1.0, 1.5, 2.0, 3.0]
const AMB_DIR := "res://assets/vehicles/ambulance_v3/"
const AMB_W := 638.0           # shell width; cells at x 146 + col * 152, y 88 + row * 112 (row 0 = top floor)
const AMB_X0 := 146.0
const AMB_Y0 := 88.0
const AMB_FH := 112.0
const AMB_LIFT := 40.0
## MV-736 (switch decker): the Decker double-decker bus (tier bus) has its own shells with the same cell grid, 2-3 decks:
## assets/vehicles/decker_v3/shell_f<n>.png (640 x 232 + 112 * n), cells at x 104 + col * 152, y 56 + row * 112.
## Built by tools/art/decker/shell.py from the approved art. amb() covers both shells (see shell_spec).
const DK_DIR := "res://assets/vehicles/decker_v3/"
const DK_W := 640.0
const DK_X0 := 104.0
const DK_Y0 := 56.0         # trailers stand on the road: their bottom sits this far above the shell's bottom
## MV-721 (switch road_train): the road train (tier rig) is the approved B-double v2: prime mover + lead trailer as
## the main body (body_f<n>.png, 1-3 decks) and the red container for every trailer (trailer_f<n>.png), all drawn
## on one road line; cells at x 226 / 20 + col * 152, y 116 + row * 112 (row 0 = top deck). designs/road-train/game/shell.py
const RT_DIR := "res://assets/vehicles/road_train_v3/"
const RT_W := 694.0
const RT_TW := 500.0
const RT_X0 := 226.0
const RT_TX0 := 20.0
const RT_Y0 := 116.0
const RT_FH := 112.0
## MV-737 (switch ambulance_pup): the ambulance's trailers are the approved pup (designs/road-train/approved/12_ambulance_pup),
## stretched in code to the trailer grid (3 cells x 2 floors): pup_f2.png, its drawbar + tow plate at the front ride on the
## unit in front. Unit i starts at PUP_X0 + PUP_STEP * i in ambulance shell px; cells at x 86 + col * 152, y 88 + row * 112
## (row 0 = top floor); it stands on the road like the ambulance. designs/road-train/pup2/game_shell.py
const PUP_DIR := "res://assets/vehicles/ambulance_pup/"
const PUP_X0 := 600.0
const PUP_STEP := 542.0
const PUP_W := 576.0
const PUP_H := 352.0
const PUP_REAR := 562.0
const PUP_CX0 := 86.0
const PUP_CY0 := 88.0

var scroll: ScrollContainer
var canvas: Control
var world: Node2D
var shell: Node2D
var amb_shell: Sprite2D           # MV-715 ambulance shell over the main body's cells
var rt_shells: Array = []         # MV-721 road train: body + one per trailer
var pup_shells: Array = []        # MV-737 ambulance pups, one per trailer
var cells: Dictionary = {}        # slot -> RoomV3Cell
var info: Label
var open_btn: Button
var zoom_i := 1
var selected := -1
var world_size := Vector2.ZERO
var _press := Vector2.ZERO
var _tick := 0.0
var _shape := ""


func _build() -> void:
	set_title(Loc.t("VAULT INTERIOR v3 / ภายในรถ (ห้อง + ลูกเรือชุดใหม่)"))
	fit_height = false
	max_size = Vector2(1600, 1400)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	canvas = Control.new()
	canvas.name = "InteriorCanvas"
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.clip_contents = true
	canvas.gui_input.connect(_on_canvas_input)
	scroll.add_child(canvas)
	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	canvas.add_child(world)
	shell = Node2D.new()
	shell.draw.connect(_draw_shell)
	world.add_child(shell)
	amb_shell = Sprite2D.new()
	amb_shell.name = "AmbulanceShell"
	amb_shell.centered = false
	amb_shell.visible = false
	world.add_child(amb_shell)
	var bar := UIKit.hbox(4)
	info = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_TEXT)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(info)
	var zo := UIKit.button("-", "gray")
	zo.custom_minimum_size = Vector2(26, 22)
	zo.pressed.connect(func(): set_zoom(zoom_i - 1))
	bar.add_child(zo)
	var zi := UIKit.button("+", "gray")
	zi.custom_minimum_size = Vector2(26, 22)
	zi.pressed.connect(func(): set_zoom(zoom_i + 1))
	bar.add_child(zi)
	open_btn = UIKit.button(Loc.t("เปิดห้อง"), "green")
	open_btn.name = "OpenRoom"
	open_btn.disabled = true
	open_btn.pressed.connect(func():
		if selected >= 0:
			var s := Game.room_anchor(selected)
			close()
			room_requested.emit(s))
	bar.add_child(open_btn)
	body.add_child(bar)
	Game.rooms_changed.connect(func(): if is_open: refresh())
	Game.dwellers_changed.connect(func(): if is_open: refresh())


## the rooms + crew only animate while the window is open (a closed window costs nothing per frame)
func open() -> void:
	world.process_mode = Node.PROCESS_MODE_INHERIT
	super.open()


func close() -> void:
	super.close()
	world.process_mode = Node.PROCESS_MODE_DISABLED


func open_at(slot: int = -1) -> void:
	open()
	if slot >= 0 and cells.has(slot):
		select(slot, Vector2(-1, -1))
		await get_tree().process_frame
		var c: RoomV3Cell = cells[slot]
		var z := zoom()
		scroll.scroll_horizontal = int(maxf(0.0, (c.position.x + 72.0) * z - scroll.size.x * 0.5))
		scroll.scroll_vertical = int(maxf(0.0, (c.position.y + 48.0) * z - scroll.size.y * 0.5))


func zoom() -> float:
	return float(ZOOMS[zoom_i])


func set_zoom(i: int) -> void:
	zoom_i = clampi(i, 0, ZOOMS.size() - 1)
	world.scale = Vector2.ONE * zoom()
	canvas.custom_minimum_size = (world_size * zoom()).ceil()


## top-left of a cell in world px: units side by side (main body first, trailers behind it), floor 0 at the bottom
func cell_pos(slot: int) -> Vector2:
	var unit := Game.slot_unit(slot)
	var c := Game.slot_cell(slot)
	var floors := _unit_floors(unit)
	var top := _unit_top(unit)
	if unit < 0 and amb():
		var sp := shell_spec(Game.tier())
		return Vector2(float(sp.x0) + c.x * (V3Art.CELL.x + WALL), top + float(sp.y0) + float(floors - 1 - c.y) * AMB_FH)
	if unit >= 0 and pup():
		return Vector2(_unit_x(unit) + PUP_CX0 + c.x * (V3Art.CELL.x + WALL), top + PUP_CY0 + float(floors - 1 - c.y) * AMB_FH)
	if rt():
		var x0 := RT_X0 if unit < 0 else _unit_x(unit) + RT_TX0
		return Vector2(x0 + c.x * (V3Art.CELL.x + WALL), top + RT_Y0 + float(floors - 1 - c.y) * RT_FH)
	var x := _unit_x(unit) + FRAME + c.x * (V3Art.CELL.x + WALL)
	return Vector2(x, top + FRAME + float(floors - 1 - c.y) * (V3Art.CELL.y + SLAB))


## MV-715: the main body is the ambulance shell (switch ambulance_v3, first vehicle, 1-5 floors)
func amb() -> bool:
	return dk() or Features.on("ambulance_v3") and Game.tier() == "van" and Game.floors() >= 1 and Game.floors() <= 5 \
		and ResourceLoader.exists(AMB_DIR + "shell_f%d.png" % Game.floors())


## MV-736: the main body is the Decker shell (switch decker, tier bus, 2-3 decks)
func dk() -> bool:
	return Game.decker_on() and Game.tier() == "bus" and Game.floors() >= 2 and Game.floors() <= 3 \
		and ResourceLoader.exists(DK_DIR + "shell_f%d.png" % Game.floors())


## shell art of a body drawn as one sprite: dir, width, first cell x0 / y0, height at 1 floor (+112 per floor)
static func shell_spec(t: String) -> Dictionary:
	if t == "bus":
		return {"dir": DK_DIR, "w": DK_W, "x0": DK_X0, "y0": DK_Y0, "base": 232.0}
	return {"dir": AMB_DIR, "w": AMB_W, "x0": AMB_X0, "y0": AMB_Y0, "base": 240.0}


## MV-721: the road train shells (switch road_train, tier rig, body 1-3 decks, trailers 2-3 decks)
func rt() -> bool:
	return Features.on("road_train") and Game.tier() == "rig" and ResourceLoader.exists(RT_DIR + "body_f%d.png" % Game.floors()) \
		and (Game.trailers() == 0 or ResourceLoader.exists(RT_DIR + "trailer_f%d.png" % _unit_floors(0)))


## MV-737: the ambulance's trailers are the pup shell (switch ambulance_pup, trailers of 2 floors)
func pup() -> bool:
	return Features.on("ambulance_pup") and amb() and not dk() and Game.trailers() > 0 and _unit_floors(0) == 2 \
		and ResourceLoader.exists(PUP_DIR + "pup_f2.png")


func _rt_h(floors: int) -> float:
	return 268.0 + RT_FH * float(floors - 1)


## MV-731: the bumper tip + tow hook of the flat front stick out 12 px in front of the 638 px shell (nose.png); a child
## of the shell sprite so it rides every hop / lurch. hide=true (road train body etc.) hides it.
static func attach_nose(shell: Sprite2D, hide := false) -> void:
	var nose := shell.get_node_or_null("Nose") as Sprite2D
	if nose == null:
		if hide or not ResourceLoader.exists(AMB_DIR + "nose.png"):
			return
		nose = Sprite2D.new()
		nose.name = "Nose"
		nose.centered = false
		nose.texture = load(AMB_DIR + "nose.png")
		shell.add_child(nose)
	nose.visible = not hide and shell.texture != null
	if nose.visible:
		nose.position = Vector2(-nose.texture.get_width(), shell.texture.get_height() - nose.texture.get_height())


func _amb_h() -> float:
	return float(shell_spec(Game.tier()).base) + AMB_FH * float(Game.floors() - 1)


func _unit_w() -> float:
	return FRAME * 2.0 + V3Art.CELL.x * 3.0 + WALL * 2.0 + SHAFT


func _main_w() -> float:
	if rt():
		return RT_W
	return float(shell_spec(Game.tier()).w) if amb() else _unit_w()


## left edge of a unit (-1 = main body, 0.. = trailers)
func _unit_x(unit: int) -> float:
	if unit < 0:
		return 0.0
	if pup():
		return PUP_X0 + PUP_STEP * float(unit)  # the pup's drawbar + tow plate ride on the unit in front
	if rt():
		return RT_W + RT_TW * float(unit)     # the container's nose rides on the unit in front: no gap
	return _main_w() + UNIT_GAP + (_unit_w() + UNIT_GAP) * float(unit)


func _box_h(floors: int) -> float:
	return FRAME * 2.0 + floors * (V3Art.CELL.y + SLAB) - SLAB


## everything stands on one road line: the ambulance's wheels, or the drawn boxes' bottoms
func _world_h() -> float:
	if rt():
		return maxf(_rt_h(Game.floors()), _rt_h(_unit_floors(0)) if Game.trailers() > 0 else 0.0)
	var h := _amb_h() if amb() else _box_h(Game.floors())
	if pup():
		return maxf(h, PUP_H)
	if Game.trailers() > 0:
		h = maxf(h, _box_h(_unit_floors(0)) + (AMB_LIFT if amb() else 0.0))
	return h


func _unit_top(unit: int) -> float:
	if rt():
		return _world_h() - _rt_h(_unit_floors(unit))
	if unit < 0:
		return _world_h() - (_amb_h() if amb() else _box_h(Game.floors()))
	if pup():
		return _world_h() - PUP_H
	return _world_h() - (AMB_LIFT if amb() else 0.0) - _box_h(_unit_floors(unit))


func _unit_floors(unit: int) -> int:
	return Game.floors() if unit < 0 else Data.TRAILER_SLOTS / Data.ROOMS_PER_FLOOR


func _rebuild() -> void:
	for c in cells.values():
		c.queue_free()
	cells.clear()
	for slot in Game.slot_count():
		var c := RoomV3Cell.new()
		c.slot = slot
		c.position = cell_pos(slot)
		world.add_child(c)
		cells[slot] = c
	var units := 1 + Game.trailers()
	world_size = Vector2(_unit_x(units - 2) + _unit_w() if units > 1 else _main_w(), _world_h())
	if rt():
		world_size.x = _unit_x(units - 2) + RT_TW if units > 1 else RT_W
	if pup():
		world_size.x = _unit_x(units - 2) + PUP_W
	for sp in rt_shells:
		sp.queue_free()
	rt_shells.clear()
	if rt():
		for u in units:
			var sp := Sprite2D.new()
			sp.name = "RoadTrainShell%d" % u
			sp.centered = false
			sp.texture = load(RT_DIR + ("body_f%d.png" % Game.floors() if u == 0 else "trailer_f%d.png" % _unit_floors(u - 1)))
			sp.position = Vector2(_unit_x(u - 1), _unit_top(u - 1))
			world.add_child(sp)
			rt_shells.append(sp)
	amb_shell.visible = amb()
	if amb_shell.visible:
		amb_shell.texture = load(str(shell_spec(Game.tier()).dir) + "shell_f%d.png" % Game.floors())
		amb_shell.position = Vector2(0.0, _unit_top(-1))
		attach_nose(amb_shell, dk())
	world.move_child(amb_shell, world.get_child_count() - 1)     # the shell's lip and decks over the room edges
	for sp in pup_shells:
		sp.queue_free()
	pup_shells.clear()
	if pup():                                                     # front first: each tow plate sits on the unit in front
		var tex: Texture2D = load(PUP_DIR + "pup_f2.png")
		for u in Game.trailers():
			var sp := Sprite2D.new()
			sp.name = "PupShell%d" % u
			sp.centered = false
			sp.texture = tex
			sp.position = Vector2(_unit_x(u), _unit_top(u))
			world.add_child(sp)
			pup_shells.append(sp)
	for i in range(rt_shells.size() - 1, -1, -1):                 # road train: rear units first, the body on top
		world.move_child(rt_shells[i], world.get_child_count() - 1)
	if not _fit_once():
		set_zoom(zoom_i)
	shell.queue_redraw()


## first open: the biggest zoom at which every floor fits the window's height and the main body its width (a tall
## portrait screen gives up width instead: the floors scroll sideways), at least the smallest step
func _fit_once() -> bool:
	if _shape != "":
		return false
	var vp := get_viewport_rect().size
	var avail := Vector2(maxf(vp.x - 24.0, 100.0), maxf(vp.y - 150.0, 100.0))
	var portrait := vp.y > vp.x
	var i := 0
	for k in ZOOMS.size():
		var z := float(ZOOMS[k])
		if world_size.y * z <= avail.y and (portrait or _main_w() * z <= avail.x):
			i = k
	set_zoom(i)
	return true


func refresh() -> void:
	if Game.s.is_empty():
		return
	var shape := "%d/%d/%d/%s/%s/%s/%s" % [Game.floors(), Game.trailers(), Game.slot_count(), amb(), rt(), pup(), Game.tier()]
	if shape != _shape or cells.is_empty():
		_rebuild()
		_shape = shape
	for c in cells.values():
		(c as RoomV3Cell).refresh()
	_update_info()


func _process(delta: float) -> void:
	if not is_open:
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		for c in cells.values():
			(c as RoomV3Cell).refresh()


func _on_canvas_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_press = mb.position
		elif mb.position.distance_to(_press) < 8.0:
			tap(mb.position / zoom())


## a tap at a world point (room px): select the cell + the hotspot under it
func tap(p: Vector2) -> int:
	for slot in cells:
		var c: RoomV3Cell = cells[slot]
		if Rect2(c.position, V3Art.CELL).has_point(p):
			select(slot, p - c.position)
			return slot
	return -1


func select(slot: int, local: Vector2) -> void:
	if selected >= 0 and cells.has(selected):
		(cells[selected] as RoomV3Cell).selected_id = ""
	selected = slot
	var c: RoomV3Cell = cells[slot]
	var h := c.hotspot_at(local) if local.x >= 0.0 else {}
	c.selected_id = str(h.get("id", ""))
	_update_info(h)


func _update_info(h: Dictionary = {}) -> void:
	if selected < 0 or not cells.has(selected):
		info.text = Loc.t("แตะห้องเพื่อดูรายละเอียด · ลากเพื่อเลื่อน")
		open_btn.disabled = true
		return
	var c: RoomV3Cell = cells[selected]
	var name := Loc.t("ห้องล็อก") if c.kind == "locked" else (Loc.t("ช่องว่าง") if c.kind == "empty" else str(Data.room_def(c.room_type).get("th", c.room_type)))
	var art := ""
	match c.kind:
		"v3":
			art = "v3 L%d%s" % [clampi(c.level, 1, 3), "" if V3Art.room_types().get(c.room_type, "") == "approved" else " (รอตรวจ)"]
		"fallback":
			art = Loc.t("ยังไม่มีภาพ v3")
		"site":
			art = Loc.t("กำลังสร้าง %d%%") % int(Game.build_progress(selected) * 100.0)
	var crew := c.actors.size()
	var t := "%s · %s · %s %d" % [name, art, Loc.t("คน"), crew] if c.kind != "locked" else name
	if c.dark:
		t += " · " + Loc.t("ไฟดับ")
	if not h.is_empty():
		t += "\n> " + str(h.get("label", h.get("id", "")))
	info.text = t
	open_btn.disabled = c.kind == "locked"


func _draw_shell() -> void:
	var steel := Color8(38, 36, 34)
	var rivet := Color8(70, 64, 58)
	var beam := Color8(52, 50, 48)
	var beam_hi := Color8(84, 80, 74)
	var units := 1 + Game.trailers()
	for u in units:
		var unit := u - 1
		var floors := _unit_floors(unit)
		var x0 := _unit_x(unit)
		var top := _unit_top(unit)
		var h := _box_h(floors)
		if unit < 0 and amb():
			continue                # the ambulance shell sprite is the main body
		if rt():
			continue                # MV-721: the road train shell sprites are every unit
		if unit >= 0 and pup():
			continue                # MV-737: the pup shell sprites are the trailers
		shell.draw_rect(Rect2(x0, top, _unit_w(), h), steel)
		for rx in range(int(x0) + 4, int(x0 + _unit_w()), 12):
			shell.draw_rect(Rect2(rx, top + 3, 1, 1), rivet)
			shell.draw_rect(Rect2(rx, top + h - 4, 1, 1), rivet)
		for f in floors:
			var y := top + FRAME + f * (V3Art.CELL.y + SLAB)
			for col in 2:            # 8 px I-beam between rooms: flanges + web
				var wx := x0 + FRAME + V3Art.CELL.x * (col + 1) + WALL * col
				shell.draw_rect(Rect2(wx, y, WALL, V3Art.CELL.y), beam)
				shell.draw_rect(Rect2(wx, y, 1, V3Art.CELL.y), beam_hi)
				shell.draw_rect(Rect2(wx + WALL - 1, y, 1, V3Art.CELL.y), Color8(24, 22, 21))
				shell.draw_rect(Rect2(wx + 3, y, 2, V3Art.CELL.y), Color8(44, 42, 40))
			var sx := x0 + FRAME + V3Art.CELL.x * 3.0 + WALL * 2.0       # rear ladder shaft
			shell.draw_rect(Rect2(sx, y, SHAFT, V3Art.CELL.y + (SLAB if f < floors - 1 else 0.0)), Color8(22, 21, 20))
			shell.draw_rect(Rect2(sx + 3, y, 1, V3Art.CELL.y), beam_hi)
			shell.draw_rect(Rect2(sx + SHAFT - 4, y, 1, V3Art.CELL.y), beam_hi)
			for ry in range(int(y) + 4, int(y + V3Art.CELL.y), 8):
				shell.draw_rect(Rect2(sx + 3, ry, SHAFT - 6, 1), Color8(96, 88, 76))
			if f < floors - 1:      # floor slab between decks
				shell.draw_rect(Rect2(x0 + FRAME, y + V3Art.CELL.y, _unit_w() - FRAME * 2.0 - SHAFT, SLAB), Color8(30, 28, 27))
				shell.draw_rect(Rect2(x0 + FRAME, y + V3Art.CELL.y, _unit_w() - FRAME * 2.0 - SHAFT, 1), beam_hi)
		if u > 0:                   # tow bar to the unit in front
			shell.draw_rect(Rect2(x0 - UNIT_GAP, top + h - 14, UNIT_GAP, 4), beam)
