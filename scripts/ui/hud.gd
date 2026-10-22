class_name HUD
extends Control
## Main terminal overlay. Portrait (primary): resource strip + status row + route bar on top,
## combat chip under it, travel strip + 6 tool buttons at the bottom. Landscape: one top strip and a
## tool column on the right. Exposes world_rect() so the camera frames the truck in the free space.

signal build_placement_requested(room_type: String)
signal build_placement_cancelled
signal layout_changed

const RES := [["power", "power", Color("ffdc8e")], ["water", "water", Color("8cfff6")], ["food", "food", Color("f0644a")], ["fuel", "fuel", Color("ff9a1a")], ["scrap", "scrap", Color("cad8d0")]]
const TOOLS := [["Build", "hammer", "build", "yellow"], ["Squad", "sword", "squad", "red"], ["Map", "map", "map", "green"],
	["Crew", "people", "dwellers", "green"], ["Loot", "chest", "inventory", "green"], ["Mods", "wrench", "garage", "blue"], ["Log", "book", "log", "blue"]]

var res_labels := {}
var res_bars := {}
var lvl_lbl: Label
var status_lbl: Label
var pop_lbl: Label
var happy_lbl: Label
var happy_icon: TextureRect
var weather_icon: TextureRect
var weather_lbl: Label
var tod_icon: TextureRect
var speed_lbl: Label
var dist_lbl: Label
var hull_bar: ProgressBar
var go_btn: Button
var biome_lbl: Label
var toast_box: VBoxContainer
var banner: PanelContainer
var banner_lbl: Label
var biome_bar: BiomeBar

