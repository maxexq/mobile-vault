extends Node2D
## Scene orchestrator.
##  Root window: canvas_items stretch + INTEGER scale (design size 360x640 portrait / 560x320 landscape).
##  The whole game world (parallax, truck, combat, weather, blur) renders inside a SubViewport at exactly
##  the design resolution, then gets scaled up by a whole number -> true pixel art: one pixel grid, no
##  mixels, even for particles, tweens and the close-up zoom. UI lives in a CanvasLayer on top.
##  Handles camera framing, swipe-to-pan, tap-to-zoom room close-up (integer zoom Tween + blur shader),
##  build placement, floating numbers, screen shake.
##  WIDE VIEW: zooming out keeps true pixels by rendering the world viewport larger and scaling it with a
##  smaller WHOLE number (S -> S-1 ...), e.g. 3 px per art pixel -> 2 px: more road, still crisp. Auto mode
##  pulls back for boss fights and long trailer convoys. Pinch / mouse wheel / the zoom button switch it.

const PAN_LIMIT := 220.0
const FIT_MARGIN := 4.0       # art px kept around the main body when a portrait phone zooms in (MV-148)
const FIT_CAP := 2.0          # portrait zoom-in stops at this many times the UI pixel scale
const SHAKE_SCALE := 0.5      # screen shake strength x (tune fx.shake; 1.0 = before MV-175)
const TAP_SLOP := 8.0
const PINCH_STEP := 1.25      # finger distance ratio for one pinch zoom step
const PORTRAIT_BASE := Vector2i(360, 640)
const LANDSCAPE_BASE := Vector2i(560, 320)

var world_vp: SubViewport
var world_tex: TextureRect
var world: Node2D
var background: Background
var vehicle: Vehicle
var combat_view: CombatView
var expedition_view: ExpeditionView
var chatter: Chatter
var canvas_mod: CanvasModulate
var camera: Camera2D
var weather: WeatherFX
var blur_rect: ColorRect
var blur_mat: ShaderMaterial
var crt: ColorRect
var hud: HUD

var cam_home := Vector2.ZERO
var pixel_scale := 1.0
var pan_x := 0.0
var pan_y := 0.0          # drag down to look up a tall (5-6 floor) truck
var pan_y_max := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragged := false
var _last_input_t := 0.0
var _closeup_slot := -1
var _zoom_tw: Tween
var _zf := 1.0
var _zoom_from := {}
var _placing := ""
var _shake := 0.0
var zoom_mode := "auto"          # normal | wide | auto
var world_scale := 1.0           # physical px per art pixel used by the world (whole number)
var view_k := 1.0                # world viewport px per UI/design px (S / world_scale)
var pan_right := PAN_LIMIT       # how far right a swipe may move the camera (world px), set by _fit_camera
var _touches := {}
var _pinch_d := 0.0


