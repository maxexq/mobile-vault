class_name EngineArt
## Engine menu art v2 (MV-766, switch "engine_art_v2"): every engine type drawn on its own at 112x80 (PixelLab,
## same three-quarter angle as the v3 engine bay) plus an 8-frame running loop (10 fps). The engine menu shows the
## loop while the vault drives and the still when it is parked; the swap list shows the still at half size.
## Body and base never move in the loop: only fans, belts, flames, glow and smoke (locked in code before import).
## Sources: project files designs/engine-menu-art/approved/<id>/ (still.png, 00..07.png); off = the old 56x40 eng_*.

const DIR := "res://assets/engines_v2/"
const W := 112
const H := 80
const FRAMES := 8
const FPS := 10.0


static func on(id: String) -> bool:
	return Features.on("engine_art_v2") and ResourceLoader.exists(DIR + "eng_" + id + ".png")


## still of an engine type (EngineBay.TYPES key): 112x80 v2 when the switch is on, else the old 56x40 atlas sprite
static func still(id: String) -> Texture2D:
	if on(id):
		return load(DIR + "eng_" + id + ".png")
	return Atlas.tex("eng_" + id)


## first frame of the running loop as an AtlasTexture that animate() then steps; the still when off
static func anim_texture(id: String) -> Texture2D:
	if not on(id) or not ResourceLoader.exists(DIR + "eng_" + id + "_run.png"):
		return still(id)
	var at := AtlasTexture.new()
	at.atlas = load(DIR + "eng_" + id + "_run.png")
	at.region = frame_rect(0)
	at.set_meta("engine_run", true)   # animate() steps only this, never a shared Atlas.tex sprite
	return at


static func frame_rect(i: int) -> Rect2:
	return Rect2((i % FRAMES) * W, 0, W, H)


## the engine turns over only while the vault drives (EngineBay.tick runs it then); parked = frame 0 held
static func running() -> bool:
	return Game.is_moving() and not EngineBay.seized()


## step the AtlasTexture from anim_texture() on `rect` while the engine runs; no-op for anything else
## (the old eng_* sprite is a cached, shared Atlas.tex AtlasTexture and must never be re-cut)
static func animate(rect: TextureRect) -> void:
	if rect == null or not (rect.texture is AtlasTexture) or not rect.texture.has_meta("engine_run"):
		return
	var at: AtlasTexture = rect.texture
	var f := [0]
	var tw := rect.create_tween().set_loops()
	tw.tween_interval(1.0 / FPS)
	tw.tween_callback(func():
		f[0] = (f[0] + 1) % FRAMES if running() else 0
		at.region = frame_rect(f[0]))
