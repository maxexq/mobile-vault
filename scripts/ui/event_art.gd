class_name EventArt
## Road event art v2 (MV-730, switch "event_art_v2"): the 21 road events redrawn at 320x160 with no vehicle
## in the scene (MV-674/675), each with its 3-beat story animation (threat -> action -> outcome).
## ev_<image>_anim.png = 80 frames as 10 x 8 cells of 320x160, played at 10 fps with the last frame held
## 1.6 s, then the story starts again (same timing as the approved GIFs). ev_<image>.png = the last frame
## (the outcome beat), shown on the result screen. Made by tools/event_art_import.py from the project
## files designs/event-art-*/hd/novan/. Off, or an image with no v2 art = the old 160x80 picture.

const DIR := "res://assets/events/v2/"
const W := 320
const H := 160
const COLS := 10
const FRAMES := 80
const FPS := 10.0
const HOLD := 1.6   # seconds the last frame stays before the story repeats


static func on(image: String) -> bool:
	return Features.on("event_art_v2") and ResourceLoader.exists(DIR + "ev_" + image + ".png")


static func old(image: String) -> Texture2D:
	return load("res://assets/events/%s.png" % image)


## the outcome still when the switch is on and the art exists, else the old 160x80
static func still(image: String) -> Texture2D:
	if on(image):
		return load(DIR + "ev_" + image + ".png")
	return old(image)


## first frame of the story sheet as an AtlasTexture that animate() steps; the old art when off
static func anim_texture(image: String) -> Texture2D:
	if not on(image) or not ResourceLoader.exists(DIR + "ev_" + image + "_anim.png"):
		return still(image)
	var at := AtlasTexture.new()
	at.atlas = load(DIR + "ev_" + image + "_anim.png")
	at.region = Rect2(0, 0, W, H)
	return at


static func frame_rect(i: int) -> Rect2:
	return Rect2((i % COLS) * W, (i / COLS) * H, W, H)


## seconds per full story: 79 frames at 10 fps + the held last frame
static func cycle() -> float:
	return (FRAMES - 1) / FPS + HOLD


## frame shown `t` seconds after the event opened: play the story, hold the end, repeat
static func frame_at(t: float) -> int:
	var tt := fmod(maxf(t, 0.0), cycle())
	return mini(int(tt * FPS + 0.0001), FRAMES - 1)


## drive an AtlasTexture from anim_texture() on `rect` (the popup's media TextureRect); `t0_ms` = when the
## event opened (Time.get_ticks_msec), so a rebuilt window (picking defenders) keeps the story going
static func animate(rect: TextureRect, t0_ms: int) -> void:
	if rect == null or not (rect.texture is AtlasTexture):
		return
	var at: AtlasTexture = rect.texture
	at.region = frame_rect(frame_at((Time.get_ticks_msec() - t0_ms) / 1000.0))
	var tw := rect.create_tween().set_loops()
	tw.tween_interval(1.0 / FPS)
	tw.tween_callback(func(): at.region = frame_rect(frame_at((Time.get_ticks_msec() - t0_ms) / 1000.0)))
