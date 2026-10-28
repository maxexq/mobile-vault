class_name BossArt
## MV-558: the animated 128px biome bosses. One sheet per boss in assets/atlas/bosses/<id>.png, packed by
## tools/art/boss_sheets.py: a row per animation (walk = chase loop, attack once, death once + hold), every
## cell the same size with the feet at "pivot". Drawn at 1x: the art is already boss-sized.

const DIR := "res://assets/atlas/bosses/"

static var _meta: Dictionary = {}
static var _frames: Dictionary = {}


static func has(id: String) -> bool:
	return id != "" and ResourceLoader.exists(DIR + id + ".png")


static func meta(id: String) -> Dictionary:
	if not _meta.has(id):
		var f := FileAccess.open(DIR + id + ".json", FileAccess.READ)
		_meta[id] = JSON.parse_string(f.get_as_text()) if f else {}
	return _meta[id]


## SpriteFrames with "walk", "attack" and "death" (cached: every spawn of this boss shares them)
static func frames(id: String) -> SpriteFrames:
	if _frames.has(id):
		return _frames[id]
	var m := meta(id)
	var sheet: Texture2D = load(DIR + id + ".png")
	var cw := int(m.cell[0])
	var ch := int(m.cell[1])
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim in m.anims:
		var a: Dictionary = m.anims[anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(a.fps))
		sf.set_animation_loop(anim, bool(a.loop))
		for i in int(a.count):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * cw, int(a.row) * ch, cw, ch)
			at.filter_clip = true
			sf.add_frame(anim, at)
	_frames[id] = sf
	return sf


## sprite offset that puts the feet on the node's position
static func offset(id: String) -> Vector2:
	var p: Array = meta(id).pivot
	return -Vector2(float(p[0]), float(p[1]))


## how long the death animation lasts before the body may fade (seconds, last-frame hold included)
static func death_time(id: String) -> float:
	var a: Dictionary = meta(id).anims.get("death", {})
	if a.is_empty():
		return 0.0
	return float(int(a.count) - 1) / float(a.fps)
