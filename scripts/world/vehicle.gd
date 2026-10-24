class_name Vehicle
extends Node2D
## The Mobile Vault convoy: a main vehicle (camper van / armoured bus / 18-wheeler rig / armoured train, picked by
## the prestige ladder) with three 64x52 rooms per floor, plus up to two towed trailers (wagons for the train),
## two floors x three rooms each. Cut-away by default; the X-ray toggle swaps in the closed, plated exterior.
## Exterior mods are drawn as overlays (spiked ram, roof turret, fuel drums, snow tracks, armour, solar hoods,
## lead skirt, rain catcher, heater chimney, heavy suspension, off-road wheels).
## Local coordinates match tools/art/vehicles.py (main shells are 280x300, trailers 248x300, faces LEFT).

const COLS := [44, 118, 184]
const TRAILER_COLS := [22, 88, 154]
const ROOM_SIZE := Vector2(64, 52)
const FLOOR_H := 56
const ROW0 := 210                 # y of the bottom floor's rooms
const MAIN_W := 280.0
const TRAILER_W := 248.0
const TRACKS_X := {"van": 200, "bus": 200, "rig": 202}
const SOLAR_X := [79, 105]
const TITLE_CRUISE := 0.35         # title-screen backdrop speed (matches the road scroll in background.gd)
const SOLAR_Y := 14               # relative to a 4-floor roof (roof_dy() shifts it)
const ANTENNA := Vector2(113, 1)
const ROOF_Y := 36
const DECK := Vector2(266, 260)
const TURRET_POS := Vector2(254, 110)
## roof rest deck (ดาดฟ้า, Mods "roof_deck"): 76x60 sprite on stilts over the rear roof, planks 26px up
const ROOF_DECK_X := 182
const ROOF_DECK_H := 26
const ROOF_DECK_COT := Vector2(201, 0)    # where the reserve sits, relative to the planks (x truck-local)
const SPIKES_POS := Vector2(272, 236)
const SIZE := Vector2(280, 300)
const ROAD_Y := 300.0             # tyre contact line (local)
const TRAILER_WHEELS := [Vector2(60, 284), Vector2(184, 284)]
const WAGON_WHEELS := [Vector2(34, 290), Vector2(54, 290), Vector2(172, 290), Vector2(192, 290)]
const TRAIN_WHEELS := [Vector2(16, 290), Vector2(36, 290), Vector2(150, 290), Vector2(170, 290), Vector2(214, 290), Vector2(234, 290)]

var body: Node2D
var room_views: Array[RoomView] = []
var cab_view: CabView              # v4.6: the engine room in the cab (Data.CAB_SLOT)
var wheels: Array[AnimatedSprite2D] = []
var tracks: AnimatedSprite2D
var dusts: Array[Node2D] = []
var smoke: Node2D
var solars: Array[Sprite2D] = []
var headlight: Polygon2D
var antenna_light: Sprite2D
var floors := 4
var tier := "rig"
var n_trailers := 0
var xray := true                  # true = cut-away (rooms visible)
var _xray_hold := 0.0             # tap on the hull peeks inside for a few seconds
var _ext_alpha := 0.0
var _wheels_root: Node2D
var _shells: Node2D
var _seams_root: Node2D          # large-room interior strips drawn over the hull partitions (v4.4)
var _exteriors: Node2D
var _rooms_root: Node2D
var _mods_root: Node2D
var _roof_root: Node2D
var pets_root: Node2D
var _bump_t := 0.0
var _bump := 0.0
var _rumble_t := 0.0
var _rumble := 0.0
var _sparks: Node2D
var _speed := 0.0
var _t := 0.0


static func roof_dy_for(n_floors: int) -> float:
	return float(FLOOR_H * (4 - n_floors))


## offset of the roof from the 4-floor roof (positive = lower)
func roof_dy() -> float:
	return roof_dy_for(floors)


func roof_y() -> float:
	return ROOF_Y + roof_dy()


func unit_x(unit: int) -> float:
	return 0.0 if unit < 0 else MAIN_W + TRAILER_W * unit


## how far the convoy's rear deck moved back because of trailers
func rear_shift() -> float:
	return TRAILER_W * n_trailers


func length() -> float:
	return MAIN_W + rear_shift()


