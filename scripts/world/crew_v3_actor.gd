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
## MV-724: contact shadow = a pixel-grid ellipse in room pixels (crisp edge like the room art, the first soft
## draw_circle version read as a faint smudge), width SHADOW_W kept so other crew-sized shadows can match it.
## Strength x tune crew_v3.shadow (1 = these alphas), colour = the room's deepest tone.
const SHADOW := 1.0
const SHADOW_A := [0.38, 0.20]       # outer ring, core (centre ~50 % opaque, in the room's own dark tone)
## [row y from the feet line, width]: 5 rows, mostly below the feet so it shows past the boots
const SHADOW_ROWS := [[-1, 11], [0, 15], [1, 15], [2, 13], [3, 7]]
const SHADOW_CORE := [[0, 11], [1, 11], [2, 7]]
## MV-724: how much room grade the crew get (tune crew_v3.grade; 1 = MV-711, which Parames found too dark).
## Default 0 = the sprites own colours, like the v2 crew in the world view (Parames 2026-11-08: "ทำให้สีคล้ายๆ v2")
const GRADE := 0.0
## MV-724: brighten / saturate the crew toward the v2 crew colours (tune crew_v3.lift, 1 = off)
const LIFT := 1.5
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
var in_world := false             # MV-734: drawn in the world view (see setup)
var full := false                 # MV-734: drawn at full pixel size (world view)


## world_view: the actor stands in a cell of the world (vehicle), where one room pixel is one rendered pixel, so it
## is drawn at full pixel size (MV-734, switch crew_world_full); in the interior view it stays at 2/3
func setup(d: Dictionary, room_mode: String, level_data: Dictionary, index: int, world_view := false) -> void:
	did = int(d.get("id", -1))
	cid = V3Art.crew_for(d)
	in_world = world_view
	spr = AnimatedSprite2D.new()
	spr.centered = false
	_apply_size()
	_mat = ShaderMaterial.new()
	_mat.shader = BLEND
	spr.material = _mat
	add_child(spr)
	Features.changed.connect(_tunes_changed)
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
	_tunes_changed()


## crew_v3.grade / lift / shadow tunes (MV-724) changed: re-apply the shader values and redraw the shadow
func _tunes_changed() -> void:
	_apply_size()
	_mat.set_shader_parameter("grade", grade_k())
	_mat.set_shader_parameter("lift", lift_k())
	queue_redraw()


## MV-734: sprite scale. World view + switch crew_world_full: full pixel size (every sprite pixel = one room
## pixel = one rendered pixel, sharp); otherwise 2/3 (CREW_SCALE, the interior view where room pixels are big).
func _apply_size() -> void:
	if spr.sprite_frames == null:
		spr.sprite_frames = V3Art.crew_frames(cid)
		spr.offset = V3Art.FEET
	full = in_world and Features.on("crew_world_full")
	spr.scale = Vector2.ONE * (V3Art.CREW_SCALE_WORLD if full else V3Art.CREW_SCALE)
	queue_redraw()


## sprite pixels -> room pixels for this actor (1 in the world view, 2/3 in the interior)
func crew_k() -> float:
	return spr.scale.x if spr != null else V3Art.CREW_SCALE


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
			elif pick[2] == "man_gun":
				_act = "shoot"      # MV-716: at the rear gunner post's gun the crew aim and fire (approved shoot clip)
			else:
				_act = "work"
			timer = randf_range(4.0, 8.0)
			state = State.WALK
			_play("carrywalk" if mode == "build" and randf() < 0.5 else "walk")


## [position, face, action] of the next place to go: a stand point of the room's stations, or a spot on the walkway
func _pick_target() -> Array:
	if not stands.is_empty() and (mode != "rest" or randf() < 0.5):
		var h: Dictionary = stands[randi() % stands.size()]
		var s: Array = h.stand
		return [Vector2(float(s[0]) + randf_range(-2, 2), float(s[1])), str(h.get("face", "")), str(h.get("action", ""))]
	return [Vector2(randf_range(12, 132), _walk_y()), "", ""]


func _process(delta: float) -> void:
	if spr == null:
		return
	match state:
		State.WALK:
			var to := target - position
			var step := SPEED * delta
			if to.length() <= step:
				position = target
				queue_redraw()          # last shadow snap at the stop spot
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
	if state == State.WALK:         # the lamp light and the pixel-snapped shadow only change while walking
		_mat.set_shader_parameter("light", lerpf(0.95, 0.65, clampf(absf(position.x - lamp_x) / 72.0, 0.0, 1.0)))
		queue_redraw()


func _draw() -> void:
	# contact shadow under the feet (MV-724): crisp pixel ellipse on the room grid, room-toned
	var k := shadow_k()
	if k <= 0.0:
		return
	var o := Vector2(roundf(position.x), roundf(position.y)) - position   # snap to whole room pixels
	var c1 := Color(_shadow_col, minf(SHADOW_A[0] * k, 1.0))
	var c2 := Color(_shadow_col, minf(SHADOW_A[1] * k, 1.0))
	var wk := crew_k() / V3Art.CREW_SCALE     # MV-734: full-size crew get a 1.5x wider shadow
	for r in SHADOW_ROWS:
		var w := _sw(int(r[1]), wk)
		draw_rect(Rect2(o + Vector2(-floorf(w * 0.5), float(r[0])), Vector2(w, 1)), c1)
	for r in SHADOW_CORE:
		var w := _sw(int(r[1]), wk)
		draw_rect(Rect2(o + Vector2(-floorf(w * 0.5), float(r[0])), Vector2(w, 1)), c2)


## shadow row width scaled for the crew size, kept odd so the ellipse stays centred
static func _sw(w: int, k: float) -> int:
	var n := roundi(w * k)
	return n if n % 2 == 1 else n + 1


## contact shadow strength: tune crew_v3.shadow (MV-724), 1.0 = the pixel shadow's own alphas
static func shadow_k() -> float:
	return Features.num("crew_v3.shadow", SHADOW)


## crew brightness lift toward the v2 crew colours: tune crew_v3.lift (MV-724), 1.0 = off
static func lift_k() -> float:
	return Features.num("crew_v3.lift", LIFT)


## room grade strength on the crew: tune crew_v3.grade (MV-724), 1.0 = the MV-711 grade
static func grade_k() -> float:
	return Features.num("crew_v3.grade", GRADE)


## alpha at the centre of the shadow (outer + core blended), for checks and the GOD note
static func shadow_alpha() -> float:
	var k := shadow_k()
	return 1.0 - (1.0 - minf(SHADOW_A[0] * k, 1.0)) * (1.0 - minf(SHADOW_A[1] * k, 1.0))


func clip() -> String:
	return str(spr.animation) if spr != null else ""
