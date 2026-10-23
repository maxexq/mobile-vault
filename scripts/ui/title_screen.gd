class_name TitleScreen
extends Control
## Start menu over the live scene: a green terminal boot log types itself out, then the menu.
## NEW RUN opens the rules picker (mode / difficulty / mutators, see Modes) unless the "modes" switch is off.

signal start_requested(new_game: bool)
signal settings_requested(tab: String)

const BOOT := [
	"MAMMOTH-7 OS v%s ........ OK",
	"REACTOR / ENGINE ......... ONLINE",
	"HULL INTEGRITY ........... 100%",
	"SIGNAL 104.7 ............. DETECTED",
	"> WELCOME, OVERSEER",
]

var _panel: PanelContainer
var _log: Label
var _menu: VBoxContainer
var _picker: VBoxContainer
var _pick_scroll: ScrollContainer
var _pick := {"id": "standard", "diff": "normal", "mut": []}
var _continue: Button
var _account_btn: Button
var _settings_btn: Button
var _chars := 0.0
var _boot_text := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_boot_text = "\n".join(BOOT).replace("%s", BuildInfo.GAME_VERSION)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.window_style())
	add_child(_panel)
	var v := UIKit.vbox(6)
	_panel.add_child(v)
	v.add_child(UIKit.logo())
	v.add_child(UIKit.divider(UIKit.C_LINE_DIM))
	_log = UIKit.label("", UIKit.FP, UIKit.C_DIM, true)
	_log.custom_minimum_size.y = 52
	v.add_child(_log)
	_menu = UIKit.vbox(4)
	v.add_child(_menu)
	var t1 := UIKit.label("รถบ้านหุ้มเกราะคันสุดท้ายกำลังรอคำสั่ง", UIKit.FS, UIKit.C_TEXT)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(t1)
	_continue = UIKit.button("เดินทางต่อ  CONTINUE", "green", "play")
	_continue.pressed.connect(func(): _go(false))
	_menu.add_child(_continue)
	var nb := UIKit.button("เริ่มการเดินทางใหม่  NEW RUN", "yellow", "up")
	nb.pressed.connect(_new_run)
	_menu.add_child(nb)
	_account_btn = UIKit.button("", "blue", "book")
	_account_btn.pressed.connect(func(): settings_requested.emit("data"))
	_menu.add_child(_account_btn)
	Cloud.account_changed.connect(_refresh_account)
	Cloud.status_changed.connect(_refresh_account)
	_refresh_account()
	_settings_btn = UIKit.button("ตั้งค่า  SETTINGS", "gray", "gear")
	_settings_btn.pressed.connect(func(): settings_requested.emit("game"))
	_menu.add_child(_settings_btn)
	var note := UIKit.label(BuildInfo.short_line(), UIKit.FP, UIKit.C_LINE_DIM, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.mouse_filter = Control.MOUSE_FILTER_STOP
	note.tooltip_text = "แตะเพื่อดูข้อมูลเวอร์ชัน"
	note.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			settings_requested.emit("about"))
	_menu.add_child(note)
	_pick_scroll = UIKit.scroll()
	_pick_scroll.visible = false
	v.add_child(_pick_scroll)
	_picker = UIKit.vbox(4)
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pick_scroll.add_child(_picker)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	if _chars < _boot_text.length():
		_chars += delta * 70.0
		_log.text = _boot_text.substr(0, int(_chars)) + ("_" if int(_chars * 0.2) % 2 == 0 else "")


## cloud on: who is playing (Guest / Google) and the way to the account section
func _refresh_account() -> void:
	_account_btn.visible = Cloud.enabled()
	if Cloud.is_guest():
		_account_btn.text = "Guest · ล็อกอินด้วย Gmail"
	else:
		_account_btn.text = "บัญชี: " + str(Cloud.session.get("email", "Google"))
	_panel.custom_minimum_size.y = 0
	_layout.call_deferred()


func refresh_buttons() -> void:
	_continue.visible = Save.has_save()
	_panel.custom_minimum_size.y = 0
	_layout.call_deferred()


func _layout() -> void:
	var vp := get_viewport_rect().size
	var w := minf(300.0, vp.x - 24)
	_panel.custom_minimum_size.x = w
	if _pick_scroll.visible:
		# the picker scrolls inside the window when the screen is short (landscape)
		_pick_scroll.custom_minimum_size = Vector2(w - 16, minf(_picker.get_combined_minimum_size().y, vp.y - 96))
	_panel.reset_size()
	if vp.y > vp.x:
		_panel.position = Vector2(floorf((vp.x - _panel.size.x) * 0.5), floorf(vp.y - _panel.size.y - 24))
	else:
		_panel.position = Vector2(floorf(vp.x - _panel.size.x - 16), floorf((vp.y - _panel.size.y) * 0.5))


