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
## MV-740: and the road train (dir RT_DIR, anchors from tools/art/road_train/anim.py): one instance per unit (unit ""
## = tractor + lead trailer, "trailer" = each container trailer), plus landing legs that crank up when driving and down
## once fully stopped, roof clearance lamps, a searchlight and a blinking mast tip on the trailers.

const DIR := "res://assets/vehicles/ambulance_v3/"
const DK_DIR := "res://assets/vehicles/decker_v3/"
const RT_DIR := "res://assets/vehicles/road_train_v3/"
const LEG_LIFT := 6.0              # shell px the landing legs crank up while driving
const LEG_DOWN_AFTER := 0.8        # s fully stopped before the legs crank down
const LEG_CRANK := 1.2             # s for a full crank (up or down)
const ROAD_PX := 90.0              # world px/s at speed factor 1 (= Background.ROAD_PX_PER_SEC)
const BLINK := 0.36                # s per indicator half-cycle
const SIGNAL_SEC := 2.9            # indicator time after pulling out / before stopping
const BEACON_CYCLE := 0.9          # roof bar: L flash flash, R flash flash
const FLAG_FRAMES := 8
const WELL := Color("141214")      # dark wheel well behind each tyre (rides with the body)
const LAMP_W := 4.6                # MV-741 lantern pendulum: rad/s natural frequency
const LAMP_DAMP := 1.1             # 1/s
const GLINT_FRAMES := 12
const PUFF_LIFE := 1.8             # s
const PUFF_MAX := 7
const DRIVER_AT := Vector2(87, 139)  # cab glass: x, shell height - y (tools/art/ambulance/driver.py)

static var _meta: Dictionary = {}         # dir -> anim.json
static var _shells: Dictionary = {}        # dir + floors -> ImageTexture (tyres + flag cloth cut out)
static var _flag_frames: Dictionary = {}   # dir + floors -> Array[ImageTexture]
static var _swing_frames: Dictionary = {}  # dir + floors -> Array (per swing rect) of Array[ImageTexture]
const SWING_STEPS := 9                     # frames from -2 to +2 px at the cable's lowest point
static var _spin: Dictionary = {}          # dir -> Array[AtlasTexture]
static var _legs: Dictionary = {}          # dir + unit + floors -> Array[ImageTexture] (landing legs cut from the shell)
static var _glow_tex: GradientTexture2D
static var _lamp_src: Dictionary = {}      # dir + floors -> Image of the lantern cut out of the shell (MV-741)
static var _clips: Dictionary = {}         # dir + floors -> {clip: {"at": Vector2i, "frames": Array[AtlasTexture]}} (MV-741)
static var _glints: Dictionary = {}        # dir + floors -> {"at": Vector2i, "frames": Array[ImageTexture]} (MV-741)
static var _driver: Dictionary = {}        # state -> Array[AtlasTexture] (MV-741 Dr. Ren at the wheel)
static var _puff_tex: Array[ImageTexture] = []

var vehicle: Node2D
var dir := DIR                     # shell set: DIR (ambulance) or DK_DIR (Decker bus) or RT_DIR (road train)
var unit := ""                     # road train: "" = tractor + lead trailer, "trailer" = a container trailer,
                                   # "trailer_link" = a container trailer with another one behind it (B-link rear)
