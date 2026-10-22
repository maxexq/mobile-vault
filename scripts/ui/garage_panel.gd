class_name GaragePanel
extends ModalPanel
## Vehicle customisation: external mods (shown on the truck) and internal mods, plus blueprints found.

var tab := "ext"   # ext | int | bp
var _tabs: HBoxContainer
var _list: VBoxContainer


func _build() -> void:
	set_title("GARAGE / อู่ปรับแต่งรถ")
	_tabs = UIKit.hbox(3)
	body.add_child(_tabs)
	_list = make_list(4)
	Mods.mods_changed.connect(func(): if is_open: refresh())
	Game.resources_changed.connect(func(): if is_open: _update_buttons())


func refresh() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for t in [["ext", "ภายนอก"], ["int", "ภายใน"], ["bp", "พิมพ์เขียว"]]:
		var b := UIKit.button(t[1], "yellow" if tab == t[0] else "gray")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = t[0]
		b.pressed.connect(func():
			tab = key
			refresh())
		_tabs.add_child(b)
	set_title("GARAGE %s / อู่ปรับแต่ง %s" % [Meta.vehicle_name(), "ภายนอกรถ" if tab == "ext" else ("ภายในรถ" if tab == "int" else "")])
	if tab == "bp":
		_build_blueprints()
		return
	_list.add_child(UIKit.wrap_label("ของที่ติดตั้งภายนอกจะเห็นบนตัวรถจริง · บางชิ้นต้องมีพิมพ์เขียวจากการสำรวจสถานที่สำคัญ" if tab == "ext" else "อัปเกรดระบบภายในเพื่อรับมือภัยของแต่ละ Biome"))
	for id in Mods.MODS:
		var md: Dictionary = Mods.MODS[id]
		if md.side != tab:
			continue
		_list.add_child(_card(id, md))
	_update_buttons()


func _card(id: String, md: Dictionary) -> Control:
	var lv := Mods.level(id)
	var locked := not Mods.has_bp(md.bp)
	var p := UIKit.panel(UIKit.C_BG2, UIKit.C_GOLD if lv > 0 else UIKit.C_LINE_DARK)
	var h := UIKit.hbox(4)
	p.add_child(h)
	var ic := UIKit.icon_rect(md.icon, 32)
	if locked:
		ic.modulate = Color(0.4, 0.4, 0.4)
	h.add_child(ic)
	var v := UIKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var th := UIKit.hbox(4)
	th.add_child(UIKit.label(md.th, UIKit.FS_SMALL, UIKit.C_TEXT))
	th.add_child(UIKit.label("LV%d/%d" % [lv, int(md.max)], UIKit.FP, UIKit.C_GOLD, true))
	v.add_child(th)
	v.add_child(UIKit.wrap_label(md.desc, UIKit.FS_SMALL))
	if locked:
		v.add_child(UIKit.label("ต้องมี: " + Mods.BLUEPRINT_TH.get(md.bp, md.bp), UIKit.FS_SMALL, UIKit.C_ORANGE))
	h.add_child(v)
	if lv < int(md.max):
		var cost := Mods.next_cost(id)
		var b := UIKit.button(_cost_short(cost), "yellow", "up")
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.set_meta("mod", id)
		b.tooltip_text = Game.cost_text(cost)
		b.pressed.connect(func(): Mods.install(id))
		h.add_child(b)
	else:
		h.add_child(UIKit.label("MAX", UIKit.FP, UIKit.C_GOLD, true))
	return p


func _cost_short(cost: Dictionary) -> String:
	var parts := []
	if cost.has("scrap"):
		parts.append(str(int(cost.scrap)))
	if cost.has("components"):
		parts.append("%dชส" % int(cost.components))
	return " ".join(parts)


func _update_buttons() -> void:
	for b in _list.find_children("*", "Button", true, false):
		if b.has_meta("mod"):
			b.disabled = not Mods.can_install(str(b.get_meta("mod")))


func _build_blueprints() -> void:
	_list.add_child(UIKit.wrap_label("พิมพ์เขียวได้จากการส่งทีมสำรวจสถานที่สำคัญ และจะติดตัวไปถึงรถรุ่นถัดไป", UIKit.FS_SMALL))
	for bp in Mods.BLUEPRINT_TH:
		var have := Meta.has_blueprint(bp)
		var h := UIKit.hbox(4)
		h.add_child(UIKit.icon_rect("map", 16))
		h.add_child(UIKit.label(Mods.BLUEPRINT_TH[bp], UIKit.FS_SMALL, UIKit.C_TEXT if have else UIKit.C_LINE_DARK))
		h.add_child(UIKit.spacer())
		var where := ""
		for sid in Expedition.SITES:
			if (Expedition.SITES[sid].loot.get("bp", []) as Array).has(bp):
				where = Expedition.SITES[sid].th
		h.add_child(UIKit.label("มีแล้ว" if have else where, UIKit.FS_SMALL, UIKit.C_GOLD if have else UIKit.C_DIM))
		_list.add_child(h)
