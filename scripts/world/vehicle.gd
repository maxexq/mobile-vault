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
const WALL_DRUMS := ["rig", "bus", "bastion"]   # tiers whose spare fuel drums stack on the front (others: on the roof)
const SHELL_H := 300              # height of a 4-floor (or smaller) shell; taller shells sit above it
const ROW0 := 210                 # y of the bottom floor's rooms
const MAIN_W := 280.0
const TRAILER_W := 248.0
const TRACKS_X := {"van": 200, "bus": 200, "bastion": 200, "rig": 202}
const SOLAR_X := [79, 105]
const TITLE_CRUISE := 0.35         # title-screen backdrop speed (matches the road scroll in background.gd)
## body rumble + road bumps strength x (tune fx.engine_shake; 1.0 = before MV-176, players felt dizzy at full)
const ENGINE_SHAKE := 0.5
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
## MV-388 phase 3 idle motion (switch vehicle_ambience): roof flag (the shells no longer carry it), rear chain,
## mudflap behind the rearmost road tyre, exhaust puffs instead of the smoke emitter, rain runoff off the roof
const FLAG_POS := Vector2(115, 4)         # relative to a 4-floor roof (in _roof_root)
const CHAIN_POS := Vector2(266, 263)      # + rear_shift()
const PUFF_GAP := 1.0                     # x the spec ranges: driving 0.8-1.4 s, parked idle 2.5-4 s (tune vehicle.puff_gap)
const DRIP_GAP := 4.5                     # s between roof drips in rain on average (3-6 s, tune vehicle.drip_gap)
## MV-462 cozy roof (switch cozy_roof): roof parts in _roof_root (4-floor roof-local, = truck.ROOF_PARTS); off =
## roof_legacy_<tier>, the old planters / tank / dish lifted out of the shell, at ROOF_LEGACY_X
const ROOF_PARTS := {"prop_roof_planter_tray": [Vector2(40, 21), Vector2(54, 21)],
	"prop_roof_water_tank": [Vector2(150, 16)], "prop_roof_satellite_dish": [Vector2(156, 0)]}
const ROOF_LEGACY_X := 38
## MV-519 driving cabs: Viktor is baked into every veh_/ext_ shell (decal_<tier>_driver_cockpit at these anchors);
## switch driver_cab now and then shows one of its idle frames over the window: 1 = he blinks, 2 = the dash
## indicator goes dark, 3 = his hand nudges the wheel. Frame 0 is the baked look, so between moves nothing is drawn.
const DRIVER_CAB := {"van": Vector2(11, 153), "bus": Vector2(18, 195), "bastion": Vector2(18, 195), "rig": Vector2(17, 193), "train": Vector2(18, 66)}
const DRIVER_GAP := 4.0                   # s between moves on average (tune vehicle.driver_gap)
const DRIVER_ACTS := {"blink": [[1, 0.14]], "lamp": [[2, 0.2], [0, 0.16], [2, 0.2]], "wheel": [[3, 0.45]]}
## MV-715 world v2 phase 1 (switch world_v2): the van is Dr. Ren's ambulance with the v3 rooms + crew, drawn at
## V2_K (= half size: with world_2x every v3 pixel stays a real pixel). Shell: assets/vehicles/ambulance_v3 (the
## same art as the v3 interior, InteriorV3Panel.AMB_*). In vehicle px: shell left at V2_X, cells 72x48 at
## COLS[0] + 76 * col, floors 56 apart (= FLOOR_H), the wheels on ROAD_Y.
const V2_K := 0.5
const V2_X := 0.0                 # the cab's bumper at the van's front
const V2_W := 319.0               # 638 shell px: 39 px longer than the van, so everything behind it moves back
const V2_CELL := Vector2(72, 48)
const V2_STRIDE := 76.0
## MV-721: under road_train the rig is the B-double road train (assets/vehicles/road_train_v3, InteriorV3Panel.RT_*):
## the prime mover + lead trailer body, 694 shell px (347 here, 67 longer than the old rig). Same cell grid and K.
const V2_W_RT := 347.0
## MV-721: behind the world v2 road train the trailers are the red container shells of the v3 interior (trailer_f<n>.png,
## 500 shell px = 250 here), their nose riding on the unit in front (no gap, no old drawbar / single front wheel)
const V2_TW_RT := 250.0
## MV-736: the world v2 Decker bus (switch decker, tier bus): 640 shell px (InteriorV3Panel.DK_*), same cell grid and K
const V2_W_DK := 320.0
var v2_tshells: Array[Sprite2D] = []
var _pups_up := false              # MV-737: v2_tshells are the ambulance's pups

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
var _detail_root: Node2D        # MV-388 runtime chassis details (leaf springs), switch vehicle_detail
var flag: AnimatedSprite2D      # MV-388 phase 3 idle motion
var chain: AnimatedSprite2D
var mudflap: AnimatedSprite2D
var puffs: Array[AnimatedSprite2D] = []
var drip: AnimatedSprite2D
var _flap_root: Node2D          # behind the wheels
var _puff_t := 0.0
var _drip_t := 0.0
var _flap_t := 0.0
var driver_cab: Sprite2D          # MV-519 cab micro-animation, above the closed hull (both views carry the cab)
var _driver_t := 2.0
var _driver_left := 0.0
var _driver_seq: Array = []       # [[frame, s], ...] still to show
var _shells: Node2D
var _floor_ghost: Sprite2D = null       # MV-563: next Vault level's floor at half opacity
var _ghost_tw: Tween = null
var _seams_root: Node2D          # large-room interior strips drawn over the hull partitions (v4.4)
var _exteriors: Node2D
var _rooms_root: Node2D
var _mods_root: Node2D
var mod_motion: ExteriorModMotion # MV-565: pooled exterior details and local strips
var _roof_root: Node2D
var _roof_parts: Node2D          # MV-462: under the solar panels, rebuilt by _sync_roof
var pets_root: Node2D
var _bump_t := 0.0
var _bump := 0.0
var _rumble_t := 0.0
var _rumble := 0.0
var _rumble_on := false
var _sparks: Node2D
var _speed := 0.0
var _t := 0.0
var v2 := false                  # MV-715 world v2 body (ambulance + v3 rooms) is up
var v2_root: Node2D              # scale V2_K: ambulance shell over RoomV3Cell per main-body slot
var v2_shell: Sprite2D
var v2_cells: Dictionary = {}    # slot -> RoomV3Cell
var _v2_tick := 0.0
var amb := AmbulanceMotion.new()  # MV-726 wheels / suspension / lights / flag on the world v2 ambulance
var amb_on := false
var debug_speed := -1.0           # GOD MODE / autotest: speed factor to show (>= 0), the game's own speed otherwise
var _night := 0.0


