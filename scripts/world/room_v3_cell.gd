class_name RoomV3Cell
extends Node2D
## MV-711: one vehicle cell drawn with the v3 room art (144x96, Room guide v3) inside the v3 interior view.
## Shows the room's level image (L1-L3; the grow room cycles its 3 growth stages), its idle micro-animation (cut
## from the approved idle GIF), the ref v3 crew who are in the room (CrewV3Actor at 2/3) and the shared red
## emergency lamp at (6,6): dull while powered, pulsing with a red glow in a power-out while the room goes dark.
## Empty cells / building sites use the 3 empty-cell stages (site progress picks the stage). A room type without a
## v3 set shows its old 64x52 art on the finished empty shell. Locked cells are a dark sealed panel.
## MV-733: adopted pets (PetsV3, switch pets_v3) wander in whichever room PetsV3 put them in (PetV3Actor).

const DARK := Color(0.32, 0.29, 0.42)
const GROW_SEC := 20.0            # one growth stage of the grow room (visual only)
const LAMP := Vector2(6, 6)

var slot := -1
var room_type := ""
var level := 1
var kind := ""                    # v3 | fallback | empty | site | locked
var data: Dictionary = {}         # V3Art.level() / empty_stage() of what is shown
var dark := false
var selected_id := ""             # hotspot id outlined by a tap
var bg: Sprite2D
var old_art: Sprite2D
var idle: Sprite2D
var actors_root: Node2D
var actors := {}                  # dweller id -> CrewV3Actor
var pets := {}                    # MV-733: pet index -> PetV3Actor
var _pet_t := 0.0
var _top: Node2D
var _idle_t := 0.0
var _t := 0.0
var _stage := -1
var _drawn := ""                  # what _top last drew (kind/dark/selection): a still lamp needs no redraw


func _ready() -> void:
	bg = Sprite2D.new()
	bg.centered = false
	add_child(bg)
	old_art = Sprite2D.new()
	old_art.centered = false
	old_art.visible = false
	add_child(old_art)
	idle = Sprite2D.new()
	idle.centered = false
	idle.visible = false
	add_child(idle)
	actors_root = Node2D.new()
	actors_root.y_sort_enabled = true
	add_child(actors_root)
	_top = Node2D.new()
	_top.draw.connect(_draw_top)
	add_child(_top)


func refresh() -> void:
	if Game.s.is_empty() or slot < 0 or slot >= Game.s.rooms.size():
		return
	var r: Dictionary = Game.s.rooms[Game.room_anchor(slot)]
	var unlocked := Game.is_slot_unlocked(slot)
	room_type = str(r.type) if unlocked else "locked"
	level = int(r.get("level", 1))
	var site := unlocked and Game.is_site(slot)
	old_art.visible = false
	if room_type == "locked":
		kind = "locked"
		data = {}
		bg.texture = null
	elif site or room_type == "empty":
		kind = "site" if site else "empty"
		var stage := 3 if not site else 1 + mini(int(Game.build_progress(slot) * 3.0), 2)
		data = V3Art.empty_stage(stage)
		bg.texture = V3Art.room_tex("empty", str(data.get("file", "")))
	elif V3Art.has_room(room_type):
		kind = "v3"
		data = V3Art.level(room_type, level)
		_stage = -1
		bg.texture = V3Art.room_tex(room_type, str(data.get("file", "")))
	else:
		kind = "fallback"           # no v3 set for this type yet: the old art on the finished shell
		data = V3Art.empty_stage(3)
		bg.texture = V3Art.room_tex("empty", str(data.get("file", "")))
		var key := room_type if room_type != "annex" else "empty"
		if Atlas.has(Data.room_art(key)):
			old_art.texture = Atlas.tex(Data.room_art(key))
			old_art.position = ((V3Art.CELL - old_art.texture.get_size()) * Vector2(0.5, 1.0) - Vector2(0, 8)).floor()
			old_art.visible = true
	var ov: Dictionary = data.get("idle", {})
	idle.visible = not ov.is_empty() and kind == "v3"
	if idle.visible:
		var tex := V3Art.room_tex(room_type, str(ov.file))
		idle.texture = tex
		idle.hframes = int(ov.cols)
		idle.vframes = ceili(float(ov.n) / float(ov.cols))
		idle.position = Vector2(float(ov.rect[0]), float(ov.rect[1]))
		idle.visible = tex != null
	_sync_actors(unlocked, site)
	sync_pets()
	_apply_dark()


func _sync_actors(unlocked: bool, site: bool) -> void:
	var want: Array = []
	if unlocked and room_type != "empty" and room_type != "locked" and not Game.is_annex(slot):
		want = Game.room_occupants(slot)
		if room_type == "quarters" and _is_first_quarters():
			want = want + Game.idle_dwellers()
	var mode := "build" if site else ("rest" if room_type == "quarters" else "work")
	var keep := {}
	for d in want:
		var id := int(d.id)
		keep[id] = true
		if not actors.has(id):
			var a := CrewV3Actor.new()
			actors_root.add_child(a)
			a.setup(d, mode, data, actors.size())
			actors[id] = a
		else:
			(actors[id] as CrewV3Actor).set_room(mode, data)
	for id in actors.keys():
		if not keep.has(id):
			actors[id].queue_free()
			actors.erase(id)


