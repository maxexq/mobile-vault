class_name CrewV3Actor
extends Node2D
## MV-711: one ref v3 crew member (2.5D, ~60 px on a 64 canvas) living in a v3 room cell. Positions are room pixels
## (144x96 cell); the sprite is drawn at 2/3 so the crew stand ~40 room px tall and keep every pixel (ref v3 rule).
## On duty the crew walk between the room's stand points (hotspots format 2: stand [x, y] + face) and play their
## work clip there; off duty in the rest room they idle, talk, eat or drink; on a building site they carry material
## and swing the sledgehammer. Contact shadow + room grade = rule crew-room-blend (shaders/crew_v3_blend.gdshader).

enum State { IDLE, WALK, ACT }

const SPEED := 16.0               # room px / s (old crew 11 px/s in a 64 px room, x 144/64 x 2/3)
const SHADOW_W := 15.0
## MV-724: contact shadow strength x (tune crew_v3.shadow; 1.0 = the MV-711 shadow, alpha 0.43 + 0.25 core, which
## read as a black blob on the lit v3 floors). The size stays SHADOW_W so other crew-sized shadows can match it.
const SHADOW := 0.5
const SHADOW_A := [0.43, 0.25]
const BLEND := preload("res://shaders/crew_v3_blend.gdshader")

var did := -1
var cid := ""
var mode := "work"                # work | rest | build
var spr: AnimatedSprite2D
var state := State.IDLE
var timer := 0.0
var target := Vector2.ZERO
var face := ""
var lamp_x := 72.0
var stands: Array = []            # [{stand: [x, y], face: "left"|"right"}]
var walkway := Vector2(89, 95)
var _mat: ShaderMaterial
var _act := "work"
var _shadow_col := Color(0.05, 0.04, 0.035)


func setup(d: Dictionary, room_mode: String, level_data: Dictionary, index: int) -> void:
	did = int(d.get("id", -1))
	cid = V3Art.crew_for(d)
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = V3Art.crew_frames(cid)
	spr.centered = false
	spr.offset = V3Art.FEET
	spr.scale = Vector2.ONE * V3Art.CREW_SCALE
	_mat = ShaderMaterial.new()
	_mat.shader = BLEND
	spr.material = _mat
	add_child(spr)
	set_room(room_mode, level_data)
	position = Vector2(clampf(24.0 + index * 30.0, 10.0, 134.0), _walk_y())
	_enter(State.ACT if mode != "rest" and randf() < 0.6 else State.IDLE)


## room type / level / mode changed under this actor (keeps its position)
func set_room(room_mode: String, level_data: Dictionary) -> void:
	mode = room_mode
	stands = []
	for h in level_data.get("hotspots", []):
		if (h as Dictionary).has("stand"):
			stands.append(h)
	var fl: Dictionary = level_data.get("floor", {})
	var ww: Array = fl.get("walkway", [89, 95])
	walkway = Vector2(float(ww[0]), float(ww[1]))
	lamp_x = float(level_data.get("lamp_x", 72))
	_mat.set_shader_parameter("tint", _v3(level_data.get("tint", [1, 1, 1])))
	_mat.set_shader_parameter("dark_col", _v3(level_data.get("dark", [12, 10, 9])))
	# the shadow takes the room's own deepest tone (a warm brown in most rooms) instead of pure black
	var dk := V3Art.color_of(level_data.get("dark", [12, 10, 9]))
	_shadow_col = Color(maxf(dk.r, 0.05), maxf(dk.g, 0.04), maxf(dk.b, 0.035))
	queue_redraw()


func set_dim(v: float) -> void:
	_mat.set_shader_parameter("dim", v)


func _v3(a: Array) -> Vector3:
	var c := V3Art.color_of(a)
	return Vector3(c.r, c.g, c.b)


func _walk_y() -> float:
	return randf_range(walkway.x, walkway.y)


func _play(clip: String) -> void:
	if spr.sprite_frames.has_animation(clip):
		spr.play(clip)
	elif spr.sprite_frames.has_animation("idle"):
		spr.play("idle")


func _enter(st: State) -> void:
	state = st
	match st:
		State.IDLE:
			timer = randf_range(1.5, 4.0)
			face = ""
			_play("idle")
		State.WALK:
			_play("carrywalk" if mode == "build" and randf() < 0.6 else "walk")
		State.ACT:
			var pick := _pick_target()
			target = pick[0]
			face = pick[1]
			if mode == "build":
				_act = "construct"
			elif mode == "rest":
				_act = ["talk", "eat", "drink", "idle"][randi() % 4]
			else:
				_act = "work"
			timer = randf_range(4.0, 8.0)
			state = State.WALK
			_play("carrywalk" if mode == "build" and randf() < 0.5 else "walk")


## [position, face] of the next place to go: a stand point of the room's stations, or a spot on the walkway
func _pick_target() -> Array:
	if not stands.is_empty() and (mode != "rest" or randf() < 0.5):
		var h: Dictionary = stands[randi() % stands.size()]
		var s: Array = h.stand
		return [Vector2(float(s[0]) + randf_range(-2, 2), float(s[1])), str(h.get("face", ""))]
	return [Vector2(randf_range(12, 132), _walk_y()), ""]


func _process(delta: float) -> void:
	if spr == null:
		return
	match state:
		State.WALK:
			var to := target - position
			var step := SPEED * delta
			if to.length() <= step:
				position = target
				state = State.ACT
				_play(_act)
				if face != "":
					spr.flip_h = face == "left"
			else:
				position += to.normalized() * step
				if absf(to.x) > 0.5:
					spr.flip_h = to.x < 0.0
		State.ACT, State.IDLE:
			timer -= delta
			if timer <= 0.0:
				_enter(State.ACT if randf() < (0.8 if mode != "rest" else 0.5) else State.IDLE)
	_mat.set_shader_parameter("light", lerpf(0.95, 0.65, clampf(absf(position.x - lamp_x) / 72.0, 0.0, 1.0)))
	queue_redraw()


func _draw() -> void:
	# contact shadow under the feet (~15 room px, soft outer + core), strength = shadow_k() (MV-724)
	var k := shadow_k()
	if k <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.2))
	draw_circle(Vector2.ZERO, SHADOW_W * 0.5, Color(_shadow_col, minf(SHADOW_A[0] * k, 1.0)))
	draw_circle(Vector2.ZERO, SHADOW_W * 0.3, Color(_shadow_col, minf(SHADOW_A[1] * k, 1.0)))
	draw_set_transform(Vector2.ZERO)


## contact shadow strength: tune crew_v3.shadow (MV-724), 1.0 = the old MV-711 shadow
static func shadow_k() -> float:
	return Features.num("crew_v3.shadow", SHADOW)


## alpha at the centre of the shadow (outer + core blended), for checks and the GOD note
static func shadow_alpha() -> float:
	var k := shadow_k()
	return 1.0 - (1.0 - minf(SHADOW_A[0] * k, 1.0)) * (1.0 - minf(SHADOW_A[1] * k, 1.0))


func clip() -> String:
	return str(spr.animation) if spr != null else ""
