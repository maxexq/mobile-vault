class_name EnginePanel
extends ModalPanel
## Engine menu (v4.6): opened by tapping the engine room in the cab.
## Tabs: สถานะ (gauges, drive mode, auto-rest, crew) · เครื่องยนต์ (swap engines) · ซ่อมบำรุง (jobs).
## The gauges update in place every frame; buttons are only rebuilt on refresh().

var tab := "status"   # status | engines | jobs
var _tabs: HBoxContainer
var _list: VBoxContainer
var _art: TextureRect
var _bars := {}        # key -> [ProgressBar, Label]
var _info: Label
var _warn: Label
var _job_lbl: Label
var _job_bar: ProgressBar
var _job_btns := {}    # job id -> Button


func _build() -> void:
	set_title("ENGINE BAY / ห้องเครื่องยนต์")
	_tabs = UIKit.hbox(3)
	body.add_child(_tabs)
	_list = make_list(4)
	EngineBay.engine_changed.connect(func(): if is_open: refresh())
	Game.gear_changed.connect(func(): if is_open and tab == "engines": refresh())
	Game.dwellers_changed.connect(func(): if is_open and tab == "status": refresh())


func refresh() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_bars = {}
	_job_btns = {}
	_job_lbl = null
	_job_bar = null
	_info = null
	_warn = null
	_art = null
	for tb in [["status", "สถานะ"], ["engines", "เครื่องยนต์"], ["jobs", "ซ่อมบำรุง"]]:
		var b := UIKit.button(tb[1], "yellow" if tab == tb[0] else "gray")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = tb[0]
		b.pressed.connect(func():
			tab = key
			refresh())
		_tabs.add_child(b)
	var et := EngineBay.t()
	set_title("%s / ห้องเครื่อง Lv.%d · %s" % [et.en, EngineBay.level(), et.th])
	match tab:
		"status": _build_status()
		"engines": _build_engines()
		"jobs": _build_jobs()
	_update()


# ------------------------------------------------------------------ status
func _build_status() -> void:
	var top := UIKit.hbox(6)
	_art = UIKit.tex_rect(Atlas.tex("eng_" + EngineBay.type_id()), Vector2(112, 80))
	top.add_child(_art)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_TEXT)
	v.add_child(_info)
	_warn = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_RED)
	v.add_child(_warn)
	top.add_child(v)
	_list.add_child(top)
	for g in [["heat", "ความร้อน", UIKit.C_ORANGE], ["cond", "สภาพเครื่อง", UIKit.C_GREEN], ["oil", "น้ำมันเครื่อง", UIKit.C_GOLD],
			["coolant", "น้ำหล่อเย็น", UIKit.C_BLUE], ["db", "เสียง", UIKit.C_RED]]:
		var row := UIKit.vbox(0)
		var lbl := UIKit.label("", UIKit.FS_SMALL, UIKit.C_TEXT)
		row.add_child(lbl)
		var bar := UIKit.progress(g[2], 5)
		row.add_child(bar)
		_list.add_child(row)
		_bars[g[0]] = [bar, lbl, g[1]]
	# drive mode
	_list.add_child(UIKit.header("DRIVE MODE", "โหมดขับ"))
	var modes := UIKit.hbox(3)
	for m in EngineBay.MODE_ORDER:
		if m == "silent" and not EngineBay.t().get("silent", false):
			continue
		var md: Dictionary = EngineBay.MODES[m]
		var b := UIKit.button(md.th, "yellow" if EngineBay.mode() == m else "gray")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mk: String = m
		b.pressed.connect(func(): EngineBay.set_mode(mk))
		modes.add_child(b)
	_list.add_child(modes)
	var mdd: Dictionary = EngineBay.MODES[EngineBay.mode()]
	_list.add_child(UIKit.wrap_label("ความเร็ว x%.2f · เชื้อเพลิง x%.1f · เสียง %+d dB · ความร้อน x%.1f" % [mdd.speed, mdd.fuel, int(mdd.db), mdd.heat]))
	# auto-rest
	var e := EngineBay.st()
	var ar := UIKit.hbox(3)
	var tog := UIKit.button("พักเครื่องอัตโนมัติ: %s" % ("เปิด" if bool(e.auto_rest) else "ปิด"), "green" if bool(e.auto_rest) else "red")
	tog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tog.pressed.connect(func():
		e.auto_rest = not bool(e.auto_rest)
		refresh())
	ar.add_child(tog)
	for at in [100.0, 110.0]:
		var bt := UIKit.button("%d°C" % int(at), "yellow" if is_equal_approx(float(e.rest_at), at) else "gray")
		var a: float = at
		bt.pressed.connect(func():
			e.rest_at = a
			refresh())
		ar.add_child(bt)
	_list.add_child(ar)
	var rest := UIKit.button("จอดพักเครื่องตอนนี้" if not EngineBay.resting() else "กำลังพักเครื่อง…", "orange", "pause")
	rest.disabled = EngineBay.resting()
	rest.pressed.connect(func():
		e.resting = true
		EngineBay._changed())
	_list.add_child(rest)
	_list.add_child(UIKit.wrap_label("ปิดพักอัตโนมัติ = ขับต่อได้จนถึง %d°C แล้วเครื่องดับเอง (เสียสภาพ -5%%) · ตอนออฟไลน์จะพักเสมอ" % int(EngineBay.STALL_AT)))
	# crew
	var cw := EngineBay.crew()
	_list.add_child(UIKit.header("MECHANICS", "ช่างในห้องเครื่อง %d/%d" % [Game.room_occupants(Data.CAB_SLOT).size(), Data.CAB_WORKERS]))
	if cw.is_empty():
		_list.add_child(UIKit.wrap_label("ยังไม่มีช่าง: ส่งลูกเรือ STR สูงหรือช่างเครื่องมาประจำ (หน้าลูกเรือ > ย้ายห้อง) ช่วยระบายร้อน เติมน้ำหล่อเย็น และซ่อมเครื่อง", UIKit.FS_SMALL, UIKit.C_GOLD))
	for d in cw:
		_list.add_child(UIKit.label("• %s  STR %d%s" % [d.name, int(d.str), "  (ช่างเครื่อง)" if Crew.has(d, "mechanic") else ""], UIKit.FS_SMALL, UIKit.C_TEXT))


