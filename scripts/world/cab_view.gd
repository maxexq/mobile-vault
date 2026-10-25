class_name CabView
extends Node2D
## The walk-in engine room in the cab (v4.6): sits BEHIND the vehicle shell (the shell has a hole there), shows
## the engine's state (idle / run / hot / broken art) and the crew working in it (Data.CAB_SLOT).
## Its size comes from Data.VEHICLES[tier].cab; the floor is 6 px above the bottom like every room.

const SPOTS := [12.0, 18.0]      # at the engine block; the gauges at the back wall are added per size
## MV-388 phase 2, cab-local, matching tools/art/engine_bay.py BLOCK: engine block [x, y, w, h] and hose anchor
const BLOCK := {"van": [9, 35, 14, 13], "bus": [9, 22, 17, 14], "rig": [8, 18, 16, 13], "train": [7, 36, 22, 20]}
const HOSE := {"van": Vector2(24, 35), "bus": Vector2(27, 22), "rig": Vector2(25, 18), "train": Vector2(30, 36)}
const FAN_FPS := 4.0             # running; parked idle turns at half (tune vehicle.fan_fps)
const VENT_GAP := 2.25           # s between hot-vent wisps on average (random 0.67x..1.33x, tune vehicle.vent_gap)

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
var _block: Sprite2D             # vehicle_detail: block casting detail (healthy idle / run only)
var fan: AnimatedSprite2D        # vehicle_ambience: cooling fan, hose, hot-vent wisps (pool of 2)
var hose: AnimatedSprite2D
var vents: Array[AnimatedSprite2D] = []
var _vent_t := 0.0


func setup(t: String) -> void:
	tier = t
	var r: Array = Data.VEHICLES.get(t, Data.VEHICLES.van).get("cab", [2, 204, 31, 58])
	position = Vector2(float(r[0]), float(r[1]))
	size = Vector2(float(r[2]), float(r[3]))
	interior = Sprite2D.new()
	interior.centered = false
	add_child(interior)
	_build_detail()
	add_to_group("cab_view")
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
	_tick_detail(delta)
	_t += delta
	if _t >= 0.25:
		_t = 0.0
		if not Game.s.is_empty():
			_update_state()


# ------------------------------------------------------------------ MV-388 phase 2
## children of the interior sprite, so they share its night glow; RoomAmbience and the crew draw above them
func _build_detail() -> void:
	var b: Array = BLOCK.get(tier, BLOCK.van)
	_block = Sprite2D.new()
	_block.centered = false
	_block.texture = Atlas.tex("decal_engine_%s_block" % tier)
	_block.position = Vector2(b[0], b[1])
	interior.add_child(_block)
	fan = AnimatedSprite2D.new()
	fan.centered = false
	fan.sprite_frames = Atlas.strip_frames("prop_engine_fan_idle", 4, FAN_FPS)
	fan.position = Vector2(5, int(b[1]) + int(b[3]) / 2 - 5)       # over the old static fan
	interior.add_child(fan)
	hose = AnimatedSprite2D.new()
	hose.centered = false
	hose.sprite_frames = Atlas.strip_frames("prop_engine_hose_idle", 4, 2.0)
	hose.position = HOSE.get(tier, HOSE.van)
	hose.frame = 2                                                  # out of step with the fan
	interior.add_child(hose)
	for i in 2:
		var v := AnimatedSprite2D.new()
		v.centered = false
		v.sprite_frames = Atlas.strip_frames("fx_engine_heat_vent", 6, 6.0, false)
		v.position = Vector2(int(b[0]) + int(b[2]) / 2 - 4 + i * 2, int(b[1]) - 12)
		v.visible = false
		v.animation_finished.connect(v.hide)
		interior.add_child(v)
		vents.append(v)


func ambience_on() -> bool:
	return Features.on("vehicle_ambience") and Features.on("room_ambience") and EngineBay.on()


func _tick_detail(delta: float) -> void:
	var stt := _state
	_block.visible = Features.on("vehicle_detail") and (stt == "idle" or stt == "run")
	var amb := ambience_on()
	var hot_vent := amb and stt == "hot"
	# never the old steam and the new hot-vent together; broken keeps the old dark smoke
	_steam.emitting = stt == "broken" or (stt == "hot" and not hot_vent)
	fan.visible = amb
	hose.visible = amb
	var held := stt == "broken" or EngineBay.job_holds()
	if amb and not held:
		var fps := Features.num("vehicle.fan_fps", FAN_FPS)
		_spin(fan, (fps if stt != "idle" else fps * 0.5) / FAN_FPS)
		_spin(hose, 1.0 if stt == "idle" or stt == "run" else 0.0)
	else:
		_spin(fan, 0.0)
		_spin(hose, 0.0)
	if not hot_vent:
		for v in vents:
			v.visible = false
		_vent_t = 0.0
		return
	_vent_t -= delta
	if _vent_t <= 0.0:
		vent_now()


## speed 0 = hold the first frame
func _spin(a: AnimatedSprite2D, speed: float) -> void:
	if speed <= 0.0:
		if a.is_playing():
			a.pause()
		if a == fan:
			a.frame = 0
		return
	a.speed_scale = speed
	if not a.is_playing():
		a.play("default")


## one hot-vent wisp now (at most two at a time); also GOD MODE's preview
func vent_now() -> bool:
	_vent_t = randf_range(0.67, 1.33) * Features.num("vehicle.vent_gap", VENT_GAP)
	for v in vents:
		if not v.visible:
			v.visible = true
			v.frame = 0
			v.play("default")
			return true
	return false


func vents_active() -> int:
	return vents.filter(func(v): return v.visible).size()
