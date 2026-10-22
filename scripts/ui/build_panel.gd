class_name BuildPanel
extends ModalPanel
## Construction & upgrade: room catalogue -> placement mode, Mobile Frame upgrade (unlocks slots,
## advanced rooms and the next biome checkpoint), hull repair.

signal placement_requested(room_type: String)

var _grid: GridContainer
var _scrap_lbl: Label
var _frame_btn: Button
var _frame_info: Label
var _repair_btn: Button


func _build() -> void:
	set_title("CONSTRUCTION / สร้างและขยายฐาน")
	var top := UIKit.hbox(4)
	top.add_child(UIKit.icon_rect("scrap", 16))
	_scrap_lbl = UIKit.label("", UIKit.FP, UIKit.C_TEXT, true)
	_scrap_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_scrap_lbl)
	top.add_child(UIKit.spacer())
	_repair_btn = UIKit.button("", "blue", "wrench")
	_repair_btn.pressed.connect(func():
		Game.repair_hull()
		refresh())
	top.add_child(_repair_btn)
	body.add_child(top)
	var v := make_list(4)
	_grid = GridContainer.new()
	_grid.columns = 1
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 3)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_grid)
	# mobile frame upgrade card
	var fp := UIKit.panel(Color("1a140c"), UIKit.C_GOLD)
	var fh := UIKit.hbox(4)
	fp.add_child(fh)
	var fv := UIKit.vbox(1)
	fv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fv.add_child(UIKit.label("UPGRADE MOBILE VAULT", UIKit.FP, UIKit.C_GOLD, true))
	fv.add_child(UIKit.label("อัปเกรดโครงรถ / เปิดชั้นใหม่", UIKit.FS_SMALL, UIKit.C_GOLD))
	_frame_info = UIKit.wrap_label("", UIKit.FS_SMALL)
	fv.add_child(_frame_info)
	fh.add_child(fv)
	_frame_btn = UIKit.button("", "yellow", "up", 70)
	_frame_btn.pressed.connect(func():
		Game.upgrade_vault()
		refresh())
	fh.add_child(_frame_btn)
	v.add_child(fp)
	v.move_child(fp, 0)
	v.add_child(UIKit.wrap_label("แตะสร้าง แล้วเลือกห้องว่างในรถ · แตะห้องเดิมเพื่ออัปเกรด"))
	Game.resources_changed.connect(func(): if is_open: _update_affordable())
	get_viewport().size_changed.connect(func(): _grid.columns = 2 if get_viewport_rect().size.x >= 520 else 1)


func refresh() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_grid.columns = 2 if get_viewport_rect().size.x >= 520 else 1
	for t in Data.BUILDABLE:
		_grid.add_child(_card(t))
	var lv: int = Game.s.vault_level
	if lv < Data.MAX_VAULT_LEVEL:
		var next_b := ""
		for b in Data.BIOMES:
			if int(b.req) == lv + 1:
				next_b = " · ผ่านด่านเข้าสู่ %s" % b.th
		var new_rooms := []
		for t in Data.BUILDABLE:
			if int(Data.room_def(t).unlock) == lv + 1:
				new_rooms.append(Data.room_def(t).th)
		_frame_info.text = "Lv.%d → Lv.%d: ห้อง +1, คลังใหญ่ขึ้น, ซ่อมตัวถังเต็ม%s%s" % [lv, lv + 1, next_b, (" · ห้องใหม่: " + ", ".join(new_rooms)) if not new_rooms.is_empty() else ""]
		_frame_btn.text = "%d" % Game.vault_upgrade_cost()
	else:
		_frame_info.text = "โครงรถบ้านเลเวลสูงสุดแล้ว!"
		_frame_btn.text = "MAX"
	_update_affordable()


func _card(t: String) -> Control:
	var def := Data.room_def(t)
	var ul := Game.room_unlock_level(t)
	var locked := ul > int(Game.s.vault_level)
	var p := UIKit.panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UIKit.hbox(4)
	p.add_child(h)
	var img := UIKit.tex_rect(Atlas.sub("room_" + t, Rect2(8, 6, 64, 40)), Vector2(64, 40))
	if locked:
		img.modulate = Color(0.35, 0.4, 0.35)
	h.add_child(img)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label("%s" % def.th, UIKit.FS_SMALL, UIKit.C_TEXT))
	v.add_child(UIKit.label(def.en, UIKit.FP, UIKit.C_DIM, true))
	var ch := UIKit.hbox(2)
	ch.add_child(UIKit.icon_rect("scrap", 16))
	var cl := UIKit.label(str(def.cost), UIKit.FP, UIKit.C_GOLD, true)
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.add_child(cl)
	v.add_child(ch)
	h.add_child(v)
	var b := UIKit.button(("Lv.%d" % ul if ul < 99 else "พิมพ์เขียว") if locked else "สร้าง", "gray" if locked else "green", "lock" if locked else "hammer")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = locked
	b.set_meta("cost", {"scrap": def.cost})
	b.set_meta("locked", locked)
	var tt := t
	b.pressed.connect(func():
		close()
		placement_requested.emit(tt))
	h.add_child(b)
	return p


func _update_affordable() -> void:
	_scrap_lbl.text = "SCRAP %d/%d" % [int(Game.s.res.scrap), int(Game.cap("scrap"))]
	for b in _grid.find_children("*", "Button", true, false):
		if b.has_meta("cost"):
			b.disabled = b.get_meta("locked") or not Game.can_afford(b.get_meta("cost"))
	_frame_btn.disabled = int(Game.s.vault_level) >= Data.MAX_VAULT_LEVEL or float(Game.s.res.scrap) < Game.vault_upgrade_cost()
	var missing := Game.hull_max() - float(Game.s.hull)
	_repair_btn.text = "ซ่อม %d%% (%d)" % [int(float(Game.s.hull) / Game.hull_max() * 100.0), int(ceil(missing * 0.6))]
	_repair_btn.disabled = missing < 1.0 or float(Game.s.res.scrap) < ceil(missing * 0.6)