func _ready() -> void:
	add_to_group("shake")
	# ---- low-res world viewport (sized by hand so it can render wider than the UI for the wide view)
	var world_layer := CanvasLayer.new()
	world_layer.layer = 0
	add_child(world_layer)
	world_vp = SubViewport.new()
	world_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	world_vp.snap_2d_transforms_to_pixel = true
	world_vp.snap_2d_vertices_to_pixel = true
	world_vp.handle_input_locally = false
	world_vp.gui_disable_input = true
	world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world_vp)
	world_tex = TextureRect.new()
	world_tex.texture = world_vp.get_texture()
	world_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	world_tex.stretch_mode = TextureRect.STRETCH_SCALE
	world_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_layer.add_child(world_tex)
	world_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	world = Node2D.new()
	world.name = "World"
	world_vp.add_child(world)
	background = Background.new()
	background.name = "Background"
	world.add_child(background)
	vehicle = Vehicle.new()
	vehicle.name = "Vehicle"
	world.add_child(vehicle)
	combat_view = CombatView.new()
	combat_view.name = "Combat"
	world.add_child(combat_view)
	combat_view.setup(vehicle)
	expedition_view = ExpeditionView.new()
	expedition_view.name = "ExpeditionView"
	vehicle.add_child(expedition_view)
	vehicle.move_child(expedition_view, 0)
	expedition_view.setup(vehicle)
	chatter = Chatter.new()
	chatter.vehicle = vehicle
	chatter.combat_view = combat_view
	canvas_mod = CanvasModulate.new()
	world.add_child(canvas_mod)
	camera = Camera2D.new()
	world.add_child(camera)
	camera.make_current()

	weather = WeatherFX.new()
	weather.canvas_mod = canvas_mod
	weather.vehicle = vehicle
	world_vp.add_child(weather)
	weather.lightning.connect(func(): shake(2.0))

	var blur_layer := CanvasLayer.new()
	blur_layer.layer = 5
	world_vp.add_child(blur_layer)
	blur_rect = ColorRect.new()
	blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur_mat = ShaderMaterial.new()
	blur_mat.shader = load("res://shaders/focus_blur.gdshader")
	blur_rect.material = blur_mat
	blur_rect.visible = false
	blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur_layer.add_child(blur_rect)
	var chat_layer := CanvasLayer.new()
	chat_layer.layer = 6
	world_vp.add_child(chat_layer)
	chat_layer.add_child(chatter)

	# ---- UI
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	hud = HUD.new()
	ui_layer.add_child(hud)
	hud.build_placement_requested.connect(_enter_placement)
	hud.build_placement_cancelled.connect(_exit_placement)
	hud.room_closeup.closed.connect(_close_closeup)
	hud.title_screen.start_requested.connect(_on_start)
	hud.layout_changed.connect(_fit_camera)
	hud.zoom_pressed.connect(cycle_zoom)
	hud.xray_toggled.connect(func(on: bool): vehicle.set_xray(on))
	hud.tutorial_overlay.main = self
	Tutorial.hud = hud
	Tutorial.main = self
	# CRT scanlines / vignette over everything
	var crt_layer := CanvasLayer.new()
	crt_layer.layer = 50
	add_child(crt_layer)
	crt = ColorRect.new()
	crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := ShaderMaterial.new()
	cm.shader = load("res://shaders/crt.gdshader")
	crt.material = cm
	crt_layer.add_child(crt)
	crt.visible = bool(Settings.get_value("crt"))
	zoom_mode = str(Settings.get_value("zoom"))
	Settings.changed.connect(_on_setting_changed)
	# a switch like portrait_fit (GOD panel, remote features.json) reframes at once, not on the next 20-frame check
	Features.changed.connect(_on_features_changed)

	Game.floating_text.connect(_spawn_float)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()

	# live backdrop behind the title screen
	Game.setup_default_state()
	Game.s.weather = "rain"
	background._on_biome_changed(0, true)
	weather._set_weather("rain")
	vehicle.refresh_rooms()
	hud.title_screen.refresh_buttons()
	Cloud.pulled.connect(hud.title_screen.refresh_buttons)
	Cloud.conflict.connect(func(): hud.open_settings("data"))
	var args := OS.get_cmdline_user_args()
	if "--migrate-test" in args:
		var mt: Node = load("res://tools/migrate_test.gd").new()
		add_child(mt)
		return
	if "--balance" in args:
		var b: Node = load("res://tools/balance.gd").new()
		b.main = self
		add_child(b)
		return
	if "--autotest" in args:
		var t: Node = load("res://tools/autotest.gd").new()
		t.main = self
		add_child(t)


func _on_start(new_game: bool) -> void:
	if new_game or not Game.load_game():
		Game.new_game()
	vehicle.refresh_rooms()


# ------------------------------------------------------------------ resolution / camera
func is_portrait() -> bool:
	var real := Vector2(DisplayServer.window_get_size())
	return real.y >= real.x * 0.95