static func roof_dy_for(n_floors: int) -> float:
	return float(FLOOR_H * (4 - n_floors))


## offset of the roof from the 4-floor roof (positive = lower)
func roof_dy() -> float:
	if v2_rt():
		return v2_top() + 48.0 - ROOF_Y      # the road train's roof slab is 97 shell px under the shell top
	if v2_dk():
		if tier == "bastion":
			return v2_top() + 18.0 - ROOF_Y  # MV-738: the Bastion box top is 36 shell px under the shell top
		return v2_top() + 20.0 - ROOF_Y      # MV-736: the bus roof rail sits 40 shell px under the shell top
	if v2:
		return v2_top() + 40.0 - ROOF_Y      # the ambulance roof deck is 80 shell px above the top floor's cells
	return roof_dy_for(floors)


## MV-715: is the van drawn as the world v2 ambulance (switch world_v2, v3 art loaded, a shell for its floors)?
static func v2_wanted() -> bool:
	if not Features.on("world_v2") or Game.s.is_empty() or not V3Art.ok() or Game.floors() < 1:
		return false
	if Game.tier() == "rig" and Features.on("road_train"):
		return Game.floors() <= 3 and ResourceLoader.exists(InteriorV3Panel.RT_DIR + "body_f%d.png" % Game.floors())
	if Game.dk_tier():
		return Game.floors() >= 2 and Game.floors() <= 3 \
			and ResourceLoader.exists(str(InteriorV3Panel.shell_spec(Game.tier()).dir) + "shell_f%d.png" % Game.floors())
	return Game.tier() == "van" and Game.floors() <= 5 \
		and ResourceLoader.exists(InteriorV3Panel.AMB_DIR + "shell_f%d.png" % Game.floors())


## MV-721: is the world v2 body the road train (else the ambulance)?
func v2_rt() -> bool:
	return v2 and tier == "rig"


## MV-736/738: is the world v2 body the Decker bus or Bastion 42-B (both 640 shell px)?
func v2_dk() -> bool:
	return v2 and (tier == "bus" or tier == "bastion")


## the world v2 body's shell texture for the current floors
func v2_shell_path() -> String:
	if v2_rt():
		return InteriorV3Panel.RT_DIR + "body_f%d.png" % floors
	return str(InteriorV3Panel.shell_spec(tier).dir) + "shell_f%d.png" % floors


## local y of the ambulance shell's top edge (its tyres stand on ROAD_Y)
func v2_top() -> float:
	var base := 268.0 if v2_rt() else float(InteriorV3Panel.shell_spec(tier).base)
	return ROAD_Y + 1.0 - (base + 112.0 * float(floors - 1)) * V2_K


## top-left of a main-body cell of the ambulance (floor 0 at the bottom)
func v2_cell_pos(col: int, fl: int) -> Vector2:
	if v2_rt():
		return Vector2(V2_X + (InteriorV3Panel.RT_X0 + 152.0 * col) * V2_K,
			v2_top() + (InteriorV3Panel.RT_Y0 + InteriorV3Panel.RT_FH * float(floors - 1 - fl)) * V2_K)
	var sp := InteriorV3Panel.shell_spec(tier)
	return Vector2(V2_X + (float(sp.x0) + 152.0 * col) * V2_K,
		v2_top() + (float(sp.y0) + InteriorV3Panel.AMB_FH * float(floors - 1 - fl)) * V2_K)


func roof_y() -> float:
	return ROOF_Y + roof_dy()


func unit_x(unit: int) -> float:
	if unit < 0:
		return 0.0
	if v2_pup_trailers():
		return V2_X + (InteriorV3Panel.PUP_X0 + InteriorV3Panel.PUP_STEP * unit) * V2_K
	if v2_rt_trailers():
		return V2_X + V2_W_RT + V2_TW_RT * unit
	return MAIN_W + v2_extra() + TRAILER_W * unit


## MV-721: are the trailers drawn as the road train's container shells (world v2 road train + trailer art for them)?
func v2_rt_trailers() -> bool:
	return v2_rt() and n_trailers > 0 and ResourceLoader.exists(InteriorV3Panel.RT_DIR + "trailer_f%d.png" % v2_trailer_floors())


## MV-737: are the ambulance's trailers drawn as the approved pup shell (world v2 ambulance, switch ambulance_pup)?
func v2_pup_trailers() -> bool:
	return v2 and tier == "van" and n_trailers > 0 and Features.on("ambulance_pup") and v2_trailer_floors() == 2 \
		and ResourceLoader.exists(InteriorV3Panel.PUP_DIR + "pup_f2.png")


## trailers drawn as their own v3 shells (road train containers or ambulance pups) instead of the old trailer sprites
func v2_shell_trailers() -> bool:
	return v2_rt_trailers() or v2_pup_trailers()


func v2_trailer_floors() -> int:
	return Data.TRAILER_SLOTS / Data.ROOMS_PER_FLOOR


