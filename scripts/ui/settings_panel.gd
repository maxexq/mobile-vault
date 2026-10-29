class_name SettingsPanel
extends ModalPanel
## Settings terminal, reachable from the title menu and the gear button on the HUD.
##  tabs: ตั้งค่า (audio, language, display, feel, tutorial) · เซฟ (save / export / import / reset)
##        · เกี่ยวกับ (game + engine + build versions, copy for bug reports, credits)
## Each tab is built once when shown; rows keep a sync callable so a change updates labels in place
## (no rebuild -> the scroll position stays where the player left it).

const TABS := [["game", "ตั้งค่า"], ["data", "เซฟ"], ["about", "เกี่ยวกับ"]]
const RESET_CONFIRM_SEC := 4.0

var tab := "game"
var _tabs: HBoxContainer
var _list: VBoxContainer
var _syncs: Array[Callable] = []
var _reset_btn: Button
var _reset_t := 0.0
var _note: Label
var _shown_conflict := false


func _build() -> void:
	set_title(Loc.t("SETTINGS / ตั้งค่า"))
	_tabs = UIKit.hbox(3)
	body.add_child(_tabs)
	_list = make_list(4)
	_note = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_GOLD)
	_note.visible = false
	body.add_child(_note)
	Settings.changed.connect(func(_k): _sync())
	Settings.import_failed.connect(func(why): _say(why, UIKit.C_RED))
	Settings.import_ready.connect(_confirm_import)
	Cloud.account_changed.connect(func():
		if is_open and tab == "data":
			refresh())
	Cloud.status_changed.connect(func():
		# the conflict choice adds/removes buttons, so that change rebuilds the tab; the rest updates labels
		if is_open and tab == "data":
			if (Cloud.state == Cloud.State.CONFLICT) != _shown_conflict:
				refresh()
			else:
				_sync())


func open_tab(t: String) -> void:
	tab = t
	if is_open:
		refresh()
	else:
		open()


func refresh() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_syncs.clear()
	_reset_btn = null
	_reset_t = 0.0
	_note.visible = false
	for t in TABS:
		var key: String = t[0]
		var b := UIKit.button(t[1], "yellow" if tab == key else "gray")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			tab = key
			refresh())
		_tabs.add_child(b)
	_shown_conflict = Cloud.state == Cloud.State.CONFLICT
	match tab:
		"game": _tab_game()
		"data": _tab_data()
		"about": _tab_about()
	_sync()


func _sync() -> void:
	if not is_open:
		return
	for f in _syncs:
		f.call()


func _say(text: String, col: Color = UIKit.C_GOLD) -> void:
	_note.text = text
	_note.add_theme_color_override("font_color", col)
	_note.visible = text != ""


# ------------------------------------------------------------------ row builders
func _head(en: String, th: String) -> void:
	_list.add_child(UIKit.header(en, th))