var panels := {}
var _top: VBoxContainer
var _res_row: HBoxContainer
var _info_row: HBoxContainer
var _route_row: HBoxContainer
var _bottom: VBoxContainer
var _travel: PanelContainer
var _tools: BoxContainer
var _tool_buttons := {}
var _combat_box: PanelContainer
var _portrait := true
var _closeup_on := false
var _wave_lbl: Label
var _wave_sub: Label
var _push_btn: Button
var _boss_btn: Button
var _log_badge: Label
var _haz_box: HBoxContainer
var _haz_key := ""
var _exp_box: PanelContainer
var _exp_lbl: Label
var _exp_btn: Button
var _scav_btn: Button
var _door_box: PanelContainer
var _door_lbl: Label
var room_closeup: RoomCloseup
var event_popup: EventPopup
var encounter_popup: EncounterPopup
var title_screen: TitleScreen
var boss_bar: BossBar
var _boss_was := false
var _view_box: HBoxContainer
var _xray_btn: Button
var _zoom_btn: Button
var _god_btn: Button
var tutorial_overlay: TutorialOverlay
var settings_panel: SettingsPanel
var _settings_btn: Button
signal zoom_pressed
signal xray_toggled(on: bool)


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_bottom()
	_build_combat_chip()
	boss_bar = BossBar.new()
	add_child(boss_bar)
	_view_box = UIKit.hbox(2)
	_xray_btn = UIKit.button("", "gray", "eye")
	_xray_btn.custom_minimum_size = Vector2(26, 22)
	_xray_btn.tooltip_text = "สลับมุมมอง ผ่าซีก (X-RAY) / เปลือกนอก"
	_xray_btn.toggle_mode = true
	_xray_btn.button_pressed = true
	_xray_btn.toggled.connect(func(on: bool):
		UIKit.style_button(_xray_btn, "gray" if on else "yellow")
		xray_toggled.emit(on)
		show_toast("มุมมอง: ผ่าซีก X-RAY" if on else "มุมมอง: เปลือกนอก (แตะตัวรถเพื่อส่องข้างใน)", "info"))
	_view_box.add_child(_xray_btn)
	_zoom_btn = UIKit.button("", "gray", "zoom")
	_zoom_btn.custom_minimum_size = Vector2(26, 22)
	_zoom_btn.tooltip_text = "ซูม: อัตโนมัติ / กว้าง / ปกติ"
	_zoom_btn.pressed.connect(func(): zoom_pressed.emit())
	_view_box.add_child(_zoom_btn)
	_settings_btn = UIKit.button("", "gray", "gear")
	_settings_btn.custom_minimum_size = Vector2(26, 22)
	_settings_btn.tooltip_text = "ตั้งค่า / ข้อมูลเวอร์ชัน"
	_settings_btn.pressed.connect(func(): open_settings())
	_view_box.add_child(_settings_btn)
	# tester console: only exists once Dev is unlocked (debug build, ?god=1, or 7 taps on the VAULT chip)
	_god_btn = UIKit.button("GOD", "gray")
	_god_btn.custom_minimum_size = Vector2(34, 22)
	_god_btn.add_theme_font_override("font", UIKit.font_pixel)
	_god_btn.add_theme_font_size_override("font_size", UIKit.FP)
	_god_btn.pressed.connect(func(): open_panel("god"))
	_view_box.add_child(_god_btn)
	Dev.changed.connect(_sync_god_btn)
	_sync_god_btn()
	add_child(_view_box)
	toast_box = UIKit.vbox(2)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)
	_build_banner()
	resized.connect(_apply_layout)

	room_closeup = RoomCloseup.new()
	add_child(room_closeup)
	for k in ["build", "map", "dwellers", "squad", "solar", "inventory", "log", "garage", "skills", "expedition", "nextgen", "god", "door"]:
		var p: ModalPanel
		match k:
			"build": p = BuildPanel.new()
			"map": p = MapPanel.new()
			"dwellers": p = DwellersPanel.new()
			"inventory": p = LootPanel.new()
			"squad": p = SquadPanel.new()
			"solar": p = SolarPanel.new()
			"log": p = LogPanel.new()
			"garage": p = GaragePanel.new()
			"skills": p = SkillPanel.new()
			"expedition": p = ExpeditionPanel.new()
			"nextgen": p = NextGenPanel.new()
			"god": p = GodPanel.new()
			"door": p = InspectionPanel.new()
		add_child(p)
		panels[k] = p
	(panels.build as BuildPanel).placement_requested.connect(func(t): build_placement_requested.emit(t))
	event_popup = EventPopup.new()
	add_child(event_popup)
	encounter_popup = EncounterPopup.new()
	add_child(encounter_popup)
	title_screen = TitleScreen.new()
	add_child(title_screen)
	# settings opens from the title menu too, so it sits above the title screen
	settings_panel = SettingsPanel.new()
	add_child(settings_panel)
	panels["settings"] = settings_panel
	title_screen.settings_requested.connect(open_settings)

	Game.resources_changed.connect(_refresh_res)
	Game.travel_changed.connect(_refresh_travel)
	Game.vault_level_changed.connect(func(_l): _refresh_res())
	Game.weather_changed.connect(func(_w): _refresh_weather())
	Game.biome_changed.connect(func(_i, _x): _refresh_travel())
	Game.toast.connect(show_toast)
	Game.event_triggered.connect(func(id): event_popup.show_event(id))
	Game.game_started.connect(func(): _set_hud_visible(true))
	Lore.unlocked.connect(func(_id): _refresh_log_badge())
	Expedition.site_reached.connect(func(id):
		if not any_modal_open():
			open_expedition(id))
	Expedition.expedition_finished.connect(func(_r):
		if encounter_popup.is_open:
			encounter_popup.close()
		if not any_modal_open():
			panels.expedition.open())
	Encounter.encounter_ready.connect(func(_id):
		if not any_modal_open():
			encounter_popup.show_encounter())
	Meta.wrecked.connect(func(): open_nextgen(true))
	Meta.generation_started.connect(func(_g):
		_refresh_res()
		_refresh_travel())
	_set_hud_visible(false)
	_apply_layout.call_deferred()
	# first-run guide sits above every window but lets taps through to them
	tutorial_overlay = TutorialOverlay.new()
	tutorial_overlay.hud = self
	add_child(tutorial_overlay)


func _set_hud_visible(v: bool) -> void:
	for c in [_top, _bottom, _combat_box, _tools, _view_box]:
		c.visible = v
	if v:
		_refresh_res()
		_refresh_travel()
		_refresh_weather()
		_refresh_log_badge()
	layout_changed.emit()