## top-left of a trailer cell of the road train (floor 0 at the bottom)
func v2_trailer_cell_pos(unit: int, col: int, fl: int) -> Vector2:
	var tf := v2_trailer_floors()
	if v2_pup_trailers():
		var ptop := ROAD_Y + 1.0 - InteriorV3Panel.PUP_H * V2_K
		return Vector2(unit_x(unit) + (InteriorV3Panel.PUP_CX0 + 152.0 * col) * V2_K,
			ptop + (InteriorV3Panel.PUP_CY0 + 112.0 * float(tf - 1 - fl)) * V2_K)
	var top := ROAD_Y + 1.0 - (268.0 + 112.0 * float(tf - 1)) * V2_K
	return Vector2(unit_x(unit) + (InteriorV3Panel.RT_TX0 + 152.0 * col) * V2_K,
		top + (InteriorV3Panel.RT_Y0 + InteriorV3Panel.RT_FH * float(tf - 1 - fl)) * V2_K)


## how far the convoy's rear deck moved back because of trailers (and the longer world v2 ambulance)
func rear_shift() -> float:
	if v2_pup_trailers():
		return unit_x(n_trailers - 1) + InteriorV3Panel.PUP_REAR * V2_K - MAIN_W
	if v2_rt_trailers():
		return unit_x(n_trailers) - MAIN_W
	return TRAILER_W * n_trailers + v2_extra()


func v2_extra() -> float:
	if not v2:
		return 0.0
	return (V2_W_RT if v2_rt() else (V2_W_DK if v2_dk() else V2_W)) - MAIN_W


func length() -> float:
	return MAIN_W + rear_shift()


func _ready() -> void:
	_flap_root = Node2D.new()
	add_child(_flap_root)
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
	# above the wheels (they are outside body), under the shell: the springs show in the wheel-well gaps
	_detail_root = Node2D.new()
	body.add_child(_detail_root)
	_shells = Node2D.new()
	body.add_child(_shells)
	_seams_root = Node2D.new()
	body.add_child(_seams_root)
	_roof_root = Node2D.new()
	body.add_child(_roof_root)
	_roof_parts = Node2D.new()
	_roof_root.add_child(_roof_parts)
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
	_build_idle_motion()
	_mods_root = Node2D.new()
	body.add_child(_mods_root)
	_exteriors = Node2D.new()
	_exteriors.modulate.a = 0.0
	body.add_child(_exteriors)
	driver_cab = Sprite2D.new()
	driver_cab.centered = false
	driver_cab.visible = false
	body.add_child(driver_cab)
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
	mod_motion = ExteriorModMotion.new()
	body.add_child(mod_motion)
	mod_motion.setup(self)

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
	Features.changed.connect(func():
		if v2 != v2_wanted() or amb_on != amb_wanted() or _pups_drawn() != v2_pup_trailers():
			rebuild()
			return
		_sync_detail()
		_sync_roof()
		_sync_pets_view()
		_refresh_mods())
	add_to_group("vehicle_fx")
	rebuild()


## (re)creates shells, wheels and room views for the current tier + trailers
func rebuild() -> void:
	var empty := Game.s.is_empty()
	tier = "rig" if empty else Game.tier()
	floors = 4 if empty else Game.floors()
	n_trailers = 0 if empty else Game.trailers()
	v2 = v2_wanted()
	_pups_up = false
	var vd: Dictionary = Data.VEHICLES.get(tier, Data.VEHICLES.rig)
	var dy := roof_dy()
	for n in [_shells, _exteriors, _wheels_root]:
		for ch in n.get_children():
			ch.queue_free()
	wheels.clear()
	_clear_floor_ghost()
	# MV-563: a body grown by the Vault draws vehf<n>_ / extf<n>_; the 5-floor ones are taller, bottom-aligned
	var sh := _add_sprite(_shells, shell_region("veh", tier, floors), Vector2.ZERO)
	sh.position.y = SHELL_H - sh.texture.get_height()
	_driver_seq.clear()
	driver_cab.visible = false
	var ex := _add_sprite(_exteriors, shell_region("ext", tier, floors), Vector2.ZERO)
	ex.position.y = SHELL_H - ex.texture.get_height()
	sh.visible = not v2           # world v2: the ambulance shell replaces the van's (cut-away only, no closed hull)
	ex.visible = not v2
	var kind: String = vd.get("trailer", "trailer")
	for t in (0 if v2_shell_trailers() else n_trailers):
		var x := unit_x(t)
		_add_sprite(_shells, "veh_" + kind, Vector2(x, 0))
		_add_sprite(_exteriors, "ext_" + kind, Vector2(x, 0))
		for w in (WAGON_WHEELS if kind == "wagon" else TRAILER_WHEELS):
			_add_wheel(Vector2(x, 0) + w, kind == "wagon")
	if vd.get("rail", false):
		for w in TRAIN_WHEELS:
			_add_wheel(w, true)
	elif not v2:                  # the ambulance's axles are part of its shell
		for w in vd.wheels:
			_add_wheel(Vector2(w[0], w[1]), false)
	_roof_root.position = Vector2(0, dy)
	_sync_roof()
	smoke.position = Vector2(vd.chimney[0], vd.chimney[1])
	headlight.position = Vector2(vd.headlight[0], vd.headlight[1])
	if v2:                        # exhaust stack tip behind the cab, headlight at the bumper
		smoke.position = v2_cell_pos(0, 0) + (Vector2(-9, -16) if v2_rt() else Vector2(-9, -22))
		headlight.position = v2_cell_pos(0, 0) + (Vector2(-109, 36) if v2_rt() else Vector2(-71, 34))
		if v2_dk():               # MV-736: rear engine: exhaust over the rear grille, headlight at the flat front
			smoke.position = v2_cell_pos(2, 0) + Vector2(91, 77)   # MV-739: the tail pipe under the rear bumper
			headlight.position = v2_cell_pos(0, 0) + Vector2(-45, 51)
			if tier == "bastion":     # MV-738: front engine: snorkel top over the nose, headlight on the hood front
				smoke.position = v2_cell_pos(0, 0) + Vector2(-36, -25)
				headlight.position = v2_cell_pos(0, 0) + Vector2(-72, 41)
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
	_build_v2()
	refresh_rooms()
	_refresh_mods()
	_sync_pets()


