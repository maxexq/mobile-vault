class_name WorldMapView
extends Control
## The seeded world map (MV-515, MV-500 phase 3): the world's 336x360 native map drawn at whole pixels, panned by drag
## when the window is narrower. Terrain = the biome's 16x16 tile in every cell nearest that region (MV-501..506),
## regions above the Vault level dimmed with the fog dither (MV-513); roads are code-drawn whole-pixel strokes, the
## selected route in amber, border roads with a red / white checkpoint marker; landmarks sit in the 27x27 frame
## (MV-507) with their existing 16x16 icon, junctions are road stops (MV-508), unknown reports show "?" with the suspect
## ping (MV-511), locked stops a padlock; the selection rim (MV-509) marks the chosen stop; the vehicle marker (MV-510)
## sits above everything, follows the trip's progress and never takes a tap. MV-546: a blueprint cache shows the
## existing 16x16 blueprint icon as a badge above its stop, bobbing 1 px (never takes a tap).
## MV-556 (switch world_map_detail): calm `ui_map_terrain_<biome>` tiles, a 1 px soot line where two regions meet, small
## `ui_map_prop_*` landmarks scattered per region from the world seed (never on a road, a stop or a region name; density
## tune world_map.props) and a dark plate under each region name. Off = the original MV-501 tiles and bare names.
##  * a tap that didn't drag selects a stop (signal stop_selected); dragging only pans. Selecting never drives.
##  * stops are 44x44 focusable buttons (keyboard / gamepad focus moves between them).
##  * redrawn only when the world, the trip or the selection change; the marker moves and the small loops (vehicle
##    treads while driving, suspect pings) run only while visible, never while the game is paused.

signal stop_selected(id: String)

const TILE := 16
const MAP := Vector2(336, 360)
const LOOP_FPS := 2.0
const TOUCH := 44
const DRAG_PX := 6.0
## the existing 16x16 icon for each landmark (as in the approved preview)
const SITE_ICON := {"market": "food", "hospital": "medkit", "depot": "ammo", "gas_stop": "fuel", "sat_base": "signal",
	"ranger": "explore", "lab": "chip", "chem_plant": "rad", "stilt_town": "people", "polar": "snow", "mine": "scrap",
	"mall": "supply", "helios": "power"}
const C_ROAD := Color("54544e")
const C_ROAD_DIRT := Color("6e5a3e")
const C_ROUTE := Color("d8ae44")
const C_EDGE := Color("0c0a0a")
## MV-556: the props a region may scatter (atlas ui_map_prop_<key>); a key listed twice comes up twice as often
const PROPS := {
	"industrial": ["industrial_factory", "industrial_factory", "industrial_tank", "industrial_heap", "industrial_heap", "industrial_pylon"],
	"desert": ["desert_dune", "desert_dune", "desert_glass", "desert_glass", "desert_bones", "desert_stump", "desert_rock"],
	"forest": ["forest_clump", "forest_clump", "forest_pines", "forest_pines", "forest_bush", "forest_bush", "forest_log"],
	"swamp": ["swamp_pool", "swamp_pool", "swamp_tree", "swamp_tree", "swamp_reeds", "swamp_reeds", "swamp_shack"],
	"tundra": ["tundra_pine", "tundra_pine", "tundra_pine", "tundra_rock", "tundra_drift", "tundra_drift", "tundra_wreck"],
	"metro": ["metro_tower", "metro_tower", "metro_block", "metro_block", "metro_mast", "metro_wreck", "metro_wreck"],
}
const PROP_STEP := 14          # candidate grid (px); each candidate jitters -3..+4 px
const ROAD_CLEAR := 4.0        # px between a prop and any road
const STOP_CLEAR := 16.0       # px between a prop and a stop centre (beyond the prop's own half size)
const C_LABEL := Color("b2a88a")
const C_PLATE := Color(0.047, 0.039, 0.039, 0.78)

