class_name SolarPanel
extends ModalPanel
## Rooftop solar system: weather & sun intensity, generation, battery, net power flow, upgrades.

var _info: Label
var _gen: Label
var _bat_bar: ProgressBar
var _bat_lbl: Label
var _flow: Label
var _ups: VBoxContainer
var _cells: HBoxContainer
var _w_icon: TextureRect
var _box: BoxContainer


func _build() -> void:
	set_title("ROOFTOP SOLAR / ระบบโซลาร์เซลล์บนหลังคา")
	var outer := UIKit.scroll()
	body.add_child(outer)
	var h := BoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.set_meta("responsive", true)
	outer.add_child(h)
	_box = h
	var left := UIKit.vbox(6)
	left.custom_minimum_size.x = 150
	h.add_child(left)
	var wh := UIKit.hbox(4)
	_w_icon = UIKit.icon_rect("sun", 32)
	wh.add_child(_w_icon)
	_info = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_TEXT)
	wh.add_child(_info)
	left.add_child(wh)
	_gen = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_GREEN)
	left.add_child(_gen)
	var mid := UIKit.vbox(6)
	mid.custom_minimum_size.x = 140
	h.add_child(mid)
	_cells = UIKit.hbox(2)
	mid.add_child(_cells)
	for i in 4:
		_cells.add_child(UIKit.icon_rect("power", 32))
	_bat_lbl = UIKit.label("", UIKit.FP, UIKit.C_TEXT, true)
	mid.add_child(_bat_lbl)
	_bat_bar = UIKit.progress(UIKit.C_GREEN, 6)
	mid.add_child(_bat_bar)
	_flow = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_GOLD)
	mid.add_child(_flow)
	_ups = UIKit.vbox(3)
	_ups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_ups)


func refresh() -> void:
	_box.vertical = true
	for c in _ups.get_children():
		_ups.remove_child(c)
		c.queue_free()
	var sol: Dictionary = Game.s.solar
	_ups.add_child(_up_row("pickaxe", "ทำความสะอาดแผง", "ฝุ่น/ใบไม้เกาะ %d%% (ลดกำลังผลิตสูงสุด 60%%) · ฟรี" % int(float(sol.dirt) * 100), "clean", {}, float(sol.dirt) < 0.01))
	var pl: int = sol.panels
	_ups.add_child(_up_row("solar", "เพิ่มแผงโซลาร์เซลล์ใหม่ (Lv.%d)" % pl, "+25% กำลังผลิตต่อแผง", "panels", {"scrap": Game.SOLAR_COSTS.panels[mini(pl + 1, 4)]}, pl >= 4))
	var bl: int = sol.battery
	_ups.add_child(_up_row("battery", "แบตเตอรี่สำรอง (Lv.%d)" % bl, "+80 ความจุแบตเตอรี่", "battery", {"scrap": Game.SOLAR_COSTS.battery[mini(bl + 1, 4)]}, bl >= 4))
	_ups.add_child(_up_row("tracking", "ระบบหมุนตามแสงแดด", "แผงหมุนตามดวงอาทิตย์ · ผลิตไฟดีขึ้นช่วงเช้า/เย็น", "tracking", {"scrap": Game.SOLAR_COSTS.tracking}, bool(sol.tracking)))
	_update()


func _up_row(_icon: String, title: String, desc: String, kind: String, cost: Dictionary, done: bool) -> Control:
	var p := UIKit.panel()
	var h := UIKit.hbox(4)
	p.add_child(h)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.wrap_label(title, UIKit.FS_SMALL, UIKit.C_TEXT))
	v.add_child(UIKit.wrap_label(desc))
	h.add_child(v)
	var b := UIKit.button("MAX" if done and kind != "clean" else ("ล้าง" if kind == "clean" else "%d" % int(cost.get("scrap", 0))), "green", "wrench" if kind == "clean" else "scrap", 64)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = done or not Game.can_afford(cost)
	b.pressed.connect(func():
		Game.solar_upgrade(kind)
		refresh())
	h.add_child(b)
	return p


func _process(_d: float) -> void:
	if is_open:
		_update()


func _update() -> void:
	var w := Game.weather_def()
	_w_icon.texture = Atlas.icon(w.icon)
	var sun := Game.sun_level()
	_info.text = "%s · แสงแดด %d%%%s" % [w.th, int(sun * float(w.solar) * 100), " (กลางคืน)" if Game.is_night() else ""]
	_gen.text = "ผลิต +%.1f ไฟ/นาที (สูงสุด %.0f ตอนเที่ยงฟ้าใส)" % [Game.solar_output_pm(), 20.0 * (1.0 + 0.25 * float(Game.s.solar.panels - 1))]
	var p: float = Game.s.res.power
	var c := Game.cap("power")
	_bat_bar.value = p / c
	_bat_lbl.text = "BATTERY %d%% %d/%d" % [int(p / c * 100), int(p), int(c)]
	for i in 4:
		(_cells.get_child(i) as Control).modulate = Color.WHITE if p / c > i * 0.25 else Color(0.25, 0.25, 0.25)
	var flow := Game.power_flow_pm()
	_flow.text = "ไฟสุทธิ %+.1f/นาที · %s" % [flow, "กำลังชาร์จ" if flow > 0.1 else ("ไฟกำลังลดลง!" if flow < -0.1 else "คงที่")]
