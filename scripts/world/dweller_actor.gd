class_name DwellerActor
extends Node2D
## Little pixel survivor living inside a room: idles, wanders, sits, and uses the room's equipment.

enum State { IDLE, WALK, WORK, SIT }

## x positions (room-local) where a dweller "uses" equipment, per room type
const WORK_SPOTS := {
	"kitchen": [14, 36, 60], "hydroponics": [14, 34, 56, 70], "water": [12, 30, 62], "medical": [12, 44, 66],
	"armory": [20, 34, 70], "science": [16, 50, 60], "radio": [12, 30, 52], "engine": [28, 40, 66], "quarters": [14, 58],
}
const SIT_ROOMS := ["quarters", "kitchen", "radio"]
const FLOOR_Y := 46.0
const X_MIN := 7.0
const X_MAX := 57.0

var did := -1
var room_type := ""
var spr: AnimatedSprite2D
var state := State.IDLE
var timer := 0.0
var target_x := 28.0
var speed := 11.0


func setup(d: Dictionary, rtype: String, index: int) -> void:
	did = int(d.id)
	room_type = rtype
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = Atlas.dweller_frames(d.variant)
	spr.centered = false
	spr.offset = Vector2(-Atlas.DW_W / 2, -Atlas.DW_H)
	add_child(spr)
	position = Vector2(12.0 + index * 18.0 + randf_range(-3, 3), FLOOR_Y)
	position.x = clampf(position.x, X_MIN, X_MAX)
	spr.flip_h = randf() < 0.5
	_enter(State.WORK if randf() < 0.6 else State.IDLE)
	spr.frame = randi() % 2


func _enter(st: State) -> void:
	state = st
	match st:
		State.IDLE:
			timer = randf_range(1.2, 3.5)
			spr.play("idle")
		State.WALK:
			target_x = randf_range(X_MIN, X_MAX)
			spr.play("walk")
		State.WORK:
			var spots: Array = WORK_SPOTS.get(room_type, [28])
			target_x = float(spots[randi() % spots.size()]) + randf_range(-2, 2)
			timer = randf_range(3.0, 7.0)
			spr.play("walk")
		State.SIT:
			timer = randf_range(4.0, 9.0)
			spr.play("sit")


func _process(delta: float) -> void:
	match state:
		State.IDLE, State.SIT:
			timer -= delta
			if timer <= 0.0:
				var r := randf()
				if r < 0.45:
					_enter(State.WORK)
				elif r < 0.75 or not room_type in SIT_ROOMS:
					_enter(State.WALK)
				else:
					_enter(State.SIT)
		State.WALK, State.WORK:
			var dx := target_x - position.x
			if absf(dx) > 0.6:
				position.x += signf(dx) * minf(absf(dx), speed * delta)
				spr.flip_h = dx < 0.0
				if spr.animation != "walk":
					spr.play("walk")
			else:
				if state == State.WALK:
					_enter(State.IDLE)
				else:
					if spr.animation != "work":
						spr.play("work")
					timer -= delta
					if timer <= 0.0:
						_enter(State.IDLE)
	# pixel-snap so sprites never shimmer
	spr.position = Vector2(round(position.x) - position.x, 0)
