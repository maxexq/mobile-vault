class_name OfflineSummary
extends ModalPanel
## MV-587: a receipt for progress already credited by Game, never a second reward claim.

var report: Dictionary = {}
var _list: VBoxContainer
var continue_button: Button


func _build() -> void:
	name = "OfflineSummary"
	max_size = Vector2(360, 520)
	_list = make_list(6)
	continue_button = UIKit.button(Loc.t("เดินทางต่อ"), "green")
	continue_button.custom_minimum_size.y = 36
	continue_button.focus_mode = Control.FOCUS_ALL
	continue_button.add_theme_stylebox_override("focus", UIKit.panel_style(Color.TRANSPARENT, UIKit.C_GOLD, 1))
	continue_button.pressed.connect(close)
	body.add_child(continue_button)


func refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	set_title("WELCOME BACK / ยินดีต้อนรับกลับ")
	_list.add_child(UIKit.wrap_label("ระหว่างที่คุณไม่อยู่ %s" % _duration(float(report.get("away_seconds", 0.0))), UIKit.FS_BIG, UIKit.C_GOLD))
	var credited := float(report.get("seconds", 0.0))
	if float(report.get("away_seconds", 0.0)) > credited + 1.0:
		_list.add_child(UIKit.wrap_label("คำนวณความคืบหน้าสูงสุด %s ตามโหมดที่เล่น" % _duration(credited), UIKit.FS_SMALL, UIKit.C_DIM))
	_list.add_child(UIKit.wrap_label("ของเข้าคลังแล้ว · ตัวเลขแสดงผลสุทธิหลังหักที่ใช้ระหว่างไม่อยู่", UIKit.FS_SMALL, UIKit.C_DIM))
	_list.add_child(UIKit.header("SUPPLIES", "ทรัพยากรและไอเทม", UIKit.C_GOLD))
	var rows := 0
	for group in ["resources", "items"]:
		for key in report.get(group, {}):
			var amount := float(report[group][key])
			if absf(amount) < 0.05:
				continue
			var text := "%+.1f" % amount if group == "resources" else "%+d" % int(amount)
			_add_row(Data.item_icon(key), Data.item_name(key), text, UIKit.C_GREEN if amount > 0.0 else UIKit.C_RED)
			rows += 1
	if rows == 0:
		_list.add_child(UIKit.wrap_label("ไม่มีทรัพยากรหรือไอเทมเปลี่ยนแปลง", UIKit.FS_SMALL, UIKit.C_DIM))
	var gear: Array = report.get("gear", [])
	if not gear.is_empty():
		_list.add_child(UIKit.header("GEAR", "อุปกรณ์ที่ได้", UIKit.C_GOLD))
		for item in gear:
			_list.add_child(UIKit.wrap_label("%s · Lv.%d" % [Loot.item_name(item), int(item.ilvl)], UIKit.FS, Loot.rar_color(item)))
	_list.add_child(UIKit.header("PROGRESS", "ความคืบหน้า", UIKit.C_GOLD))
	_add_row("map", "ระยะทาง", "+%.1f กม." % float(report.get("km", 0.0)), UIKit.C_TEXT)
	var combat: Dictionary = report.get("combat", {})
	if not combat.is_empty():
		_list.add_child(UIKit.wrap_label("ทีมป้องกันกำจัดศัตรู %d ตัว · +%d XP ต่อสมาชิกทีม" % [int(combat.kills), int(combat.xp)], UIKit.FS, UIKit.C_GREEN))
	if str(report.get("arrival", "")) != "":
		_list.add_child(UIKit.wrap_label("ถึง%sแล้ว รถจอดรอ เลือกปลายทางใหม่บนแผนที่" % str(report.arrival), UIKit.FS, UIKit.C_GOLD))
	for cache in report.get("caches", []):
		_list.add_child(UIKit.wrap_label("เก็บกล่องพิมพ์เขียวระหว่างทาง: %s" % str(cache), UIKit.FS, UIKit.C_GREEN))
	for room in report.get("built", []):
		_list.add_child(UIKit.wrap_label("ก่อสร้างเสร็จ: %s" % str(room), UIKit.FS, UIKit.C_GREEN))
	continue_button.grab_focus()


func _add_row(icon: String, title: String, amount: String, color: Color) -> void:
	var row := UIKit.hbox(6)
	row.add_child(UIKit.icon_rect(icon, 16))
	var label := UIKit.wrap_label(title, UIKit.FS, UIKit.C_TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(UIKit.label(amount, UIKit.FS, color))
	_list.add_child(row)


static func _duration(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	if total >= 3600:
		return "%d ชม. %d นาที" % [total / 3600, (total % 3600) / 60]
	if total >= 60:
		return "%d นาที %d วินาที" % [total / 60, total % 60]
	return "%d วินาที" % total


func _unhandled_key_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
