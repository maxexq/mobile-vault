class_name WeatherV2
extends Node2D
## MV-770 Weather v2 (switch weather_v2), ported from the approved preview page
## https://claude.ai/artifact/MbpYUNRcoCgZ5PqYeVoXP4 (picks 2026-11-11: rain/storm/acid/fog/snow/ash/overcast A, sandstorm D).
## Art: res://assets/weather/v2/<group>.png + sheets.json, baked from that page by
## designs/weather-v2/export/export.js (PixelLab lightning, fog banks, snow drifts, ash banks, sandstorm walls +
## debris loops; code-drawn snow flakes, hero crystals, ash flakes, charred scraps, overcast wisps, sun rays, cloud shadows).
## Three places draw:
##  - this node (inside WeatherFX, ABOVE the haze): hero snowflakes + big burning ash scraps
##  - `under` (inside WeatherFX, BELOW the haze): rain/storm/acid streaks, snow, ash + embers, sand stream + bits +
##    flying debris, front fog
##  - ParallaxV2Backdrop slots between the parallax strips (world space): sky darkening, ash/overcast clouds,
##    lightning bolts (sky), fog banks + sandstorm walls (far / mid), wet road, snow drifts, cloud shadows, sun rays.
## Coordinates follow the page: art px, the road at y 290, screen x 0 = camera left.

const DIR := "res://assets/weather/v2/"
const ROAD_Y := 290.0
const BASE_VH := 260.0        # height of the preview view the densities were tuned on
const NORMAL_SPEED := 90.0    # Background.ROAD_PX_PER_SEC = speed factor 1
const SANDC := [Color8(232, 178, 108), Color8(214, 150, 84), Color8(190, 128, 70), Color8(246, 206, 150), Color8(160, 104, 58), Color8(120, 82, 50)]
const DARK := {"storm": 0.55, "rain": 0.35, "acid_rain": 0.35, "overcast": 0.25}

static var inst: WeatherV2
static var _sheets: Dictionary = {}
static var _fog_tex: Dictionary = {}     # "banks"/"float" -> Array[ImageTexture] (one per bank, for the wave shader)
static var _fog_mat: ShaderMaterial
static var _add_mat: CanvasItemMaterial

var weather := "clear"
var t := 0.0
var off := 0.0               # road scroll in px (moves with the road)
var spd := 1.0               # road speed / normal speed
var slant := 0.2
var tint := Color.WHITE      # screen layers: night darkening + close-up fade (alpha)
var night := 0.0
var vw := 360.0
var vh := 640.0
var under: Node2D
var front_fog_mat: ShaderMaterial
var bolt := {}
var _deb_live: Array = []
var _deb_next := 2.0
var _deb_bag: Array = []
var _hch_live: Array = []
var _hch_next := 2.5
var _hch_bag: Array = []
var _rng := RandomNumberGenerator.new()
var _tables: Dictionary = {}
var _tables_key := ""


static func load_sheets() -> void:
	if not _sheets.is_empty():
		return
	var f := FileAccess.open(DIR + "sheets.json", FileAccess.READ)
	if f == null:
		return
	var meta: Dictionary = JSON.parse_string(f.get_as_text())
	for k in meta:
		var g: Dictionary = meta[k]
		var items: Array = []
		for it in g.items:
			var frames: Array[Rect2] = []
			for r in it:
				frames.append(Rect2(r[0], r[1], r[2], r[3]))
			items.append(frames)
		_sheets[k] = {"tex": load(DIR + k + ".png"), "k": float(g.k), "items": items, "classes": g.get("classes", [])}
	for k in ["banks", "float"]:
		var list: Array[ImageTexture] = []
		var s: Dictionary = _sheets.get("fog_" + k, {})
		if not s.is_empty():
			var img: Image = (s.tex as Texture2D).get_image()
			for it in s.items:
				list.append(ImageTexture.create_from_image(img.get_region(Rect2i(it[0]))))
		_fog_tex[k] = list
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = preload("res://shaders/weather_fog_wave.gdshader")
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


static func active() -> bool:
	return inst != null and is_instance_valid(inst) and Features.on("weather_v2")


static func sheet_count(group: String) -> int:
	load_sheets()
	return (_sheets.get(group, {}).get("items", []) as Array).size()


func _ready() -> void:
	load_sheets()
	inst = self
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	under = Node2D.new()
	under.name = "WeatherV2Under"
	under.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	under.draw.connect(_draw_under)
	front_fog_mat = _fog_mat.duplicate() as ShaderMaterial


