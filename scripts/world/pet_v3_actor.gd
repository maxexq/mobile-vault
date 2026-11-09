class_name PetV3Actor
extends Node2D
## MV-733: one approved realistic-size pet (PetsV3) living in a v3 room cell. Positions are room pixels (144x96 cell),
## the sprite is drawn 1:1 (room scale). It trots along the room's front walkway, stops for a look around (still
## frame), trots on; it fades in when it arrives in the room and fades out when it leaves (the cell frees it).
## Small pixel contact shadow in the room's dark tone like the crew (rule crew-room-blend, x tune crew_v3.shadow).

enum State { WALK, STAND }

var idx := -1                     # index in Game.s.pets
var breed := ""
var kind := ""
var spr: Sprite2D
var state := State.STAND
var timer := 0.0
var target := Vector2.ZERO
var speed := 12.0
var walkway := Vector2(89, 95)
var leaving := false
var _n := 8                       # walk frames
var _fps := 12.0
var _anim := 0.0
var _w := 16                      # body width in px (shadow)
var _shadow_col := Color(0.05, 0.04, 0.035)


func setup(p: Dictionary, level_data: Dictionary) -> void:
	idx = int(p.i)
	breed = str(p.breed)
	kind = str(p.kind)
	var e := PetsV3.info(breed)
	_n = int(e.get("walk", {}).get("n", 8))
	_fps = float(e.get("walk", {}).get("fps", 12))
	speed = float(e.get("speed", 12.0))
	_w = int((e.get("size", [16, 16]) as Array)[0])
	spr = Sprite2D.new()
	spr.texture = PetsV3.sheet(breed)
	spr.hframes = 1 + _n
	spr.centered = false
	var fr: Array = PetsV3._data.get("frame", [32, 24])
	spr.offset = Vector2(-float(fr[0]) * 0.5, -float(fr[1]))
	add_child(spr)
	set_room(level_data)
	position = Vector2(randf_range(16.0, 128.0), _walk_y())
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
	_enter(State.WALK)


func set_room(level_data: Dictionary) -> void:
	var fl: Dictionary = level_data.get("floor", {})
	var ww: Array = fl.get("walkway", [89, 95])
	walkway = Vector2(float(ww[0]), float(ww[1]))
	var dk := V3Art.color_of(level_data.get("dark", [12, 10, 9]))
	_shadow_col = Color(maxf(dk.r, 0.05), maxf(dk.g, 0.04), maxf(dk.b, 0.035))
	queue_redraw()


func set_dim(dark: bool) -> void:
	spr.modulate = RoomV3Cell.DARK if dark else Color.WHITE


## fade out, then free (the pet hopped to another room)
func leave() -> void:
	if leaving:
		return
	leaving = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


func _walk_y() -> float:
	return roundf(randf_range(walkway.x, walkway.y))


func _enter(st: State) -> void:
	state = st
	if st == State.WALK:
		target = Vector2(roundf(randf_range(12.0, 132.0)), _walk_y())
	else:
		timer = randf_range(1.5, 5.0) if kind != "hen" else randf_range(0.6, 2.0)
		spr.frame = 0


func _process(delta: float) -> void:
	if spr == null:
		return
	if state == State.WALK:
		var to := target - position
		var step := speed * Features.num("pets_v3.speed", 1.0) * delta
		if to.length() <= step:
			position = target
			_enter(State.STAND if randf() < 0.7 else State.WALK)
		else:
			position += to.normalized() * step
			if absf(to.x) > 0.5:
				spr.flip_h = to.x < 0.0          # the art faces east
		_anim += delta * _fps
		spr.frame = 1 + int(_anim) % _n
		queue_redraw()
	else:
		timer -= delta
		if timer <= 0.0:
			_enter(State.WALK)
	# whole room pixels for the sprite, like the crew's shadow snap
	spr.position = Vector2(roundf(position.x), roundf(position.y)) - position


func _draw() -> void:
	var k := CrewV3Actor.shadow_k()
	if k <= 0.0:
		return
	var o := Vector2(roundf(position.x), roundf(position.y)) - position
	var w := maxi(5, int(_w * 0.8))
	var c1 := Color(_shadow_col, minf(0.38 * k, 1.0))
	var c2 := Color(_shadow_col, minf(0.20 * k, 1.0))
	for r in [[-1, w - 2], [0, w], [1, w - 2]]:
		draw_rect(Rect2(o + Vector2(-floorf(r[1] * 0.5), float(r[0])), Vector2(r[1], 1)), c1)
	draw_rect(Rect2(o + Vector2(-floorf((w - 4) * 0.5), 0.0), Vector2(w - 4, 1)), c2)


func is_walking() -> bool:
	return state == State.WALK
