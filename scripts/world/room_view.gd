class_name RoomView
extends Node2D
## One room slot inside the vehicle: interior art, dwellers walking around, level pips,
## crafting progress strip, build-mode highlight and night glow.

const W := 64.0
const H := 52.0

var slot := 0
var build_highlight := false
var interior: Sprite2D
var actors_root: Node2D
var actors: Dictionary = {}   # dweller id -> DwellerActor
var _type := ""
var _t := 0.0


func _ready() -> void:
	interior = Sprite2D.new()
	interior.centered = false
	add_child(interior)
	actors_root = Node2D.new()
	add_child(actors_root)


func refresh() -> void:
	var r: Dictionary = Game.s.rooms[slot]
	var unlocked := Game.is_slot_unlocked(slot)
	var t: String = r.type if unlocked else "locked"
	if t != _type:
		_type = t
		interior.texture = Atlas.tex("room_" + t)
	# sync dwellers shown in this room
	var want: Array = []
	if unlocked and t != "empty":
		want = Game.room_workers(slot)
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
	for id in actors.keys():
		if not keep.has(id):
			actors[id].queue_free()
			actors.erase(id)
	queue_redraw()


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
	if build_highlight or (not Game.s.is_empty() and not Game.s.rooms[slot].job.is_empty()):
		queue_redraw()


func _draw() -> void:
	if Game.s.is_empty():
		return
	var r: Dictionary = Game.s.rooms[slot]
	if not Game.is_slot_unlocked(slot):
		return
	# level pips (top-left)
	if r.type != "empty":
		for i in int(r.level):
			draw_rect(Rect2(3 + i * 4, 8, 3, 3), Color("ffcc6a"))
			draw_rect(Rect2(3 + i * 4, 11, 3, 1), Color("c46010"))
	# crafting progress strip (top)
	if not r.job.is_empty():
		var p := clampf(float(r.job.progress) / float(r.job.total), 0.0, 1.0)
		draw_rect(Rect2(0, 0, W, 3), Color(0.04, 0.03, 0.03, 0.85))
		draw_rect(Rect2(0, 0, floorf(W * p), 2), Color("d8ae44"))
		var blink := int(_t * 4.0) % 2 == 0
		if blink:
			draw_rect(Rect2(W - 6, 8, 3, 3), Color("d8ae44"))
	# empty slot hint
	if r.type == "empty":
		var a := 0.45 if int(_t * 2.0) % 2 == 0 else 0.8
		_draw_plus(Vector2(W * 0.5, H * 0.45), Color(1, 0.8, 0.3, a))
	if build_highlight:
		var c := Color(0.85, 0.68, 0.27, 1.0 if int(_t * 4.0) % 2 == 0 else 0.55)
		draw_rect(Rect2(0, 0, W, 1), c)
		draw_rect(Rect2(0, H - 1, W, 1), c)
		draw_rect(Rect2(0, 0, 1, H), c)
		draw_rect(Rect2(W - 1, 0, 1, H), c)
		draw_rect(Rect2(1, 1, W - 2, H - 2), Color(0.85, 0.68, 0.27, 0.14))


func _draw_plus(c: Vector2, col: Color) -> void:
	draw_rect(Rect2(c.x - 1, c.y - 6, 3, 13), col)
	draw_rect(Rect2(c.x - 6, c.y - 1, 13, 3), col)