func _exit_tree() -> void:
	if inst == self:
		inst = null


func set_weather(w: String) -> void:
	if w == weather:
		return
	weather = w
	bolt = {}
	_deb_live.clear()
	_hch_live.clear()
	under.material = front_fog_mat if w == "fog" else null


## called by WeatherFX every frame: road speed (px/s), viewport size, screen tint
func step(delta: float, road_speed: float, size: Vector2, screen_tint: Color, night_k: float) -> void:
	t = fmod(t + delta, 3600.0)
	spd = road_speed / NORMAL_SPEED
	off = fmod(off + road_speed * delta, 100000.0)
	vw = size.x
	vh = size.y
	tint = screen_tint
	night = night_k
	front_fog_mat.set_shader_parameter("tint", Color(tint.r, tint.g, tint.b, tint.a))
	var wind := 0.08 if weather == "storm" else 0.04
	slant += (wind + 0.26 * spd - slant) * (1.0 - pow(0.96, delta * 60.0))
	if not bolt.is_empty():
		bolt.t = float(bolt.t) + delta
		if float(bolt.t) > 0.6:
			bolt = {}
	if weather == "sandstorm":
		_step_debris(delta)
	if weather == "ashfall":
		_step_hero_ash(delta)
	queue_redraw()
	under.queue_redraw()


## a lightning bolt from the PixelLab sheet behind the scene (WeatherFX owns the timer and the white flash)
func strike() -> void:
	var n := sheet_count("lightning")
	if n == 0:
		return
	bolt = {"i": _rng.randi() % n, "x": 30.0 + _rng.randf() * (vw - 90.0), "t": 0.0}


# =================================================================== helpers
func _r(n: float) -> float:
	var x := sin(n * 127.1 + 311.7) * 43758.5453
	return x - floorf(x)


func _density() -> float:
	return Features.num("weather_v2.density", 1.0) * clampf(vh / BASE_VH, 1.0, 2.6)


## draw one sheet frame at art position p (scale = extra size multiplier on top of the sheet's own k)
func _item(n: CanvasItem, group: String, i: int, frame: int, p: Vector2, a: float, scale: float = 1.0, col: Color = Color.WHITE) -> Vector2:
	var s: Dictionary = _sheets.get(group, {})
	if s.is_empty():
		return Vector2.ZERO
	var frames: Array = s.items[i % s.items.size()]
	var src: Rect2 = frames[clampi(frame, 0, frames.size() - 1)]
	var size := src.size * float(s.k) * scale
	n.draw_texture_rect_region(s.tex, Rect2(p.round(), size), src, Color(col.r, col.g, col.b, a * col.a))
	return size


func _size(group: String, i: int) -> Vector2:
	var s: Dictionary = _sheets.get(group, {})
	if s.is_empty():
		return Vector2.ZERO
	var frames: Array = s.items[i % s.items.size()]
	return (frames[0] as Rect2).size * float(s.k)


## ping-pong frame of a looping clip (the PixelLab loops have no seam)
func _pp(nframes: int, i: int, fps: float) -> int:
	if nframes < 2:
		return 0
	var per := 2 * nframes - 2
	var k := int(floorf(t * fps + i * 3.7)) % per
	return per - k if k >= nframes else k


func _cam(n: CanvasItem) -> Rect2:
	var vp := n.get_viewport()
	var camera := vp.get_camera_2d()
	var extent := vp.get_visible_rect().size
	var center := Vector2(140, 150)
	if camera:
		extent /= camera.zoom
		center = camera.get_screen_center_position()
	return Rect2(center - extent * 0.5, extent)


## world y -> screen y for the screen layers
func _sy(wy: float) -> float:
	var ct := get_viewport().get_canvas_transform()
	return (ct * Vector2(0, wy)).y


# =================================================================== world slots (ParallaxV2Backdrop)
static func draw_slot(n: Node2D, key: String) -> void:
	if not active():
		return
	inst._slot(n, key)


