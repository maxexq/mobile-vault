class_name AmbulanceMotion
extends RefCounted
## MV-726 vehicle micro animations for Dr. Ren's ambulance on the road (world v2, switch vehicle_anim). All code, no
## new art: anchors + a 24-frame tyre strip come from tools/ambulance_anim.py (assets/vehicles/ambulance_v3/anim.json).
## - wheels: the tyres are cut out of the shell and drawn as their own sprites that roll with the road speed; they
##   stay on the road while the body rides on its springs (the rumble / bumps move only the body), and every tyre
##   hops over a bump in turn, front axle first, then the body follows (suspension)
## - start / stop: the body lags back a pixel when pulling out and dips forward when braking to a stop
## - lights: headlight lens (on with the engine), tail lamps (dim when driving, bright when braking or stopped with
##   the engine on), amber marker (blinks when pulling out / pulling over, hazard blink when the engine is broken),
##   roof light bar (red double flash L then R during a raid wave), lantern flicker after dark, mast tip blink
## - roof flag: the cloth is cut from the shell and waves column by column, faster with speed
## Everything sits in two nodes the Vehicle owns: `under` (behind the body: wheel wells + tyres) and `over` (in the
## v2 root over the shell: flag + lamp glows), both in shell px.
## MV-739: the same class drives the Decker bus (dir DK_DIR, anchors from tools/art/decker/anim.py): no flag, roof
## bar, lantern or mast there; instead the "9 DEPOT" destination sign (glyphs lit with the engine, an old display that
## flickers and drops a glyph now and then, brighter at night), the rear amber indicator and a headlight beam at night.

const DIR := "res://assets/vehicles/ambulance_v3/"
const DK_DIR := "res://assets/vehicles/decker_v3/"
const ROAD_PX := 90.0              # world px/s at speed factor 1 (= Background.ROAD_PX_PER_SEC)
const BLINK := 0.36                # s per indicator half-cycle
const SIGNAL_SEC := 2.9            # indicator time after pulling out / before stopping
const BEACON_CYCLE := 0.9          # roof bar: L flash flash, R flash flash
const FLAG_FRAMES := 8
const WELL := Color("141214")      # dark wheel well behind each tyre (rides with the body)

static var _meta: Dictionary = {}         # dir -> anim.json
static var _shells: Dictionary = {}        # dir + floors -> ImageTexture (tyres + flag cloth cut out)
static var _flag_frames: Dictionary = {}   # dir + floors -> Array[ImageTexture]
static var _spin: Dictionary = {}          # dir -> Array[AtlasTexture]
static var _glow_tex: GradientTexture2D

var vehicle: Node2D
var dir := DIR                     # shell set: DIR (ambulance) or DK_DIR (Decker bus)
var floors := 0
var under: Node2D                  # behind the body, scale V2_K
var wells: Node2D
var over: Node2D                   # in the v2 root, over the shell
var tyres: Array[Sprite2D] = []
var hops: Array[float] = []        # per tyre: s until its bump hop, < 0 = none pending
var hop_left: Array[float] = []
var flag: Sprite2D
var glows: Dictionary = {}         # name -> Sprite2D (tails: "tail0", "tail1" ...)
var spin_angle := 0.0              # radians the tyres have rolled
var lurch := 0.0                   # body x offset (shell px): + = lags back east, - = dips forward
var signal_t := 0.0                # indicator time left
var _t := 0.0
var _flag_t := 0.0
var _flag_i := 0
var _was_moving := false
var _lantern := 1.0
var _lantern_t := 0.0
var sign_lit: Sprite2D             # Decker: the destination sign's glyphs, additive
var sign_dead: Sprite2D            # Decker: covers one glyph while it drops out
var _sign := 1.0
var _sign_t := 0.0
var _dead_t := 0.0
## GOD MODE / autotest overrides
var force_beacon := false
var force_brake := false


