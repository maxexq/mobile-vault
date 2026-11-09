class_name Background
extends Node2D
## Biome backgrounds built from Parallax2D layers (ParallaxBackground is deprecated in the Godot 4.7 docs).
## Tall 9:16-friendly layers are stacked upwards from the road line. Every layer autoscrolls with the truck
## speed (road fastest, skyline slowest). Changing biome cross-fades the whole set.
## Everything is drawn at 1:1 inside the low-res world viewport -> true pixel art.

const BW := 480.0
const ROAD_Y := 290.0            # top of the road strip (tyres touch at ROAD_Y + 10)
## name, scroll_scale.x (camera swipe parallax), speed factor (vs road), y of the layer's top-left
const LAYERS := [
	["clouds", 0.04, 0.03, ROAD_Y - 610.0],
	["far", 0.10, 0.08, ROAD_Y - 296.0],
	["mid", 0.25, 0.25, ROAD_Y - 226.0],
	["near", 0.6, 0.6, ROAD_Y - 122.0],
	["road", 1.0, 1.0, ROAD_Y],
]
const ROAD_PX_PER_SEC := 90.0
const WIND_PX := 4.0
const SUN_POS := Vector2(150, ROAD_Y - 250.0)
const GROUND_COLORS := {"industrial": Color("26262a"), "desert": Color("4e3e2a"), "forest": Color("3a2818"),
	"swamp": Color("21160f"), "tundra": Color("3a3a3e"), "metro": Color("18181c")}

var groups: Dictionary = {}      # biome id -> {root, layers:[Parallax2D]}
var _view_w := 0.0               # MV-723: widest view the strips were last fitted to (art px)
var rails: Parallax2D            # railway laid over the road when the convoy is an armoured train
var current := ""
var _speed := 0.0
var _target := 0.0
var _target_t := 0.0
const TARGET_SEC := 0.1


func _ready() -> void:
	for b in Data.BIOMES:
		_build_group(b.id)
	Game.biome_changed.connect(_on_biome_changed)
	Features.changed.connect(_refresh_backdrops)
	rails = _px_layer(load("res://assets/bg/rails.png"), 1.0, 1.0, ROAD_Y + 8.0, BW)
	rails.z_index = 1
	rails.visible = false
	add_child(rails)
	_refresh_backdrops()


func _px_layer(tex: Texture2D, scroll_x: float, speed: float, y: float, repeat_w: float) -> Parallax2D:
	var px := Parallax2D.new()
	px.scroll_scale = Vector2(scroll_x, 1.0)
	px.repeat_size = Vector2(repeat_w, 0)
	# repeat_times spreads copies evenly behind and in front of the original (docs: 2D Parallax > Repeat times);
	# the wide battle zoom shows ~1.6x more world, so cover ~±1300 px whatever the strip width
	px.repeat_times = maxi(5, int(ceil(2600.0 / repeat_w)) | 1)
	px.set_meta("speed", speed)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.position = Vector2(0, y)
	px.add_child(spr)
	return px


func _build_group(id: String) -> void:
	var root := Node2D.new()
	root.name = id
	root.visible = false
	root.modulate.a = 0.0
	add_child(root)
	var sky_tex: Texture2D = load("res://assets/bg/%s_sky.png" % id)
	# solid top colour above the sky strip (tall portrait screens)
	var top := ColorRect.new()
	top.color = sky_tex.get_image().get_pixel(0, 0)
	top.position = Vector2(-4000, ROAD_Y - 900.0 - 2000.0)
	top.size = Vector2(8000, 2004)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var sky := _px_layer(sky_tex, 0.0, 0.0, ROAD_Y + 4.0 - 900.0, 64.0)
	root.add_child(sky)
	var sun := Parallax2D.new()
	sun.scroll_scale = Vector2(0.02, 1.0)
	var ss := Sprite2D.new()
	ss.texture = load("res://assets/bg/%s_sun.png" % id)
	ss.centered = false
	ss.position = SUN_POS
	sun.add_child(ss)
	root.add_child(sun)
	var layers := []
	for L in LAYERS:
		var px := _px_layer(load("res://assets/bg/%s_%s.png" % [id, L[0]]), L[1], L[2], L[3], BW)
		root.add_child(px)
		layers.append(px)
	var ground := ColorRect.new()
	ground.color = GROUND_COLORS.get(id, Color("15121c"))
	ground.position = Vector2(-4000, ROAD_Y + 64.0)
	ground.size = Vector2(8000, 1200)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ground)
	groups[id] = {"root": root, "layers": layers, "legacy": root.get_children()}
	# MV-710: approved 5-layer parallax v2 (every biome), wins over legacy when parallax_v2 is on
	# (MV-729: the MV-548/MV-539 industrial + desert "modern" backdrops it replaced were retired)
	if DirAccess.dir_exists_absolute("res://assets/bg/v2/%s" % id):
		var v2 := ParallaxV2Backdrop.new(id)
		v2.name = id.capitalize() + "V2"
		v2.visible = false
		root.add_child(v2)
		groups[id]["v2"] = v2
	_fit_repeats(root)