func _slot(n: Node2D, key: String) -> void:
	var cam := _cam(n)
	var x0 := cam.position.x
	var w := weather
	var fog_slot := w == "fog" and key in ["sky", "far", "mid"]
	if fog_slot and n.material != _fog_mat:
		n.material = _fog_mat
	elif not fog_slot and key != "rays" and n.material != null:
		n.material = null
	match key:
		"sky":
			var dk: float = DARK.get(w, 0.0)
			if dk > 0.0:
				n.draw_rect(Rect2(x0, cam.position.y - 10.0, cam.size.x, 240.0 - cam.position.y), Color8(40, 46, 58, int(dk * 255)))
			# the game shows far more sky than the preview (tall phones), so every sky weather gets a higher band too
			if w == "ashfall":
				_banks(n, x0, "ash_banks", 20.0, 3.0, 0.7, false, 7.0)
				_banks(n, x0, "ash_banks", 118.0, 4.0, 0.95, false)
			elif w == "fog":
				_fog_banks(n, x0, "float", 70.0, 4.0, 0.25, 11.0)
				_fog_banks(n, x0, "float", 150.0, 5.0, 0.38, 5.0)
			elif w == "sandstorm":
				_anim_banks(n, x0, 196.0, 22.0, 0.35, 2.0, 9.0)
			if w == "storm" and not bolt.is_empty():
				var bt := float(bolt.t)
				if bt < 0.06 or (bt > 0.12 and bt < 0.2):
					var sz := _size("lightning", int(bolt.i))
					var sc := maxf(1.0, floorf(150.0 / maxf(1.0, sz.y)))
					_item(n, "lightning", int(bolt.i), 0, Vector2(x0 + float(bolt.x), 250.0 - sz.y * sc), 1.0, sc)
			if w == "overcast":
				_oc_layer(n, x0, "oc_wisp", 2, 7, -110.0, 1.5, 0.008, 0.35, 110.0)
				_oc_layer(n, x0, "oc_wisp", 0, 5, 10.0, 2.0, 0.01, 0.4, 100.0)
				_oc_layer(n, x0, "oc_wisp", 3, 8, 116.0, 3.5, 0.03, 0.55, 44.0)
		"far":
			if w == "fog":
				_fog_banks(n, x0, "float", 205.0, 7.0, 0.55)
			elif w == "sandstorm":
				_anim_banks(n, x0, 236.0, 30.0, 0.5, 2.0, 2.0)
			elif w == "overcast":
				_oc_layer(n, x0, "oc_lo", 0, 5, 158.0, 6.0, 0.06, 0.45, 22.0)
		"mid":
			if w == "fog":
				_fog_banks(n, x0, "float", 250.0, 12.0, 0.7)
			elif w == "sandstorm":
				_anim_banks(n, x0, 276.0, 55.0, 0.55, 2.0, 5.0)
		"ground":
			if w in ["rain", "storm"]:
				var span := cam.size.x + 60.0
				for i in 26:
					var y := ROAD_Y + 8.0 + _r(i * 2.2) * 60.0
					var ww := 6.0 + _r(i * 5.5) * 22.0
					var x := fmod(off + _r(i * 3.9) * span, span) - 30.0 - ww
					n.draw_rect(Rect2(roundf(x0 + x), roundf(y), roundf(ww), 1), Color8(190, 210, 228, 56))
			elif w == "snow":
				var span := cam.size.x + 200.0
				for i in sheet_count("snow_drifts"):
					var sz := _size("snow_drifts", i)
					var x := fmod(off + i * 180.0, span) - 100.0 - sz.x
					_item(n, "snow_drifts", i, 0, Vector2(x0 + x, ROAD_Y + 8.0 - sz.y), 1.0)
			elif w == "overcast":
				var span := cam.size.x + 700.0
				for i in sheet_count("shadows"):
					var sz := _size("shadows", i)
					var x := fmod(t * 5.0 + off * 0.35 + i * span / 2.0, span + sz.x) - sz.x - 200.0
					_item(n, "shadows", i, 0, Vector2(x0 + x, 196.0), 0.34)
		"rays":
			if n.material != _add_mat:
				n.material = _add_mat
			if w == "overcast" and night < 0.6:
				_sun_rays(n, x0)


## PixelLab cloud/ash banks: drift with the wind, a little with the road
func _banks(n: CanvasItem, x0: float, group: String, y0: float, speed: float, alpha: float, bottom: bool, seed: float = 0.0) -> void:
	var span := vw + 260.0
	for i in sheet_count(group):
		var sz := _size(group, i)
		var sp := speed * (0.8 + _r(i * 3.1 + seed) * 0.5)
		var x := fmod(t * sp + off * 0.05 + _r(i * 9.7 + seed) * span, span + sz.x) - sz.x - 60.0
		var y := y0 - sz.y + _r(i * 4.3 + seed) * 10.0 if bottom else y0 + _r(i * 4.3 + seed) * 26.0 - (sz.y - 40.0 if sz.y > 40.0 else 0.0)
		_item(n, group, i, 0, Vector2(x0 + x, y), alpha)