var floors := 0
var behind: Node2D                 # road train: in the v2 root under every shell (landing legs slide up behind them)
var legs: Array[Sprite2D] = []
var leg_down := 1.0                # 1 = feet on the road, 0 = cranked up
var _stopped_t := 0.0
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
var swings: Array[Sprite2D] = []   # Decker: loose cables under the floor
var _swing_ph := 0.0
var _swing_kick := 0.0
var sign_lit: Sprite2D             # Decker: the destination sign's glyphs, additive
var sign_dead: Sprite2D            # Decker: covers one glyph while it drops out
var _sign := 1.0
var _sign_t := 0.0
var _dead_t := 0.0
var flame: Sprite2D                # MV-741: the whole lantern, cut from the shell, with the PixelLab flame flicker
var flame_frames: Array[ImageTexture] = []
var _flame_i := 0
var lamp: Node2D                   # MV-741: pivot at the lantern's bail: it swings while the vehicle moves
var lamp_angle := 0.0              # radians, + = the lantern swings forward (west, the way the cab faces)
var _lamp_vel := 0.0
var _lamp_kick_t := 0.0
var clips: Dictionary = {}         # MV-741 PixelLab roof clips: potsL / potsR (leaves sway) / birds (a sparrow) -> Sprite2D
var clip_i: Dictionary = {}        # clip -> current frame
var _clip_t: Dictionary = {}       # clip -> s until the next frame
var _bird_wait := 3.0
var glint: Sprite2D                # MV-741 sun glint sweeping the solar cells by day (additive)
var glint_frame := -1              # -1 = no sweep running
var _glint_wait := 2.0
var _glint_t := 0.0
var pipe_at := Vector2.ZERO
var puffs: Array[Sprite2D] = []    # MV-741 smoke puffs from the copper pipe on the tank
var _puff_wait := 0.5
var driver: Sprite2D               # MV-741 Dr. Ren at the wheel: drive / chill / idle / still loops
var driver_state := ""
var _driver_i := 0
var _driver_t := 0.0
## GOD MODE / autotest overrides
var force_beacon := false
var force_brake := false


static func meta(d := DIR) -> Dictionary:
	if not _meta.has(d) and FileAccess.file_exists(d + "anim.json"):
		_meta[d] = JSON.parse_string(FileAccess.get_file_as_string(d + "anim.json"))
	return _meta.get(d, {})


static func spot(n: int, d := DIR, u := "") -> Dictionary:
	return (meta(d).get(u if u != "" else "floors", {}) as Dictionary).get(str(n), {})


## the shell texture of a unit: shell_f<n> (ambulance, Decker), body_f<n> / trailer_f<n> (road train)
static func shell_file(n: int, d := DIR, u := "") -> String:
	if d == RT_DIR:
		return d + ("%s_f%d.png" % [u, n] if u != "" else "body_f%d.png" % n)
	return d + "shell_f%d.png" % n


## the anchors are there and match the shell size (rerun tools/ambulance_anim.py / tools/art/decker/anim.py /
## tools/art/road_train/anim.py after a shell rebuild)
static func ok(n: int, d := DIR, u := "") -> bool:
	var f := spot(n, d, u)
	if f.is_empty() or not ResourceLoader.exists(d + "wheel_spin.png") or not ResourceLoader.exists(shell_file(n, d, u)):
		return false
	var tex: Texture2D = load(shell_file(n, d, u))
	return tex.get_size() == Vector2(f.size[0], f.size[1])


## the shell with the tyres, the flag cloth and the landing legs cut out (they are drawn by this class)
static func cut_shell(n: int, d := DIR, u := "") -> Texture2D:
	var key := d + u + str(n)
	if _shells.has(key):
		return _shells[key]
	var f := spot(n, d, u)
	var img: Image = (load(shell_file(n, d, u)) as Texture2D).get_image()
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
	var sw: Array = []
	for q in f.get("swing", []):
		var rect := Rect2i(int(q[0]), int(q[1]), int(q[2]), int(q[3]))
		sw.append(_swing_set(img.get_region(rect)))
		img.fill_rect(rect, Color(0, 0, 0, 0))
	_swing_frames[key] = sw
	if f.has("lantern_still"):                 # MV-741: the lantern swings on its own sprite
		var lr: Array = f.lantern_still
		var lrect := Rect2i(int(lr[0]), int(lr[1]), int(lr[2]), int(lr[3]))
		_lamp_src[key] = img.get_region(lrect)
		img.fill_rect(lrect, Color(0, 0, 0, 0))
	_clips[key] = _cut_clips(img, f, d)        # MV-741: PixelLab roof parts animate on their own sprites
	if f.has("solar_px"):
		_glints[key] = _glint_frames(f.solar_px)
	if (_clips[key] as Dictionary).has("flag"):
		_flag_frames[key] = (_clips[key] as Dictionary).flag.frames
		(_clips[key] as Dictionary).erase("flag")
	elif f.has("flag"):
		var fr: Array = f.flag
		var cloth := img.get_region(Rect2i(fr[0], fr[1], fr[2], fr[3]))
		img.fill_rect(Rect2i(fr[0], fr[1], fr[2], fr[3]), Color(0, 0, 0, 0))
		_flag_frames[key] = _wave_frames(cloth)
	_legs[key] = []
	for lr in f.get("legs", []):
		var r2 := Rect2i(int(lr[0]), int(lr[1]), int(lr[2]), int(lr[3]))
		_legs[key].append(ImageTexture.create_from_image(img.get_region(r2)))
		img.fill_rect(r2, Color(0, 0, 0, 0))
	_shells[key] = ImageTexture.create_from_image(img)
	return _shells[key]