static func meta(d := DIR) -> Dictionary:
	if not _meta.has(d) and FileAccess.file_exists(d + "anim.json"):
		_meta[d] = JSON.parse_string(FileAccess.get_file_as_string(d + "anim.json"))
	return _meta.get(d, {})


static func spot(n: int, d := DIR) -> Dictionary:
	return (meta(d).get("floors", {}) as Dictionary).get(str(n), {})


## the anchors are there and match the shell size (rerun tools/ambulance_anim.py / tools/art/decker/anim.py after a
## shell rebuild)
static func ok(n: int, d := DIR) -> bool:
	var f := spot(n, d)
	if f.is_empty() or not ResourceLoader.exists(d + "wheel_spin.png") or not ResourceLoader.exists(d + "shell_f%d.png" % n):
		return false
	var tex: Texture2D = load(d + "shell_f%d.png" % n)
	return tex.get_size() == Vector2(f.size[0], f.size[1])


## the shell with the tyres and the flag cloth cut out (they are drawn by this class)
static func cut_shell(n: int, d := DIR) -> Texture2D:
	var key := d + str(n)
	if _shells.has(key):
		return _shells[key]
	var f := spot(n, d)
	var img: Image = (load(d + "shell_f%d.png" % n) as Texture2D).get_image()
	img.decompress()
	var r: float = f.wheel_r
	for w in f.wheels:
		var c := Vector2(w[0], w[1])
		for y in range(int(c.y - r) - 1, int(c.y + r) + 2):
			for x in range(int(c.x - r) - 1, int(c.x + r) + 2):
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() \
						and Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
	_flag_frames[key] = []
	if f.has("flag"):
		var fr: Array = f.flag
		var cloth := img.get_region(Rect2i(fr[0], fr[1], fr[2], fr[3]))
		img.fill_rect(Rect2i(fr[0], fr[1], fr[2], fr[3]), Color(0, 0, 0, 0))
		_flag_frames[key] = _wave_frames(cloth)
	_shells[key] = ImageTexture.create_from_image(img)
	return _shells[key]


## Decker: the sign's glyph pixels alone (white, tinted amber by modulate) and the sign's unlit face colour
static func sign_glyphs(n: int, d: String) -> Image:
	var f := spot(n, d)
	var sr: Array = f.sign
	var img: Image = (load(d + "shell_f%d.png" % n) as Texture2D).get_image()
	img.decompress()
	var out := Image.create_empty(int(sr[2]), int(sr[3]), false, Image.FORMAT_RGBA8)
	for y in int(sr[3]):
		for x in int(sr[2]):
			var c := img.get_pixel(int(sr[0]) + x, int(sr[1]) + y)
			if c.r > 0.59 and c.g > 0.35 and c.b < 0.35:
				out.set_pixel(x, y, Color(1, 1, 1, 1))
	return out


## FLAG_FRAMES frames of the cloth waving: every column shifts up/down by whole pixels, more the further it is from
## the pole (2 px of padding above and below)
static func _wave_frames(cloth: Image) -> Array:
	var out: Array = []
	var w := cloth.get_width()
	var h := cloth.get_height()
	for i in FLAG_FRAMES:
		var im := Image.create_empty(w, h + 4, false, Image.FORMAT_RGBA8)
		var ph := TAU * float(i) / float(FLAG_FRAMES)
		for x in w:
			var k := float(x + 1) / float(w)
			var dy := int(round(sin(ph - float(x) * 0.55) * 1.6 * k))
			for y in h:
				var c := cloth.get_pixel(x, y)
				if c.a > 0.0:
					im.set_pixel(x, y + 2 + dy, c)
		out.append(ImageTexture.create_from_image(im))
	return out


static func spin_frames(d := DIR) -> Array:
	if not _spin.has(d):
		var arr: Array = []
		var strip: Texture2D = load(d + "wheel_spin.png")
		var s: int = int(meta(d).get("wheel_size", 47))
		for i in int(meta(d).get("spin_frames", 24)):
			var a := AtlasTexture.new()
			a.atlas = strip
			a.region = Rect2(s * i, 0, s, s)
			arr.append(a)
		_spin[d] = arr
	return _spin[d]