## fog banks with the wave shader: each bank twice (main + faint copy drifting against it), swaying and breathing
func _fog_banks(n: CanvasItem, x0: float, list: String, y0: float, speed: float, alpha: float, seed: float = 0.0) -> void:
	var texs: Array = _fog_tex.get(list, [])
	var span := vw + 260.0
	for i in texs.size():
		var tex: ImageTexture = texs[i]
		var sz := Vector2(tex.get_width(), tex.get_height())
		var sp := speed * (0.8 + _r(i * 3.1 + seed) * 0.5)
		var x := fmod(t * sp + off * 0.05 + _r(i * 9.7 + seed) * span, span + sz.x) - sz.x - 60.0
		var y := y0 - sz.y + _r(i * 4.3 + seed) * 10.0
		_fog_draw(n, tex, Vector2(x0 + x, y), alpha, i)


func _fog_draw(n: CanvasItem, tex: Texture2D, p: Vector2, a: float, i: int) -> void:
	var sway := sin(t * 0.21 + i * 1.7) * 6.0
	var br := 0.82 + 0.18 * sin(t * 0.37 + i * 2.3)
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	const PAD := 4.0
	for c in 2:
		var dx := 0.0 if c == 0 else 17.0 + sin(t * 0.13 + i) * 9.0
		var k := 1.0 if c == 0 else 0.38
		var pos := (p + Vector2(sway + dx, -PAD)).round()
		n.draw_texture_rect_region(tex, Rect2(pos, Vector2(w, h + PAD * 2.0)), Rect2(0, -PAD, w, h + PAD * 2.0),
			Color(float(i % 32) / 32.0, float(c), 0.0, a * br * k), false, false)


## sandstorm D walls: PixelLab loops (3 frames ping-pong) + stills, graded to the road haze
func _anim_banks(n: CanvasItem, x0: float, y0: float, speed: float, alpha: float, fps: float, seed: float) -> void:
	var span := vw + 260.0
	var s: Dictionary = _sheets.get("sand_walls", {})
	if s.is_empty():
		return
	for i in s.items.size():
		var sz := _size("sand_walls", i)
		var sp := speed * (0.8 + _r(i * 3.1 + seed) * 0.5)
		var x := fmod(t * sp + off * 0.05 + _r(i * 9.7 + seed) * span, span + sz.x) - sz.x - 60.0
		var y := y0 - sz.y + _r(i * 4.3 + seed) * 10.0
		var br := 0.85 + 0.15 * sin(t * 0.37 + i * 2.3)
		_item(n, "sand_walls", i, _pp((s.items[i] as Array).size(), i, fps), Vector2(x0 + x, y), alpha * br)


func _oc_layer(n: CanvasItem, x0: float, group: String, from: int, to: int, y0: float, speed: float, par: float, alpha: float, jit: float) -> void:
	var span := vw + 320.0
	var cnt := mini(to, sheet_count(group)) - from
	for j in cnt:
		var i := from + j
		var sz := _size(group, i)
		var sp := speed * (0.85 + _r(j * 3.7) * 0.3)
		var x := fmod(t * sp + off * par + _r(j * 8.9) * span + j * span / cnt, span + sz.x) - sz.x - 60.0
		_item(n, group, i, 0, Vector2(x0 + x, y0 + _r(j * 4.1) * jit), alpha)


## a fan of light through a gap every 20 s: fades in, holds, fades out (additive)
func _sun_rays(n: CanvasItem, x0: float) -> void:
	var per := 20.0
	var cyc := floorf((t + 5.0) / per)
	var u := fmod(t + 5.0, per) / per
	var a := u / 0.2 if u < 0.2 else (maxf(0.0, (0.85 - u) / 0.25) if u > 0.6 else 1.0)
	if a <= 0.0 or sheet_count("rays") == 0:
		return
	var x := 40.0 + _r(cyc * 1.9) * (vw - 200.0) - fmod(t + 5.0, per) * 1.2
	_item(n, "rays", int(cyc) % sheet_count("rays"), 0, Vector2(x0 + x, 150.0), a * 0.16 * (1.0 - night))


# =================================================================== screen layers
func _tables_for(key: String) -> Dictionary:
	if _tables_key != key:
		_tables.clear()
		_tables_key = key
	return _tables


