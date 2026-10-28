class_name ExteriorModMotion
extends Node2D
## MV-565. Cosmetic atlas strips; fixed pool, local phase clocks, no simulation writes.

const CAP := 12
var vehicle
var bindings: Array[Dictionary] = []
var rims: Array[Dictionary] = []
var pool: Array[Dictionary] = []
var _owned: Array[Sprite2D] = []
var _restores: Array[Dictionary] = []
var _roof: Dictionary = {}
var _catcher: Sprite2D
var _grit_left := 1.5
var _rain_left := 1.0
var _hit_left := 0.0
var _suspended := false
var _water_root: Node2D


func setup(owner_vehicle: Node2D) -> void:
	vehicle = owner_vehicle
	_water_root = Node2D.new()
	vehicle._roof_root.add_child(_water_root)
	vehicle._roof_root.move_child(_water_root, 0) # runoff behind the receiving tank
	for i in CAP:
		var s := Sprite2D.new()
		s.centered = false
		s.visible = false
		if i == 0: _water_root.add_child(s)
		else: add_child(s)
		pool.append({"sprite": s, "prefix": "", "time": -1.0, "count": 4, "fps": 8.0, "combat": false, "clip": false})


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_suspended = true
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN]:
		_suspended = false


func enabled() -> bool:
	return Features.on("exterior_mod_ambience") and not Game.s.is_empty()


