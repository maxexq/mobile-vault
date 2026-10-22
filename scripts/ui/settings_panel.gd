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


func _build() -> void:
	set_title("SETTINGS / ตั้งค่า")
	_tabs = UIKit.hbox(3)
	body.add_child(_tabs)
	_list = make_list(4)
	_note = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_GOLD)
	_note.visible = false
	body.add_child(_note)
	Settings.changed.connect(func(_k): _sync())
	Settings.import_failed.connect(func(why): _say(why, UIKit.C_RED))


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


func _toggle(th: String, key: String, hint: String = "") -> void:
	_choice(th, key, [[true, "เปิด"], [false, "ปิด"]], hint)


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
	_head("AUDIO", "เสียง")
	_volume("เสียงรวม", "master")
	_volume("ดนตรี", "music")
	_volume("เอฟเฟกต์", "sfx")
	_toggle("ปิดเสียงทั้งหมด", "mute", "เกมยังไม่มีเสียงในเวอร์ชันนี้ ค่าที่ตั้งไว้จะใช้ทันทีเมื่อเพิ่มเสียงเข้ามา")

	_head("LANGUAGE", "ภาษา")
	var langs := []
	for l in Settings.LANGS:
		langs.append([l[0], l[1], l[2]])
	_choice("ภาษา", "lang", langs, "ตอนนี้มีภาษาไทยเท่านั้น ภาษาอังกฤษจะตามมา")

	_head("DISPLAY", "การแสดงผล")
	_choice("ขนาดพิกเซล", "ui_scale", [["auto", "ใหญ่"], ["small", "เล็ก"]], "เล็ก = ย่อลงหนึ่งขั้น เห็นพื้นที่มากขึ้น ภาพยังคมเต็มเม็ด")
	_choice("มุมกล้อง", "zoom", [["auto", "AUTO"], ["wide", "กว้าง"], ["normal", "ปกติ"]], "AUTO จะถอยกล้องเองตอนสู้บอสหรือลากโบกี้")
	_toggle("ฟิลเตอร์จอ CRT", "crt")
	_choice("เอฟเฟกต์อนุภาค", "fx_gpu", [[true, "GPU"], [false, "CPU"]], "เลือก CPU ถ้าเครื่องช้าหรือเครื่องเก่า")
	_choice("เฟรมเรต", "fps", [[60, "60"], [30, "30"]], "30 FPS ช่วยประหยัดแบตเตอรี่")
	_toggle("เต็มจอ", "fullscreen", "บน iPhone (Safari) ให้ใช้ แชร์ > เพิ่มไปยังหน้าจอโฮม แทน")

	_head("FEEL", "ความรู้สึก")
	_toggle("จอสั่น", "shake")
	_toggle("เลือดและชิ้นส่วน", "gore", "ปิดแล้วศัตรูจะสลายไปโดยไม่มีเลือดกระเด็น")
	_toggle("สั่นเครื่อง", "vibrate", "สั่นสั้นๆ ตอนโดนโจมตีหนัก (Safari ไม่รองรับ)")

	_head("TUTORIAL", "บทแนะนำ")
	var tb := _action("ดูบทแนะนำอีกครั้ง", "blue", "book", func():
		close()
		Tutorial.restart())
	tb.disabled = not Game.started
	if not Game.started:
		_list.add_child(UIKit.wrap_label("เริ่มเกมก่อนแล้วค่อยเปิดบทแนะนำ", UIKit.FS_SMALL, UIKit.C_DIM))
	_action("คืนค่าตั้งค่าเริ่มต้น", "gray", "cog", func():
		Settings.reset_defaults()
		_say("คืนค่าตั้งค่าทั้งหมดแล้ว"))


