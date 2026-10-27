class_name NextGenPanel
extends ModalPanel
## "The Next Generation": bank legacy points, buy permanent perks, choose who escapes, build the next truck.
## Forced (no close) when the truck is wrecked; voluntary retirement from the map screen.

var forced := false
var carry: Array = []
var step := "story"     # story | summary | perks | crew
var tier_pick := ""
var earned := 0
var refunded := 0
var _list: VBoxContainer


func _build() -> void:
	_list = make_list(4)


func _on_backdrop_tap() -> void:
	if not forced:
		close()


func open_retire(is_forced: bool) -> void:
	forced = is_forced
	close_btn.visible = not forced
	step = "story"
	tier_pick = ""
	refunded = 0
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
		"story": _build_story()
		"summary": _build_summary()
		"perks": _build_perks()
		"crew": _build_crew()


func _build_story() -> void:
	var st: Dictionary = Meta.STORIES[Meta.story_key()]
	set_title("%s / %s" % [st.en, st.title])
	var img := "res://assets/events/%s.png" % st.img
	if ResourceLoader.exists(img):
		var fr := UIKit.panel(Color("0c0c0e"), UIKit.C_LINE_DIM)
		var tr := UIKit.tex_rect(load(img), Vector2(320, 160))
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fr.add_child(tr)
		_list.add_child(fr)
	var story := str(st.text)
	if Meta.all_crew_on() and Meta.is_wrecked():
		story = Loc.t("%s พังกลางทาง แต่สัญญาณขอความช่วยเหลือส่งถึงศูนย์บัญชาการ หน่วยกู้ภัยรับผู้รอดชีวิตทุกคนพร้อมอุปกรณ์กลับฐาน เพื่อออกเดินทางด้วยรถคันใหม่")
	var body_l := UIKit.wrap_label(story % Meta.vehicle_name(), UIKit.FS, UIKit.C_TEXT)
	body_l.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_list.add_child(body_l)
	body_l.visible_ratio = 0.0
	var tw := body_l.create_tween()
	tw.tween_property(body_l, "visible_ratio", 1.0, 3.0)
	var nx := UIKit.button(Loc.t("ต่อไป"), "yellow", "play")
	nx.pressed.connect(func():
		step = "summary"
		refresh())
	_list.add_child(nx)


func _build_summary() -> void:
	set_title(Loc.t("NEXT GENERATION / ส่งต่อรุ่นถัดไป"))
	var s := Game.s
	if forced:
		_list.add_child(UIKit.label(Loc.t("%s พังทลายแล้ว...") % Meta.vehicle_name(), UIKit.FS_HUGE, UIKit.C_RED))
		_list.add_child(UIKit.wrap_label(Loc.t("ผู้รอดชีวิตทุกคนกลับฐานพร้อมอุปกรณ์ เลเวล และทักษะครบ") if Meta.all_crew_on() else Loc.t("ผู้รอดชีวิตบางส่วนหนีออกมาได้ พร้อมพิมพ์เขียวและเสบียงที่ขนมาได้"), UIKit.FS_SMALL, UIKit.C_TEXT))
	else:
		_list.add_child(UIKit.label(Loc.t("ปลดระวาง %s") % Meta.vehicle_name(), UIKit.FS_HUGE, UIKit.C_GOLD))
		_list.add_child(UIKit.wrap_label(Loc.t("รถคันนี้พาทุกคนมาได้ไกลแล้ว ถึงเวลาสร้างพาหนะที่ใหญ่กว่าเดิมเพื่อไปให้ไกลกว่านี้"), UIKit.FS_SMALL, UIKit.C_TEXT))
	var bosses := (s.combat.get("boss_beaten", {}) as Dictionary).size()
	var rows := [
		[Loc.t("ระยะทางรวม"), Loc.t("%.1f กม.") % float(s.stats.km_total)],
		[Loc.t("บอสด่านตรวจ"), str(bosses)],
		[Loc.t("รอบเส้นทาง"), str(int(s.get("lap", 0)) + 1)],
		["Vault Lv.", str(int(s.vault_level))],
		[Loc.t("การสำรวจ"), str(int(s.stats.get("expeditions", 0)))],
		[Loc.t("พิมพ์เขียว"), str((Meta.m().blueprints as Array).size())],
	]
	for r in rows:
		var h := UIKit.hbox(4)
		h.add_child(UIKit.label(r[0], UIKit.FS_SMALL, UIKit.C_DIM))
		h.add_child(UIKit.spacer())
		h.add_child(UIKit.label(r[1], UIKit.FP, UIKit.C_TEXT, true))
		_list.add_child(h)
	_list.add_child(UIKit.label(Loc.t("RESEARCH +%d (รวม %d)") % [Meta.legacy_earned(), int(Meta.m().legacy) + (0 if s.get("legacy_banked", false) else Meta.legacy_earned())], UIKit.FP, UIKit.C_GOLD, true))
	var hb := UIKit.hbox(4)
	if not forced:
		var cancel := UIKit.button(Loc.t("ยังไม่ใช่ตอนนี้"), "gray")
		cancel.pressed.connect(close)
		hb.add_child(cancel)
	var nx := UIKit.button(Loc.t("ถัดไป: งานวิจัย"), "yellow", "up")
	nx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nx.pressed.connect(func():
		refunded += Meta.refund_retired_research()
		earned = Meta.bank_legacy()
		step = "perks"
		refresh())
	hb.add_child(nx)
	_list.add_child(hb)


