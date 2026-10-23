class_name ExpeditionPanel
extends ModalPanel
## Expedition planner / tracker.
##  - at a landmark (or anywhere: "scavenge the area") pick 1-3 survivors, pack supplies, see the odds
##  - while a team is out: progress, time left, who went
##  - after: the report (loot, injuries, infections, losses)

var site := ""
var picked: Array = []
var sup := {"food": 0, "water": 0, "stimpack": 0, "ammo": 0, "antibiotics": 0}
var report := {}
var _list: VBoxContainer
# live view while a team is out (built once, then updated in place so the feed keeps animating)
var _feed: ExpeditionFeed
var _active_built := false
var _pr: ProgressBar
var _time_lbl: Label
var _status_lbls: Array = []
var _log_lbls: Array = []
var _enc_btn: Button


func _build() -> void:
	_list = make_list(4)
	Expedition.expedition_finished.connect(func(r):
		report = r
		if is_open:
			refresh())


func open_site(id: String) -> void:
	site = id
	picked = []
	report = {}
	_auto_supplies()
	open()


func _auto_supplies() -> void:
	var need := Expedition.need_supplies(site, maxi(1, picked.size()))
	sup.food = mini(int(need.food), int(Game.s.res.food))
	sup.water = mini(int(need.water), int(Game.s.res.water))
	sup.stimpack = mini(1, int(Game.s.items.get("stimpack", 0)))
	sup.ammo = mini(5, int(Game.s.items.get("ammo", 0)))
	sup.antibiotics = 0


func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_active_built = false
	_feed = null
	if not report.is_empty():
		_build_report()
	elif Expedition.active():
		_build_active()
		_active_built = true
	else:
		_build_planner()


func _process(_d: float) -> void:
	if not is_open or not report.is_empty():
		return
	if Expedition.active():
		if not _active_built:
			refresh()
		elif Engine.get_process_frames() % 10 == 0:
			_update_active()
	elif _active_built:
		refresh()


