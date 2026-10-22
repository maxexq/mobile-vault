class_name SkillPanel
extends ModalPanel
## One survivor's skill tree: 3 branches (combat / survival / craft), 5 nodes each, prerequisites drawn
## as connectors. Points come from levels; respec costs scrap.

var did := -1
var _grid: GridContainer
var _info: Label
var _pts: Label


func _build() -> void:
	var top := UIKit.hbox(4)
	body.add_child(top)
	_pts = UIKit.label("", UIKit.FP, UIKit.C_GOLD, true)
	_pts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_pts)
	var rs := UIKit.button("รีเซ็ต", "red", "close")
	rs.pressed.connect(func():
		var d := Game.dweller_by_id(did)
		if not d.is_empty() and Skills.respec(d):
			refresh())
	top.add_child(rs)
	var sc := UIKit.scroll()
	body.add_child(sc)
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 0)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_grid)
	_info = UIKit.wrap_label("แตะช่องสกิลเพื่ออัปเกรด (ต้องมีสกิลก่อนหน้าอย่างน้อย 1 ระดับ)", UIKit.FS_SMALL)
	v.add_child(_info)


func open_for(id: int) -> void:
	did = id
	open()


func refresh() -> void:
	var d := Game.dweller_by_id(did)
	if d.is_empty():
		close()
		return
	set_title("SKILL TREE / %s Lv.%d" % [d.name, d.lvl])
	_pts.text = "POINTS %d/%d · RESPEC %d" % [Skills.points_free(d), Skills.points_total(d), Skills.respec_cost(d)]
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	for b in Skills.TREE:
		var t: Dictionary = Skills.TREE[b]
		var hl := UIKit.label(t.th, UIKit.FS_SMALL, Color(t.col))
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(hl)
	# rows: tier 1 (n1,n2) / tier 2 (n3,n4) / tier 3 (n5); laid out as 5 rows per column for clarity
	for row in 5:
		for b in Skills.TREE:
			var node: String = Skills.TREE[b].nodes[row]
			_grid.add_child(_node_cell(d, node, Color(Skills.TREE[b].col), row))


func _node_cell(d: Dictionary, node: String, col: Color, row: int) -> Control:
	var nd: Dictionary = Skills.NODES[node]
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# connector from the row above (shows the prerequisite chain)
	var link := ColorRect.new()
	link.custom_minimum_size = Vector2(2, 6)
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	link.color = col if row > 0 and not (nd.req as Array).is_empty() else Color(0, 0, 0, 0)
	link.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(link)
	var r := Skills.rank(d, node)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 44)
	b.focus_mode = Control.FOCUS_NONE
	UIKit.style_button(b, "yellow" if r >= int(nd.max) else ("green" if Skills.can_learn(d, node) else "gray"))
	var bv := UIKit.vbox(0)
	bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hh := UIKit.hbox(2)
	hh.alignment = BoxContainer.ALIGNMENT_CENTER
	hh.add_child(UIKit.icon_rect(nd.icon, 16))
	hh.add_child(UIKit.label("%d/%d" % [r, int(nd.max)], UIKit.FP, col if r > 0 else UIKit.C_DIM, true))
	bv.add_child(hh)
	var nl := UIKit.label(nd.th, UIKit.FS_SMALL, UIKit.C_TEXT if r > 0 else UIKit.C_DIM)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.clip_text = true
	bv.add_child(nl)
	b.add_child(bv)
	b.tooltip_text = "%s: %s" % [nd.th, nd.desc]
	b.pressed.connect(func():
		_info.text = "%s (%s) — %s" % [nd.th, nd.en, nd.desc]
		if Skills.learn(d, node):
			refresh())
	v.add_child(b)
	return v
