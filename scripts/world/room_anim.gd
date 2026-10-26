class_name RoomAnim
extends Sprite2D
## One room-local micro-animation (MV-429 foundation for the room expansion): an atlas strip <prefix>_0..n-1 drawn at
## a fixed spot in the 64x52 room art, below the crew. The shared lamp / dust ambience (RoomAmbience) is separate and
## never counts as a room's own animation.
##  * it moves only while its room is doing its thing (RoomX.active(slot, active)), the room is lit, the switches
##    rooms_expansion and room_ambience are on and nothing reduces effects; otherwise it holds the rest frame, so the
##    rest frame + the background must look like the approved room (never a moving copy over a baked copy)
##  * its clock only runs while it is visible and the game isn't paused (a hidden tab doesn't process at all), so
##    it never jumps after a pause; each instance gets a phase offset so two rooms of one kind don't move in step
##  * one Sprite2D per strip, textures swapped in place: no nodes spawned while it plays
## GOD can force a mode ("rest" / "active") and step frames by hand (preview / frame_step).

## GOD preview for every RoomAnim: "" = live, "rest" = hold the rest frame, "active" = play as if active
static var preview := ""
static var paused_preview := false     # GOD frame stepping: the clock stops, frame_step() moves one frame

var slot := -1
var prefix := ""
var count := 1
var fps := 3.0
var loop := true
var rest := 0
var active_kind := "job"
var cur_frame := -1
var _t := 0.0
var _phase := 0.0
var _textures: Array = []


## spec = {prefix, count, fps, loop, rest, x, y, active}
func setup(room_slot: int, spec: Dictionary) -> void:
	add_to_group("room_anim")
	slot = room_slot
	prefix = str(spec.get("prefix", ""))
	count = maxi(1, int(spec.get("count", 1)))
	fps = maxf(0.1, float(spec.get("fps", 3.0)))
	loop = bool(spec.get("loop", true))
	rest = clampi(int(spec.get("rest", 0)), 0, count - 1)
	active_kind = str(spec.get("active", "job"))
	centered = false
	position = Vector2(float(spec.get("x", 0)), float(spec.get("y", 0)))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_textures.clear()
	for i in count:
		_textures.append(Atlas.tex("%s_%d" % [prefix, i]) if Atlas.has("%s_%d" % [prefix, i]) else null)
	_phase = float(absi(hash("%s:%d" % [prefix, slot])) % 997) / 997.0 * float(count) / fps
	_t = 0.0
	_show(rest)


## should it move right now
func playing() -> bool:
	if preview == "rest":
		return false
	if not Features.on("rooms_expansion") or not Features.on("room_ambience") or reduced():
		return false
	if preview == "active":
		return true
	return RoomX.active(slot, active_kind)


## a reduced-effects setting does not exist yet: this is the one place to hook it in
static func reduced() -> bool:
	return false


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not playing():
		_t = 0.0
		_show(rest)
		return
	if not paused_preview:
		_t += delta
	var f := int(floor((_t + _phase) * fps))
	if loop:
		f = f % count
	else:
		f = f % (count + 1)      # a one-shot strip plays through, then holds its rest frame for one beat
		if f == count:
			f = rest
	_show(f if not paused_preview else cur_frame)


## GOD: move one frame forward (with paused_preview on)
func frame_step() -> void:
	_show((maxi(cur_frame, 0) + 1) % count)


func _show(f: int) -> void:
	if f == cur_frame:
		return
	cur_frame = f
	texture = _textures[f] if f >= 0 and f < _textures.size() else null
