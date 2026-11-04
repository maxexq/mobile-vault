class_name ParallaxV2Backdrop
extends Node2D
## MV-710: the approved 5-layer parallax road backgrounds (preview https://claude.ai/artifact/QNMzL5sSSobED3sqVKBBzY)
## for every biome: industrial MV-684, desert MV-690, forest MV-693, swamp MV-696, tundra MV-699, metro MV-701.
## Art lives in res://assets/bg/v2/<biome>/ (far/mid 1x, near/road/props/decals drawn at 2x density, own
## sky gradients, clean sun/low-sun/moon sheets MV-706, clouds) plus biome.json (layer heights, effect flags and
## the light/smoke spots measured on the strips). Lights, sky and celestial are unshaded; the land takes the world grade.

const ROAD_Y := 290.0
const N_FRAMES := 48
const FPS := 12.0
## key, scroll_scale.x (swipe parallax), speed vs road, default top y, pixel density
const CONFIG := [
	["far", 0.10, 0.08, 145.0, 1],
	["mid", 0.25, 0.25, 168.0, 1],
	["near", 0.60, 0.60, 210.0, 2],
	["road", 1.0, 1.0, ROAD_Y, 2],
]
const SKY_NAMES := ["night", "dawn", "day", "dusk"]
## hour -> sky (same keys as the preview page)
const SKY_KEYS := [[0.0, 0], [4.5, 0], [6.0, 1], [7.5, 2], [16.5, 2], [18.0, 3], [19.5, 0], [24.0, 0]]
const SMOKE := {"pale": [Color("b4c2c8"), Color("98a2a0"), Color("8a98a4")], "dark": [Color("9a9684"), Color("727064"), Color("666a68")],
	"sand": [Color("e6d2a8"), Color("d6bc8c"), Color("c8ad80")]}
const CLOUD_WRAP := 2600.0
const DITHER := [[0.125, 0.625], [0.875, 0.375]]

var biome := "industrial"
var cfg: Dictionary = {}
var layers: Dictionary = {}
var road_speed := 0.0
var phase := 0.0
var sky_state := 0
var sky_mix := 0.0
var celestial_position := Vector2.ZERO
var celestial_kind := "sun"
var celestial_alpha := 1.0
var _hour := 12.0
var _sky: Sprite2D
var _sky_material: ShaderMaterial
var _sky_textures: Array[Texture2D] = []
var _top: ColorRect
var _celestial: Node2D
var _sheets: Dictionary = {}
var _clouds: Array = []
var _cloud_tex: Array[Texture2D] = []
var _cloud_layer: Parallax2D
var _cloud_node: Node2D
var _air: Node2D
var _air_lit: Node2D
var _decal_tex: Array[Texture2D] = []
var _tick := -1
var _unshaded: ShaderMaterial


func _init(id: String = "industrial") -> void:
	biome = id


