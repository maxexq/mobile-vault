class_name Background
extends Node2D
## Biome backgrounds built from Parallax2D layers (ParallaxBackground is deprecated in the Godot 4.7 docs).
## Tall 9:16-friendly layers are stacked upwards from the road line. Every layer autoscrolls with the truck
## speed (road fastest, skyline slowest). Changing biome cross-fades the whole set.
## Everything is drawn at 1:1 inside the low-res world viewport -> true pixel art.
## v2 (MV-163, Features "bg_v2"): a biome with assets/bg/v2/<id>.json gets its layout from that file
## (tools/art/bg2.py: 8 layers, 1440-3840 px strips at real scale). Only the biome on screen (and the
## one fading out) is built; the rest are freed so the long strips don't all sit in phone memory.

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

const V2_DIR := "res://assets/bg/v2/"

var groups: Dictionary = {}      # biome id -> {root, layers:[Parallax2D], v2: bool}
var rails: Parallax2D            # railway laid over the road when the convoy is an armoured train
var current := ""
var _speed := 0.0


func _ready() -> void:
	add_to_group("world_bg")
	Game.biome_changed.connect(_on_biome_changed)
	Features.changed.connect(_on_features_changed)
	rails = _px_layer(load("res://assets/bg/rails.png"), 1.0, 1.0, ROAD_Y + 8.0, BW)
	rails.z_index = 1
	rails.visible = false
	add_child(rails)


func _px_layer(tex: Texture2D, scroll_x: float, speed: float, y: float, repeat_w: float) -> Parallax2D:
	var px := Parallax2D.new()
	px.scroll_scale = Vector2(scroll_x, 1.0)
	px.repeat_size = Vector2(repeat_w, 0)
	# repeat_times spreads copies evenly behind and in front of the original (docs: 2D Parallax > Repeat times);
	# the wide battle zoom shows ~1.6x more world, so cover ~±1300 px whatever the strip width
	px.repeat_times = maxi(3 if repeat_w >= 1300.0 else 5, int(ceil(2600.0 / repeat_w)) | 1)
	px.set_meta("speed", speed)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.position = Vector2(0, y)
	px.add_child(spr)
	return px


## v2 layout of a biome, or {} when the switch is off / the biome has not been converted yet
static func v2_layout(id: String) -> Dictionary:
	if not Features.on("bg_v2"):
		return {}
	var path := V2_DIR + id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary and d.has("layers") else {}


func _build_group(id: String) -> void:
	var lay := v2_layout(id)
	if not lay.is_empty():
		_build_group_v2(id, lay)
		return
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
	groups[id] = {"root": root, "layers": layers, "v2": false}


func _build_group_v2(id: String, lay: Dictionary) -> void:
	var root := Node2D.new()
	root.name = id
	root.visible = false
	root.modulate.a = 0.0
	add_child(root)
	var sky_h := float(lay.get("sky_h", 900))
	var sky_tex: Texture2D = load(V2_DIR + id + "_sky.png")
	var top := ColorRect.new()
	top.color = sky_tex.get_image().get_pixel(0, 0)
	top.position = Vector2(-4000, ROAD_Y - sky_h - 2000.0)
	top.size = Vector2(8000, 2004)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	root.add_child(_px_layer(sky_tex, 0.0, 0.0, ROAD_Y + 4.0 - sky_h, 64.0))
	var sun := Parallax2D.new()
	sun.scroll_scale = Vector2(0.02, 1.0)
	var ss := Sprite2D.new()
	ss.texture = load(V2_DIR + id + "_sun.png")
	ss.centered = false
	var sp: Array = lay.get("sun", [150, 40])
	ss.position = Vector2(float(sp[0]), ROAD_Y - 250.0 + float(sp[1]))
	sun.add_child(ss)
	root.add_child(sun)
	var layers := []
	for L in lay.layers:
		var px := _px_layer(load(V2_DIR + "%s_%s.png" % [id, L.name]), float(L.scroll), float(L.speed), float(L.y), float(L.w))
		px.name = str(L.name)
		root.add_child(px)
		layers.append(px)
	var ground := ColorRect.new()
	ground.color = Color(str(lay.get("ground", "#15121c")))
	ground.position = Vector2(-4000, ROAD_Y + 64.0)
	ground.size = Vector2(8000, 1200)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ground)
	groups[id] = {"root": root, "layers": layers, "v2": true}


## the switch was flipped (GOD MODE / remote config): rebuild the biome on screen in the other style
func _on_features_changed() -> void:
	if current == "" or not groups.has(current):
		return
	if bool(groups[current].v2) == not v2_layout(current).is_empty():
		return
	_free_group(current)
	_build_group(current)
	var root: Node2D = groups[current].root
	root.visible = true
	root.modulate.a = 1.0


func _free_group(id: String) -> void:
	if groups.has(id):
		groups[id].root.queue_free()
		groups.erase(id)


## GOD MODE: jump every layer of the biome on screen ahead by `sec` seconds of driving at road speed,
## to check the strips loop without a visible seam or a quick repeat
func skip(sec: float) -> void:
	if not groups.has(current):
		return
	for px in groups[current].layers:
		var p := px as Parallax2D
		p.scroll_offset.x += ROAD_PX_PER_SEC * float(p.get_meta("speed")) * sec


func _on_biome_changed(index: int, instant: bool) -> void:
	var id: String = Data.biome(index).id
	if id == current:
		return
	var old := current
	current = id
	if not groups.has(id):
		_build_group(id)
	var g: Dictionary = groups[id]
	var root: Node2D = g.root
	root.visible = true
	move_child(root, get_child_count() - 1)
	if instant or old == "":
		root.modulate.a = 1.0
		for k in groups.keys():
			if k != id:
				_free_group(k)
		return
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		if old != current:
			_free_group(old))


func _process(delta: float) -> void:
	var target := ROAD_PX_PER_SEC * Game.speed_factor() if Game.started else ROAD_PX_PER_SEC * 0.35
	_speed = move_toward(_speed, target, ROAD_PX_PER_SEC * delta * 0.8)   # smooth accelerate/brake
	for k in groups:
		var g: Dictionary = groups[k]
		if not g.root.visible:
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
