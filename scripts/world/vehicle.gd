class_name Vehicle
extends Node2D
## The Mobile Vault: a cut-away rust-bucket truck with THREE rooms per floor (64x52 each), a ladder shaft,
## roof garden, twin solar panels (pre-drawn tilt frames), 3 animated wheels (or snow tracks), dust, exhaust,
## headlight, blinking antenna and road-bump body bob.
## The chassis grows with the prestige meta (MK-I/II/III = 4/5/6 floors): extra floors are stacked on top,
## so the cab, wheels and road line never move. Exterior mods (spiked ram, roof turret, spare fuel drums,
## snow tracks, armour plates, solar hoods, lead skirt, rain catcher, heater chimney) are drawn as overlays.
## Local coordinates match tools/art/truck.py (4-floor shell is 280x300, faces LEFT).

const COLS := [44, 118, 184]
const ROOM_SIZE := Vector2(64, 52)
const FLOOR_H := 56
const ROW0 := 210                 # y of the bottom floor's rooms
## slot -> (column, floor from the bottom). Slots 0-7 keep their old places; 8-11 fill the new third column,
## 12-17 are the extra MK-II / MK-III floors. The engine (slot 7) sits right behind the cab.
const SLOT_CELL := [Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 1), Vector2i(1, 1),
	Vector2i(1, 0), Vector2i(0, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3),
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)]
const WHEELS := [Vector2(22, 284), Vector2(182, 284), Vector2(222, 284)]
const TRACKS_POS := Vector2(202, 284)
const CHIMNEY := Vector2(33, 144)
const SOLAR_X := [79, 105]
const SOLAR_Y := 14               # for the 4-floor shell; taller chassis shift everything on the roof up
const HEADLIGHT := Vector2(0, 227)
const ANTENNA := Vector2(113, 1)
const ROOF_Y := 36
const DECK := Vector2(266, 260)
const TURRET_POS := Vector2(254, 110)
const SPIKES_POS := Vector2(272, 236)
const SIZE := Vector2(280, 300)
const ROAD_Y := 300.0             # tyre contact line (local)

var body: Node2D
var room_views: Array[RoomView] = []
var wheels: Array[AnimatedSprite2D] = []
var tracks: AnimatedSprite2D
var dusts: Array[Node2D] = []
var smoke: Node2D
var solars: Array[Sprite2D] = []
var headlight: Polygon2D
var antenna_light: Sprite2D
var floors := 4
var _shell: Sprite2D
var _rooms_root: Node2D
var _mods_root: Node2D
var _roof_root: Node2D
var _bump_t := 0.0
var _bump := 0.0
var _sparks: Node2D
var _speed := 0.0
var _t := 0.0


static func roof_dy_for(n_floors: int) -> float:
	return -float(FLOOR_H * (n_floors - 4))


## extra height above the 4-floor shell (negative = up)
func roof_dy() -> float:
	return roof_dy_for(floors)


func _ready() -> void:
	for i in WHEELS.size():
		var w := AnimatedSprite2D.new()
		w.sprite_frames = Atlas.wheel_frames()
		w.position = WHEELS[i]
		add_child(w)
		wheels.append(w)
	tracks = AnimatedSprite2D.new()
	tracks.sprite_frames = Atlas.track_frames()
	tracks.position = TRACKS_POS
	tracks.visible = false
	body = Node2D.new()
	add_child(body)
	smoke = FX.particles({
		"tex": Atlas.tex("pt_smoke"), "amount": 14, "lifetime": 3.0, "dir": Vector2(0.4, -1), "spread": 10.0,
		"vmin": 8.0, "vmax": 13.0, "gravity": Vector2(12, -3), "smin": 1.0, "smax": 2.0,
		"color": Color(0.45, 0.43, 0.42, 0.85), "preprocess": 3.0,
	})
	smoke.position = CHIMNEY
	body.add_child(smoke)
	_rooms_root = Node2D.new()
	body.add_child(_rooms_root)
	_shell = Sprite2D.new()
	_shell.centered = false
	body.add_child(_shell)
	_roof_root = Node2D.new()
	body.add_child(_roof_root)
	for x in SOLAR_X:
		var s := Sprite2D.new()
		s.texture = Atlas.tex("solar_2")
		s.centered = false
		s.position = Vector2(x - 15, SOLAR_Y)
		_roof_root.add_child(s)
		solars.append(s)
	antenna_light = Sprite2D.new()
	antenna_light.texture = Atlas.tex("pt_spark")
	antenna_light.centered = false
	antenna_light.position = ANTENNA
	antenna_light.modulate = Color("ff5a4a")
	_roof_root.add_child(antenna_light)
	_mods_root = Node2D.new()
	body.add_child(_mods_root)
	body.add_child(tracks)

	headlight = Polygon2D.new()
	headlight.polygon = PackedVector2Array([Vector2(0, -2), Vector2(-150, -24), Vector2(-150, 30), Vector2(0, 3)])
	headlight.vertex_colors = PackedColorArray([Color(1, 0.85, 0.5, 0.45), Color(1, 0.85, 0.5, 0.0), Color(1, 0.85, 0.5, 0.0), Color(1, 0.85, 0.5, 0.45)])
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	headlight.material = add_mat
	headlight.position = HEADLIGHT
	body.add_child(headlight)

	for i in [1, 2]:
		var d := FX.particles({
			"tex": Atlas.tex("pt_dust"), "amount": 16, "lifetime": 0.8, "dir": Vector2(1, -0.5), "spread": 25.0,
			"vmin": 20.0, "vmax": 50.0, "gravity": Vector2(-10, 90), "smin": 1.0, "smax": 1.0,
			"color": Color(0.6, 0.54, 0.46, 0.9), "box": Vector2(5, 1),
		})
		d.position = WHEELS[i] + Vector2(12, 14)
		d.emitting = false
		add_child(d)
		dusts.append(d)

	_sparks = FX.particles({
		"tex": Atlas.tex("pt_spark"), "amount": 10, "lifetime": 0.5, "dir": Vector2(0.4, -1), "spread": 50.0,
		"vmin": 30.0, "vmax": 70.0, "gravity": Vector2(0, 160), "color": Color(1, 0.75, 0.35), "explosiveness": 0.8,
	})
	_sparks.position = Vector2(254, 200)
	_sparks.emitting = false
	body.add_child(_sparks)

	Game.rooms_changed.connect(refresh_rooms)
	Game.dwellers_changed.connect(refresh_rooms)
	Game.vault_level_changed.connect(func(_l): refresh_rooms())
	Game.weather_changed.connect(_on_weather)
	Game.game_started.connect(rebuild)
	Mods.mods_changed.connect(_refresh_mods)
	Meta.generation_started.connect(func(_g): rebuild())
	rebuild()