var selected := ""
var pan := Vector2.ZERO
var _route: Dictionary = {}
var _buttons := {}
var _marker: TextureRect
var _pings := {}
var _cache_icon: TextureRect
var _t := 0.0
var _press := Vector2(-1, -1)
var _dragging := false
var _drag_from := Vector2.ZERO
var _cells := PackedInt32Array()    # MV-556: region index of every 16 px cell (row-major)
var _props: Array = []              # MV-556: [atlas name, top-left on the map]
var _plates: Array = []             # MV-556: region-name plates (Rect2 on the map)
var _layout_key := ""


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(0, MAP.y)
	WorldMap.world_changed.connect(rebuild)
	# MV-542: a loaded save brings its own world without world_changed (nothing about it changed), so the stop
	# buttons built at startup (no world yet) stayed missing: the map drew but no stop could be tapped
	Game.game_started.connect(rebuild)
	visibility_changed.connect(func():
		if is_visible_in_tree() and _stale():
			rebuild())
	Game.travel_changed.connect(_refresh_route)
	Features.changed.connect(func():
		_layout_key = ""             # MV-556: the switch or the prop density may have changed
		queue_redraw()
		if (_cache_icon != null) != (WorldMap.cache_at() != ""):
			rebuild())
	resized.connect(_clamp_pan)
	rebuild()


func _drop(n: Node) -> void:
	if n.get_parent() == self:
		remove_child(n)
	n.queue_free()


## the stop buttons don't belong to the world being shown (another save / cloud load / new world)
func _stale() -> bool:
	var w := WorldMap.world()
	if w.is_empty():
		return not _buttons.is_empty()
	if _buttons.size() != (w.nodes as Array).size():
		return true
	for n in w.nodes:
		if not _buttons.has(str(n.id)):
			return true
	return false


## all stop buttons + overlays for the current world (only when the world changes)
func rebuild() -> void:
	# detached first: the world can change twice in one frame (MV-514 create + place), and nodes still waiting for
	# queue_free would keep their names, so the new "Stop_*" / "VehicleMarker" would be renamed
	for b in _buttons.values():
		_drop(b)
	_buttons.clear()
	for p in _pings.values():
		_drop(p)
	_pings.clear()
	if _marker:
		_drop(_marker)
		_marker = null
	if _cache_icon:
		_drop(_cache_icon)
		_cache_icon = null
	var w := WorldMap.world()
	if w.is_empty():
		queue_redraw()
		return
	for n in w.nodes:
		var id := str(n.id)
		var b := Button.new()
		b.name = "Stop_" + id
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(TOUCH, TOUCH)
		b.size = Vector2(TOUCH, TOUCH)
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.tooltip_text = label_of(id)
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(func():
			if not _dragging:
				select(id))
		add_child(b)
		_buttons[id] = b
		if str(n.type) == "rumor" and not bool(w.visited.get(id, false)):
			var p := TextureRect.new()
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.texture = Atlas.tex("fx_map_suspect_ping_0")
			add_child(p)
			_pings[id] = p
	if WorldMap.cache_at() != "":
		_cache_icon = TextureRect.new()
		_cache_icon.name = "BlueprintCache"
		_cache_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cache_icon.texture = Atlas.icon("blueprint")
		add_child(_cache_icon)
	_marker = TextureRect.new()
	_marker.name = "VehicleMarker"
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE      # above every stop, never takes a tap
	_marker.texture = Atlas.tex("fx_map_vehicle_marker_0")
	add_child(_marker)
	if selected != "" and WorldMap.node(selected).is_empty():
		selected = ""
	_center_on(_vehicle_pos())
	_refresh_route()
	_place_children()


func select(id: String) -> void:
	selected = id
	_refresh_route()
	stop_selected.emit(id)


func _refresh_route() -> void:
	_route = {}
	if selected != "" and WorldMap.on() and not WorldMap.world().is_empty():
		var from := WorldMap.here()
		_route = WorldMap.route(from, selected, int(Game.s.vault_level)) if selected != from else {}
	queue_redraw()
	_place_children()


## the drivable route to the selected stop ({} = none or not reachable)
func route() -> Dictionary:
	return _route


