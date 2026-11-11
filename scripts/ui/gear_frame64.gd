class_name GearFrame64
extends Control
## MV-767: the approved 64 px Vault hatch item frame (F5, MV-687 / MV-689) behind one equipment tile (switch gear_frame64).
## assets/gear64/frames.png (tools/gear64_import.py) holds the whole tier ladder pre-drawn, 16 frames at 8 fps per
## rarity: gauge lamps 1-6 on the left edge, ring unlit / breathing / running lights, locking dogs (Rare 4, Legendary 8),
## lit bolt caps + glass light (Epic+), trim light + embers (Legendary+), Mythic inner ring, cracks and broken arcs.
## Row 6 = the empty slot (lamps off). Each cell is 96 px: the 64 px plate + 16 px round it for the outer light.
## The plate is drawn into the tile's px x px box (mixed pixel size on purpose, like icons v2 and the crew at 2/3: on a
## 2x+ phone screen every frame pixel stays visible). The icon, +N badge and lock are the tile's own children
## (UIKit.gear_tile); this node only adds the set emblem: the bottom-right bolt becomes a diamond in the set colour.
## One shared clock for every tile; reduced effects / gear_slot_vfx off = frame 0, no motion.
## MV-773 (switch gear_frame_simple, on by default): the calm option B instead, assets/gear64/frames_simple.png
## (tools/art/gear_frame_simple.py): plain steel plate, dark well, rarity as four muted corner brackets, one still cell
## per row, no clock; the set emblem moves onto the bottom-right rivet so it never sits on a bracket.

const FRAMES_PNG := "res://assets/gear64/frames.png"
const SIMPLE_PNG := "res://assets/gear64/frames_simple.png"
const CELL := 96
const PAD := 16
const PLATE := 64
const N := 16
const FPS := 8.0
const EMPTY_ROW := 6

static var _sheet: Texture2D
static var _simple_sheet: Texture2D
static var _clock := 0.0
static var _clock_frame := -1

var rank := -1           # -1 = empty slot
var set_col := Color(0, 0, 0, 0)
var phase := -1
var simple := false


static func sheet() -> Texture2D:
	if _sheet == null:
		_sheet = load(FRAMES_PNG)
	return _sheet


static func simple_sheet() -> Texture2D:
	if _simple_sheet == null:
		_simple_sheet = load(SIMPLE_PNG)
	return _simple_sheet


static func use_simple() -> bool:
	return Features.on("gear_frame_simple")


static func animated() -> bool:
	return Features.on("gear_slot_vfx") and not RoomAnim.reduced()


static func current_phase() -> int:
	return int(floor(_clock * FPS)) % N


func setup(r: int, px: int, set_color: Color = Color(0, 0, 0, 0)) -> void:
	rank = clampi(r, -1, 5)
	set_col = set_color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = Vector2.ZERO
	size = Vector2(px, px)
	simple = use_simple()
	set_process(rank >= 0 and not simple)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var p := 0
	if animated() and not get_tree().paused:
		if Engine.get_process_frames() != _clock_frame:
			_clock_frame = Engine.get_process_frames()
			_clock = fmod(_clock + delta, float(N) / FPS)
		p = current_phase()
	if p != phase:
		phase = p
		queue_redraw()


func _draw() -> void:
	var k := size.x / float(PLATE)
	var row := EMPTY_ROW if rank < 0 else rank
	var col := 0 if rank < 0 or simple else maxi(phase, 0)
	draw_texture_rect_region(simple_sheet() if simple else sheet(), Rect2(Vector2(-PAD, -PAD) * k, Vector2(CELL, CELL) * k), Rect2(col * CELL, row * CELL, CELL, CELL))
	if set_col.a > 0.0:
		# set emblem: the bottom-right bolt as a diamond in the set colour (Vault hatch bolt 55.5, simple rivet 59)
		var c := (Vector2(59, 59) if simple else Vector2(55.5, 55.5)) * k
		var r := (3.0 if simple else 4.5) * k
		var dark := PackedVector2Array([c + Vector2(0, -r - k), c + Vector2(r + k, 0), c + Vector2(0, r + k), c + Vector2(-r - k, 0)])
		draw_colored_polygon(dark, Color(0.05, 0.04, 0.04))
		var dia := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		draw_colored_polygon(dia, set_col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.5, -r * 0.5), c, c + Vector2(-r * 0.5, -r * 0.5)]), set_col.lightened(0.45))