## MV-733: keep one PetV3Actor per pet PetsV3 has in this room (arrivals fade in, leavers fade out)
func sync_pets() -> void:
	var want := {}
	if kind == "v3" or kind == "fallback":
		for p in PetsV3.pets_in(slot):
			want[int(p.i)] = p
	for i in pets.keys():
		var a: PetV3Actor = pets[i]
		if not want.has(i) or str(want[i].breed) != a.breed:
			a.leave()
			pets.erase(i)
	for i in want:
		if not pets.has(i):
			var a := PetV3Actor.new()
			actors_root.add_child(a)
			a.setup(want[i], data)
			a.set_dim(dark)
			pets[i] = a
		else:
			(pets[i] as PetV3Actor).set_room(data)


func _is_first_quarters() -> bool:
	for i in Game.s.rooms.size():
		if str(Game.s.rooms[i].type) == "quarters" and Game.is_slot_unlocked(i):
			return i == Game.room_anchor(slot)
	return false


func _apply_dark() -> void:
	dark = kind != "locked" and Game.room_dark(slot)
	var m := DARK if dark else Color.WHITE
	bg.modulate = m
	old_art.modulate = m
	idle.modulate.a = 0.0 if dark else 1.0
	for a in actors.values():
		(a as CrewV3Actor).set_dim(1.0 if dark else 0.0)
	for a in pets.values():
		(a as PetV3Actor).set_dim(dark)


func _process(delta: float) -> void:
	_t += delta
	_pet_t -= delta
	if _pet_t <= 0.0:                 # pets hop between rooms on their own clock (PetsV3.slot_of)
		_pet_t = 0.5
		if not pets.is_empty() or not (Game.s.get("pets", []) as Array).is_empty():
			sync_pets()
	var ov: Dictionary = data.get("idle", {})
	if idle.visible and not ov.is_empty():
		_idle_t += delta * float(ov.fps)
		idle.frame = int(_idle_t) % int(ov.n)
	if kind == "v3" and data.has("stages"):
		var st := int(_t / GROW_SEC) % 3
		if st != _stage:
			_stage = st
			bg.texture = V3Art.room_tex(room_type, str(data.stages[st]))
	# the lamp only animates in a power-out; otherwise redraw when what it shows changed (MV-715: the world v2
	# body keeps a cell per room on screen all the time)
	var key := "%s/%s/%s" % [kind, dark, selected_id]
	if dark or key != _drawn:
		_drawn = key
		_top.queue_redraw()


## hotspot under a room-local point (later entries win on overlap, as in hotspots.py)
func hotspot_at(p: Vector2) -> Dictionary:
	var hit := {}
	for h in data.get("hotspots", []):
		var r: Array = h.rect
		if Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).has_point(p):
			hit = h
	return hit


func _draw_top() -> void:
	if kind == "locked":
		_top.draw_rect(Rect2(Vector2.ZERO, V3Art.CELL), Color(0.05, 0.05, 0.06))
		for y in range(8, 96, 16):
			_top.draw_line(Vector2(0, y), Vector2(144, y), Color(0.12, 0.12, 0.13), 2.0)
		_top.draw_rect(Rect2(60, 36, 24, 20), Color(0.3, 0.12, 0.08))
		_top.draw_rect(Rect2(66, 30, 12, 8), Color(0.3, 0.12, 0.08), false, 2.0)
		return
	# shared v3 emergency lamp (emergency_light.py): bracket, screws, dome; lit = pulsing red with a glow
	var a := 0.5 + 0.5 * sin(_t * TAU * 0.5)
	if dark:
		for i in 6:
			_top.draw_circle(LAMP + Vector2(0, 2), 40.0 * (1.0 - i * 0.15), Color(1.0, 0.12, 0.08, (0.05 + 0.07 * a) * 0.55))
	_top.draw_rect(Rect2(3, 2, 7, 2), Color8(34, 32, 34))
	_top.draw_rect(Rect2(3, 4, 1, 1), Color8(34, 32, 34))
	_top.draw_rect(Rect2(9, 4, 1, 1), Color8(34, 32, 34))
	_top.draw_rect(Rect2(3, 1, 1, 1), Color8(60, 58, 60))
	_top.draw_rect(Rect2(9, 1, 1, 1), Color8(60, 58, 60))
	var dome := Color8(int(130 + 125 * a), int(18 + 20 * a), 15) if dark else Color8(92, 22, 20)
	_top.draw_rect(Rect2(4, 4, 5, 3), dome)
	_top.draw_rect(Rect2(5, 7, 3, 1), dome)
	if dark:
		_top.draw_rect(Rect2(5, 4, 2, 1), Color8(255, int(150 + 80 * a), 130))
	else:
		_top.draw_rect(Rect2(5, 4, 1, 1), Color8(130, 50, 45))
	if selected_id != "":
		for h in data.get("hotspots", []):
			if str(h.id) == selected_id:
				var r: Array = h.rect
				_top.draw_rect(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])), Color(1.0, 0.85, 0.3, 0.9), false, 1.0)