# ------------------------------------------------------------------ rules picker
func _new_run() -> void:
	if not Features.on("modes"):
		Modes.pending = {}
		_go(true)
		return
	open_picker()


func open_picker() -> void:
	_menu.visible = false
	_log.visible = false
	_pick_scroll.visible = true
	_build_picker()


func close_picker() -> void:
	_pick_scroll.visible = false
	_log.visible = true
	_menu.visible = true
	_relayout()


func pick(key: String, value: Variant) -> void:
	if key == "mut":
		var mu: Array = (_pick.mut as Array).duplicate()
		if mu.has(value):
			mu.erase(value)
		else:
			mu.append(value)
		_pick.mut = mu
	else:
		_pick[key] = value
	_pick = Modes.make(str(_pick.id), str(_pick.diff), _pick.mut)
	_build_picker()


func _build_picker() -> void:
	for c in _picker.get_children():
		_picker.remove_child(c)
		c.queue_free()
	_picker.add_child(UIKit.header("RUN RULES", "กฎของการเดินทางครั้งนี้"))
	var mrow := UIKit.flow(3)
	for k in Modes.MODES:
		var mid: String = k
		var b := UIKit.button(str(Modes.MODES[k].th), "yellow" if _pick.id == mid else "gray")
		b.pressed.connect(func(): pick("id", mid))
		mrow.add_child(b)
	_picker.add_child(mrow)
	_picker.add_child(UIKit.wrap_label(str(Modes.MODES[_pick.id].desc), UIKit.FS_SMALL, UIKit.C_DIM))
	_picker.add_child(UIKit.label("ความยาก  DIFFICULTY", UIKit.FS_SMALL, UIKit.C_GOLD))
	var drow := UIKit.flow(3)
	for k in Modes.DIFFS:
		var did: String = k
		var b := UIKit.button(str(Modes.DIFFS[k].th), "yellow" if _pick.diff == did else "gray")
		b.pressed.connect(func(): pick("diff", did))
		drow.add_child(b)
	_picker.add_child(drow)
	_picker.add_child(UIKit.label("ตัวแปรกฎ  MUTATORS", UIKit.FS_SMALL, UIKit.C_GOLD))
	var peaceful := bool(Modes.MODES[_pick.id].get("peaceful", false))
	var murow := UIKit.flow(3)
	var descs := []
	for k in Modes.MUTATORS:
		var key: String = k
		var mu: Dictionary = Modes.MUTATORS[k]
		if peaceful and bool(mu.get("combat", false)):
			continue
		var on: bool = (_pick.mut as Array).has(key)
		var b := UIKit.button(("+ " if on else "") + str(mu.th), "green" if on else "gray")
		b.tooltip_text = str(mu.desc)
		b.pressed.connect(func(): pick("mut", key))
		murow.add_child(b)
		if on:
			descs.append("%s: %s" % [mu.th, mu.desc])
	_picker.add_child(murow)
	if not descs.is_empty():
		_picker.add_child(UIKit.wrap_label("\n".join(descs), UIKit.FS_SMALL, UIKit.C_DIM))
	var ranked := bool(Modes.MODES[_pick.id].get("ranked", false))
	_picker.add_child(UIKit.wrap_label("แต้มวิจัยพันธุกรรม ×%.2f · %s" % [Modes.legacy_mult(_pick), "นับอันดับได้ในอนาคต" if ranked else "ไม่นับอันดับ"],
		UIKit.FS_SMALL, UIKit.C_TEXT))
	var row := UIKit.hbox(4)
	var back := UIKit.button("ย้อนกลับ", "gray")
	back.pressed.connect(close_picker)
	row.add_child(back)
	var go := UIKit.button("ออกเดินทาง  START", "green", "play")
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func():
		Modes.pending = _pick.duplicate(true)
		_go(true))
	row.add_child(go)
	_picker.add_child(row)
	_relayout()


func _relayout() -> void:
	_panel.custom_minimum_size.y = 0
	_panel.reset_size()
	_layout.call_deferred()


func _go(new_game: bool) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		visible = false
		if _pick_scroll.visible:
			close_picker()
		start_requested.emit(new_game))
