class_name BossIntro
extends Control
## MV-387: the moment a boss walks on. Checkpoint warlord: white flash, red pulse on the screen edges and a
## hazard-stripe "WARNING" band with the name; a mutant boss: a smaller "BOSS" band. Elites get no band (they
## are common), only the world cue in CombatView. Never takes input; hidden while a room close-up is open.
## Switch boss_intro, tune boss_intro.time (length ×) and boss_intro.flash (white flash strength).

const DUR := {"warlord": 2.6, "boss": 1.8}
const BAND_H := {"warlord": 48.0, "boss": 32.0}
const FLASH := 0.35

var kind := ""              # "" = idle
var band_y := 120.0         # top of the band (set by the HUD layout)
var _t := 0.0
var _dur := 1.0
var _title: Label
var _name: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = UIKit.label("", UIKit.FP, UIKit.C_WHITE, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_name = UIKit.label("", UIKit.FS_BIG, UIKit.C_WHITE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_color_override("font_outline_color", Color("0b0a10"))
	_name.add_theme_constant_override("outline_size", 3)
	add_child(_name)
	for l in [_title, _name]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	Combat.entrance.connect(_on_entrance)


func _on_entrance(e: Dictionary) -> void:
	var k := "warlord" if e.get("warlord", false) else ("boss" if e.get("boss", false) else "")
	if k == "" or Game.closeup_slot >= 0:
		return
	play(k, str(e.get("name", "")), int(e.get("lvl", 1)))


func play(k: String, title: String, lvl: int) -> void:
	kind = k
	_t = 0.0
	_dur = float(DUR[k]) * Features.num("boss_intro.time", 1.0)
	_title.text = "!! WARNING !!" if k == "warlord" else "- BOSS -"
	_title.add_theme_color_override("font_color", UIKit.C_RED if k == "warlord" else UIKit.C_GOLD)
	_title.add_theme_font_size_override("font_size", UIKit.FP * 2 if k == "warlord" else UIKit.FP)
	_name.text = "%s  Lv.%d" % [title, lvl]
	_name.add_theme_font_size_override("font_size", UIKit.FS_HUGE if k == "warlord" else UIKit.FS_BIG)
	visible = true
	Trace.rec("combat", "boss_intro", {"kind": k, "lvl": lvl})


func _process(delta: float) -> void:
	if kind == "":
		return
	_t += delta
	if _t >= _dur or Game.closeup_slot >= 0:
		kind = ""
		visible = false
		return
	var big := kind == "warlord"
	_title.size = Vector2(size.x, 18 if big else 10)
	_title.position = Vector2(_slide(), band_y + (5.0 if big else 4.0)).round()
	_name.size = Vector2(size.x, 22)
	_name.position = Vector2(-_slide(), band_y + (20.0 if big else 11.0)).round()
	# the title blinks for a warlord
	_title.visible = kind != "warlord" or int(_t * 5.0) % 2 == 0 or _t > _dur * 0.6
	_title.modulate.a = _fade()
	_name.modulate.a = _fade()
	queue_redraw()


## 0 -> 1 over the first 0.18 s, back to 0 over the last 0.3 s
func _fade() -> float:
	return clampf(minf(_t / 0.18, (_dur - _t) / 0.3), 0.0, 1.0)


## text and stripes sweep in from the side, then settle
func _slide() -> float:
	var k := clampf(_t / 0.25, 0.0, 1.0)
	return roundf((1.0 - k) * (1.0 - k) * size.x * 0.6)


func _draw() -> void:
	if kind == "":
		return
	var h: float = BAND_H[kind]
	var w := size.x
	var warlord := kind == "warlord"
	var f := _fade()
	# white flash in the first frames
	var fl := Features.num("boss_intro.flash", FLASH) * (1.0 if warlord else 0.5)
	if _t < 0.12 and fl > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, fl * (1.0 - _t / 0.12)))
	# red pulse on the screen edges (warlord)
	if warlord:
		var p := 0.25 + 0.2 * sin(_t * TAU * 1.5)
		for i in 4:
			var a := p * (1.0 - i / 4.0) * 0.6 * f
			var t := 4.0 * (i + 1)
			var c := Color(0.7, 0.08, 0.05, a)
			draw_rect(Rect2(0, 0, w, t), c)
			draw_rect(Rect2(0, size.y - t, w, t), c)
			draw_rect(Rect2(0, 0, t, size.y), c)
			draw_rect(Rect2(w - t, 0, t, size.y), c)
	# the band: dark body, hazard stripes top and bottom scrolling opposite ways
	var y := band_y
	draw_rect(Rect2(0, y, w, h), Color(0.04, 0.035, 0.05, 0.86 * f))
	var stripe := 4.0 if warlord else 3.0
	var dark := Color("0b0a10", f)
	var col := Color(Color("d4a02c") if warlord else UIKit.C_LINE, f)
	var off := fmod(_t * 40.0, 16.0)
	for row in [[y, 1.0], [y + h - stripe, -1.0]]:
		var ry: float = row[0]
		draw_rect(Rect2(0, ry, w, stripe), dark)
		var x := -16.0 + off * float(row[1])
		while x < w + 16.0:
			# 8 px slanted blocks, drawn as stacked 1 px rows so they stay on the pixel grid
			for r in int(stripe):
				draw_rect(Rect2(roundf(x + r), ry + r, 8, 1), col)
			x += 16.0
	if warlord and int(_t * 5.0) % 2 == 0:
		draw_rect(Rect2(0, y + stripe, w, 1), Color(UIKit.C_RED, 0.8 * f))
		draw_rect(Rect2(0, y + h - stripe - 1, w, 1), Color(UIKit.C_RED, 0.8 * f))
