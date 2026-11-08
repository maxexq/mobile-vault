class_name EnemiesV2
## MV-714: v2 enemy art (MV-677/680/703). Every non-boss mob of the 6 biomes has an 8-frame move clip and an
## 8-frame attack clip drawn at crew v3 pixel density (Dr. Ren 61 px = 1.75 m), facing left. Sheets and the
## body anchor come from tools/enemies_v2_import.py (assets/enemies_v2/). The world shows them at
## Features "enemies_v2.scale" (0.5: with world_2x one art px of the sheet = one world-viewport px, no mixels).

const DIR := "res://assets/enemies_v2/"
const MOVE_FPS := 10.0
const ATTACK_FPS := 12.0

static var _meta: Dictionary = {}
static var _frames: Dictionary = {}     # mob -> SpriteFrames (cached, shared by every actor)


static func meta() -> Dictionary:
	if _meta.is_empty():
		var f := FileAccess.open(DIR + "enemies_v2.json", FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_meta = d
	return _meta


## the switch is on and this mob has v2 art (wave/checkpoint bosses keep their own sprites)
static func use_for(e: Dictionary) -> bool:
	if not Features.on("enemies_v2") or e.get("boss", false) or e.get("warlord", false):
		return false
	return meta().has(str(e.get("mob", "")))


static func scale() -> float:
	return Features.num("enemies_v2.scale", 0.5)


static func info(mob: String) -> Dictionary:
	return meta().get(mob, {})


static func frames(mob: String) -> SpriteFrames:
	if _frames.has(mob):
		return _frames[mob]
	var m := info(mob)
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for clip in ["walk", "attack"]:
		var tex: Texture2D = load(DIR + "%s_%s.png" % [mob, "move" if clip == "walk" else "attack"])
		sf.add_animation(clip)
		sf.set_animation_speed(clip, MOVE_FPS if clip == "walk" else ATTACK_FPS)
		sf.set_animation_loop(clip, clip == "walk")
		var fw := int(m.fw)
		for i in int(m.frames):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, 0, fw, int(m.fh))
			sf.add_frame(clip, at)
	_frames[mob] = sf
	return sf
