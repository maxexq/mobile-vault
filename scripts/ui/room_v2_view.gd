class_name RoomV2View
extends Control
## MV-595 trial (switch room_art_v2): the room close-up of a KITCHEN shows the approved v2 room art
## (docs/art/room-style-reference-v2.md, 144x96 per slot) with the new-scale crew, instead of the zoomed 64x52 room.
## The vehicle overview keeps the old art. Picks the art from the room level (L1-L3) and span (2 / 3 slots = the
## level-3 bar rooms) and one of three states: idle (empty), working (crew in the room) and power out
## (Game.room_dark). Light, steam, flames and crew are drawn in code on the 1 px grid of the art, at a whole-number
## scale that fits the close-up's room area; positions come from tools/anim.py in the reference folder.

const FPS := 12.0
const DIR := "res://assets/room_v2/"
const WARM := Color(1.0, 0.7, 0.35)
const GAS := Color(0.24, 0.47, 1.0)
const FLAME := Color(0.43, 0.7, 1.0)
const STEAM := Color(0.88, 0.88, 0.88)
## art key -> lamps, steam origins, burners, feet line, status LEDs [pos, colour, blink], cook spot x, walk lanes
const ART := {
	"L1": {"lamps": [Vector2(65, 9)], "pots": [Vector2(44, 40)], "burners": [Vector2(44, 51)], "floor": 90,
		"leds": [], "cook_x": 34, "lanes": [[30, 104]]},
	"L2": {"lamps": [Vector2(65, 3)], "pots": [Vector2(27, 34)], "burners": [Vector2(27, 51), Vector2(46, 51)], "floor": 90,
		"leds": [], "cook_x": 18, "lanes": [[30, 104]]},
	"L3": {"lamps": [Vector2(66, 3)], "pots": [Vector2(28, 33)], "burners": [Vector2(28, 51), Vector2(47, 51)], "floor": 90,
		"leds": [[Vector2(84, 47), Color(0.31, 1.0, 0.47), true], [Vector2(102, 46), Color(0.31, 0.67, 1.0), false]],
		"cook_x": 18, "lanes": [[30, 104]]},
	"L3_x2": {"lamps": [Vector2(66, 3), Vector2(202, 15), Vector2(234, 15), Vector2(268, 15)], "pots": [Vector2(28, 33)],
		"burners": [Vector2(28, 51), Vector2(47, 51)], "floor": 94,
		"leds": [[Vector2(84, 47), Color(0.31, 1.0, 0.47), true], [Vector2(102, 46), Color(0.31, 0.67, 1.0), false],
			[Vector2(270, 44), Color(1.0, 0.47, 0.24), true]], "cook_x": 18, "lanes": [[150, 262]]},
	"L3_x3": {"lamps": [Vector2(66, 3), Vector2(205, 14), Vector2(277, 14), Vector2(349, 14)], "pots": [Vector2(28, 33)],
		"burners": [Vector2(28, 51), Vector2(47, 51)], "floor": 94,
		"leds": [[Vector2(84, 47), Color(0.31, 1.0, 0.47), true], [Vector2(102, 46), Color(0.31, 0.67, 1.0), false]],
		"cook_x": 18, "lanes": [[150, 290], [285, 412]]},
}
const CAST := ["teen_scrap_runner", "lounge_singer", "biker", "soldier"]
const CLIP_FPS := {"walk": 10.0, "idle": 5.0, "work": 9.0}
## walking speed in art px per second
const WALK_SPEED := 14.0

## Dev preview: {"art": "L2", "state": "working"} forces what the close-up shows (empty = follow the game)
static var preview := {}
static var _clips := {}      # "name/clip" -> {"frames": [Texture2D], "feet": int, "w": int}

var slot := -1
var art_key := ""
var state := "idle"          # idle | working | powerout
var _bg: Texture2D
var _root: Node2D
var _art: Node2D
var _glow: Node2D
var _t := 0.0
var _frame := -1
var _rng := RandomNumberGenerator.new()
var _steam: Array = []       # [x, y, age, life]
var _motes: Array = []       # [x, y, dx, dy]
var _flick := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	_root = Node2D.new()
	add_child(_root)
	_art = Node2D.new()
	_art.draw.connect(_draw_art)
	_root.add_child(_art)
	_glow = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	_root.add_child(_glow)
	_rng.seed = 595


static func on() -> bool:
	return Features.on("room_art_v2")


