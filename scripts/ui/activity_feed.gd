class_name ActivityFeed
extends VBoxContainer
## Stable controls; only the history rows change, and never while reading older entries.
var category := ""
var warnings_only := false
var page_size := 40
var _filter_buttons: Array[Button] = []
var _resource_labels := {}
var _resource_grid: GridContainer
var _stress: Label
var _count: Label
var _new: Button
var _older: Button
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _pending := false


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	var status := UIKit.panel(UIKit.C_BG, UIKit.C_LINE_DIM)
	var sv := UIKit.vbox(2)
	status.add_child(sv)
	sv.add_child(UIKit.label("สถานะบนรถตอนนี้", UIKit.FS_SMALL, UIKit.C_GOLD))
	var grid := GridContainer.new()
	_resource_grid = grid
	grid.columns = 3
	sv.add_child(grid)
	for key in Activity.RESOURCE_KEYS:
		var l := UIKit.label("", UIKit.FS_SMALL)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		_resource_labels[key] = l
	_stress = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_ORANGE)
	sv.add_child(_stress)
	add_child(status)
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 3)
	filters.add_theme_constant_override("v_separation", 3)
	add_child(filters)
	for f in [["", "ทั้งหมด"], ["loot", "สิ่งของ"], ["resources", "ทรัพยากร"], ["crew", "ลูกเรือ"], ["event", "เหตุการณ์"], ["warnings", "คำเตือน"]]:
		var key: String = f[0]
		var b := UIKit.button(f[1], "gray")
		b.focus_mode = Control.FOCUS_ALL
		b.set_meta("filter", key)
		b.pressed.connect(func(): select_filter(key))
		filters.add_child(b)
		_filter_buttons.append(b)
	_count = UIKit.label("", UIKit.FS_SMALL, UIKit.C_DIM)
	add_child(_count)
	_new = UIKit.button("มีรายการใหม่ · แตะเพื่อดู", "yellow")
	_new.pressed.connect(func():
		_scroll.scroll_vertical = 0
		_rebuild())
	_new.visible = false
	add_child(_new)
	_scroll = UIKit.scroll()
	_scroll.follow_focus = true
	add_child(_scroll)
	_rows = UIKit.vbox(4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	_older = UIKit.button("ดูรายการเก่ากว่านี้", "gray")
	_older.focus_mode = Control.FOCUS_ALL
	_older.pressed.connect(func():
		page_size += 40
		_rebuild(true))
	add_child(_older)
	Activity.changed.connect(_on_changed)
	Activity.status_changed.connect(_update_status)
	Game.resources_changed.connect(_update_status)
	resized.connect(_update_status)
	visibility_changed.connect(func():
		if is_visible_in_tree(): refresh())
	select_filter("")


func select_filter(key: String) -> void:
	warnings_only = key == "warnings"
	category = "" if warnings_only else key
	page_size = 40
	_scroll.scroll_vertical = 0
	for b in _filter_buttons:
		UIKit.style_button(b, "yellow" if str(b.get_meta("filter")) == key else "gray")
	_rebuild()


func refresh() -> void:
	_update_status()
	_rebuild()


func _update_status() -> void:
	if not is_visible_in_tree() or not is_instance_valid(_stress):
		return
	_resource_grid.columns = 4 if size.x >= 460.0 else 3
	for key in _resource_labels:
		var text := "%s %d" % [Data.item_name(key), int(Game.s.get("res", {}).get(key, 0))]
		var l: Label = _resource_labels[key]
		if l.text != text:
			l.text = text
	var names: Array[String] = []
	for d in Activity.stressed():
		names.append("%s %d%%%s" % [d.name, int(d.happy), " (หยุดงาน)" if d.get("strike", false) else ""])
	var shown := " · ".join(names.slice(0, 2))
	if names.size() > 2:
		shown += " · อีก %d คน" % (names.size() - 2)
	_stress.text = "เครียด / ขวัญกำลังใจ: " + shown if not names.is_empty() else "ลูกเรือ: ไม่มีใครเครียด"
	_stress.add_theme_color_override("font_color", UIKit.C_ORANGE if not names.is_empty() else UIKit.C_GREEN)
	_stress.tooltip_text = " · ".join(names) + "\nขวัญกำลังใจต่ำกว่า %d/100 · อาหาร น้ำ ห้องพัก งานที่ถนัด และการรักษาช่วยได้" % int(Features.num("activity.stress", 35.0))


func _on_changed() -> void:
	if not is_visible_in_tree() or _pending:
		return
	_pending = true
	_update_history.call_deferred()


func _update_history() -> void:
	_pending = false
	if not is_visible_in_tree():
		return
	if _scroll.scroll_vertical > 12:
		_new.visible = true
	else:
		_rebuild()


func _rebuild(keep_scroll: bool = false) -> void:
	if not is_instance_valid(_rows):
		return
	var offset := _scroll.scroll_vertical if keep_scroll else 0
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var entries := Activity.entries(category, warnings_only)
	_count.text = "%d รายการ · ล่าสุดก่อน · เก็บสูงสุด %d ในเซฟ" % [entries.size(), Activity.limit()]
	_new.visible = false
	_older.visible = entries.size() > page_size
	if entries.is_empty():
		_rows.add_child(UIKit.wrap_label("ยังไม่มีกิจกรรมในหมวดนี้\nเหตุการณ์ระหว่างเล่นจะปรากฏที่นี่", UIKit.FS, UIKit.C_DIM))
	for i in range(entries.size() - 1, maxi(-1, entries.size() - page_size - 1), -1):
		var e: Dictionary = entries[i]
		var cat := str(e.get("cat", "event"))
		var kind := str(e.get("kind", "info"))
		var col := UIKit.C_RED if kind == "bad" else (UIKit.C_ORANGE if kind == "warn" else UIKit.C_LINE_DIM)
		var card := UIKit.panel(UIKit.C_BG, col)
		var v := UIKit.vbox(2)
		card.add_child(v)
		var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
		var dt := Time.get_datetime_dict_from_unix_time(int(float(e.get("t", 0))) + bias)
		v.add_child(UIKit.label("%02d/%02d %02d:%02d:%02d · %s · %.1f กม." % [dt.day, dt.month, dt.hour, dt.minute, dt.second, Activity.CATEGORIES.get(cat, "เหตุการณ์"), float(e.get("km", 0))], UIKit.FS_SMALL, UIKit.C_DIM))
		v.add_child(UIKit.wrap_label(str(e.get("text", "")), UIKit.FS, UIKit.C_GOLD if kind == "good" else UIKit.C_TEXT))
		_rows.add_child(card)
	_scroll.set_deferred("scroll_vertical", offset)