# ------------------------------------------------------------------ planner
func _build_planner() -> void:
	var def := Expedition.site_def(site)
	set_title("%s / %s" % [def.en, def.th])
	if not Features.on("expeditions"):
		_list.add_child(UIKit.wrap_label("การส่งทีมสำรวจปิดใช้งานชั่วคราว", UIKit.FS, UIKit.C_RED))
	var card := UIKit.panel(UIKit.C_BG2, UIKit.C_GOLD)
	var h := UIKit.hbox(6)
	card.add_child(h)
	if def.sprite != "" and Atlas.has(def.sprite):
		h.add_child(UIKit.tex_rect(Atlas.tex(def.sprite), Vector2(64, 64)))
	var v := UIKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.wrap_label("ภารกิจ: " + def.goal, UIKit.FS_SMALL, UIKit.C_TEXT))
	var dh := UIKit.hbox(2)
	dh.add_child(UIKit.label("DANGER", UIKit.FP, UIKit.C_RED, true))
	dh.add_child(UIKit.skulls(int(def.danger)))
	v.add_child(dh)
	v.add_child(UIKit.label("ใช้เวลา %d นาที · รถจะจอดรอ" % int(Expedition.duration_sec(site) / 60.0), UIKit.FS_SMALL, UIKit.C_DIM))
	var bps: Array = def.loot.get("bp", [])
	var new_bp := ""
	for b in bps:
		if not Meta.has_blueprint(b):
			new_bp = Mods.BLUEPRINT_TH.get(b, b)
			break
	if new_bp != "":
		v.add_child(UIKit.label("รางวัลพิเศษ: " + new_bp, UIKit.FS_SMALL, UIKit.C_GOLD))
	h.add_child(v)
	_list.add_child(card)
	# team
	_list.add_child(UIKit.header("TEAM %d/%d" % [picked.size(), Expedition.MAX_TEAM], "เลือกทีมสำรวจ"))
	var cands := []
	for d in Game.s.dwellers:
		if not Game.is_away(d):
			cands.append(d)
	cands.sort_custom(func(a, b): return Combat.hero_power(a) > Combat.hero_power(b))
	for d in cands:
		var did: int = d.id
		var sel := picked.has(did)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 30)
		b.focus_mode = Control.FOCUS_NONE
		UIKit.style_button(b, "yellow" if sel else "gray")
		b.disabled = not sel and picked.size() >= Expedition.MAX_TEAM
		var bh := UIKit.hbox(4)
		bh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bh.offset_left = 3
		bh.offset_top = 3
		bh.offset_right = -3
		bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bh.add_child(UIKit.tex_rect(Atlas.tex("pt_" + d.variant), Vector2(20, 20)))
		var tv := UIKit.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tags := []
		for t in Crew.traits(d):
			tags.append(Crew.TRAITS[t].th)
		tv.add_child(UIKit.label("%s Lv%d  พลัง %d" % [d.name, d.lvl, int(Combat.hero_power(d))], UIKit.FS_SMALL))
		var role := Game.squad_role(d)
		if role >= 0:
			# defence squad members can go, but their slot is freed for someone else
			var rh := UIKit.hbox(2)
			rh.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rh.add_child(UIKit.icon_rect("sword", 10))
			rh.add_child(UIKit.label("อยู่ในทีมป้องกันรถ · %s" % Combat.ROLES[role].th, UIKit.FS_SMALL, UIKit.C_ORANGE))
			tv.add_child(rh)
		tv.add_child(UIKit.label(" · ".join(tags), UIKit.FS_SMALL, UIKit.C_DIM))
		bh.add_child(tv)
		var hp := UIKit.progress(UIKit.C_GREEN if float(d.hp) > float(d.max_hp) * 0.4 else UIKit.C_RED, 3)
		hp.value = float(d.hp) / float(d.max_hp)
		hp.custom_minimum_size.x = 22
		hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bh.add_child(hp)
		b.add_child(bh)
		b.pressed.connect(func():
			if picked.has(did):
				picked.erase(did)
			elif picked.size() < Expedition.MAX_TEAM:
				picked.append(did)
			_auto_supplies()
			refresh())
		_list.add_child(b)
	var leaving := []
	for id in picked:
		var pr := Game.squad_role(Game.dweller_by_id(int(id)))
		if pr >= 0:
			leaving.append(Combat.ROLES[pr].th)
	if not leaving.is_empty():
		_list.add_child(UIKit.wrap_label("ช่องทีมป้องกันรถ (%s) จะว่างทันทีที่ออกเดินทาง — เลือกคนใหม่ได้ที่เมนู Squad" % ", ".join(leaving), UIKit.FS_SMALL, UIKit.C_ORANGE))
	# supplies
	var need := Expedition.need_supplies(site, maxi(1, picked.size()))
	_list.add_child(UIKit.header("SUPPLIES", "เสบียงที่พกไป (แนะนำ อาหาร %d น้ำ %d)" % [int(need.food), int(need.water)]))
	for k in Expedition.SUPPLY_KEYS:
		_list.add_child(_stepper(k))
	# odds + actions
	var members := []
	for id in picked:
		members.append(Game.dweller_by_id(int(id)))
	var ch := Expedition.success_chance(site, members, sup)
	var col := UIKit.C_GREEN if ch >= 0.7 else (UIKit.C_GOLD if ch >= 0.45 else UIKit.C_RED)
	_list.add_child(UIKit.label("โอกาสสำเร็จ ~%d%%  (พลังทีม %d vs อันตราย %d)" % [int(ch * 100), int(Expedition.team_power(members, sup)), int(Expedition.danger_need(site))], UIKit.FS, col))
	_list.add_child(UIKit.wrap_label("ล้มเหลว = ได้ของน้อย บาดเจ็บ ติดเชื้อ หรือมีคนไม่กลับมา · สติมแพ็กลดการบาดเจ็บ ยาปฏิชีวนะลดการติดเชื้อ", UIKit.FS_SMALL))
	var hb := UIKit.hbox(4)
	if Expedition.SITES.has(site):
		var skip := UIKit.button("ขับผ่าน", "gray", "play")
		skip.pressed.connect(func():
			Expedition.skip_site()
			close())
		hb.add_child(skip)
	var go := UIKit.button("ส่งทีมสำรวจ!", "red", "explore")
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.disabled = picked.size() < Expedition.min_team()
	if go.disabled:
		go.text = "ต้องการทีม %d-%d คน" % [Expedition.min_team(), Expedition.MAX_TEAM]
	go.pressed.connect(func():
		if Expedition.start(site, picked, sup):
			close())
	hb.add_child(go)
	_list.add_child(hb)


