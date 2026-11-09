class_name RtCouplings
extends Node2D
## MV-740: the road train's couplings drawn in code, in shell px inside the world v2 root (Parames: the air lines must
## run unbroken from unit to unit). The lead trailer's red / blue air lines already run on into the first container
## trailer in the art; this node adds what the art lacks:
## - container trailer -> container trailer: the 4 air lines (2 red, 2 blue) sag from the rear end post of the unit in
##   front to the hose ends on the nose of the unit behind, and a steel link joins the tow hook to the drawbar beam
## - no trailer behind the lead trailer: its air line ends get coupler heads on the end post instead of ending in air
## The lines sway a pixel with the road while driving (`sway` is set by the Vehicle).

const RED := Color8(121, 46, 53)
const BLUE := Color8(46, 65, 110)
const DARK := Color8(14, 12, 12)
const STEEL := Color8(85, 81, 69)
const STEEL_HI := Color8(128, 122, 104)
const BASE_H := 380.0                       # anchors are measured on the 2-deck shells; rows shift with the height
## [rear end post (unit in front), hose end on the nose (unit behind), colour]
const LINES := [
	[Vector2(489, 312), Vector2(0, 312), RED], [Vector2(489, 318), Vector2(0, 319), BLUE],
	[Vector2(489, 330), Vector2(1, 332), RED], [Vector2(489, 337), Vector2(0, 341), BLUE]]
const BODY_CAPS := [Vector2(691, 329), Vector2(691, 340)]   # the lead trailer's air line ends (red, blue)

var hoses: Array = []        # {a, b, col}
var links: Array = []        # Rect2 steel bars
var caps: Array = []         # Vector2 top-left of a 3x3 coupler head
var sway := 0.0              # extra sag in px (whole px when drawn)


## trailers: top-left (shell px) of each container trailer, front first; their shell height (decks)
func setup(body_pos: Vector2, body_h: float, trailers: Array, trailer_h: float) -> void:
	hoses.clear()
	links.clear()
	caps.clear()
	if trailers.is_empty():
		for c in BODY_CAPS:
			caps.append(body_pos + c + Vector2(0, body_h - BASE_H))
	var dy := trailer_h - BASE_H
	for i in range(1, trailers.size()):
		var front: Vector2 = trailers[i - 1]
		var back: Vector2 = trailers[i]
		for l in LINES:
			hoses.append({"a": front + (l[0] as Vector2) + Vector2(0, dy), "b": back + (l[1] as Vector2) + Vector2(0, dy), "col": l[2]})
		var x0 := front.x + 493.0
		links.append(Rect2(x0, front.y + 349.0 + dy, back.x + 2.0 - x0, 5.0))
	queue_redraw()


func set_sway(px: float) -> void:
	var r := roundf(px)
	if r != sway:
		sway = r
		queue_redraw()


func _draw() -> void:
	for r in links:
		var b: Rect2 = r
		draw_rect(b, DARK)
		draw_rect(Rect2(b.position + Vector2(0, 1), Vector2(b.size.x, b.size.y - 2)), STEEL)
		draw_rect(Rect2(b.position + Vector2(0, 1), Vector2(b.size.x, 1)), STEEL_HI)
	for h in hoses:
		_hose(h.a, h.b, h.col)
	for c in caps:
		var p: Vector2 = c
		draw_rect(Rect2(p, Vector2(3, 3)), DARK)
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 1)), STEEL_HI)


## a sagging hose, one column at a time: colour pixel with a dark pixel above and below
func _hose(a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(b.x - a.x)
	if n <= 0:
		return
	var sag := 2.0 + sway
	for i in n + 1:
		var t := float(i) / float(n)
		var y := roundf(lerpf(a.y, b.y, t) + sag * 4.0 * t * (1.0 - t))
		var x := a.x + i
		draw_rect(Rect2(x, y - 1, 1, 3), DARK)
	for i in n + 1:
		var t := float(i) / float(n)
		var y := roundf(lerpf(a.y, b.y, t) + sag * 4.0 * t * (1.0 - t))
		draw_rect(Rect2(a.x + i, y, 1, 1), col)