## Integer scale S = how many whole screen pixels one art pixel gets. The design size is then the
## window divided by S, so the picture fills the screen edge to edge with no letterbox bars.
func _on_resize() -> void:
	var real := Vector2(DisplayServer.window_get_size())
	var base := Vector2(PORTRAIT_BASE if is_portrait() else LANDSCAPE_BASE)
	var s := maxf(1.0, floorf(minf(real.x / base.x, real.y / base.y)))
	if Settings.get_value("ui_scale") == "small":
		s = maxf(1.0, s - 1.0)
	var want := Vector2i(int(floorf(real.x / s)), int(floorf(real.y / s)))
	want = Vector2i(maxi(want.x, 200), maxi(want.y, 200))
	if get_window().content_scale_size != want:
		get_window().content_scale_size = want
	pixel_scale = s
	_apply_world_scale()


## the world's whole-number scale (screen px per art px) for the current zoom mode: wide pulls back (S-1 ...);
## auto on a portrait phone zooms in to fill the screen (_fit_ws, MV-148); otherwise S
func target_ws() -> float:
	return _ws_for(zoom_mode)


func _ws_for(mode: String) -> float:
	var s := pixel_scale
	var wide := mode == "wide" or (mode == "auto" and _auto_wide())
	if _closeup_slot >= 0:
		wide = false
	if wide:
		return floorf(s * 0.67) if s >= 4.0 else maxf(1.0, s - 1.0)
	if mode == "auto":
		return maxf(s, _fit_ws())
	return s


## pinch / mouse wheel steps (MV-148): one mode per distinct zoom level right now, farthest first, so every step
## visibly moves and one step in never pulls back. Where modes look the same, auto stands for that level (it also
## follows bosses and, on a portrait phone, fills the screen): landscape with trailers = [auto, normal],
## a 780 px portrait phone = [wide, auto], a 1170 px one = [wide, normal, auto]
func zoom_ladder() -> Array:
	var by := {}
	for m in ["wide", "normal", "auto"]:
		by[_ws_for(m)] = m        # later wins on a tie: auto over normal over wide
	var levels := by.keys()
	levels.sort()
	return levels.map(func(w): return by[w])


## one pinch / wheel step: +1 closer, -1 farther; nothing (no toast) at either end. Spreading the fingers in
## normal when auto looks the same still switches to auto, so the gestures can always get back to it
func zoom_step(dir: int) -> void:
	var ladder := zoom_ladder()
	var cur := _ws_for(zoom_mode)
	var i := 0
	for k in ladder.size():
		if is_equal_approx(_ws_for(ladder[k]), cur):
			i = k
	if dir > 0 and ladder[i] == "auto" and zoom_mode != "auto":
		set_zoom_mode("auto")
		return
	var j := clampi(i + dir, 0, ladder.size() - 1)
	if j != i:
		set_zoom_mode(ladder[j])


## portrait fill (MV-148): the largest whole scale at which the main body (without trailers) fits the width the
## HUD leaves free and the whole vehicle fits its height. Trailers then sit off-screen and are reached by swiping.
## 0 = not in use (landscape, title screen, switch portrait_fit off)
func _fit_ws() -> float:
	if not Features.on("portrait_fit") or not is_portrait() or hud == null or not Game.started or Game.s.is_empty():
		return 0.0
	var free: Rect2 = hud.world_rect()
	var m := Features.num("view.fit_margin", FIT_MARGIN)
	var w := Vehicle.MAIN_W + 2.0 * m
	var h := Vehicle.ROAD_Y - (vehicle.top_y() - 6.0) + 12.0 + m
	var ws := floorf(minf(free.size.x * pixel_scale / w, free.size.y * pixel_scale / h))
	return minf(ws, floorf(pixel_scale * Features.num("view.fit_cap", FIT_CAP)))


