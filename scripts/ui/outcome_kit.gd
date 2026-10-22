class_name OutcomeKit
## Shared pieces of the decision-outcome screens (road events, expedition radio calls):
## a stamp slammed over the illustration, resource rows that count up, affected-crew chips.


## stamp over the art in `frame` (built by ModalPanel.media_layout); bad results tint the art red
static func stamp(frame: PanelContainer, en: String, th: String, col: Color, bad: bool) -> PanelContainer:
	var img: Control = frame.get_child(0)
	img.modulate = Color(1.0, 0.45, 0.4) if bad else Color.WHITE
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(cc)
	var st := PanelContainer.new()
	var sb := UIKit.card_style(Color(0, 0, 0, 0.72), col, 4)
	sb.set_border_width_all(2)
	st.add_theme_stylebox_override("panel", sb)
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sv := UIKit.vbox(0)
	st.add_child(sv)
	var t := UIKit.label(en, 18, col, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(t)
	var tl := UIKit.label(th, UIKit.FS_SMALL, UIKit.C_WHITE)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(tl)
	cc.add_child(st)
	st.modulate = Color(3, 3, 3, 0)
	var tw := st.create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(st, "modulate", Color.WHITE, 0.16)
	if bad:
		tw.tween_property(img, "modulate", Color(1.4, 0.5, 0.45), 0.06)
		tw.tween_property(img, "modulate", Color(1.0, 0.45, 0.4), 0.2)
	return st


## CHANGES grid + CREW chips under `v`; returns the delay after the last staggered item
static func lists(v: VBoxContainer, rows: Array, crew: Array, col: Color, rows_th: String, delay: float) -> float:
	if not rows.is_empty():
		v.add_child(UIKit.header("CHANGES", rows_th, col))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 3)
		v.add_child(grid)
		for r in rows:
			grid.add_child(change_row(r, delay))
			delay += 0.09
	if not crew.is_empty():
		v.add_child(UIKit.header("CREW", "ลูกเรือที่ได้รับผล", col))
		var fl := UIKit.flow(4)
		v.add_child(fl)
		for c in crew.slice(0, 8):
			fl.add_child(crew_chip(c.d, c.tags, delay))
			delay += 0.07
		if crew.size() > 8:
			fl.add_child(UIKit.label("+%d คน" % (crew.size() - 8), UIKit.FS_SMALL, UIKit.C_DIM))
	return delay


## icon + name + count-up delta (green gain, red loss)
static func change_row(r: Dictionary, delay: float) -> Control:
	var p := UIKit.panel(UIKit.C_BG2, UIKit.C_LINE_DARK)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UIKit.hbox(4)
	p.add_child(h)
	var ic := UIKit.icon_rect(str(r.icon), 16)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var nm := UIKit.wrap_label(str(r.name), UIKit.FS_SMALL, UIKit.C_TEXT)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(nm)
	var n := int(r.n)
	var sfx: String = r.get("suffix", "")
	var c := UIKit.C_GOLD if r.get("neutral", false) else (UIKit.C_GREEN if n > 0 else UIKit.C_RED)
	var num := UIKit.label("+0" + sfx, UIKit.FS, c)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(num)
	var neutral: bool = r.get("neutral", false)
	var tw := fade_in(p, delay)
	tw.tween_method(func(x: float):
		num.text = ("%d" % int(round(x)) if neutral else "%+d" % int(round(x))) + sfx, 0.0, float(n), 0.45)
	return p


static func crew_chip(d: Dictionary, tags: Array, delay: float) -> Control:
	var p := UIKit.panel(UIKit.C_BG2, UIKit.C_LINE_DARK)
	var h := UIKit.hbox(3)
	p.add_child(h)
	var pt := UIKit.portrait(d.variant)
	if d.get("dead", false):
		pt.modulate = Color(0.55, 0.4, 0.4)
	h.add_child(pt)
	var info := UIKit.vbox(0)
	h.add_child(info)
	info.add_child(UIKit.label(str(d.name), UIKit.FS_SMALL, UIKit.C_WHITE))
	var tl := UIKit.hbox(3)
	info.add_child(tl)
	for t in tags:
		tl.add_child(UIKit.label(t[0], UIKit.FP, t[1], true))
	fade_in(p, delay)
	return p


static func fade_in(c: Control, delay: float) -> Tween:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 1.0, 0.12)
	return tw
