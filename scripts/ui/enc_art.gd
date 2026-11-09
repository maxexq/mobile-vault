class_name EncArt
## Expedition encounter art v2 (MV-717, switch "enc_art_v2"): 320x160 scenes inpainted into the approved
## expedition interiors, no crew drawn: the team's flashlight comes in from the left edge in code and sweeps
## from the floor onto the encounter. Each encounter ships a still (frame 30, light on target) and a
## 48-frame sheet (8 x 6 cells of 320x160, 10 fps): frames 0-17 = light clicks on and sweeps in (played once),
## 18-47 = hold with jitter and flicker (looped). Sources: designs/enc-art/approved/ in the project files.

const DIR := "res://assets/events/v2/"
const W := 320
const H := 160
const COLS := 8
const FRAMES := 48
const LOOP_FROM := 18
const FPS := 10.0


static func on(image: String) -> bool:
	return Features.on("enc_art_v2") and ResourceLoader.exists(DIR + image + ".png")


## the art for an encounter image id (e.g. "enc_cry"): v2 still when the switch is on, else the old 160x80
static func still(image: String) -> Texture2D:
	if on(image):
		return load(DIR + image + ".png")
	return load("res://assets/events/%s.png" % image)


## first frame of the animated sheet, as an AtlasTexture that animate() then steps; old art when off
static func anim_texture(image: String) -> Texture2D:
	if not on(image) or not ResourceLoader.exists(DIR + image + "_anim.png"):
		return still(image)
	var at := AtlasTexture.new()
	at.atlas = load(DIR + image + "_anim.png")
	at.region = Rect2(0, 0, W, H)
	return at


static func frame_rect(i: int) -> Rect2:
	return Rect2((i % COLS) * W, (i / COLS) * H, W, H)


## frame shown `t` seconds after the popup opened: sweep once, then loop the hold part
static func frame_at(t: float) -> int:
	var f := int(t * FPS)
	if f < FRAMES:
		return f
	return LOOP_FROM + (f - FRAMES) % (FRAMES - LOOP_FROM)


## drive an AtlasTexture from anim_texture() on `rect` (the popup's media TextureRect); no-op for plain textures
static func animate(rect: TextureRect) -> void:
	if rect == null or not (rect.texture is AtlasTexture):
		return
	var at: AtlasTexture = rect.texture
	var t0 := Time.get_ticks_msec()
	var tw := rect.create_tween().set_loops()
	tw.tween_interval(1.0 / FPS)
	tw.tween_callback(func(): at.region = frame_rect(frame_at((Time.get_ticks_msec() - t0) / 1000.0)))
