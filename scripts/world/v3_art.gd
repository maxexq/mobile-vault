class_name V3Art
extends RefCounted
## MV-711: the v3 room art (144x96 per cell, Room guide v3) and the ref v3 crew (~60 px drawn on 64x64, shown at
## 2/3) that tools/v3_import.py copied into assets/v3/. rooms.json / crew.json describe every image; this class
## loads them once and hands out textures, the per-level data (floor polygon, stand points, hotspots, crew blend
## colours, idle micro-animation sheet) and SpriteFrames per character.
## Rooms whose set is still In Review (status "review") are only used while switch rooms_v3_review is on.

const DIR := "res://assets/v3/"
const CELL := Vector2(144, 96)
const CREW_SCALE := 2.0 / 3.0      # crew ref v3 rule: room x3, crew x2 on screen
const FEET := Vector2(-32, -64)    # frame offset: 64x64 canvas, feet on the bottom row
## MV-734 (Parames 2026-11-09, option C): in the world view one v3 room pixel is one rendered pixel, so crew at 2/3
## got 0.67 px per sprite pixel and nearest sampling dropped every third row and column ("the crew look blurry").
## There the crew are drawn at full pixel size (1 sprite px = 1 room px, ~60 room px tall); the interior view, where
## a room pixel is several screen pixels, keeps 2/3. Switch crew_world_full.
const CREW_SCALE_WORLD := 1.0
## which v3 character plays a recruit variant: the named crew roster keep a fixed look; everyone else gets a stable
## pick from their id (the 2.5D crew are 11 people, the old variants many more)
const CREW_IDS := ["ren", "clara", "bit", "wan", "sorn", "lin", "tham", "fah", "krai", "ploy", "noi"]
## old outfit word in the variant -> the v3 people who fit it (picked by id among them)
const VARIANT_CREW := {"medic": ["ren", "clara"], "chef": ["wan", "ploy"], "army": ["fah", "sorn"], "scav": ["noi", "krai"],
	"builder": ["bit", "tham"], "jumpsuit": ["bit", "lin"]}

static var _rooms := {}
static var _empty := {}
static var _crew := {}
static var _tex := {}
static var _frames := {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var r = JSON.parse_string(FileAccess.get_file_as_string(DIR + "rooms.json"))
	if r is Dictionary:
		_rooms = r.get("rooms", {})
		_empty = r.get("empty", {})
	var c = JSON.parse_string(FileAccess.get_file_as_string(DIR + "crew.json"))
	if c is Dictionary:
		_crew = c.get("crew", {})


static func ok() -> bool:
	_load()
	return not _rooms.is_empty() and not _crew.is_empty()


## every room type that has a v3 set, with its status ("approved" | "review")
static func room_types() -> Dictionary:
	_load()
	var out := {}
	for t in _rooms:
		out[t] = str(_rooms[t].status)
	return out


## the v3 set used for this room type right now (empty = draw the old art in the cell)
static func has_room(t: String) -> bool:
	_load()
	if not _rooms.has(t):
		return false
	return str(_rooms[t].status) == "approved" or Features.on("rooms_v3_review")


static func level_key(level: int) -> String:
	return "L%d" % clampi(level, 1, 3)


## per-level data (file, floor, hotspots, tint, dark, lamp_x, idle?, stages?) or {} when there is no v3 set in use
static func level(t: String, lv: int) -> Dictionary:
	if not has_room(t):
		return {}
	return (_rooms[t].levels as Dictionary).get(level_key(lv), {})


## the empty cell / building site: stage 1 just started, 2 under construction, 3 finished shell
static func empty_stage(stage: int) -> Dictionary:
	_load()
	if _empty.is_empty():
		return {}
	return (_empty.levels as Dictionary).get("stage%d" % clampi(stage, 1, 3), {})


static func room_tex(t: String, file: String) -> Texture2D:
	var p := DIR + "rooms/%s/%s" % [t, file]
	if not _tex.has(p):
		_tex[p] = load(p) if ResourceLoader.exists(p) else null
	return _tex[p]


static func crew_ids() -> Array:
	_load()
	return _crew.keys()


static func crew_for(d: Dictionary) -> String:
	var v := str(d.get("variant", ""))
	var id := absi(int(d.get("id", 0)))
	for word in VARIANT_CREW:
		if v.contains(word):
			var pick: Array = VARIANT_CREW[word]
			return pick[id % pick.size()]
	return CREW_IDS[absi(id * 7 + v.hash()) % CREW_IDS.size()]


## MV-722: the character's approved 64x64 bust portrait (MV-708), null when it has none.
## MV-735: `mood` = "happy" / "stressed" / "injured" picks that face (falls back to the neutral one when missing)
const PORTRAIT_MOODS := ["happy", "stressed", "injured"]
## Dr. Ren's extra faces (MV-735) for events and the tutorial
const PORTRAIT_MOODS_EXTRA := ["surprised", "angry", "sad", "scared", "thinking", "talking", "tired", "sick"]
## Dr. Ren's explaining poses with a hand (MV-735): point at a tutorial target, or a raised finger for tips
const PORTRAIT_POSES := ["point_left", "point_right", "point_up", "finger_up"]
static func has_portrait_mood(cid: String, mood: String) -> bool:
	_load()
	return mood == "" or ((_crew.get(cid, {}) as Dictionary).get("portrait_moods", {}) as Dictionary).has(mood)
static func portrait_tex(cid: String, mood: String = "") -> Texture2D:
	_load()
	var e := _crew.get(cid, {}) as Dictionary
	var f := str(e.get("portrait", ""))
	if mood != "":
		f = str((e.get("portrait_moods", {}) as Dictionary).get(mood, f))
	if f == "":
		return null
	var p := DIR + f
	if not _tex.has(p):
		_tex[p] = load(p) if ResourceLoader.exists(p) else null
	return _tex[p]


static func crew_frames(cid: String) -> SpriteFrames:
	_load()
	if _frames.has(cid):
		return _frames[cid]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var e: Dictionary = _crew.get(cid, {})
	var p := DIR + "crew/" + str(e.get("file", ""))
	var sheet: Texture2D = load(p) if not e.is_empty() and ResourceLoader.exists(p) else null
	if sheet != null:
		var clips: Dictionary = e.clips
		for clip in clips:
			sf.add_animation(clip)
			sf.set_animation_speed(clip, float(clips[clip].fps))
			sf.set_animation_loop(clip, true)
			for i in int(clips[clip].n):
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(i * 64, int(clips[clip].row) * 64, 64, 64)
				sf.add_frame(clip, at)
	_frames[cid] = sf
	return sf


static func color_of(a: Array, alpha: float = 1.0) -> Color:
	if a.size() < 3:
		return Color(1, 1, 1, alpha)
	var k := 255.0 if float(a[0]) > 1.0 or float(a[1]) > 1.0 or float(a[2]) > 1.0 else 1.0
	return Color(float(a[0]) / k, float(a[1]) / k, float(a[2]) / k, alpha)