func label_of(id: String) -> String:
	var n := WorldMap.node(id)
	if n.is_empty():
		return id
	if id == WorldMap.cache_at():
		return Loc.t("กล่องพิมพ์เขียว (สุ่ม)")
	match str(n.type):
		"landmark":
			return str(Expedition.SITES[n.site].th)
		"rumor":
			return Loc.t("สัญญาณไม่ทราบที่มา") if not bool(WorldMap.world().visited.get(id, false)) else Loc.t("จุดที่เคยส่งสัญญาณ")
		"start":
			return Loc.t("จุดเริ่มต้น")
		"exit":
			return Loc.t("ทางออกสู่โลกใหม่")
	return Loc.t("ทางแยก")


func locked(id: String) -> bool:
	var n := WorldMap.node(id)
	return not n.is_empty() and int(Data.biome(int(n.biome)).req) > int(Game.s.vault_level)


# =================================================================== drawing
func _origin() -> Vector2:
	return (pan + ((size - MAP) * 0.5).max(Vector2.ZERO)).round()


## a stop on the map canvas (no pan); the same 17 px inset as _p
func _mp(n: Dictionary) -> Vector2:
	return Vector2(clampi(int(n.x), 17, int(MAP.x) - 17), clampi(int(n.y), 17, int(MAP.y) - 17))


## a stop on screen; kept 17 px inside the map edge so its frame and the 33 px selection rim are never cut off
func _p(n: Dictionary) -> Vector2:
	return _origin() + _mp(n)


# =================================================================== MV-556 layout: cells, props, name plates
func _cols() -> int:
	return int(MAP.x / TILE) + 1


func _rows() -> int:
	return int(MAP.y / TILE)


## the region index of the 16 px cell under a map point (what the terrain shows there); -1 = off the map
func region_at(p: Vector2) -> int:
	_layout()
	return -1 if _cells.is_empty() else _cell_of(p)


## the scattered props ([atlas name, top-left on the map]) and the region-name plates, for tests
func props() -> Array:
	_layout()
	return _props


func plates() -> Array:
	_layout()
	return _plates


func _plate(r: Dictionary) -> Rect2:
	var nm := str(Data.biome(int(r.i)).en)
	var fs := UIKit.FP
	var tw := UIKit.font_pixel.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var asc := UIKit.font_pixel.get_ascent(fs)
	var tp := (Vector2(int(r.x), int(r.y)) + Vector2(-tw * 0.5, 4)).round()
	return Rect2(tp + Vector2(-3, -asc - 1), Vector2(round(tw) + 7, round(asc + UIKit.font_pixel.get_descent(fs)) + 3))


## recomputed only when the world, the lap, the switch or the density change; a pure function of the world seed
func _layout() -> void:
	var w := WorldMap.world()
	var dens := Features.num("world_map.props", 0.7) if Features.on("world_map_detail") else 0.0
	var key := "%s/%d/%d/%.3f" % [str(w.get("seed", "")), int(w.get("lap", 0)), (w.get("nodes", []) as Array).size(), dens]
	if key == _layout_key:
		return
	_layout_key = key
	_cells = PackedInt32Array()
	_props = []
	_plates = []
	if w.is_empty():
		return
	var regs: Array = w.regions
	for cy in _rows():
		for cx in _cols():
			var c := Vector2(cx * TILE + 8, cy * TILE + 8)
			var best := 0
			var bd := INF
			for i in regs.size():
				var d := c.distance_squared_to(Vector2(int(regs[i].x), int(regs[i].y)))
				if d < bd:
					bd = d
					best = i
			_cells.append(best)
	for r in regs:
		_plates.append(_plate(r))
	if dens <= 0.0:
		return
	var segs := []
	for e in w.edges:
		segs.append([_mp(WorldMap.node(str(e.a))), _mp(WorldMap.node(str(e.c)))])
	var stops := []
	for n in w.nodes:
		stops.append(_mp(n))
	var taken: Array = []
	for gy in int(MAP.y / PROP_STEP):
		for gx in int(MAP.x / PROP_STEP):
			var h := WorldMap.fnv1a("%s/%d/prop/%d/%d" % [str(w.seed), int(w.get("lap", 0)), gx, gy])
			if float((h >> 8) & 0xFFFF) / 65535.0 >= dens:
				continue
			var at := Vector2(gx * PROP_STEP + (h & 7) - 3, gy * PROP_STEP + ((h >> 3) & 7) - 3)
			var ri := _cell_of(at + Vector2(PROP_STEP, PROP_STEP) * 0.5)
			if ri < 0:
				continue
			var pool: Array = PROPS.get(str(regs[ri].id), [])
			if pool.is_empty():
				continue
			var nm := "ui_map_prop_" + str(pool[(h >> 24) % pool.size()])
			var rc := Rect2(at, Atlas.tex(nm).get_size())
			if _prop_fits(rc, ri, segs, stops, taken):
				taken.append(rc)
				_props.append([nm, rc.position])