## soft round glow in 4 hard steps (pixel-art bloom), white: tinted per lamp with modulate
static func glow_tex() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.width = 32
		_glow_tex.height = 32
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
	return _glow_tex


## (re)build for a shell of n floors whose top-left is `origin` (shell px). `under_parent` is behind the body,
## `over_parent` is the v2 root (over the shell).
func build(n: int, origin: Vector2, under_parent: Node2D, over_parent: Node2D, k: float, d := DIR) -> void:
	clear()
	dir = d
	floors = n
	var f := spot(n, dir)
	under = Node2D.new()
	under.name = "AmbulanceWheels"
	under.scale = Vector2.ONE * k
	under_parent.add_child(under)
	wells = Node2D.new()
	under.add_child(wells)
	var s: int = int(meta(dir).get("wheel_size", 47))
	var r: float = f.wheel_r
	for w in f.wheels:
		var c := origin + Vector2(w[0], w[1])
		var well := Polygon2D.new()                 # half disc up into the arch: never any sky between tyre and body
		var pts := PackedVector2Array()
		for i in 17:
			var a := PI + PI * float(i) / 16.0
			pts.append(c + Vector2(cos(a), sin(a)) * (r + 1.5))
		well.polygon = pts
		well.color = WELL
		wells.add_child(well)
		var t := Sprite2D.new()
		t.centered = false
		t.texture = spin_frames(dir)[0]
		t.position = c - Vector2(s, s) * 0.5
		t.set_meta("y0", t.position.y)
		under.add_child(t)
		tyres.append(t)
		hops.append(-1.0)
		hop_left.append(0.0)
	over = Node2D.new()
	over.name = "AmbulanceLights"
	over_parent.add_child(over)
	cut_shell(n, dir)
	flag = null
	if f.has("flag"):
		var fr: Array = f.flag
		flag = Sprite2D.new()
		flag.centered = false
		flag.position = origin + Vector2(fr[0], fr[1] - 2)
		over.add_child(flag)
		flag.texture = (_flag_frames[dir + str(n)] as Array)[0]
	_glow("head", origin + _v(f.head), 9.0, Color(1.0, 0.86, 0.55))
	_glow("marker", origin + _v(f.marker), 7.0, Color(1.0, 0.6, 0.15))
	for id in ["bar_l", "bar_r"]:
		if f.has(id):
			_glow(id, origin + _v(f[id]), 11.0, Color(1.0, 0.12, 0.1))
	if f.has("lantern"):
		_glow("lantern", origin + _v(f.lantern), 12.0, Color(1.0, 0.7, 0.3))
	if f.has("mast"):
		_glow("mast", origin + _v(f.mast), 5.0, Color(1.0, 0.25, 0.2))
	if f.has("sign"):
		_build_sign(f, origin)
		var beam := _glow("beam", origin + _v(f.head) + Vector2(-26, 2), 1.0, Color(1.0, 0.88, 0.6))
		beam.scale = Vector2(56.0, 14.0) / 32.0       # a flat cone of light on the road ahead after dark
	var i := 0
	for p in f.tails:
		_glow("tail%d" % i, origin + _v(p) + Vector2(1, 0), 7.0, Color(1.0, 0.1, 0.08))
		i += 1


func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