func _sprite(parent: Node2D, prefix: String, at: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.position = at
	s.texture = Atlas.tex(prefix + "_0")
	parent.add_child(s)
	_owned.append(s)
	return s


## MV-566: the strip cut from the finer mod art while mod_detail_fine is on
func _art(prefix: String) -> String:
	return prefix + "_fine" if Features.on("mod_detail_fine") and Atlas.has(prefix + "_fine_0") else prefix


func _remember(s: Sprite2D) -> void:
	_restores.append({"sprite": s, "texture": s.texture})


func _bind(s: Sprite2D, prefix: String, fps: float, mode: String, gap: Vector2) -> void:
	bindings.append({"sprite": s, "prefix": prefix, "fps": fps, "mode": mode, "gap": gap,
		"left": gap.x + float(bindings.size() % 4) * 0.3, "time": -1.0, "frame": 0})
	s.texture = Atlas.tex(prefix + "_0")
	s.set_meta("ext_frame", 0)
	if mode == "shot": _roof = bindings[-1]


func rebuild() -> void:
	for r in _restores:
		if is_instance_valid(r.sprite) and not r.sprite.is_queued_for_deletion(): r.sprite.texture = r.texture
	_restores.clear()
	for s in _owned:
		if is_instance_valid(s) and not s.is_queued_for_deletion():
			s.get_parent().remove_child(s)
			s.queue_free()
	_owned.clear()
	bindings.clear()
	rims.clear()
	_roof = {}
	_catcher = null
	for p in pool:
		p.time = -1.0
		p.sprite.visible = false
	_grit_left = 1.5
	_rain_left = 1.0
	_hit_left = 0.0
	if Game.s.is_empty(): return
	for child in vehicle._mods_root.get_children():
		if not child is Sprite2D or child.is_queued_for_deletion(): continue
		var s := child as Sprite2D
		var region := str(s.get_meta("region", ""))
		# Clamp density remains a purchased-level cue even with motion disabled.
		if region == "mod_rad_shield":
			var xs: Array = [22, 178] if Mods.level("rad_shield") == 1 else [22, 74, 126, 178]
			for x in xs:
				var tab := _sprite(s, "anim_ext_shield_tab", Vector2(x, 4))
				if enabled(): _bind(tab, "anim_ext_shield_tab", 4.0, "drive", Vector2(6, 10))
		if not enabled(): continue
		if region.begins_with("mod_roof_turret_"):
			_remember(s)
			_bind(s, _art("anim_ext_turret_lv%d_recoil" % Mods.level("roof_turret")), 20.0, "shot", Vector2.ZERO)
		elif region.begins_with("mod_roof_deck_"):
			_remember(s)
			s.texture = Atlas.tex("ext_base_" + region)
			var lv := Mods.level("roof_deck")
			if lv == 1 and Features.on("cozy_roof"):
				_bind(_sprite(s, "anim_ext_deck_awning", Vector2(0, 12)), "anim_ext_deck_awning", 4.0, "cloth", Vector2(3, 5))
			if lv >= 2:
				_bind(_sprite(s, "fx_ext_deck_brazier", Vector2(50, 26)), "fx_ext_deck_brazier", 4.0, "loop", Vector2.ZERO)
			if lv == 3:
				_bind(_sprite(s, "anim_ext_deck_lamp", Vector2(63, 0)), "anim_ext_deck_lamp", 3.0, "idle", Vector2(8, 12))
		elif region == "mod_fuel_tank":
			_bind(_sprite(s, "anim_ext_fuel_strap", Vector2(10, 2)), "anim_ext_fuel_strap", 5.0, "drive", Vector2(4, 7))
		elif region == "mod_solar_cover":
			_bind(_sprite(s, "anim_ext_solar_latch", Vector2(26, 3)), "anim_ext_solar_latch", 5.0, "wind", Vector2(5, 8))
		elif region == "mod_rain_catcher":
			_catcher = s
			_remember(s)
			_bind(s, _art("anim_ext_catcher_hem"), 4.0, "wind", Vector2(4, 7))
		elif region == "mod_heater":
			_remember(s)
			var cap := _art("anim_ext_heater_cap")
			s.texture = Atlas.tex("ext_base_mod_heater_fine" if cap.ends_with("_fine") else "ext_base_mod_heater")
			_bind(_sprite(s, cap, Vector2.ZERO), cap, 4.0, "wind", Vector2(6, 10))
		elif region.begins_with("mod_shock_"):
			_remember(s)
			_bind(s, _art("anim_ext_shock_lv%d" % Mods.level("suspension")), 8.0, "drive", Vector2(2.5, 5))
	if enabled() and Mods.level("armor_plates") == 1:
		for x in [37, 247]:
			var tab := Sprite2D.new()
			tab.centered = false
			tab.texture = Atlas.tex("prop_ext_armor_lv1")
			tab.position = Vector2(x, 262)
			vehicle._mods_root.add_child(tab)
			tab.set_meta("region", "prop_ext_armor_lv1")
			_owned.append(tab)
	if Mods.level("rain_catcher") == 2:
		var collar := Sprite2D.new()
		collar.centered = false
		collar.texture = Atlas.tex("prop_ext_catcher_lv2")
		collar.position = Vector2(162, vehicle.roof_y() - 24)
		vehicle._mods_root.add_child(collar)
		_owned.append(collar)
	if enabled() and Mods.level("offroad_wheels") >= 2:
		for w in vehicle.wheels:
			if not bool(w.get_meta("rail", false)) and w.visible:
				var prefix := "anim_ext_offroad_lv%d_rim" % mini(Mods.level("offroad_wheels"), 3)
				var rim := _sprite(w, prefix, Vector2(-8, -8))
				rims.append({"sprite": rim, "wheel": w, "prefix": prefix, "frame": -1})


func _on_screen(s: Sprite2D) -> bool:
	if not s.is_visible_in_tree() or s.texture == null: return false
	var rect: Rect2 = s.get_global_transform_with_canvas() * s.get_rect()
	return get_viewport().get_visible_rect().intersects(rect)


func _frame(b: Dictionary, index: int) -> void:
	if int(b.frame) == index: return
	b.frame = index
	b.sprite.texture = Atlas.tex("%s_%d" % [b.prefix, index])
	b.sprite.set_meta("ext_frame", index)


func _process(delta: float) -> void:
	if vehicle == null or not enabled() or _suspended or not is_visible_in_tree() or not get_window().visible: return
	_tick(delta)


func _tick(delta: float) -> void:
	var moving: bool = vehicle._speed > 0.02
	var wind: bool = str(Game.s.get("weather", "")) in ["storm", "sandstorm"]
	var rate := Features.num("mods.fps", 1.0)
	_hit_left = maxf(0.0, _hit_left - delta)
	for b in bindings:
		if not _on_screen(b.sprite): continue # freeze phase and delay outside the camera
		var mode := str(b.mode)
		var active: bool = mode in ["idle", "loop", "shot", "cloth"] or moving or (mode == "wind" and wind)
		if not active:
			b.time = -1.0
			_frame(b, 0)
			continue
		if mode == "loop":
			b.time = maxf(float(b.time), 0.0) + delta * rate
			_frame(b, int(float(b.time) * float(b.fps)) % 4)
			continue
		if float(b.time) < 0.0:
			if mode == "shot": continue
			b.left = float(b.left) - delta
			if float(b.left) > 0.0: continue
			b.time = 0.0
		else: b.time = float(b.time) + delta * rate
		var f := int(float(b.time) * float(b.fps))
		if f >= 4:
			b.time = -1.0
			var gap: Vector2 = b.gap
			b.left = randf_range(9.0, 14.0) if mode == "cloth" and not moving else randf_range(gap.x, gap.y)
			b.left = float(b.left) * Features.num("mods.gap", 1.0) * (2.0 if mode == "wind" and not moving else 1.0)
			_frame(b, 0)
		else: _frame(b, f)
	for r in rims:
		if _on_screen(r.sprite): _frame(r, int(r.wheel.frame)) # tyre owns the phase
	for p in pool:
		if float(p.time) < 0.0 or not _on_screen(p.sprite): continue
		p.time = float(p.time) + delta * rate
		var f := int(float(p.time) * float(p.fps))
		if f >= int(p.count):
			p.time = -1.0
			p.sprite.visible = false
		else: _set_pool_frame(p, f)
	_grit_left -= delta
	if _grit_left <= 0.0:
		_grit_left = randf_range(2.0, 4.0) * Features.num("mods.gap", 1.0)
		grit_now(moving)
	_rain_left -= delta
	if _rain_left <= 0.0:
		_rain_left = (randf_range(1.5, 2.5) if Mods.level("rain_catcher") == 2 else randf_range(2.5, 4.0)) * Features.num("mods.gap", 1.0)
		runoff_now()


func _set_pool_frame(p: Dictionary, f: int) -> void:
	var name := "%s_%d" % [p.prefix, f]
	p.sprite.texture = Atlas.sub(name, Rect2(0, 0, 8, 6)) if bool(p.clip) else Atlas.tex(name)
	p.sprite.set_meta("ext_frame", f)
	if str(p.prefix) == "fx_ext_turret_muzzle":
		p.sprite.position.x = (float(_roof.sprite.position.x) + 24.0 if not _roof.is_empty() else 224.0) - (1.0 if not _roof.is_empty() and int(_roof.frame) in [1, 2] else 0.0)


func _spawn(prefix: String, at: Vector2, fps: float, count: int = 4, combat: bool = false, clip: bool = false) -> bool:
	if not enabled(): return false
	var slot: Dictionary = {}
	for p in pool:
		if float(p.time) >= 0.0 and str(p.prefix) == prefix:
			slot = p
			break
	var limit := clampi(int(Features.num("mods.fx_cap", CAP)), 1, CAP)
	if slot.is_empty() and active_fx() < limit:
		for i in range(0 if prefix == "fx_ext_catcher_runoff" else 1, 1 if prefix == "fx_ext_catcher_runoff" else CAP):
			if float(pool[i].time) < 0.0:
				slot = pool[i]
				break
	if slot.is_empty() and combat:
		for i in range(1, CAP):
			if float(pool[i].time) >= 0.0 and not bool(pool[i].combat):
				slot = pool[i]
				break
		# The rain slot has a different parent/layer. Release it, then use an idle
		# foreground slot so reclaiming runoff cannot put impact chips behind the hull.
		if slot.is_empty() and float(pool[0].time) >= 0.0:
			for i in range(1, CAP):
				if float(pool[i].time) < 0.0:
					pool[0].time = -1.0
					pool[0].sprite.visible = false
					slot = pool[i]
					break
	if slot.is_empty(): return false
	slot.prefix = prefix
	slot.time = 0.0
	slot.fps = fps
	slot.count = count
	slot.combat = combat
	slot.clip = clip
	var s: Sprite2D = slot.sprite
	s.position = (s.get_parent() as Node2D).to_local(vehicle.body.to_global(at)).round()
	s.visible = true
	_set_pool_frame(slot, 0)
	if not _on_screen(s):
		s.visible = false
		slot.time = -1.0
		return false
	return true


func active_fx() -> int:
	var count := 0
	for p in pool:
		if float(p.time) >= 0.0: count += 1
	return count


func roof_shot() -> Vector2:
	var lv := Mods.level("roof_turret")
	if not enabled() or lv == 0: return vehicle.body.to_global(Vector2(222, vehicle.roof_y() - 12))
	if not _roof.is_empty():
		_roof.time = 0.0
		_frame(_roof, 0)
	var origin: Vector2 = _roof.sprite.position if not _roof.is_empty() else Vector2(200, vehicle.roof_y() - 18)
	var muzzle := origin + Vector2(24, 8 if lv == 1 else 7)
	_spawn("fx_ext_turret_muzzle", muzzle - Vector2(0, 4), 24.0, 4, true, lv == 1)
	return vehicle.body.to_global(muzzle)


func ram_contact() -> bool:
	return Mods.level("spike_ram") > 0 and _spawn("fx_ext_ram_contact", Vector2(-20, 258), 16.0, 4, true)


func armor_hit(global_at: Vector2) -> bool:
	if _hit_left > 0.0 or not enabled(): return false
	var at: Vector2 = vehicle.body.to_local(global_at)
	for s in vehicle._mods_root.get_children():
		if not s is Sprite2D or s.is_queued_for_deletion(): continue
		if str(s.get_meta("region", "")) not in ["mod_armor_wall", "prop_ext_armor_lv1"]: continue
		if Rect2(s.position, s.texture.get_size()).has_point(at):
			_hit_left = 0.15
			return _spawn("fx_ext_armor_chip", at.round() - Vector2(4, 4), 16.0, 4, true)
	return false


func grit_now(moving: bool) -> bool:
	if not moving or not enabled() or bool(Game.vehicle_def().get("rail", false)) or str(Game.s.get("weather", "")) in ["rain", "storm", "acid_rain", "snow"]: return false
	if vehicle.n_trailers == 0 and vehicle.tracks.visible:
		return _spawn("fx_ext_track_grit", vehicle.tracks.position + Vector2(22, 9), 8.0)
	if Mods.level("offroad_wheels") == 0: return false
	var rear: AnimatedSprite2D
	for w in vehicle.wheels:
		if w.visible and not bool(w.get_meta("rail", false)) and (rear == null or w.position.x > rear.position.x): rear = w
	return rear != null and _spawn("fx_ext_offroad_grit", rear.position + Vector2(4, 8), 8.0)


func runoff_now() -> bool:
	if Mods.level("rain_catcher") == 0 or str(Game.s.get("weather", "")) not in ["rain", "storm"]: return false
	var origin: Vector2 = _catcher.position if is_instance_valid(_catcher) else Vector2(146, vehicle.roof_y() - 36)
	return _spawn("fx_ext_catcher_runoff", origin + Vector2(18, 16), 10.0, 5)


func replaces_dust() -> bool:
	return enabled() and (vehicle.tracks.visible or Mods.level("offroad_wheels") > 0) and str(Game.s.get("weather", "")) not in ["rain", "storm", "acid_rain", "snow"]


func preview(what: String) -> bool:
	match what:
		"shot":
			if Mods.level("roof_turret") == 0 or not enabled(): return false
			roof_shot()
			return true
		"ram": return ram_contact()
		"grit": return grit_now(true)
		"rain": return runoff_now()
		"motion":
			if not enabled(): return false
			for b in bindings:
				if str(b.mode) != "shot": b.left = 0.0
			return true
	return false
