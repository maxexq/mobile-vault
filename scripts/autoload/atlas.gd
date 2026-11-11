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
const DW_FRAMES := {"idle": [0, 1], "walk": [2, 3, 4, 5], "sit": [6], "work": [7, 8],
	"guitar": [9, 10], "coffee": [11, 12], "clean": [13, 14], "hammer": [15, 16, 17], "carry": [18, 19]}
const DW_FPS := {"idle": 2.0, "walk": 8.0, "sit": 1.0, "work": 4.0, "guitar": 5.0, "coffee": 1.2, "clean": 3.0,
	"hammer": 6.0, "carry": 6.0}

var sheet: Texture2D
var regions: Dictionary = {}
var dweller_variants: Array = []
var _cache: Dictionary = {}
var _v2_cache: Dictionary = {}
const V2_ONLY := {"neutral": "happy", "stressed": "sad", "broken": "sad"}
var _frames_cache: Dictionary = {}
## MV-775 icons B (switch icons_room16): native 16 px icons at the pixel size of the v3 room objects
const ICONS16_PNG := "res://assets/icons16/icons16.png"
const ICONS16_JSON := "res://assets/icons16/icons16.json"
var _i16_sheet: Texture2D
var _i16_index: Dictionary = {}
var _i16_cols := 16
var _i16_cache: Dictionary = {}


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


## MV-694: icons_v2 on -> the 32 px PixelLab icon `ic2_<name>` wrapped in an IconTex that still reports 16x16,
## so layouts never change. Mood icons "stressed" / "broken" exist only in v2 (old set falls back to "sad").
func icon(icon_name: String) -> Texture2D:
	if Features.on("icons_room16"):
		var t16 := icon16(icon_name)
		if t16 != null:
			return t16
	if Features.on("icons_v2") and regions.has("ic2_" + icon_name):
		var key := "ic2_" + icon_name
		if not _v2_cache.has(key):
			_v2_cache[key] = IconTex.new(tex(key))
		return _v2_cache[key]
	if not regions.has("ic_" + icon_name) and V2_ONLY.has(icon_name):
		return tex("ic_" + str(V2_ONLY[icon_name]))
	return tex("ic_" + icon_name)


## MV-775: the 16 px room-style icon `name` ("medkit", or "set_<piece>" for a gear set piece), null if there is none
func icon16(icon_name: String) -> Texture2D:
	if _i16_cache.has(icon_name):
		return _i16_cache[icon_name]
	if _i16_sheet == null:
		var f := FileAccess.open(ICONS16_JSON, FileAccess.READ)
		if f == null:
			return null
		var j: Dictionary = JSON.parse_string(f.get_as_text())
		_i16_index = j.get("icons", {})
		_i16_cols = int(j.get("cols", 16))
		_i16_sheet = load(ICONS16_PNG)
	if not _i16_index.has(icon_name):
		return null
	var i := int(_i16_index[icon_name])
	var at := AtlasTexture.new()
	at.atlas = _i16_sheet
	at.region = Rect2(16 * (i % _i16_cols), 16 * (i / _i16_cols), 16, 16)
	at.filter_clip = true
	_i16_cache[icon_name] = at
	return at


## the old 16 px icon even while icons_v2 is on (GOD before/after preview)
func icon_v1(icon_name: String) -> AtlasTexture:
	return tex("ic_" + str(V2_ONLY.get(icon_name, icon_name)) if not regions.has("ic_" + icon_name) else "ic_" + icon_name)


## mood icon for a happiness value / morale stage (MV-694): happy >= mood.happy_icon 70, neutral >= 50, sad, stressed (Depressed), broken
func mood_icon(happy: float, stage: String = "") -> Texture2D:
	if stage == "broken":
		return icon("broken")
	if stage == "depressed":
		return icon("stressed")
	if stage == "" and happy >= Features.num("mood.happy_icon", 70.0):
		return icon("happy")
	if stage == "" and happy >= 50.0:
		return icon("neutral")
	if stage == "" and happy >= Features.num("morale.depressed", 35.0):
		return icon("sad")
	if happy >= Features.num("morale.broken", 20.0):
		return icon("stressed")
	return icon("broken")


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


func wheel_frames(offroad: bool = false) -> SpriteFrames:
	return _loop_frames("bwheel" if offroad else "wheel", 4, 12.0)


func rail_wheel_frames() -> SpriteFrames:
	return _loop_frames("rwheel", 4, 12.0)


func _loop_frames(prefix: String, n: int, fps: float) -> SpriteFrames:
	var key := "_" + prefix
	if _frames_cache.has(key):
		return _frames_cache[key]
	var sf := SpriteFrames.new()
	if not sf.has_animation("default"):
		sf.add_animation("default")
	sf.set_animation_speed("default", fps)
	for i in n:
		sf.add_frame("default", tex("%s_%d" % [prefix, i]))
	_frames_cache[key] = sf
	return sf


## MV-388: a numbered strip <prefix>_0..n-1 as one "default" animation (cached per prefix)
func strip_frames(prefix: String, n: int, fps: float, loop: bool = true) -> SpriteFrames:
	var sf := _loop_frames(prefix, n, fps)
	sf.set_animation_loop("default", loop)
	return sf


## MV-566: fine = the redrawn belt (mod_tracks_<i>_fine, switch mod_detail_fine)
func track_frames(fine: bool = false) -> SpriteFrames:
	var key := "_tracks_fine" if fine else "_tracks"
	if _frames_cache.has(key):
		return _frames_cache[key]
	var sf := SpriteFrames.new()
	if not sf.has_animation("default"):
		sf.add_animation("default")
	sf.set_animation_speed("default", 12.0)
	for i in 4:
		sf.add_frame("default", tex(("mod_tracks_%d_fine" if fine else "mod_tracks_%d") % i))
	_frames_cache[key] = sf
	return sf