## Decker: lit glyphs over the sign (additive amber) + a patch of the sign's dark face that hides one glyph at a time
func _build_sign(f: Dictionary, origin: Vector2) -> void:
	var sr: Array = f.sign
	sign_lit = Sprite2D.new()
	sign_lit.centered = false
	sign_lit.position = origin + Vector2(sr[0], sr[1])
	sign_lit.texture = ImageTexture.create_from_image(sign_glyphs(floors, dir))
	sign_lit.modulate = Color(1.0, 0.62, 0.18, 0.0)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sign_lit.material = m
	over.add_child(sign_lit)
	sign_dead = Sprite2D.new()
	sign_dead.centered = false
	var px := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	px.set_pixel(0, 0, Color("1e1c1a"))
	sign_dead.texture = ImageTexture.create_from_image(px)
	sign_dead.visible = false
	sign_dead.set_meta("glyphs", f.get("glyphs", []))
	sign_dead.set_meta("o", origin + Vector2(0, sr[1]))
	sign_dead.set_meta("h", float(sr[3]))
	over.add_child(sign_dead)


func _glow(id: String, at: Vector2, radius: float, col: Color) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = glow_tex()
	g.position = at
	g.scale = Vector2.ONE * (radius * 2.0 / 32.0)
	g.modulate = Color(col, 0.0)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	g.set_meta("col", col)
	over.add_child(g)
	glows[id] = g
	return g


func clear() -> void:
	for n in [under, over]:
		if is_instance_valid(n):
			n.queue_free()
	under = null
	over = null
	tyres.clear()
	sign_lit = null
	sign_dead = null
	flag = null
	hops.clear()
	hop_left.clear()
	glows.clear()
	floors = 0


func set_visible(on: bool) -> void:
	for n in [under, over]:
		if is_instance_valid(n):
			n.visible = on


func _lamp(id: String, a: float) -> void:
	var g: Sprite2D = glows.get(id)
	if g:
		g.modulate.a = clampf(a, 0.0, 1.0)
		g.visible = a > 0.01


## a road bump under the front axle now: the tyres hop over it one after another at the road speed
func bump(speed_px: float) -> void:
	if tyres.is_empty() or speed_px < 1.0:
		return
	var x0 := tyres[0].position.x
	for i in tyres.size():
		var d := (tyres[i].position.x - x0) * under.scale.x            # world px behind the front axle
		hops[i] = d / speed_px
		hop_left[i] = 0.0


## per frame. speed_px = road speed (world px/s), accel in speed-factor/s, body_y = the body's bounce (world px)
func tick(delta: float, speed_px: float, accel: float, engine_on: bool, night: float, body_y: float, alert: bool, hazard: bool) -> void:
	if under == null:
		return
	_t += delta
	var moving := speed_px > 1.0
	# tyres roll: angle = distance / radius (in shell px: the strip is drawn at shell scale)
	var r: float = spot(floors, dir).get("wheel_r", 22.5)
	spin_angle = fposmod(spin_angle + speed_px / under.scale.x / r * delta, TAU)
	var frames := spin_frames(dir)
	var n := frames.size()
	var fi := int(spin_angle / TAU * float(n)) % n
	for i in tyres.size():
		var t := tyres[i]
		t.texture = frames[fi]
		if hops[i] >= 0.0:
			hops[i] -= delta
			if hops[i] < 0.0:
				hop_left[i] = 0.09
		hop_left[i] = maxf(0.0, hop_left[i] - delta)
		t.position.y = float(t.get_meta("y0")) - (2.0 if hop_left[i] > 0.0 else 0.0)
	# start / stop: the body lags back when pulling out, dips forward while braking hard to a stop
	if moving != _was_moving:
		signal_t = SIGNAL_SEC
		_was_moving = moving
	var want := 0.0
	if accel > 0.05 and speed_px < ROAD_PX * 0.6:
		want = 2.0
	elif accel < -0.05:
		want = -2.0
	lurch = move_toward(lurch, want, delta * 12.0)
	var lx := roundf(lurch)
	(over.get_parent() as Node2D).position.x = lx * under.scale.x
	wells.position = Vector2(lx, body_y / under.scale.y)
	# lights
	var dark := clampf(night, 0.0, 1.0)
	var braking := force_brake or (engine_on and (accel < -0.02 or not moving))
	_lamp("head", (0.35 + 0.55 * dark) if engine_on else 0.0)
	for i in 8:
		if not glows.has("tail%d" % i):
			break
		_lamp("tail%d" % i, (0.85 if braking else 0.25 + 0.3 * dark) if (engine_on or force_brake) else 0.0)
	signal_t = maxf(0.0, signal_t - delta)
	var blink_on := fmod(_t, BLINK * 2.0) < BLINK
	_lamp("marker", 0.9 if (hazard or signal_t > 0.0) and blink_on else 0.0)
	var bar_l := 0.0
	var bar_r := 0.0
	if alert or force_beacon:
		var ph := fmod(_t, BEACON_CYCLE) / BEACON_CYCLE        # double flash left, then double flash right
		bar_l = 1.0 if (ph < 0.1 or (ph >= 0.18 and ph < 0.28)) else 0.0
		bar_r = 1.0 if (ph >= 0.5 and ph < 0.6) or (ph >= 0.68 and ph < 0.78) else 0.0
	_lamp("bar_l", bar_l)
	_lamp("bar_r", bar_r)
	_lantern_t -= delta
	if _lantern_t <= 0.0:
		_lantern_t = randf_range(0.08, 0.22)
		_lantern = randf_range(0.7, 1.0)
	_lamp("lantern", dark * 0.8 * _lantern)
	_lamp("mast", 0.9 if fmod(_t, 1.6) < 0.22 else 0.0)
	_lamp("beam", dark * 0.5 if engine_on else 0.0)
	_tick_sign(delta, engine_on, dark, hazard)
	# flag: a slow breeze parked, snapping in the headwind when driving
	if flag == null:
		return
	_flag_t -= delta
	if _flag_t <= 0.0:
		_flag_t = 1.0 / (4.0 + 10.0 * clampf(speed_px / ROAD_PX, 0.0, 1.2))
		_flag_i = (_flag_i + 1) % FLAG_FRAMES
		flag.texture = (_flag_frames[dir + str(floors)] as Array)[_flag_i]