## MV-723: every Parallax2D strip gets enough copies for the widest view. The layers were built for ~±1300 art px, but
## the free camera zoomed out to 1 screen px per art px on a big screen shows more than 2000 art px across, and the sky
## strip (64 px, scroll 0) then ran out on the right: a black box behind the clouds. Copies spread evenly behind and
## ahead of a wrapped origin up to one strip from the screen edge, so n * w / 2 must reach view width + w.
func fit_repeats(view_w: float) -> void:
	if is_equal_approx(view_w, _view_w):
		return
	_view_w = view_w
	_fit_repeats(self)


func _fit_repeats(under: Node) -> void:
	for n in under.find_children("*", "Parallax2D", true, false):
		var px := n as Parallax2D
		var w := px.repeat_size.x
		if w <= 0.0:
			continue
		if not px.has_meta("base_repeat"):
			px.set_meta("base_repeat", px.repeat_times)
		var want := maxi(int(px.get_meta("base_repeat")), int(ceil(2.0 * (_view_w + w) / w)) | 1)
		if px.repeat_times != want:
			px.repeat_times = want


func _refresh_backdrops() -> void:
	var use_v2 := Features.on("parallax_v2")
	for id in groups:
		var g: Dictionary = groups[id]
		var v2_on: bool = use_v2 and g.has("v2")
		for node in g.legacy:
			(node as CanvasItem).visible = not v2_on
		if g.has("v2"):
			(g.v2 as Node2D).visible = v2_on


## which backdrop draws a biome right now: "v2" or "legacy"
func backdrop_kind(id: String) -> String:
	var g: Dictionary = groups.get(id, {})
	if g.has("v2") and g.v2.visible:
		return "v2"
	return "legacy"


func _on_biome_changed(index: int, instant: bool) -> void:
	var id: String = Data.biome(index).id
	if id == current:
		return
	var old := current
	current = id
	var g: Dictionary = groups[id]
	var root: Node2D = g.root
	root.visible = true
	move_child(root, get_child_count() - 1)
	if instant or old == "":
		root.modulate.a = 1.0
		for k in groups:
			if k != id:
				groups[k].root.visible = false
		return
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		var o: Node2D = groups[old].root
		o.visible = false
		o.modulate.a = 0.0)


func _process(delta: float) -> void:
	# MV-562 (perf_cache): the vehicle speed (weather, gear, engine, haul...) is read 10 times a second; the scroll
	# eases toward it anyway, so the road looks the same
	_target_t -= delta
	if _target_t <= 0.0 or not Features.on("perf_cache"):
		_target_t = TARGET_SEC
		_target = ROAD_PX_PER_SEC * Game.speed_factor() if Game.started else ROAD_PX_PER_SEC * 0.35
	_speed = move_toward(_speed, _target, ROAD_PX_PER_SEC * delta * 0.8)   # smooth accelerate/brake
	for k in groups:
		var g: Dictionary = groups[k]
		if not g.root.visible:
			continue
		if g.has("v2") and g.v2.visible:
			g.v2.road_speed = _speed
			continue
		for px in g.layers:
			var sp: float = px.get_meta("speed")
			var wind := WIND_PX if sp < 0.05 else 0.0
			# the truck drives to the LEFT, so the world scrolls to the right (+x)
			(px as Parallax2D).autoscroll = Vector2(_speed * sp + wind, 0.0)
	rails.visible = Game.started and not Game.s.is_empty() and Game.vehicle_def().get("rail", false)
	rails.autoscroll = Vector2(_speed, 0.0)


func current_speed_px() -> float:
	return _speed