## the art the close-up of this slot would show ("" = not a v2 room)
static func art_for(s: int) -> String:
	if preview.has("art"):
		return str(preview.art)
	if s < 0 or Game.s.is_empty() or s >= Game.s.rooms.size() or str(Game.s.rooms[s].type) != "kitchen" or Game.is_constructing(s):
		return ""
	var span := Game.room_span(s)
	if span >= 3:
		return "L3_x3"
	if span == 2:
		return "L3_x2"
	return "L%d" % clampi(int(Game.s.rooms[s].level), 1, 3)


static func state_for(s: int) -> String:
	if preview.has("state"):
		return str(preview.state)
	if Game.room_dark(s):
		return "powerout"
	return "working" if not Game.room_workers(s).is_empty() else "idle"


static func clip(char_name: String, c: String) -> Dictionary:
	var k := char_name + "/" + c
	if not _clips.has(k):
		var frames: Array = []
		var feet := 0
		var w := 0
		for i in 16:
			var p := "%screw/%s/%s/%d.png" % [DIR, char_name, c, i]
			if not ResourceLoader.exists(p):
				break
			var tex: Texture2D = load(p)
			frames.append(tex)
			var img := tex.get_image()
			feet = maxi(feet, img.get_used_rect().end.y)
			w = img.get_width()
		_clips[k] = {"frames": frames, "feet": feet, "w": w}
	return _clips[k]


func _process(delta: float) -> void:
	var s := Game.closeup_slot if Game.started else -1
	var key := art_for(s) if on() and s >= 0 else ""
	if key == "" or not ART.has(key):
		if visible:
			visible = false
			slot = -1
		return
	if key != art_key or s != slot:
		_load(key, s)
	state = state_for(slot)
	visible = true
	_layout()
	_t += delta
	var f := int(_t * FPS)
	if f != _frame:
		_frame = f
		_step()
		_art.queue_redraw()
		_glow.queue_redraw()


func _load(key: String, s: int) -> void:
	art_key = key
	slot = s
	_bg = load(DIR + "kitchen_%s.png" % key)
	_steam.clear()
	_motes.clear()
	var a: Dictionary = ART[key]
	for i in 10 * a.lamps.size():
		var l: Vector2 = a.lamps[_rng.randi() % a.lamps.size()]
		_motes.append([l.x + _rng.randf_range(-18, 18), _rng.randf_range(8, 60), _rng.randf_range(-0.08, 0.08), _rng.randf_range(0.03, 0.1)])
	for i in 30:
		_step_steam()


## centred in the close-up's room area at the biggest whole-number scale that fits
func _layout() -> void:
	var hud := get_parent() as HUD
	if hud == null or _bg == null:
		return
	var r: Rect2 = hud.room_closeup.focus_rect()
	var sz := Vector2(_bg.get_size())
	var k := maxi(1, int(minf(r.size.x / sz.x, r.size.y / sz.y)))
	_root.scale = Vector2(k, k)
	_root.position = (r.get_center() - sz * k * 0.5).floor()


func _step_steam() -> void:
	var a: Dictionary = ART[art_key]
	var rate := 3 if state == "working" else 1
	for o in a.pots:
		for i in rate:
			if _rng.randf() < 0.5:
				_steam.append([o.x + _rng.randf_range(-3, 3), o.y, 0.0, _rng.randf_range(14, 22)])
	for q in _steam:
		q[1] -= 0.45
		q[0] += sin(q[2] * 0.35 + q[0]) * 0.25
		q[2] += 1.0
	_steam = _steam.filter(func(q): return q[2] < q[3])


func _step() -> void:
	_step_steam()
	for m in _motes:
		m[0] += m[2]
		m[1] += m[3]
		if m[1] > 62:
			m[1] = 8.0
	_flick = _rng.randf() < (0.1 if state == "powerout" else 0.03)


func _px(p: Vector2, c: Color) -> void:
	_art.draw_rect(Rect2(p.floor(), Vector2.ONE), c)


