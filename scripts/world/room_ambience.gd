class_name RoomAmbience
extends Node2D
## Room lighting + micro animation (MV-167): a warm light pool under every ceiling lamp that breathes and
## sometimes flickers (the bulb blinks, the room dips dark), plus small loops drawn on the room art: steam
## from the kitchen pot, bubbles in the water tank and the lab flask, an ECG on the medical monitor, radio
## LEDs, gauge needles, furnace fire, the workshop wheel, drips and dust in the lamp light. The cab engine
## bay gets the same treatment from its engine state (run = rocker covers tick, hot = glow, broken = sparks).
## Drawn on the 1 px grid at ~12 fps (redraw only when the frame changes), off with Features "room_ambience".
## All positions are room-local pixels of the 64x52 PixelLab room art (tools/art/pixellab/overrides).

const GROUP := "room_ambience"
const FPS := 12.0
## flickers per lamp per minute (Features tune "ambience.flicker")
const FLICKER_PM := 0.6
const WARM := Color(1.0, 0.82, 0.5)
## ceiling lamp per room type (the bulb's centre); default = the middle of the ceiling
const LAMPS := {"engine": Vector2(24, 7), "refinery": Vector2(29, 9), "default": Vector2(32, 7)}
## cab engine bays: lamp, engine block top (x, y, w), gauge centre, status LED
const CAB := {
	"van": {"lamp": Vector2(10, 2), "block": [9, 33, 14], "gauge": Vector2(26, 9), "led": Vector2(26, 13)},
	"bus": {"lamp": Vector2(10, 2), "block": [9, 19, 15], "gauge": Vector2(26, 9), "led": Vector2(26, 13)},
	"rig": {"lamp": Vector2(10, 2), "block": [8, 15, 16], "gauge": Vector2(26, 9), "led": Vector2(26, 13)},
	"train": {"lamp": Vector2(10, 2), "block": [8, 37, 20], "gauge": Vector2(30, 9), "led": Vector2(30, 13)},
}
const ECG := [0, 0, 0, -1, -3, 2, 0, 0]

static var _pool_tex: Texture2D
static var _add_mat: CanvasItemMaterial

var kind := ""           # room type, or "cab_<tier>"
var cab_state := "idle"  # cab only: idle / run / hot / broken
var night := 0.0         # 0 day .. 1 deep night (stronger light pools)
var flicker_left := 0.0
var _lamp := Vector2(32, 7)
var _pool: Sprite2D
var _fx: Node2D
var _t := 0.0
var _frame := -1
var _rng := RandomNumberGenerator.new()
var _dip := false
var _motes: Array = []
var _sparks: Array = []   # {p, v, t}


func _ready() -> void:
	add_to_group(GROUP)
	if _pool_tex == null:
		_pool_tex = _make_pool()
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_pool = Sprite2D.new()
	_pool.centered = false
	_pool.texture = _pool_tex
	_pool.material = _add_mat
	add_child(_pool)
	_fx = Node2D.new()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_rng.seed = hash(get_path())
	if kind != "":
		var k := kind
		kind = ""
		setup(k)


## kind = room type ("kitchen") or "cab_<tier>"; call again when the room changes type
func setup(k: String) -> void:
	if k == kind:
		return
	kind = k
	if _pool == null:
		return      # not in the tree yet: _ready() finishes the setup
	if kind.begins_with("cab_"):
		_lamp = CAB.get(kind.trim_prefix("cab_"), CAB.van).lamp
	else:
		_lamp = LAMPS.get(kind, LAMPS.default)
	_pool.position = (_lamp - Vector2(_pool_tex.get_width() * 0.5, 0)).round()
	_motes.clear()
	for i in 4:
		_motes.append(Vector2(_lamp.x + _rng.randf_range(-12, 12), _lamp.y + _rng.randf_range(6, 30)))
	_sparks.clear()
	_frame = -1


## tester / Dev action: this lamp stutters for `sec`
func flicker(sec: float = 1.6) -> void:
	flicker_left = maxf(flicker_left, sec)


