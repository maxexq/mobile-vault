class_name TraitFx
extends Control
## MV-483 (MV-485..498): the light of one trait card, drawn for the card's REAL size (cards grow with their text, so a
## fixed 160x58 bitmap can't be used). light() is the same algorithm as tools/art/ui.py trait_light(), which made the
## approved canonical masks; the autotest checks this port against them pixel for pixel at 160x58.
##  * a (w+12)x(h+12) paint cell at the card origin minus (6,6); the card content (inset 4) never lights; the light
##    stays within 4 px of the card; it ignores input
##  * beneficial = clean tier-coloured pulse, travelling glints, outside motes; trade-off = the dominant broken crimson
##    edge with an uneven flicker, hot fragments and downward embers (RED / RED_HOT), never the text or the body
##  * the light strengths decode to three levels (faint / lit / hot) and are coloured here; each (profile, size, phase)
##    becomes one small texture, cached (bounded, oldest first) and redrawn only when the phase changes
##  * one shared clock at 8 fps, 16 phases = a 2 s loop, advanced only while visible and the game isn't paused

const FPS := 8.0
const PHASES := 16
const PAD := 6
const FLICKER := [0.62, 0.70, 0.66, 0.84, 0.73, 0.97, 0.76, 0.82, 0.68, 0.73, 0.92, 0.80, 0.66, 0.71, 0.78, 0.68]
const HOT_S := 1.25
## approved colours (tools/art/trait_cards/build_preview.py): tier emission / hot, and the trade-off crimson
const EMIT := [Color8(190, 190, 177), Color8(88, 225, 65), Color8(51, 166, 255), Color8(190, 58, 252), Color8(255, 175, 44), Color8(255, 59, 86)]
const HOT := [Color8(238, 236, 217), Color8(194, 255, 161), Color8(181, 239, 255), Color8(243, 180, 255), Color8(255, 236, 165), Color8(255, 180, 185)]
const RED := Color8(214, 43, 42)
const RED_HOT := Color8(255, 118, 83)
const CACHE_MAX := 96

## GOD: "" = live, "still" = the static look, "off" = no light at all
static var preview := ""
static var paused_preview := false
static var _clock := 0.0
static var _clock_frame := -1
static var _cache := {}
static var _order: Array = []

var negative := false
var tier := -1            # -1 = not classified yet (MV-497): the quiet semantic fallback
var phase := -1
var _tex: Texture2D
var _key := ""


static func current_phase() -> int:
	return int(floor(_clock * FPS)) % PHASES


static func frame_step() -> void:
	paused_preview = true
	_clock = float(current_phase() + 1) / FPS + 0.001


## "anim", "still" (switch off / reduced effects / not classified), "accent" (a beneficial trait not classified: only the
## semantic bar), "off" (style off or GOD)
static func mode_for(neg: bool, t: int) -> String:
	if not Features.on("trait_card_style") or preview == "off":
		return "off"
	if t < 0:
		return "still" if neg else "accent"
	if preview == "still" or not Features.on("trait_card_vfx") or RoomAnim.reduced():
		return "still"
	return "anim"


static func _path(x0: int, y0: int, x1: int, y1: int, ch: int) -> Array:
	var v := [Vector2i(x0 + ch, y0), Vector2i(x1 - ch, y0), Vector2i(x1, y0 + ch), Vector2i(x1, y1 - ch),
		Vector2i(x1 - ch, y1), Vector2i(x0 + ch, y1), Vector2i(x0, y1 - ch), Vector2i(x0, y0 + ch)]
	var pts: Array = []
	for i in v.size():
		var a: Vector2i = v[i]
		var b: Vector2i = v[(i + 1) % v.size()]
		var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
		for k in steps:
			var p := Vector2i(int(round(a.x + (b.x - a.x) * float(k) / steps)), int(round(a.y + (b.y - a.y) * float(k) / steps)))
			if pts.is_empty() or pts[-1] != p:
				pts.append(p)
	return pts