## MV-715: (re)build the world v2 body: v3 room cells for the main body's slots under the ambulance shell; the
## old room views of those slots stay (game logic, close-ups) but are hidden
func _build_v2() -> void:
	for c in v2_cells.values():
		c.queue_free()
	v2_cells.clear()
	if v2_root == null:
		v2_root = Node2D.new()
		v2_root.name = "WorldV2"
		v2_root.scale = Vector2.ONE * V2_K
		body.add_child(v2_root)
		body.move_child(v2_root, _seams_root.get_index() + 1)
		v2_shell = Sprite2D.new()
		v2_shell.name = "AmbulanceShell"
		v2_shell.centered = false
		v2_root.add_child(v2_shell)
	v2_root.visible = v2
	_sync_pets_view()
	_roof_root.visible = not v2   # the ambulance carries its own roof garden, flag and mast
	_mods_root.visible = not v2   # (old-van mod overlays: world v2 phase 2)
	if cab_view:
		cab_view.visible = not v2
	amb.clear()
	amb_on = false
	v2_root.position.x = 0.0
	for p in puffs:               # the old shells hide the puffs' start behind them; the ambulance's stack is in front
		body.move_child(p, (body.get_child_count() - 1) if v2 else smoke.get_index() + 1)
	if not v2:
		return
	v2_shell.texture = load(v2_shell_path())
	v2_shell.position = Vector2(V2_X, v2_top()) / V2_K
	InteriorV3Panel.attach_nose(v2_shell, v2_rt() or v2_dk())   # MV-731 bumper tip + tow hook in front of the shell
	_build_v2_trailers()
	for slot in Game.main_slots():
		var c := RoomV3Cell.new()
		c.slot = slot
		c.world_view = true      # MV-734: crew at full pixel size (a room pixel is one rendered pixel here)
		var cell := Game.slot_cell(slot)
		c.position = v2_cell_pos(cell.x, cell.y) / V2_K
		v2_root.add_child(c)
		v2_cells[slot] = c
	v2_root.move_child(v2_shell, v2_root.get_child_count() - 1)
	if amb_wanted():
		amb_on = true
		v2_shell.texture = AmbulanceMotion.cut_shell(floors, amb_dir())
		amb.build(floors, v2_shell.position, _wheels_root, v2_root, V2_K, amb_dir())
	_pups_on_top()
	for rv in room_views:
		if v2_cells.has(rv.slot):
			rv.visible = false
			rv.process_mode = Node.PROCESS_MODE_DISABLED   # hidden twin: no per-frame room / crew work (MV-715 perf)


## MV-721: the road train's container trailers, rearmost first so each nose rides over the unit behind it is covered
## by the unit in front (as in the v3 interior); cells under their own shell
func _build_v2_trailers() -> void:
	for sp in v2_tshells:
		sp.queue_free()
	v2_tshells.clear()
	_pups_up = v2_pup_trailers()
	if _pups_up:
		_build_v2_pups()
		return
	if not v2_rt_trailers():
		return
	var tex: Texture2D = load(InteriorV3Panel.RT_DIR + "trailer_f%d.png" % v2_trailer_floors())
	for u in range(n_trailers - 1, -1, -1):
		for i in Data.TRAILER_SLOTS:
			var slot := Game.main_slots() + u * Data.TRAILER_SLOTS + i
			if slot >= Game.slot_count():
				continue
			var c := RoomV3Cell.new()
			c.slot = slot
			var cell := Game.slot_cell(slot)
			c.position = v2_trailer_cell_pos(u, cell.x, cell.y) / V2_K
			v2_root.add_child(c)
			v2_cells[slot] = c
		var sp := Sprite2D.new()
		sp.name = "TrailerShell%d" % u
		sp.centered = false
		sp.texture = tex
		sp.position = Vector2(unit_x(u), ROAD_Y + 1.0 - tex.get_height() * V2_K) / V2_K
		v2_root.add_child(sp)
		v2_tshells.append(sp)


## MV-737: the ambulance's pups: cells first, then the shells front to rear (each tow plate over the unit in front);
## _pups_on_top() moves them over the ambulance shell once it is placed
func _build_v2_pups() -> void:
	var tex: Texture2D = load(InteriorV3Panel.PUP_DIR + "pup_f2.png")
	for u in n_trailers:
		for i in Data.TRAILER_SLOTS:
			var slot := Game.main_slots() + u * Data.TRAILER_SLOTS + i
			if slot >= Game.slot_count():
				continue
			var c := RoomV3Cell.new()
			c.slot = slot
			c.world_view = true      # MV-734: pup crew use the same pixel size as the main vehicle
			var cell := Game.slot_cell(slot)
			c.position = v2_trailer_cell_pos(u, cell.x, cell.y) / V2_K
			v2_root.add_child(c)
			v2_cells[slot] = c
	for u in n_trailers:
		var sp := Sprite2D.new()
		sp.name = "PupShell%d" % u
		sp.centered = false
		sp.texture = tex
		sp.position = Vector2(unit_x(u), ROAD_Y + 1.0 - InteriorV3Panel.PUP_H * V2_K) / V2_K
		v2_root.add_child(sp)
		v2_tshells.append(sp)


## the pup shells are up (to rebuild when the ambulance_pup switch flips)
func _pups_drawn() -> bool:
	return _pups_up


func _pups_on_top() -> void:
	if not v2_pup_trailers():
		return
	for sp in v2_tshells:
		v2_root.move_child(sp, v2_root.get_child_count() - 1)


## MV-726: the ambulance's own wheels / suspension / lights / flag (switch vehicle_anim; anchors from anim.json)
func amb_wanted() -> bool:
	if v2_dk() and tier == "bastion":
		return false              # MV-738: no wheel / suspension anchors for Bastion 42-B yet (static shell)
	if v2_dk():                   # MV-739: the Decker bus gets the same wheels / suspension / lights + its sign
		return Features.on("vehicle_anim") and AmbulanceMotion.ok(floors, AmbulanceMotion.DK_DIR)
	return v2 and tier == "van" and Features.on("vehicle_anim") and AmbulanceMotion.ok(floors)   # the road train (MV-721) has its own shells