func _draw_under() -> void:
	if not Features.on("weather_v2") or tint.a <= 0.0:
		return
	match weather:
		"rain":
			_rain(under, 100, Color8(200, 215, 235), 5.0, 360.0)
		"storm":
			_rain(under, 170, Color8(200, 215, 235), 5.0, 440.0)
		"acid_rain":
			_rain(under, 90, Color8(190, 240, 110), 5.0, 320.0)
		"snow":
			_snow(under)
		"ashfall":
			_ash(under)
		"sandstorm":
			_sand(under, 150)
			_debris(under)
		"fog":
			var span := vw + 260.0
			var texs: Array = _fog_tex.get("banks", [])
			var base := _sy(345.0)
			for i in texs.size():
				var tex: ImageTexture = texs[i]
				var sp := 20.0 * (0.8 + _r(i * 3.1) * 0.5)
				var x := fmod(t * sp + off * 0.05 + _r(i * 9.7) * span, span + tex.get_width()) - tex.get_width() - 60.0
				_fog_draw(under, tex, Vector2(x, base - tex.get_height() + _r(i * 4.3) * 10.0), 0.45, i)


func _draw() -> void:
	if not Features.on("weather_v2") or tint.a <= 0.0:
		return
	if weather == "snow":
		_hero_snow()
	elif weather == "ashfall":
		_draw_hero_ash()


func _col(c: Color, a: float) -> Color:
	return Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, clampf(a, 0.0, 1.0) * tint.a)


## slender streaks in 3 depths; every drop its own length, speed and brightness, a few fat near drops;
## they travel along the slant (wind + vehicle speed). One draw_multiline_colors call per width.
func _rain(n: CanvasItem, count: int, col: Color, len: float, vy: float) -> void:
	var dens := _density()
	var tab := _tables_for("rain%d_%d" % [count, int(dens * 100)])
	if tab.is_empty():
		var lay := [[0.45, 0.3, maxf(2.0, len * 0.5), vy * 0.6], [0.7, 0.45, len * 0.75, vy * 0.8], [1.0, 0.65, len, vy]]
		var drops: Array = []
		for li in 3:
			var L: Array = lay[li]
			for i in int(count * float(L[0]) * dens):
				var r1 := _r(i * 2.9 + li * 31)
				var r2 := _r(i * 5.7 + li * 17)
				var r3 := _r(i * 8.3 + li * 7)
				drops.append([maxf(1.0, roundf(float(L[2]) * 2.0 * (0.45 + r1 * 1.25)) / 2.0), float(L[3]) * (0.85 + r2 * 0.3),
					li == 2 and r3 > 0.8, float(L[1]) * (0.6 + r2 * 0.55), _r(i * 1.3 + li * 91), _r(i * 7.1 + li * 13)])
		tab.drops = drops
	var thin := PackedVector2Array()
	var thin_c := PackedColorArray()
	var fat := PackedVector2Array()
	var fat_c := PackedColorArray()
	var ww := vw + 20.0
	for d in tab.drops:
		var per := (vh + 40.0) / float(d[1])
		var u := fmod((t + float(d[4]) * per) / per, 1.0)
		var y := roundf((-20.0 + u * (vh + 40.0)) * 2.0) / 2.0
		var x := fposmod(float(d[5]) * ww + y * slant, ww) - 10.0
		var L: float = d[0]
		var c := _col(col, float(d[3]))
		if d[2]:
			fat.append(Vector2(x, y)); fat.append(Vector2(x - L * slant, y - L)); fat_c.append(c)
		else:
			thin.append(Vector2(x, y)); thin.append(Vector2(x - L * slant, y - L)); thin_c.append(c)
	if not thin.is_empty():
		n.draw_multiline_colors(thin, thin_c, -1.0)
	if not fat.is_empty():
		n.draw_multiline_colors(fat, fat_c, 1.0)


