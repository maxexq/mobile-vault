class_name BossesV2
## MV-718: the six lore checkpoint bosses (The Foreman, Glass King, Mossback Alpha, Bog Mother, Cryo Titan,
## Warden-9) that replace the old biome bosses (Junk Golem ... Overseer Mech). HD art: redrawn at 1.5x crew
## density (Cryo Titan 1.19x) and repainted inside the biome's dusk scene, facing left. Each boss has a walk
## loop (Bog Mother hops), an attack with its own FX and the same attack without FX ("strike").
## Sheets + feet anchor come from tools/bosses_v2_import.py (assets/bosses_v2/). Shown at Features
## "bosses_v2.scale" (0.5 = the same pixel size as crew v3 and enemies v2 with world_2x).

const DIR := "res://assets/bosses_v2/"
const WALK_FPS := 10.0
const ATTACK_FPS := 12.0

static var _meta: Dictionary = {}
static var _frames: Dictionary = {}     # biome -> SpriteFrames (cached, shared)


static func meta() -> Dictionary:
	if _meta.is_empty():
		var f := FileAccess.open(DIR + "bosses_v2.json", FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_meta = d
	return _meta


static func on() -> bool:
	return Features.on("bosses_v2")


## the spawned boss carries the biome of its v2 art (Combat._spawn sets e.boss_v2)
static func use_for(e: Dictionary) -> bool:
	return on() and e.get("boss", false) and meta().has(str(e.get("boss_v2", "")))


static func scale() -> float:
	return Features.num("bosses_v2.scale", 0.5)


## which attack clip plays when the boss hits: "attack" (FX drawn in) or "strike" (no FX)
static func attack_clip() -> String:
	return "attack" if Features.num("bosses_v2.fx", 1.0) >= 0.5 else "strike"


static func info(biome: String) -> Dictionary:
	return meta().get(biome, {})


static func frames(biome: String) -> SpriteFrames:
	if _frames.has(biome):
		return _frames[biome]
	var m := info(biome)
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var fw := int(m.fw)
	for clip in ["walk", "attack", "strike"]:
		var tex: Texture2D = load(DIR + "%s_%s.png" % [str(m.key), clip])
		sf.add_animation(clip)
		sf.set_animation_speed(clip, WALK_FPS if clip == "walk" else ATTACK_FPS)
		sf.set_animation_loop(clip, clip == "walk")
		for i in int(m.frames[clip]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, 0, fw, int(m.fh))
			sf.add_frame(clip, at)
	_frames[biome] = sf
	return sf
