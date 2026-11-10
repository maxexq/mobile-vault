class_name LandmarkArt
extends RefCounted
## MV-750 landmarks v2 (switch "landmarks_v2"): the 13 expedition sites redrawn for world v2 at 2x density
## (same pixel size as the ambulance v3 shell and the near / road parallax layers), wider than the old 100 px
## sprites, with ground that fades into low ragged mounds at both ends (never cut by a frame).
## assets/landmarks/v2/<sprite>.png + landmarks.json {scale, sites: {<sprite>: {door, w, h}}} (door = doorway centre
## in image px). Sources: project files designs/landmarks-v2/approved/. Off = the old 100 px atlas sprites.

const DIR := "res://assets/landmarks/v2/"
const OLD_DOOR := 30.0          # door centre inside every old lm_* atlas sprite (tools/art/landmarks.py DOOR_X)

static var _cfg: Dictionary = {}


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var f := FileAccess.open(DIR + "landmarks.json", FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_cfg = d
	return _cfg


## is the v2 art in use for this sprite?
static func on(sprite: String) -> bool:
	return Features.on("landmarks_v2") and cfg().get("sites", {}).has(sprite) and ResourceLoader.exists(DIR + sprite + ".png")


static func texture(sprite: String) -> Texture2D:
	if on(sprite):
		return load(DIR + sprite + ".png")
	return Atlas.tex(sprite) if Atlas.has(sprite) else null


## draw scale of the sprite node (v2 art is 2x density)
static func scale(sprite: String) -> float:
	return float(cfg().get("scale", 0.5)) if on(sprite) else 1.0


## doorway centre from the sprite's left edge, in world (art) px
static func door(sprite: String) -> float:
	if on(sprite):
		return float(cfg().sites[sprite].get("door", 60)) * scale(sprite)
	return OLD_DOOR


## drawn size in world (art) px
static func size(sprite: String) -> Vector2:
	var t := texture(sprite)
	return t.get_size() * scale(sprite) if t else Vector2.ZERO


## expedition panel thumbnail: a 128x128 crop of the v2 art around the doorway (shown at 64x64 = the world's 0.5)
static func thumb(sprite: String) -> Texture2D:
	var t := texture(sprite)
	if t == null or not on(sprite):
		return t
	var w := t.get_width()
	var h := t.get_height()
	var side := mini(128, mini(w, h))
	var cx := clampi(int(cfg().sites[sprite].get("door", 60)) + 40, side / 2, w - side / 2)
	var y0 := clampi(h - side - int(h * 0.08), 0, h - side)
	var a := AtlasTexture.new()
	a.atlas = t
	a.region = Rect2(cx - side / 2, y0, side, side)
	return a