## ~35 code flake patterns in 4 size classes, 3 depths, drifting with the wind and the vehicle speed
func _snow(n: CanvasItem) -> void:
	var dens := _density()
	var tab := _tables_for("snow%d" % int(dens * 100))
	var classes: Array = _sheets.get("flakes", {}).get("classes", [])
	if classes.size() < 4:
		return
	if tab.is_empty():
		var starts := [0]
		for c in 3:
			starts.append(int(starts[c]) + int(classes[c]))
		var lay := [[340, 0, 14.0, 0.55, [0, 0, 0, 1]], [180, 1, 24.0, 0.8, [0, 1, 1, 2]], [70, 2, 38.0, 0.95, [1, 2, 3, 3]]]
		var fl: Array = []
		for L in lay:
			var li: int = L[1]
			for i in int(int(L[0]) * dens):
				var r1 := _r(i * 3.7 + li * 17)
				var r2 := _r(i * 6.1 + li * 5)
				var r3 := _r(i * 9.9 + li * 11)
				var cls: int = L[4][int(r1 * 4)]
				var idx: int = int(starts[cls]) + int(r2 * int(classes[cls]))
				fl.append([idx, float(L[2]) * (0.7 + r3 * 0.6), li, float(L[3]) * (0.7 + r3 * 0.3), _r(i * 1.7 + li * 29), _r(i * 2.3 + li * 7), 0.8 + r2, i])
		tab.fl = fl
	var span := vw + 120.0
	for f in tab.fl:
		var li: int = f[2]
		var per := (vh + 40.0) / float(f[1])
		var u := fmod((t + float(f[4]) * per) / per, 1.0)
		var drift := (10.0 + li * 8) + (20.0 + li * 25) * spd
		var x := fposmod(float(f[5]) * span + u * per * drift + sin(t * float(f[6]) + int(f[7])) * (2.0 + li * 3), span) - 60.0
		_item(n, "flakes", int(f[0]), 0, Vector2(x, -20.0 + u * (vh + 40.0)), float(f[3]) * tint.a, 1.0, tint)


## big 6-armed crystals now and then twirling past the camera (3 slots, 35% of cycles empty)
func _hero_snow() -> void:
	var n_sets := sheet_count("hero_snow")
	if n_sets == 0:
		return
	for i in 3:
		var per := 9.0 + _r(i * 5.1) * 7.0
		var cyc := floorf((t + i * 4.3) / per)
		var u := fmod(t + i * 4.3, per) / per
		if _r(cyc * 7.7 + i) < 0.35:
			continue
		var si := int(_r(cyc * 3.9 + i * 1.3) * n_sets)
		var nf: int = (_sheets.hero_snow.items[si] as Array).size()
		var drift := 12.0 + 40.0 * spd
		var x := _r(cyc * 2.1 + i) * (vw - 40.0) + u * per * drift * 0.5 - 40.0 + sin(t * 0.9 + i) * 10.0
		var y := -30.0 + u * (vh + 60.0)
		var k := int(floorf(t * (3.0 + _r(cyc) * 3.0) + i * 2)) % (2 * nf - 2)
		var fi := k if k < nf else 2 * nf - 2 - k
		var sc := 2.0 if _r(cyc * 5.3 + i) < 0.5 else 1.0
		var sz := _size("hero_snow", si) * sc
		_item(self, "hero_snow", si, fi, Vector2(x - sz.x / 2.0, y), 0.95 * tint.a, sc, tint)


## 48 irregular ash flakes x 3 tumble frames in 3 depths + flickering embers that smear with speed
func _ash(n: CanvasItem) -> void:
	var dens := _density()
	var tab := _tables_for("ash%d" % int(dens * 100))
	var n_ash := sheet_count("ash")
	if n_ash == 0:
		return
	if tab.is_empty():
		var fl: Array = []
		for L in [[150, 0, 9.0, 0.6], [90, 1, 15.0, 0.85], [34, 2, 24.0, 1.0]]:
			var li: int = L[1]
			for i in int(int(L[0]) * dens):
				var r1 := _r(i * 2.7 + li * 19)
				var r2 := _r(i * 5.9 + li * 3)
				var r3 := _r(i * 8.1 + li * 13)
				fl.append([int(r1 * n_ash), float(L[2]) * (0.6 + r2 * 0.8), li, float(L[3]) * (0.7 + r3 * 0.3), r2, r3, _r(i * 1.9 + li * 7), _r(i * 4.3 + li * 11), i])
		tab.fl = fl
	var span := vw + 140.0
	for f in tab.fl:
		var li: int = f[2]
		var r2: float = f[4]
		var r3: float = f[5]
		var i: int = f[8]
		var per := (vh + 40.0) / float(f[1])
		var u := fmod((t + float(f[6]) * per) / per, 1.0)
		var wind := 6.0 + li * 5 + (18.0 + li * 30) * spd
		var flut := sin(t * (0.7 + r2 * 1.6) + i * 1.3) * (3.0 + li * 3) + sin(t * (2.3 + r3 * 2.0) + i) * (1.0 + li)
		var x := fposmod(float(f[7]) * span + u * per * wind + flut, span) - 70.0
		var y := -20.0 + u * (vh + 40.0) + sin(t * (1.1 + r3) + i * 2) * 2.0
		var k := int(floorf(t * (2.0 + r3 * 5.0) + i)) % 4
		var sc := (2.0 if li == 2 and r2 > 0.7 else 1.0) / (2.0 if li == 0 else 1.0)
		_item(n, "ash", int(f[0]), 1 if k == 3 else k, Vector2(x, y), float(f[3]) * tint.a, sc, tint)
	for i in 22:
		var r1 := _r(i * 6.6)
		var r2 := _r(i * 3.3)
		var per := 6.0 + r1 * 8.0
		var u := fmod((t + r2 * per) / per, 1.0)
		var rise := r1 < 0.35
		var x := roundf(fmod(_r(i * 7.7) * (vw + 80.0) + u * per * (10.0 + 60.0 * spd), vw + 80.0) - 40.0)
		var y := roundf(vh - u * vh * 0.8 if rise else -10.0 + u * (vh + 20.0))
		var fl := 0.5 + 0.5 * sin(t * (9.0 + r2 * 8.0) + i * 3)
		if fl < 0.2:
			continue
		var L := 1 + int(roundf(spd * 3.0 * (0.5 + r1)))
		n.draw_rect(Rect2(x, y, 1, 1), _col(Color8(255, 150 + int(fl * 80), 70), 0.55 + fl * 0.45))
		for s2 in range(1, L + 1):
			n.draw_rect(Rect2(x - s2, roundf(y - (-s2 * 0.3 if rise else s2 * 0.3)), 1, 1), _col(Color8(200, 80, 30), 0.35 * fl))


