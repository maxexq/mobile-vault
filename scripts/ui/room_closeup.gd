class_name RoomCloseup
extends ModalPanel
## Terminal panel shown while the camera is zoomed into a room (management mode).
## Workers (assign / move / remove), production, recipes with pixel progress bars, upgrade, demolish.
## Empty slots show a build list; locked slots explain the vault upgrade.
## focus_rect() tells the camera where on screen the zoomed room should sit.

signal build_requested(slot: int, room_type: String)

var slot := -1
var mode := "main"           # main | assign
var _job_bar: ProgressBar
var _job_lbl: Label
var _content: VBoxContainer


func _build() -> void:
	dim_alpha = 0.0
	dim.color = Color(0, 0, 0, 0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content = make_list(4)
	Game.rooms_changed.connect(_maybe_refresh)
	Game.dwellers_changed.connect(_maybe_refresh)
	Game.resources_changed.connect(_update_buttons)


func _portrait() -> bool:
	var vp := get_viewport_rect().size
	return vp.y >= vp.x


## screen area reserved for the zoomed-in room
func focus_rect() -> Rect2:
	var vp := get_viewport_rect().size
	if _portrait():
		return Rect2(8, 26, vp.x - 16, floorf(vp.y * 0.3))
	return Rect2(4, 4, floorf(vp.x * 0.46), vp.y - 8)


func _layout() -> void:
	var vp := get_viewport_rect().size
	var f := focus_rect()
	var sz: Vector2
	if _portrait():
		var z := clampi(int(minf(f.size.x / 80.0, f.size.y / 52.0)), 2, 3)
		var room_bottom := f.get_center().y + 26.0 * z + 6.0
		sz = Vector2(vp.x - 8, vp.y - room_bottom - 4)
		box.position = Vector2(4, floorf(room_bottom))
	else:
		sz = Vector2(vp.x - f.end.x - 8, vp.y - 8)
		box.position = Vector2(floorf(f.end.x + 4), 4)
	sz = sz.floor()
	box.custom_minimum_size = sz
	box.size = sz


func open_slot(s: int) -> void:
	slot = s
	mode = "main"
	open()


func _maybe_refresh() -> void:
	if is_open:
		refresh()


func refresh() -> void:
	if slot < 0:
		return
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_job_bar = null
	var r: Dictionary = Game.s.rooms[slot]
	if not Game.is_slot_unlocked(slot):
		_build_locked()
		return
	if r.type == "empty":
		_build_empty()
		return
	var def := Data.room_def(r.type)
	set_title("%s LV%d / %s" % [def.en, r.level, def.th])
	if mode == "assign":
		_build_assign(def)
		return
	_build_workers(def)
	_build_production(r, def)
	_build_recipes(r, def)
	_build_upgrade(r, def)


# ------------------------------------------------------------------ sections
func _section(en: String, th: String = "") -> void:
	_content.add_child(UIKit.header(en, th))


func _build_workers(def: Dictionary) -> void:
	var workers := Game.room_workers(slot)
	var st: String = def.get("stat", "str")
	_section("WORKERS %d/%d · %s" % [workers.size(), Data.ROOM_WORKERS, st.to_upper()], "ผู้ทำงาน")
	for d in workers:
		var card := UIKit.panel()
		var h := UIKit.hbox(4)
		card.add_child(h)
		h.add_child(UIKit.portrait(d.variant))
		var v := UIKit.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label("%s  Lv.%d" % [d.name, d.lvl], UIKit.FS_SMALL))
		v.add_child(UIKit.stat_bar(st, int(d[st])))
		h.add_child(v)
		var did: int = d.id
		var mv := UIKit.button("ย้าย", "blue")
		mv.pressed.connect(func(): _open_dweller(did))
		h.add_child(mv)
		var rm := UIKit.button("", "gray", "close")
		rm.tooltip_text = "ถอดออก"
		rm.pressed.connect(func(): Game.assign(Game.dweller_by_id(did), -1))
		h.add_child(rm)
		_content.add_child(card)
	if workers.size() < Data.ROOM_WORKERS:
		var add := UIKit.button("+ เพิ่มคนทำงาน", "green", "people")
		add.pressed.connect(func():
			mode = "assign"
			refresh())
		_content.add_child(add)


