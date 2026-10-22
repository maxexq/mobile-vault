class_name Chatter
extends Node2D
## Idle chatter: every so often a survivor says a context-aware line (Lore.pick_line) in a little
## green terminal speech bubble above their head. Bubbles sit on a screen-space layer of the world
## viewport (always 1:1 pixels, even while the camera is zoomed into a room) and track the speaker.

const MIN_GAP := 9.0
const MAX_GAP := 20.0
const LIFE := 4.2
const MAX_W := 128

var vehicle: Vehicle
var combat_view: CombatView
var focus_slot := -1          # during a room close-up only that room talks
var _t := 6.0
var _rng := RandomNumberGenerator.new()
var _bubbles: Array = []      # [{node, actor, t}]
static var _tex: Texture2D
static var _tail: Texture2D


func _ready() -> void:
	_rng.randomize()
	z_index = 60
	if _tex == null:
		_tex = load("res://assets/ui/bubble.png")
		_tail = load("res://assets/ui/bubble_tail.png")


func _process(delta: float) -> void:
	for b in _bubbles.duplicate():
		b.t -= delta
		var actor = b.actor
		if b.t <= 0.0 or not is_instance_valid(actor) or not (actor as Node2D).is_visible_in_tree():
			_free_bubble(b)
			continue
		_place(b)
	if not Game.started or Game.s.is_empty() or Game.active_event != "":
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = _rng.randf_range(MIN_GAP, MAX_GAP)
	say_random()


func _candidates() -> Array:
	var out := []
	for rv in vehicle.room_views:
		if focus_slot >= 0 and rv.slot != focus_slot:
			continue
		for did in rv.actors:
			out.append([did, rv.actors[did]])
	if vehicle.cab_view and (focus_slot < 0 or focus_slot == Data.CAB_SLOT):
		for did in vehicle.cab_view.actors:
			out.append([did, vehicle.cab_view.actors[did]])
	if focus_slot < 0:
		for n in combat_view.hero_nodes:
			if n and not n.dead:
				out.append([n.did, n])
	return out


func say_random() -> void:
	var c := _candidates()
	if c.is_empty() or _bubbles.size() >= 2:
		return
	var pick: Array = c[_rng.randi() % c.size()]
	var d := Game.dweller_by_id(int(pick[0]))
	if d.is_empty():
		return
	var line := Lore.pick_line(d, _rng)
	if line != "":
		say(pick[1], line)


func say(actor: Node2D, text: String) -> void:
	for b in _bubbles:
		if b.actor == actor:
			_free_bubble(b)
			break
	var root := Node2D.new()
	add_child(root)
	var box := NinePatchRect.new()
	box.texture = _tex
	box.patch_margin_left = 3
	box.patch_margin_right = 3
	box.patch_margin_top = 3
	box.patch_margin_bottom = 3
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIKit.font_main)
	l.add_theme_font_size_override("font_size", UIKit.FS_SMALL)
	l.add_theme_color_override("font_color", UIKit.C_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# measure: single line if it fits, otherwise wrap at MAX_W
	var w := UIKit.font_main.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FS_SMALL).x
	l.custom_minimum_size.x = minf(ceilf(w) + 1.0, MAX_W)
	l.position = Vector2(4, 1)
	root.add_child(l)
	l.reset_size()
	var sz := (l.size + Vector2(8, 3)).ceil()
	box.size = sz
	var tail := Sprite2D.new()
	tail.texture = _tail
	tail.centered = false
	tail.position = Vector2(6, sz.y - 1)
	root.add_child(tail)
	var b := {"node": root, "actor": actor, "t": LIFE, "size": sz}
	_bubbles.append(b)
	_place(b)
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.15)


func _place(b: Dictionary) -> void:
	var actor: Node2D = b.actor
	var root: Node2D = b.node
	var sz: Vector2 = b.size
	var xf := actor.get_global_transform_with_canvas()
	var z := xf.get_scale().y
	var head := xf.origin + Vector2(-7.0 * z, -21.0 * z)
	var pos := head + Vector2(-2, -sz.y - 3)
	var vp := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 2, vp.x - sz.x - 2)
	pos.y = clampf(pos.y, 2, vp.y - sz.y - 2)
	root.position = pos.round()


func _free_bubble(b: Dictionary) -> void:
	_bubbles.erase(b)
	var n: Node2D = b.node
	if is_instance_valid(n):
		var tw := n.create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 0.2)
		tw.tween_callback(n.queue_free)
