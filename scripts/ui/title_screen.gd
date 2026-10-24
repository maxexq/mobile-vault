class_name TitleScreen
extends Control
## Start menu over the live scene: a green terminal boot log types itself out, then the menu.
## One persistent account (Account): CONTINUE when there is a save, START only on a browser without one. No
## rules picker any more: the main vehicle is standard, difficulty is in Settings. Switch "persistent_account"
## off brings back NEW RUN, which starts over from nothing.
## A web page reload with a save goes straight back into the game (switch "resume_on_reload") once the cloud
## has answered, unless the player is needed first (Guest / Gmail choice, log in again, save conflict).

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
var _continue: Button
var _new_btn: Button
var _account_btn: Button
var _gate: VBoxContainer
var _gate_err: Label
var _gate_switch: Button
var _settings_btn: Button
var _chars := 0.0
var _boot_text := ""
var _channel: Label
var _env_tag: Label
## set at start on a web reload; cleared once the game was entered (or by the player tapping anything)
var auto_continue := false


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
	_channel = UIKit.channel_tag()
	v.add_child(_channel)
	_env_tag = UIKit.env_tag()
	v.add_child(_env_tag)
	Features.changed.connect(func():
		UIKit.refresh_channel_tag(_channel)
		UIKit.refresh_env_tag(_env_tag))
	visibility_changed.connect(func():
		UIKit.refresh_channel_tag(_channel)
		UIKit.refresh_env_tag(_env_tag))
	v.add_child(UIKit.divider(UIKit.C_LINE_DIM))
	_log = UIKit.label("", UIKit.FP, UIKit.C_DIM, true)
	_log.custom_minimum_size.y = 52
	v.add_child(_log)
	_menu = UIKit.vbox(4)
	v.add_child(_menu)
	var t1 := UIKit.wrap_label(Loc.t("รถบ้านหุ้มเกราะคันสุดท้ายกำลังรอคำสั่ง"), UIKit.FS, UIKit.C_TEXT)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(t1)
	_continue = UIKit.button(Loc.t("เดินทางต่อ  CONTINUE"), "green", "play")
	_continue.pressed.connect(func(): _go(false))
	_menu.add_child(_continue)
	_new_btn = UIKit.button(Loc.t("เริ่มการเดินทาง  START"), "yellow", "up")
	_new_btn.pressed.connect(_new_run)
	_menu.add_child(_new_btn)
	_account_btn = UIKit.button("", "blue", "book")
	_account_btn.pressed.connect(func(): settings_requested.emit("data"))
	_menu.add_child(_account_btn)
	Cloud.account_changed.connect(_refresh_account)
	Cloud.status_changed.connect(_refresh_account)
	_settings_btn = UIKit.button(Loc.t("ตั้งค่า  SETTINGS"), "gray", "gear")
	_settings_btn.pressed.connect(func(): settings_requested.emit("game"))
	_menu.add_child(_settings_btn)
	var note := UIKit.label(BuildInfo.short_line(), UIKit.FP, UIKit.C_LINE_DIM, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.mouse_filter = Control.MOUSE_FILTER_STOP
	note.tooltip_text = Loc.t("แตะเพื่อดูข้อมูลเวอร์ชัน")
	note.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			settings_requested.emit("about"))
	_menu.add_child(note)
	_build_gate(v)
	auto_continue = Features.on("resume_on_reload") and _is_page_reload()
	settings_requested.connect(func(_tab: String): auto_continue = false)
	_refresh_account()
	get_viewport().size_changed.connect(_layout)
	# the boot log types itself out and the account line / UI scale can change after _ready: re-place the
	# window whenever it grows so it never runs off the screen edge
	_panel.minimum_size_changed.connect(_layout, CONNECT_DEFERRED)
	_layout()


func _process(delta: float) -> void:
	if _chars < _boot_text.length():
		_chars += delta * 70.0
		_log.text = _boot_text.substr(0, int(_chars)) + ("_" if int(_chars * 0.2) % 2 == 0 else "")