func _step_hero_ash(delta: float) -> void:
	var n := sheet_count("char")
	if n == 0:
		return
	_hch_next -= delta
	if _hch_next <= 0.0 and _hch_live.size() < 2:
		if _hch_bag.is_empty():
			_hch_bag = range(n)
			_hch_bag.shuffle()
		_hch_live.append({"f": _hch_bag.pop_back(), "x": -40.0, "y": _rng.randf() * vh * 0.7, "vx": 30.0 + _rng.randf() * 30.0,
			"vy": 10.0 + _rng.randf() * 16.0, "sc": 2.0 if _rng.randf() < 0.5 else 1.0, "tq": 2.0 + _rng.randf() * 3.0, "ph": _rng.randf() * 9.0, "sp": []})
		_hch_next = 3.0 + _rng.randf() * 7.0
	var keep: Array = []
	for d in _hch_live:
		d.x += (float(d.vx) + 70.0 * spd) * delta
		d.y += float(d.vy) * delta + sin(t * 1.3 + float(d.ph)) * 0.25 * delta * 60.0
		if _rng.randf() < (0.05 + 0.1 * spd) * delta * 60.0:
			d.sp.append({"x": float(d.x), "y": float(d.y) + _size("char", int(d.f)).y / 2.0 * float(d.sc), "l": 1.0})
		var sp: Array = []
		for p in d.sp:
			p.l -= delta * 1.6
			p.x -= delta * (10.0 + 30.0 * spd)
			p.y += delta * (_rng.randf() * 12.0 - 8.0)
			if float(p.l) > 0.0:
				sp.append(p)
		d.sp = sp
		if float(d.x) < vw + 40.0 and float(d.y) < vh + 30.0:
			keep.append(d)
	_hch_live = keep


## big charred scraps with a little smouldering rim tumbling past the camera, shedding sparks
func _draw_hero_ash() -> void:
	for d in _hch_live:
		for p in d.sp:
			draw_rect(Rect2(roundf(float(p.x)), roundf(float(p.y)), 1, 1), _col(Color8(255, 120 + int(float(p.l) * 100), 50), float(p.l)))
		var k := int(floorf(t * float(d.tq) + float(d.ph))) % 4
		var hot := 1 if sin(t * 11.0 + float(d.ph) * 3.0) + sin(t * 4.3 + float(d.ph)) > 0.3 else 0
		var fi := k * 2 + hot
		var frames: Array = _sheets.char.items[int(d.f)]
		var h0 := (frames[0] as Rect2).size.y * 0.5
		var h := (frames[fi] as Rect2).size.y * 0.5
		_item(self, "char", int(d.f), fi, Vector2(float(d.x), float(d.y) + (h0 - h) / 2.0 * float(d.sc)), tint.a, float(d.sc), tint)