func _ready() -> void:
	_wheels_root = Node2D.new()
	add_child(_wheels_root)
	tracks = AnimatedSprite2D.new()
	tracks.sprite_frames = Atlas.track_frames()
	tracks.visible = false
	body = Node2D.new()
	add_child(body)
	smoke = FX.particles({
		"tex": Atlas.tex("pt_smoke"), "amount": 14, "lifetime": 3.0, "dir": Vector2(0.4, -1), "spread": 10.0,
		"vmin": 8.0, "vmax": 13.0, "gravity": Vector2(12, -3), "smin": 1.0, "smax": 2.0,
		"color": Color(0.45, 0.43, 0.42, 0.85), "preprocess": 3.0,
	})
	body.add_child(smoke)
	_rooms_root = Node2D.new()
	body.add_child(_rooms_root)
	pets_root = Node2D.new()
	body.add_child(pets_root)
	_shells = Node2D.new()
	body.add_child(_shells)
	_seams_root = Node2D.new()
	body.add_child(_seams_root)
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
	_exteriors = Node2D.new()
	_exteriors.modulate.a = 0.0
	body.add_child(_exteriors)
	body.add_child(tracks)

	headlight = Polygon2D.new()
	headlight.polygon = PackedVector2Array([Vector2(0, -2), Vector2(-150, -24), Vector2(-150, 30), Vector2(0, 3)])
	headlight.vertex_colors = PackedColorArray([Color(1, 0.85, 0.5, 0.45), Color(1, 0.85, 0.5, 0.0), Color(1, 0.85, 0.5, 0.0), Color(1, 0.85, 0.5, 0.45)])
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	headlight.material = add_mat
	body.add_child(headlight)

	for i in 2:
		var d := FX.particles({
			"tex": Atlas.tex("pt_dust"), "amount": 16, "lifetime": 0.8, "dir": Vector2(1, -0.5), "spread": 25.0,
			"vmin": 20.0, "vmax": 50.0, "gravity": Vector2(-10, 90), "smin": 1.0, "smax": 1.0,
			"color": Color(0.6, 0.54, 0.46, 0.9), "box": Vector2(5, 1),
		})
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
	Game.pets_changed.connect(_sync_pets)
	Mods.mods_changed.connect(func():
		if Game.trailers() != n_trailers:
			rebuild()
		else:
			_refresh_mods())
	Meta.generation_started.connect(func(_g): rebuild())
	rebuild()


## (re)creates shells, wheels and room views for the current tier + trailers
func rebuild() -> void:
	var empty := Game.s.is_empty()
	tier = "rig" if empty else Game.tier()
	floors = 4 if empty else Game.floors()
	n_trailers = 0 if empty else Game.trailers()
	var vd: Dictionary = Data.VEHICLES.get(tier, Data.VEHICLES.rig)
	var dy := roof_dy()
	for n in [_shells, _exteriors, _wheels_root]:
		for ch in n.get_children():
			ch.queue_free()
	wheels.clear()
	_add_sprite(_shells, "veh_" + tier, Vector2.ZERO)
	_add_sprite(_exteriors, "ext_" + tier, Vector2.ZERO)
	var kind: String = vd.get("trailer", "trailer")
	for t in n_trailers:
		var x := unit_x(t)
		_add_sprite(_shells, "veh_" + kind, Vector2(x, 0))
		_add_sprite(_exteriors, "ext_" + kind, Vector2(x, 0))
		for w in (WAGON_WHEELS if kind == "wagon" else TRAILER_WHEELS):
			_add_wheel(Vector2(x, 0) + w, kind == "wagon")
	if vd.get("rail", false):
		for w in TRAIN_WHEELS:
			_add_wheel(w, true)
	else:
		for w in vd.wheels:
			_add_wheel(Vector2(w[0], w[1]), false)
	_roof_root.position = Vector2(0, dy)
	smoke.position = Vector2(vd.chimney[0], vd.chimney[1])
	headlight.position = Vector2(vd.headlight[0], vd.headlight[1])
	tracks.position = Vector2(TRACKS_X.get(tier, 202), 284)
	var rear := length()
	dusts[0].position = Vector2(rear - 60, 298)
	dusts[1].position = Vector2(rear - 20, 298)
	for rv in room_views:
		rv.queue_free()
	room_views.clear()
	if cab_view:
		cab_view.queue_free()
	cab_view = CabView.new()
	_rooms_root.add_child(cab_view)
	cab_view.setup(tier)
	var n := Data.SLOT_COUNT if empty else Game.slot_count()
	for slot in n:
		var rv := RoomView.new()
		rv.slot = slot
		rv.position = slot_local_pos(slot)
		_rooms_root.add_child(rv)
		room_views.append(rv)
	refresh_rooms()
	_refresh_mods()
	_sync_pets()