# ------------------------------------------------------------------ engines
func _build_engines() -> void:
	var cap := int(EngineBay.MAX_SIZE.get(Game.tier(), 3))
	_list.add_child(UIKit.wrap_label("ห้องเครื่องของ%s รับเครื่องได้ถึงขนาด %s · เครื่องหาได้จากของดรอป/สำรวจ" % [Game.vehicle_def().th, EngineBay.SIZE_TH[cap]], UIKit.FS_SMALL, UIKit.C_TEXT))
	var cur := Loot.van_equipped("engine")
	_list.add_child(_engine_card({}, "diesel4", cur.is_empty()))
	for it in EngineBay.owned_engines():
		_list.add_child(_engine_card(it, EngineBay.type_of(it), not cur.is_empty() and int(it.uid) == int(cur.uid)))


func _engine_card(item: Dictionary, id: String, installed: bool) -> Control:
	var d: Dictionary = EngineBay.TYPES.get(id, EngineBay.TYPES.diesel4)
	var fits := item.is_empty() or EngineBay.fits(item)
	var p := UIKit.panel(UIKit.C_BG2, UIKit.C_GOLD if installed else UIKit.C_LINE_DARK)
	var h := UIKit.hbox(4)
	p.add_child(h)
	var art := UIKit.tex_rect(Atlas.tex("eng_" + id), Vector2(56, 40))
	if not fits:
		art.modulate = Color(0.4, 0.4, 0.4)
	h.add_child(art)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := UIKit.label(d.th if item.is_empty() else Loot.item_name(item), UIKit.FS_SMALL, UIKit.C_TEXT if item.is_empty() else Loot.rar_color(item))
	v.add_child(name_l)
	var parts := []
	for kv in EngineBay.describe_type(id).slice(1):
		parts.append("%s %s" % kv)
	v.add_child(UIKit.wrap_label("ขนาด %s · %s" % [EngineBay.SIZE_TH[int(d.size)], " · ".join(parts)]))
	v.add_child(UIKit.wrap_label(str(d.desc), UIKit.FS_SMALL, UIKit.C_DIM))
	h.add_child(v)
	var b: Button
	if installed:
		b = UIKit.button("ใช้อยู่", "yellow", "", 64)
		b.disabled = true
	elif not fits:
		b = UIKit.button("ใหญ่เกิน", "gray", "", 64)
		b.disabled = true
	else:
		b = UIKit.button("ติดตั้ง", "green", "wrench", 64)
		if item.is_empty():
			b.pressed.connect(func(): EngineBay.uninstall())
		else:
			var uid := int(item.uid)
			b.pressed.connect(func(): Loot.equip_from_stash(uid))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return p


# ------------------------------------------------------------------ jobs
func _build_jobs() -> void:
	_job_lbl = UIKit.label("", UIKit.FS_SMALL, UIKit.C_GOLD)
	_list.add_child(_job_lbl)
	_job_bar = UIKit.progress(UIKit.C_GOLD, 5)
	_list.add_child(_job_bar)
	_list.add_child(UIKit.wrap_label("ช่างในห้องเครื่องทำงานเร็วขึ้น (STR / ช่างเครื่อง) · งานที่มี [จอด] จะหยุดรถจนเสร็จ"))
	for id in ["coolant", "oil", "tune", "overhaul", "bay"]:
		var jd: Dictionary = EngineBay.JOBS[id]
		var p := UIKit.panel()
		var h := UIKit.hbox(4)
		p.add_child(h)
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := str(jd.th) + (" Lv.%d" % (EngineBay.level() + 1) if id == "bay" else "") + (" [จอด]" if bool(jd.park) else "")
		v.add_child(UIKit.wrap_label(title, UIKit.FS_SMALL, UIKit.C_TEXT))
		v.add_child(UIKit.wrap_label("%s · %d วินาที" % [_cost_text(EngineBay.job_cost(id)), int(EngineBay.job_time(id))]))
		v.add_child(UIKit.wrap_label(_job_desc(id), UIKit.FS_SMALL, UIKit.C_DIM))
		h.add_child(v)
		var b := UIKit.button("เริ่ม", "green", "wrench", 64)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var jid: String = id
		b.pressed.connect(func(): EngineBay.start_job(jid))
		h.add_child(b)
		_job_btns[id] = b
		_list.add_child(p)


