class_name BossBar
extends Control
## Big boss health bar that slams in when a boss / checkpoint warlord is on the field:
## name + level + mechanic tags, a chunky segmented bar with a delayed "damage trail", phase markers
## (armour holds above 60%, enrage below 30%), impact shake + white flash on big hits, red pulse when enraged.

const H := 30.0
var _name_lbl: Label
var _tag_lbl: Label
var _boss_id := -1
var _shown := 0.0
var _trail := 1.0
var _hp := 1.0
var _shake := 0.0
var _flash := 0.0
var _t := 0.0
var _enraged := false
var _armored := false
var _burrowed := false
var _warlord := false

const MECH_TH := {"enrage": "คลั่ง", "armor": "เกราะ", "summon": "เรียกลูกสมุน", "acid": "กรด", "solar": "จิกโซลาร์",
	"burrow": "มุดดิน", "revive": "ปลุกศพ", "explode": "ระเบิด"}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_lbl = UIKit.label("", UIKit.FS_SMALL, UIKit.C_WHITE)
	_name_lbl.position = Vector2(26, 1)
	add_child(_name_lbl)
	_tag_lbl = UIKit.label("", UIKit.FP, UIKit.C_GOLD, true)
	_tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_tag_lbl)
	visible = false


func _process(delta: float) -> void:
	_t += delta
	var e: Dictionary = Combat.current_boss() if Game.started and not Game.s.is_empty() else {}
	var want := not e.is_empty() and Game.closeup_slot < 0
	_shown = move_toward(_shown, 1.0 if want else 0.0, delta * 5.0)
	visible = _shown > 0.0
	if not visible:
		_boss_id = -1
		return
	if not e.is_empty():
		var hp := clampf(float(e.hp) / maxf(1.0, float(e.max)), 0.0, 1.0)
		if int(e.id) != _boss_id:
			_boss_id = int(e.id)
			_trail = hp
			_hp = hp
			_shake = 4.0
			_warlord = e.get("warlord", false)
			var mech: Array = e.get("mech", [])
			var tags := []
			for m in mech:
				tags.append(Loc.t(str(MECH_TH.get(m, m))))
			_name_lbl.text = "%s  Lv.%d" % [str(e.name), int(e.lvl)]
			_tag_lbl.text = (" · ".join(tags)).to_upper() if not tags.is_empty() else ""
			_tag_lbl.add_theme_font_override("font", UIKit.font_main)
			_tag_lbl.add_theme_font_size_override("font_size", UIKit.FS_SMALL)
		if _hp - hp > 0.015:
			_shake = minf(4.0, _shake + (_hp - hp) * 60.0)
			_flash = 0.08
		_hp = hp
		_enraged = e.get("enraged", false)
		_burrowed = e.get("burrowed", false)
		_armored = (e.get("mech", []) as Array).has("armor") and hp > 0.6
	_trail = move_toward(_trail, _hp, delta * (0.35 if _trail - _hp < 0.2 else 0.8))
	_shake = move_toward(_shake, 0.0, delta * 18.0)
	_flash -= delta
	_tag_lbl.position = Vector2(size.x - _tag_lbl.size.x - 6, 1)
	queue_redraw()


func _draw() -> void:
	var off := Vector2(round(randf_range(-_shake, _shake)), round(randf_range(-_shake, _shake) * 0.5))
	var slide: float = roundf((1.0 - _shown) * -40.0)
	var r := Rect2(off + Vector2(0, slide), Vector2(size.x, H))
	var border := UIKit.C_LINE
	if _enraged and int(_t * 6.0) % 2 == 0:
		border = UIKit.C_RED
	draw_rect(r, Color("0a0a0c"))
	draw_rect(r, border, false, 1.0)
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), Color(1, 1, 1, 0.06))
	# skull / crown badge
	draw_texture(Atlas.icon("crown" if _warlord else "skull"), r.position + Vector2(5, 2))
	# bar
	var bx := r.position.x + 6.0
	var by := r.position.y + 18.0
	var bw := r.size.x - 12.0
	var bh := 8.0
	draw_rect(Rect2(bx - 1, by - 1, bw + 2, bh + 2), Color("000000"))
	draw_rect(Rect2(bx, by, bw, bh), Color("2e0e0c"))
	draw_rect(Rect2(bx, by, floorf(bw * _trail), bh), Color("e8dcc0"))           # damage trail
	var fill := Color("c03a28") if not _enraged else Color("ff5a3a")
	if _burrowed:
		fill = Color("5a4a3a")
	draw_rect(Rect2(bx, by, floorf(bw * _hp), bh), fill)
	draw_rect(Rect2(bx, by, floorf(bw * _hp), 2), fill.lightened(0.3))
	draw_rect(Rect2(bx, by + bh - 2, floorf(bw * _hp), 2), fill.darkened(0.35))
	if _armored:
		# steel plating over the part of the bar that is still armoured
		var ax := bx + floorf(bw * 0.6)
		var aw := floorf(bw * _hp) - floorf(bw * 0.6)
		for x in range(int(ax), int(ax + aw), 4):
			draw_rect(Rect2(x, by, 2, bh), Color(0.75, 0.75, 0.72, 0.45))
	# segment ticks every 10% + phase markers
	for k in range(1, 10):
		draw_rect(Rect2(bx + floorf(bw * k / 10.0), by, 1, bh), Color(0, 0, 0, 0.5))
	for p in [0.6, 0.3]:
		draw_rect(Rect2(bx + floorf(bw * p) - 1, by - 3, 2, bh + 6), UIKit.C_GOLD)
	if _flash > 0.0:
		draw_rect(Rect2(bx, by, floorf(bw * _hp), bh), Color(1, 1, 1, 0.7))
	var pct := "%d%%" % int(ceil(_hp * 100.0))
	draw_string(UIKit.font_pixel, Vector2(bx + bw - 26, by + 7), pct, HORIZONTAL_ALIGNMENT_RIGHT, 24, UIKit.FP, UIKit.C_WHITE)
	if _burrowed:
		draw_string(UIKit.font_pixel, Vector2(bx + 4, by + 7), "UNDERGROUND", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FP, UIKit.C_GOLD)
	elif _enraged:
		draw_string(UIKit.font_pixel, Vector2(bx + 4, by + 7), "ENRAGED", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FP, UIKit.C_WHITE)
