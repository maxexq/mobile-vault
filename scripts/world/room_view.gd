class_name RoomView
extends Node2D
## One room slot inside the vehicle: interior art, dwellers, level pips, crafting strip, build-mode highlight
## (with a room-synergy preview), night glow and BLACKOUTS: when the room has no power (empty battery or a
## short circuit) it goes pitch dark and the only light is the crew's head-torches sweeping around
## (additive pixel light cones over a darkness layer — cheap 2D lighting that stays on the pixel grid).
## CONSTRUCTION (v4.3): a new room starts as a bare steel frame; the finished interior rises from the floor up
## as work progresses, behind scaffolding, with welding sparks and dust puffs from every hammer blow.
## Upgrades put the scaffolding over the working room.

const W := 64.0
const H := 52.0

var slot := 0
var build_highlight := false
var preview_type := ""
var interior: Sprite2D
var _reveal: Sprite2D
var _scaffold: Sprite2D
var _reveal_h := -1
var _fx: Array = []          # {p: Vector2, t: float, kind: "weld"|"dust"}
var _spark_t := 0.0
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
	_reveal = Sprite2D.new()
	_reveal.centered = false
	_reveal.visible = false
	add_child(_reveal)
	_scaffold = Sprite2D.new()
	_scaffold.centered = false
	_scaffold.texture = Atlas.tex("scaffold_front")
	_scaffold.visible = false
	add_child(_scaffold)
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
	var site := unlocked and Game.is_site(slot)
	var tex_key := "construct" if site else t
	if tex_key != _type:
		_type = tex_key
		interior.texture = Atlas.tex("room_" + tex_key)
		_reveal_h = -1
	_reveal.visible = site
	_scaffold.visible = unlocked and Game.is_constructing(slot)
	_update_reveal()
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
		(actors[int(d.id)] as DwellerActor).building = Game.is_constructing(slot) and not d.get("strike", false)
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
	if Game.is_constructing(slot) and Game.is_slot_unlocked(slot):
		_update_reveal()
		_tick_fx(delta)
		_top.queue_redraw()
	elif not _fx.is_empty():
		_fx.clear()
		_top.queue_redraw()
	if build_highlight or not Game.s.rooms[slot].job.is_empty() or Game.s.rooms[slot].type == "empty":
		_top.queue_redraw()


## the finished room grows up from the floor (2 px steps keep the cached sub-textures few)
func _update_reveal() -> void:
	if not _reveal.visible:
		return
	var h := int(floorf(Game.build_progress(slot) * H / 2.0)) * 2
	if h == _reveal_h:
		return
	_reveal_h = h
	if h <= 0:
		_reveal.texture = null
		return
	_reveal.texture = Atlas.sub("room_" + str(Game.s.rooms[slot].type), Rect2(0, H - h, W, h))
	_reveal.position = Vector2(0, H - h)


func _tick_fx(delta: float) -> void:
	for i in range(_fx.size() - 1, -1, -1):
		_fx[i].t = float(_fx[i].t) + delta
		if float(_fx[i].t) > (0.5 if _fx[i].kind == "weld" else 0.45):
			_fx.remove_at(i)
	# dust where a hammer lands
	for a in actors.values():
		var da: DwellerActor = a
		if is_instance_valid(da) and da.striking_now() and not da.has_meta("hit"):
			da.set_meta("hit", true)
			_fx.append({"p": da.hit_point(), "t": 0.0, "kind": "dust"})
		elif is_instance_valid(da) and not da.striking_now() and da.has_meta("hit"):
			da.remove_meta("hit")
	# welding sparks along the rising edge (new room) or on the frame (upgrade); faster crews spark more
	_spark_t -= delta * clampf(Game.build_speed(slot), 0.5, 4.0)
	if _spark_t <= 0.0:
		_spark_t = randf_range(0.5, 1.1)
		var y := H - float(maxi(_reveal_h, 6)) if _reveal.visible else randf_range(10.0, 34.0)
		_fx.append({"p": Vector2(randf_range(8.0, W - 8.0), clampf(y, 6.0, H - 8.0)), "t": 0.0, "kind": "weld"})


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
	if r.type != "empty" and not Game.is_site(slot):
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
	if Game.is_constructing(slot):
		_draw_construction()
	elif not r.job.is_empty():
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


func _draw_construction() -> void:
	for f in _fx:
		var p: Vector2 = (f.p as Vector2).round()
		if f.kind == "weld":
			var fr := clampi(int(float(f.t) / 0.125), 0, 3)
			_top.draw_texture(Atlas.tex("fx_weld_%d" % fr), p - Vector2(4, 4))
		else:
			var fr := clampi(int(float(f.t) / 0.15), 0, 2)
			_top.draw_texture(Atlas.tex("fx_dust_%d" % fr), p - Vector2(5, 3))
	# hazard-striped progress strip along the ceiling
	var pr := Game.build_progress(slot)
	_top.draw_rect(Rect2(0, 0, W, 4), Color(0.04, 0.03, 0.03, 0.9))
	for x in range(0, int(W), 4):
		_top.draw_rect(Rect2(x, 3, 2, 1), Color("a07c24"))
	_top.draw_rect(Rect2(0, 0, floorf(W * pr), 2), Color("d8ae44"))
	# blinking hammer badge: the next level pip (upgrade) or the corner (new room)
	if int(_t * 2.0) % 2 == 0:
		var x := 3.0 + int(Game.s.rooms[slot].level) * 4.0 if not _reveal.visible else 3.0
		_top.draw_rect(Rect2(x + 1, 8, 1, 4), Color("745434"))
		_top.draw_rect(Rect2(x, 7, 3, 2), Color("9a9684"))


func _draw_plus(c: Vector2, col: Color) -> void:
	_top.draw_rect(Rect2(c.x - 1, c.y - 6, 3, 13), col)
	_top.draw_rect(Rect2(c.x - 6, c.y - 1, 13, 3), col)