## anchors / spin strip set for the current world v2 body
func amb_dir() -> String:
	return AmbulanceMotion.DK_DIR if v2_dk() else AmbulanceMotion.DIR


## atlas region of a main shell ("veh" / "ext") of this tier with n floors: its own shell, or the grown one
static func shell_region(kind: String, t: String, n: int) -> String:
	if t == "bastion":
		t = "bus"         # MV-738: no closed-hull atlas art of its own (world v2 draws its shell); fall back to the bus
	var grown := "%sf%d_%s" % [kind, n, t]
	return grown if n != int(Data.VEHICLES.get(t, Data.VEHICLES.rig).floors) and Atlas.has(grown) else "%s_%s" % [kind, t]


## MV-563: the floor the next Vault level adds (closed exterior), drawn at half opacity over the roof for sec seconds (the roof
## parts move up onto it meanwhile). False when the next level adds none.
func preview_next_floor(sec: float = 5.0) -> bool:
	_clear_floor_ghost()
	if Game.s.is_empty() or not Game.vault_adds_floor(int(Game.s.vault_level)):
		return false
	var n := Game.floors_at(int(Game.s.vault_level) + 1)
	var region := shell_region("ext", tier, n)      # the plated exterior: the new floor reads as a whole floor
	var full := Atlas.tex(region)
	var top := SHELL_H - full.get_height()                  # local y of the grown shell's top
	var cut := roof_y() + 6.0 - float(top)                  # down to just under the current roof slab
	_floor_ghost = Sprite2D.new()
	_floor_ghost.centered = false
	_floor_ghost.texture = Atlas.sub(region, Rect2(0, 0, full.get_width(), cut))
	_floor_ghost.position = Vector2(0, top)
	_floor_ghost.modulate.a = 0.5
	_floor_ghost.set_meta("region", region)
	body.add_child(_floor_ghost)
	var lift := roof_dy_for(n) - roof_dy()
	_roof_root.position.y = roof_dy_for(n)
	for m in _mods_root.get_children():         # roof turret, deck, solar covers... ride up with the roof
		if m is Node2D and (m as Node2D).position.y < roof_y() + 6.0:
			(m as Node2D).position.y += lift
	_ghost_tw = create_tween()
	_ghost_tw.tween_interval(sec)
	_ghost_tw.tween_callback(_clear_floor_ghost)
	return true


func floor_ghost() -> Sprite2D:
	return _floor_ghost if is_instance_valid(_floor_ghost) else null


func _clear_floor_ghost() -> void:
	if _ghost_tw != null:
		_ghost_tw.kill()
		_ghost_tw = null
	var was := _floor_ghost != null
	if is_instance_valid(_floor_ghost):
		_floor_ghost.queue_free()
	_floor_ghost = null
	if _roof_root != null:
		_roof_root.position.y = roof_dy()
	if was and not Game.s.is_empty():
		_refresh_mods()       # puts the roof mods back on the roof