# ------------------------------------------------------------------ building blocks
func _chip_box(line: Color = UIKit.C_LINE_DARK) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UIKit.card_style(Color(0.08, 0.075, 0.07, 0.92), line, 2)
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _res_chip(key: String, icon: String, col: Color) -> PanelContainer:
	var p := _chip_box()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(1)
	p.add_child(v)
	var h := UIKit.hbox(2)
	h.add_child(UIKit.icon_rect(icon, 16))
	var l := UIKit.label("0", UIKit.FP, col, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	v.add_child(h)
	var bar := UIKit.progress(col, 3)
	v.add_child(bar)
	res_labels[key] = l
	res_bars[key] = bar
	return p


func _build_top() -> void:
	_top = UIKit.vbox(2)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	_res_row = UIKit.hbox(2)
	_res_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_res_row)
	for r in RES:
		_res_row.add_child(_res_chip(r[0], r[1], r[2]))
	_info_row = UIKit.hbox(2)
	_info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_info_row)
	# vault level
	var vb := _chip_box(UIKit.C_LINE_DIM)
	lvl_lbl = UIKit.label("VAULT 1", UIKit.FP, UIKit.C_GOLD, true)
	vb.add_child(lvl_lbl)
	vb.mouse_filter = Control.MOUSE_FILTER_STOP
	vb.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			Dev.secret_tap())
	_info_row.add_child(vb)
	# population / happiness
	var pc := _chip_box()
	var ph := UIKit.hbox(2)
	ph.add_child(UIKit.icon_rect("people", 16))
	pop_lbl = UIKit.label("0/0", UIKit.FP, UIKit.C_TEXT, true)
	pop_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(pop_lbl)
	happy_icon = UIKit.icon_rect("happy", 16)
	ph.add_child(happy_icon)
	happy_lbl = UIKit.label("0%", UIKit.FP, UIKit.C_GOLD, true)
	happy_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(happy_lbl)
	pc.add_child(ph)
	_info_row.add_child(pc)
	# weather (tap -> solar system)
	var wb := _chip_box()
	wb.mouse_filter = Control.MOUSE_FILTER_STOP
	wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wh := UIKit.hbox(2)
	tod_icon = UIKit.icon_rect("sun", 16)
	wh.add_child(tod_icon)
	weather_icon = UIKit.icon_rect("rain", 16)
	wh.add_child(weather_icon)
	weather_lbl = UIKit.label("", UIKit.FS_SMALL, UIKit.C_TEXT)
	weather_lbl.clip_text = true
	weather_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh.add_child(weather_lbl)
	wb.add_child(wh)
	wb.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			open_panel("solar"))
	_info_row.add_child(wb)
	# status
	var sb := _chip_box()
	status_lbl = UIKit.label("DRIVING", UIKit.FP, UIKit.C_ORANGE, true)
	sb.add_child(status_lbl)
	_info_row.add_child(sb)
	# route
	_route_row = UIKit.hbox(4)
	_route_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(_route_row)
	biome_lbl = UIKit.label("", UIKit.FS_SMALL, UIKit.C_GOLD)
	_route_row.add_child(biome_lbl)
	biome_bar = BiomeBar.new()
	biome_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	biome_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_route_row.add_child(biome_bar)
	_haz_box = UIKit.hbox(0)
	_haz_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_haz_box.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			open_panel("map"))
	_route_row.add_child(_haz_box)


