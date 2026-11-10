class_name RoomWindowView
extends Node2D
## MV-757: what a v3 room sees through its window. RoomV3Cell puts this behind the room image wherever rooms.json
## gives a level a "window" rect (so far the grow room's centre window; v3_import.py cut the window light out of the
## art). Draws the current biome's v2 parallax sky (by the hour, like ParallaxV2Backdrop), its far skyline and mid
## layer, sliding with the vehicle's speed, inside the rect only. Switch room_window_bg off = the old flat window light.
## Tune room_window.speed scales the slide, room_window.horizon moves the skyline up/down in the window.

const LIGHT := Color(0.86, 0.9, 0.84)       # the window light the art had before the cut (switch off)
const NIGHT := Color(0.34, 0.38, 0.55)
const LAYERS := [["far", 0.08, 145.0], ["mid", 0.25, 168.0]]   # key, speed vs road, default top y (ParallaxV2Backdrop.CONFIG)
const SKY_TOP := ParallaxV2Backdrop.ROAD_Y - 900.0
const ROAD_PX := 90.0                       # Background.ROAD_PX_PER_SEC
const VIEW_PAD := 6.0                       # the window bottom sits this far below the row where the far skyline turns solid

var rect := Rect2()
var biome := ""
var _tex := {}                              # "far"/"mid"/"sky_<n>" -> Texture2D of `biome`
var _cfg := {}
var _view_y := 245.0
var _offset := 0.0
var _sky := 2
var _night := 0.0
var _redraw_t := 0.0
static var _cache := {}                     # biome -> {tex, cfg}: every grow room shares the loaded strips


func set_window(r: Array) -> void:
	rect = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	visible = true
	_sync()
	queue_redraw()


static func on() -> bool:
	return Features.on("room_window_bg")


static func biome_now() -> String:
	if Game.s.is_empty():
		return "industrial"
	return str(Data.biome(int(Game.s.get("biome", 0))).get("id", "industrial"))


## the sky index (ParallaxV2Backdrop.SKY_NAMES) and 0..1 night for an hour
static func sky_for(hour: float) -> Array:
	var sky := 2
	for i in ParallaxV2Backdrop.SKY_KEYS.size() - 1:
		var a: Array = ParallaxV2Backdrop.SKY_KEYS[i]
		var b: Array = ParallaxV2Backdrop.SKY_KEYS[i + 1]
		if hour >= float(a[0]) and hour < float(b[0]):
			sky = int(a[1])
			break
	var d := minf(absf(hour - 12.0), 12.0)
	return [sky, clampf((d - 5.2) / 1.8, 0.0, 1.0)]


static func load_biome(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var dir := "res://assets/bg/v2/%s/" % id
	var out := {"tex": {}, "cfg": {}}
	if not ResourceLoader.exists(dir + "far.png"):
		_cache[id] = out
		return out
	var f := FileAccess.open(dir + "biome.json", FileAccess.READ)
	if f:
		var j = JSON.parse_string(f.get_as_text())
		if j is Dictionary:
			out.cfg = j
	for k in ["far", "mid"]:
		out.tex[k] = load(dir + k + ".png")
	out["view_y"] = float(out.cfg.get("farY", 145.0)) + _solid_row(out.tex.far) + VIEW_PAD
	for i in ParallaxV2Backdrop.SKY_NAMES.size():
		out.tex["sky_%d" % i] = load(dir + "sky_" + ParallaxV2Backdrop.SKY_NAMES[i] + ".png")
	_cache[id] = out
	return out


## first row of the far strip that is (almost) fully opaque: where the skyline meets its own solid ground
static func _solid_row(tex: Texture2D) -> float:
	var img := tex.get_image() if tex else null
	if img == null:
		return 100.0
	var w := img.get_width()
	for y in img.get_height():
		var solid := 0
		for x in range(0, w, 4):
			solid += 1 if img.get_pixel(x, y).a > 0.5 else 0
		if solid * 4 >= w * 0.95:
			return float(y)
	return float(img.get_height())


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_offset = randf() * 600.0           # neighbouring grow rooms don't show the same spot


func _sync() -> void:
	var id := biome_now()
	if id != biome:
		biome = id
		var b := load_biome(id)
		_tex = b.tex
		_cfg = b.cfg
		_view_y = float(b.get("view_y", 245.0))
	var hour := fposmod(float(Game.s.get("tod", 0.5)), 1.0) * 24.0 if not Game.s.is_empty() else 12.0
	var s := sky_for(hour)
	_sky = int(s[0])
	_night = float(s[1])


func _process(delta: float) -> void:
	if not visible or rect.size == Vector2.ZERO:
		return
	var sp := Game.speed_factor() if Game.started and not Game.s.is_empty() else 0.0
	_offset += delta * ROAD_PX * sp * Features.num("room_window.speed", 1.0)
	_redraw_t -= delta
	if sp > 0.0 or _redraw_t <= 0.0:    # parked: the sky still follows the clock, once a second is plenty
		_redraw_t = 1.0
		_sync()
		queue_redraw()


func _draw() -> void:
	if rect.size == Vector2.ZERO:
		return
	if not on() or _tex.is_empty():
		draw_rect(rect, LIGHT)
		return
	var h := rect.size.y
	var bottom := _view_y + Features.num("room_window.horizon", 0.0)
	var sky: Texture2D = _tex.get("sky_%d" % _sky)
	if sky:                              # the sky strip is a vertical gradient 64 wide: stretch it across
		draw_texture_rect_region(sky, rect, Rect2(0, bottom - h - SKY_TOP, sky.get_width(), h))
	var tint := Color.WHITE.lerp(NIGHT, _night)
	for c in LAYERS:
		var tex: Texture2D = _tex.get(c[0])
		if tex == null:
			continue
		var top := float(_cfg.get(str(c[0]) + "Y", c[2]))
		var src_y := bottom - h - top
		var y0 := maxf(src_y, 0.0)
		var hh := minf(src_y + h, float(tex.get_height())) - y0
		if hh <= 0.0:
			continue
		var w := float(tex.get_width())
		var x := fposmod(-_offset * float(c[1]), w)   # the vehicle drives left, the world slides right
		var dst_y := rect.position.y + (y0 - src_y)
		var left := rect.size.x
		var dx := 0.0
		while left > 0.0:
			var take := minf(left, w - x)
			draw_texture_rect_region(tex, Rect2(rect.position.x + dx, dst_y, take, hh), Rect2(x, y0, take, hh), tint)
			dx += take
			left -= take
			x = 0.0