func _cell_of(q: Vector2) -> int:
	var cx := int(floor(q.x / TILE))
	var cy := int(floor(q.y / TILE))
	if cx < 0 or cy < 0 or cx >= _cols() or cy >= _rows():
		return -1
	return _cells[cy * _cols() + cx]


func _prop_fits(rc: Rect2, ri: int, segs: Array, stops: Array, taken: Array) -> bool:
	if rc.position.x < 1 or rc.position.y < 1 or rc.end.x > MAP.x - 1 or rc.end.y > MAP.y - 1:
		return false
	# the whole prop stands on its own region's terrain (none straddles a border)
	for q in [rc.position, Vector2(rc.end.x - 1, rc.position.y), Vector2(rc.position.x, rc.end.y - 1), rc.end - Vector2.ONE]:
		if _cell_of(q) != ri:
			return false
	var c := rc.get_center()
	var rad := maxf(rc.size.x, rc.size.y) * 0.5
	for s in segs:
		if Geometry2D.get_closest_point_to_segment(c, s[0], s[1]).distance_to(c) < rad + ROAD_CLEAR:
			return false
	for p in stops:
		if p.distance_to(c) < rad + STOP_CLEAR:
			return false
	for pl in _plates:
		if pl.grow(2).intersects(rc):
			return false
	for t in taken:
		if t.grow(1).intersects(rc):
			return false
	return true


func _draw() -> void:
	var w := WorldMap.world()
	draw_rect(Rect2(Vector2.ZERO, size), UIKit.C_BG)
	if w.is_empty():
		return
	var o := _origin()
	if Features.on("world_map_detail"):
		_draw_detail_ground(w, o)
		_draw_roads_and_stops(w, o, true)
		return
	# terrain: each 16px cell takes the tile of the nearest region; locked regions get the fog dither
	var regs: Array = w.regions
	var fog := Atlas.tex("ui_map_fog_dither")
	for cy in int(MAP.y / TILE):
		for cx in int(MAP.x / TILE) + 1:
			var c := Vector2(cx * TILE + 8, cy * TILE + 8)
			var best: Dictionary = regs[0]
			var bd := INF
			for r in regs:
				var d := c.distance_squared_to(Vector2(int(r.x), int(r.y)))
				if d < bd:
					bd = d
					best = r
			var at := o + Vector2(cx * TILE, cy * TILE)
			draw_texture(Atlas.tex("ui_map_ground_" + str(best.id)), at)
			if int(best.req) > int(Game.s.vault_level):
				draw_texture(fog, at, Color(1, 1, 1, 0.45))     # dims; the biome stays recognisable
	_draw_roads_and_stops(w, o, false)