## label (+ optional hint below) on the left, controls on the right
func _row(th: String, hint: String = "") -> HBoxContainer:
	var p := UIKit.panel()
	var v := UIKit.vbox(1)
	p.add_child(v)
	var h := UIKit.hbox(3)
	var l := UIKit.label(th, UIKit.FS_SMALL, UIKit.C_TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	v.add_child(h)
	if hint != "":
		v.add_child(UIKit.wrap_label(hint, UIKit.FS_SMALL, UIKit.C_DIM))
	_list.add_child(p)
	return h


## segmented choice: [[value, caption, enabled?], ...]; the selected one is amber
func _choice(th: String, key: String, opts: Array, hint: String = "") -> void:
	var h := _row(th, hint)
	var btns := []
	for o in opts:
		var val = o[0]
		var b := UIKit.button(str(o[1]), "gray")
		b.custom_minimum_size = Vector2(34, 22)
		b.add_theme_font_size_override("font_size", UIKit.FS_SMALL)
		b.disabled = o.size() > 2 and not bool(o[2])
		b.pressed.connect(func(): Settings.set_value(key, val))
		h.add_child(b)
		btns.append([b, val])
	_syncs.append(func():
		for e in btns:
			var on: bool = Settings.get_value(key) == e[1]
			UIKit.style_button(e[0], "yellow" if on else "gray"))


## difficulty of the account's vehicle: a setting, not a run rule (Account.set_diff)
func _difficulty() -> void:
	var h := _row(Loc.t("ความยาก"), Loc.t("เปลี่ยนได้ทุกเมื่อ มีผลทันที · ยากขึ้น = ศัตรูแรงขึ้น กินมากขึ้น ได้แต้มวิจัยพันธุกรรมมากขึ้น"))
	var btns := []
	for k in Modes.DIFFS:
		var did: String = k
		var b := UIKit.button(Loc.t(str(Modes.DIFFS[k].th)), "gray")
		b.custom_minimum_size = Vector2(34, 22)
		b.add_theme_font_size_override("font_size", UIKit.FS_SMALL)
		b.pressed.connect(func(): Account.set_diff(did))
		h.add_child(b)
		btns.append([b, did])
	_syncs.append(func():
		for e in btns:
			UIKit.style_button(e[0], "yellow" if Account.diff() == e[1] else "gray"))


func _toggle(th: String, key: String, hint: String = "") -> void:
	_choice(th, key, [[true, Loc.t("เปิด")], [false, Loc.t("ปิด")]], hint)


## 0..100% in 10% steps: [-] tappable meter [+] 70%
func _volume(th: String, key: String) -> void:
	var h := _row(th)
	var minus := UIKit.button("-", "gray")
	minus.custom_minimum_size = Vector2(26, 22)
	minus.pressed.connect(func(): _step_volume(key, -0.1))
	h.add_child(minus)
	var bar := UIKit.progress(UIKit.C_GOLD, 8)
	bar.custom_minimum_size = Vector2(64, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Settings.set_value(key, snappedf(clampf(e.position.x / maxf(1.0, bar.size.x), 0.0, 1.0), 0.1)))
	h.add_child(bar)
	var plus := UIKit.button("+", "gray")
	plus.custom_minimum_size = Vector2(26, 22)
	plus.pressed.connect(func(): _step_volume(key, 0.1))
	h.add_child(plus)
	var pct := UIKit.label("", UIKit.FP, UIKit.C_GOLD, true)
	pct.custom_minimum_size.x = 30
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pct)
	_syncs.append(func():
		var val := float(Settings.get_value(key))
		var muted := bool(Settings.get_value("mute"))
		bar.value = val
		bar.modulate = Color(1, 1, 1, 0.4) if muted else Color.WHITE
		pct.text = "%d%%" % int(round(val * 100.0)))


func _step_volume(key: String, d: float) -> void:
	Settings.set_value(key, snappedf(clampf(float(Settings.get_value(key)) + d, 0.0, 1.0), 0.1))


func _action(text: String, color: String, icon: String, cb: Callable) -> Button:
	var b := UIKit.button(text, color, icon)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	_list.add_child(b)
	return b


func _info(key: String, value: String) -> HBoxContainer:
	var h := UIKit.hbox(4)
	var k := UIKit.label(key, UIKit.FP, UIKit.C_DIM, true)
	k.custom_minimum_size.x = 70
	h.add_child(k)
	var v := UIKit.label(value, UIKit.FS_SMALL, UIKit.C_TEXT)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.custom_minimum_size.x = 40
	h.add_child(v)
	_list.add_child(h)
	return h


