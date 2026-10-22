class_name WeatherFX
extends CanvasLayer
## Screen-space weather (rain / storm + lightning / snow / sandstorm / fog / forest leaves)
## and the day-night + weather colour grade applied through a CanvasModulate in the world.

var canvas_mod: CanvasModulate
var vehicle: Vehicle
var rain: Node2D
var snow: Node2D
var acid: Node2D
var ash: Node2D
var sand: Node2D
var fog: Node2D
var leaves: Node2D
var motes: Node2D
var flash: ColorRect
var haze: ColorRect
var fx_alpha := 1.0          # faded to 0 while a room close-up is open
var _lightning_t := 4.0
var _weather := "clear"
var _vp := Vector2(360, 640)
var light := Color.WHITE
var night := 0.0

signal lightning

const HAZE := {
	"sandstorm": Color(0.85, 0.58, 0.32, 0.30), "fog": Color(0.78, 0.84, 0.86, 0.26),
	"storm": Color(0.08, 0.1, 0.16, 0.18), "snow": Color(0.9, 0.95, 1.0, 0.10), "rain": Color(0.2, 0.25, 0.32, 0.08),
	"acid_rain": Color(0.35, 0.55, 0.1, 0.14), "ashfall": Color(0.35, 0.32, 0.36, 0.22),
}


func set_closeup(on: bool) -> void:
	var tw := create_tween()
	tw.tween_property(self, "fx_alpha", 0.0 if on else 1.0, 0.35)