## picks the world's whole-number scale for the current zoom mode and resizes the world viewport
func _apply_world_scale() -> void:
	var s := pixel_scale
	var ws := target_ws()
	world_scale = ws
	view_k = s / ws
	var design := Vector2(get_window().content_scale_size)
	# zoomed in, the viewport is rounded UP and the texture drawn at exactly vp * ws screen px (anchored top-left,
	# the overhang is off-screen) so every art pixel is ws screen px; zoomed out, the design size divides evenly
	var want := Vector2i(int(ceilf(design.x * view_k)), int(ceilf(design.y * view_k))) if view_k < 1.0 \
		else Vector2i(int(floorf(design.x * view_k)), int(floorf(design.y * view_k)))
	if world_vp.size != want:
		world_vp.size = want
	if view_k < 1.0:
		world_tex.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		world_tex.size = Vector2(want) / view_k
	elif world_tex.anchor_right != 1.0:
		world_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit_camera.call_deferred()


func _auto_wide() -> bool:
	if not Game.started or Game.s.is_empty():
		return false
	if not Combat.current_boss().is_empty():
		return true
	# a portrait phone fills the screen with the main body instead; trailers are a swipe away
	return Game.trailers() > 0 and _fit_ws() <= 0.0


func set_zoom_mode(m: String) -> void:
	zoom_mode = m
	Settings.set_value("zoom", m)
	_apply_world_scale()
	var auto_txt := Loc.t("มุมกล้อง: อัตโนมัติ (รถเต็มจอ ปัดดูโบกี้ ถอยกว้างตอนสู้บอส)") if _fit_ws() > 0.0 else Loc.t("มุมกล้อง: อัตโนมัติ (กว้างตอนสู้บอส/ลากพ่วง)")
	Game.toast.emit({"normal": Loc.t("มุมกล้อง: ปกติ"), "wide": Loc.t("มุมกล้อง: มุมกว้าง"), "auto": auto_txt}[m], "info")


func cycle_zoom() -> void:
	set_zoom_mode({"auto": "wide", "wide": "normal", "normal": "auto"}[zoom_mode])


func vp_size() -> Vector2:
	return Vector2(world_vp.size)


## frames the truck (+ the fight behind it) inside the area the HUD leaves free, at zoom 1
func _fit_camera() -> void:
	var vp := vp_size()
	if vp.x < 8:
		return
	var cm := crt.material as ShaderMaterial
	cm.set_shader_parameter("design_size", get_viewport_rect().size)
	cm.set_shader_parameter("pixel_scale", pixel_scale)
	var free_ui: Rect2 = hud.world_rect() if hud else Rect2(Vector2.ZERO, vp / view_k)
	var free := Rect2(free_ui.position * view_k, free_ui.size * view_k)
	var span := vehicle.length() + 124.0                 # vehicle front .. enemy spawn
	var left := free.position.x + 4.0
	if free.size.x > span + 8.0:
		left = free.position.x + floorf((free.size.x - span) * 0.5)
	# swiping right reaches the end of the convoy and the fight behind it, however far that is off-screen
	pan_right = maxf(PAN_LIMIT, span + 8.0 - free.size.x)
	var road_screen := free.end.y - 12.0
	cam_home = Vector2(round(-left + vp.x * 0.5), round(Vehicle.ROAD_Y - road_screen + vp.y * 0.5))
	var need := Vehicle.ROAD_Y - (vehicle.top_y() - 6.0)
	pan_y_max = maxf(0.0, need - (free.size.y - 12.0))
	pan_y = clampf(pan_y, 0.0, pan_y_max)
	if _closeup_slot < 0:
		if _zoom_tw == null or not _zoom_tw.is_running():
			camera.zoom = Vector2.ONE
			camera.position = cam_home + Vector2(round(pan_x), -round(pan_y))
	else:
		_apply_zoom(1.0)