## the old game's sand stream (2x1 bits, ribbon waves) + varied bits in 3 depths
func _sand(n: CanvasItem, count: int) -> void:
	var dens := _density()
	var nf := int(count * 1.3 * dens)
	for i in nf:
		var r1 := _r(i * 4.1)
		var r2 := _r(i * 9.3)
		var v := 260.0 + r1 * 160.0 + 60.0 * spd
		var per := (vw + 60.0) / v
		var u := fmod((t + _r(i * 2.2) * per) / per, 1.0)
		var x := -30.0 + u * (vw + 60.0)
		var y := _r(i * 6.6) * vh + u * (vw + 60.0) * 0.08 * (r2 - 0.3) + sin(x * 0.035 + t * 2.4 + i * 0.7) * 3.0 + sin(x * 0.011 + t * 0.9) * 4.0
		n.draw_rect(Rect2(roundf(x), roundf(y), 2, 1), _col(Color8(232, 176, 112) if r2 < 0.5 else Color8(214, 150, 84), 0.85 * (0.6 + r2 * 0.4)))
	var lay := [[0.5, 0.35, 240.0, 0], [0.35, 0.6, 360.0, 1], [0.15, 0.9, 520.0, 2]]
	for li in 3:
		var L: Array = lay[li]
		var d: int = L[3]
		var a: float = L[1]
		for i in int(count * float(L[0]) * 1.6 * dens):
			var r1 := _r(i * 3.3 + li * 41)
			var r2 := _r(i * 7.7 + li * 13)
			var r3 := _r(i * 1.9 + li * 29)
			var vv := float(L[2]) * (0.7 + r1 * 0.6) + 60.0 * spd
			var per := (vw + 80.0) / vv
			var u := fmod((t + _r(i * 5.3 + li * 7) * per) / per, 1.0)
			var x := -40.0 + u * (vw + 80.0)
			var y := _r(i * 2.7 + li * 3) * vh + sin(t * (3.0 + r2 * 4.0) + i) * (1.0 + d)
			var c: Color = SANDC[int(r2 * SANDC.size())]
			var al := a * (0.6 + r3 * 0.4)
			var w := 1.0
			var h := 1.0
			if d == 0:
				w = 1.0 if r3 < 0.7 else 2.0
			elif d == 1:
				if r3 < 0.35: w = 1.0
				elif r3 < 0.6: w = 2.0
				elif r3 < 0.85: w = 3.0 + floorf(r1 * 5.0)
				else:
					w = 2.0; h = 2.0
			else:
				if r3 < 0.25:
					w = 2.0; h = 2.0
				elif r3 < 0.45:
					w = 3.0; h = 2.0
				elif r3 < 0.75: w = 6.0 + floorf(r1 * 10.0)
				else:
					w = 1.0 + floorf(r1 * 2.0); h = w; c = SANDC[5]; al = a
			n.draw_rect(Rect2(roundf(x), roundf(y), w, h), _col(c, al))


## flying junk, rare and random: a random 4-12 s gap, at most 2 on screen, shuffle bag of the 36 PixelLab pieces
func _step_debris(delta: float) -> void:
	var n := sheet_count("sand_debris")
	if n == 0:
		return
	_deb_next -= delta
	if _deb_next <= 0.0 and _deb_live.size() < 2:
		if _deb_bag.is_empty():
			_deb_bag = range(n)
			_deb_bag.shuffle()
		_deb_live.append({"o": _deb_bag.pop_back(), "x": -50.0, "y": 175.0 + _rng.randf() * 165.0, "v": 110.0 + _rng.randf() * 120.0,
			"amp": 3.0 + _rng.randf() * 10.0, "fq": 1.5 + _rng.randf() * 3.0, "rise": (_rng.randf() - 0.4) * 40.0, "ph": _rng.randf() * 9.0, "i": _rng.randi() % 50})
		_deb_next = 4.0 + _rng.randf() * 8.0
	var keep: Array = []
	for d in _deb_live:
		d.x += (float(d.v) + 40.0 * spd) * delta
		if float(d.x) < vw + 50.0:
			keep.append(d)
	_deb_live = keep


func _debris(n: CanvasItem) -> void:
	for d in _deb_live:
		var u := (float(d.x) + 50.0) / (vw + 100.0)
		var y := _sy(float(d.y)) - u * float(d.rise) + sin(t * float(d.fq) + float(d.ph)) * float(d.amp)
		var nf: int = (_sheets.sand_debris.items[int(d.o)] as Array).size()
		_item(n, "sand_debris", int(d.o), _pp(nf, int(d.i), 5.0), Vector2(float(d.x), y), 0.85 * tint.a, 0.5, tint)