func _tab_data() -> void:
	_head("SAVE", "ข้อมูลเซฟ")
	var d := Save.read()
	if d.is_empty():
		_list.add_child(UIKit.wrap_label("ยังไม่มีเซฟในเครื่องนี้", UIKit.FS, UIKit.C_TEXT))
	else:
		var at := int(float(d.get("saved_at", 0)))
		var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
		_info("SAVED", Time.get_datetime_string_from_unix_time(at + bias, true) if at > 0 else "-")
		_info("SIZE", "%.1f KB" % (JSON.stringify(d).length() / 1024.0))
		_info("RUN", "รุ่นที่ %d · Vault %d · %.1f กม." % [int(d.get("meta", {}).get("gen", 1)), int(d.get("vault_level", 1)), float(d.get("stats", {}).get("km_total", d.get("km", 0.0)))])
		_info("STORE", "localStorage ของเบราว์เซอร์" if OS.has_feature("web") else ProjectSettings.globalize_path(Save.FILE_PATH))
	_list.add_child(UIKit.wrap_label("เกมเซฟเองทุก 15 วินาที และตอนสลับแอป เซฟอยู่ในเบราว์เซอร์นี้เท่านั้น ถ้าล้างข้อมูลเว็บ เซฟจะหาย ควรส่งออกไฟล์เก็บไว้", UIKit.FS_SMALL, UIKit.C_DIM))
	var sb := _action("บันทึกตอนนี้", "green", "chest", func():
		Game.save_game()
		_say("บันทึกแล้ว"))
	sb.disabled = not Game.started
	var eb := _action("ส่งออกเซฟเป็นไฟล์", "blue", "up", func():
		var where := Settings.export_save()
		_say(("ส่งออกแล้ว: " + where) if where != "" else "ไม่มีเซฟให้ส่งออก", UIKit.C_GOLD if where != "" else UIKit.C_RED))
	eb.disabled = d.is_empty() and not Game.started
	_action("นำเข้าเซฟจากไฟล์", "blue", "book", func():
		_say("เลือกไฟล์ .json ที่ส่งออกไว้ เซฟปัจจุบันจะถูกแทนที่")
		Settings.begin_import())

	_head("DANGER", "ล้างความคืบหน้า")
	_list.add_child(UIKit.wrap_label("ลบรถ ลูกเรือ ของ และรุ่นทั้งหมด แล้วกลับไปหน้าแรก ย้อนคืนไม่ได้ (ค่าตั้งค่ายังอยู่)", UIKit.FS_SMALL, UIKit.C_DIM))
	_reset_btn = _action("รีเซ็ตความคืบหน้า", "red", "skull", _on_reset_pressed)
	_reset_btn.disabled = d.is_empty() and not Game.started


func _on_reset_pressed() -> void:
	if _reset_t <= 0.0:
		_reset_t = RESET_CONFIRM_SEC
		_say("แตะปุ่มแดงอีกครั้งภายใน %d วินาทีเพื่อยืนยัน" % int(RESET_CONFIRM_SEC), UIKit.C_RED)
		return
	_reset_t = 0.0
	Settings.reset_progress()


func _process(delta: float) -> void:
	if _reset_t <= 0.0 or _reset_btn == null:
		return
	_reset_t -= delta
	if _reset_t <= 0.0:
		_reset_btn.text = "รีเซ็ตความคืบหน้า"
		_say("")
	else:
		_reset_btn.text = "ยืนยันลบทั้งหมด (%d)" % int(ceilf(_reset_t))


func _extra_rows() -> Array:
	var out := []
	var d: Dictionary = Game.s if Game.started else Save.read()
	if not d.is_empty():
		out.append(["SAVE FMT", "v%d · route %d · slots %d" % [int(d.get("version", 1)), int(d.get("route_v", 1)), int(d.get("slots_v", 1))]])
	out.append(["SESSION", Trace.session])
	return out


func _tab_about() -> void:
	var head := UIKit.hbox(6)
	head.add_child(UIKit.icon_rect("emblem", 24))
	var hv := UIKit.vbox(0)
	hv.add_child(UIKit.label("MOBILE VAULT", 18, UIKit.C_LINE, true))
	hv.add_child(UIKit.label("PROJECT: SURVIVAL · v" + BuildInfo.GAME_VERSION, UIKit.FP, UIKit.C_GOLD, true))
	head.add_child(hv)
	_list.add_child(head)
	_head("VERSION", "ข้อมูลเวอร์ชัน")
	for r in BuildInfo.rows() + _extra_rows():
		_info(str(r[0]), str(r[1]))
	_action("คัดลอกข้อมูลสำหรับแจ้งบั๊ก", "blue", "book", func():
		DisplayServer.clipboard_set(BuildInfo.as_text(_extra_rows()))
		_say("คัดลอกแล้ว วางในข้อความแจ้งบั๊กได้เลย"))
	_action("ดาวน์โหลด log การเล่น", "gray", "chest", func():
		_say("บันทึก log แล้ว: " + Trace.download()))
	_head("CREDITS", "เครดิต")
	_list.add_child(UIKit.wrap_label("สร้างด้วย Godot Engine (MIT License) · ฟอนต์ Chakra Petch และ Silkscreen (SIL Open Font License) · ภาพพิกเซลทั้งหมดวาดขึ้นเองสำหรับเกมนี้", UIKit.FS_SMALL, UIKit.C_DIM))