## loose cables: SWING_STEPS frames, every pixel shifted sideways by s * its depth below the attach row (s = -2..2),
## 3 px padding left and right
static func _swing_set(src: Image) -> Array:
	var out: Array = []
	var w := src.get_width()
	var h := src.get_height()
	for i in SWING_STEPS:
		var sv := -2.0 + 4.0 * float(i) / float(SWING_STEPS - 1)
		var im := Image.create_empty(w + 6, h, false, Image.FORMAT_RGBA8)
		for y in h:
			var dx := int(round(sv * float(y + 1) / float(h)))
			for x in w:
				var c := src.get_pixel(x, y)
				if c.a > 0.0:
					im.set_pixel(x + 3 + dx, y, c)
		out.append(ImageTexture.create_from_image(im))
	return out


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


## MV-741 round 3: every clip in anim.json (roof_<clip>.png strips from tools/art/ambulance/roof, PixelLab
## animate-with-text-v3 over the Pro inpaint-v3 parts): its frame 0 is baked into the shell, so those pixels are cut out
## of `img` and the clip's sprite draws them. {clip: {"at": Vector2i, "frames": Array[AtlasTexture]}}
static func _cut_clips(img: Image, f: Dictionary, d := DIR) -> Dictionary:
	var out := {}
	for c in (f.get("clips", {}) as Dictionary):
		if not ResourceLoader.exists(d + "roof_%s.png" % c):
			continue
		var r: Array = f.clips[c].rect
		var at := Vector2i(int(r[0]), int(r[1]))
		var sz := Vector2i(int(r[2]), int(r[3]))
		var strip: Texture2D = load(d + "roof_%s.png" % c)
		var still := strip.get_image()
		still.decompress()
		for y in sz.y:
			for x in sz.x:
				if still.get_pixel(x, y).a > 0.5:
					img.set_pixel(at.x + x, at.y + y, Color(0, 0, 0, 0))
		var frames: Array[AtlasTexture] = []
		for i in int(f.clips[c].frames):
			var a := AtlasTexture.new()
			a.atlas = strip
			a.region = Rect2(Vector2(sz.x * i, 0), Vector2(sz))
			frames.append(a)
		out[c] = {"at": at, "frames": frames}
	return out

## MV-741: GLINT_FRAMES frames of a bright diagonal band sweeping west to east over the solar cell glass (solar_px)
static func _glint_frames(px: Array) -> Dictionary:
	var lo := Vector2i(100000, 100000)
	var hi := Vector2i(-1, -1)
	for q in px:
		lo = Vector2i(mini(lo.x, int(q[0])), mini(lo.y, int(q[1])))
		hi = Vector2i(maxi(hi.x, int(q[0])), maxi(hi.y, int(q[1])))
	var size := hi - lo + Vector2i.ONE
	var out: Array[ImageTexture] = []
	for i in GLINT_FRAMES:
		var im := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		var pos := -12.0 + (float(size.x) + 24.0) * float(i) / float(GLINT_FRAMES - 1)
		for q in px:
			var x := int(q[0]) - lo.x
			var y := int(q[1]) - lo.y
			var d := absf(float(x) + float(y) * 0.7 - pos)
			if d < 1.5:
				im.set_pixel(x, y, Color(1, 1, 0.92, 0.85))
			elif d < 4.0:
				im.set_pixel(x, y, Color(0.8, 0.9, 1.0, 0.35))
		out.append(ImageTexture.create_from_image(im))
	return {"at": lo, "frames": out}