func dir() -> String:
	return "res://assets/bg/v2/%s/" % biome


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var f := FileAccess.open(dir() + "biome.json", FileAccess.READ)
	if f:
		cfg = JSON.parse_string(f.get_as_text())
	_unshaded = ShaderMaterial.new()
	_unshaded.shader = preload("res://shaders/pixel_unshaded.gdshader")
	for key in SKY_NAMES:
		_sky_textures.append(load(dir() + "sky_" + key + ".png"))
	_top = ColorRect.new()
	_top.position = Vector2(-5000, -4000)
	_top.size = Vector2(10000, 3391)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.material = _unshaded
	add_child(_top)
	var sky_layer := _layer(_sky_textures[2], 0.0, ROAD_Y - 900.0, 1)
	sky_layer.name = "Sky"
	_sky = sky_layer.get_child(0) as Sprite2D
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = preload("res://shaders/industrial_sky.gdshader")
	_sky.material = _sky_material
	for k in ["sun", "low", "moon"]:
		_sheets[k] = load(dir() + k + "_sheet.png")
	_celestial = Node2D.new()
	_celestial.name = "Celestial"
	_celestial.material = _unshaded
	_celestial.draw.connect(_draw_celestial)
	add_child(_celestial)
	# clouds + birds: one long wrapping band that drifts with the wind and a little with the road
	_cloud_tex = _textures("clouds")
	_cloud_layer = Parallax2D.new()
	_cloud_layer.name = "Clouds"
	_cloud_layer.scroll_scale = Vector2(0.04, 1.0)
	_cloud_layer.repeat_size = Vector2(CLOUD_WRAP, 0)
	_cloud_layer.repeat_times = 3
	add_child(_cloud_layer)
	_cloud_node = Node2D.new()
	_cloud_node.draw.connect(_draw_clouds)
	_cloud_layer.add_child(_cloud_node)
	for i in 9:
		_clouds.append({"i": i % maxi(1, _cloud_tex.size()), "x": _rng(i + 1) * CLOUD_WRAP, "y": -140.0 + _rng(i + 9) * 150.0, "w": 2.0 + _rng(i + 5) * 5.0})
	var spots: Dictionary = cfg.get("spots", {})
	for c in CONFIG:
		var key: String = c[0]
		var d: int = c[4]
		var y := float(cfg.get(key + "Y", c[3]))
		var tex: Texture2D = load(dir() + key + ".png")
		var px := _layer(tex, float(c[1]), y, d)
		px.name = key.capitalize()
		var entry := {"node": px, "speed": float(c[2]), "offset": 0.0, "y": y, "d": d, "spots": spots.get(key, [])}
		if key != "road":
			# smoke/drips take the world grade, lights stay lit
			for lit in [false, true]:
				var fx := Node2D.new()
				fx.name = "Lights" if lit else "Fx"
				fx.position.y = y
				fx.scale = Vector2.ONE / d
				if lit:
					fx.material = _unshaded
				var lit_flag: bool = lit
				fx.draw.connect(func(): _draw_spots(fx, entry.spots, lit_flag))
				px.add_child(fx)
				entry["lights" if lit else "fx"] = fx
		layers[key] = entry
		if key == "near":
			_scatter(px, _textures("props"), tex.get_width() / d, 6, 0.45, 11, func(t: Texture2D, _i: int): return 288.0 - t.get_height() / 2.0)
		if key == "road":
			_decal_tex = _textures("decals")
			_scatter(px, _decal_tex, tex.get_width() / d, 4, 0.5, 23, func(t: Texture2D, i: int): return y + 14.0 + _rng(i * 9.1 + 23) * 36.0 - t.get_height() / 4.0)
	_air = Node2D.new()
	_air.name = "Air"
	_air.draw.connect(_draw_air.bind(false))
	add_child(_air)
	var ground := ColorRect.new()
	ground.position = Vector2(-5000, ROAD_Y + 64)
	ground.size = Vector2(10000, 3000)
	ground.color = Background.GROUND_COLORS.get(biome, Color("18181c"))
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	_air_lit = Node2D.new()
	_air_lit.name = "AirLit"
	_air_lit.material = _unshaded
	_air_lit.draw.connect(_draw_air.bind(true))
	add_child(_air_lit)
	update_clock()


