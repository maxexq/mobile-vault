class_name DesertBackdrop
extends Node2D
## MV-539: approved native desert art, independent repeats and simulation-clock sky.
## Shares the industrial renderer's public interface until the MV-371 common renderer lands.

const DIR := "res://assets/bg/desert_live/"
const ROAD_Y := 290.0
## key, camera parallax, default road-speed multiplier, top (bottom of land layers = ROAD_Y).
const CONFIG := [
	["clouds", 0.04, 0.03, -320.0],
	["far", 0.10, 0.08, -10.0],
	["mid", 0.25, 0.25, 60.0],
	["near", 0.60, 0.60, 166.0],
	["road", 1.0, 1.0, ROAD_Y],
]
const SKY_NAMES := ["night", "dawn", "day", "dusk"]
const SKY_TOP := [Color("060608"), Color("0e0e16"), Color("908670"), Color("060608")]

var layers: Dictionary = {}
var road_speed := 0.0
var phase := 0.0
var celestial_position := Vector2.ZERO
var sun_visible := true
var sky_state := 0
var sky_mix := 0.0
var _sky: Sprite2D
var _top: ColorRect
var _sky_material: ShaderMaterial
var _sky_textures: Array[Texture2D] = []
var _celestial: Node2D
var _sun: Texture2D
var _moon: Texture2D
var _cloud_wind := 4.0
var _tick := -1


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var unshaded := ShaderMaterial.new()
	unshaded.shader = preload("res://shaders/pixel_unshaded.gdshader")
	for key in SKY_NAMES:
		_sky_textures.append(load(DIR + "sky_" + key + ".png"))
	_top = ColorRect.new()
	_top.position = Vector2(-5000, -4000)
	_top.size = Vector2(10000, 3391)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.material = unshaded
	add_child(_top)
	var sky_layer := _layer(_sky_textures[0], 0.0, -610.0)
	_sky = sky_layer.get_child(0) as Sprite2D
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = preload("res://shaders/industrial_sky.gdshader")
	_sky.material = _sky_material
	_celestial = Node2D.new()
	_celestial.material = unshaded
	_celestial.draw.connect(_draw_celestial)
	add_child(_celestial)
	# Reuse the existing independent pixel sprites; no celestial body is baked into desert art.
	_sun = load("res://assets/bg/industrial_live/sun.png")
	_moon = load("res://assets/bg/industrial_live/moon.png")
	for cfg in CONFIG:
		var key: String = cfg[0]
		var px := _layer(load(DIR + key + ".png"), float(cfg[1]), float(cfg[3]))
		px.name = key.capitalize()
		layers[key] = {"node": px, "speed": float(cfg[2]), "default_speed": float(cfg[2]), "offset": 0.0}
	var ground := ColorRect.new()
	ground.position = Vector2(-5000, ROAD_Y + 64)
	ground.size = Vector2(10000, 3000)
	ground.color = Color("26262a")
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	Features.changed.connect(_update_tuning)
	_update_tuning()
	update_clock()


func _update_tuning() -> void:
	for key in layers:
		layers[key].speed = Features.num("desert_background." + key + "_speed", float(layers[key].default_speed))
	_cloud_wind = Features.num("desert_background.cloud_wind", 4.0)


func _layer(tex: Texture2D, scroll: float, y: float) -> Parallax2D:
	var px := Parallax2D.new()
	px.scroll_scale = Vector2(scroll, 1.0)
	px.repeat_size = Vector2(tex.get_width(), 0)
	px.repeat_times = maxi(3, int(ceil(2600.0 / tex.get_width())) | 1)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = tex
	sprite.position.y = y
	px.add_child(sprite)
	add_child(px)
	return px


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	phase = fmod(phase + delta, 600.0)
	for key in layers:
		var entry: Dictionary = layers[key]
		var px: Parallax2D = entry.node
		var wind := _cloud_wind if key == "clouds" else 0.0
		entry.offset = fposmod(float(entry.offset) + (road_speed * float(entry.speed) + wind) * delta, px.repeat_size.x)
		px.scroll_offset = Vector2(roundf(float(entry.offset)), 0)
	var tick := int(phase * Features.num("background.fps", 8.0))
	if tick != _tick:
		_tick = tick
		update_clock()


## Uses Game.tod, including offline catch-up and GOD time jumps. WeatherFX grades land once.
func update_clock() -> void:
	if _sky == null:
		return
	var tod := fposmod(float(Game.s.get("tod", 0.32)), 1.0)
	var part := tod * 4.0
	sky_state = int(floor(part)) % 4
	sky_mix = part - floor(part)
	_sky.texture = _sky_textures[sky_state]
	_sky_material.set_shader_parameter("next_sky", _sky_textures[(sky_state + 1) % 4])
	_sky_material.set_shader_parameter("phase", sky_mix)
	_top.color = SKY_TOP[sky_state] if sky_mix < 0.5 else SKY_TOP[(sky_state + 1) % 4]
	sun_visible = tod >= 0.25 and tod < 0.75
	var cycle := (tod - 0.25) * 2.0 if sun_visible else fposmod(tod - 0.75, 1.0) * 2.0
	var camera := get_viewport().get_camera_2d()
	var extent := get_viewport_rect().size
	var center := Vector2(140, 150)
	if camera:
		extent /= camera.zoom
		center = camera.get_screen_center_position()
	var left := center.x - extent.x * 0.46
	var right := center.x + extent.x * 0.46
	var horizon := ROAD_Y - 100.0
	var arc := maxf(25.0, horizon - maxf(center.y - extent.y * 0.5 + 80.0, ROAD_Y - 380.0))
	celestial_position = Vector2(lerpf(left, right, clampf(cycle, 0.0, 1.0)), horizon - sin(cycle * PI) * arc).round()
	_celestial.position = celestial_position - Vector2(16, 16)
	_celestial.queue_redraw()


func _draw_celestial() -> void:
	_celestial.draw_texture(_sun if sun_visible else _moon, Vector2.ZERO)


func preview_offset(value: float) -> void:
	for key in layers:
		var entry: Dictionary = layers[key]
		entry.offset = fposmod(value * float(entry.speed), entry.node.repeat_size.x)
		entry.node.scroll_offset = Vector2(roundf(float(entry.offset)), 0)