## MV-556: calm terrain, region borders, props, then the fog over locked regions (props dim with their region)
func _draw_detail_ground(w: Dictionary, o: Vector2) -> void:
	_layout()
	var regs: Array = w.regions
	var cols := _cols()
	for cy in _rows():
		for cx in cols:
			draw_texture(Atlas.tex("ui_map_terrain_" + str(regs[_cells[cy * cols + cx]].id)), o + Vector2(cx * TILE, cy * TILE))
	var edge := Color(C_EDGE, 0.7)
	for cy in _rows():
		for cx in cols:
			var me := _cells[cy * cols + cx]
			var at := o + Vector2(cx * TILE, cy * TILE)
			if cx + 1 < cols and _cells[cy * cols + cx + 1] != me:
				draw_rect(Rect2(at + Vector2(TILE - 1, 0), Vector2(1, TILE)), edge)
			if cy + 1 < _rows() and _cells[(cy + 1) * cols + cx] != me:
				draw_rect(Rect2(at + Vector2(0, TILE - 1), Vector2(TILE, 1)), edge)
	for pr in _props:
		draw_texture(Atlas.tex(pr[0]), o + pr[1])
	# locked: a flat shade plus a faint dither, so the region reads as closed without a loud checkerboard
	var fog := Atlas.tex("ui_map_fog_dither")
	var shade := Color(C_EDGE, 0.32)
	for cy in _rows():
		for cx in cols:
			if int(regs[_cells[cy * cols + cx]].req) > int(Game.s.vault_level):
				draw_rect(Rect2(o + Vector2(cx * TILE, cy * TILE), Vector2(TILE, TILE)), shade)
				draw_texture(fog, o + Vector2(cx * TILE, cy * TILE), Color(1, 1, 1, 0.18))


func _draw_roads_and_stops(w: Dictionary, o: Vector2, detail: bool) -> void:
	var regs: Array = w.regions
	# roads: soot edge, then the road; the route on top in amber
	var on_route := {}
	for eid in _route.get("edges", []):
		on_route[str(eid)] = true
	for e in w.edges:
		var a := _p(WorldMap.node(str(e.a)))
		var c := _p(WorldMap.node(str(e.c)))
		draw_line(a, c, C_EDGE, 4.0)
		draw_line(a, c, C_ROAD_DIRT if bool(e.get("dirt", false)) else C_ROAD, 2.0)
	for e in w.edges:
		if on_route.has(str(e.id)):
			draw_line(_p(WorldMap.node(str(e.a))), _p(WorldMap.node(str(e.c))), C_ROUTE, 2.0)
	# checkpoint markers on border roads (red / white bar at the middle)
	for e in w.edges:
		if int(e.get("gate", 0)) > 0:
			var m := ((_p(WorldMap.node(str(e.a))) + _p(WorldMap.node(str(e.c)))) * 0.5).round()
			draw_rect(Rect2(m - Vector2(5, 3), Vector2(10, 6)), C_EDGE)
			draw_rect(Rect2(m - Vector2(4, 2), Vector2(8, 4)), Color("a8372a"))
			draw_rect(Rect2(m - Vector2(4, 0), Vector2(8, 1)), Color("b2a88a"))
	# region names, over the roads so a road never hides them
	for r in regs:
		var b := Data.biome(int(r.i))
		var nm := str(b.en)
		var fs := UIKit.FP
		var tw := UIKit.font_pixel.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp := (o + Vector2(int(r.x), int(r.y)) + Vector2(-tw * 0.5, 4)).round()
		if detail:
			var pl := _plate(r)
			draw_rect(Rect2(o + pl.position, pl.size), C_PLATE)
		draw_string(UIKit.font_pixel, tp + Vector2(1, 1), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_EDGE)
		draw_string(UIKit.font_pixel, tp, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			C_LABEL if detail and int(r.req) <= int(Game.s.vault_level) else UIKit.C_DIM)
	# stops
	var frame := Atlas.tex("ui_map_landmark_frame")
	var dot := Atlas.tex("ui_map_road_stop")
	for n in w.nodes:
		var id := str(n.id)
		var p := _p(n)
		var lock := locked(id)
		var t := str(n.type)
		if t in ["landmark", "rumor", "exit"] or lock:
			draw_texture(frame, (p - Vector2(13, 13)).round())
			var tl := (p - Vector2(8, 8)).round()
			if lock:
				draw_texture(Atlas.icon("lock"), tl, Color(1, 1, 1, 0.85))
			elif t == "landmark":
				var done := Expedition.is_done(str(n.site))
				draw_texture(Atlas.icon(str(SITE_ICON.get(str(n.site), "map"))), tl, Color(0.6, 0.6, 0.6) if done else Color.WHITE)
			elif t == "exit":
				draw_texture(Atlas.icon("up"), tl)
			else:
				var q := "?" if not bool(w.visited.get(id, false)) else "·"
				draw_string(UIKit.font_pixel, (p + Vector2(-3, 4)).round(), q, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FP, Color("d8ae44"))
		else:
			draw_texture(dot, (p - Vector2(8, 8)).round())
		if bool(w.visited.get(id, false)) and t != "start":
			draw_rect(Rect2((p + Vector2(9, 9)).round(), Vector2(2, 2)), UIKit.C_GREEN)   # visited tick
	if selected != "" and not WorldMap.node(selected).is_empty():
		draw_texture(Atlas.tex("ui_map_selection_ring"), (_p(WorldMap.node(selected)) - Vector2(16, 16)).round())