func _process(delta: float) -> void:
	_last_input_t += delta
	if zoom_mode == "auto" and Engine.get_process_frames() % 20 == 0:
		if not is_equal_approx(target_ws(), world_scale):
			_apply_world_scale()
	if _closeup_slot < 0 and not _pressing and _last_input_t > 3.0 and absf(pan_x) > 0.5:
		pan_x = lerpf(pan_x, 0.0, clampf(delta * 1.5, 0.0, 1.0))
		if _zoom_tw == null or not _zoom_tw.is_running():
			camera.position.x = cam_home.x + round(pan_x)
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, delta * 12.0)
		# the camera moves in world px: x view_k keeps the shake the same size on screen at every zoom (a phone zoomed
		# in to 4 px per art pixel used to shake 4x harder, MV-148 / MV-175)
		var sw := _shake * view_k
		camera.offset = Vector2(round(randf_range(-sw, sw)), round(randf_range(-sw, sw)))
	else:
		camera.offset = Vector2.ZERO
	if blur_rect.visible:
		_update_blur_rect()


## amount is in UI pixels; tune fx.shake scales every shake (MV-175: half of the old strength by default)
func shake(amount: float) -> void:
	if amount >= 4.0:
		Settings.buzz(int(amount * 10.0))
	if not bool(Settings.get_value("shake")):
		return
	_shake = maxf(_shake, amount * Features.num("fx.shake", SHAKE_SCALE))


func _on_setting_changed(key: String) -> void:
	match key:
		"crt":
			crt.visible = bool(Settings.get_value("crt"))
		"ui_scale":
			_on_resize()
		"zoom":
			if zoom_mode != str(Settings.get_value("zoom")):
				zoom_mode = str(Settings.get_value("zoom"))
				_apply_world_scale()


func _on_features_changed() -> void:
	if world_vp != null and not is_equal_approx(target_ws(), world_scale):
		_apply_world_scale()


func screen_to_world(p: Vector2) -> Vector2:
	return world_vp.get_canvas_transform().affine_inverse() * (p * view_k)


func world_to_screen(p: Vector2) -> Vector2:
	return (world_vp.get_canvas_transform() * p) / view_k