func _build_assign(def: Dictionary) -> void:
	var st: String = def.get("stat", "str")
	var back := UIKit.button("< กลับ", "gray")
	back.pressed.connect(func():
		mode = "main"
		refresh())
	_content.add_child(back)
	_section("SELECT · SORT %s" % st.to_upper(), "เลือกผู้ลี้ภัย")
	var list: Array = []
	for d in Game.s.dwellers:
		if not Game.is_away(d) and int(d.room) != slot:
			list.append(d)
	list.sort_custom(func(a, b): return int(a[st]) > int(b[st]))
	if list.is_empty():
		_content.add_child(UIKit.wrap_label("ไม่มีผู้ลี้ภัยว่าง (ทุกคนทำงานอยู่ที่นี่หรือออกสำรวจ)"))
	for d in list:
		var where: String = "ว่าง" if int(d.room) < 0 else Data.room_def(Game.s.rooms[int(d.room)].type).th
		if Game.squad_role(d) >= 0:
			where = Combat.ROLES[Game.squad_role(d)].th
		var b := _row_button(d, "%s  %s%d  (%s)" % [d.name, st.to_upper(), d[st], where], "gray" if int(d.room) >= 0 else "green")
		var did: int = d.id
		b.pressed.connect(func():
			if Game.assign(Game.dweller_by_id(did), slot):
				mode = "main"
				refresh())
		_content.add_child(b)


func _row_button(d: Dictionary, text: String, color: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 28)
	b.focus_mode = Control.FOCUS_NONE
	UIKit.style_button(b, color)
	var h := UIKit.hbox(4)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 3
	h.offset_top = 3
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pt := UIKit.tex_rect(Atlas.tex("pt_" + d.variant), Vector2(20, 20))
	h.add_child(pt)
	var l := UIKit.label(text, UIKit.FS_SMALL)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	b.add_child(h)
	return b


func _build_production(r: Dictionary, def: Dictionary) -> void:
	var rate := Game.room_rate_pm(slot)
	var txt := ""
	for k in rate:
		txt += "+%.1f %s/นาที  " % [rate[k], Data.item_name(k)]
	if txt == "" and not def.produce.is_empty():
		txt = "ไม่มีคนทำงาน — หยุดผลิต"
	var eff := UIKit.panel()
	var v := UIKit.vbox(1)
	eff.add_child(v)
	v.add_child(UIKit.label("EFFECT: " + def.effect_en, UIKit.FP, UIKit.C_GREEN, true))
	v.add_child(UIKit.wrap_label(def.effect_th, UIKit.FS_SMALL, UIKit.C_DIM))
	if txt != "":
		v.add_child(UIKit.wrap_label(txt, UIKit.FS_SMALL, UIKit.C_TEXT))
	var syn := Crew.synergy_text(slot)
	var cm := Crew.room_mult(slot)
	if syn != "" or absf(cm - 1.0) > 0.01:
		v.add_child(UIKit.wrap_label("โบนัสทีม x%.2f %s" % [cm, ("· " + syn) if syn != "" else ""], UIKit.FS_SMALL, UIKit.C_GOLD))
	for e in Synergy.effects(slot):
		var good := float(e.mult) + float(e.happy) > 0.0
		v.add_child(UIKit.wrap_label("%s ติด%s: %s" % ["▲" if good else "▼", Data.room_def(str(e.type)).th, e.th], UIKit.FS_SMALL, UIKit.C_GREEN if good else UIKit.C_RED))
	if Game.room_dark(slot):
		v.add_child(UIKit.wrap_label("ไฟดับ! ห้องมืดสนิท ผลิตได้น้อยลง — ช่างเครื่องซ่อมได้เร็วขึ้น" if not Game.blackout() else "แบตเตอรี่หมด! ทั้งรถมืด", UIKit.FS_SMALL, UIKit.C_RED))
	for d in Game.room_occupants(slot):
		if d.get("strike", false):
			v.add_child(UIKit.wrap_label("%s ประท้วงหยุดงาน (ความสุข %d)" % [d.name, int(d.happy)], UIKit.FS_SMALL, UIKit.C_RED))
	if Env.prod_mult() < 0.99:
		v.add_child(UIKit.wrap_label("หนาวจัด! ผลิตได้ x%.2f (ต้องการเชื้อเพลิง)" % Env.prod_mult(), UIKit.FS_SMALL, UIKit.C_RED))
	if def.get("weather_crop", false):
		v.add_child(UIKit.label("สภาพอากาศ: %s (x%.2f)" % [Game.weather_def().th, Game.weather_def().crop], UIKit.FS_SMALL, UIKit.C_BLUE))
	_content.add_child(eff)