func _build_bottom() -> void:
	_bottom = UIKit.vbox(2)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bottom)
	_travel = _chip_box(UIKit.C_LINE_DIM)
	_travel.mouse_filter = Control.MOUSE_FILTER_STOP
	var th := UIKit.hbox(4)
	_travel.add_child(th)
	go_btn = UIKit.button("", "green", "pause")
	go_btn.custom_minimum_size = Vector2(26, 22)
	go_btn.pressed.connect(func(): Game.set_traveling(not Game.s.traveling))
	th.add_child(go_btn)
	_scav_btn = UIKit.button("", "yellow", "explore")
	_scav_btn.custom_minimum_size = Vector2(26, 22)
	_scav_btn.tooltip_text = "ส่งทีมสำรวจรอบๆ"
	_scav_btn.pressed.connect(func(): open_expedition("scav"))
	th.add_child(_scav_btn)
	var tv := UIKit.vbox(1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(tv)
	var r1 := UIKit.hbox(6)
	speed_lbl = UIKit.label("0 KM/H", UIKit.FP, UIKit.C_TEXT, true)
	r1.add_child(speed_lbl)
	dist_lbl = UIKit.label("0.0 KM", UIKit.FP, UIKit.C_DIM, true)
	r1.add_child(dist_lbl)
	tv.add_child(r1)
	var hh := UIKit.hbox(3)
	hh.add_child(UIKit.label("HULL", UIKit.FP, UIKit.C_DIM, true))
	hull_bar = UIKit.progress(UIKit.C_GREEN, 4)
	hull_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hull_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(hull_bar)
	tv.add_child(hh)
	_exp_box = _chip_box(UIKit.C_GOLD)
	_exp_box.mouse_filter = Control.MOUSE_FILTER_STOP
	var eh := UIKit.hbox(4)
	_exp_box.add_child(eh)
	eh.add_child(UIKit.icon_rect("explore", 16))
	_exp_lbl = UIKit.label("", UIKit.FS_SMALL, UIKit.C_GOLD)
	_exp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exp_lbl.clip_text = true
	eh.add_child(_exp_lbl)
	_exp_btn = UIKit.button("เปิด", "yellow")
	_exp_btn.custom_minimum_size = Vector2(40, 20)
	_exp_btn.pressed.connect(func():
		if Encounter.pending():
			open_encounter()
		elif Expedition.active():
			panels.expedition.open()
		elif Expedition.at_site() != "":
			open_expedition(Expedition.at_site()))
	eh.add_child(_exp_btn)
	_exp_box.visible = false
	# v4.4 a stranger knocking: blinking red strip above the travel bar until someone answers the door
	_door_box = _chip_box(UIKit.C_RED)
	_door_box.mouse_filter = Control.MOUSE_FILTER_STOP
	var dh := UIKit.hbox(4)
	_door_box.add_child(dh)
	dh.add_child(UIKit.icon_rect("people", 16))
	_door_lbl = UIKit.label("", UIKit.FS_SMALL, UIKit.C_RED)
	_door_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_door_lbl.clip_text = true
	dh.add_child(_door_lbl)
	var door_btn := UIKit.button("ตรวจ", "red", "eye")
	door_btn.custom_minimum_size = Vector2(48, 20)
	door_btn.pressed.connect(open_door)
	dh.add_child(door_btn)
	_door_box.visible = false
	_bottom.add_child(_door_box)
	_bottom.add_child(_exp_box)
	_bottom.add_child(_travel)
	_tools = BoxContainer.new()
	_tools.add_theme_constant_override("separation", 2)
	add_child(_tools)
	for t in TOOLS:
		var b := UIKit.tool_button(t[0], t[1], t[3])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = t[2]
		b.pressed.connect(func(): open_panel(key))
		_tools.add_child(b)
		_tool_buttons[key] = b
	_log_badge = UIKit.label("NEW", UIKit.FP, UIKit.C_GOLD, true)
	_log_badge.add_theme_constant_override("outline_size", 2)
	_log_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_log_badge.position = Vector2(2, -2)
	_log_badge.visible = false
	(_tool_buttons.log as Button).add_child(_log_badge)


func _build_combat_chip() -> void:
	_combat_box = _chip_box(Color("9c2426"))
	_combat_box.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := UIKit.hbox(3)
	_combat_box.add_child(h)
	h.add_child(UIKit.icon_rect("sword", 16))
	var v := UIKit.vbox(0)
	_wave_lbl = UIKit.label("WAVE 1", UIKit.FP, UIKit.C_TEXT, true)
	v.add_child(_wave_lbl)
	_wave_sub = UIKit.label("", UIKit.FP, UIKit.C_DIM, true)
	v.add_child(_wave_sub)
	h.add_child(v)
	_push_btn = UIKit.button("", "yellow")
	_push_btn.custom_minimum_size = Vector2(38, 20)
	_push_btn.add_theme_font_override("font", UIKit.font_pixel)
	_push_btn.add_theme_font_size_override("font_size", UIKit.FP)
	_push_btn.pressed.connect(func(): Combat.set_push(not bool(Game.s.combat.push)))
	h.add_child(_push_btn)
	_boss_btn = UIKit.button("", "red", "crown")
	_boss_btn.custom_minimum_size = Vector2(24, 20)
	_boss_btn.tooltip_text = "ท้าบอสด่านตรวจ"
	_boss_btn.pressed.connect(Combat.challenge_warlord)
	_boss_btn.visible = false
	h.add_child(_boss_btn)
	add_child(_combat_box)
	Combat.wave_changed.connect(_refresh_combat)


func _build_banner() -> void:
	banner = PanelContainer.new()
	banner.add_theme_stylebox_override("panel", UIKit.card_style(Color(0.12, 0.08, 0.03, 0.95), UIKit.C_GOLD, 4))
	var h := UIKit.hbox(4)
	banner.add_child(h)
	banner_lbl = UIKit.label("", UIKit.FS_SMALL, UIKit.C_GOLD)
	banner_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_lbl.custom_minimum_size.x = 200
	h.add_child(banner_lbl)
	var cancel := UIKit.button("ยกเลิก", "gray", "close")
	cancel.pressed.connect(func(): build_placement_cancelled.emit())
	h.add_child(cancel)
	banner.visible = false
	add_child(banner)


# ------------------------------------------------------------------ layout
const M := 4


func _apply_layout() -> void:
	if _top == null:
		return
	var vp := size
	_portrait = vp.y >= vp.x
	if _portrait:
		_top.position = Vector2(M, M)
		_top.size = Vector2(vp.x - M * 2, 0)
		_top.custom_minimum_size.x = vp.x - M * 2
		_route_row.visible = true
		_tools.vertical = false
		_tools.custom_minimum_size = Vector2(vp.x - M * 2, 40)
		_tools.size = Vector2(vp.x - M * 2, 40)
		_tools.position = Vector2(M, vp.y - 40 - M)
		_bottom.custom_minimum_size.x = vp.x - M * 2
		_bottom.size = Vector2(vp.x - M * 2, 0)
		_bottom.reset_size()
		_bottom.position = Vector2(M, _tools.position.y - _bottom.size.y - 2)
		_top.reset_size()
		_pin_right(_combat_box, M, _top.position.y + _top.size.y + 2)
		_view_box.position = Vector2(M, _top.position.y + _top.size.y + 2)
		boss_bar.position = Vector2(M, _top.position.y + _top.size.y + 28)
		boss_bar.size = Vector2(vp.x - M * 2, 32)
	else:
		_top.position = Vector2(M, M)
		_top.custom_minimum_size.x = vp.x - 52 - M * 2
		_top.size = Vector2(vp.x - 52 - M * 2, 0)
		_route_row.visible = true
		_tools.vertical = true
		_tools.custom_minimum_size = Vector2(44, vp.y - M * 2)
		_tools.size = Vector2(44, vp.y - M * 2)
		_tools.position = Vector2(vp.x - 44 - M, M)
		_bottom.custom_minimum_size.x = 200
		_bottom.reset_size()
		_bottom.position = Vector2(M, vp.y - _bottom.size.y - M)
		_top.reset_size()
		_pin_right(_combat_box, 52 + M, _top.position.y + _top.size.y + 2)
		_view_box.position = Vector2(M, _top.position.y + _top.size.y + 2)
		boss_bar.position = Vector2(M + 60, _top.position.y + _top.size.y + 2)
		boss_bar.size = Vector2(vp.x - 52 - M * 2 - 160, 32)
	_place_toasts()
	if banner.visible:
		show_banner(banner_lbl.text)
	layout_changed.emit()


## anchor to the top-right corner and grow to the left, so changing text never pushes it off-screen
func _pin_right(c: Control, right: float, top: float) -> void:
	c.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	c.offset_right = -right
	c.offset_left = -right
	c.offset_top = top
	c.offset_bottom = top


## the part of the screen the world camera should frame (design px)
func world_rect() -> Rect2:
	var vp := size if size.x > 0 else get_viewport_rect().size
	if not Game.started or not _top.visible:
		return Rect2(Vector2(0, 0), vp - Vector2(0, 150))
	if vp.y >= vp.x:
		var top := _combat_box.position.y + _combat_box.size.y + 2
		var bottom := _bottom.position.y - 2
		return Rect2(0, top, vp.x, bottom - top)
	return Rect2(0, 0, vp.x - 52, vp.y - 2)


func _place_toasts() -> void:
	toast_box.reset_size()
	var y := _top.position.y + _top.size.y + 26 if _top.visible else 40.0
	if boss_bar.visible:
		y = maxf(y, boss_bar.position.y + boss_bar.H + 4.0)
	if _closeup_on:
		y = size.y - toast_box.size.y - 8
	toast_box.position = Vector2(floorf((size.x - toast_box.size.x) * 0.5), floorf(y))


func show_banner(text: String) -> void:
	banner_lbl.text = text
	banner.visible = text != ""
	if banner.visible:
		banner_lbl.custom_minimum_size.x = minf(240.0, size.x - 110)
		banner.reset_size()
		var y := _bottom.position.y - banner.size.y - 4 if _portrait else size.y - banner.size.y - 40
		banner.position = Vector2(floorf((size.x - banner.size.x) * 0.5), floorf(y))


# ------------------------------------------------------------------ refresh
var _combat_t := 0.0


func _process(d: float) -> void:
	if not Game.started:
		return
	_combat_t -= d
	if _combat_t <= 0.0:
		_combat_t = 0.5
		_refresh_combat()
		if boss_bar.visible != _boss_was:
			_boss_was = boss_bar.visible
			_place_toasts()
		speed_lbl.text = "%d KM/H" % int(round(Game.speed_kmh()))
		var stage_km: float = float(Game.s.km) - Data.biome_start_km(Game.s.biome)
		dist_lbl.text = "%.1f/%d KM" % [stage_km, int(Data.biome(Game.s.biome).length)]
		tod_icon.texture = Atlas.icon("moon" if Game.is_night() else "sun")
		_refresh_status()
		_refresh_hazards()
		_refresh_expedition()
		_refresh_door()


func _refresh_res() -> void:
	if Game.s.is_empty():
		return
	for k in res_labels:
		var v: float = Game.s.res[k]
		var c: float = Game.cap(k)
		res_labels[k].text = "%s/%s" % [UIKit.fmt(v), UIKit.fmt(c)]
		res_bars[k].value = v / c
		res_labels[k].modulate = Color(1, 0.4, 0.4) if v < c * 0.1 else Color.WHITE
	lvl_lbl.text = "VAULT %d" % int(Game.s.vault_level)
	pop_lbl.text = "%d/%d" % [Game.s.dwellers.size(), Game.pop_cap()]
	var h := Game.avg_happiness()
	happy_lbl.text = "%d%%" % int(h)
	happy_icon.texture = Atlas.icon("happy" if h >= 50 else "sad")


func _refresh_travel() -> void:
	if Game.s.is_empty():
		return
	var b := Data.biome(Game.s.biome)
	biome_lbl.text = b.th + ((" ·รอบ%d" % (int(Game.s.lap) + 1)) if int(Game.s.lap) > 0 else "")
	hull_bar.value = float(Game.s.hull) / Game.hull_max()
	var fill := StyleBoxFlat.new()
	var hp := hull_bar.value
	fill.bg_color = UIKit.C_GREEN if hp > 0.5 else (UIKit.C_GOLD if hp > 0.25 else UIKit.C_RED)
	hull_bar.add_theme_stylebox_override("fill", fill)
	go_btn.icon = Atlas.icon("pause" if Game.s.traveling else "play")
	UIKit.style_button(go_btn, "gray" if Game.s.traveling else "green")
	_refresh_status()


func _refresh_status() -> void:
	var txt := "DRIVING"
	var col := UIKit.C_ORANGE
	var br := Game.blocked_reason()
	if Game.active_event != "":
		txt = "DANGER!"
		col = UIKit.C_RED
	elif Game.closeup_slot >= 0:
		txt = "MANAGE"
		col = UIKit.C_BLUE
	elif not Game.s.traveling:
		txt = "PARKED"
		col = UIKit.C_DIM
	elif br != "":
		txt = "STOPPED"
		col = UIKit.C_RED
	if status_lbl.text != txt:
		status_lbl.text = txt
		status_lbl.add_theme_color_override("font_color", col)
	status_lbl.tooltip_text = br


func _refresh_hazards() -> void:
	var a := Env.active()
	var key := str(a)
	if key == _haz_key:
		return
	_haz_key = key
	for c in _haz_box.get_children():
		c.queue_free()
	for h in a:
		var ic := UIKit.icon_rect(Env.HAZARDS[h].icon, 16)
		ic.tooltip_text = "%s Lv%d" % [Env.HAZARDS[h].th, int(a[h])]
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		_haz_box.add_child(ic)


func _refresh_expedition() -> void:
	var show := Expedition.active() or Expedition.at_site() != ""
	if _exp_box.visible != show:
		_exp_box.visible = show
		_apply_layout.call_deferred()
	_scav_btn.disabled = Expedition.active() or Game.s.get("wrecked", false)
	if Expedition.active():
		var tl := Expedition.time_left()
		_exp_lbl.text = "ทีมสำรวจ %s · %d:%02d" % [Expedition.site_def(str(Expedition.state().site)).th, int(tl) / 60, int(tl) % 60]
		_exp_btn.text = "ดู"
		if Encounter.pending():
			_exp_lbl.text = "จุดพิเศษ! ทีมรอคำสั่ง · %d:%02d" % [int(tl) / 60, int(tl) % 60]
			_exp_btn.text = "สั่งการ"
	elif Expedition.at_site() != "":
		_exp_lbl.text = "พบ %s!" % Expedition.site_def(Expedition.at_site()).th
		_exp_btn.text = "สำรวจ"
	if float(Game.s.get("wreck_t", 0.0)) > 0.0 and float(Game.s.hull) <= 0.0:
		status_lbl.text = "WRECK %d" % int(Meta.wreck_time_left())
		status_lbl.add_theme_color_override("font_color", UIKit.C_RED)


func _refresh_door() -> void:
	var show := Inspection.pending()
	if _door_box.visible != show:
		_door_box.visible = show
		_apply_layout.call_deferred()
	if show:
		var c := Inspection.current()
		_door_lbl.text = "มีคนเคาะประตู! %s [%s] · %s" % [c.name, Inspection.GRADES[c.grade].th, Game.fmt_time(float(c.wait))]
		_door_box.modulate.a = 1.0 if int(Time.get_ticks_msec() / 500) % 2 == 0 else 0.75


func open_door() -> void:
	if not Game.started:
		return
	for k in panels:
		if panels[k].is_open:
			panels[k].close()
	(panels.door as InspectionPanel).open_door()


func open_expedition(site_id: String) -> void:
	if not Game.started:
		return
	for k in panels:
		if panels[k].is_open:
			panels[k].close()
	if Expedition.active():
		panels.expedition.open()
	else:
		(panels.expedition as ExpeditionPanel).open_site(site_id)


func open_encounter() -> void:
	if not Encounter.pending():
		return
	for k in panels:
		if panels[k].is_open:
			panels[k].close()
	encounter_popup.show_encounter()


func open_nextgen(forced: bool) -> void:
	for k in panels:
		if panels[k].is_open and k != "nextgen":
			panels[k].close()
	if room_closeup.is_open:
		room_closeup.close()
	(panels.nextgen as NextGenPanel).open_retire(forced)


func open_skills(did: int) -> void:
	(panels.skills as SkillPanel).open_for(did)


func _refresh_weather() -> void:
	if Game.s.is_empty():
		return
	var w := Game.weather_def()
	weather_icon.texture = Atlas.icon(w.icon)
	weather_lbl.text = w.th


func _refresh_log_badge() -> void:
	if Game.s.is_empty():
		return
	var seen := int(Game.s.get("lore_seen", 0))
	_log_badge.visible = Lore.count_open() > seen


# ------------------------------------------------------------------ toasts & panels
var _last_toast := ""
var _last_toast_t := 0


func show_toast(text: String, kind: String = "info") -> void:
	var now := Time.get_ticks_msec()
	if text == _last_toast and now - _last_toast_t < 6000:
		return
	_last_toast = text
	_last_toast_t = now
	var col: Color = {"good": UIKit.C_GREEN, "warn": UIKit.C_ORANGE, "biome": UIKit.C_GOLD, "bad": UIKit.C_RED}.get(kind, UIKit.C_LINE)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.card_style(Color(0.08, 0.075, 0.07, 0.94), col, 3))
	var l := UIKit.label(text, UIKit.FS_SMALL, col.lightened(0.35))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = minf(320.0, size.x - 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	while toast_box.get_child_count() > 3:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(3.2 if kind != "biome" else 5.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	_place_toasts.call_deferred()


func _refresh_combat() -> void:
	if Game.s.is_empty() or _wave_lbl == null:
		return
	var w := Combat.wave()
	var boss := Combat.wave_is_warlord
	_wave_lbl.text = ("WARLORD!" if boss else ("BOSS W%d" % w if Combat.is_boss_wave(w) else "WAVE %d" % w))
	_wave_lbl.add_theme_color_override("font_color", UIKit.C_RED if boss or Combat.is_boss_wave(w) else UIKit.C_TEXT)
	var lv := Combat.warlord_level() if boss else Combat.enemy_level()
	_wave_sub.text = "LV%d DPS%d" % [lv, int(Combat.dps_meter)]
	var push := bool(Game.s.combat.push)
	_push_btn.text = "PUSH" if push else "FARM"
	UIKit.style_button(_push_btn, "yellow" if push else "blue")
	_push_btn.tooltip_text = "PUSH = ชนะแล้วขึ้นเวฟถัดไป · FARM = วนเวฟเดิมเก็บของ"
	var show_boss := Game.at_checkpoint() and not Combat.boss_beaten(int(Game.s.biome)) and not Combat.wave_is_warlord
	if _boss_btn.visible != show_boss:
		_boss_btn.visible = show_boss
		_apply_layout.call_deferred()


## while the camera is zoomed into a room only the resource strip stays on screen
func set_closeup_mode(on: bool) -> void:
	if not Game.started:
		return
	for c in [_info_row, _route_row, _combat_box, _bottom, _tools]:
		c.visible = not on
	_top.reset_size()
	_closeup_on = on
	_place_toasts()


func open_loot_pick(slot: String, did: int) -> void:
	(panels.inventory as LootPanel).open_pick(slot, did)


func open_loot_equipped(item: Dictionary, did: int) -> void:
	(panels.inventory as LootPanel).open_equipped(item, did)


func open_panel(key: String) -> void:
	if not Game.started:
		return
	if room_closeup.is_open:
		room_closeup.close()
	for k in panels:
		if k != key and panels[k].is_open:
			panels[k].close()
	panels[key].open()
	if key == "log":
		Game.s["lore_seen"] = Lore.count_open()
		_refresh_log_badge()


## works before a run has started (title menu), unlike open_panel()
func open_settings(tab: String = "game") -> void:
	if room_closeup.is_open:
		room_closeup.close()
	for k in panels:
		if k != "settings" and panels[k].is_open:
			panels[k].close()
	settings_panel.open_tab(tab)


func any_modal_open() -> bool:
	for k in panels:
		if panels[k].is_open:
			return true
	return event_popup.is_open or encounter_popup.is_open or title_screen.visible


func _sync_god_btn() -> void:
	_god_btn.visible = Dev.unlocked
	UIKit.style_button(_god_btn, "red" if Dev.any_active() else "gray")


func _unhandled_key_input(e: InputEvent) -> void:
	if Dev.unlocked and e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_F1 or e.keycode == KEY_QUOTELEFT):
		if panels.god.is_open:
			panels.god.close()
		else:
			open_panel("god")