func _add_sprite(parent: Node, region: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Atlas.tex(region)
	s.centered = false
	s.position = pos
	s.set_meta("region", region)     # MV-462: lets autotest / GOD read what is drawn
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
	if v2 and unit < 0:
		return v2_cell_pos(cell.x, cell.y)
	if v2_shell_trailers():
		return v2_trailer_cell_pos(unit, cell.x, cell.y)
	var cols: Array = COLS if unit < 0 else TRAILER_COLS
	return Vector2(unit_x(unit) + cols[cell.x], ROW0 - FLOOR_H * cell.y)


## size of the whole room at `slot` (a large room spans 2-3 cells, v4.4)
func room_size(slot: int) -> Vector2:
	if slot == Data.CAB_SLOT and cab_view:
		return cab_view.size
	if Game.s.is_empty():
		return ROOM_SIZE
	var cells := Game.room_cells(slot)
	var cs := cell_size(slot)
	return Vector2(slot_local_pos(int(cells[-1])).x - slot_local_pos(int(cells[0])).x + cs.x, cs.y)


## one cell of the room at `slot`: 64x52, or 72x48 in the world v2 ambulance
func cell_size(slot: int) -> Vector2:
	if v2 and slot != Data.CAB_SLOT and (Game.slot_unit(slot) < 0 or v2_shell_trailers()):
		return V2_CELL
	return ROOM_SIZE


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
		var cell := Rect2(body.to_global(slot_local_pos(rv.slot)), cell_size(rv.slot) * global_scale)
		if cell.has_point(global_pos):
			return Game.room_anchor(rv.slot)
	return -1


## is the point on the convoy's hull at all (for the tap-to-peek X-ray)
func hull_has_point(global_pos: Vector2) -> bool:
	var l := to_local(global_pos)
	return l.x >= (V2_X if v2 else 0.0) and l.x <= length() and l.y >= roof_y() - 10.0 and l.y <= ROAD_Y


func solar_global_rect() -> Rect2:
	return Rect2(to_global(Vector2(60, 4 + roof_dy())), Vector2(64, 32))


## how far the roof crew stands above the roof (0 without a deck)
static func deck_lift() -> float:
	return float(ROOF_DECK_H) if Mods.level("roof_deck") > 0 else 0.0


## top of the vehicle incl. roof props (local y) – the camera keeps this on screen
func top_y() -> float:
	return roof_y() - 40.0 - deck_lift() - (float(FLOOR_H) if floor_ghost() != null else 0.0)


## how hard the body shakes: tune fx.engine_shake, 0 when "car_shake" is off in settings (MV-176)
static func shake_scale() -> float:
	if not bool(Settings.get_value("car_shake")):
		return 0.0
	return Features.num("fx.engine_shake", ENGINE_SHAKE)


## a strength below 1 px on the 1 px grid: the fraction is how often the extra pixel shows,
## so 0.5 x a 1 px jolt = a 1 px jolt half as often (same total motion as half a pixel)
static func px_amp(a: float) -> float:
	var whole := floorf(a)
	return whole + (1.0 if randf() < a - whole else 0.0)


func refresh_rooms() -> void:
	if Game.s.is_empty():
		return
	if Game.tier() != tier or Game.floors() != floors or Game.trailers() != n_trailers or room_views.size() != Game.slot_count():
		rebuild()
		return
	if v2 != v2_wanted():
		rebuild()
		return
	_sync_large_rooms()
	for rv in room_views:
		rv.refresh()
		if v2_cells.has(rv.slot):
			rv.visible = false
			rv.process_mode = Node.PROCESS_MODE_DISABLED
	if cab_view:
		cab_view.refresh()
	for c in v2_cells.values():
		(c as RoomV3Cell).refresh()


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
		if room_type == RearGunner.TYPE and RearGunner.build_block(rv.slot) != "":
			rv.build_highlight = false     # MV-727: the gunner room only goes into a rear slot
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
	for c in v2_cells.values():        # world v2: the crew you see are the v3 actors
		if (c as RoomV3Cell).actors.has(did):
			return c.actors[did]
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
## MV-733: on the world v2 body the pets live in the v3 room cells (PetsV3, switch pets_v3); the old 16-bit pets
## only roam the old van view
func _sync_pets_view() -> void:
	if pets_root:
		pets_root.visible = not (v2 and PetsV3.on())


func _sync_pets() -> void:
	if Game.s.is_empty():
		return
	var want: Array = Game.s.get("pets", [])
	if pets_root.get_child_count() == want.size():
		return
	for ch in pets_root.get_children():
		# detach first: a node waiting for queue_free still counts as a child, so two pets adopted in one frame
		# made the count look right and the last one never appeared (MV-178)
		pets_root.remove_child(ch)
		ch.queue_free()
	for p in want:
		var a := PetActor.new()
		pets_root.add_child(a)
		a.setup(self, str(p.kind), str(p.name))


# ------------------------------------------------------------------ exterior mods on the model
func _mod_sprite(region: String, pos: Vector2) -> Sprite2D:
	# MV-566: the finer redraw (same size and anchor) while mod_detail_fine is on; meta "region" keeps the mod's name
	var fine := region + "_fine"
	var s := _add_sprite(_mods_root, fine if Features.on("mod_detail_fine") and Atlas.has(fine) else region, pos)
	s.set_meta("art", s.get_meta("region"))
	s.set_meta("region", region)
	return s


func _refresh_mods() -> void:
	for ch in _mods_root.get_children():
		_mods_root.remove_child(ch)
		ch.queue_free()
	if Game.s.is_empty():
		return
	var dy := roof_dy()
	var vd := Game.vehicle_def()
	var ram := Mods.level("spike_ram")
	if ram > 0:
		_mod_sprite("mod_spike_ram_%d" % mini(ram, 3), Vector2(-20, 242))
	var tur := Mods.level("roof_turret")
	if tur > 0 and not Combat.room_mode():     # MV-727: no roof gun with the room squad
		_mod_sprite("mod_roof_turret_%d" % mini(tur, 3), Vector2(200, ROOF_Y + dy - 18))
	var deck := Mods.level("roof_deck")
	if deck > 0:
		var deck_art := "mod_roof_deck_cozy_%d" if Features.on("cozy_roof") else "mod_roof_deck_%d"
		_mod_sprite(deck_art % mini(deck, 3), Vector2(ROOF_DECK_X, ROOF_Y + dy - 60))
	# the drums stack on a front face only where there is one (the rig's cab-over front, beside the bus's tall
	# nose) and only as high as the vehicle's own roof; elsewhere they ride on the roof. MV-563: on a body grown
	# by the Vault they used to hang in the air above the low van cab, and half behind the train's nose.
	var own_roof := ROOF_Y + roof_dy_for(int(vd.floors))
	var wall := tier in WALL_DRUMS
	for k in mini(Mods.level("fuel_tanks"), 3):
		var fy := 140 - 24 * k
		if wall and fy > own_roof + 6:
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
	var track_art := Atlas.track_frames(Features.on("mod_detail_fine"))
	if tracks.sprite_frames != track_art:
		tracks.sprite_frames = track_art
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
	_sync_detail()
	mod_motion.rebuild()


## MV-462: the cozy roof parts (water tank, dish, two planter trays) or, with cozy_roof off, the old ones
func _sync_roof() -> void:
	for ch in _roof_parts.get_children():
		_roof_parts.remove_child(ch)
		ch.queue_free()
	if not Features.on("cozy_roof"):
		_add_sprite(_roof_parts, "roof_legacy_" + ("bus" if tier == "bastion" else tier), Vector2(ROOF_LEGACY_X, 0))
		return
	for region in ROOF_PARTS:
		for pos in ROOF_PARTS[region]:
			_add_sprite(_roof_parts, region, pos)


## the atlas regions drawn now on the roof parts (roof=true) or as exterior mods (autotest)
func sprite_regions(roof: bool) -> Array:
	var out := []
	for ch in (_roof_parts if roof else _mods_root).get_children():
		if not ch.is_queued_for_deletion() and ch.has_meta("region"):
			out.append(str(ch.get_meta("region")))
	return out


## MV-388: a stock leaf spring above every road wheel (main vehicle + trailers). Not on rails; the main vehicle's
## springs give way to the heavy-suspension coil-overs, and the rear ones to the tracks.
func _sync_detail() -> void:
	for ch in _detail_root.get_children():
		_detail_root.remove_child(ch)
		ch.queue_free()
	if Game.s.is_empty() or not Features.on("vehicle_detail"):
		return
	var vd := Game.vehicle_def()
	var spots := []
	if not vd.get("rail", false) and Mods.level("suspension") == 0:
		var tracked: bool = Mods.level("tracks") > 0
		for w in vd.wheels:
			if not (tracked and float(w[0]) > 100.0):
				spots.append(float(w[0]))
	if str(vd.get("trailer", "trailer")) == "trailer" and not v2_shell_trailers():
		for t in n_trailers:
			for w in TRAILER_WHEELS:
				spots.append(unit_x(t) + w.x)
	for x in spots:
		var s := Sprite2D.new()
		s.texture = Atlas.tex("prop_car_leaf_spring")
		s.centered = false
		s.position = Vector2(x - 16.0, 266.0)
		_detail_root.add_child(s)


func leaf_springs() -> int:
	return _detail_root.get_child_count() if is_instance_valid(_detail_root) else 0


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
	_night = night
	headlight.visible = night > 0.15 or Game.s.get("weather", "") in ["storm", "fog", "sandstorm", "snow", "ashfall"]
	headlight.modulate.a = clampf(maxf(night, 0.5), 0.0, 1.0)
	antenna_light.modulate = Color("ff5a4a") * Color(inv.r, inv.g, inv.b) if night > 0.3 else Color("ff5a4a")


func _process(delta: float) -> void:
	if Game.s.is_empty():
		return
	_t += delta
	if v2:
		_v2_tick -= delta
		if _v2_tick <= 0.0:          # crew move / power-out / build progress, like the v3 interior
			_v2_tick = 0.5
			for c in v2_cells.values():
				(c as RoomV3Cell).refresh()
	_xray_hold = maxf(0.0, _xray_hold - delta)
	var want := 0.0 if is_open_view() else 1.0
	if not is_equal_approx(_ext_alpha, want):
		_ext_alpha = move_toward(_ext_alpha, want, delta * 4.0)
		# stepped fade (4 levels) so the hull "slides" open in a pixel-art way
		_exteriors.modulate.a = floorf(_ext_alpha * 4.0) / 4.0
	var f := Game.speed_factor() if Game.started else TITLE_CRUISE
	if debug_speed >= 0.0:
		f = debug_speed
	var was := _speed
	_speed = move_toward(_speed, f, delta * 0.7)
	var accel := (_speed - was) / maxf(delta, 0.001)
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
		d.emitting = moving and not Game.vehicle_def().get("rail", false) and not mod_motion.replaces_dust()
		if d is GPUParticles2D:
			(d as GPUParticles2D).amount_ratio = clampf(_speed, 0.2, 1.0)
	if smoke is GPUParticles2D:
		(smoke as GPUParticles2D).speed_scale = 1.0 + _speed * 0.8
	_tick_idle_motion(delta, moving)
	_tick_driver(delta)
	antenna_light.visible = fmod(_t, 1.6) < 0.25
	var k := shake_scale()
	_bump_t -= delta
	if moving and _bump_t <= 0.0:
		_bump_t = randf_range(0.18, 0.55) / maxf(_speed, 0.3)
		_bump = -px_amp((2.0 if randf() < 0.15 else 1.0) * k)
		if Game.vehicle_def().get("rail", false):
			_bump = -px_amp(k) if randf() < 0.3 else 0.0     # rails are smoother
		if amb_on and _bump < 0.0:
			amb.bump(_speed * AmbulanceMotion.ROAD_PX)        # the tyres take the bump first, front axle to rear
	_bump = move_toward(_bump, 0.0, delta * 14.0)
	# engine rumble: the body buzzes 1 px while the engine runs (driving, title backdrop), slower when idling;
	# every other beat is a buzz, and fx.engine_shake decides how many of those beats really move (MV-176)
	_rumble_t -= delta
	if _rumble_t <= 0.0:
		var engine_on := moving or not Game.started or bool(Game.s.get("traveling", false))
		_rumble_on = engine_on and not _rumble_on
		_rumble = -px_amp(k) if _rumble_on else 0.0
		_rumble_t = randf_range(0.06, 0.1) if moving else randf_range(0.1, 0.16)
	body.position.y = round(minf(_bump, _rumble))
	if amb_on:
		var engine := moving or not Game.started or bool(Game.s.get("traveling", false)) or debug_speed >= 0.0
		amb.tick(delta, _speed * AmbulanceMotion.ROAD_PX, accel, engine, _night, body.position.y,
			Combat.wave_active, EngineBay.state_key() == "broken")
	var sun := Game.sun_level()
	var az := clampf((float(Game.s.tod) - 0.25) / 0.5, 0.0, 1.0)
	var frame := 2
	if sun > 0.0 and Game.s.weather != "sandstorm":
		var span := 2.0 if Game.s.solar.tracking else 1.0
		frame = clampi(int(round(2.0 + lerpf(-span, span, az))), 0, 4)
	for s in solars:
		s.texture = Atlas.tex("solar_%d" % frame)
		s.modulate = Color(1, 0.55, 0.5) if float(Game.s.solar.get("damage", 0.0)) > 0.3 and int(_t * 3.0) % 2 == 0 else Color.WHITE


# ------------------------------------------------------------------ MV-388 phase 3: idle motion
func _strip(prefix: String, n: int, fps: float, loop: bool, parent: Node) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.centered = false
	a.sprite_frames = Atlas.strip_frames(prefix, n, fps, loop)
	parent.add_child(a)
	return a


## built once (pools, no per-frame nodes); rebuild() / _refresh_mods() only move them
func _build_idle_motion() -> void:
	flag = _strip("prop_car_flag_idle", 4, 3.0, true, _roof_root)
	flag.position = FLAG_POS
	# the chain hangs behind the shell (the deck covers its top), in its own node next to the leaf springs
	var chain_root := Node2D.new()
	body.add_child(chain_root)
	body.move_child(chain_root, _detail_root.get_index())
	chain = _strip("prop_car_chain_idle", 4, 2.0, true, chain_root)
	chain.frame = randi() % 4
	mudflap = _strip("prop_car_mudflap_idle", 4, 3.0, false, _flap_root)
	for i in 2:
		var p := _strip("fx_car_exhaust_puff", 6, 6.0, false, body)
		body.move_child(p, smoke.get_index() + 1)               # behind the shell, like the old emitter
		p.visible = false
		p.animation_finished.connect(p.hide)
		puffs.append(p)
	drip = _strip("fx_car_roof_rain_drip", 6, 6.0, false, body)
	drip.visible = false
	drip.animation_finished.connect(drip.hide)
	_flap_t = randf_range(6.0, 10.0)


func idle_motion_on() -> bool:
	return Features.on("vehicle_ambience") and not Game.s.is_empty()


## where the chain / mudflap / drip / puffs sit for the current tier, trailers and mods
func _place_idle_motion() -> void:
	var vd := Game.vehicle_def()
	chain.position = CHAIN_POS + Vector2(rear_shift(), 0)
	# mudflap behind the convoy's rearmost road tyre (trailer tyres are never under the tracks)
	var flap_x := -1.0
	if str(vd.get("trailer", "trailer")) == "trailer" and n_trailers > 0 and not v2_shell_trailers():
		flap_x = unit_x(n_trailers - 1) + TRAILER_WHEELS[-1].x + 16.0
	elif v2:
		flap_x = -1.0                 # world v2: the ambulance's axles are in its shell, no old-van mudflap
	elif not vd.get("rail", false) and not (vd.wheels as Array).is_empty():
		var rear: Array = vd.wheels[-1]
		if not (Mods.level("tracks") > 0 and float(rear[0]) > 100.0):
			flap_x = float(rear[0]) + 16.0
	mudflap.set_meta("x", flap_x)
	mudflap.position = Vector2(maxf(flap_x, 0.0), 276)
	var ch: Array = vd.get("chimney", [250, 272])
	for i in puffs.size():
		puffs[i].position = Vector2(float(ch[0]) + i * 2, float(ch[1]) - 14.0)
		if v2:                    # MV-726: from the ambulance's exhaust stack, not the old van's chimney
			puffs[i].position = smoke.position + Vector2(i * 2 - 4, -10.0)
	drip.position = Vector2(250, roof_y() + 6.0)


## combustion only: no puffs from an electric / fusion engine or silent mode, nor when broken, resting or held
## by a parked job. Cosmetic: nothing here touches fuel, wear, heat or speed.
func exhaust_burning() -> bool:
	if EngineBay.state_key() == "broken" or EngineBay.resting() or EngineBay.job_holds():
		return false
	var kind := str(EngineBay.t().get("fuel_kind", "fuel"))
	if kind == "power" or kind == "none":
		return false
	return not (EngineBay.mode() == "silent" and EngineBay.t().get("silent", false))


func _tick_idle_motion(delta: float, moving: bool) -> void:
	var on := idle_motion_on()
	_place_idle_motion()
	# flag: always there (the shells lost theirs); wind moves it, held on frame 0 when the switch is off
	if on:
		if not flag.is_playing():
			flag.play("default")
	elif flag.is_playing() or flag.frame != 0:
		flag.stop()
		flag.frame = 0
	chain.visible = on
	if on and not chain.is_playing():
		chain.play("default")
	var flap_x: float = mudflap.get_meta("x", -1.0)
	mudflap.visible = on and flap_x >= 0.0
	if mudflap.visible and not mudflap.is_playing():
		_flap_t -= delta
		if moving or _flap_t <= 0.0:
			_flap_t = randf_range(6.0, 10.0)
			mudflap.frame = 0
			mudflap.play("default")
	# exhaust: the new puffs replace the old emitter, never both
	smoke.emitting = not on
	if not on or not exhaust_burning():
		for p in puffs:
			p.visible = false
		_puff_t = minf(_puff_t, 0.5)
	else:
		_puff_t -= delta
		if _puff_t <= 0.0:
			puff_now(moving)
	# rain runoff: rain / storm only (acid rain keeps its own art), one drip at a time
	var wet: bool = str(Game.s.get("weather", "")) in ["rain", "storm"]
	if not on or not wet:
		drip.visible = false
		return
	_drip_t -= delta
	if _drip_t <= 0.0:
		drip_now()


## one exhaust puff now (max two at once); also GOD MODE's preview
func puff_now(moving: bool = true) -> bool:
	var k := Features.num("vehicle.puff_gap", PUFF_GAP)
	_puff_t = (randf_range(0.8, 1.4) if moving else randf_range(2.5, 4.0)) * k
	for p in puffs:
		if not p.visible:
			p.visible = true
			p.frame = 0
			p.play("default")
			return true
	return false


func drip_now() -> bool:
	_drip_t = randf_range(0.67, 1.33) * Features.num("vehicle.drip_gap", DRIP_GAP)
	if drip.visible:
		return false
	drip.visible = true
	drip.frame = 0
	drip.play("default")
	return true


func flap_now() -> void:
	if mudflap.visible:
		mudflap.frame = 0
		mudflap.play("default")


func driver_cab_on() -> bool:
	return Features.on("driver_cab") and not Game.s.is_empty()


## one driver move now ("blink" / "lamp" / "wheel"); also GOD MODE's preview
func driver_act(kind: String) -> bool:
	if not driver_cab_on() or not DRIVER_ACTS.has(kind):
		return false
	_driver_seq = (DRIVER_ACTS[kind] as Array).duplicate(true)
	_driver_step()
	_driver_t = randf_range(0.6, 1.4) * Features.num("vehicle.driver_gap", DRIVER_GAP)
	return true


func _driver_step() -> void:
	if _driver_seq.is_empty():
		driver_cab.visible = false
		return
	var st: Array = _driver_seq.pop_front()
	var f := int(st[0])
	if f > 0:
		driver_cab.texture = Atlas.tex("decal_%s_driver_cockpit_idle_%d" % [tier, f])
	driver_cab.set_meta("frame", f)
	driver_cab.visible = f > 0
	_driver_left = float(st[1])


func _tick_driver(delta: float) -> void:
	driver_cab.position = DRIVER_CAB.get(tier, DRIVER_CAB.rig)
	if not driver_cab_on() or v2:  # MV-726: the old van's cab frames floated beside the world v2 ambulance
		_driver_seq.clear()
		driver_cab.visible = false
		return
	if driver_cab.visible or not _driver_seq.is_empty():
		_driver_left -= delta
		if _driver_left <= 0.0:
			_driver_step()
		return
	_driver_t -= delta
	if _driver_t <= 0.0:
		driver_act(["blink", "blink", "lamp", "wheel"].pick_random())


func puffs_active() -> int:
	return puffs.filter(func(p): return p.visible).size()