# ------------------------------------------------------------------ input (tap / swipe)
## Finger releases are booked here, before the GUI and the modal check in _unhandled_input. A tap that
## opens a panel used to lose its release (emulated mouse-up fires first and opens the panel, then the
## touch-up hit any_modal_open()), so a ghost finger stayed in _touches and every later one-finger swipe
## counted as a pinch: the camera flipped normal/wide instead of panning. On the web a finger's index is
## the browser Touch.identifier, which never repeats on iOS, so the ghost never got overwritten either.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed:
		_touches.erase(event.index)
		if _touches.size() < 2:
			_pinch_d = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not Game.started or hud.any_modal_open():
		return
	# zoom: mouse wheel / trackpad magnify / two-finger pinch
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if _closeup_slot < 0:
			zoom_step(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		return
	if event is InputEventMagnifyGesture and _closeup_slot < 0:
		zoom_step(1 if event.factor > 1.0 else -1)
		return
	if event is InputEventScreenTouch and event.pressed:
		_touches[event.index] = event.position
	if event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			_pinch(_touches.values())
			_pressing = false
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_dragged = false
			_press_pos = event.position
		elif _pressing:
			_pressing = false
			if not _dragged:
				_on_tap(event.position)
		_last_input_t = 0.0
	elif event is InputEventMouseMotion and _pressing:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_pressing = false      # the release went to a panel: don't pan on hover
			return
		if event.position.distance_to(_press_pos) > TAP_SLOP:
			_dragged = true
		if _dragged and _closeup_slot < 0:
			# relative is in UI px; the camera moves in world px, so the road follows the finger at any zoom
			pan_x = clampf(pan_x - event.relative.x * view_k, -PAN_LIMIT, pan_right)
			camera.position.x = cam_home.x + round(pan_x)
		_last_input_t = 0.0


## two fingers spreading by PINCH_STEP switch to the normal view, closing by it to the wide one;
## once per step, and only when the mode really changes (no toast storm while the fingers keep moving)
func _pinch(pts: Array) -> void:
	var d := (pts[0] as Vector2).distance_to(pts[1])
	if _pinch_d <= 0.0:
		_pinch_d = d
		return
	if _closeup_slot >= 0:
		return
	var dir := 0
	if d > _pinch_d * PINCH_STEP:
		dir = 1
	elif d * PINCH_STEP < _pinch_d:
		dir = -1
	if dir == 0:
		return
	_pinch_d = d
	zoom_step(dir)


func _on_tap(screen_pos: Vector2) -> void:
	if _closeup_slot >= 0:
		# tapping outside the focused room closes the close-up
		var r := vehicle.slot_global_rect(_closeup_slot)
		if not r.has_point(screen_to_world(screen_pos)) and not hud.room_closeup.get_global_rect().has_point(screen_pos):
			hud.room_closeup.close()
		return
	var world_pos := screen_to_world(screen_pos)
	var slot := vehicle.slot_at(world_pos)
	if not vehicle.is_open_view() and vehicle.hull_has_point(world_pos) and _placing == "":
		vehicle.peek(5.0)       # first tap on the closed hull opens the X-ray view
		return
	if _placing != "":
		if slot >= 0 and slot != Data.CAB_SLOT and Game.is_slot_unlocked(slot) and Game.s.rooms[slot].type == "empty":
			if Game.build_room(slot, _placing):
				vehicle.spark()
				shake(2.5)
		_exit_placement()
		return
	if slot == Data.CAB_SLOT:
		if EngineBay.on():
			hud.open_panel("engine")
		else:
			Game.toast.emit(Loc.t("ห้องเครื่องปิดใช้งานชั่วคราว รถใช้เครื่องดีเซลเดิม"), "info")
	elif slot >= 0:
		open_closeup(slot)
	elif vehicle.solar_global_rect().has_point(world_pos):
		hud.open_panel("solar")


# ------------------------------------------------------------------ room close-up (integer zoom)
func open_closeup(slot: int) -> void:
	slot = Game.room_anchor(slot)
	_closeup_slot = slot
	vehicle.peek(9999.0)
	if view_k > 1.0:
		_apply_world_scale()
	Game.closeup_slot = slot
	Game.travel_changed.emit()
	weather.set_closeup(true)
	chatter.focus_slot = slot
	blur_rect.visible = true
	hud.set_closeup_mode(true)
	hud.room_closeup.open_slot(slot)
	_zoom_from = {"pos": camera.position, "zoom": camera.zoom.x}
	_run_zoom(true)
	var tw := create_tween()
	tw.tween_method(func(v: float): blur_mat.set_shader_parameter("amount", v), 0.0, 1.0, 0.45)


func closeup_zoom() -> int:
	var vp := vp_size()
	var focus: Rect2 = hud.room_closeup.focus_rect()
	var sz := vehicle.room_size(_closeup_slot) if _closeup_slot >= 0 else Vehicle.ROOM_SIZE
	var z := int(minf(focus.size.x / sz.x, focus.size.y / sz.y))
	# a large room (v4.4) still has to fit: it may drop to 1x instead of overflowing the screen
	return clampi(z, 2 if sz.x <= Vehicle.ROOM_SIZE.x else 1, 3) if vp.x >= 200 else 1


func _closeup_target() -> Dictionary:
	var vp := vp_size()
	var z := float(closeup_zoom())
	var r := vehicle.slot_rect(_closeup_slot)
	var focus: Rect2 = hud.room_closeup.focus_rect()
	var target := focus.get_center()
	var cam := r.get_center() - (target - vp * 0.5) / z
	cam = (cam * z).round() / z
	return {"pos": cam, "zoom": z}


func _apply_zoom(t: float) -> void:
	var to := _closeup_target() if _closeup_slot >= 0 else {"pos": cam_home + Vector2(round(pan_x), -round(pan_y)), "zoom": 1.0}
	var fz: float = _zoom_from.get("zoom", 1.0)
	var fp: Vector2 = _zoom_from.get("pos", camera.position)
	var z := lerpf(fz, float(to.zoom), t)
	camera.zoom = Vector2(z, z)
	camera.position = fp.lerp(to.pos, t)
	if t >= 1.0:
		camera.zoom = Vector2(to.zoom, to.zoom)
		camera.position = to.pos


func _run_zoom(_opening: bool) -> void:
	if _zoom_tw:
		_zoom_tw.kill()
	_zoom_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom_tw.tween_method(_apply_zoom, 0.0, 1.0, 0.5)


func _close_closeup() -> void:
	if _closeup_slot < 0:
		return
	_closeup_slot = -1
	Game.closeup_slot = -1
	vehicle.peek(2.0)
	vehicle._xray_hold = minf(vehicle._xray_hold, 2.0)
	_apply_world_scale()
	chatter.focus_slot = -1
	hud.set_closeup_mode(false)
	Game.travel_changed.emit()
	weather.set_closeup(false)
	_zoom_from = {"pos": camera.position, "zoom": camera.zoom.x}
	_run_zoom(false)
	var tw := create_tween()
	tw.tween_method(func(v: float): blur_mat.set_shader_parameter("amount", v), 1.0, 0.0, 0.35)
	tw.tween_callback(func(): blur_rect.visible = _closeup_slot >= 0)


func _update_blur_rect() -> void:
	var vp := vp_size()
	var slot := _closeup_slot if _closeup_slot >= 0 else hud.room_closeup.slot
	if slot < 0:
		return
	var r := vehicle.slot_global_rect(slot)
	var p0 := world_vp.get_canvas_transform() * r.position
	var p1 := world_vp.get_canvas_transform() * r.end
	blur_mat.set_shader_parameter("focus_rect", Vector4(p0.x / vp.x, p0.y / vp.y, (p1.x - p0.x) / vp.x, (p1.y - p0.y) / vp.y))
	blur_mat.set_shader_parameter("px_uv", Vector2(1.0 / vp.x, 1.0 / vp.y))


# ------------------------------------------------------------------ build placement
func _enter_placement(room_type: String) -> void:
	_placing = room_type
	vehicle.set_build_highlight(true, room_type)
	var any := false
	for s in Game.unlocked_slots():
		if Game.s.rooms[s].type == "empty":
			any = true
	if not any:
		Game.toast.emit(Loc.t("ไม่มีช่องว่าง! อัปเกรด Mobile Vault เพื่อปลดล็อกชั้นเพิ่ม"), "warn")
		_exit_placement()
		return
	hud.show_banner(Loc.t("แตะห้องว่างเพื่อสร้าง %s (%d เศษเหล็ก · %s)") % [Data.room_def(room_type).th, Game.build_cost(room_type), Game.fmt_time(Game.build_time(room_type))])


func _exit_placement() -> void:
	_placing = ""
	vehicle.set_build_highlight(false)
	hud.show_banner("")


# ------------------------------------------------------------------ floating numbers (world space, pixel font)
const RES_COL := {"power": Color("ffdc8e"), "water": Color("8cfff6"), "food": Color("f0644a"), "scrap": Color("cad8d0")}


func _spawn_float(slot: int, text: String, icon: String) -> void:
	var pos: Vector2
	if slot >= 0:
		var r := vehicle.slot_global_rect(slot)
		pos = r.position + Vector2(r.size.x * 0.5, 12)
	else:
		pos = vehicle.to_global(Vector2(120, 40))
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIKit.font_pixel)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", RES_COL.get(icon, Color("ffefc0")))
	l.add_theme_color_override("font_outline_color", Color("0b0a10"))
	l.add_theme_constant_override("outline_size", 2)
	l.position = (pos + Vector2(randi_range(-8, 4), 0)).round()
	l.z_index = 50
	world.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 14, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.6)
	tw.tween_callback(l.queue_free)