# ------------------------------------------------------------------ tabs
func _tab_game() -> void:
	if Game.started and not Game.s.is_empty():
		_head("DIFFICULTY", Loc.t("ความยาก"))
		_difficulty()

	_head("AUDIO", Loc.t("เสียง"))
	_volume(Loc.t("เสียงรวม"), "master")
	_volume(Loc.t("ดนตรี"), "music")
	_volume(Loc.t("บรรยากาศ"), "ambience")
	_volume(Loc.t("เอฟเฟกต์"), "sfx")
	_volume(Loc.t("ปุ่มกด"), "ui")
	_toggle(Loc.t("ปิดเสียงทั้งหมด"), "mute", Loc.t("บรรยากาศ = เสียงพื้นที่ เครื่องยนต์ ฝนและพายุ · บนเว็บเสียงเริ่มหลังแตะจอครั้งแรก"))

	_head("LANGUAGE", Loc.t("ภาษา"))
	var langs := []
	for l in Settings.LANGS:
		langs.append([l[0], l[1], l[0] == "th" or Features.on("english")])
	_choice(Loc.t("ภาษา"), "lang", langs, Loc.t("ภาษาอังกฤษยังแปลไม่ครบ ส่วนที่ยังไม่แปลจะแสดงเป็นภาษาไทย"))

	_head("DISPLAY", Loc.t("การแสดงผล"))
	_choice(Loc.t("ขนาดพิกเซล"), "ui_scale", [["auto", Loc.t("ใหญ่")], ["small", Loc.t("เล็ก")]], Loc.t("เล็ก = ย่อลงหนึ่งขั้น เห็นพื้นที่มากขึ้น ภาพยังคมเต็มเม็ด"))
	_choice(Loc.t("มุมกล้อง"), "zoom", [["auto", "AUTO"], ["wide", Loc.t("กว้าง")], ["normal", Loc.t("ปกติ")]], Loc.t("AUTO จะถอยกล้องเองตอนสู้บอสหรือลากโบกี้"))
	_toggle(Loc.t("ฟิลเตอร์จอ CRT"), "crt")
	_choice(Loc.t("เอฟเฟกต์อนุภาค"), "fx_gpu", [[true, "GPU"], [false, "CPU"]], Loc.t("เลือก CPU ถ้าเครื่องช้าหรือเครื่องเก่า"))
	_choice(Loc.t("เฟรมเรต"), "fps", [[30, "30"], [60, "60"], [120, "120"]], Loc.t("30 FPS ประหยัดแบตเตอรี่ · 120 FPS ลื่นสุดบนจอ 120Hz (จอ 60Hz จะได้ 60)"))
	_toggle(Loc.t("เต็มจอ"), "fullscreen", Loc.t("บน iPhone (Safari) ให้ใช้ แชร์ > เพิ่มไปยังหน้าจอโฮม แทน"))

	_head("FEEL", Loc.t("ความรู้สึก"))
	_toggle(Loc.t("จอสั่น"), "shake")
	_toggle(Loc.t("รถสั่น"), "car_shake", Loc.t("ตัวรถสั่นตามเครื่องยนต์และหลุมบนถนน ปิดได้ถ้ารู้สึกเวียนหัว"))
	_toggle(Loc.t("เลือดและชิ้นส่วน"), "gore", Loc.t("ปิดแล้วศัตรูจะสลายไปโดยไม่มีเลือดกระเด็น"))
	_toggle(Loc.t("สั่นเครื่อง"), "vibrate", Loc.t("สั่นสั้นๆ ตอนโดนโจมตีหนัก (Safari ไม่รองรับ)"))

	_head("COMBAT", Loc.t("การต่อสู้"))
	_choice(Loc.t("จังหวะศัตรู"), "pacing", [["threat", Loc.t("สมจริง")], ["classic", Loc.t("คลาสสิก")]], Loc.t("สมจริง = ศัตรูบุกเป็นครั้งตามเสียง แสง และความเร็วของรถ · คลาสสิก = ศัตรูมาเป็นเวฟต่อเนื่องแบบเดิม"))
	if Features.on("event_timer"):
		_choice(Loc.t("เวลาตัดสินใจอีเว้นต์"), "event_timer", [["normal", Loc.t("ปกติ")], ["long", Loc.t("นานขึ้น x2")], ["off", Loc.t("ไม่จับเวลา")]], Loc.t("อีเว้นต์บนถนนมีเวลาจำกัด หมดเวลาลูกเรือจะเลือกทางที่ปลอดภัยเอง เวลาหยุดเดินถ้าไม่ได้แตะจอเกิน 20 วินาที"))

	_head("PRIVACY", Loc.t("ความเป็นส่วนตัว"))
	if Features.on("legal_notice"):
		_action("ข้อกำหนดและความเป็นส่วนตัว", "blue", "book", func():
			var hud := get_parent() as HUD
			hud.open_legal())
		_list.add_child(UIKit.wrap_label("ข้อมูลเสริม: บันทึกแก้ปัญหา %s · สถิติการเล่น %s" % ["เปิด" if LegalPolicy.allows("diagnostics") else "ปิด", "เปิด" if LegalPolicy.allows("analytics") else "ปิด"], UIKit.FS_SMALL, UIKit.C_DIM))
	_action("ปิดการส่งข้อมูลเสริมทั้งหมด", "gray", "close", func():
		LegalPolicy.withdraw_all()
		refresh())

	_head("TUTORIAL", Loc.t("บทแนะนำ"))
	var tb := _action(Loc.t("ดูบทแนะนำอีกครั้ง"), "blue", "book", func():
		close()
		Tutorial.restart())
	tb.disabled = not Game.started
	if not Game.started:
		_list.add_child(UIKit.wrap_label(Loc.t("เริ่มเกมก่อนแล้วค่อยเปิดบทแนะนำ"), UIKit.FS_SMALL, UIKit.C_DIM))
	if Features.on("tutorial_tips"):
		_toggle(Loc.t("คำแนะนำเมื่อเปิดระบบใหม่"), "tips", Loc.t("จ่ามาร์คจะอธิบายแต่ละระบบครั้งแรกที่เปิดหน้านั้น"))
		var rb := _action(Loc.t("แสดงคำแนะนำทุกระบบอีกครั้ง"), "gray", "book", func():
			Tutorial.reset_tips()
			_say(Loc.t("คำแนะนำจะขึ้นอีกครั้งเมื่อเปิดแต่ละระบบ")))
		rb.disabled = not Game.started
	_action(Loc.t("คืนค่าตั้งค่าเริ่มต้น"), "gray", "cog", func():
		ConfirmPanel.ask(self, Loc.t("คืนค่าตั้งค่าเริ่มต้น"), Loc.t("ค่าตั้งค่าเสียง ภาษา ภาพ และการควบคุมจะกลับเป็นค่าเริ่มต้น ความคืบหน้าเกมยังอยู่"), Loc.t("คืนค่าเริ่มต้น"), func():
			Settings.reset_defaults()
			_say(Loc.t("คืนค่าตั้งค่าทั้งหมดแล้ว"))))