## first visit with the cloud on (or a Google session that ended): Guest or Gmail, as two separate choices
func _build_gate(v: VBoxContainer) -> void:
	_gate = UIKit.vbox(4)
	_gate.visible = false
	v.add_child(_gate)
	var t := UIKit.label(Loc.t("เลือกวิธีเล่น"), UIKit.FS, UIKit.C_TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gate.add_child(t)
	_gate_err = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_RED)
	_gate.add_child(_gate_err)
	var guest := UIKit.button(Loc.t("เล่นเลยแบบ Guest"), "green", "play")
	guest.pressed.connect(func(): Cloud.play_as_guest())
	_gate.add_child(guest)
	var gmail := UIKit.button(Loc.t("ล็อกอินด้วย Gmail"), "blue", "book")
	gmail.pressed.connect(func(): Cloud.sign_in_google())
	_gate.add_child(gmail)
	_gate_switch = UIKit.button(Loc.t("สลับไปบัญชี Google นั้น"), "yellow", "play")
	_gate_switch.pressed.connect(func(): Cloud.switch_to_google())
	_gate.add_child(_gate_switch)
	_gate.add_child(UIKit.wrap_label(Loc.t("Guest เล่นได้ทันที เซฟอยู่ในเบราว์เซอร์นี้ ผูก Gmail ทีหลังได้ที่ ตั้งค่า > เซฟ · Gmail เก็บเซฟไว้ในบัญชี เล่นต่อจากเครื่องไหนก็ได้"), UIKit.FS_SMALL, UIKit.C_DIM))


## cloud on: who is playing (Guest / Google) and the way to the account section
func _refresh_account() -> void:
	if _gate == null:
		return
	var choose := Cloud.needs_choice()
	_gate.visible = choose
	_menu.visible = not choose
	_gate_err.text = Cloud.auth_error
	_gate_err.visible = Cloud.auth_error != ""
	_gate_switch.visible = Cloud.link_taken
	_account_btn.visible = Cloud.enabled()
	if Cloud.is_guest():
		_account_btn.text = Loc.t("Guest · ผูกบัญชี Gmail")
	else:
		_account_btn.text = Loc.t("บัญชี: ") + str(Cloud.session.get("email", "Google"))
	_panel.custom_minimum_size.y = 0
	_layout.call_deferred()
	try_auto_continue()


func refresh_buttons() -> void:
	var has := Save.has_save()
	_continue.visible = has
	# a persistent account never starts over from the title; Settings > เซฟ can still erase it
	_new_btn.visible = not has or not Features.on("persistent_account")
	_new_btn.text = Loc.t("เริ่มการเดินทางใหม่  NEW RUN") if has else Loc.t("เริ่มการเดินทาง  START")
	_panel.custom_minimum_size.y = 0
	_layout.call_deferred()
	try_auto_continue()


# ------------------------------------------------------------------ resume after a page reload
static func _is_page_reload() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("(performance.getEntriesByType('navigation')[0] || {}).type === 'reload'", true))


## enter the saved game on our own once nothing needs the player: the cloud has answered (a newer save
## from another device is pulled first, not turned into a conflict) and no login / conflict is pending
func try_auto_continue() -> void:
	if not auto_continue or not visible or not Save.has_save():
		return
	if Cloud.url != "" and Cloud.state in [Cloud.State.OFF, Cloud.State.CONNECTING]:
		return    # cloud configured but not answered yet; status_changed calls this again
	if Cloud.state == Cloud.State.CONFLICT or Cloud.needs_choice():
		return
	_go(false)


func _layout() -> void:
	var vp := get_viewport_rect().size
	var w := minf(300.0, vp.x - 24)
	_panel.custom_minimum_size.x = w
	_panel.reset_size()
	if vp.y > vp.x:
		_panel.position = Vector2(floorf((vp.x - _panel.size.x) * 0.5), floorf(vp.y - _panel.size.y - 24))
	else:
		_panel.position = Vector2(floorf(vp.x - _panel.size.x - 16), floorf((vp.y - _panel.size.y) * 0.5))
	_panel.position = _panel.position.clamp(Vector2(4, 4), (vp - _panel.size - Vector2(4, 4)).max(Vector2(4, 4)))


# ------------------------------------------------------------------ start
func _new_run() -> void:
	Modes.pending = {}
	_go(true)


func _go(new_game: bool) -> void:
	auto_continue = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		visible = false
		start_requested.emit(new_game))