func _stepper(k: String) -> Control:
	var h := UIKit.hbox(4)
	h.add_child(UIKit.icon_rect(Data.item_icon(k), 16))
	var have := int(Game.s.res[k]) if Game.s.res.has(k) else int(Game.s.items.get(k, 0))
	var l := UIKit.label("%s %d (มี %d)" % [Data.item_name(k), int(sup[k]), have], UIKit.FS_SMALL)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var step := 5 if k in ["food", "water", "ammo"] else 1
	var minus := UIKit.button("-", "gray")
	minus.pressed.connect(func():
		sup[k] = maxi(0, int(sup[k]) - step)
		refresh())
	h.add_child(minus)
	var plus := UIKit.button("+", "green")
	plus.disabled = int(sup[k]) + step > have
	plus.pressed.connect(func():
		sup[k] = mini(have, int(sup[k]) + step)
		refresh())
	h.add_child(plus)
	return h


# ------------------------------------------------------------------ active / report
func _build_active() -> void:
	var e := Expedition.state()
	var def := Expedition.site_def(str(e.site))
	set_title("EXPEDITION / ทีมกำลังสำรวจ %s" % def.th)
	_feed = ExpeditionFeed.new()
	_feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(_feed)
	_enc_btn = UIKit.button("วิทยุจากทีม: เจอจุดพิเศษ! แตะเพื่อสั่งการ", "yellow", "explore")
	_enc_btn.pressed.connect(func():
		var hud := get_parent()
		if hud.has_method("open_encounter"):
			hud.open_encounter())
	_list.add_child(_enc_btn)
	_pr = UIKit.progress(UIKit.C_GOLD, 6)
	_list.add_child(_pr)
	_time_lbl = UIKit.label("", UIKit.FS, UIKit.C_TEXT)
	_list.add_child(_time_lbl)
	_list.add_child(UIKit.wrap_label("ภารกิจ: " + def.goal, UIKit.FS_SMALL))
	_list.add_child(UIKit.header("SQUAD", "ใครไปบ้าง · กำลังทำอะไร"))
	_status_lbls = []
	var team := Expedition.team()
	for i in team.size():
		var d: Dictionary = team[i]
		var h := UIKit.hbox(4)
		var mark := ColorRect.new()
		mark.color = ExpeditionFeed.MARK[i % ExpeditionFeed.MARK.size()]
		mark.custom_minimum_size = Vector2(3, 24)
		h.add_child(mark)
		h.add_child(UIKit.portrait(d.variant))
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label("%s Lv%d" % [d.name, d.lvl], UIKit.FS_SMALL))
		var st := UIKit.label("", UIKit.FS_SMALL, UIKit.C_GOLD)
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(st)
		_status_lbls.append(st)
		h.add_child(v)
		_list.add_child(h)
	_list.add_child(UIKit.header("FIELD LOG", "บันทึกภาคสนาม"))
	_log_lbls = []
	for k in 3:
		var l := UIKit.label("", UIKit.FS_SMALL, UIKit.C_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(l)
		_log_lbls.append(l)
	_list.add_child(UIKit.label("โอกาสสำเร็จ ~%d%%" % int(Expedition.success_chance(str(e.site), team, e.sup) * 100), UIKit.FS_SMALL, UIKit.C_GOLD))
	_update_active()


func _update_active() -> void:
	if _feed == null or not Expedition.active():
		return
	_pr.value = Expedition.progress()
	_enc_btn.visible = Encounter.pending()
	var tl := Expedition.time_left()
	_time_lbl.text = "เหลืออีก %d:%02d · รถจอดรอทีมอยู่" % [int(tl) / 60, int(tl) % 60]
	for i in _status_lbls.size():
		var s := _feed.member_status(i)
		(_status_lbls[i] as Label).text = ("> " + s) if s != "" else ""
	var lines := _feed.log_lines(3)
	for k in _log_lbls.size():
		var l: Label = _log_lbls[k]
		if k < lines.size():
			var ln: Dictionary = lines[lines.size() - 1 - k]
			l.text = "%02d:%02d  %s" % [int(ln.t) / 60, int(ln.t) % 60, str(ln.text)]
			l.add_theme_color_override("font_color", ln.col if k == 0 else (ln.col as Color).darkened(0.35))
		else:
			l.text = ""


func _build_report() -> void:
	var def := Expedition.site_def(str(report.site))
	set_title("REPORT / ผลการสำรวจ %s" % def.th)
	var ok: bool = report.ok
	var col := UIKit.C_GREEN if ok else UIKit.C_RED
	var kind: String = ExpeditionFeed.KIND.get(str(report.site), "ruins")
	var tex: Texture2D = load("res://assets/exp/exp_%s.png" % kind)
	var inner := box.custom_minimum_size.x - 30.0
	var frame := media_frame(tex, col, 2 if inner >= tex.get_size().x * 2.0 + 2.0 else 1)
	_list.add_child(frame)
	var dead := (report.dead as Array).size()
	OutcomeKit.stamp(frame, "MISSION SUCCESS" if ok else ("LOST" if dead > 0 else "FAILED"),
		"ภารกิจสำเร็จ!" if ok else ("เสียคนไป..." if dead > 0 else "ภารกิจล้มเหลว..."), col, not ok)
	var odds := UIKit.label("โอกาสสำเร็จตอนออกเดินทาง %d%%" % int(float(report.get("chance", 0.0)) * 100.0), UIKit.FS_SMALL, UIKit.C_DIM)
	odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(odds)
	var rows := []
	# what the team carried home; storage that was already full keeps only part of it
	var gain: Dictionary = report.get("gain", {})
	var want: Dictionary = report.get("want", {})
	var keys: Array = want.keys()
	for k in gain:
		if not keys.has(k):
			keys.append(k)
	for k in keys:
		var n := int(want.get(k, gain.get(k, 0)))
		if n == 0:
			continue
		var kept := int(gain.get(k, 0))
		var nm := Data.item_name(str(k))
		if kept < n:
			nm += " (คลังเต็ม เก็บได้ %d)" % kept
		rows.append({"icon": Data.item_icon(str(k)), "name": nm, "n": n})
	if int(report.get("gear", 0)) > 0:
		rows.append({"icon": "chest", "name": "อุปกรณ์", "n": int(report.gear)})
	var crew := []
	for c in report.get("crew", []):
		var tags := []
		if c.dead:
			tags.append(["KIA", UIKit.C_RED])
		else:
			if int(c.hp) != 0:
				tags.append(["%+d HP" % int(c.hp), UIKit.C_GREEN if int(c.hp) > 0 else UIKit.C_RED])
			if int(c.inf) > 0:
				tags.append(["+%d INF" % int(c.inf), UIKit.C_ORANGE])
			if tags.is_empty():
				tags.append(["OK", UIKit.C_GREEN])
		crew.append({"d": c, "tags": tags})
	var delay := OutcomeKit.lists(_list, rows, crew, col, "ของที่ขนกลับมา", 0.35)
	# gear names, blueprints, recruits only live in the text line
	_list.add_child(UIKit.wrap_label("ได้รับ: " + str(report.loot).trim_prefix(", "), UIKit.FS_SMALL, UIKit.C_DIM))
	var enc: Dictionary = report.get("enc", {})
	if not enc.is_empty():
		var rp := UIKit.panel(Color("14100a"), UIKit.C_GOLD)
		var rv := UIKit.vbox(2)
		rp.add_child(rv)
		var eh := UIKit.hbox(4)
		eh.add_child(UIKit.icon_rect("signal", 16))
		eh.add_child(UIKit.header("RADIO", "จุดพิเศษ: " + str(Encounter.def(str(enc.id)).th), UIKit.C_GOLD))
		rv.add_child(eh)
		rv.add_child(UIKit.wrap_label("\"%s\"" % str(enc.text), UIKit.FS_SMALL, UIKit.C_TEXT))
		_list.add_child(rp)
		OutcomeKit.fade_in(rp, delay)
		delay += 0.1
	for line in report.lines:
		if not enc.is_empty() and str(line).begins_with("จุดพิเศษ"):
			continue
		if str(line).contains("บาดเจ็บ (HP") or str(line).contains("ติดเชื้อ!"):
			continue   # shown on the crew chips
		_list.add_child(UIKit.wrap_label("• " + str(line), UIKit.FS_SMALL, UIKit.C_ORANGE))
	if dead > 0:
		_list.add_child(UIKit.wrap_label("ชื่อของพวกเขาถูกสลักไว้บนกำแพงอนุสรณ์ในสมุดบันทึก", UIKit.FS_SMALL, UIKit.C_DIM))
	var ok_b := UIKit.button("ตกลง", "green" if ok else "red", "play")
	ok_b.custom_minimum_size.y = 32
	ok_b.pressed.connect(func():
		report = {}
		close())
	_list.add_child(ok_b)
	OutcomeKit.fade_in(ok_b, delay)
	if not ok:
		get_tree().call_group("shake", "shake", 4.0)
