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

const DIR := "res://assets/vehicles/ambulance_v3/"
const ROAD_PX := 90.0              # world px/s at speed factor 1 (= Background.ROAD_PX_PER_SEC)
const BLINK := 0.36                # s per indicator half-cycle
const SIGNAL_SEC := 2.9            # indicator time after pulling out / before stopping
const BEACON_CYCLE := 0.9          # roof bar: L flash flash, R flash flash
const FLAG_FRAMES := 8
const WELL := Color("141214")
const LAMP_W := 4.6                # lantern pendulum: rad/s natural frequency
const LAMP_DAMP := 1.1             # 1/s
const GLINT_FRAMES := 12
const PUFF_LIFE := 1.8             # s
const PUFF_MAX := 7
const DRIVER_AT := Vector2(87, 139)  # cab glass: x, shell height - y (driver.py)      # dark wheel well behind each tyre (rides with the body)

static var _meta: Dictionary = {}
static var _shells: Dictionary = {}        # floors -> ImageTexture (tyres + flag cloth cut out)
static var _flag_frames: Dictionary = {}   # floors -> Array[ImageTexture]
static var _spin: Array[AtlasTexture] = []
static var _glow_tex: GradientTexture2D
static var _lamp_src: Dictionary = {}      # floors -> Image of the lantern cut out of the shell (lantern_still rect)
static var _clips: Dictionary = {}         # floors -> {clip: {"at": Vector2i, "frames": Array[AtlasTexture]}} (MV-741 PixelLab roof)
static var _glints: Dictionary = {}        # floors -> {"at": Vector2i, "frames": Array[ImageTexture]} (MV-741 solar glint)
static var _driver: Dictionary = {}        # state -> Array[AtlasTexture] (MV-741 Dr. Ren at the wheel)
static var _puff_tex: Array[ImageTexture] = []

var vehicle: Node2D
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
var flame: Sprite2D                # MV-741: the whole lantern, cut from the shell, with the PixelLab flame flicker
var flame_frames: Array[ImageTexture] = []
var _flame_i := 0
var lamp: Node2D                   # MV-741: pivot at the lantern's bail: it swings while the vehicle moves
var lamp_angle := 0.0              # radians, + = the lantern swings forward (west, the way the cab faces)
var _lamp_vel := 0.0
var _lamp_kick_t := 0.0
## GOD MODE / autotest overrides
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
var force_beacon := false
var force_brake := false


static func meta() -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists(DIR + "anim.json"):
		_meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "anim.json"))
	return _meta


static func spot(n: int) -> Dictionary:
	return (meta().get("floors", {}) as Dictionary).get(str(n), {})


## the anchors are there and match the shell size (rerun tools/ambulance_anim.py after a shell rebuild)
static func ok(n: int) -> bool:
	var f := spot(n)
	if f.is_empty() or not ResourceLoader.exists(DIR + "wheel_spin.png") or not ResourceLoader.exists(DIR + "shell_f%d.png" % n):
		return false
	var tex: Texture2D = load(DIR + "shell_f%d.png" % n)
	return tex.get_size() == Vector2(f.size[0], f.size[1])


