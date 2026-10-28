class_name LogPanel
extends ModalPanel
## Logbook terminal: world chapters, records found on the road (event choices), crew dossiers.

var tab := "activity"       # activity | world | found | crew
var open_id := ""        # entry being read
var _tabs: HBoxContainer
var _list: VBoxContainer
var _type_t := 0.0
var _reader: Label
var activity_feed: ActivityFeed
var _tutorial_button: Button


func _build() -> void:
	set_title(Loc.t("LOGBOOK / สมุดบันทึก MAMMOTH-7"))
	_tabs = UIKit.hbox(3)
	body.add_child(_tabs)
	activity_feed = ActivityFeed.new()
	body.add_child(activity_feed)
	_list = make_list(3)
	var tb := UIKit.button(Loc.t("ดูบทแนะนำอีกครั้ง  TUTORIAL"), "blue", "book")
	_tutorial_button = tb
	tb.pressed.connect(func():
		close()
		Tutorial.restart())
	body.add_child(tb)
	Lore.unlocked.connect(func(_id): if is_open: refresh())
	Features.changed.connect(func(): if is_open: refresh())


func _layout() -> void:
	var vp := get_viewport_rect().size
	max_size.x = 600.0 if tab == "activity" and vp.x > vp.y else 420.0
	super._layout()


func close() -> void:
	open_id = ""
	super.close()


func refresh() -> void:
	if tab == "activity" and not Features.on("activity_log"):
		tab = "world"
	set_title("ACTIVITY LOG / บันทึกกิจกรรม" if tab == "activity" else Loc.t("LOGBOOK / สมุดบันทึก MAMMOTH-7"))
	_layout()
	activity_feed.visible = tab == "activity"
	_tutorial_button.visible = tab != "activity"
	_list.get_parent().visible = tab != "activity"
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_reader = null
	for t in [["activity", "กิจกรรม"], ["world", "โลก"], ["found", "สิ่งที่พบ"], ["crew", "ลูกเรือ"]]:
		if t[0] == "activity" and not Features.on("activity_log"):
			continue
		var b := UIKit.button(t[1], "yellow" if tab == t[0] else "gray")
		b.focus_mode = Control.FOCUS_ALL
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = t[0]
		b.pressed.connect(func():
			tab = key
			open_id = ""
			refresh())
		_tabs.add_child(b)
	if tab == "activity":
		activity_feed.refresh()
	elif open_id != "":
		_build_reader()
	elif tab == "crew":
		_build_crew()
	else:
		_build_entries()


func _build_entries() -> void:
	var n := 0
	var total := 0
	for e in Lore.entries():
		if e.cat != tab:
			continue
		total += 1
		if e.open:
			n += 1
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 26)
		b.focus_mode = Control.FOCUS_NONE
		UIKit.style_button(b, "green" if e.open else "gray")
		b.disabled = not e.open
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = ("> " + e.th) if e.open else "> ??? " + e.text
		b.add_theme_font_size_override("font_size", UIKit.FS_SMALL)
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
		var id: String = e.id
		b.pressed.connect(func():
			open_id = id
			_type_t = 0.0
			refresh())
		_list.add_child(b)
	_list.add_child(UIKit.label("RECORDS %d/%d" % [n, total], UIKit.FP, UIKit.C_DIM, true))


func _build_reader() -> void:
	var e: Dictionary = Lore.ENTRIES.get(open_id, {})
	var back := UIKit.button(Loc.t("< กลับ"), "gray")
	back.pressed.connect(func():
		open_id = ""
		refresh())
	_list.add_child(back)
	_list.add_child(UIKit.label(e.get("th", ""), UIKit.FS_BIG, UIKit.C_GOLD))
	_list.add_child(UIKit.divider(UIKit.C_LINE_DIM))
	_reader = UIKit.wrap_label("", UIKit.FS, UIKit.C_TEXT)
	_reader.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_reader.text = e.get("text", "")
	_reader.visible_characters = 0
	_list.add_child(_reader)


func _build_crew() -> void:
	var mem: Array = Game.s.get("memorial", [])
	if not mem.is_empty():
		_list.add_child(UIKit.header("MEMORIAL", Loc.t("กำแพงอนุสรณ์")))
		for e in mem:
			_list.add_child(UIKit.label(Loc.t("† %s Lv%d — %s (รุ่นที่ %d, กม. %.1f)") % [e.name, int(e.lvl), e.cause, int(e.get("gen", 1)), float(e.km)], UIKit.FS_SMALL, UIKit.C_DIM))
		_list.add_child(UIKit.header("CREW", Loc.t("ลูกเรือปัจจุบัน")))
	for d in Game.s.dwellers:
		var bio := Lore.bio(d)
		var p := UIKit.panel()
		var h := UIKit.hbox(4)
		p.add_child(h)
		h.add_child(UIKit.portrait(d.variant))
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label("%s · %s" % [d.name, bio.role], UIKit.FS_SMALL, UIKit.C_GOLD))
		v.add_child(UIKit.wrap_label(bio.text, UIKit.FS_SMALL, UIKit.C_DIM))
		h.add_child(v)
		_list.add_child(p)


func _process(delta: float) -> void:
	# typewriter effect on the open record
	if is_open and _reader and is_instance_valid(_reader) and _reader.visible_characters >= 0:
		_type_t += delta * 60.0
		_reader.visible_characters = int(_type_t)
		if _type_t >= _reader.get_total_character_count():
			_reader.visible_characters = -1