## light strengths {Vector2i: s} in the (w+12)x(h+12) cell, the card at (6,6): tools/art/ui.py trait_light()
static func light(neg: bool, rank: int, index: int, w: int, h: int, still: bool, accent_only: bool = false) -> Dictionary:
	var lit := {}
	var x0 := PAD
	var y0 := PAD
	var x1 := PAD + w - 1
	var y1 := PAD + h - 1
	var rim := _path(x0, y0, x1, y1, 2)
	var n := PHASES
	var ph := 0 if still else (index + rank * 2) % n
	for y in range(y0 + 3, y1 - 2):
		lit[Vector2i(x0 + 1, y)] = 0.6
		lit[Vector2i(x0 + 2, y)] = 0.6
	if accent_only:
		return lit
	if not neg:
		var pulse: float = round((1.0 - cos(TAU * ph / n)) * 2.0) / 4.0
		var s: float = 0.5 if rank == 0 else 0.3 + 0.7 * pulse
		if still:
			s = 0.5
		for p in rim:
			lit[p] = s
		if rank >= 2 and not still:
			for ring in range(1, mini(rank - 1, 2) + 1):
				var ringp := _path(x0 - ring, y0 - ring, x1 + ring, y1 + ring, 2 + ring)
				for i in ringp.size():
					if (i + ph + ring) % 3 != 0 and not lit.has(ringp[i]):
						lit[ringp[i]] = 0.25
		if not still:
			var head := ph * rim.size() / n
			var length := int(round((3 if rank == 0 else 5 + rank) * 1.4))
			for offset in ([0, rim.size() / 2] if rank >= 3 else [0]):
				for k in length:
					lit[rim[posmod(head + offset - k, rim.size())]] = 0.6 + 0.65 * float(length - k) / length
			var count: int = [0, 1, 2, 3, 4, 5][rank]
			var orbit := _path(x0 - 3, y0 - 3, x1 + 3, y1 + 3, 5)
			for m in count:
				var o: Vector2i = orbit[posmod(ph * orbit.size() / n + m * orbit.size() / count, orbit.size())]
				var size := 1 if rank < 4 else 2
				for dx in size:
					for dy in size:
						lit[Vector2i(o.x + dx, o.y + dy)] = 0.6 + 0.6 * float((ph + m) % 4) / 3.0
	else:
		var gain := 0.86 + (float(FLICKER[ph]) - 0.75) * (0.35 + rank * 0.13)
		if still:
			gain = 0.86
		for i in rim.size():
			if (i * 7 + 3) % 23 < 3:
				continue
			lit[rim[i]] = 0.6 * gain
		if rank >= 1 and not still:
			for ring in range(1, mini(rank, 2) + 1):
				var ringp := _path(x0 - ring, y0 - ring, x1 + ring, y1 + ring, 2 + ring)
				for i in ringp.size():
					if (i + ph * 2 + ring) % 4 == 0 and not lit.has(ringp[i]):
						lit[ringp[i]] = 0.25
		if not still:
			var head := (ph * rim.size() / n + rank * 15) % rim.size()
			var length := int(round((3 + rank) * 1.4))
			for k in length:
				if k % 3 == 2:
					continue
				lit[rim[(head + k) % rim.size()]] = 1.0 - 0.3 * float(k) / length
			var count: int = [0, 1, 2, 3, 4, 6][rank]
			for m in count:
				var age := (ph + m * 5) % n
				var ex := (x0 - 3 if m % 2 == 0 else x1 + 2) + ((age / 4 + m) % 2)
				var ey := y0 + age * h / n
				var size := 2 if rank == 5 and m % 3 == 0 else 1
				for dx in size:
					for dy in size:
						lit[Vector2i(ex + dx, ey + dy)] = 0.35 + 0.65 * float(n - age) / n
			if rank >= 4:
				var b: Vector2i = rim[(rank * 43 + ph / 2 * 6) % rim.size()]
				for dx in 2:
					for dy in 2:
						lit.erase(Vector2i(b.x + dx, b.y + dy))
	for p in lit.keys():
		if p.x >= x0 + 4 and p.x < x1 - 3 and p.y >= y0 + 4 and p.y < y1 - 3:
			lit.erase(p)
	return lit


## 0 = dark, 1 = faint (gray2), 2 = lit (gray4), 3 = hot (gray6): the same thresholds as the mask codes
static func level(s: float) -> int:
	if s < 0.02:
		return 0
	if s < 0.45:
		return 1
	if s < 0.9:
		return 2
	return 3


static func colour(lv: int, base: Color, hot: Color) -> Color:
	match lv:
		1:
			return Color(base.r * 0.3, base.g * 0.3, base.b * 0.3)
		2:
			return Color(base.r * 0.75, base.g * 0.75, base.b * 0.75)
		3:
			return base.lerp(hot, 0.65)
	return Color(0, 0, 0, 0)


## one cached texture per (look, size, phase); the oldest entries go first once CACHE_MAX are held
static func texture_for(neg: bool, t: int, mode: String, p: int, w: int, h: int) -> Texture2D:
	var key := "%s|%d|%s|%d|%dx%d" % [neg, t, mode, p, w, h]
	if _cache.has(key):
		return _cache[key]
	var rank := maxi(t, 0)
	var img := Image.create(w + PAD * 2, h + PAD * 2, false, Image.FORMAT_RGBA8)
	var base: Color = RED if neg else (EMIT[rank] if t >= 0 else UIKit.C_GREEN)
	var hot: Color = RED_HOT if neg else (HOT[rank] if t >= 0 else UIKit.C_GREEN)
	var lit := light(neg, rank, p, w, h, mode != "anim", mode == "accent")
	for q in lit:
		var lv := level(float(lit[q]))
		if lv > 0 and q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
			img.set_pixelv(q, colour(lv, base, hot))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	_order.append(key)
	while _order.size() > CACHE_MAX:
		_cache.erase(_order.pop_front())
	return tex


func setup(neg: bool, t: int) -> void:
	negative = neg
	tier = t
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	phase = -1


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var mode := mode_for(negative, tier)
	var p := 0
	if mode == "anim":
		if is_inside_tree() and not get_tree().paused and not paused_preview and Engine.get_process_frames() != _clock_frame:
			_clock_frame = Engine.get_process_frames()
			_clock = fmod(_clock + delta, float(PHASES) / FPS)
		p = current_phase()
	var w := int(size.x) - PAD * 2
	var h := int(size.y) - PAD * 2
	var key := "%s|%d|%dx%d" % [mode, p, w, h]
	if key != _key:
		_key = key
		phase = p
		_tex = null if mode == "off" or w < 16 or h < 16 else texture_for(negative, tier, mode, p, w, h)
		queue_redraw()


func _draw() -> void:
	if _tex:
		draw_texture(_tex, Vector2.ZERO)