## how many animated parts this room has (autotest: every room type has something moving)
func fx_count() -> int:
	return _parts().size()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if flicker_left > 0.0:
		flicker_left -= delta
	elif _rng.randf() < Features.num("ambience.flicker", FLICKER_PM) / 60.0 * delta:
		flicker(_rng.randf_range(0.4, 1.2))
	var f := int(_t * FPS)
	if f == _frame:
		return
	_frame = f
	_dip = flicker_left > 0.0 and _rng.randf() < 0.55
	var breathe := 0.92 + 0.08 * sin(_t * 1.7)
	var a := (0.55 + 0.45 * night) * breathe * (0.15 if _dip else 1.0)
	if kind.begins_with("cab_") and cab_state == "broken":
		a *= 0.6
	_pool.modulate = Color(WARM.r * a, WARM.g * a, WARM.b * a, 1.0)
	_step(1.0 / FPS)
	_fx.queue_redraw()


func _step(dt: float) -> void:
	for i in _motes.size():
		var m: Vector2 = _motes[i]
		m += Vector2(sin(_t * 0.7 + i * 2.1) * 0.6, -1.0) * dt * 2.0
		if m.y < _lamp.y + 3:
			m = Vector2(_lamp.x + _rng.randf_range(-12, 12), _lamp.y + 30)
		_motes[i] = m
	for i in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		s.t = float(s.t) - dt
		s.v = (s.v as Vector2) + Vector2(0, 40) * dt
		s.p = (s.p as Vector2) + (s.v as Vector2) * dt
		if float(s.t) <= 0.0:
			_sparks.remove_at(i)
	var spark_at := Vector2.ZERO
	if kind == "workshop" and _rng.randf() < 0.05:
		spark_at = Vector2(22, 30)
	elif kind.begins_with("cab_") and cab_state == "broken" and _rng.randf() < 0.12:
		var b: Array = CAB.get(kind.trim_prefix("cab_"), CAB.van).block
		spark_at = Vector2(float(b[0]) + _rng.randf_range(0, float(b[2])), float(b[1]))
	if spark_at != Vector2.ZERO:
		for k in _rng.randi_range(3, 5):
			_sparks.append({"p": spark_at, "v": Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-22, -8)), "t": _rng.randf_range(0.2, 0.45)})


## the names of the animated parts of this room (lamp + dust everywhere)
func _parts() -> Array:
	var p := ["lamp", "dust"]
	match kind:
		"medical": p += ["ecg"]
		"quarters": p += ["clock"]
		"kitchen": p += ["steam", "stove"]
		"hydroponics": p += ["growlight", "drip"]
		"water": p += ["bubbles", "drip"]
		"armory": p += ["led"]
		"science": p += ["flask", "screen"]
		"radio": p += ["leds", "vu"]
		"engine": p += ["gauges", "warn", "puffs"]
		"refinery": p += ["fire", "gauges", "screen"]
		"workshop": p += ["wheel", "sparks"]
		_:
			if kind.begins_with("cab_"):
				p += ["gauge", "led", "rockers"]
	return p


# ------------------------------------------------------------------ drawing
func _px(x: float, y: float, c: Color, w: float = 1.0, h: float = 1.0) -> void:
	_fx.draw_rect(Rect2(floorf(x), floorf(y), w, h), c)


