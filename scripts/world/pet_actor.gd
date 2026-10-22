class_name PetActor
extends Node2D
## An adopted pet (dog / cat / two-headed hen) that actually lives on the vehicle: it trots around a room,
## sits next to the crew, naps, then slips through the hatch to another room (fades out, pops up elsewhere).
## Frames: pet_<kind>_0/1 walk, _2 sit, _3 sleep (tools/art/chars.py).

enum S { WALK, SIT, SLEEP, LEAVE }

const FLOOR_Y := 46.0
var kind := "dog"
var pet_name := ""
var vehicle: Vehicle
var slot := -1
var spr: Sprite2D
var state := S.WALK
var timer := 2.0
var target_x := 30.0
var speed := 16.0
var _anim_t := 0.0
var _frame := 0


func setup(v: Vehicle, k: String, n: String) -> void:
	vehicle = v
	kind = k
	pet_name = n
	speed = {"dog": 18.0, "cat": 14.0, "hen": 9.0}.get(k, 14.0)
	spr = Sprite2D.new()
	spr.centered = false
	add_child(spr)
	z_index = 3
	_hop_to_random_room(true)


func _tex(f: int) -> Texture2D:
	return Atlas.tex("pet_%s_%d" % [kind, f])


func _hop_to_random_room(instant: bool) -> void:
	var cands := []
	for rv in vehicle.room_views:
		if Game.is_slot_unlocked(rv.slot) and Game.s.rooms[rv.slot].type != "empty":
			cands.append(rv.slot)
			if not Game.room_occupants(rv.slot).is_empty():
				cands.append(rv.slot)      # prefers rooms with people in them
	if cands.is_empty():
		cands = [Data.ENGINE_SLOT]
	slot = cands[randi() % cands.size()]
	var base := vehicle.slot_local_pos(slot)
	position = Vector2(base.x + randf_range(8, 52), base.y + FLOOR_Y)
	modulate.a = 1.0 if instant else 0.0
	if not instant:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.4)
	_enter(S.WALK)


func _enter(st: S) -> void:
	state = st
	match st:
		S.WALK:
			var base := vehicle.slot_local_pos(slot)
			target_x = base.x + randf_range(6, 56)
			timer = randf_range(2.0, 5.0)
		S.SIT:
			timer = randf_range(3.0, 7.0)
		S.SLEEP:
			timer = randf_range(6.0, 14.0)
		S.LEAVE:
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.35)
			tw.tween_callback(func(): _hop_to_random_room(false))


func _process(delta: float) -> void:
	if vehicle == null or slot < 0:
		return
	_anim_t += delta
	match state:
		S.WALK:
			var dx := target_x - position.x
			if absf(dx) > 0.6:
				position.x += signf(dx) * minf(absf(dx), speed * delta)
				spr.flip_h = dx < 0.0
				if _anim_t > 0.18:
					_anim_t = 0.0
					_frame = 1 - _frame
				spr.texture = _tex(_frame)
			else:
				var r := randf()
				_enter(S.SIT if r < 0.45 else (S.SLEEP if r < 0.6 else (S.LEAVE if r < 0.8 else S.WALK)))
		S.SIT, S.SLEEP:
			spr.texture = _tex(2 if state == S.SIT else 3)
			timer -= delta
			if timer <= 0.0:
				_enter(S.LEAVE if randf() < 0.4 else S.WALK)
		S.LEAVE:
			pass
	var h := float(spr.texture.get_height()) if spr.texture else 10.0
	spr.position = Vector2(round(position.x) - position.x - 7.0, -h)
	# dark rooms hide the pet (the flashlights only catch the crew)
	visible = not (Game.room_dark(slot) and state == S.SLEEP)
