class_name TitleScreen
extends Control
## Start menu over the live scene: a green terminal boot log types itself out, then the menu.

signal start_requested(new_game: bool)

const BOOT := [
	"MAMMOTH-7 OS v4.3 ........ OK",
	"REACTOR / ENGINE ......... ONLINE",
	"HULL INTEGRITY ........... 100%",
	"SIGNAL 104.7 ............. DETECTED",
	"> WELCOME, OVERSEER",
]

var _panel: PanelContainer
var _log: Label
var _menu: VBoxContainer
var _continue: Button
var _fx_btn: Button
var _chars := 0.0
var _boot_text := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_boot_text = "\n".join(BOOT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.window_style())
	add_child(_panel)
	var v := UIKit.vbox(6)
	_panel.add_child(v)
	var head := UIKit.hbox(6)
	head.add_child(UIKit.icon_rect("emblem", 24))
	var hv := UIKit.vbox(0)
	hv.add_child(UIKit.label("MOBILE VAULT", 18, UIKit.C_LINE, true))
	hv.add_child(UIKit.label("PROJECT: SURVIVAL", UIKit.FP, UIKit.C_GOLD, true))
	head.add_child(hv)
	v.add_child(head)
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
	nb.pressed.connect(func(): _go(true))
	_menu.add_child(nb)
	_fx_btn = UIKit.button("", "gray", "gear")
	_fx_btn.pressed.connect(func():
		FX.use_gpu = not FX.use_gpu
		_update_fx())
	_menu.add_child(_fx_btn)
	var note := UIKit.label("v4.3 · GODOT 4.7.2 · AUTOSAVE", UIKit.FP, UIKit.C_LINE_DIM, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(note)
	_update_fx()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	if _chars < _boot_text.length():
		_chars += delta * 70.0
		_log.text = _boot_text.substr(0, int(_chars)) + ("_" if int(_chars * 0.2) % 2 == 0 else "")


func _update_fx() -> void:
	_fx_btn.text = "เอฟเฟกต์: %s" % ("GPU (สวย)" if FX.use_gpu else "CPU (ประหยัด)")


func refresh_buttons() -> void:
	_continue.visible = Save.has_save()
	_panel.custom_minimum_size.y = 0
	_layout.call_deferred()


func _layout() -> void:
	var vp := get_viewport_rect().size
	var w := minf(300.0, vp.x - 24)
	_panel.custom_minimum_size.x = w
	_panel.reset_size()
	if vp.y > vp.x:
		_panel.position = Vector2(floorf((vp.x - _panel.size.x) * 0.5), floorf(vp.y - _panel.size.y - 24))
	else:
		_panel.position = Vector2(floorf(vp.x - _panel.size.x - 16), floorf((vp.y - _panel.size.y) * 0.5))


func _go(new_game: bool) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		visible = false
		start_requested.emit(new_game))