## (re)creates the room views / shell for the current chassis (called on load and on a new generation)
func rebuild() -> void:
	floors = Meta.floors() if not Game.s.is_empty() else 4
	floors = clampi(floors, 4, 6)
	var dy := roof_dy()
	_shell.texture = Atlas.tex("truck_shell_%d" % floors)
	_shell.position = Vector2(0, dy)
	_roof_root.position = Vector2(0, dy)
	for rv in room_views:
		rv.queue_free()
	room_views.clear()
	var n := Game.slot_count() if not Game.s.is_empty() else Data.SLOT_COUNT
	for slot in mini(n, SLOT_CELL.size()):
		var rv := RoomView.new()
		rv.slot = slot
		rv.position = slot_local_pos(slot)
		_rooms_root.add_child(rv)
		room_views.append(rv)
	refresh_rooms()
	_refresh_mods()


func slot_local_pos(slot: int) -> Vector2:
	var cell: Vector2i = SLOT_CELL[slot]
	return Vector2(COLS[cell.x], ROW0 - FLOOR_H * cell.y)


func slot_global_rect(slot: int) -> Rect2:
	var p := body.to_global(slot_local_pos(slot))
	return Rect2(p, ROOM_SIZE * global_scale)


## rect in the vehicle's own space (no body bob) – used by the camera so close-ups don't jitter
func slot_rect(slot: int) -> Rect2:
	return Rect2(to_global(slot_local_pos(slot)), ROOM_SIZE)


func slot_at(global_pos: Vector2) -> int:
	for rv in room_views:
		if slot_global_rect(rv.slot).has_point(global_pos):
			return rv.slot
	return -1


func solar_global_rect() -> Rect2:
	return Rect2(to_global(Vector2(60, 4 + roof_dy())), Vector2(64, 32))


## top of the truck incl. roof props (local y) – the camera keeps this on screen
func top_y() -> float:
	return roof_dy() - 4.0


func refresh_rooms() -> void:
	if Game.s.is_empty():
		return
	if room_views.size() != mini(Game.slot_count(), SLOT_CELL.size()):
		rebuild()
		return
	for rv in room_views:
		rv.refresh()


func set_build_highlight(on: bool) -> void:
	for rv in room_views:
		rv.build_highlight = on and Game.is_slot_unlocked(rv.slot) and Game.s.rooms[rv.slot].type == "empty"
		rv.queue_redraw()


func spark() -> void:
	_sparks.restart()
	_sparks.emitting = true


func actor_for(did: int) -> Node2D:
	for rv in room_views:
		if rv.actors.has(did):
			return rv.actors[did]
	return null


func all_actors() -> Array:
	var out := []
	for rv in room_views:
		out.append_array(rv.actors.values())
	return out


