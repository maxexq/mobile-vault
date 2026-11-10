class_name DeckerSign
extends RefCounted
## MV-744 (switch decker_sign): the Decker's "9 DEPOT" destination sign doubles as the bus's status board. An alert
## (raid, hull, low water / food / fuel / power) runs across the old LED face in amber (a raid in red); when nothing is
## wrong the sign shows its route and now and then scrolls a cheerful line. The sign lifts crew spirits a little
## (Game.decker_sign_happy, tune decker_sign.happy). AmbulanceMotion draws it: a blank copy of the sign face covers the
## baked "9 DEPOT", and a white strip of text in this 5x7 font scrolls behind a window the size of the face.

const GLYPH_W := 5
const GLYPH_H := 7
const ADV := 6                 # glyph + 1 px gap
const SCROLL_PX := 16.0        # px per second
const CHEER_GAP := Vector2(18.0, 34.0)   # seconds between cheerful lines (random in range)
const LOW := 0.15              # a resource below this share of its cap is "low"
const HULL_LOW := 0.3

## status lines (English: it is a bus destination board)
const CHEERS := ["ALL ABOARD", "NEXT STOP: HOPE", "HOLD ON TIGHT", "HOME SWEET BUS", "NO ZOMBIES ON BOARD",
	"SMILE, WE'RE ALIVE", "MIND THE GAP", "KEEP ROLLING"]

## 5x7 font, one string of 5 chars per row ("#" = lit)
const FONT := {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
	"!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
	":": [".....", "..#..", "..#..", ".....", "..#..", "..#..", "....."],
	".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
	",": [".....", ".....", ".....", ".....", ".##..", "..#..", ".#..."],
	"'": ["..#..", "..#..", ".#...", ".....", ".....", ".....", "....."],
	"-": [".....", ".....", ".....", ".###.", ".....", ".....", "....."],
	" ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
}


static func on() -> bool:
	return Features.on("decker_sign")


## pixel width of a line in the sign font
static func text_w(text: String) -> int:
	return maxi(0, text.length() * ADV - 1)


## white text on transparent, GLYPH_H tall; pad = empty px before and after (the scroll runs in and out)
static func text_image(text: String, pad: int = 0) -> Image:
	var w := text_w(text) + pad * 2
	var img := Image.create_empty(maxi(1, w), GLYPH_H, false, Image.FORMAT_RGBA8)
	var x0 := pad
	for ch in text.to_upper():
		var rows: Array = FONT.get(ch, FONT[" "])
		for y in GLYPH_H:
			var row: String = rows[y]
			for x in GLYPH_W:
				if row[x] == "#":
					img.set_pixel(x0 + x, y, Color.WHITE)
		x0 += ADV
	return img


## the alerts that are true right now, most urgent first: [text, kind] with kind "raid" (red) or "warn" (amber)
static func alerts() -> Array:
	var out: Array = []
	if Game.s.is_empty():
		return out
	if Threat.phase == "raid":
		out.append(["RAID!", "raid"])
	elif Threat.phase == "warning":
		out.append(["RAID AHEAD", "raid"])
	if float(Game.s.get("hull", 100.0)) < Game.hull_max() * HULL_LOW:
		out.append(["HULL LOW", "warn"])
	var res: Dictionary = Game.s.get("res", {})
	for k in ["water", "food", "fuel", "power"]:
		if res.has(k) and float(res[k]) < Game.cap(k) * LOW:
			out.append(["%s LOW" % k.to_upper(), "warn"])
	return out