## MV-741: driver.png rows = drive, chill, idle, still (driver.py); {} when the strip is not there
static func driver_frames() -> Dictionary:
	if _driver.is_empty() and ResourceLoader.exists(DIR + "driver.png") and FileAccess.file_exists(DIR + "driver.json"):
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "driver.json"))
		var strip: Texture2D = load(DIR + "driver.png")
		var sz := Vector2(float(j.size[0]), float(j.size[1]))
		var row := 0
		for st in ["drive", "chill", "idle", "still"]:
			var arr: Array[AtlasTexture] = []
			for i in int(j.states.get(st, 0)):
				var a := AtlasTexture.new()
				a.atlas = strip
				a.region = Rect2(Vector2(sz.x * i, sz.y * row), sz)
				arr.append(a)
			_driver[st] = arr
			row += 1
		_driver["fps"] = float(j.get("fps", 8))
	return _driver

## MV-741: small grey pixel puffs, radius 1..3
static func puff_tex() -> Array[ImageTexture]:
	if _puff_tex.is_empty():
		for r in [1, 2, 3]:
			var s: int = r * 2 + 1
			var im := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
			for y in s:
				for x in s:
					var d := Vector2(x - r, y - r).length()
					if d <= float(r) + 0.25:
						im.set_pixel(x, y, Color(0.62, 0.6, 0.57, 1.0) if y < r else Color(0.48, 0.46, 0.44, 1.0))
			_puff_tex.append(ImageTexture.create_from_image(im))
	return _puff_tex


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
func build(n: int, origin: Vector2, under_parent: Node2D, over_parent: Node2D, k: float, d := DIR, u := "") -> void:
	clear()
	dir = d
	unit = u
	floors = n
	var f := spot(n, dir, unit)
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
	cut_shell(n, dir, unit)
	var key := dir + unit + str(n)
	flag = null
	if f.has("flag"):
		var fr: Array = f.flag
		flag = Sprite2D.new()
		flag.centered = false
		flag.position = origin + Vector2(fr[0], fr[1] - (0 if (f.get("clips", {}) as Dictionary).has("flag") else 2))
		over.add_child(flag)
		flag.texture = (_flag_frames[key] as Array)[0]
	if not (_legs.get(key, []) as Array).is_empty():
		behind = Node2D.new()
		behind.name = "RoadTrainLegs"
		over_parent.add_child(behind)
		over_parent.move_child(behind, 0)
		var li := 0
		for lr in f.legs:
			var leg := Sprite2D.new()
			leg.centered = false
			leg.texture = _legs[key][li]
			leg.position = origin + Vector2(lr[0], lr[1])
			leg.set_meta("y0", leg.position.y)
			behind.add_child(leg)
			legs.append(leg)
			li += 1
	if f.has("head"):
		_glow("head", origin + _v(f.head), 9.0, Color(1.0, 0.86, 0.55))
	if f.has("marker"):
		_glow("marker", origin + _v(f.marker), 7.0, Color(1.0, 0.6, 0.15))
	var roof_i := 0
	for p in f.get("roof_lamps", []):
		_glow("roof%d" % roof_i, origin + _v(p), 5.0, Color(1.0, 0.25, 0.12))
		roof_i += 1
	if f.has("search"):
		_glow("lantern", origin + _v(f.search), 10.0, Color(1.0, 0.92, 0.65))
	for id in ["bar_l", "bar_r"]:
		if f.has(id):
			_glow(id, origin + _v(f[id]), 11.0, Color(1.0, 0.12, 0.1))
	if f.has("lantern"):
		_glow("lantern", origin + _v(f.lantern), 12.0, Color(1.0, 0.7, 0.3))
	_build_flame(f, origin)
	_build_roof(f, origin)
	if f.has("mast"):
		_glow("mast", origin + _v(f.mast), 5.0, Color(1.0, 0.25, 0.2))
	var ri := 0
	for q in f.get("swing", []):
		var sp := Sprite2D.new()
		sp.centered = false
		sp.position = origin + Vector2(float(q[0]) - 3.0, float(q[1]))
		sp.texture = (_swing_frames[dir + unit + str(n)][ri] as Array)[SWING_STEPS / 2]
		sp.set_meta("i", ri)
		over.add_child(sp)
		swings.append(sp)
		ri += 1
	if f.has("sign") or dir == RT_DIR and f.has("head"):
		if f.has("sign"):
			_build_sign(f, origin)
		var beam := _glow("beam", origin + _v(f.head) + Vector2(-26, 2), 1.0, Color(1.0, 0.88, 0.6))
		beam.scale = Vector2(56.0, 14.0) / 32.0       # a flat cone of light on the road ahead after dark
	var i := 0
	for p in f.tails:
		_glow("tail%d" % i, origin + _v(p) + Vector2(1, 0), 7.0, Color(1.0, 0.1, 0.08))
		i += 1