# ------------------------------------------------------------------ exterior mods on the model
func _mod_sprite(region: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Atlas.tex(region)
	s.centered = false
	s.position = pos
	_mods_root.add_child(s)
	return s


func _refresh_mods() -> void:
	for ch in _mods_root.get_children():
		ch.queue_free()
	if Game.s.is_empty():
		return
	var dy := roof_dy()
	var ram := Mods.level("spike_ram")
	if ram > 0:
		_mod_sprite("mod_spike_ram_%d" % mini(ram, 3), Vector2(-20, 242))
	var tur := Mods.level("roof_turret")
	if tur > 0:
		_mod_sprite("mod_roof_turret_%d" % mini(tur, 3), Vector2(200, ROOF_Y + dy - 18))
	for k in mini(Mods.level("fuel_tanks"), 3):
		_mod_sprite("mod_fuel_tank", Vector2(20, 140 - 24 * k))
	var arm := Mods.level("armor_plates")
	if arm > 0:
		_mod_sprite("mod_armor_cab", Vector2(2, 226))
		# level 2: bottom two floors plated, level 3: every floor
		var plated := floors if arm >= 3 else (2 if arm == 2 else 0)
		for fb in plated:
			_mod_sprite("mod_armor_wall", Vector2(37, ROW0 - FLOOR_H * fb - 2))
			_mod_sprite("mod_armor_wall", Vector2(247, ROW0 - FLOOR_H * fb - 2))
	if Mods.level("solar_covers") > 0:
		for x in SOLAR_X:
			_mod_sprite("mod_solar_cover", Vector2(x - 17, 8 + dy))
	if Mods.level("rad_shield") > 0:
		_mod_sprite("mod_rad_shield", Vector2(42, 268))
	if Mods.level("rain_catcher") > 0:
		_mod_sprite("mod_rain_catcher", Vector2(146, ROOF_Y + dy - 36))
	if Mods.level("heater") > 0:
		_mod_sprite("mod_heater", Vector2(130, ROOF_Y + dy - 20))
	var has_tracks := Mods.level("tracks") > 0
	tracks.visible = has_tracks
	for i in [1, 2]:
		wheels[i].visible = not has_tracks


func _on_weather(w: String) -> void:
	var mud := w in ["rain", "storm", "snow", "acid_rain"]
	for d in dusts:
		if d is GPUParticles2D:
			d.texture = Atlas.tex("pt_mud" if mud else "pt_dust")
		elif d is CPUParticles2D:
			d.texture = Atlas.tex("pt_mud" if mud else "pt_dust")


## called by the lighting controller: keeps room interiors / headlight glowing at night
func apply_light(ambient: Color, night: float) -> void:
	var inv := Color(1.0 / maxf(ambient.r, 0.3), 1.0 / maxf(ambient.g, 0.3), 1.0 / maxf(ambient.b, 0.3))
	var warm := Color(1.0, 0.97, 0.9).lerp(inv * Color(1.0, 0.9, 0.75), clampf(night * 0.85, 0.0, 1.0))
	for rv in room_views:
		rv.set_glow(warm)
	headlight.visible = night > 0.15 or Game.s.get("weather", "") in ["storm", "fog", "sandstorm", "snow", "ashfall"]
	headlight.modulate.a = clampf(maxf(night, 0.5), 0.0, 1.0)
	antenna_light.modulate = Color("ff5a4a") * Color(inv.r, inv.g, inv.b) if night > 0.3 else Color("ff5a4a")


func _process(delta: float) -> void:
	if Game.s.is_empty():
		return
	_t += delta
	var f := Game.speed_factor()
	_speed = move_toward(_speed, f, delta * 0.7)
	var moving := _speed > 0.02
	for w in wheels:
		if moving:
			if not w.is_playing():
				w.play_backwards("default")   # driving left -> wheels spin counter-clockwise
			w.speed_scale = 2.4 * _speed
		else:
			w.pause()
	if tracks.visible:
		if moving:
			if not tracks.is_playing():
				tracks.play_backwards("default")
			tracks.speed_scale = 2.0 * _speed
		else:
			tracks.pause()
	for d in dusts:
		d.emitting = moving
		if d is GPUParticles2D:
			(d as GPUParticles2D).amount_ratio = clampf(_speed, 0.2, 1.0)
	if smoke is GPUParticles2D:
		(smoke as GPUParticles2D).speed_scale = 1.0 + _speed * 0.8
	antenna_light.visible = fmod(_t, 1.6) < 0.25
	_bump_t -= delta
	if moving and _bump_t <= 0.0:
		_bump_t = randf_range(0.18, 0.55) / maxf(_speed, 0.3)
		_bump = -2.0 if randf() < 0.15 else -1.0
	_bump = move_toward(_bump, 0.0, delta * 14.0)
	body.position.y = round(_bump)
	var sun := Game.sun_level()
	var az := clampf((float(Game.s.tod) - 0.25) / 0.5, 0.0, 1.0)
	var frame := 2
	if sun > 0.0 and Game.s.weather != "sandstorm":
		var span := 2.0 if Game.s.solar.tracking else 1.0
		frame = clampi(int(round(2.0 + lerpf(-span, span, az))), 0, 4)
	for s in solars:
		s.texture = Atlas.tex("solar_%d" % frame)
