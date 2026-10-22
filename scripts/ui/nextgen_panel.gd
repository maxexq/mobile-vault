class_name NextGenPanel
extends ModalPanel
## "The Next Generation": bank legacy points, buy permanent perks, choose who escapes, build the next truck.
## Forced (no close) when the truck is wrecked; voluntary retirement from the map screen.

var forced := false
var carry: Array = []
var step := "summary"   # summary | perks | crew
var earned := 0
var _list: VBoxContainer


func _build() -> void:
	_list = make_list(4)


func _on_backdrop_tap() -> void:
	if not forced:
		close()


func open_retire(is_forced: bool) -> void:
	forced = is_forced
	close_btn.visible = not forced
	step = "summary"
	carry = []
	# default picks: highest level survivors
	var arr: Array = Game.s.dwellers.duplicate()
	arr.sort_custom(func(a, b): return int(a.lvl) > int(b.lvl))
	for d in arr.slice(0, Meta.carry_slots()):
		carry.append(int(d.id))
	open()


func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	match step:
		"summary": _build_summary()
		"perks": _build_perks()
		"crew": _build_crew()


func _build_summary() -> void:
	set_title("NEXT GENERATION / ส่งต่อรุ่นถัดไป")
	var s := Game.s
	if forced:
		_list.add_child(UIKit.label("%s พังทลายแล้ว..." % Meta.vehicle_name(), UIKit.FS_HUGE, UIKit.C_RED))
		_list.add_child(UIKit.wrap_label("ผู้รอดชีวิตบางส่วนหนีออกมาได้ พร้อมพิมพ์เขียวและเสบียงที่ขนมาได้", UIKit.FS_SMALL, UIKit.C_TEXT))
	else:
		_list.add_child(UIKit.label("ปลดระวาง %s" % Meta.vehicle_name(), UIKit.FS_HUGE, UIKit.C_GOLD))
		_list.add_child(UIKit.wrap_label("รถคันนี้พาทุกคนมาได้ไกลแล้ว ถึงเวลาสร้างพาหนะที่ใหญ่กว่าเดิมเพื่อไปให้ไกลกว่านี้", UIKit.FS_SMALL, UIKit.C_TEXT))
	var bosses := (s.combat.get("boss_beaten", {}) as Dictionary).size()
	var rows := [
		["ระยะทางรวม", "%.1f กม." % float(s.stats.km_total)],
		["บอสด่านตรวจ", str(bosses)],
		["รอบเส้นทาง", str(int(s.get("lap", 0)) + 1)],
		["Vault Lv.", str(int(s.vault_level))],
		["การสำรวจ", str(int(s.stats.get("expeditions", 0)))],
		["พิมพ์เขียว", str((Meta.m().blueprints as Array).size())],
	]
	for r in rows:
		var h := UIKit.hbox(4)
		h.add_child(UIKit.label(r[0], UIKit.FS_SMALL, UIKit.C_DIM))
		h.add_child(UIKit.spacer())
		h.add_child(UIKit.label(r[1], UIKit.FP, UIKit.C_TEXT, true))
		_list.add_child(h)
	_list.add_child(UIKit.label("LEGACY +%d (รวม %d)" % [Meta.legacy_earned(), int(Meta.m().legacy) + (0 if s.get("legacy_banked", false) else Meta.legacy_earned())], UIKit.FP, UIKit.C_GOLD, true))
	var hb := UIKit.hbox(4)
	if not forced:
		var cancel := UIKit.button("ยังไม่ใช่ตอนนี้", "gray")
		cancel.pressed.connect(close)
		hb.add_child(cancel)
	var nx := UIKit.button("ถัดไป: มรดก", "yellow", "up")
	nx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nx.pressed.connect(func():
		earned = Meta.bank_legacy()
		step = "perks"
		refresh())
	hb.add_child(nx)
	_list.add_child(hb)