func _draw_fx() -> void:
	if _dip:
		# the bulb is out for a moment: the room drops dark and the bulb goes grey
		_fx.draw_rect(Rect2(0, 0, 64 if not kind.begins_with("cab_") else 40, 70), Color(0.02, 0.015, 0.03, 0.35))
		_px(_lamp.x - 1, _lamp.y - 1, Color(0.25, 0.22, 0.2), 2, 2)
	else:
		_px(_lamp.x - 1, _lamp.y - 1, Color(1, 0.95, 0.75, 0.55 + 0.25 * sin(_t * 9.0)), 2, 2)
		for m in _motes:
			_px(m.x, m.y, Color(1, 0.9, 0.7, 0.35))
	var t := _t
	match kind:
		"medical":
			# heartbeat trace sweeping the bedside monitor
			var off := int(t * 6.0)
			for i in 8:
				_px(40 + i, 27 + ECG[(i + off) % 8], Color(0.5, 1, 0.55, 1.0 if i == 7 else 0.6))
		"quarters":
			# alarm clock on the bedside locker: the colon blinks
			_px(53, 33, Color(1, 0.3, 0.2, 0.9), 1, 1)
			_px(56, 33, Color(1, 0.3, 0.2, 0.9), 1, 1)
			if int(t * 2.0) % 2 == 0:
				_px(55, 33, Color(1, 0.3, 0.2, 0.9))
		"kitchen":
			for i in 3:
				var ph := fmod(t * 0.6 + i / 3.0, 1.0)
				_px(9 + sin(ph * 6.0 + i) * 1.5, 23 - ph * 12, Color(0.85, 0.85, 0.8, 0.55 * (1.0 - ph)), 2 if ph < 0.5 else 1, 1)
			for x in range(18, 23):
				var hgt := 1 + int(abs(sin(t * 11.0 + x * 1.7)) * 2.0)
				_px(x, 30 - hgt, Color(1, 0.6 + 0.3 * sin(t * 7.0 + x), 0.15, 0.9), 1, hgt)
		"hydroponics":
			var g := 0.25 + 0.15 * sin(t * 2.2)
			_fx.draw_rect(Rect2(22, 16, 23, 1), Color(0.75, 1, 0.95, g + 0.25))
			_fx.draw_rect(Rect2(20, 17, 27, 3), Color(0.6, 1, 0.8, g * 0.35))
			_drip(Vector2(30, 19), 46.0, 2.3, 0.0)
			_drip(Vector2(51, 19), 46.0, 3.1, 1.2)
		"water":
			for i in 4:
				var ph := fmod(t * 0.45 + i * 0.27, 1.0)
				_px(12 + (i * 3) % 8 + sin(ph * 9.0 + i), 37 - ph * 19, Color(0.7, 0.9, 1, 0.75 * (1.0 - ph * 0.6)))
			_drip(Vector2(33, 22), 46.0, 1.9, 0.0)
		"armory":
			_px(47, 28, Color(1, 0.2, 0.15, 1.0 if int(t * 1.5) % 2 == 0 else 0.25))
		"science":
			for i in 3:
				var ph := fmod(t * 0.9 + i / 3.0, 1.0)
				_px(41 + (i % 2) * 2, 27 - ph * 7, Color(0.75, 1, 0.3, 0.9 * (1.0 - ph)))
			_px(40, 12, Color(0.7, 1, 0.3, 0.5 + 0.5 * sin(t * 3.0)), 2, 1)
			var sy := 11 + int(t * 8.0) % 13
			_fx.draw_rect(Rect2(11, sy, 18, 1), Color(0.55, 1, 0.55, 0.18))
			if int(t * 2.0) % 2 == 0:
				_px(14, 20, Color(0.6, 1, 0.6, 0.9), 2, 1)
		"radio":
			var leds := [Vector2(37, 18), Vector2(47, 24), Vector2(53, 18), Vector2(41, 18)]
			for i in leds.size():
				var on := int(t * (2.0 + i * 0.7) + i) % 3 != 0
				_px(leds[i].x, leds[i].y, Color(1, 0.65, 0.15, 1.0) if on else Color(0.35, 0.2, 0.05, 1.0))
			for i in 4:
				var lv := int(2.0 + 2.0 * sin(t * (5.0 + i * 1.3) + i * 2.0))
				_px(52 + i, 29 - lv, Color(0.5, 1, 0.5, 0.9), 1, lv)
		"engine":
			_needle(Vector2(29, 37), 0.4 + 0.15 * sin(t * 13.0))
			_needle(Vector2(40, 37), -0.3 + 0.1 * sin(t * 7.0 + 1.0))
			_px(12, 25, Color(1, 0.55, 0.1, 1.0 if int(t * 2.5) % 2 == 0 else 0.2), 2, 1)
			_puffs(Vector2(28, 13), t)
		"refinery":
			for x in range(9, 15):
				var hgt := 2 + int(abs(sin(t * 9.0 + x * 2.3)) * 3.0)
				_px(x, 48 - hgt, Color(1, 0.45 + 0.4 * abs(sin(t * 5.0 + x)), 0.1, 0.95), 1, hgt)
			_needle(Vector2(23, 22), 0.6 + 0.2 * sin(t * 4.0))
			_needle(Vector2(23, 36), -0.2 + 0.25 * sin(t * 2.5 + 2.0))
			_fx.draw_rect(Rect2(34, 27 + int(t * 6.0) % 16, 9, 1), Color(0.6, 1, 0.95, 0.4))
		"workshop":
			# the big wheel turns: a highlight runs around its rim
			for k in 2:
				var a := t * 2.4 + k * PI
				_px(46 + round(cos(a) * 5), 15 + round(sin(a) * 5), Color(0.85, 0.85, 0.8, 0.9))
				_px(46 + round(cos(a) * 3), 15 + round(sin(a) * 3), Color(0.6, 0.6, 0.6, 0.8))
		_:
			if kind.begins_with("cab_"):
				_draw_cab(t)
	for s in _sparks:
		_px((s.p as Vector2).x, (s.p as Vector2).y, Color(1, 0.85, 0.3, clampf(float(s.t) * 4.0, 0.0, 1.0)))