func _build_recipes(r: Dictionary, def: Dictionary) -> void:
	var recs: Array = def.get("recipes", [])
	if recs.is_empty():
		return
	_section("CRAFTING", "การผลิต")
	for rec in recs:
		var active: bool = not r.job.is_empty() and r.job.id == rec.id
		var p := UIKit.panel(UIKit.C_BG2, UIKit.C_LINE if active else UIKit.C_LINE_DARK)
		var v := UIKit.vbox(2)
		p.add_child(v)
		var h := UIKit.hbox(4)
		v.add_child(h)
		h.add_child(UIKit.icon_rect(Data.item_icon(rec.out.keys()[0]), 16))
		var outs := []
		for k in rec.out:
			outs.append("%s x%d" % [Data.item_name(k), rec.out[k]])
		var lv := UIKit.vbox(0)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.add_child(UIKit.label(rec.th, UIKit.FS_SMALL, UIKit.C_TEXT))
		lv.add_child(UIKit.wrap_label("%s → %s" % [Game.cost_text(rec.cost), ", ".join(outs)], UIKit.FS_SMALL, UIKit.C_DIM))
		h.add_child(lv)
		if active:
			_job_bar = UIKit.progress(UIKit.C_GREEN, 10)
			_job_bar.custom_minimum_size.y = 10
			_job_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_job_lbl = UIKit.label("", UIKit.FP, UIKit.C_WHITE, true)
			_job_lbl.add_theme_constant_override("outline_size", 2)
			_job_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			_job_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_job_bar.add_child(_job_lbl)
			v.add_child(_job_bar)
		else:
			var b := UIKit.button("ผลิต", "green", "gear")
			b.set_meta("cost", rec.cost)
			b.set_meta("busy", not r.job.is_empty())
			var rid: String = rec.id
			b.pressed.connect(func(): Game.start_craft(slot, rid))
			h.add_child(b)
		_content.add_child(p)
	_update_buttons()


func _build_upgrade(r: Dictionary, def: Dictionary) -> void:
	_section("UPGRADE", "อัปเกรด")
	var h := UIKit.hbox(4)
	if int(r.level) < Data.ROOM_MAX_LEVEL:
		var c: int = Data.ROOM_UPGRADE_COST[int(r.level) + 1]
		var b := UIKit.button("อัปเกรด Lv.%d  (%d เศษเหล็ก)" % [int(r.level) + 1, c], "yellow", "wrench")
		b.set_meta("cost", {"scrap": c})
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): Game.upgrade_room(slot))
		h.add_child(b)
	else:
		h.add_child(UIKit.label("ห้องเลเวลสูงสุดแล้ว (MAX)", UIKit.FS_SMALL, UIKit.C_GOLD))
	if r.type != "engine":
		var d := UIKit.button("รื้อ", "red", "close")
		d.pressed.connect(func():
			Game.demolish_room(slot)
			refresh())
		h.add_child(d)
	_content.add_child(h)
	_update_buttons()


