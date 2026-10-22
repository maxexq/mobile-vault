class_name RoomView
extends Node2D
## One room slot inside the vehicle: interior art, dwellers, level pips, crafting strip, build-mode highlight
## (with a room-synergy preview), night glow and BLACKOUTS: when the room has no power (empty battery or a
## short circuit) it goes pitch dark and the only light is the crew's head-torches sweeping around
## (additive pixel light cones over a darkness layer — cheap 2D lighting that stays on the pixel grid).

const W := 64.0
const H := 52.0

var slot := 0
var build_highlight := false
var preview_type := ""
var interior: Sprite2D
var actors_root: Node2D
var actors: Dictionary = {}   # dweller id -> DwellerActor
var _dark: ColorRect
var _cones: Node2D
var _top: Node2D
var _type := ""
var _t := 0.0
var _is_dark := false
static var _add_mat: CanvasItemMaterial


func _ready() -> void:
	interior = Sprite2D.new()
	interior.centered = false
	add_child(interior)
	actors_root = Node2D.new()
	add_child(actors_root)
	_dark = ColorRect.new()
	_dark.size = Vector2(W, H)
	_dark.color = Color(0.015, 0.012, 0.02, 0.9)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark.visible = false
	add_child(_dark)
	_cones = Node2D.new()
	add_child(_cones)
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_top = Node2D.new()
	_top.draw.connect(_draw_top)
	add_child(_top)


func refresh() -> void:
	if slot >= Game.s.rooms.size():
		return
	var r: Dictionary = Game.s.rooms[slot]
	var unlocked := Game.is_slot_unlocked(slot)
	var t: String = r.type if unlocked else "locked"
	if t != _type:
		_type = t
		interior.texture = Atlas.tex("room_" + t)
	var want: Array = []
	if unlocked and t != "empty":
		want = Game.room_occupants(slot)
		if t == "quarters" and _is_first_quarters():
			want = want + Game.idle_dwellers()
	var keep := {}
	for d in want:
		keep[int(d.id)] = true
		if not actors.has(int(d.id)):
			var a := DwellerActor.new()
			actors_root.add_child(a)
			a.setup(d, t, actors.size())
			actors[int(d.id)] = a
		else:
			(actors[int(d.id)] as DwellerActor).room_type = t
		(actors[int(d.id)] as DwellerActor).striking = d.get("strike", false)
	for id in actors.keys():
		if not keep.has(id):
			actors[id].queue_free()
			actors.erase(id)
	_top.queue_redraw()


func _is_first_quarters() -> bool:
	for i in Game.s.rooms.size():
		if Game.s.rooms[i].type == "quarters" and Game.is_slot_unlocked(i):
			return i == slot
	return false


func set_glow(c: Color) -> void:
	interior.modulate = c
	actors_root.modulate = c


func _process(delta: float) -> void:
	_t += delta
	if Game.s.is_empty() or slot >= Game.s.rooms.size():
		return
	var dark: bool = Game.is_slot_unlocked(slot) and Game.s.rooms[slot].type != "empty" and Game.room_dark(slot)
	if dark != _is_dark:
		_is_dark = dark
		_dark.visible = dark
		if not dark:
			for c in _cones.get_children():
				c.queue_free()
	if _is_dark:
		_update_torches()
		# the bulb flickers back to life now and then
		_dark.color.a = 0.9 if randf() > 0.01 else 0.6
	if build_highlight or not Game.s.rooms[slot].job.is_empty() or Game.s.rooms[slot].type == "empty":
		_top.queue_redraw()


