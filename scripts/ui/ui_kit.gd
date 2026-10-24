class_name UIKit
extends RefCounted
## Grim wasteland UI toolkit (rusted riveted steel, soot-black panels, bone text, amber accents).
## Everything is laid out in design pixels (360 px wide portrait) and scaled by a whole number,
## so 1 px borders stay razor sharp. Frames are 9-slice textures from assets/ui (tools/art/ui.py).

# ---- wasteland palette (matches tools/art/common.py RAMPS)
const C_BG := Color("141416")
const C_BG2 := Color("1c1c20")
const C_LINE := Color("b0702e")        # rusted brass / frame accent
const C_LINE_DIM := Color("5c4e40")
const C_LINE_DARK := Color("2e2a28")
const C_TEXT := Color("d4ccb2")        # bone
const C_DIM := Color("8e8670")
const C_GOLD := Color("e0b048")        # lamp amber
const C_ORANGE := Color("d8782c")
const C_RED := Color("d4523c")
const C_BLUE := Color("86a8bc")
const C_GREEN := Color("98c050")
const C_WHITE := Color("f2ecd8")
# ---- type scale (design px). Thai body text uses Chakra Petch, numbers / tags use Silkscreen.
const FS_SMALL := 11
const FS := 12
const FS_BIG := 14
const FS_HUGE := 16
const FP := 8          # pixel font size (Silkscreen is drawn on an 8 px grid)
const MIN_TOUCH := 26

static var _theme: Theme
static var font_main: Font
static var font_bold: Font
static var font_pixel: Font
static var _tex := {}


static func ui_tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://assets/ui/%s.png" % name)
	return _tex[name]


static func nine(name: String, margin: int, content: Vector4 = Vector4(-1, -1, -1, -1)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = ui_tex(name)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	var cm := content if content.x >= 0 else Vector4(margin, margin, margin, margin)
	sb.content_margin_left = cm.x
	sb.content_margin_top = cm.y
	sb.content_margin_right = cm.z
	sb.content_margin_bottom = cm.w
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	var chakra: FontFile = load("res://assets/fonts/ChakraPetch-SemiBold.ttf")
	var chakra_b: FontFile = load("res://assets/fonts/ChakraPetch-Bold.ttf")
	var silk: FontFile = load("res://assets/fonts/Silkscreen-Regular.ttf")
	for f in [chakra, chakra_b, silk]:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NORMAL
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font_main = chakra
	font_bold = chakra_b
	var pix := FontVariation.new()
	pix.base_font = silk
	pix.fallbacks = [chakra_b]
	font_pixel = pix

	var t := Theme.new()
	t.default_font = chakra
	t.default_font_size = FS
	t.set_color("font_color", "Label", C_TEXT)
	t.set_constant("line_spacing", "Label", 0)

	t.set_stylebox("panel", "PanelContainer", card_style())
	t.set_stylebox("panel", "Panel", card_style())

	_set_button_styles(t, "Button", "green")
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", C_WHITE)
	t.set_color("font_pressed_color", "Button", C_BG)
	t.set_color("font_hover_pressed_color", "Button", C_BG)
	t.set_color("font_disabled_color", "Button", Color(C_DIM, 0.55))
	t.set_color("font_focus_color", "Button", C_TEXT)
	t.set_font("font", "Button", chakra_b)
	t.set_font_size("font_size", "Button", FS)
	t.set_constant("h_separation", "Button", 4)
	t.set_constant("icon_max_width", "Button", 16)

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color("0c0c0e")
	pb_bg.border_color = C_LINE_DARK
	pb_bg.set_border_width_all(1)
	pb_bg.anti_aliasing = false
	var pb_fg := StyleBoxFlat.new()
	pb_fg.bg_color = C_GREEN
	pb_fg.anti_aliasing = false
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fg)
	t.set_font("font", "ProgressBar", pix)
	t.set_font_size("font_size", "ProgressBar", FP)
	t.set_color("font_color", "ProgressBar", C_WHITE)
	t.set_color("font_outline_color", "ProgressBar", Color.BLACK)
	t.set_constant("outline_size", "ProgressBar", 2)

	var sb_grab := StyleBoxFlat.new()
	sb_grab.bg_color = C_LINE_DIM
	sb_grab.set_content_margin_all(1)
	sb_grab.anti_aliasing = false
	var sb_track := StyleBoxFlat.new()
	sb_track.bg_color = Color("0c0c0e")
	sb_track.set_content_margin_all(1)
	sb_track.anti_aliasing = false
	for sb_type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb_type, sb_track)
		t.set_stylebox("grabber", sb_type, sb_grab)
		t.set_stylebox("grabber_highlight", sb_type, sb_grab)
		t.set_stylebox("grabber_pressed", sb_type, sb_grab)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TooltipPanel", card_style())
	t.set_font_size("font_size", "TooltipLabel", FS_SMALL)
	t.set_color("font_color", "TooltipLabel", C_TEXT)
	_theme = t
	return t