func _job_desc(id: String) -> String:
	match id:
		"coolant": return "หม้อน้ำเต็ม: ระบายร้อนได้ปกติ (หมด = ระบายร้อนได้ครึ่งเดียว)"
		"oil": return "น้ำมันเครื่องเต็ม (ต่ำกว่า 20% เครื่องสึกเร็ว x2)"
		"tune": return "+20% สภาพเครื่อง ทำได้ระหว่างขับ"
		"overhaul": return "สภาพ 100% + น้ำมันเครื่องเต็ม"
		"bay": return "ไฟจากไดชาร์จ +25% ต่อเลเวล · เครื่องเสียงดังขึ้นเล็กน้อย"
	return ""


func _cost_text(c: Dictionary) -> String:
	return "ฟรี" if c.is_empty() else Game.cost_text(c)


# ------------------------------------------------------------------ live update
func _process(_d: float) -> void:
	if is_open:
		_update()


func _update() -> void:
	if Game.s.is_empty():
		return
	var e := EngineBay.st()
	if _info:
		var burn := EngineBay.burn_pm()
		var bt := []
		for k in burn:
			bt.append("%s %.1f/นาที" % [Data.item_name(k), float(burn[k])])
		_info.text = "อากาศ %d°C · ขับต่อจะนิ่งที่ %d°C\nความเร็ว x%.2f · แรงลาก x%.2f\nไฟให้ห้อง +%.1f/นาที · กิน %s\nเสียงเพิ่ม Threat %.2f/นาที" % [
			int(EngineBay.ambient()), int(EngineBay.settle_temp()), EngineBay.speed_mult(), EngineBay.tow_mult(),
			EngineBay.power_pm(), ", ".join(bt) if not bt.is_empty() else "-", 0.12 * Game.speed_kmh() * EngineBay.noise_mult() + EngineBay.smoke_pm()]
		var w := []
		if EngineBay.resting():
			w.append("จอดพักเครื่อง รอเย็นถึง %d°C" % int(EngineBay.RESUME_AT))
		if EngineBay.heat() >= EngineBay.HOT:
			w.append("เครื่องร้อน!")
		if EngineBay.cond() < EngineBay.BREAK_BELOW:
			w.append("สภาพต่ำ เสี่ยงดับกลางทาง")
		if float(e.oil) < 20.0:
			w.append("น้ำมันเครื่องใกล้หมด")
		if float(e.coolant) <= 0.0:
			w.append("น้ำหล่อเย็นหมด")
		if EngineBay.starved():
			w.append("เชื้อเพลิงหมด!")
		_warn.text = " · ".join(w)
	for k in _bars:
		var bar: ProgressBar = _bars[k][0]
		var lbl: Label = _bars[k][1]
		var name: String = _bars[k][2]
		match k:
			"heat":
				bar.value = clampf((EngineBay.heat() - 0.0) / EngineBay.STALL_AT, 0.0, 1.0)
				lbl.text = "%s %d°C (พักที่ %d · ดับที่ %d)" % [name, int(EngineBay.heat()), int(e.rest_at), int(EngineBay.STALL_AT)]
				lbl.modulate = UIKit.C_RED if EngineBay.heat() >= EngineBay.HOT else Color.WHITE
			"db":
				bar.value = clampf((EngineBay.db() - 30.0) / 90.0, 0.0, 1.0)
				lbl.text = "%s %d dB" % [name, int(EngineBay.db())]
			_:
				bar.value = float(e.get(k, 100.0)) / 100.0
				lbl.text = "%s %d%%" % [name, int(float(e.get(k, 100.0)))]
	if _job_lbl:
		var j: Dictionary = e.get("job", {})
		if j.is_empty():
			_job_lbl.text = "ไม่มีงานค้าง"
			_job_bar.value = 0.0
		else:
			_job_lbl.text = "กำลัง%s… เหลือ %d วินาที" % [str(EngineBay.JOBS[str(j.id)].th), int(ceil(EngineBay.job_left_sec()))]
			_job_bar.value = 1.0 - float(j.left) / maxf(float(j.total), 0.01)
		for id in _job_btns:
			var why := EngineBay.job_block(id)
			(_job_btns[id] as Button).disabled = why != ""
			(_job_btns[id] as Button).tooltip_text = why