## MV-741 micro anims: the swaying leaves, the solar glint, the pipe puffs and Dr. Ren at the wheel
func _build_roof(f: Dictionary, origin: Vector2) -> void:
	clip_i.clear()
	_clip_t.clear()
	glint_frame = -1
	puffs.clear()
	for c in (_clips.get(dir + unit + str(floors), {}) as Dictionary):
		var cs := Sprite2D.new()
		cs.name = "Roof_" + str(c)
		cs.centered = false
		cs.position = origin + Vector2(_clips[dir + unit + str(floors)][c].at)
		cs.texture = (_clips[dir + unit + str(floors)][c].frames as Array)[0]
		over.add_child(cs)
		over.move_child(cs, 0)
		clips[c] = cs
		clip_i[c] = 0
		_clip_t[c] = randf_range(0.0, 0.3)
	if _glints.has(dir + unit + str(floors)):
		glint = Sprite2D.new()
		glint.name = "SolarGlint"
		glint.centered = false
		glint.position = origin + Vector2(_glints[dir + unit + str(floors)].at)
		glint.visible = false
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glint.material = m
		over.add_child(glint)
	if f.get("pipe") != null:
		pipe_at = origin + _v(f.pipe)
	var d := driver_frames() if dir == DIR else {}
	if not d.is_empty() and not (d.still as Array).is_empty():
		driver = Sprite2D.new()
		driver.name = "Driver"
		driver.centered = false
		driver.position = origin + Vector2(DRIVER_AT.x, float(f.size[1]) - DRIVER_AT.y)
		driver.texture = (d.still as Array)[0]
		driver_state = "still"
		over.add_child(driver)
		over.move_child(driver, 0)