## Decker destination sign: on with the engine (brighter after dark), an old display that flickers now and then and
## sometimes loses one glyph for a moment; hazard (broken engine) = the whole sign blinks
func _tick_sign(delta: float, engine_on: bool, dark: float, hazard: bool) -> void:
	if sign_lit == null:
		return
	_sign_t -= delta
	if _sign_t <= 0.0:
		var glitch := randf() < 0.12
		_sign_t = randf_range(0.04, 0.09) if glitch else randf_range(0.5, 1.6)
		_sign = randf_range(0.15, 0.5) if glitch else randf_range(0.85, 1.0)
	_dead_t -= delta
	if _dead_t <= 0.0:
		var gl: Array = sign_dead.get_meta("glyphs")
		var drop := not gl.is_empty() and randf() < 0.35
		_dead_t = randf_range(0.15, 0.6) if drop else randf_range(2.0, 5.0)
		sign_dead.visible = drop and engine_on
		if drop:
			var g: Array = gl[randi() % gl.size()]
			sign_dead.position = (sign_dead.get_meta("o") as Vector2) + Vector2(float(g[0]), 0.0)
			sign_dead.scale = Vector2(float(g[1]), float(sign_dead.get_meta("h")))
	var a := (0.45 + 0.4 * dark) * _sign if engine_on else 0.0
	if hazard and fmod(_t, BLINK * 2.0) >= BLINK:
		a = 0.0
	sign_lit.modulate.a = a
	sign_lit.visible = a > 0.01
	if not engine_on:
		sign_dead.visible = false


func sign_alpha() -> float:
	return sign_lit.modulate.a if sign_lit and sign_lit.visible else 0.0


func lamp_alpha(id: String) -> float:
	var g: Sprite2D = glows.get(id)
	return g.modulate.a if g and g.visible else 0.0


func flag_frame() -> int:
	return _flag_i


func spin_frame() -> int:
	return int(spin_angle / TAU * float(spin_frames(dir).size())) % spin_frames(dir).size()