func _ready() -> void:
	layer = 2
	rain = FX.particles({"tex": Atlas.tex("pt_rain"), "amount": 160, "lifetime": 0.8, "dir": Vector2(0.25, 1), "spread": 2.0,
		"vmin": 300.0, "vmax": 380.0, "smin": 1.0, "smax": 1.0, "color": Color(0.75, 0.85, 0.95, 0.8), "fade": false,
		"box": Vector2(300, 6), "preprocess": 1.0})
	acid = FX.particles({"tex": Atlas.tex("pt_acid"), "amount": 140, "lifetime": 0.9, "dir": Vector2(0.15, 1), "spread": 2.0,
		"vmin": 240.0, "vmax": 300.0, "smin": 1.0, "smax": 1.0, "color": Color(0.8, 1.0, 0.5, 0.85), "fade": false,
		"box": Vector2(300, 6), "preprocess": 1.0})
	snow = FX.particles({"tex": Atlas.tex("pt_snow"), "amount": 120, "lifetime": 6.0, "dir": Vector2(0.4, 1), "spread": 25.0,
		"vmin": 20.0, "vmax": 45.0, "gravity": Vector2(10, 6), "smin": 0.5, "smax": 1.0, "color": Color(1, 1, 1, 0.9),
		"box": Vector2(300, 6), "preprocess": 6.0})
	ash = FX.particles({"tex": Atlas.tex("pt_ash"), "amount": 90, "lifetime": 7.0, "dir": Vector2(0.6, 1), "spread": 30.0,
		"vmin": 10.0, "vmax": 25.0, "gravity": Vector2(6, 4), "smin": 0.5, "smax": 1.0, "color": Color(0.8, 0.78, 0.8, 0.9),
		"box": Vector2(300, 6), "preprocess": 7.0})
	sand = FX.particles({"tex": Atlas.tex("pt_sand"), "amount": 200, "lifetime": 1.6, "dir": Vector2(1, 0.08), "spread": 6.0,
		"vmin": 260.0, "vmax": 420.0, "smin": 1.0, "smax": 2.0, "color": Color(0.95, 0.72, 0.45, 0.85),
		"box": Vector2(6, 300), "preprocess": 2.0})
	fog = FX.particles({"tex": Atlas.tex("pt_fog"), "amount": 24, "lifetime": 14.0, "dir": Vector2(1, 0), "spread": 4.0,
		"vmin": 12.0, "vmax": 26.0, "smin": 1.0, "smax": 2.0, "color": Color(0.9, 0.93, 0.95, 0.55), "fade_in": true,
		"box": Vector2(6, 260), "preprocess": 14.0})
	leaves = FX.particles({"tex": Atlas.tex("pt_leaf"), "amount": 18, "lifetime": 5.0, "dir": Vector2(1, 0.3), "spread": 30.0,
		"vmin": 40.0, "vmax": 80.0, "gravity": Vector2(0, 15), "smin": 1.0, "smax": 1.0, "color": Color(0.55, 0.8, 0.4, 1),
		"box": Vector2(6, 250), "preprocess": 5.0})
	motes = FX.particles({"tex": Atlas.tex("pt_px"), "amount": 30, "lifetime": 6.0, "dir": Vector2(1, -0.2), "spread": 40.0,
		"vmin": 5.0, "vmax": 14.0, "smin": 1.0, "smax": 1.0, "color": Color(1, 0.9, 0.7, 0.6), "fade_in": true,
		"box": Vector2(300, 300), "preprocess": 6.0})
	for p in [fog, motes, leaves, sand, rain, acid, snow, ash]:
		p.emitting = false
		add_child(p)
	haze = ColorRect.new()
	haze.color = Color(0, 0, 0, 0)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(haze)
	move_child(haze, 0)
	flash = ColorRect.new()
	flash.color = Color(0.9, 0.95, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	get_viewport().size_changed.connect(_layout)
	Game.weather_changed.connect(_set_weather)
	Game.biome_changed.connect(func(_i, _inst): _set_weather(Game.s.weather))
	_layout()


func _layout() -> void:
	_vp = get_viewport().get_visible_rect().size
	for p in [rain, acid]:
		p.position = Vector2(_vp.x * 0.4, -12)
		FX.set_box(p, Vector2(_vp.x * 0.75, 6))
		p.lifetime = (_vp.y + 40.0) / 260.0
	for p in [snow, ash]:
		p.position = Vector2(_vp.x * 0.4, _vp.y * 0.5)
		FX.set_box(p, Vector2(_vp.x * 0.75, _vp.y * 0.55))
	for p in [sand, fog, leaves]:
		p.position = Vector2(-40, _vp.y * 0.5)
		FX.set_box(p, Vector2(10, _vp.y * 0.55))
	motes.position = _vp * 0.5
	FX.set_box(motes, _vp * 0.55)


func _set_weather(w: String) -> void:
	_weather = w
	var biome: String = Data.biome(Game.s.biome).id if not Game.s.is_empty() else "industrial"
	rain.emitting = w in ["rain", "storm"]
	acid.emitting = w == "acid_rain"
	ash.emitting = w == "ashfall"
	if rain is GPUParticles2D:
		(rain as GPUParticles2D).amount_ratio = 1.0 if w == "storm" else 0.55
	snow.emitting = w == "snow"
	sand.emitting = w == "sandstorm"
	fog.emitting = w == "fog"
	leaves.emitting = biome == "forest" and w != "snow"
	motes.emitting = biome in ["desert", "industrial", "metro", "swamp"] and w in ["clear", "overcast"]


func _process(delta: float) -> void:
	if Game.s.is_empty():
		return
	# --- day / night colour grade
	var tod: float = Game.s.tod
	var sun := Game.sun_level()
	var day_col := Color(1, 1, 1)
	var dusk_col := Color(1.0, 0.72, 0.5)
	var night_col := Color(0.42, 0.44, 0.64)
	var c: Color
	var dusk := 1.0 - clampf(absf(sun - 0.12) / 0.14, 0.0, 1.0)   # strongest near the horizon
	if sun > 0.0:
		c = day_col.lerp(dusk_col, dusk * 0.7)
	else:
		var depth := clampf(-sin((tod - 0.25) * TAU) / 0.25, 0.0, 1.0)
		c = dusk_col.lerp(night_col, depth)
	night = clampf(1.0 - sun * 6.0, 0.0, 1.0)
	var wt: Color = Data.WEATHER.get(_weather, Data.WEATHER.clear).tint
	c = c * wt
	light = light.lerp(c, clampf(delta * 0.8, 0.0, 1.0))
	if canvas_mod:
		canvas_mod.color = light
	if vehicle:
		vehicle.apply_light(light, night)
	# weather particles get slightly darker at night too
	var pm := Color(1, 1, 1).lerp(light, 0.5)
	pm.a = fx_alpha
	for p in [rain, acid, snow, ash, sand, fog, leaves, motes]:
		p.modulate = pm
	# full-screen haze for low-visibility weather
	var hz: Color = HAZE.get(_weather, Color(0, 0, 0, 0))
	hz.a *= fx_alpha
	haze.color = haze.color.lerp(hz, clampf(delta * 1.5, 0.0, 1.0))
	# --- lightning
	if _weather == "storm":
		_lightning_t -= delta
		if _lightning_t <= 0.0:
			_lightning_t = randf_range(3.0, 9.0)
			_do_lightning()


func _do_lightning() -> void:
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.75, 0.04)
	tw.tween_property(flash, "color:a", 0.1, 0.08)
	tw.tween_property(flash, "color:a", 0.55, 0.04)
	tw.tween_property(flash, "color:a", 0.0, 0.35)
	lightning.emit()