func _tick_roof(delta: float, speed_px: float, engine_on: bool, accel: float, dark: float) -> void:
	var sp := clampf(speed_px / ROAD_PX, 0.0, 1.5)
	for c in clips:                            # MV-741 PixelLab clips: pots sway (faster in the headwind), the sparrow pops out now and then
		var fs: Array = _clips[dir + unit + str(floors)][c].frames
		_clip_t[c] = float(_clip_t[c]) - delta
		if float(_clip_t[c]) > 0.0:
			continue
		if c == "birds":
			if int(clip_i[c]) == 0:
				_bird_wait -= 0.125
				if _bird_wait > 0.0:
					_clip_t[c] = 0.125
					continue
				_bird_wait = randf_range(5.0, 11.0)
			_clip_t[c] = 0.16
		else:
			_clip_t[c] = 1.0 / (4.0 if sp < 0.15 else 7.0 + 5.0 * sp)
		clip_i[c] = (int(clip_i[c]) + 1) % fs.size()
		(clips[c] as Sprite2D).texture = fs[int(clip_i[c])]
	if glint:                                  # a sun glint runs over the cells every few seconds by day
		var day := 1.0 - dark
		if glint_frame < 0:
			_glint_wait -= delta
			if _glint_wait <= 0.0 and day > 0.4:
				glint_frame = 0
				_glint_t = 0.0
		if glint_frame >= 0:
			_glint_t += delta
			var i := int(_glint_t * 22.0)
			if i >= GLINT_FRAMES:
				glint_frame = -1
				glint.visible = false
				_glint_wait = randf_range(4.0, 8.0)
			else:
				glint_frame = i
				glint.texture = (_glints[dir + unit + str(floors)].frames as Array)[i]
				glint.modulate.a = day
				glint.visible = true
	if pipe_at != Vector2.ZERO:                # puffs while the engine runs, faster when pulling away
		_puff_wait -= delta
		if engine_on and _puff_wait <= 0.0:
			_puff_wait = randf_range(0.25, 0.5) if accel > 0.05 else randf_range(0.7, 1.4)
			if puffs.size() < PUFF_MAX:
				var p := Sprite2D.new()
				p.texture = puff_tex()[0]
				p.set_meta("t", 0.0)
				p.set_meta("pos", pipe_at + Vector2(randf_range(-0.5, 0.5), 0))
				over.add_child(p)
				puffs.append(p)
		for p in puffs.duplicate():
			var t: float = float(p.get_meta("t")) + delta
			if t >= PUFF_LIFE:
				puffs.erase(p)
				p.queue_free()
				continue
			var pos: Vector2 = p.get_meta("pos") + Vector2(2.0 + 14.0 * sp, -9.0 + 4.0 * t) * delta
			p.set_meta("t", t)
			p.set_meta("pos", pos)
			p.position = pos.round()
			p.texture = puff_tex()[mini(2, int(t / PUFF_LIFE * 3.0))]
			p.modulate = Color(1.0 - 0.45 * dark, 1.0 - 0.45 * dark, 1.0 - 0.45 * dark, 0.75 * (1.0 - t / PUFF_LIFE))
	if driver:                                 # Dr. Ren: hands on the wheel at speed, relaxed slow, idles parked
		var st := "still"
		if engine_on:
			st = "drive" if speed_px > ROAD_PX * 0.5 else ("chill" if speed_px > 1.0 else "idle")
		var d := driver_frames()
		var frames: Array = d.get(st, [])
		if frames.is_empty():
			return
		if st != driver_state:
			driver_state = st
			_driver_i = 0
			_driver_t = 0.0
			driver.texture = frames[0]
		_driver_t += delta
		if _driver_t >= 1.0 / float(d.fps):
			_driver_t = 0.0
			_driver_i = (_driver_i + 1) % frames.size()
			driver.texture = frames[_driver_i]


## MV-741: the lantern as its own sprite hanging from `lamp` (pivot = the top of its bail): one texture per PixelLab
## flicker frame (the frame's colours on the glass pixels lantern_px). Without lantern_still in anim.json only the
## glass is drawn over the shell and nothing swings.
func _build_flame(f: Dictionary, origin: Vector2) -> void:
	flame_frames.clear()
	_flame_i = 0
	lamp_angle = 0.0
	_lamp_vel = 0.0
	if not f.has("lantern_px") or (f.lantern_px as Array).is_empty():
		return
	var at := Vector2i.ZERO
	var base: Image
	if f.has("lantern_still") and _lamp_src.has(dir + unit + str(floors)):
		var lr: Array = f.lantern_still
		at = Vector2i(int(lr[0]), int(lr[1]))
		base = _lamp_src[dir + unit + str(floors)]
	else:
		var lo := Vector2i(100000, 100000)
		var hi := Vector2i(-1, -1)
		for q in f.lantern_px:
			lo = Vector2i(mini(lo.x, int(q[0])), mini(lo.y, int(q[1])))
			hi = Vector2i(maxi(hi.x, int(q[0])), maxi(hi.y, int(q[1])))
		at = lo
		base = Image.create_empty(hi.x - lo.x + 1, hi.y - lo.y + 1, false, Image.FORMAT_RGBA8)
	for cols in f.lantern_frames:
		var img := base.duplicate() as Image
		var k := 0
		for q in f.lantern_px:
			img.set_pixel(int(q[0]) - at.x, int(q[1]) - at.y, Color.html(str(cols[k])))
			k += 1
		flame_frames.append(ImageTexture.create_from_image(img))
	var pivot := Vector2(at) if not f.has("lantern_pivot") else _v(f.lantern_pivot)
	lamp = Node2D.new()
	lamp.name = "Lantern"
	lamp.position = origin + pivot
	over.add_child(lamp)
	over.move_child(lamp, 0)                   # under the additive glows
	flame = Sprite2D.new()
	flame.name = "LanternFlame"
	flame.centered = false
	flame.position = Vector2(at) - pivot
	flame.texture = flame_frames[0]
	lamp.add_child(flame)
	var g: Sprite2D = glows.get("lantern")
	if g:
		g.set_meta("arm", _v(f.lantern) - pivot)    # the glow rides with the glass
		g.set_meta("pivot", origin + pivot)