## the shell with the tyres and the flag cloth cut out (they are drawn by this class)
static func cut_shell(n: int) -> Texture2D:
	if _shells.has(n):
		return _shells[n]
	var f := spot(n)
	var img: Image = (load(DIR + "shell_f%d.png" % n) as Texture2D).get_image()
	img.decompress()
	var r: float = f.wheel_r
	for w in f.wheels:
		var c := Vector2(w[0], w[1])
		for y in range(int(c.y - r) - 1, int(c.y + r) + 2):
			for x in range(int(c.x - r) - 1, int(c.x + r) + 2):
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() \
						and Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
	if f.has("lantern_still"):                 # MV-741: the lantern swings on its own sprite
		var lr: Array = f.lantern_still
		var rect := Rect2i(int(lr[0]), int(lr[1]), int(lr[2]), int(lr[3]))
		_lamp_src[n] = img.get_region(rect)
		img.fill_rect(rect, Color(0, 0, 0, 0))
	_clips[n] = _cut_clips(img, f)             # MV-741: PixelLab roof parts animate on their own sprites
	if f.has("solar_px"):
		_glints[n] = _glint_frames(f.solar_px)
	if (_clips[n] as Dictionary).has("flag"):
		_flag_frames[n] = (_clips[n] as Dictionary).flag.frames
		(_clips[n] as Dictionary).erase("flag")
	else:
		var fr: Array = f.flag
		var cloth := img.get_region(Rect2i(fr[0], fr[1], fr[2], fr[3]))
		img.fill_rect(Rect2i(fr[0], fr[1], fr[2], fr[3]), Color(0, 0, 0, 0))
		_flag_frames[n] = _wave_frames(cloth)
	_shells[n] = ImageTexture.create_from_image(img)
	return _shells[n]


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


## MV-741 round 3: every clip in anim.json (roof_<clip>.png strips from tools/art/ambulance/roof, PixelLab
## animate-with-text-v3 over the Pro inpaint-v3 parts): its frame 0 is baked into the shell, so those pixels are cut out
## of `img` and the clip's sprite draws them. {clip: {"at": Vector2i, "frames": Array[AtlasTexture]}}
static func _cut_clips(img: Image, f: Dictionary) -> Dictionary:
	var out := {}
	for c in (f.get("clips", {}) as Dictionary):
		if not ResourceLoader.exists(DIR + "roof_%s.png" % c):
			continue
		var r: Array = f.clips[c].rect
		var at := Vector2i(int(r[0]), int(r[1]))
		var sz := Vector2i(int(r[2]), int(r[3]))
		var strip: Texture2D = load(DIR + "roof_%s.png" % c)
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


static func spin_frames() -> Array[AtlasTexture]:
	if _spin.is_empty():
		var strip: Texture2D = load(DIR + "wheel_spin.png")
		var s: int = int(meta().get("wheel_size", 47))
		for i in int(meta().get("spin_frames", 24)):
			var a := AtlasTexture.new()
			a.atlas = strip
			a.region = Rect2(s * i, 0, s, s)
			_spin.append(a)
	return _spin


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
func build(n: int, origin: Vector2, under_parent: Node2D, over_parent: Node2D, k: float) -> void:
	clear()
	floors = n
	var f := spot(n)
	under = Node2D.new()
	under.name = "AmbulanceWheels"
	under.scale = Vector2.ONE * k
	under_parent.add_child(under)
	wells = Node2D.new()
	under.add_child(wells)
	var s: int = int(meta().get("wheel_size", 47))
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
		t.texture = spin_frames()[0]
		t.position = c - Vector2(s, s) * 0.5
		t.set_meta("y0", t.position.y)
		under.add_child(t)
		tyres.append(t)
		hops.append(-1.0)
		hop_left.append(0.0)
	over = Node2D.new()
	over.name = "AmbulanceLights"
	over_parent.add_child(over)
	var fr: Array = f.flag
	flag = Sprite2D.new()
	flag.centered = false
	flag.position = origin + Vector2(fr[0], fr[1] - (0 if spot(n).has("clips") and (spot(n).clips as Dictionary).has("flag") else 2))
	over.add_child(flag)
	cut_shell(n)
	flag.texture = (_flag_frames[n] as Array)[0]
	_glow("head", origin + _v(f.head), 9.0, Color(1.0, 0.86, 0.55))
	_glow("marker", origin + _v(f.marker), 7.0, Color(1.0, 0.6, 0.15))
	_glow("bar_l", origin + _v(f.bar_l), 11.0, Color(1.0, 0.12, 0.1))
	_glow("bar_r", origin + _v(f.bar_r), 11.0, Color(1.0, 0.12, 0.1))
	_glow("lantern", origin + _v(f.lantern), 12.0, Color(1.0, 0.7, 0.3))
	_build_flame(f, origin)
	_build_roof(f, origin)
	_glow("mast", origin + _v(f.mast), 5.0, Color(1.0, 0.25, 0.2))
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
	for c in (_clips.get(floors, {}) as Dictionary):
		var cs := Sprite2D.new()
		cs.name = "Roof_" + str(c)
		cs.centered = false
		cs.position = origin + Vector2(_clips[floors][c].at)
		cs.texture = (_clips[floors][c].frames as Array)[0]
		over.add_child(cs)
		over.move_child(cs, 0)
		clips[c] = cs
		clip_i[c] = 0
		_clip_t[c] = randf_range(0.0, 0.3)
	if _glints.has(floors):
		glint = Sprite2D.new()
		glint.name = "SolarGlint"
		glint.centered = false
		glint.position = origin + Vector2(_glints[floors].at)
		glint.visible = false
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glint.material = m
		over.add_child(glint)
	if f.get("pipe") != null:
		pipe_at = origin + _v(f.pipe)
	var d := driver_frames()
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
		var fs: Array = _clips[floors][c].frames
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
				glint.texture = (_glints[floors].frames as Array)[i]
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
	if f.has("lantern_still") and _lamp_src.has(floors):
		var lr: Array = f.lantern_still
		at = Vector2i(int(lr[0]), int(lr[1]))
		base = _lamp_src[floors]
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


