class_name ExpeditionView
extends Node2D
## World-side visuals for expeditions:
##  - when the truck parks at a landmark, the site (lm_* sprite) rolls in from the left along the road and
##    stops right behind the truck; it rolls away again when the truck drives on
##  - a team that sets out climbs down from the rear deck and walks into the landmark's door (vanishes inside)
##  - when the expedition ends the survivors walk back out to the truck; the fallen never come back
## Lives in vehicle-local space (first child of the Vehicle, so it draws behind the truck body).

const SITE_X := 284.0          # landmark left edge when parked (truck-local)
const DOOR_OFF := 30.0         # door centre inside every lm_* sprite (tools/art/landmarks.py DOOR_X)
const GROUND_Y := 296.0        # walkers' feet on the road shoulder
const DECK_EXIT := Vector2(266, 260)
const WALK_SPEED := 22.0

var vehicle: Vehicle
var site_spr: Sprite2D
var _site := ""
var _team_cache: Array = []    # [{id, variant}] of the team currently out
var _walkers: Array = []


func setup(v: Vehicle) -> void:
	vehicle = v      # first child of the Vehicle -> drawn behind the wheels / body, but above the background
	site_spr = Sprite2D.new()
	site_spr.centered = false
	site_spr.visible = false
	add_child(site_spr)
	Expedition.site_reached.connect(func(_id): _sync(false))
	Expedition.expedition_started.connect(_on_started)
	Expedition.expedition_finished.connect(_on_finished)
	Game.travel_changed.connect(func(): _sync(false))
	Game.game_started.connect(func(): _sync(true))
	_sync(true)


func _current_site() -> String:
	if Game.s.is_empty():
		return ""
	if Expedition.active():
		return str(Game.s.exp.get("site", ""))
	return Expedition.at_site()


func door_x() -> float:
	if site_spr.visible and site_spr.texture:
		return SITE_X + DOOR_OFF
	return 380.0     # generic "scavenge the area": they walk off-screen


func _sync(instant: bool) -> void:
	var id := _current_site()
	if id == _site:
		return
	var old := _site
	_site = id
	if id == "":
		if old != "" and site_spr.visible:
			var tw := create_tween()
			tw.tween_property(site_spr, "position:x", SITE_X + 420.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_callback(func(): site_spr.visible = false)
		return
	var spr: String = Expedition.site_def(id).get("sprite", "")
	if spr == "" or not Atlas.has(spr):
		site_spr.visible = false
	else:
		site_spr.texture = Atlas.tex(spr)
		site_spr.visible = true
		var h := float(site_spr.texture.get_height())
		var target := Vector2(SITE_X, GROUND_Y - h + 2.0)
		if instant:
			site_spr.position = target
		else:
			site_spr.position = Vector2(-160.0, target.y)
			var tw := create_tween()
			tw.tween_property(site_spr, "position:x", target.x, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if Expedition.active():
		_cache_team()


func _cache_team() -> void:
	_team_cache.clear()
	for d in Expedition.team():
		_team_cache.append({"id": int(d.id), "variant": str(d.variant)})


func _on_started() -> void:
	_sync(false)
	_cache_team()
	var i := 0
	for t in _team_cache:
		_spawn_walker(t.variant, [DECK_EXIT, Vector2(DECK_EXIT.x + 6, GROUND_Y), Vector2(door_x(), GROUND_Y)], i * 0.7, true)
		i += 1


func _on_finished(_report: Dictionary) -> void:
	var i := 0
	for t in _team_cache:
		if Game.dweller_by_id(int(t.id)).is_empty():
			continue     # did not make it back
		_spawn_walker(t.variant, [Vector2(door_x(), GROUND_Y), Vector2(DECK_EXIT.x + 6, GROUND_Y), DECK_EXIT], i * 0.8, false)
		i += 1
	_team_cache.clear()
	_sync(false)


func _spawn_walker(variant: String, path: Array, delay: float, outbound: bool) -> void:
	var w := AnimatedSprite2D.new()
	w.sprite_frames = Atlas.dweller_frames(variant)
	w.centered = false
	w.offset = Vector2(-Atlas.DW_W / 2, -Atlas.DW_H)
	w.position = path[0]
	w.visible = false
	w.z_index = 2
	add_child(w)
	_walkers.append(w)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func():
		w.visible = true
		w.modulate.a = 0.0 if not outbound else 1.0
		w.play("walk"))
	if not outbound:
		tw.tween_property(w, "modulate:a", 1.0, 0.3)
	for k in range(1, path.size()):
		var a: Vector2 = path[k - 1]
		var b: Vector2 = path[k]
		var flip := b.x < a.x
		tw.tween_callback(func(): w.flip_h = flip)
		tw.tween_property(w, "position", b, maxf(0.2, a.distance_to(b) / WALK_SPEED))
	tw.tween_property(w, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		_walkers.erase(w)
		w.queue_free())