func _update_torches() -> void:
	var list := actors.values()
	while _cones.get_child_count() < list.size():
		var s := Sprite2D.new()
		s.material = _add_mat
		s.centered = false
		_cones.add_child(s)
	while _cones.get_child_count() > list.size():
		var last := _cones.get_child(_cones.get_child_count() - 1)
		_cones.remove_child(last)
		last.queue_free()
	for i in list.size():
		var a: DwellerActor = list[i]
		var cone: Sprite2D = _cones.get_child(i)
		if not is_instance_valid(a):
			continue
		# sweep: level / up / down / level, a bit out of phase per person
		var ph := int((_t * 1.4 + i * 0.7)) % 4
		var fr: int = [0, 1, 0, 2][ph]
		cone.texture = Atlas.tex("fx_flashlight_%d" % fr)
		var left := a.spr.flip_h
		cone.flip_h = left
		var head := a.position + Vector2(0, -15)
		cone.position = Vector2(round(head.x - (44 if left else 0) + (-2 if left else 2)), round(head.y - 12))
		cone.modulate = Color(1, 0.92, 0.7, 0.85 + 0.15 * sin(_t * 9.0 + i))


func _draw_top() -> void:
	if Game.s.is_empty() or slot >= Game.s.rooms.size():
		return
	var r: Dictionary = Game.s.rooms[slot]
	if not Game.is_slot_unlocked(slot):
		return
	if r.type != "empty":
		for i in int(r.level):
			_top.draw_rect(Rect2(3 + i * 4, 8, 3, 3), Color("e0b048"))
			_top.draw_rect(Rect2(3 + i * 4, 11, 3, 1), Color("7a5216"))
		# synergy markers (top-right): green + for each good neighbour, red - for each bad one
		var x := W - 5.0
		for e in Synergy.effects(slot):
			var good := float(e.mult) + float(e.happy) > 0.0
			_top.draw_rect(Rect2(x - 1, 8, 3, 1), Color("98c050") if good else Color("d4523c"))
			if good:
				_top.draw_rect(Rect2(x, 7, 1, 3), Color("98c050"))
			x -= 5.0
	if not r.job.is_empty():
		var p := clampf(float(r.job.progress) / float(r.job.total), 0.0, 1.0)
		_top.draw_rect(Rect2(0, 0, W, 3), Color(0.04, 0.03, 0.03, 0.85))
		_top.draw_rect(Rect2(0, 0, floorf(W * p), 2), Color("d8ae44"))
	if r.type == "empty":
		var a := 0.45 if int(_t * 2.0) % 2 == 0 else 0.8
		_draw_plus(Vector2(W * 0.5, H * 0.45), Color(1, 0.8, 0.3, a))
	if build_highlight:
		var c := Color(0.85, 0.68, 0.27, 1.0 if int(_t * 4.0) % 2 == 0 else 0.55)
		var pv := Synergy.preview(slot, preview_type) if preview_type != "" else {"good": 0, "bad": 0}
		if int(pv.bad) > 0 and int(pv.good) == 0:
			c = Color(0.83, 0.32, 0.24, c.a)
		elif int(pv.good) > 0 and int(pv.bad) == 0:
			c = Color(0.6, 0.75, 0.31, c.a)
		_top.draw_rect(Rect2(0, 0, W, 1), c)
		_top.draw_rect(Rect2(0, H - 1, W, 1), c)
		_top.draw_rect(Rect2(0, 0, 1, H), c)
		_top.draw_rect(Rect2(W - 1, 0, 1, H), c)
		_top.draw_rect(Rect2(1, 1, W - 2, H - 2), Color(c.r, c.g, c.b, 0.14))
		for k in int(pv.good):
			_top.draw_rect(Rect2(4 + k * 6, H - 8, 3, 1), Color("98c050"))
			_top.draw_rect(Rect2(5 + k * 6, H - 9, 1, 3), Color("98c050"))
		for k in int(pv.bad):
			_top.draw_rect(Rect2(W - 8 - k * 6, H - 8, 3, 1), Color("d4523c"))


func _draw_plus(c: Vector2, col: Color) -> void:
	_top.draw_rect(Rect2(c.x - 1, c.y - 6, 3, 13), col)
	_top.draw_rect(Rect2(c.x - 6, c.y - 1, 13, 3), col)