## MV-741: a pendulum on the bail: it leans back when the vehicle pulls away, forward when it brakes, rocks on the
## road (random kicks, more at speed + every bump) and settles parked
func _tick_lamp(delta: float, speed_px: float, accel: float) -> void:
	if lamp == null:
		return
	var sp := clampf(speed_px / ROAD_PX, 0.0, 1.5)
	var rest := clampf(accel * 1.2, -0.22, 0.22)               # accel > 0: the lantern lags east (negative angle)
	rest = -rest
	_lamp_kick_t -= delta
	if sp > 0.05 and _lamp_kick_t <= 0.0:
		_lamp_kick_t = randf_range(0.35, 0.9)
		_lamp_vel += randf_range(-0.7, 0.7) * sp
	_lamp_vel += (-LAMP_W * LAMP_W * (lamp_angle - rest) - LAMP_DAMP * _lamp_vel) * delta
	lamp_angle = clampf(lamp_angle + _lamp_vel * delta, -0.35, 0.35)
	lamp.rotation = lamp_angle
	var g: Sprite2D = glows.get("lantern")
	if g and g.has_meta("arm"):
		g.position = (g.get_meta("pivot") as Vector2) + (g.get_meta("arm") as Vector2).rotated(lamp_angle)


func flame_frame() -> int:
	return _flame_i


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
	for n in [under, over, behind]:
		if is_instance_valid(n):
			n.queue_free()
	under = null
	over = null
	behind = null
	legs.clear()
	tyres.clear()
	swings.clear()
	sign_lit = null
	sign_dead = null
	flag = null
	lamp = null
	flame = null
	flame_frames.clear()
	clips.clear()
	clip_i.clear()
	glint = null
	driver = null
	driver_state = ""
	puffs.clear()
	pipe_at = Vector2.ZERO
	hops.clear()
	hop_left.clear()
	glows.clear()
	floors = 0


func set_visible(on: bool) -> void:
	for n in [under, over, behind]:
		if is_instance_valid(n):
			n.visible = on


func _lamp(id: String, a: float) -> void:
	var g: Sprite2D = glows.get(id)
	if g:
		g.modulate.a = clampf(a, 0.0, 1.0)
		g.visible = a > 0.01


## a road bump under the front axle now: the tyres hop over it one after another at the road speed (`lead` = world px
## from the convoy's front axle to this unit's first tyre: a trailer takes the bump later)
func bump(speed_px: float, lead := 0.0) -> void:
	if tyres.is_empty() or speed_px < 1.0:
		return
	_swing_kick = 1.4
	var x0 := tyres[0].position.x
	for i in tyres.size():
		var d := (tyres[i].position.x - x0) * under.scale.x + lead     # world px behind the front axle
		hops[i] = d / speed_px
		hop_left[i] = 0.0
	_lamp_vel += (0.9 if randf() < 0.5 else -0.9)     # MV-741: a bump rocks the lantern