func _textures(sub: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(1, 20):
		var p := dir() + "%s/%02d.png" % [sub, i]
		if not ResourceLoader.exists(p):
			break
		out.append(load(p))
	return out


func _layer(tex: Texture2D, scroll: float, y: float, d: int) -> Parallax2D:
	var px := Parallax2D.new()
	var w := float(tex.get_width()) / d
	px.scroll_scale = Vector2(scroll, 1.0)
	px.repeat_size = Vector2(w, 0)
	px.repeat_times = maxi(3, int(ceil(2600.0 / w)) | 1)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = tex
	sprite.position.y = y
	sprite.scale = Vector2.ONE / d
	px.add_child(sprite)
	add_child(px)
	return px


## props/decals: a fixed random pick per cell, laid inside the layer's repeat width so they loop with it
func _scatter(px: Parallax2D, list: Array[Texture2D], width: float, cells: int, chance: float, salt: int, yb: Callable) -> void:
	if list.is_empty():
		return
	var cell := width / cells
	for i in cells:
		if _rng(i * 7.3 + salt) > chance:
			continue
		var t: Texture2D = list[int(_rng(i * 3.1 + salt) * list.size()) % list.size()]
		var s := Sprite2D.new()
		s.centered = false
		s.texture = t
		s.scale = Vector2(0.5, 0.5)
		s.position = Vector2(roundf(i * cell + _rng(i * 5.7 + salt) * maxf(0.0, cell - t.get_width() / 2.0)), roundf(float(yb.call(t, i))))
		px.add_child(s)


static func _rng(n: float) -> float:
	var x := sin(n * 127.1 + 311.7) * 43758.5453
	return x - floorf(x)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	phase = fmod(phase + delta, 600.0)
	for key in layers:
		var entry: Dictionary = layers[key]
		var px: Parallax2D = entry.node
		var speed := Features.num("parallax_v2." + str(key) + "_speed", float(entry.speed))
		entry.offset = fposmod(float(entry.offset) + road_speed * speed * delta, px.repeat_size.x)
		px.scroll_offset = Vector2(roundf(float(entry.offset)), 0)
	var wind := Features.num("parallax_v2.cloud_wind", 1.0)
	for c in _clouds:
		c.x = fposmod(float(c.x) + (float(c.w) * wind + road_speed * 0.03) * delta, CLOUD_WRAP)
	var tick := int(phase * Features.num("background.fps", 8.0))
	if tick != _tick:
		_tick = tick
		update_clock()
		_cloud_node.queue_redraw()
		for key in layers:
			for k in ["fx", "lights"]:
				if layers[key].has(k):
					(layers[key][k] as Node2D).queue_redraw()
		_air.queue_redraw()
		_air_lit.queue_redraw()


func hour() -> float:
	return fposmod(float(Game.s.get("tod", 0.5)), 1.0) * 24.0


## 0 by day .. 1 at night (preview nightK)
func night_k() -> float:
	var d := minf(absf(_hour - 12.0), 12.0)
	return clampf((d - 5.2) / 1.8, 0.0, 1.0)


## Uses the simulation clock (offline catch-up, GOD time jumps), never OS time.
func update_clock() -> void:
	if _sky == null:
		return
	_hour = hour()
	for i in SKY_KEYS.size() - 1:
		var a: Array = SKY_KEYS[i]
		var b: Array = SKY_KEYS[i + 1]
		if _hour >= float(a[0]) and _hour < float(b[0]):
			sky_state = int(a[1])
			sky_mix = 0.0 if int(a[1]) == int(b[1]) else (_hour - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0]))
			_sky.texture = _sky_textures[sky_state]
			_sky_material.set_shader_parameter("next_sky", _sky_textures[int(b[1])])
			_sky_material.set_shader_parameter("phase", sky_mix)
			break
	var img := (_sky.texture as Texture2D).get_image()
	if img:
		_top.color = img.get_pixel(0, 0)
	# camera-relative arc like the industrial sky: rises on the right (east), sets on the left
	var camera := get_viewport().get_camera_2d()
	var extent := get_viewport_rect().size
	var center := Vector2(140, 150)
	if camera:
		extent /= camera.zoom
		center = camera.get_screen_center_position()
	var left := center.x - extent.x * 0.46
	var right := center.x + extent.x * 0.46
	var horizon := ROAD_Y - 40.0
	var arc := maxf(40.0, horizon - maxf(center.y - extent.y * 0.5 + 40.0, ROAD_Y - 400.0))
	var u := 0.0
	celestial_alpha = 1.0
	if _hour > 5.4 and _hour < 18.6:
		u = clampf((_hour - 6.0) / 12.0, 0.0, 1.0)
		var e := sin(PI * u)
		celestial_kind = "low" if e < 0.32 else "sun"
	else:
		u = fposmod(_hour - 18.5 + 24.0, 24.0) / 11.0
		celestial_kind = "moon"
		celestial_alpha = 1.0 if u <= 1.0 else 0.0
		u = clampf(u, 0.0, 1.0)
	celestial_position = Vector2(lerpf(right, left, u), horizon - sin(u * PI) * arc).round()
	_celestial.position = celestial_position - Vector2(32, 32)
	_celestial.queue_redraw()


func _draw_celestial() -> void:
	if celestial_alpha <= 0.0:
		return
	var sheet: Texture2D = _sheets.get(celestial_kind)
	if sheet == null:
		return
	var fr := int(phase * 4.0) % 8
	_celestial.draw_texture_rect_region(sheet, Rect2(0, 0, 64, 64), Rect2(0, fr * 64, 64, 64))


