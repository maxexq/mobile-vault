class_name LegalPanel
extends ModalPanel
## MV-589: readable notice + independent optional choices. Drafts never record acceptance.
signal approved
var section := "summary"
var preview_only := false
var terms_checked := false
var diagnostics_checked := false
var analytics_checked := false
var _tabs: HFlowContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _choices: Dictionary = {}
var accept_button: ChoiceButton
var decline_button: ChoiceButton
var _note: Label

func _build() -> void:
	name = "LegalNotice"
	max_size = Vector2(420, 600)
	fit_height = false
	_tabs = UIKit.flow(3)
	body.add_child(_tabs)
	_list = make_list(7)
	_scroll = _list.get_parent() as ScrollContainer
	_note = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_DIM)
	body.add_child(_note)
	var actions := UIKit.hbox(4)
	decline_button = ChoiceButton.new("ยังไม่ยอมรับ", "", "", "gray")
	accept_button = ChoiceButton.new("ยอมรับและเล่นต่อ", "", "", "green")
	for action in [decline_button, accept_button]:
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.button.focus_mode = Control.FOCUS_ALL
		action.button.add_theme_stylebox_override("focus", UIKit.panel_style(Color.TRANSPARENT, UIKit.C_GOLD, 1))
		actions.add_child(action)
	decline_button.pressed.connect(close)
	accept_button.pressed.connect(_accept)
	body.add_child(actions)

func open_notice(preview: bool = false) -> void:
	if not Features.on("legal_notice"):
		return
	preview_only = preview
	section = "summary"
	terms_checked = LegalPolicy.accepted()
	diagnostics_checked = LegalPolicy.allows("diagnostics")
	analytics_checked = LegalPolicy.allows("analytics")
	open()
	move_to_front()
	(accept_button.button if is_draft() else decline_button.button).grab_focus()

func is_draft() -> bool:
	return preview_only or not LegalPolicy.publication_ready()

func refresh() -> void:
	set_title("TERMS & PRIVACY / ข้อกำหนดและความเป็นส่วนตัว")
	for parent in [_tabs, _list]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	_choices.clear()
	for entry in [["summary", "สรุปและตัวเลือก"], ["terms", "ข้อกำหนด"], ["privacy", "ความเป็นส่วนตัว"]]:
		var key: String = entry[0]
		var tab := UIKit.button(entry[1], "yellow" if section == key else "gray")
		tab.focus_mode = Control.FOCUS_ALL
		tab.pressed.connect(func(): section = key; refresh())
		_tabs.add_child(tab)
	var d := LegalPolicy.document()
	_list.add_child(UIKit.wrap_label("ฉบับร่าง · ข้อมูลผู้ให้บริการยังเว้นไว้" if is_draft() else "มีผลใช้ตั้งแต่ %s" % str(d.effective_date), UIKit.FS, UIKit.C_GOLD))
	if section == "summary":
		_list.add_child(UIKit.wrap_label(str(d.get("intro", "")), UIKit.FS, UIKit.C_TEXT))
		_list.add_child(UIKit.header("SERVICE", "ข้อมูลที่จำเป็นต่อการเล่น", UIKit.C_GOLD))
		_list.add_child(UIKit.wrap_label("เกมใช้เซฟ การตั้งค่า และข้อมูลบัญชีเพื่อให้เล่นต่อและซิงก์ข้อมูลได้ ดูรายละเอียดผู้ให้บริการ การเก็บข้อมูล และสิทธิของคุณในแท็บความเป็นส่วนตัว", UIKit.FS_SMALL, UIKit.C_TEXT))
		_add_choice("terms", terms_checked)
		_list.add_child(UIKit.header("OPTIONAL", "เลือกได้ · ไม่อนุญาตก็เล่นต่อได้", UIKit.C_GOLD))
		_add_choice("diagnostics", diagnostics_checked)
		_add_choice("analytics", analytics_checked)
	else:
		for item in d.get(section, []):
			_list.add_child(UIKit.wrap_label(str(item.heading), UIKit.FS_BIG, UIKit.C_GOLD))
			_list.add_child(UIKit.wrap_label(LegalPolicy.section_text(str(item.text)), UIKit.FS, UIKit.C_TEXT))
	_scroll.scroll_vertical = 0
	_note.text = "ฉบับร่างสำหรับตรวจข้อความและหน้าต่าง ยังไม่บันทึกการยอมรับหรือส่งข้อมูลเสริม" if is_draft() else "เปลี่ยนใจเรื่องข้อมูลเสริมได้ทุกเมื่อที่ ตั้งค่า > ความเป็นส่วนตัว"
	_set_action_text(accept_button, "ปิดฉบับร่าง" if is_draft() else ("บันทึกตัวเลือก" if LegalPolicy.accepted() else "ยอมรับและเล่นต่อ"))
	_set_action_text(decline_button, "ปิด" if is_draft() or LegalPolicy.accepted() else "ยังไม่ยอมรับ")
	_sync_choices()

func _set_action_text(control: ChoiceButton, text: String) -> void:
	(control._text.get_child(0) as Label).text = text

func _add_choice(key: String, selected: bool) -> void:
	var data: Dictionary = LegalPolicy.document().get("choices", {}).get(key, {})
	var control := ChoiceButton.new(str(data.get("label", key)), "", str(data.get("detail", "")), "gray")
	control.button.focus_mode = Control.FOCUS_ALL
	control.pressed.connect(func():
		match key:
			"terms": terms_checked = not terms_checked
			"diagnostics": diagnostics_checked = not diagnostics_checked
			"analytics": analytics_checked = not analytics_checked
		_sync_choices())
	_choices[key] = {"control": control, "label": str(data.get("label", key))}
	_list.add_child(control)

func _sync_choices() -> void:
	var state := {"terms": terms_checked, "diagnostics": diagnostics_checked, "analytics": analytics_checked}
	for key in _choices:
		var control: ChoiceButton = _choices[key].control
		_set_action_text(control, ("[x] " if state[key] else "[ ] ") + str(_choices[key].label))
		UIKit.style_button(control.button, "green" if state[key] else "gray")
	decline_button.visible = not is_draft()
	accept_button.disabled = not is_draft() and not terms_checked

func _accept() -> void:
	if is_draft():
		close()
		return
	if not terms_checked or not LegalPolicy.record_choices(diagnostics_checked, analytics_checked):
		return
	approved.emit()
	close()

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