func _build_perks() -> void:
	set_title("LEGACY %d / มรดกถาวร" % int(Meta.m().legacy))
	_list.add_child(UIKit.wrap_label("ใช้แต้มมรดกซื้อความสามารถถาวรให้ทุกรุ่นถัดไป", UIKit.FS_SMALL))
	for id in Meta.PERKS:
		var p: Dictionary = Meta.PERKS[id]
		var lv := Meta.perk(id)
		var card := UIKit.panel(UIKit.C_BG2, UIKit.C_GOLD if lv > 0 else UIKit.C_LINE_DARK)
		var h := UIKit.hbox(4)
		card.add_child(h)
		h.add_child(UIKit.icon_rect(p.icon, 16))
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label("%s  %d/%d" % [p.th, lv, int(p.max)], UIKit.FS_SMALL, UIKit.C_TEXT))
		v.add_child(UIKit.wrap_label(p.desc, UIKit.FS_SMALL))
		if p.has("bp") and not Meta.has_blueprint(p.bp):
			v.add_child(UIKit.label("ต้องมี " + Mods.BLUEPRINT_TH.get(p.bp, p.bp), UIKit.FS_SMALL, UIKit.C_ORANGE))
		h.add_child(v)
		if lv < int(p.max):
			var b := UIKit.button("%d" % Meta.perk_cost(id), "yellow", "xp")
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.disabled = not Meta.can_buy(id, int(Meta.m().legacy))
			var pid: String = id
			b.pressed.connect(func():
				if Meta.buy(pid):
					refresh())
			h.add_child(b)
		_list.add_child(card)
	var nx := UIKit.button("ถัดไป: เลือกผู้รอดชีวิต", "yellow", "people")
	nx.pressed.connect(func():
		step = "crew"
		refresh())
	_list.add_child(nx)


func _build_crew() -> void:
	set_title("ESCAPE %d/%d / ใครจะไปกับรถคันใหม่" % [carry.size(), Meta.carry_slots()])
	_list.add_child(UIKit.wrap_label("คนที่เลือกจะเก็บ Trait อาวุธ และ %d%% ของเลเวลไว้ · พาเศษเหล็ก/ชิ้นส่วนไปได้ %d%% · พิมพ์เขียวไปทั้งหมด" % [int(Meta.carry_level_keep() * 100), int(Meta.carry_res_ratio() * 100)], UIKit.FS_SMALL))
	var arr: Array = Game.s.dwellers.duplicate()
	arr.sort_custom(func(a, b): return int(a.lvl) > int(b.lvl))
	for d in arr:
		var did: int = d.id
		var sel := carry.has(did)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 28)
		b.focus_mode = Control.FOCUS_NONE
		UIKit.style_button(b, "yellow" if sel else "gray")
		b.disabled = not sel and carry.size() >= Meta.carry_slots()
		var h := UIKit.hbox(4)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 3
		h.offset_top = 3
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(UIKit.tex_rect(Atlas.tex("pt_" + d.variant), Vector2(20, 20)))
		var tags := []
		for t in Crew.traits(d):
			tags.append(Crew.TRAITS[t].th)
		var l := UIKit.label("%s Lv%d · %s" % [d.name, d.lvl, ", ".join(tags)], UIKit.FS_SMALL)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		b.add_child(h)
		b.pressed.connect(func():
			if carry.has(did):
				carry.erase(did)
			elif carry.size() < Meta.carry_slots():
				carry.append(did)
			refresh())
		_list.add_child(b)
	var ch := Meta.chassis()
	_list.add_child(UIKit.label("รถคันใหม่: %s · แชสซี MK-%s (%d ชั้น)" % [Meta.VEHICLE_NAMES[clampi(Meta.generation(), 0, Meta.VEHICLE_NAMES.size() - 1)], ["I", "II", "III"][ch - 1], 3 + ch], UIKit.FS_SMALL, UIKit.C_GOLD))
	var go := UIKit.button("สร้างพาหนะคันใหม่!", "red", "hammer")
	go.pressed.connect(func():
		var picks := carry.duplicate()
		forced = false
		is_open = false
		visible = false
		Meta.next_generation(picks))
	_list.add_child(go)