func _tab_data() -> void:
	_head("SAVE", Loc.t("ข้อมูลเซฟ"))
	var d := Save.read()
	if d.is_empty():
		_list.add_child(UIKit.wrap_label(Loc.t("ยังไม่มีเซฟในเครื่องนี้"), UIKit.FS, UIKit.C_TEXT))
	else:
		var at := int(float(Account.vehicle_of(d).get("saved_at", 0)))
		var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
		_info("SAVED", Time.get_datetime_string_from_unix_time(at + bias, true) if at > 0 else "-")
		_info("SIZE", "%.1f KB" % (JSON.stringify(d).length() / 1024.0))
		var veh := Account.vehicle_of(d)
		_info("RUN", Loc.t("รุ่นที่ %d · Vault %d · %.1f กม.") % [int(Account.account_of(d).get("meta", {}).get("gen", 1)), int(veh.get("vault_level", 1)), float(veh.get("stats", {}).get("km_total", veh.get("km", 0.0)))])
		var where := Loc.t("localStorage ของเบราว์เซอร์") if OS.has_feature("web") else (ProjectSettings.globalize_path(Save.FILE_PATH) if show_tech() else Loc.t("ไฟล์ในเครื่องนี้"))
		_info("STORE", where + ((" + Supabase" if show_tech() else " + " + Loc.t("คลาวด์")) if Cloud.enabled() else ""))
	if Cloud.enabled():
		_list.add_child(UIKit.wrap_label(Loc.t("เกมเซฟลงเครื่องทุก 15 วินาที และส่งขึ้นคลาวด์ทุกนาทีเมื่อออนไลน์ ถ้าออฟไลน์จะเก็บในเครื่องไว้ก่อนแล้วส่งตามทีหลัง"), UIKit.FS_SMALL, UIKit.C_DIM))
	else:
		_list.add_child(UIKit.wrap_label(Loc.t("เกมเซฟเองทุก 15 วินาที และตอนสลับแอป เซฟอยู่ในเบราว์เซอร์นี้เท่านั้น ถ้าล้างข้อมูลเว็บ เซฟจะหาย ควรส่งออกไฟล์เก็บไว้"), UIKit.FS_SMALL, UIKit.C_DIM))
	_cloud_rows()
	var sb := _action(Loc.t("บันทึกตอนนี้"), "green", "chest", func():
		Game.save_game()
		_say(Loc.t("บันทึกแล้ว")))
	sb.disabled = not Game.started
	var eb := _action(Loc.t("ส่งออกเซฟเป็นไฟล์"), "blue", "up", func():
		var where := Settings.export_save()
		_say((Loc.t("ส่งออกแล้ว: ") + where) if where != "" else Loc.t("ไม่มีเซฟให้ส่งออก"), UIKit.C_GOLD if where != "" else UIKit.C_RED))
	eb.disabled = d.is_empty() and not Game.started
	_action(Loc.t("นำเข้าเซฟจากไฟล์"), "blue", "book", func():
		_say(Loc.t("เลือกไฟล์ .json ที่ส่งออกไว้ เซฟปัจจุบันจะถูกแทนที่"))
		Settings.begin_import())

	_head("DANGER", Loc.t("ล้างความคืบหน้า"))
	_list.add_child(UIKit.wrap_label(Loc.t("ลบไอดีนี้ทั้งหมด: รถ ลูกเรือ ของ ทุกรุ่น แต้มวิจัย และบันทึก แล้วกลับไปหน้าแรก ย้อนคืนไม่ได้ (ค่าตั้งค่ายังอยู่)"), UIKit.FS_SMALL, UIKit.C_DIM))
	_reset_btn = _action(Loc.t("รีเซ็ตความคืบหน้า"), "red", "skull", _on_reset_pressed)
	_reset_btn.disabled = d.is_empty() and not Game.started