## per frame. speed_px = road speed (world px/s), accel in speed-factor/s, body_y = the body's bounce (world px)
func tick(delta: float, speed_px: float, accel: float, engine_on: bool, night: float, body_y: float, alert: bool, hazard: bool) -> void:
	if under == null:
		return
	_t += delta
	var moving := speed_px > 1.0
	# tyres roll: angle = distance / radius (in shell px: the strip is drawn at shell scale)
	var r: float = spot(floors, dir, unit).get("wheel_r", 22.5)
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
	_tick_lamp(delta, speed_px, accel)
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
		if flame_frames.is_empty():
			_lantern = randf_range(0.7, 1.0)
		else:                                  # MV-741: next flame frame; the glow follows that frame's brightness
			_flame_i = (_flame_i + 1) % flame_frames.size()
			flame.texture = flame_frames[_flame_i]
			_lantern = float((spot(floors, dir).get("lantern_glow", []) as Array)[_flame_i])
	# MV-741: the lantern is always lit: a faint warm glow by day, full after dark
	_lamp("lantern", (0.15 + 0.7 * dark) * _lantern if not flame_frames.is_empty() else dark * 0.8 * _lantern)
	_lamp("mast", 0.9 if fmod(_t, 1.6) < 0.22 else 0.0)
	_lamp("beam", dark * 0.5 if engine_on else 0.0)
	for i in 8:
		if not glows.has("roof%d" % i):
			break
		_lamp("roof%d" % i, dark * 0.7 if engine_on or force_brake else 0.0)
	_tick_sign(delta, engine_on, dark, hazard)
	_tick_legs(delta, moving)
	_tick_swing(delta, speed_px, engine_on)
	_tick_roof(delta, speed_px, engine_on, accel, dark)
	# flag: a slow breeze parked, snapping in the headwind when driving
	if flag == null:
		return
	_flag_t -= delta
	if _flag_t <= 0.0:
		_flag_t = 1.0 / (4.0 + 10.0 * clampf(speed_px / ROAD_PX, 0.0, 1.2))
		_flag_i = (_flag_i + 1) % (_flag_frames[dir + unit + str(floors)] as Array).size()
		flag.texture = (_flag_frames[dir + unit + str(floors)] as Array)[_flag_i]


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


## loose cables sway: a lazy swing parked with the engine idling, more on the road, a kick at every bump
func _tick_swing(delta: float, speed_px: float, engine_on: bool) -> void:
	if swings.is_empty():
		return
	var sp := clampf(speed_px / ROAD_PX, 0.0, 1.5)
	_swing_ph += delta * (2.2 + 2.5 * sp)
	_swing_kick = move_toward(_swing_kick, 0.0, delta * 1.5)
	var amp := (0.5 if engine_on else 0.25) + 0.9 * sp + _swing_kick
	var sv := clampf(amp * sin(_swing_ph), -2.0, 2.0)
	var fi := clampi(int(round((sv + 2.0) / 4.0 * float(SWING_STEPS - 1))), 0, SWING_STEPS - 1)
	for s in swings:
		s.texture = (_swing_frames[dir + unit + str(floors)][int(s.get_meta("i"))] as Array)[fi]


func swing_frame() -> int:
	if swings.is_empty():
		return -1
	return (_swing_frames[dir + unit + str(floors)][0] as Array).find(swings[0].texture)


func sign_alpha() -> float:
	return sign_lit.modulate.a if sign_lit and sign_lit.visible else 0.0


func lamp_alpha(id: String) -> float:
	var g: Sprite2D = glows.get(id)
	return g.modulate.a if g and g.visible else 0.0


func flag_frame() -> int:
	return _flag_i


func spin_frame() -> int:
	return int(spin_angle / TAU * float(spin_frames(dir).size())) % spin_frames(dir).size()


## road train landing legs: crank up as soon as the rig rolls, crank back down once it has stood still a moment;
## whole pixels only, a crank handle turns in steps
func _tick_legs(delta: float, moving: bool) -> void:
	if legs.is_empty():
		return
	_stopped_t = 0.0 if moving else _stopped_t + delta
	var want := 1.0 if _stopped_t >= LEG_DOWN_AFTER else 0.0
	leg_down = move_toward(leg_down, want, delta / LEG_CRANK)
	for leg in legs:
		leg.position.y = float(leg.get_meta("y0")) - roundf(LEG_LIFT * (1.0 - leg_down))


func legs_down() -> float:
	return leg_down if not legs.is_empty() else -1.0

