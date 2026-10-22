extends Node
## Texture-atlas loader. All small sprites live in ONE png (assets/atlas/atlas.png)
## so the browser downloads a single texture and batches draw calls.
## Usage: Atlas.tex("ic_power")  -> AtlasTexture (cached)

const ATLAS_PNG := "res://assets/atlas/atlas.png"
const ATLAS_JSON := "res://assets/atlas/atlas.json"
const VARIANTS_JSON := "res://assets/atlas/dweller_variants.json"

## frame layout of every dweller sheet (14x20 px chibi frames) – must match tools/art/chars.py
const DW_W := 14
const DW_H := 20
const DW_FRAMES := {"idle": [0, 1], "walk": [2, 3, 4, 5], "sit": [6], "work": [7, 8]}
const DW_FPS := {"idle": 2.0, "walk": 8.0, "sit": 1.0, "work": 4.0}

var sheet: Texture2D
var regions: Dictionary = {}
var dweller_variants: Array = []
var _cache: Dictionary = {}
var _frames_cache: Dictionary = {}


func _ready() -> void:
	sheet = load(ATLAS_PNG)
	var f := FileAccess.open(ATLAS_JSON, FileAccess.READ)
	regions = JSON.parse_string(f.get_as_text())
	var v := FileAccess.open(VARIANTS_JSON, FileAccess.READ)
	dweller_variants = JSON.parse_string(v.get_as_text())


func has(region_name: String) -> bool:
	return regions.has(region_name)


func tex(region_name: String) -> AtlasTexture:
	if _cache.has(region_name):
		return _cache[region_name]
	var at := AtlasTexture.new()
	at.atlas = sheet
	var r: Array = regions.get(region_name, [0, 0, 1, 1])
	at.region = Rect2(r[0], r[1], r[2], r[3])
	at.filter_clip = true
	_cache[region_name] = at
	return at


func icon(icon_name: String) -> AtlasTexture:
	return tex("ic_" + icon_name)


func sub(region_name: String, rect: Rect2) -> AtlasTexture:
	var key := "%s@%s" % [region_name, rect]
	if _cache.has(key):
		return _cache[key]
	var r: Array = regions[region_name]
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(r[0] + rect.position.x, r[1] + rect.position.y, rect.size.x, rect.size.y)
	at.filter_clip = true
	_cache[key] = at
	return at


## first idle frame -> portrait for UI
func dweller_portrait(variant: String) -> AtlasTexture:
	return sub(variant, Rect2(0, 0, DW_W, DW_H))


func dweller_frames(variant: String) -> SpriteFrames:
	if _frames_cache.has(variant):
		return _frames_cache[variant]
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim in DW_FRAMES:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, DW_FPS[anim])
		sf.set_animation_loop(anim, true)
		for idx in DW_FRAMES[anim]:
			sf.add_frame(anim, sub(variant, Rect2(idx * DW_W, 0, DW_W, DW_H)))
	_frames_cache[variant] = sf
	return sf


func wheel_frames() -> SpriteFrames:
	if _frames_cache.has("_wheel"):
		return _frames_cache["_wheel"]
	var sf := SpriteFrames.new()
	if not sf.has_animation("default"):
		sf.add_animation("default")
	sf.set_animation_speed("default", 12.0)
	for i in 4:
		sf.add_frame("default", tex("wheel_%d" % i))
	_frames_cache["_wheel"] = sf
	return sf


func track_frames() -> SpriteFrames:
	if _frames_cache.has("_tracks"):
		return _frames_cache["_tracks"]
	var sf := SpriteFrames.new()
	if not sf.has_animation("default"):
		sf.add_animation("default")
	sf.set_animation_speed("default", 12.0)
	for i in 4:
		sf.add_frame("default", tex("mod_tracks_%d" % i))
	_frames_cache["_tracks"] = sf
	return sf