func _build_perks() -> void:
	set_title("RESEARCH %d / %s" % [int(Meta.m().legacy), Meta.RESEARCH_TH])
	_list.add_child(UIKit.wrap_label(Loc.t("ใช้%sซื้อความสามารถถาวรให้ทุกรุ่นถัดไป · พาหนะใหม่ต้องมีพิมพ์เขียวด้วย") % Meta.RESEARCH_TH, UIKit.FS_SMALL))
	if Meta.all_crew_on():
		_list.add_child(UIKit.wrap_label(Loc.t("ทุกคนไปต่อพร้อมเลเวลและสกิลครบ ไม่ต้องซื้อวิจัยพาคนเพิ่มหรือรักษาเลเวล · คืนแต้มวิจัยเดิม %d") % refunded, UIKit.FS_SMALL))
	for id in Meta.PERKS:
		if Meta.all_crew_on() and id in ["veterans", "training"]:
			continue
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
			v.add_child(UIKit.label(Loc.t("ต้องมี ") + Mods.BLUEPRINT_TH.get(p.bp, p.bp), UIKit.FS_SMALL, UIKit.C_ORANGE))
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
	var nx := UIKit.button(Loc.t("ถัดไป: ทีมและพาหนะ") if Meta.all_crew_on() else Loc.t("ถัดไป: เลือกผู้รอดชีวิต"), "yellow", "people")
	nx.pressed.connect(func():
		step = "crew"
		refresh())
	_list.add_child(nx)