func _cloud_rows() -> void:
	_head("CLOUD", Loc.t("คลาวด์"))
	if not Cloud.enabled():
		_info("STATUS", Cloud.status_text())
		return
	var st := _info("STATUS", "")
	var acc := _info("ACCOUNT", "")
	var pid_row: HBoxContainer = _info("PLAYER ID", "") if Features.on("player_id") else null
	var last := _info("SYNC", "")
	_syncs.append(func():
		(st.get_child(1) as Label).text = Cloud.status_text()
		(acc.get_child(1) as Label).text = Cloud.account_text(not show_tech())
		if pid_row:
			(pid_row.get_child(1) as Label).text = Cloud.player_id() if Cloud.player_id() != "" else "-"
		(last.get_child(1) as Label).text = "rev %d · %s" % [int(Cloud.meta.rev), _when(Cloud.last_sync_at) if Cloud.last_sync_at > 0 else Loc.t("ยังไม่ได้ซิงก์")])
	if pid_row and Cloud.player_id() != "":
		_action(Loc.t("คัดลอกไอดีผู้เล่น"), "gray", "book", func():
			DisplayServer.clipboard_set(Cloud.player_id())
			_say(Loc.t("คัดลอกไอดีแล้ว แนบไอดีนี้ตอนแจ้งปัญหาหรือติดต่อทีมงาน")))
	_account_rows()
	if Cloud.state == Cloud.State.CONFLICT:
		var r := Cloud.remote
		var rd: Dictionary = r.get("data", {}) if r.get("data") is Dictionary else {}
		var ld := Save.read()
		_list.add_child(UIKit.wrap_label(Loc.t("คลาวด์มีเซฟจากอีกเครื่อง (%s) ที่เครื่องนี้ยังไม่เคยเห็น เลือกเซฟที่จะเก็บไว้ อีกอันจะถูกแทนที่") % _when(float(r.get("updated_at", 0))), UIKit.FS_SMALL, UIKit.C_RED))
		_info("CLOUD", _run_text(rd))
		_info("DEVICE", _run_text(ld))
		_action(Loc.t("ใช้เซฟจากคลาวด์"), "blue", "up", func():
			ConfirmPanel.ask(self, Loc.t("ใช้เซฟจากคลาวด์"), Loc.t("เซฟในเครื่องนี้จะถูกแทนที่ด้วยเซฟคลาวด์ ย้อนคืนไม่ได้ ควรส่งออกเซฟเก็บไว้ก่อน"), Loc.t("แทนที่เซฟในเครื่อง"), Cloud.use_cloud,
				func(): return Cloud.state == Cloud.State.CONFLICT and is_same(Cloud.remote, r)))
		_action(Loc.t("ใช้เซฟเครื่องนี้ (ทับคลาวด์)"), "red", "chest", func():
			ConfirmPanel.ask(self, Loc.t("ใช้เซฟเครื่องนี้ (ทับคลาวด์)"), Loc.t("เซฟคลาวด์จะถูกแทนที่ด้วยเซฟเครื่องนี้ ความคืบหน้าจากอีกเครื่องอาจหายไป ย้อนคืนไม่ได้"), Loc.t("แทนที่เซฟคลาวด์"), func():
				await Cloud.use_local()
				refresh(), func(): return Cloud.state == Cloud.State.CONFLICT and is_same(Cloud.remote, r)))
		return
	_action(Loc.t("ซิงก์ตอนนี้"), "green", "up", func():
		if Game.started:
			Game.save_game()
		_say(Loc.t("กำลังซิงก์..."))
		await Cloud.sync()
		_say(Cloud.status_text(), UIKit.C_GOLD if Cloud.state == Cloud.State.OK else UIKit.C_RED))


