class_name CabView
extends Node2D
## The walk-in engine room in the cab (v4.6): sits BEHIND the vehicle shell (the shell has a hole there), shows
## the engine's state (idle / run / hot / broken art) and the crew working in it (Data.CAB_SLOT).
## Its size comes from Data.VEHICLES[tier].cab; the floor is 6 px above the bottom like every room.

const SPOTS := [12.0, 18.0]      # at the engine block; the gauges at the back wall are added per size

var tier := "van"
var size := Vector2(31, 58)
var interior: Sprite2D
var actors_root: Node2D
var actors: Dictionary = {}       # dweller id -> DwellerActor
var _state := ""
var _glow := Color.WHITE
var _t := 0.0
var _steam: Node2D
var ambience: RoomAmbience


func setup(t: String) -> void:
	tier = t
	var r: Array = Data.VEHICLES.get(t, Data.VEHICLES.van).get("cab", [2, 204, 31, 58])
	position = Vector2(float(r[0]), float(r[1]))
	size = Vector2(float(r[2]), float(r[3]))
	interior = Sprite2D.new()
	interior.centered = false
	add_child(interior)
	ambience = RoomAmbience.new()
	add_child(ambience)
	ambience.setup("cab_" + t)
	actors_root = Node2D.new()
	actors_root.position.y = size.y - RoomView.H     # DwellerActor.FLOOR_Y assumes a 52 px room
	add_child(actors_root)
	_steam = FX.particles({
		"tex": Atlas.tex("pt_smoke"), "amount": 8, "lifetime": 1.6, "dir": Vector2(0, -1), "spread": 25.0,
		"vmin": 6.0, "vmax": 12.0, "gravity": Vector2(0, -4), "smin": 1.0, "smax": 1.5,
		"color": Color(0.85, 0.82, 0.75, 0.8),
	})
	_steam.position = Vector2(size.x * 0.5, 10)
	_steam.emitting = false
	add_child(_steam)
	_state = ""
	refresh()


func refresh() -> void:
	if Game.s.is_empty():
		return
	_update_state()
	var want: Array = Game.room_occupants(Data.CAB_SLOT)
	var keep := {}
	var spots: Array = SPOTS.duplicate()
	spots.append(size.x - 9.0)
	for d in want:
		keep[int(d.id)] = true
		if not actors.has(int(d.id)):
			var a := DwellerActor.new()
			actors_root.add_child(a)
			a.setup(d, "engine", actors.size())
			a.x_max = size.x - 7.0
			a.spots = spots
			a.position.x = clampf(10.0 + actors.size() * 10.0, DwellerActor.X_MIN, a.x_max)
			actors[int(d.id)] = a
		(actors[int(d.id)] as DwellerActor).striking = d.get("strike", false)
	for id in actors.keys():
		if not keep.has(id):
			actors[id].queue_free()
			actors.erase(id)


func _update_state() -> void:
	var stt := EngineBay.state_key()
	if stt != _state:
		_state = stt
		interior.texture = Atlas.tex("cab_%s_%s" % [tier, stt])
		ambience.cab_state = stt
		_steam.emitting = stt == "hot" or stt == "broken"
		if _steam is GPUParticles2D:
			(_steam as GPUParticles2D).modulate = Color(0.5, 0.5, 0.5) if stt == "broken" else Color.WHITE
		elif _steam is CPUParticles2D:
			(_steam as CPUParticles2D).modulate = Color(0.5, 0.5, 0.5) if stt == "broken" else Color.WHITE


func set_glow(c: Color) -> void:
	_glow = c
	interior.modulate = c
	actors_root.modulate = c


func has_global_point(p: Vector2) -> bool:
	return Rect2(global_position, size * global_scale).has_point(p)


func _process(delta: float) -> void:
	ambience.visible = Features.on("room_ambience")
	_t += delta
	if _t >= 0.25:
		_t = 0.0
		if not Game.s.is_empty():
			_update_state()
