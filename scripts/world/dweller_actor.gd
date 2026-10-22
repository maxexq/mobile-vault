class_name DwellerActor
extends Node2D
## Little pixel survivor living inside a room: idles, wanders, sits, uses the room's equipment and — when off
## duty in the quarters (or idle anywhere) — plays little micro-animations: strumming a guitar, sipping coffee,
## cleaning a rifle. Striking crew sit down with a protest sign.

enum State { IDLE, WALK, WORK, SIT, FUN }

## x positions (room-local) where a dweller "uses" equipment, per room type (64 px rooms)
const WORK_SPOTS := {
	"kitchen": [11, 29, 48], "hydroponics": [11, 27, 45, 56], "water": [10, 24, 50], "medical": [10, 35, 53],
	"armory": [16, 27, 56], "science": [13, 40, 48], "radio": [10, 24, 42], "engine": [22, 32, 53], "quarters": [11, 46],
	"refinery": [12, 36, 52], "workshop": [10, 26, 48],
}
const SIT_ROOMS := ["quarters", "kitchen", "radio", "workshop"]
const FUN_ANIMS := ["guitar", "coffee", "clean"]
const FLOOR_Y := 46.0
const X_MIN := 7.0
const X_MAX := 57.0

var did := -1
var room_type := ""
var striking := false
var spr: AnimatedSprite2D
var state := State.IDLE
var timer := 0.0
var target_x := 28.0
var speed := 11.0
var _fun := "coffee"


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


func _off_duty() -> bool:
	if room_type == "quarters":
		return true
	var d := Game.dweller_by_id(did)
	return d.is_empty() or int(d.get("room", -1)) < 0


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
		State.FUN:
			_fun = FUN_ANIMS[randi() % FUN_ANIMS.size()]
			timer = randf_range(5.0, 11.0)
			if spr.sprite_frames.has_animation(_fun):
				spr.play(_fun)
			else:
				spr.play("sit")


func _process(delta: float) -> void:
	if striking:
		if state != State.SIT:
			_enter(State.SIT)
		spr.pause()
		queue_redraw()
	match state:
		State.IDLE, State.SIT, State.FUN:
			if striking:
				return
			timer -= delta
			if timer <= 0.0:
				var r := randf()
				if _off_duty() and r < 0.45:
					_enter(State.FUN)
				elif r < 0.45:
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
	spr.position = Vector2(round(position.x) - position.x, 0)


func _draw() -> void:
	if not striking:
		return
	# hand-painted protest sign on a stick
	var x: float = roundf(position.x) - position.x + 5.0
	draw_rect(Rect2(x + 2, -26, 1, 10), Color("3a2818"))
	draw_rect(Rect2(x - 3, -32, 11, 7), Color("0c0a0a"))
	draw_rect(Rect2(x - 2, -31, 9, 5), Color("b2a88a"))
	draw_rect(Rect2(x, -30, 1, 3), Color("a8372a"))
	draw_rect(Rect2(x, -26, 1, 1), Color("a8372a"))
	draw_rect(Rect2(x + 3, -30, 3, 1), Color("a8372a"))
	draw_rect(Rect2(x + 3, -28, 3, 1), Color("a8372a"))