# =================================================================== overlays, marker, loops
func _vehicle_pos() -> Vector2:
	var t := WorldMap.trip()
	if t.is_empty():
		var n := WorldMap.node(WorldMap.here())
		return Vector2(int(n.get("x", 0)), int(n.get("y", 0)))
	var a := WorldMap.node(str(t.ids[int(t.i)]))
	var b := WorldMap.node(str(t.ids[int(t.i) + 1]))
	var e := WorldMap.edge(str(t.edges[int(t.i)]))
	var f := clampf(float(t.prog) / maxf(0.01, float(e.km)), 0.0, 1.0)
	return Vector2(int(a.x), int(a.y)).lerp(Vector2(int(b.x), int(b.y)), f)


func _place_children() -> void:
	var w := WorldMap.world()
	if w.is_empty():
		return
	for id in _buttons:
		_buttons[id].position = (_p(WorldMap.node(id)) - Vector2(TOUCH, TOUCH) * 0.5).round()
	for id in _pings:
		_pings[id].position = (_p(WorldMap.node(id)) - Vector2(16, 16)).round()
	if _cache_icon and WorldMap.cache_at() != "":
		_cache_icon.position = (_p(WorldMap.node(WorldMap.cache_at())) - Vector2(-4, 29 + (int(_t * LOOP_FPS) % 2))).round()
	if _marker:
		_marker.position = (_origin() + _vehicle_pos() - Vector2(11, 14)).round()
		move_child(_marker, get_child_count() - 1)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or get_tree().paused:
		return
	_t += delta
	var f := int(_t * LOOP_FPS) % 4
	for id in _pings:
		_pings[id].texture = Atlas.tex("fx_map_suspect_ping_%d" % f)
	if _cache_icon:
		_cache_icon.position.y = (_p(WorldMap.node(WorldMap.cache_at())) - Vector2(-4, 29 + (int(_t * LOOP_FPS) % 2))).round().y
	if _marker:
		var moving := Game.is_moving() and WorldMap.driving()
		_marker.texture = Atlas.tex("fx_map_vehicle_marker_%d" % (int(_t * 4.0) % 4 if moving else 0))
		if moving:
			_place_children()


# =================================================================== pan (drag) vs tap
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = e.position
			_drag_from = pan
			_dragging = false
		else:
			_press = Vector2(-1, -1)
			_dragging = false
	elif e is InputEventMouseMotion and _press.x >= 0.0:
		if e.position.distance_to(_press) > DRAG_PX:
			_dragging = true
		if _dragging:
			pan = _drag_from + (e.position - _press)
			_clamp_pan()


## while the map fits there is nothing to pan; when it doesn't, keep the map edge inside the window
func _clamp_pan() -> void:
	var lo := (size - MAP).min(Vector2.ZERO)
	pan = pan.clamp(lo, Vector2.ZERO).round()
	queue_redraw()
	_place_children()


func _center_on(p: Vector2) -> void:
	pan = (size * 0.5 - p).round()
	_clamp_pan()