## guest: link Google (keeps this save) · Google: sign out · account errors from the last attempt
func _account_rows() -> void:
	if Cloud.auth_error != "":
		_list.add_child(UIKit.wrap_label(Cloud.auth_error, UIKit.FS_SMALL, UIKit.C_RED))
	if Cloud.is_guest():
		_list.add_child(UIKit.wrap_label(Loc.t("ตอนนี้เล่นแบบ Guest เซฟผูกกับเบราว์เซอร์นี้ ล็อกอินด้วย Gmail เพื่อเก็บเซฟนี้ไว้ในบัญชี Google แล้วเล่นต่อจากเครื่องไหนก็ได้"), UIKit.FS_SMALL, UIKit.C_DIM))
		if Cloud.can_google():
			_action(Loc.t("ผูกบัญชี Gmail (เก็บเซฟนี้ไว้)") if Save.has_save() else Loc.t("ล็อกอินด้วย Gmail"), "blue", "up", func():
				_say(Loc.t("กำลังไปหน้า Google..."))
				await Cloud.sign_in_google())
			if Cloud.link_taken:
				_action(Loc.t("สลับไปบัญชี Google นั้น"), "yellow", "play", func():
					_say(Loc.t("กำลังไปหน้า Google..."))
					await Cloud.switch_to_google())
		else:
			_list.add_child(UIKit.wrap_label(Loc.t("Google ไม่ให้ล็อกอินในหน้าที่ฝังอยู่ เปิดเกมบนเว็บโดยตรงก่อน"), UIKit.FS_SMALL, UIKit.C_GOLD))
			if Cloud.site_url != "":
				_action(Loc.t("เปิดเกมในแท็บใหม่"), "blue", "up", func(): OS.shell_open(Cloud.site_url))
	else:
		_action(Loc.t("ออกจากระบบ (กลับไปเป็น Guest)"), "gray", "skull", func():
			ConfirmPanel.ask(self, Loc.t("ออกจากระบบ (กลับไปเป็น Guest)"), Loc.t("เกมจะส่งเซฟขึ้นบัญชี Google แล้วลบสำเนาในเครื่องนี้เพื่อเริ่ม Guest ใหม่ ต้องล็อกอินบัญชีเดิมเพื่อเล่นต่อ"), Loc.t("ยืนยันออกจากระบบ"), func():
				_say(Loc.t("กำลังส่งเซฟขึ้นคลาวด์ก่อนออกจากระบบ..."))
				if await Cloud.sign_out():
					_say(Loc.t("ออกจากระบบแล้ว เซฟยังอยู่ในบัญชี Google"))
				else:
					refresh()))


func _when(unix: float) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_datetime_string_from_unix_time(int(unix) + bias, true)


func _run_text(d: Dictionary) -> String:
	if d.is_empty():
		return Loc.t("ไม่มีเซฟ")
	var veh := Account.vehicle_of(d)
	return Loc.t("รุ่นที่ %d · Vault %d · %.1f กม. · %s") % [int(Account.account_of(d).get("meta", {}).get("gen", 1)), int(veh.get("vault_level", 1)), float(veh.get("stats", {}).get("km_total", veh.get("km", 0.0))), _when(float(veh.get("saved_at", 0)))]