func _build_crew() -> void:
	if Meta.all_crew_on():
		carry = Meta.all_crew_ids()
	set_title(Loc.t("CREW %d / ทุกคนไปกับรถคันใหม่") % carry.size() if Meta.all_crew_on() else Loc.t("ESCAPE %d/%d / ใครจะไปกับรถคันใหม่") % [carry.size(), Meta.carry_slots()])
	var carry_text := Loc.t("ทุกคนเก็บเลเวล XP สกิล นิสัย และอุปกรณ์ที่สวมใส่ครบ · พาเศษเหล็ก/ชิ้นส่วนไปได้ %d%% · พิมพ์เขียวไปทั้งหมด") % int(Meta.carry_res_ratio() * 100) if Meta.all_crew_on() else Loc.t("คนที่เลือกจะเก็บนิสัย อาวุธ และ %d%% ของเลเวลไว้ · พาเศษเหล็ก/ชิ้นส่วนไปได้ %d%% · พิมพ์เขียวไปทั้งหมด") % [int(Meta.carry_level_keep() * 100), int(Meta.carry_res_ratio() * 100)]
	_list.add_child(UIKit.wrap_label(carry_text, UIKit.FS_SMALL))
	if Meta.all_crew_on() and carry.size() > Data.BASE_POP_CAP:
		_list.add_child(UIKit.wrap_label(Loc.t("ทุกคนขึ้นรถได้ แม้เกินที่นอนเริ่มต้น %d ที่ · สร้างห้องพักเพิ่มบนรถใหม่") % Data.BASE_POP_CAP, UIKit.FS_SMALL, UIKit.C_ORANGE))
	var arr: Array = Game.s.dwellers.duplicate()
	arr.sort_custom(func(a, b): return int(a.lvl) > int(b.lvl))
	for d in arr:
		var did: int = d.id
		var sel := carry.has(did)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 28)
		b.focus_mode = Control.FOCUS_NONE
		UIKit.style_button(b, "yellow" if sel else "gray")
		b.disabled = Meta.all_crew_on() or (not sel and carry.size() >= Meta.carry_slots())
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
			if Meta.all_crew_on():
				return
			if carry.has(did):
				carry.erase(did)
			elif carry.size() < Meta.carry_slots():
				carry.append(did)
			refresh())
		_list.add_child(b)
	_list.add_child(UIKit.header("VEHICLE", Loc.t("พาหนะคันใหม่")))
	if tier_pick == "":
		tier_pick = Meta.best_tier()
	var vh := UIKit.flow(3)
	for t in Data.TIER_ORDER:
		if not Meta.tier_unlocked(t):
			continue
		var vd: Dictionary = Data.VEHICLES[t]
		var tb := UIKit.button(Loc.t("%s (%d ห้อง)") % [vd.th, int(vd.floors) * 3], "yellow" if t == tier_pick else "gray")
		var tid: String = t
		tb.pressed.connect(func():
			tier_pick = tid
			refresh())
		vh.add_child(tb)
	_list.add_child(vh)
	var go := UIKit.button(Loc.t("สร้างพาหนะคันใหม่!"), "red", "hammer")
	go.name = "NextGenerationButton"
	go.pressed.connect(_request_next_generation)
	_list.add_child(go)


func _request_next_generation() -> void:
	var whole_crew := Meta.all_crew_on()
	var picks := Meta.all_crew_ids() if whole_crew else carry.duplicate()
	var tier := tier_pick
	var state := Game.s
	var names: Array = []
	for did in picks:
		var d := Game.dweller_by_id(int(did))
		if not d.is_empty():
			names.append(str(d.name))
	var message := Loc.t("รถและห้องปัจจุบันจะถูกแทนที่ เก็บไว้เฉพาะลูกเรือที่เลือกพร้อมอาวุธ และ %d%% ของเศษเหล็ก/ชิ้นส่วน อุปกรณ์อื่นจะหายไป ย้อนคืนไม่ได้\nผู้รอดชีวิตที่เลือก: %s") % [int(Meta.carry_res_ratio() * 100), ", ".join(names) if not names.is_empty() else Loc.t("ไม่มี")]
	if whole_crew:
		message = Loc.t("ผู้รอดชีวิตทั้ง %d คนไปต่อ พร้อมเลเวล XP สกิล และอุปกรณ์ที่สวมใส่ครบ\nรถ ห้อง และเส้นทางเริ่มใหม่ เก็บเศษเหล็ก/ชิ้นส่วน %d%% กับพิมพ์เขียวทั้งหมด ของในคลังและอุปกรณ์รถเดิมจะหายไป ย้อนคืนไม่ได้") % [picks.size(), int(Meta.carry_res_ratio() * 100)]
	ConfirmPanel.ask(self, Loc.t("สร้างพาหนะคันใหม่!"), message, Loc.t("ยืนยันขึ้นรุ่นถัดไป"), func():
		forced = false
		close()
		Meta.next_generation(picks, tier), func(): return is_same(Game.s, state) and Meta.all_crew_on() == whole_crew and (Meta.all_crew_ids() == picks if whole_crew else carry == picks) and tier_pick == tier and _picks_present(picks))


func _picks_present(picks: Array) -> bool:
	for did in picks:
		if Game.dweller_by_id(int(did)).is_empty():
			return false
	return true