func _glow(id: String, at: Vector2, radius: float, col: Color) -> void:
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


func clear() -> void:
	for n in [under, over]:
		if is_instance_valid(n):
			n.queue_free()
	under = null
	over = null
	tyres.clear()
	hops.clear()
	hop_left.clear()
	glows.clear()
	lamp = null
	flame = null
	clips.clear()
	clip_i.clear()
	glint = null
	driver = null
	driver_state = ""
	puffs.clear()
	pipe_at = Vector2.ZERO
	flame_frames.clear()
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
	_lamp_vel += (0.9 if randf() < 0.5 else -0.9)     # MV-741: a bump rocks the lantern


## per frame. speed_px = road speed (world px/s), accel in speed-factor/s, body_y = the body's bounce (world px)
func tick(delta: float, speed_px: float, accel: float, engine_on: bool, night: float, body_y: float, alert: bool, hazard: bool) -> void:
	if under == null:
		return
	_t += delta
	var moving := speed_px > 1.0
	# tyres roll: angle = distance / radius (in shell px: the strip is drawn at shell scale)
	var r: float = spot(floors).get("wheel_r", 22.5)
	spin_angle = fposmod(spin_angle + speed_px / under.scale.x / r * delta, TAU)
	var n := spin_frames().size()
	var fi := int(spin_angle / TAU * float(n)) % n
	for i in tyres.size():
		var t := tyres[i]
		t.texture = _spin[fi]
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
			_lantern = float((spot(floors).get("lantern_glow", []) as Array)[_flame_i])
	# MV-741: the lantern is always lit: a faint warm glow by day, full after dark
	_lamp("lantern", (0.15 + 0.7 * dark) * _lantern if not flame_frames.is_empty() else dark * 0.8 * _lantern)
	_lamp("mast", 0.9 if fmod(_t, 1.6) < 0.22 else 0.0)
	_tick_roof(delta, speed_px, engine_on, accel, dark)
	# flag: a slow breeze parked, snapping in the headwind when driving
	_flag_t -= delta
	if _flag_t <= 0.0:
		_flag_t = 1.0 / (4.0 + 10.0 * clampf(speed_px / ROAD_PX, 0.0, 1.2))
		_flag_i = (_flag_i + 1) % (_flag_frames[floors] as Array).size()
		flag.texture = (_flag_frames[floors] as Array)[_flag_i]


func lamp_alpha(id: String) -> float:
	var g: Sprite2D = glows.get(id)
	return g.modulate.a if g and g.visible else 0.0


func flag_frame() -> int:
	return _flag_i


func spin_frame() -> int:
	return int(spin_angle / TAU * float(spin_frames().size())) % spin_frames().size()