func _on_reset_pressed() -> void:
	if Features.on("confirm_actions"):
		ConfirmPanel.ask(self, Loc.t("รีเซ็ตความคืบหน้า"), Loc.t("ลบไอดีนี้ทั้งหมด: รถ ลูกเรือ ของ ทุกรุ่น แต้มวิจัย และบันทึก แล้วกลับไปหน้าแรก ย้อนคืนไม่ได้ (ค่าตั้งค่ายังอยู่)"), Loc.t("ยืนยันลบทั้งหมด"), Settings.reset_progress)
		return
	if _reset_t <= 0.0:
		_reset_t = RESET_CONFIRM_SEC
		_say(Loc.t("แตะปุ่มแดงอีกครั้งภายใน %d วินาทีเพื่อยืนยัน") % int(RESET_CONFIRM_SEC), UIKit.C_RED)
		return
	_reset_t = 0.0
	Settings.reset_progress()


func _confirm_import(text: String) -> void:
	if not is_open:
		return
	ConfirmPanel.ask(self, Loc.t("นำเข้าเซฟจากไฟล์"), Loc.t("ไฟล์นี้จะทับรถ ลูกเรือ ของ และความคืบหน้าปัจจุบัน ย้อนคืนไม่ได้ ควรส่งออกเซฟเก็บไว้ก่อน"), Loc.t("นำเข้าและแทนที่เซฟ"), func(): Settings.apply_import(text))


func _process(delta: float) -> void:
	if _reset_t <= 0.0 or _reset_btn == null:
		return
	_reset_t -= delta
	if _reset_t <= 0.0:
		_reset_btn.text = Loc.t("รีเซ็ตความคืบหน้า")
		_say("")
	else:
		_reset_btn.text = Loc.t("ยืนยันลบทั้งหมด (%d)") % int(ceilf(_reset_t))


## MV-588: server, branch, GPU, save path and the full e-mail are for testers (GOD MODE) only
func show_tech() -> bool:
	return (Dev.unlocked and not Dev.player_view) or not Features.on("settings_privacy")


func _extra_rows() -> Array:
	var out := []
	var d: Dictionary = Game.s if Game.started else Account.vehicle_of(Save.read())
	if not d.is_empty():
		out.append(["SAVE FMT", "account v%d · v%d · route %d · slots %d" % [Account.V, int(d.get("version", 1)), int(d.get("route_v", 1)), int(d.get("slots_v", 1))]])
	if Cloud.player_id() != "":
		out.append(["PLAYER", Cloud.player_id()])
	out.append(["SESSION", Trace.session])
	return out


func _tab_about() -> void:
	_list.add_child(UIKit.logo("v" + BuildInfo.GAME_VERSION))
	_list.add_child(UIKit.channel_tag())
	_list.add_child(UIKit.env_tag())
	_head("VERSION", Loc.t("ข้อมูลเวอร์ชัน"))
	for r in BuildInfo.rows() + _extra_rows():
		if show_tech() or str(r[0]) in BuildInfo.PUBLIC_ROWS:
			_info(str(r[0]), str(r[1]))
	_action(Loc.t("คัดลอกข้อมูลสำหรับแจ้งบั๊ก"), "blue", "book", func():
		DisplayServer.clipboard_set(BuildInfo.as_text(_extra_rows(), not show_tech()))
		_say(Loc.t("คัดลอกแล้ว วางในข้อความแจ้งบั๊กได้เลย")))
	_action(Loc.t("ดาวน์โหลด log การเล่น"), "gray", "chest", func():
		_say(Loc.t("บันทึก log แล้ว: ") + Trace.download()))
	_head("CREDITS", Loc.t("เครดิต"))
	_list.add_child(UIKit.wrap_label(Loc.t("สร้างด้วย Godot Engine (MIT License) · ฟอนต์ Chakra Petch และ Silkscreen (SIL Open Font License) · ภาพพิกเซลทั้งหมดวาดขึ้นเองสำหรับเกมนี้"), UIKit.FS_SMALL, UIKit.C_DIM))