func _draw_clouds() -> void:
	for c in _clouds:
		if _cloud_tex.is_empty():
			break
		var t: Texture2D = _cloud_tex[int(c.i) % _cloud_tex.size()]
		_cloud_node.draw_texture(t, Vector2(roundf(float(c.x)), roundf(float(c.y))))
	# three small flocks
	var bird := Color(str(cfg.get("bird", "#18181c")))
	for i in 3:
		var bx := fposmod(_rng(i + 40) * 900.0 + phase * (12.0 + _rng(i + 43) * 10.0), CLOUD_WRAP)
		var by := -120.0 + _rng(i + 41) * 150.0
		for j in 3 + int(_rng(i + 42) * 4.0):
			var x := roundf(bx - j * 7 + (j % 2) * 2)
			var y := roundf(by + j * 3 + sin(phase * 2.0 + j) * 2.0)
			var up := int(phase * 6.0 + j) % 2
			_cloud_node.draw_rect(Rect2(x, y, 1, 1), bird)
			_cloud_node.draw_rect(Rect2(x - 1, y - up, 1, 1), bird)
			_cloud_node.draw_rect(Rect2(x + 1, y - up, 1, 1), bird)


func _frame() -> int:
	return int(phase * FPS) % N_FRAMES


## one dithered pixel in the layer's own image pixels (the node is scaled by 1/density)
func _put(n: Node2D, x: float, y: float, c: Color, a: float = 1.0) -> void:
	var xi := int(floorf(x))
	var yi := int(floorf(y))
	if a > DITHER[yi & 1][xi & 1]:
		n.draw_rect(Rect2(xi, yi, 1, 1), c)


func _draw_spots(n: Node2D, list: Array, lit: bool) -> void:
	var f := _frame()
	var nk := night_k()
	for s in list:
		var t := float((f + int(s.get("phase", 0))) % N_FRAMES) / N_FRAMES
		var sx := float(s.x)
		var sy := float(s.y)
		match str(s.type):
			"smoke":
				if lit:
					continue
				var pal: Array = SMOKE.get(str(s.get("tone", "dark")), SMOKE.dark)
				for q in 3:
					var u := fmod(t + q / 3.0, 1.0)
					var cx := sx + u * float(s.get("drift", 10))
					var cy := sy - u * float(s.get("rise", 26))
					var r := 2.5 + u * 5.0
					var a := 0.95 * pow(1.0 - u, 0.7)
					var col: Color = pal[mini(2, int(u * 3.0))]
					for yy in range(int(floorf(cy - r)), int(cy + r) + 1):
						for xx in range(int(floorf(cx - r)), int(cx + r) + 1):
							var dd := (pow(xx - cx, 2) + pow(yy - cy, 2)) / (r * r)
							if dd <= 1.0:
								_put(n, xx, yy, col, a * (1.0 - 0.5 * dd))
			"drip":
				if lit:
					continue
				var k2 := (f + int(s.get("phase", 0))) % 24
				var dc := Color(str(s.get("c", "#9fc4d0")))
				if k2 < 10:
					_put(n, sx, sy + floorf(k2 * k2 * 0.12), dc)
				elif k2 < 13:
					_put(n, sx - 1, sy + 12, dc, 0.6)
					_put(n, sx + 1, sy + 12, dc, 0.6)
			"glint":
				if not lit:
					continue
				var k3 := (f + int(s.get("phase", 0))) % N_FRAMES
				if k3 < 4:
					var gc := Color.WHITE if k3 < 2 else Color("bfe6ff")
					_put(n, sx, sy, gc)
					if k3 == 1:
						for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
							_put(n, sx + o.x, sy + o.y, Color("bfe6ff"))
			"glow":
				if not lit:
					continue
				var a2 := (0.2 + 0.8 * nk) * (0.65 + 0.35 * sin(TAU * t))
				var r2 := int(s.get("r", 3))
				var c1 := Color(str(s.get("c1", "#c8fff2")))
				var c2 := Color(str(s.get("c2", "#5ee8cc")))
				for yy in range(-r2, r2 + 1):
					for xx in range(-r2, r2 + 1):
						var d2 := float(xx * xx + yy * yy) / float(r2 * r2)
						if d2 <= 1.0:
							_put(n, sx + xx, sy + yy, c1 if d2 < 0.3 else c2, a2 * (1.0 - d2) * 0.9)
			"blink":
				if not lit:
					continue
				if (f + int(s.get("phase", 0))) % 24 < 6:
					_put(n, sx, sy, Color("c86450"))
					for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
						_put(n, sx + o.x, sy + o.y, Color("a8372a"), 0.5)
				else:
					_put(n, sx, sy, Color("7c2218"))
			"spark":
				if not lit:
					continue
				var k4 := (f + int(s.get("phase", 0))) % N_FRAMES
				if k4 < 6:
					for v in [Vector2(0, 1), Vector2(2, 1.6), Vector2(-2, 1.3), Vector2(1, 2)]:
						_put(n, sx + v.x * (1 + (k4 >> 1)), sy + floorf(k4 * v.y * 2.0), Color("fff0b0") if k4 < 2 else Color("f0c060"))
					if k4 < 2:
						_put(n, sx, sy, Color.WHITE)