const BTN_TEX := {
	"green": ["btn", "btn_hover"], "yellow": ["btn_amber", "btn_amber_hover"], "orange": ["btn_amber", "btn_amber_hover"],
	"red": ["btn_red", "btn_red_hover"], "gray": ["btn_gray", "btn_gray_hover"], "blue": ["btn_cyan", "btn_cyan_hover"],
}


static func _set_button_styles(t: Theme, type: String, key: String) -> void:
	var pair: Array = BTN_TEX.get(key, BTN_TEX.green)
	t.set_stylebox("normal", type, nine(pair[0], 3, Vector4(6, 3, 6, 3)))
	t.set_stylebox("hover", type, nine(pair[1], 3, Vector4(6, 3, 6, 3)))
	t.set_stylebox("pressed", type, nine("btn_pressed", 3, Vector4(6, 4, 6, 2)))
	t.set_stylebox("hover_pressed", type, nine("btn_pressed", 3, Vector4(6, 4, 6, 2)))
	t.set_stylebox("disabled", type, nine("btn_disabled", 3, Vector4(6, 3, 6, 3)))
	t.set_stylebox("focus", type, StyleBoxEmpty.new())


static func style_button(b: Button, color_key: String) -> void:
	var pair: Array = BTN_TEX.get(color_key, BTN_TEX.green)
	b.add_theme_stylebox_override("normal", nine(pair[0], 3, Vector4(6, 3, 6, 3)))
	b.add_theme_stylebox_override("hover", nine(pair[1], 3, Vector4(6, 3, 6, 3)))
	var fc: Color = {"yellow": C_GOLD, "orange": C_GOLD, "red": Color("ffb4a4"), "blue": C_BLUE, "gray": C_DIM}.get(color_key, C_TEXT)
	b.add_theme_color_override("font_color", fc)


## the main window frame (riveted rusty steel)
static func window_style() -> StyleBoxTexture:
	return nine("panel", 5, Vector4(8, 7, 8, 8))


