class_name ConfirmPanel
extends ModalPanel
## MV-422: one pending destructive action. Closing always cancels; only the named action commits.

var message: Label
var cancel_button: Button
var confirm_button: Button
var _origin: Control
var _action := Callable()
var _guard := Callable()
var _run: Dictionary
var _user_id := ""


static func ask(source: Control, title: String, detail: String, verb: String, action: Callable, guard: Callable = Callable()) -> void:
	if not Features.on("confirm_actions"):
		if action.is_valid() and (guard.is_null() or (guard.is_valid() and guard.call())):
			action.call()
		return
	var panel := source.get_tree().get_first_node_in_group("confirm_dialog") as ConfirmPanel
	if panel != null:
		panel.request(source, title, detail, verb, action, guard)


func _build() -> void:
	name = "ConfirmDialog"
	add_to_group("confirm_dialog")
	max_size = Vector2(340, 300)
	message = UIKit.wrap_label("", UIKit.FS, UIKit.C_TEXT)
	make_list(4).add_child(message)
	cancel_button = UIKit.button(Loc.t("ยกเลิก"), "gray")
	cancel_button.name = "CancelAction"
	confirm_button = UIKit.button("", "red")
	confirm_button.name = "ConfirmAction"
	for b in [cancel_button, confirm_button]:
		b.custom_minimum_size.y = 32
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_stylebox_override("focus", UIKit.panel_style(Color.TRANSPARENT, UIKit.C_GOLD, 1))
		body.add_child(b)
	cancel_button.pressed.connect(close)
	confirm_button.pressed.connect(_accept)


func request(source: Control, title: String, detail: String, verb: String, action: Callable, guard: Callable = Callable()) -> void:
	# A repeated tap must neither replace the pending target nor run an action twice.
	if is_open:
		return
	_origin = source
	_run = Game.s
	_user_id = Cloud.user_id()
	_action = action
	_guard = guard
	_origin.tree_exiting.connect(close)
	_origin.visibility_changed.connect(_origin_visibility_changed)
	set_title(title)
	message.text = detail
	cancel_button.text = Loc.t("ยกเลิก")
	confirm_button.text = verb
	visible = true
	move_to_front()
	is_open = true
	add_to_group("modal_open")
	box.modulate = Color.WHITE
	dim.modulate.a = 1.0
	_layout()
	cancel_button.grab_focus()


func _origin_visibility_changed() -> void:
	if not is_instance_valid(_origin) or not _origin.is_visible_in_tree():
		close()


func close() -> void:
	if not is_open:
		return
	# Clear synchronously before any callback, including callbacks which replace the scene.
	is_open = false
	visible = false
	remove_from_group("modal_open")
	_action = Callable()
	_guard = Callable()
	if is_instance_valid(_origin):
		_origin.tree_exiting.disconnect(close)
		_origin.visibility_changed.disconnect(_origin_visibility_changed)
	_origin = null
	_run = {}
	closed.emit()


func _accept() -> void:
	if not is_open:
		return
	var action := _action
	var valid := is_instance_valid(_origin) and _origin.is_visible_in_tree() and action.is_valid()
	valid = valid and is_same(Game.s, _run) and Cloud.user_id() == _user_id
	if _origin is ModalPanel:
		valid = valid and _origin.is_open
	valid = valid and (_guard.is_null() or (_guard.is_valid() and _guard.call()))
	close()
	if valid:
		action.call()
	else:
		Game.toast.emit(Loc.t("ข้อมูลเปลี่ยนไปแล้ว กรุณาเลือกใหม่"), "warn")


func _input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