## biome weather-free ambience in screen-ish world space: snow, falling leaves, fireflies, tumbleweed
func _draw_air(lit: bool) -> void:
	var camera := get_viewport().get_camera_2d()
	var extent := get_viewport_rect().size
	var center := Vector2(140, 150)
	if camera:
		extent /= camera.zoom
		center = camera.get_screen_center_position()
	var x0 := center.x - extent.x * 0.5 - 60.0
	var span := extent.x + 200.0
	var t := phase
	if lit:
		if cfg.get("fireflies", false):
			var nk := night_k()
			if nk > 0.0:
				for i in 18:
					var x := roundf(x0 + 60.0 + _rng(i * 5.1) * extent.x + sin(t * 0.7 + i) * 14.0)
					var y := roundf(205.0 + _rng(i * 2.7) * 75.0 + sin(t * 1.1 + i * 2) * 6.0)
					var on := 0.5 + 0.5 * sin(t * 3.0 + i * 1.7)
					if on < 0.25:
						continue
					_air_lit.draw_rect(Rect2(x, y, 1, 1), Color(0.91, 1.0, 0.6, nk * on))
					_air_lit.draw_rect(Rect2(x - 1, y - 1, 3, 3), Color(0.91, 1.0, 0.6, nk * on * 0.35))
		return
	if cfg.get("snow", false):
		var count := int(Features.num("parallax_v2.snow", 80.0))
		for i in count:
			var per := 5.0 + _rng(i * 2.3) * 6.0
			var u := fmod((t + _rng(i * 4.1) * per) / per, 1.0)
			var x := x0 + fposmod(_rng(i * 1.7) * span - u * 120.0, span) + sin(t * 1.3 + i) * 3.0
			var y := -150.0 + u * (ROAD_Y + 64.0 + 150.0)
			var big := i % 5 == 0
			_air.draw_rect(Rect2(roundf(x), roundf(y), 2 if big else 1, 2 if big else 1), Color("f4f8ff") if big else Color("d6e2ec"))
	if cfg.get("leaves", false):
		var cols := [Color("a8642a"), Color("c88a34"), Color("5a7a3a"), Color("7a5226")]
		for i in 14:
			var per := (span) / (30.0 + _rng(i) * 30.0)
			var u := fmod((t + _rng(i * 7.7) * per) / per, 1.0)
			var x := x0 + span - u * span
			var y := -60.0 + u * 330.0 + sin(t * 2.0 + i) * 8.0 + _rng(i * 1.9) * 40.0
			if y > ROAD_Y + 60.0:
				continue
			var fl := int(t * 5.0 + i) % 2
			_air.draw_rect(Rect2(roundf(x), roundf(y), 2 if fl else 1, 1 if fl else 2), cols[i % 4])
	if cfg.get("tumble", false) and not _decal_tex.is_empty():
		var per2 := 9.0
		var k := floorf(t / per2)
		var u2 := fmod(t, per2) / per2
		if _rng(k * 4.7) <= 0.75:
			var tw: Texture2D = _decal_tex[0]
			for d in _decal_tex:
				if d.get_width() < 70 and d.get_height() > 35:
					tw = d
					break
			var w := tw.get_width() / 2.0
			var h := tw.get_height() / 2.0
			var lane := ROAD_Y + 18.0 + _rng(k * 2.3) * 30.0
			var x := x0 + span - u2 * span
			var y := lane - h - absf(sin(u2 * PI * 7.0)) * 7.0
			var rot := int(t * 8.0) % 4
			_air.draw_set_transform(Vector2(roundf(x + w / 2.0), roundf(y + h / 2.0)), -rot * PI / 2.0, Vector2(0.5, 0.5))
			_air.draw_texture(tw, -Vector2(tw.get_width(), tw.get_height()) / 2.0)
			_air.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func preview_offset(value: float) -> void:
	for key in layers:
		var entry: Dictionary = layers[key]
		entry.offset = fposmod(value * Features.num("parallax_v2." + str(key) + "_speed", float(entry.speed)), entry.node.repeat_size.x)
		entry.node.scroll_offset = Vector2(roundf(float(entry.offset)), 0)