static func card_style(bg: Color = C_BG2, line: Color = C_LINE_DARK, pad: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = line
	sb.set_border_width_all(1)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = false
	return sb


static func panel_style(bg: Color = C_BG, line: Color = C_LINE, width: int = 1) -> StyleBoxFlat:
	var sb := card_style(bg, line, 4)
	sb.set_border_width_all(width)
	return sb


# ------------------------------------------------------------------ factories
## legacy sizes (14/15/18...) are folded onto the terminal type scale
static func _ts(size: int) -> int:
	if size <= FS_SMALL:
		return FS_SMALL
	if size <= 13:
		return FS
	if size <= 16:
		return FS_BIG if size >= 16 else FS
	return FS_HUGE


static func label(text: String, size: int = FS, color: Color = C_TEXT, pixel: bool = false) -> Label:
	theme()
	var l := Label.new()
	l.text = text
	if pixel:
		l.add_theme_font_override("font", font_pixel)
		l.add_theme_font_size_override("font_size", FP if size < 18 else FP * 2)
	else:
		l.add_theme_font_size_override("font_size", _ts(size))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## game logo: true-pixel APO[CAR]LYPSE plate with the MOBILE VAULT subtitle (assets/ui/logo.png, 192x60,
## pixelized from the picked AI art), drawn 1:1 so it stays on the pixel grid; caption = optional pixel line under it
const LOGO := preload("res://assets/ui/logo.png")


static func logo(caption: String = "") -> VBoxContainer:
	var v := vbox(2)
	var r := TextureRect.new()
	r.texture = LOGO
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.custom_minimum_size = LOGO.get_size()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.tooltip_text = BuildInfo.GAME_NAME
	v.add_child(r)
	if caption != "":
		var l := label(caption, FP, C_GOLD, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	return v


## "ALPHA TEST" / "BETA TEST" pixel tag under the logo (MV-111); hidden on a stable release or when the
## channel_badge switch is off. Call refresh_channel_tag() on it after a switch or GOD preview change.
static func channel_tag() -> Label:
	var l := label("", FP, C_RED, true)
	l.name = "ChannelTag"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	refresh_channel_tag(l)
	return l


static func refresh_channel_tag(l: Label) -> void:
	var badge := BuildInfo.channel_badge()
	l.visible = badge != "" and Features.on("channel_badge")
	l.text = badge + " TEST"
	l.tooltip_text = BuildInfo.channel_note()
	l.add_theme_color_override("font_color", {"red": C_RED, "yellow": C_GOLD, "blue": C_BLUE}.get(BuildInfo.channel_color(), C_GREEN))


## "STAGING SERVER" / "UAT SERVER" / "DEV SERVER" under the logo outside production (MV-112, switch env_badge)
static func env_tag() -> Label:
	var l := label("", FP, C_GOLD, true)
	l.name = "EnvTag"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	refresh_env_tag(l)
	return l


static func refresh_env_tag(l: Label) -> void:
	var badge := BuildInfo.env_badge()
	l.visible = badge != "" and Features.on("env_badge")
	l.text = badge + " SERVER"
	l.tooltip_text = BuildInfo.env_note()
	l.add_theme_color_override("font_color", {"red": C_RED, "yellow": C_GOLD, "blue": C_BLUE}.get(BuildInfo.env_color(), C_GREEN))


## bold Thai heading line with a pixel EN tag, e.g. "> CRAFTING  การผลิต"
static func header(en: String, th: String = "", color: Color = C_GOLD) -> HBoxContainer:
	var h := hbox(4)
	h.add_child(label(">" + en, FP, color, true))
	if th != "":
		h.add_child(label(th, FS_SMALL, Color(color, 0.8)))
	return h


static func wrap_label(text: String, size: int = FS_SMALL, color: Color = C_DIM) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 40
	return l


static func icon_rect(icon_name: String, px: int = 16) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Atlas.icon(icon_name) if Atlas.has("ic_" + icon_name) else Atlas.tex(icon_name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	# only whole-number scales (16 / 32) keep the art on the pixel grid
	r.custom_minimum_size = Vector2(px, px)
	if px >= 32:
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(32, 32) if px < 48 else Vector2(48, 48)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func tex_rect(tex: Texture2D, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.custom_minimum_size = size
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## 20x20 bust (x1) or 40x40 (x2) inside a dark frame
static func portrait(variant: String, big: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_style(Color("0c0c0e"), C_LINE_DIM, 1))
	var tr := TextureRect.new()
	tr.texture = Atlas.tex("pt_" + variant) if Atlas.has("pt_" + variant) else Atlas.dweller_portrait(variant)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if big else TextureRect.STRETCH_KEEP_CENTERED
	tr.custom_minimum_size = Vector2(40, 40) if big else Vector2(20, 20)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tr)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func button(text: String, color_key: String = "green", icon_name: String = "", min_w: int = 0) -> Button:
	theme()
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(maxi(min_w, MIN_TOUCH), MIN_TOUCH)
	b.focus_mode = Control.FOCUS_NONE
	if icon_name != "":
		b.icon = Atlas.icon(icon_name)
		b.expand_icon = false
	style_button(b, color_key)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.pressed.connect(func(): pop(b))
	return b


## small square-ish tool button for the bottom bar: icon over a pixel caption
static func tool_button(caption: String, icon_name: String, color_key: String = "green") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(44, 40)
	b.focus_mode = Control.FOCUS_NONE
	style_button(b, color_key)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := icon_rect(icon_name, 16)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := label(caption.to_upper(), FP, C_TEXT, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	b.add_child(v)
	b.pressed.connect(func(): pop(b))
	return b


static func progress(color: Color = C_GREEN, h: int = 4, show_pct: bool = false) -> ProgressBar:
	theme()
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(20, maxi(3, mini(h, 10)))
	p.show_percentage = show_pct
	p.max_value = 1.0
	p.step = 0.0
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.anti_aliasing = false
	p.add_theme_stylebox_override("fill", fg)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func panel(bg: Color = C_BG2, line: Color = C_LINE_DARK) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_style(bg, line))
	return p


static func hbox(sep: int = 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func flow(sep: int = 4) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func divider(color: Color = C_LINE_DARK) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func scroll() -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sc


## Finger drag-scroll. ScrollContainer scrolls by touch from the emulated mouse events, and Viewport
## stops those at the first MOUSE_FILTER_STOP control under the finger (Button, PanelContainer, ...), so
## a list of cards only scrolled from its scrollbar. Every STOP control inside a ScrollContainer becomes
## PASS: a button still gets its tap and drops it on NOTIFICATION_SCROLL_BEGIN once the finger moves past
## gui/common/default_scroll_deadzone. Controls that drag on their own keep STOP.
## https://docs.godotengine.org/en/stable/classes/class_control.html#class-control-property-mouse-filter
## Wired to SceneTree.node_added by the HUD, so panels rebuilt later are covered too.
static func touch_pass(n: Node) -> void:
	var c := n as Control
	if c == null or c.mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	if c is ScrollBar or c is Slider or c is ScrollContainer or c is LineEdit or c is TextEdit or c is ItemList or c is Tree:
		return
	if c is RichTextLabel and (c as RichTextLabel).scroll_active:
		return
	var p := c.get_parent()
	while p is Control:
		if p is ScrollContainer:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
			return
		if (p as Control).top_level:
			return
		p = p.get_parent()


## touch_pass() for a whole subtree (nodes that were already in the tree when the hook was wired)
static func touch_pass_all(n: Node) -> void:
	touch_pass(n)
	for ch in n.get_children(true):
		touch_pass_all(ch)


static func stat_bar(stat: String, value: int) -> HBoxContainer:
	var h := hbox(3)
	var l := label(stat.to_upper() + " " + str(value), FP, C_DIM, true)
	l.custom_minimum_size.x = 40
	h.add_child(l)
	var p := progress({"str": C_ORANGE, "int": C_BLUE, "agi": C_GOLD}.get(stat, C_GREEN), 4)
	p.value = value / 10.0
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(p)
	return h


static func skulls(n: int) -> HBoxContainer:
	var h := hbox(0)
	for i in clampi(n, 1, 6):
		h.add_child(icon_rect("skull", 16))
	return h


## press feedback without scaling pixels: a 1-frame bright flash
static func pop(c: Control) -> void:
	c.modulate = Color(1.6, 1.6, 1.6)
	var tw := c.create_tween()
	tw.tween_property(c, "modulate", Color.WHITE, 0.12)


## square gear slot / stash tile: rarity-tinted frame, icon, +N, item level
static func gear_tile(item: Dictionary, slot: String, px: int = 32) -> Button:
	var b := Button.new()
	px = maxi(px, 28)
	b.custom_minimum_size = Vector2(px, px)
	b.focus_mode = Control.FOCUS_NONE
	var empty := item.is_empty()
	var col: Color = Loot.rar_color(item) if not empty else C_LINE_DARK
	for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var sb := nine("tile", 2, Vector4(2, 2, 2, 2))
		sb.modulate_color = col if st != "hover" else col.lightened(0.3)
		if st == "pressed":
			sb.modulate_color = Color.WHITE
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := icon_rect(Loot.item_icon(item) if not empty else Loot.SLOT_ICON.get(slot, "gear"), 16)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if empty:
		ic.modulate = Color(C_LINE_DIM, 0.6)
	b.add_child(ic)
	if not empty:
		if int(item.plus) > 0:
			var p := label("+%d" % int(item.plus), FP, C_GOLD, true)
			p.position = Vector2(2, 0)
			b.add_child(p)
		var lv := label(str(int(item.ilvl)), FP, C_WHITE, true)
		lv.add_theme_constant_override("outline_size", 2)
		lv.add_theme_color_override("font_outline_color", Color.BLACK)
		b.add_child(lv)
		lv.position = Vector2(px - lv.get_minimum_size().x - 1, px - 10)
		if item.get("lock", false):
			var lk := TextureRect.new()
			lk.texture = Atlas.icon("lock")
			lk.position = Vector2(px - 12, -2)
			lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(lk)
	b.pressed.connect(func(): pop(b))
	return b


## coloured item title "ไรเฟิลล่าสัตว์ +2"
static func item_title(item: Dictionary, size: int = FS) -> Label:
	var t := "%s%s" % [Loot.item_name(item), (" +%d" % int(item.plus)) if int(item.plus) > 0 else ""]
	return label(t, size, Loot.rar_color(item))


static func fmt(v: float) -> String:
	if v >= 100000:
		return "%dk" % int(v / 1000.0)
	if v >= 10000:
		return "%.1fk" % (v / 1000.0)
	return str(int(v))