func _add_sprite(parent: Node, region: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Atlas.tex(region)
	s.centered = false
	s.position = pos
	parent.add_child(s)
	return s


func _add_wheel(pos: Vector2, rail: bool) -> void:
	var w := AnimatedSprite2D.new()
	w.sprite_frames = Atlas.rail_wheel_frames() if rail else Atlas.wheel_frames(Mods.level("offroad_wheels") > 0 and not Game.s.is_empty())
	w.position = pos
	w.set_meta("rail", rail)
	_wheels_root.add_child(w)
	wheels.append(w)


func slot_local_pos(slot: int) -> Vector2:
	if slot == Data.CAB_SLOT and cab_view:
		return cab_view.position
	if Game.s.is_empty():
		return Vector2(COLS[slot % 3], ROW0 - FLOOR_H * (slot / 3))
	var unit := Game.slot_unit(slot)
	var cell := Game.slot_cell(slot)
	var cols: Array = COLS if unit < 0 else TRAILER_COLS
	return Vector2(unit_x(unit) + cols[cell.x], ROW0 - FLOOR_H * cell.y)


## size of the whole room at `slot` (a large room spans 2-3 cells, v4.4)
func room_size(slot: int) -> Vector2:
	if slot == Data.CAB_SLOT and cab_view:
		return cab_view.size
	if Game.s.is_empty():
		return ROOM_SIZE
	var cells := Game.room_cells(slot)
	return Vector2(slot_local_pos(int(cells[-1])).x - slot_local_pos(int(cells[0])).x + ROOM_SIZE.x, ROOM_SIZE.y)


func slot_global_rect(slot: int) -> Rect2:
	var a := slot if Game.s.is_empty() else Game.room_anchor(slot)
	var p := body.to_global(slot_local_pos(a))
	return Rect2(p, room_size(a) * global_scale)


## rect in the vehicle's own space (no body bob) – used by the camera so close-ups don't jitter
func slot_rect(slot: int) -> Rect2:
	var a := slot if Game.s.is_empty() else Game.room_anchor(slot)
	return Rect2(to_global(slot_local_pos(a)), room_size(a))


## the room (anchor cell) under a point; any cell of a large room answers with its anchor
func slot_at(global_pos: Vector2) -> int:
	if cab_view and cab_view.has_global_point(global_pos):
		return Data.CAB_SLOT
	for rv in room_views:
		var cell := Rect2(body.to_global(slot_local_pos(rv.slot)), ROOM_SIZE * global_scale)
		if cell.has_point(global_pos):
			return Game.room_anchor(rv.slot)
	return -1


## is the point on the convoy's hull at all (for the tap-to-peek X-ray)
func hull_has_point(global_pos: Vector2) -> bool:
	var l := to_local(global_pos)
	return l.x >= 0.0 and l.x <= length() and l.y >= roof_y() - 10.0 and l.y <= ROAD_Y


func solar_global_rect() -> Rect2:
	return Rect2(to_global(Vector2(60, 4 + roof_dy())), Vector2(64, 32))


## how far the roof crew stands above the roof (0 without a deck)
static func deck_lift() -> float:
	return float(ROOF_DECK_H) if Mods.level("roof_deck") > 0 else 0.0


## top of the vehicle incl. roof props (local y) – the camera keeps this on screen
func top_y() -> float:
	return roof_y() - 40.0 - deck_lift()


func refresh_rooms() -> void:
	if Game.s.is_empty():
		return
	if Game.tier() != tier or Game.trailers() != n_trailers or room_views.size() != Game.slot_count():
		rebuild()
		return
	_sync_large_rooms()
	for rv in room_views:
		rv.refresh()
	if cab_view:
		cab_view.refresh()


## large rooms: the anchor view spans its cells, annex views hide, and the strips of interior hidden behind
## the hull's partition wall / ladder shaft are re-drawn above the shell
func _sync_large_rooms() -> void:
	for ch in _seams_root.get_children():
		ch.queue_free()
	for rv in room_views:
		rv.seams.clear()
	for rv in room_views:
		var annex := Game.is_annex(rv.slot)
		rv.visible = not annex
		if annex:
			continue
		var cells := Game.room_cells(rv.slot)
		var x0 := slot_local_pos(rv.slot).x
		var xs: Array = []
		for c in cells:
			xs.append(slot_local_pos(int(c)).x - x0)
		rv.set_cells(xs)
		if xs.size() <= 1:
			continue
		var key := rv.wide_key(str(Game.s.rooms[rv.slot].type))
		if not Atlas.has(key):
			continue
		for i in range(1, xs.size()):
			var gx := float(xs[i - 1]) + RoomView.W
			var gw := float(xs[i]) - gx
			if gw <= 0.0:
				continue
			var sm := Sprite2D.new()
			sm.centered = false
			sm.texture = Atlas.sub(key, Rect2(gx, 0, gw, RoomView.H))
			sm.position = slot_local_pos(rv.slot) + Vector2(gx, 0)
			_seams_root.add_child(sm)
			rv.seams.append(sm)
		rv.set_glow(rv._glow)


func set_build_highlight(on: bool, room_type: String = "") -> void:
	for rv in room_views:
		rv.build_highlight = on and Game.is_slot_unlocked(rv.slot) and Game.s.rooms[rv.slot].type == "empty"
		rv.preview_type = room_type if rv.build_highlight else ""
		rv.queue_redraw()
	if on:
		peek(9999.0)
	else:
		_xray_hold = 0.0


func spark() -> void:
	_sparks.restart()
	_sparks.emitting = true


func actor_for(did: int) -> Node2D:
	for rv in room_views:
		if rv.actors.has(did):
			return rv.actors[did]
	if cab_view and cab_view.actors.has(did):
		return cab_view.actors[did]
	return null


func all_actors() -> Array:
	var out := []
	for rv in room_views:
		out.append_array(rv.actors.values())
	if cab_view:
		out.append_array(cab_view.actors.values())
	return out


# ------------------------------------------------------------------ X-ray (cut-away) toggle
func set_xray(on: bool) -> void:
	xray = on


## temporarily show the inside (tap on the closed hull, close-ups, build mode)
func peek(sec: float = 5.0) -> void:
	_xray_hold = maxf(_xray_hold, sec)


func is_open_view() -> bool:
	return xray or _xray_hold > 0.0


# ------------------------------------------------------------------ pets roaming the vehicle
func _sync_pets() -> void:
	if Game.s.is_empty():
		return
	var want: Array = Game.s.get("pets", [])
	if pets_root.get_child_count() == want.size():
		return
	for ch in pets_root.get_children():
		ch.queue_free()
	for p in want:
		var a := PetActor.new()
		pets_root.add_child(a)
		a.setup(self, str(p.kind), str(p.name))


# ------------------------------------------------------------------ exterior mods on the model
func _mod_sprite(region: String, pos: Vector2) -> Sprite2D:
	return _add_sprite(_mods_root, region, pos)


func _refresh_mods() -> void:
	for ch in _mods_root.get_children():
		ch.queue_free()
	if Game.s.is_empty():
		return
	var dy := roof_dy()
	var vd := Game.vehicle_def()
	var ram := Mods.level("spike_ram")
	if ram > 0:
		_mod_sprite("mod_spike_ram_%d" % mini(ram, 3), Vector2(-20, 242))
	var tur := Mods.level("roof_turret")
	if tur > 0:
		_mod_sprite("mod_roof_turret_%d" % mini(tur, 3), Vector2(200, ROOF_Y + dy - 18))
	var deck := Mods.level("roof_deck")
	if deck > 0:
		_mod_sprite("mod_roof_deck_%d" % mini(deck, 3), Vector2(ROOF_DECK_X, ROOF_Y + dy - 60))
	for k in mini(Mods.level("fuel_tanks"), 3):
		var fy := 140 - 24 * k
		if fy > roof_y() + 6:
			_mod_sprite("mod_fuel_tank", Vector2(20 if tier == "rig" else 40, fy))
		else:
			_mod_sprite("mod_fuel_tank", Vector2(232 - 16 * k, roof_y() - 22))
	var arm := Mods.level("armor_plates")
	if arm > 0:
		# (the rig's cab armour plate is gone since v4.6: the engine room sits there)
		var plated := floors if arm >= 3 else (mini(2, floors) if arm == 2 else 0)
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
	var susp := Mods.level("suspension")
	if susp > 0 and not vd.get("rail", false):
		for w in vd.wheels:
			_mod_sprite("mod_shock_%d" % mini(susp, 3), Vector2(float(w[0]) - 4, 252))
	var has_tracks: bool = Mods.level("tracks") > 0 and not vd.get("rail", false)
	tracks.visible = has_tracks
	var rear_wheels := []
	if has_tracks:
		for w in vd.wheels:
			if float(w[0]) > 100.0:
				rear_wheels.append(Vector2(w[0], w[1]))
	var off := Mods.level("offroad_wheels") > 0
	for w in wheels:
		if not w.get_meta("rail", false):
			w.visible = not rear_wheels.has(w.position)
			w.sprite_frames = Atlas.wheel_frames(off)


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
		rv.ambience.night = night
	if cab_view:
		cab_view.set_glow(warm)
		cab_view.ambience.night = night
	headlight.visible = night > 0.15 or Game.s.get("weather", "") in ["storm", "fog", "sandstorm", "snow", "ashfall"]
	headlight.modulate.a = clampf(maxf(night, 0.5), 0.0, 1.0)
	antenna_light.modulate = Color("ff5a4a") * Color(inv.r, inv.g, inv.b) if night > 0.3 else Color("ff5a4a")


func _process(delta: float) -> void:
	if Game.s.is_empty():
		return
	_t += delta
	_xray_hold = maxf(0.0, _xray_hold - delta)
	var want := 0.0 if is_open_view() else 1.0
	if not is_equal_approx(_ext_alpha, want):
		_ext_alpha = move_toward(_ext_alpha, want, delta * 4.0)
		# stepped fade (4 levels) so the hull "slides" open in a pixel-art way
		_exteriors.modulate.a = floorf(_ext_alpha * 4.0) / 4.0
	var f := Game.speed_factor() if Game.started else TITLE_CRUISE
	_speed = move_toward(_speed, f, delta * 0.7)
	var moving := _speed > 0.02
	for w in wheels:
		if moving:
			if not w.is_playing():
				w.play_backwards("default")
			w.speed_scale = 2.4 * _speed * (1.6 if w.get_meta("rail", false) else 1.0)
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
		d.emitting = moving and not Game.vehicle_def().get("rail", false)
		if d is GPUParticles2D:
			(d as GPUParticles2D).amount_ratio = clampf(_speed, 0.2, 1.0)
	if smoke is GPUParticles2D:
		(smoke as GPUParticles2D).speed_scale = 1.0 + _speed * 0.8
	antenna_light.visible = fmod(_t, 1.6) < 0.25
	_bump_t -= delta
	if moving and _bump_t <= 0.0:
		_bump_t = randf_range(0.18, 0.55) / maxf(_speed, 0.3)
		_bump = -2.0 if randf() < 0.15 else -1.0
		if Game.vehicle_def().get("rail", false):
			_bump = -1.0 if randf() < 0.3 else 0.0     # rails are smoother
	_bump = move_toward(_bump, 0.0, delta * 14.0)
	# engine rumble: the body buzzes 1 px while the engine runs (driving, title backdrop), slower when idling
	_rumble_t -= delta
	if _rumble_t <= 0.0:
		var engine_on := moving or not Game.started or bool(Game.s.get("traveling", false))
		_rumble = -1.0 if engine_on and _rumble == 0.0 else 0.0
		_rumble_t = randf_range(0.06, 0.1) if moving else randf_range(0.1, 0.16)
	body.position.y = round(minf(_bump, _rumble))
	var sun := Game.sun_level()
	var az := clampf((float(Game.s.tod) - 0.25) / 0.5, 0.0, 1.0)
	var frame := 2
	if sun > 0.0 and Game.s.weather != "sandstorm":
		var span := 2.0 if Game.s.solar.tracking else 1.0
		frame = clampi(int(round(2.0 + lerpf(-span, span, az))), 0, 4)
	for s in solars:
		s.texture = Atlas.tex("solar_%d" % frame)
		s.modulate = Color(1, 0.55, 0.5) if float(Game.s.solar.get("damage", 0.0)) > 0.3 and int(_t * 3.0) % 2 == 0 else Color.WHITE