func _draw_cab(t: float) -> void:
	var c: Dictionary = CAB.get(kind.trim_prefix("cab_"), CAB.van)
	var b: Array = c.block
	var heat := clampf(EngineBay.heat() / 120.0, 0.0, 1.0) if not Game.s.is_empty() else 0.3
	var jitter := 0.08 * sin(t * 17.0) if cab_state == "run" or cab_state == "hot" else 0.0
	_needle(c.gauge, -1.2 + heat * 2.4 + jitter)
	var led := Color(0.6, 1, 0.3)
	if cab_state == "hot" or cab_state == "broken":
		led = Color(1, 0.25, 0.15) if int(t * 4.0) % 2 == 0 else Color(0.3, 0.05, 0.05)
	_px(c.led.x, c.led.y, led)
	if cab_state == "run" or cab_state == "hot":
		# rocker covers tick in firing order along the block top
		var n := int(b[2]) / 4
		for i in n:
			var up := (int(t * 14.0) + i * 3) % n == 0
			_px(float(b[0]) + 1 + i * 4, float(b[1]) - (2 if up else 1), Color(0.75, 0.72, 0.65, 0.9), 2, 1)
	if cab_state == "hot":
		var a := 0.18 + 0.1 * sin(t * 6.0)
		_fx.draw_rect(Rect2(float(b[0]), float(b[1]), float(b[2]), 8), Color(1, 0.35, 0.1, a))


func _needle(c: Vector2, ang: float) -> void:
	# a 3 px needle pointing up, rotated by ang (radians)
	for r in range(1, 3):
		_px(c.x + round(sin(ang) * r), c.y - round(cos(ang) * r), Color(0.95, 0.3, 0.2, 1.0))


func _drip(from: Vector2, floor_y: float, period: float, offset: float) -> void:
	var ph := fmod(_t + offset, period) / period
	var c := Color(0.65, 0.85, 1, 0.85)
	if ph < 0.55:
		if ph > 0.3:
			_px(from.x, from.y, c)
	elif ph < 0.85:
		var k := (ph - 0.55) / 0.3
		_px(from.x, from.y + (floor_y - from.y) * k * k, c, 1, 2)
	else:
		_px(from.x - 1, floor_y, Color(c.r, c.g, c.b, 0.6))
		_px(from.x + 1, floor_y, Color(c.r, c.g, c.b, 0.6))


func _puffs(at: Vector2, t: float) -> void:
	for i in 3:
		var ph := fmod(t * 0.5 + i / 3.0, 1.0)
		_px(at.x + i * 4 + sin(ph * 5.0) * 1.5, at.y - ph * 8, Color(0.6, 0.6, 0.6, 0.45 * (1.0 - ph)), 2, 1)


## the soft light pool under a lamp: 3 stepped bands with a checker dither between them (stays pixel art)
static func _make_pool() -> Texture2D:
	var w := 44
	var h := 40
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := (x + 0.5 - w * 0.5) / (w * 0.5)
			var dy := (y + 0.5) / float(h)
			var d := sqrt(dx * dx * (1.6 - dy) + dy * dy)
			var v := 0.0
			if d < 0.3:
				v = 0.26
			elif d < 0.36:
				v = 0.26 if (x + y) % 2 == 0 else 0.16
			elif d < 0.6:
				v = 0.16
			elif d < 0.68:
				v = 0.16 if (x + y) % 2 == 0 else 0.08
			elif d < 0.95:
				v = 0.08
			elif d < 1.0:
				v = 0.08 if (x + y) % 2 == 0 else 0.0
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)