func _draw_art() -> void:
	if _bg == null:
		return
	var a: Dictionary = ART[art_key]
	var sz := Vector2(_bg.get_size())
	_art.draw_rect(Rect2(Vector2(-2, -2), sz + Vector2(4, 4)), Color(0.05, 0.045, 0.04))
	_art.draw_texture(_bg, Vector2.ZERO)
	_draw_crew(a)
	if state == "powerout":
		_art.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.0, 0.01, 0.05, 0.42 if _flick else 0.72))
	var bright := 0.35 if state == "powerout" else 1.0
	for q in _steam:
		_px(Vector2(q[0], q[1]), Color(STEAM, 0.55 * (1.0 - q[2] / q[3]) * bright))
	if state == "powerout":
		var b: Vector2 = a.burners[0]
		for i in range(-2, 3):
			if _rng.randf() < 0.7:
				_px(b + Vector2(i, -_rng.randi_range(0, 1)), FLAME)
		var pulse := 0.5 + 0.5 * sin(_t * TAU * 0.5)
		_art.draw_rect(Rect2(5, 5, 2, 2), Color(0.47 + 0.53 * pulse, 0.08, 0.06))
		return
	for m in _motes:
		if _rng.randf() < 0.85:
			_px(Vector2(m[0], m[1]), Color(1, 1, 1, 0.16))
	var lit: Array = a.burners if state == "working" else [a.burners[0]]
	for b in lit:
		for i in range(-3, 4):
			if _rng.randf() < (0.8 if state == "working" else 0.4):
				_px(b + Vector2(i, -_rng.randi_range(0, 1 if state == "working" else 0)), FLAME)
	for led in a.leds:
		if not led[2] or int(_t * 2.0) % 2 == 0:
			_px(led[0], led[1])


func _draw_crew(a: Dictionary) -> void:
	var crew: Array = Game.room_workers(slot)
	if preview.has("state"):
		crew = [] if state == "idle" else [{"id": 1, "role": "cook"}, {"id": 2}, {"id": 3}]
	var floor_y := int(a.floor)
	var lanes: Array = a.lanes
	var walkers := 0
	var cook_done := false
	for d in crew:
		var is_cook := Crew.role(d) == "cook"
		var who := "street_cook" if is_cook else str(CAST[int(d.id) % CAST.size()])
		if state == "powerout":
			_draw_frame(who, "idle", Vector2(_bg.get_width() * 0.5 + (int(d.id) % 3 - 1) * 26, floor_y + 1), true)
		elif is_cook and not cook_done:
			cook_done = true
			_draw_frame(who, "work", Vector2(a.cook_x + 8, floor_y), false)
		elif walkers < lanes.size() * 2:
			var lane: Array = lanes[walkers % lanes.size()]
			var span := float(lane[1] - lane[0])
			var ph := fmod(_t * WALK_SPEED + walkers * span * 0.7, span * 2.0)
			var right := ph < span
			var x := float(lane[0]) + (ph if right else span * 2.0 - ph)
			_draw_frame(who, "walk", Vector2(x, floor_y + 1), not right)
			walkers += 1


## one crew frame with its feet on `feet` (the clip's lowest opaque row), mirrored when walking left
func _draw_frame(who: String, c: String, feet: Vector2, flip: bool) -> void:
	var cl := clip(who, c)
	if cl.frames.is_empty():
		c = "idle"
		cl = clip(who, c)
		if cl.frames.is_empty():
			return
	var tex: Texture2D = cl.frames[int(_t * float(CLIP_FPS.get(c, 8.0))) % cl.frames.size()]
	var w := float(cl.w)
	var pos := Vector2(roundf(feet.x - w * 0.5), feet.y - float(cl.feet))
	if flip:
		_art.draw_set_transform(Vector2(pos.x + w, pos.y), 0.0, Vector2(-1, 1))
		_art.draw_texture(tex, Vector2.ZERO)
		_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_art.draw_texture(tex, pos)


func _glow_at(c: Vector2, r: float, col: Color, a: float) -> void:
	var steps := 6
	for i in steps:
		var rr := r * (1.0 - float(i) / steps)
		_glow.draw_circle(c, rr, Color(col, a / steps * (1.0 - rr / r + 0.15)))


func _draw_glow() -> void:
	if _bg == null:
		return
	var a: Dictionary = ART[art_key]
	if state == "powerout":
		if _flick:
			for l in a.lamps:
				_glow_at(l + Vector2(0, 6), 26, WARM, 0.35)
		var pulse := 0.5 + 0.5 * sin(_t * TAU * 0.5)
		_glow_at(Vector2(6, 6), 34, Color(1.0, 0.12, 0.08), 0.55 * pulse)
		_glow_at(a.burners[0], 10, GAS, 0.35)
		return
	var base := 0.3 if state == "working" else 0.22
	var amp := base * (0.92 + 0.08 * sin(_t * 8.4)) if not _flick else 0.05
	for l in a.lamps:
		_glow_at(l + Vector2(0, 8), 34 if state == "working" else 30, WARM, amp)
	var lit: Array = a.burners if state == "working" else [a.burners[0]]
	for b in lit:
		_glow_at(b - Vector2(0, 2), 12 if state == "working" else 8, GAS, 0.28 if state == "working" else 0.16)
	for led in a.leds:
		if not led[2] or int(_t * 2.0) % 2 == 0:
			_glow_at(led[0], 6, led[1], 0.35)
