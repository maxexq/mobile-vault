class_name GearFx
extends Control
## MV-473 (MV-475..481): the animated rarity light of one equipment tile. A Control at the tile origin holding one
## TextureRect that shows the light mask fx_gear_<rarity>[_<w>]_<phase> at (-12,-12), coloured by gear_fx.gdshader
## with the approved emission / hot colours. Between the metal frame (the tile's stylebox) and the item icon, so the
## item, +N, level and lock stay on top; it never takes input.
##  * presentation: "aura" (default: rim + outside glow, motes, embers, arcs), "neon" (the same mask clipped to the
##    slot), "still" (gear_slot_vfx off or reduced effects: phase 0 clipped, no motion), "base" (GOD: no light)
##  * one shared clock (the first GearFx to tick in a frame advances it) at 8 fps, 16 phases = a 2 s loop; it only
##    advances while some light is visible and the game isn't paused; a hidden tile does no work
##  * textures come from the atlas cache, materials are shared per rarity: no allocation while it plays

const FPS := 8.0
const PHASES := 16
const PAD := 12
const WIDTHS := [28, 30, 32, 36, 40]
const NAMES := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
## approved emission and hot colours (tools/art/gear_slots/build_preview.py COLORS / HOT): rendering only; rarity labels
## and gameplay colours still come from Loot.RARITY
const EMIT := [Color8(182, 181, 169), Color8(65, 231, 77), Color8(38, 162, 255), Color8(183, 53, 248), Color8(255, 169, 33), Color8(249, 47, 65)]
const HOT := [Color8(231, 229, 212), Color8(189, 255, 169), Color8(179, 239, 255), Color8(243, 181, 255), Color8(255, 239, 159), Color8(255, 179, 174)]

## GOD comparison: "" = follow the switches, "base" / "neon" / "aura" / "still" = force one presentation
static var preview := ""
static var paused_preview := false     # GOD: hold the clock (frame_step moves it one phase)
static var _clock := 0.0
static var _clock_frame := -1
static var _mats := {}
static var _shader: Shader

var rank := 0
var width := 32
var phase := -1
var _tex: TextureRect


## the native width a tile of px pixels uses (the call sites are 28 / 30 / 32 / 36 / 40)
static func native_width(px: int) -> int:
	var best := 32
	for w in WIDTHS:
		if absi(w - px) < absi(best - px):
			best = w
	return best


static func mask_key(r: int, w: int, p: int) -> String:
	return "fx_gear_%s%s_%d" % [NAMES[clampi(r, 0, 5)], "" if w == 32 else "_%d" % w, p]


static func material_for(r: int) -> ShaderMaterial:
	r = clampi(r, 0, 5)
	if not _mats.has(r):
		if _shader == null:
			_shader = load("res://shaders/gear_fx.gdshader")
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("base_col", EMIT[r])
		m.set_shader_parameter("hot_col", HOT[r])
		_mats[r] = m
	return _mats[r]


## what to show now
static func presentation() -> String:
	if not Features.on("gear_slot_style"):
		return "base"
	if preview != "":
		return preview
	if not Features.on("gear_slot_vfx") or RoomAnim.reduced():
		return "still"
	return "aura"


## the shared phase: one clock for every tile, so they all move in step and nothing is spawned
static func current_phase() -> int:
	return int(floor(_clock * FPS)) % PHASES


## GOD: hold the clock and move it one phase
static func frame_step() -> void:
	paused_preview = true
	_clock = float(current_phase() + 1) / FPS + 0.001


func setup(r: int, px: int) -> void:
	rank = clampi(r, 0, 5)
	width = native_width(px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(width, width)
	_tex = TextureRect.new()
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex.stretch_mode = TextureRect.STRETCH_KEEP
	_tex.position = Vector2(-PAD, -PAD)
	_tex.size = Vector2(width + PAD * 2, width + PAD * 2)
	_tex.material = material_for(rank)
	add_child(_tex)
	_apply(true)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_apply(false, delta)


func _apply(force: bool, delta: float = 0.0) -> void:
	var mode := presentation()
	_tex.visible = mode != "base"
	clip_contents = mode != "aura"
	if mode == "base":
		return
	var p := 0
	if mode != "still":
		var running := is_inside_tree() and not get_tree().paused      # setup() runs before the tile is on screen
		if running and not paused_preview and Engine.get_process_frames() != _clock_frame:
			_clock_frame = Engine.get_process_frames()
			_clock = fmod(_clock + delta, float(PHASES) / FPS)
		p = current_phase()
	if p != phase or force:
		phase = p
		_tex.texture = Atlas.tex(mask_key(rank, width, p))