func _build_empty() -> void:
	set_title("EMPTY SLOT / ช่องว่าง — เลือกห้องที่จะสร้าง")
	_section("SCRAP %d" % int(Game.s.res.scrap), "วัสดุ")
	for t in Data.BUILDABLE:
		var def := Data.room_def(t)
		var ul := Game.room_unlock_level(t)
		var locked := ul > int(Game.s.vault_level)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 34)
		b.focus_mode = Control.FOCUS_NONE
		UIKit.style_button(b, "gray" if locked else "green")
		var h := UIKit.hbox(4)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 3
		h.offset_top = 3
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 40x26 crop of the room art (no scaling)
		h.add_child(UIKit.tex_rect(Atlas.sub("room_" + t, Rect2(20, 20, 40, 26)), Vector2(40, 26)))
		var v := UIKit.vbox(0)
		v.add_child(UIKit.label(def.th, UIKit.FS_SMALL))
		v.add_child(UIKit.label((("ต้องการ Vault Lv.%d" % ul) if ul < 99 else "ต้องมีพิมพ์เขียว") if locked else ("%d เศษเหล็ก" % def.cost), UIKit.FS_SMALL, UIKit.C_DIM))
		h.add_child(v)
		b.add_child(h)
		b.disabled = locked or float(Game.s.res.scrap) < float(def.cost)
		var tt: String = t
		b.pressed.connect(func():
			if Game.build_room(slot, tt):
				refresh())
		_content.add_child(b)


func _build_locked() -> void:
	set_title("LOCKED / ชั้นที่ยังปิดตาย")
	_content.add_child(UIKit.wrap_label("ชั้นนี้ยังถูกเชื่อมปิด ต้องอัปเกรดโครงรถ (Mobile Vault) เพื่อเปิดพื้นที่เพิ่ม", UIKit.FS, UIKit.C_TEXT))
	if int(Game.s.vault_level) < Data.MAX_VAULT_LEVEL:
		var c := Game.vault_upgrade_cost()
		var b := UIKit.button("อัปเกรด VAULT → Lv.%d (%d เศษเหล็ก)" % [int(Game.s.vault_level) + 1, c], "yellow", "up")
		b.set_meta("cost", {"scrap": c})
		b.pressed.connect(func():
			if Game.upgrade_vault():
				refresh())
		_content.add_child(b)
	_update_buttons()


func _open_dweller(did: int) -> void:
	var hud := get_parent() as HUD
	close()
	await get_tree().create_timer(0.15).timeout
	hud.open_panel("dwellers")
	(hud.panels.dwellers as DwellersPanel).manage(did)


func _update_buttons() -> void:
	if not is_open:
		return
	for b in _content.find_children("*", "Button", true, false):
		if b.has_meta("cost"):
			b.disabled = not Game.can_afford(b.get_meta("cost")) or b.get_meta("busy", false)


func _process(_d: float) -> void:
	if not is_open or slot < 0 or _job_bar == null or not is_instance_valid(_job_bar):
		return
	var r: Dictionary = Game.s.rooms[slot]
	if r.job.is_empty():
		return
	var p := float(r.job.progress) / float(r.job.total)
	_job_bar.value = p
	var sp := Game.craft_speed(slot)
	var left := (float(r.job.total) - float(r.job.progress)) / maxf(sp, 0.01)
	_job_lbl.text = "%d%% %dM%02dS" % [int(p * 100), int(left) / 60, int(left) % 60] if sp > 0.0 else "%d%% PAUSED" % int(p * 100)
	_job_lbl.size = _job_bar.size
	_job_lbl.position = Vector2(0, 1)
