class_name TraitCard
extends Control
## MV-483 / MV-498: the approved compact trait card for the crew dossier. A quiet charcoal card (ui_trait_card_frame,
## 9-slice with fixed 3 px corners, so it sizes to its content in whole pixels): a 20x20 icon recess with the trait's
## 16x16 icon, the name (a small warning mark first for a trade-off), an optional tier label, then the effect lines.
## A trade-off shows its cost in red and keeps any upside in green (COST / UPSIDE: presentation only, Crew.TRAITS is
## unchanged). The light (TraitFx) is a sibling layer over the frame that never covers the content or takes input.
## The tier comes only from the explicit Crew.TRAIT_TIERS map (MV-497); an unclassified trait gets the quiet fallback
## (no tier label: a green accent for a benefit, the still crimson edge for a trade-off). Width comes from the caller,
## height from the text (long Thai grows the card instead of being cut).

## trade-offs split into the cost and the upside they keep (Thai keys, English in i18n/en.json)
const COST := {
	"glutton": "กินอาหาร +60%", "grumpy": "เพื่อนร่วมห้องความสุข -8", "afraid_dark": "ไฟดับ/กลางคืน ความสุขลดหนัก (-16)",
	"coward": "สำรวจเสี่ยงขึ้น 30%", "clumsy": "ก่อสร้างช้าลง 30%",
}
const UPSIDE := {"glutton": "อารมณ์ดีง่าย ความสุข +5", "grumpy": "ผลิตเอง +15%", "coward": "ทำงานในรถ +10%"}
const MIN_W := 160
const GAP := 12          # 4 px of light paint per side + clearance: cards never touch each other's light

var trait_id := ""
var tier := -1
var body: PanelContainer
var fx: TraitFx
static var _style: StyleBoxTexture


static func style() -> StyleBoxTexture:
	if _style == null:
		_style = StyleBoxTexture.new()
		_style.texture = Atlas.tex("ui_trait_card_frame")
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_style.set_texture_margin(side, 3)
		_style.content_margin_left = 6
		_style.content_margin_top = 5
		_style.content_margin_right = 5
		_style.content_margin_bottom = 5
	return _style


## t = the trait id, forced_tier >= 0 (GOD preview) overrides the classification
func setup(t: String, forced_tier: int = -2) -> void:
	trait_id = t
	var d: Dictionary = Crew.TRAITS.get(t, {})
	var bad := bool(d.get("bad", false))
	tier = forced_tier if forced_tier >= -1 else Crew.trait_tier(t)
	mouse_filter = Control.MOUSE_FILTER_PASS
	body = PanelContainer.new()
	body.add_theme_stylebox_override("panel", style())
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(body)
	var h := UIKit.hbox(6)
	body.add_child(h)
	var rec := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0c0a0a")
	sb.set_content_margin_all(2)
	rec.add_theme_stylebox_override("panel", sb)
	rec.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rec.add_child(UIKit.icon_rect(str(d.get("icon", "gear")), 16))
	h.add_child(rec)
	var v := UIKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := UIKit.hbox(3)
	if bad:
		var warn := UIKit.label("!", UIKit.FS_SMALL, UIKit.C_RED, true)
		warn.name = "Warning"
		top.add_child(warn)
	var name_lbl := UIKit.label(Loc.t(str(d.get("th", t))), UIKit.FS_SMALL, UIKit.C_TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(name_lbl)
	if tier >= 0:
		var tl := UIKit.label(str(Loot.RARITY[tier].en), UIKit.FP, TraitFx.EMIT[tier], true)
		tl.name = "Tier"
		top.add_child(tl)
	v.add_child(top)
	if bad:
		v.add_child(UIKit.wrap_label(Loc.t(COST.get(t, str(d.get("desc", "")))), UIKit.FS_SMALL, UIKit.C_RED))
		if UPSIDE.has(t):
			v.add_child(UIKit.wrap_label(Loc.t(UPSIDE[t]), UIKit.FS_SMALL, UIKit.C_GREEN))
	else:
		v.add_child(UIKit.wrap_label(Loc.t(str(d.get("desc", ""))), UIKit.FS_SMALL, UIKit.C_GREEN))
	fx = TraitFx.new()
	fx.name = "TraitFx"
	fx.setup(bad, tier)
	add_child(fx)
	body.minimum_size_changed.connect(update_minimum_size)
	resized.connect(_fit)
	_fit()


func _get_minimum_size() -> Vector2:
	if body == null:
		return Vector2(MIN_W, 58)
	return Vector2(maxf(MIN_W, body.get_combined_minimum_size().x), body.get_combined_minimum_size().y)


func _fit() -> void:
	if body == null:
		return
	body.position = Vector2.ZERO
	body.size = size
	fx.position = Vector2(-TraitFx.PAD, -TraitFx.PAD)
	fx.size = (size + Vector2(TraitFx.PAD * 2, TraitFx.PAD * 2)).floor()


## the trait cards of one crew member: two columns when two whole cards plus their light fit in `width`, else one;
## a 6 px margin so the light at the edges isn't cut by the scrolling list
static func grid(traits: Array, width: float) -> Control:
	var g := GridContainer.new()
	g.name = "TraitCards"
	g.columns = 2 if width - 12.0 >= MIN_W * 2 + GAP else 1
	g.add_theme_constant_override("h_separation", GAP)
	g.add_theme_constant_override("v_separation", GAP)
	for t in traits:
		var c := TraitCard.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(c)
		c.setup(str(t))
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 6)
	m.add_child(g)
	return m
