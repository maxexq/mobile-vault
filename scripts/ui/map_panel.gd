class_name MapPanel
extends ModalPanel
## Route map: biome stages, checkpoints (vault level gates), lap, weather, travel toggle.
## MV-515: with the seeded world map (switch seeded_world_map + a world), the stage list is replaced by WorldMapView and
## one destination strip (stop, region, distance / time, danger, what is known, Drive). Park / resume, weather,
## blockers, hazards, the lap note and the next generation stay. Selecting a stop never drives; only Drive does.

var _list: VBoxContainer
var _summary: Label
var _go: Button
var map_view: WorldMapView
var _strip: VBoxContainer
var _dest_title: Label
var _dest_info: Label
var _dest_note: Label
var drive_btn: Button


func _build() -> void:
	set_title(Loc.t("WASTELAND ROUTE / แผนที่เส้นทาง"))
	var top := UIKit.hbox(4)
	_summary = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_TEXT)
	top.add_child(_summary)
	_go = UIKit.button("", "green", "play")
	_go.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_go.pressed.connect(func():
		Game.set_traveling(not Game.s.traveling)
		refresh())
	top.add_child(_go)
	body.add_child(top)
	# MV-515: the world map and its destination strip (shown only in map mode)
	map_view = WorldMapView.new()
	map_view.name = "WorldMap"
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.stop_selected.connect(func(_id): _refresh_strip())
	body.add_child(map_view)
	_strip = UIKit.vbox(1)
	_strip.name = "DestinationStrip"
	_dest_title = UIKit.label("", UIKit.FS, UIKit.C_GOLD)
	_strip.add_child(_dest_title)
	_dest_info = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_TEXT)
	_strip.add_child(_dest_info)
	var dh := UIKit.hbox(4)
	_dest_note = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_DIM)
	_dest_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(_dest_note)
	drive_btn = UIKit.button(Loc.t("ขับไป"), "green", "play")
	drive_btn.name = "DriveRoute"
	drive_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	drive_btn.pressed.connect(_drive)
	dh.add_child(drive_btn)
	_strip.add_child(dh)
	body.add_child(_strip)
	_list = make_list(3)


func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var map_on := Game.map_mode()
	map_view.visible = map_on
	_strip.visible = map_on
	if map_on:
		_refresh_strip()
	var w := Game.weather_def()
	_summary.text = Loc.t("รอบที่ %d · ระยะรวม %.1f กม. · ความเร็ว %d km/h · อากาศ: %s (อีก ~%ds)\n%s") % [
		int(Game.s.lap) + 1, float(Game.s.stats.km_total), int(Game.speed_kmh()), w.th, int(Game.s.weather_t),
		(Loc.t("สถานะ: ") + Game.blocked_reason()) if Game.blocked_reason() != "" else Loc.t("ทางโล่ง รถกำลังวิ่ง")]
	_go.text = Loc.t("จอด") if Game.s.traveling else Loc.t("ออกรถ")
	_go.icon = Atlas.icon("pause" if Game.s.traveling else "play")
	# hazards now
	var rep := Env.report()
	_list.add_child(UIKit.header("HAZARDS", Loc.t("ภัยตอนนี้") if not rep.is_empty() else Loc.t("ไม่มีภัยพิเศษตอนนี้")))
	for hz in rep:
		var hp := UIKit.panel(UIKit.C_BG2, Color(hz.col).darkened(0.4))
		var hh := UIKit.hbox(4)
		hp.add_child(hh)
		hh.add_child(UIKit.icon_rect(hz.icon, 16))
		var hv := UIKit.vbox(0)
		hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hv.add_child(UIKit.label("%s Lv%d" % [hz.th, int(hz.lvl)], UIKit.FS_SMALL, Color(hz.col)))
		hv.add_child(UIKit.wrap_label(hz.tip, UIKit.FS_SMALL, UIKit.C_TEXT))
		hv.add_child(UIKit.wrap_label(Loc.t("รับมือ: ") + hz.fix, UIKit.FS_SMALL))
		hh.add_child(hv)
		_list.add_child(hp)
	if Env.level("cold") > 0:
		_list.add_child(UIKit.label(Loc.t("ใช้เชื้อเพลิงทำความร้อน %.1f/นาที") % Env.heating_fuel_pm(), UIKit.FS_SMALL, UIKit.C_ORANGE))
	if map_on:
		_list.add_child(UIKit.wrap_label(Loc.t("รอบที่ %d · โลก seed %s · แตะจุดบนแผนที่เพื่อดูเส้นทาง แล้วกดขับไป · ผ่านทางออกในมหานครแห่งสัญญาณ = รอบใหม่ในโลกใหม่ ศัตรูอันตรายขึ้นแต่รางวัลมากขึ้น") % [
			int(Game.s.lap) + 1, str(WorldMap.world().seed)]))
	for i in (0 if map_on else Data.BIOMES.size()):
		if i == 0:
			_list.add_child(UIKit.header("ROUTE", Loc.t("เส้นทาง · จุดสำรวจ")))
		var b: Dictionary = Data.BIOMES[i]
		var cur := i == int(Game.s.biome)
		var done := i < int(Game.s.biome)
		var locked := int(b.req) > int(Game.s.vault_level)
		var col := UIKit.C_GOLD if cur else (UIKit.C_LINE_DIM if done else (UIKit.C_RED if locked else UIKit.C_LINE))
		var p := UIKit.panel(UIKit.C_BG2, col.darkened(0.3))
		var h := UIKit.hbox(4)
		p.add_child(h)
		var at := AtlasTexture.new()
		at.atlas = load("res://assets/bg/%s_far.png" % b.id)
		at.region = Rect2(150, 230, 56, 56)
		var thumb := UIKit.tex_rect(at, Vector2(56, 56))
		if locked:
			thumb.modulate = Color(0.4, 0.4, 0.4)
		h.add_child(thumb)
		var v := UIKit.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label("%d.%s" % [i + 1, b.en], UIKit.FP, col.lightened(0.3), true))
		v.add_child(UIKit.label(b.th, UIKit.FS, col.lightened(0.3)))
		var wnames := []
		for k in b.weather:
			wnames.append(Data.WEATHER[k].th)
		v.add_child(UIKit.wrap_label(Loc.t("%.0f กม. · เศษเหล็ก +%.1f/นาที · อันตราย %d · %s") % [b.length, b.scrap_pm, int(b.danger) + int(Game.s.lap), ", ".join(wnames)], UIKit.FS_SMALL, UIKit.C_DIM))
		if cur:
			var pr := UIKit.progress(UIKit.C_GOLD, 4)
			pr.value = (float(Game.s.km) - Data.biome_start_km(i)) / float(b.length)
			v.add_child(pr)
		h.add_child(v)
		var st := "DONE" if done else ("HERE" if cur else ("VAULT %d" % b.req if locked else "OPEN"))
		var stl := UIKit.label(st, UIKit.FP, col.lightened(0.3), true)
		h.add_child(stl)
		if locked:
			h.add_child(UIKit.icon_rect("lock", 16))
		var hz_names := []
		for k in Env.BIOME.get(b.id, {}):
			hz_names.append(Env.HAZARDS[k].th)
		var sites := []
		for sid in Expedition.biome_sites(i):
			sites.append(Expedition.SITES[sid].th + (Loc.t(" (สำรวจแล้ว)") if Expedition.is_done(sid) else ""))
		v.add_child(UIKit.wrap_label((Loc.t("ภัย: %s · ") % ", ".join(hz_names) if not hz_names.is_empty() else "") + Loc.t("จุดสำรวจ: ") + ", ".join(sites), UIKit.FS_SMALL, UIKit.C_GOLD))
		_list.add_child(p)
	if not map_on:
		_list.add_child(UIKit.wrap_label(Loc.t("เมื่อผ่านมหานครแห่งสัญญาณ รถบ้านจะวนกลับซากนิคมอุตสาหกรรมในรอบใหม่ — ศัตรูอันตรายขึ้นแต่รางวัลมากขึ้น")))
	_list.add_child(UIKit.header("NEXT GENERATION", Loc.t("รุ่นที่ %d · %s · แต้มวิจัย %d") % [Meta.generation(), Meta.vehicle_name(), int(Meta.m().get("legacy", 0))]))
	var rb := UIKit.button(Loc.t("ปลดระวางรถ → สร้างรุ่นถัดไป"), "red", "hammer")
	rb.disabled = not Meta.can_retire()
	rb.pressed.connect(func():
		close()
		(get_parent() as HUD).open_nextgen(false))
	_list.add_child(rb)
	if not Meta.can_retire():
		_list.add_child(UIKit.wrap_label(Loc.t("ปลดล็อกหลังปราบบอสด่านตรวจแรก · ถ้ารถพังถาวร (ตัวถัง 0% เกิน 2 นาที) จะเข้าสู่รุ่นถัดไปอัตโนมัติ")))


# =================================================================== MV-515: the destination strip
## what the selected stop is, how far, roughly how long, how dangerous, what is known, and whether Drive can go
func _refresh_strip() -> void:
	var id := map_view.selected
	if id == "":
		_dest_title.text = Loc.t("แตะจุดบนแผนที่เพื่อเลือกปลายทาง")
		_dest_info.text = Loc.t("อยู่ที่: %s") % map_view.label_of(WorldMap.here())
		_dest_note.text = ""
		drive_btn.disabled = true
		return
	var n := WorldMap.node(id)
	var b := Data.biome(int(n.biome))
	_dest_title.text = map_view.label_of(id)
	var rt := map_view.route()
	var rate := Data.BASE_TRAVEL_KMPM * (Game.speed_factor() if Game.speed_factor() > 0.0 else 1.0)
	var info := "%s · %s" % [str(b.th), Loc.t("อันตราย %d") % (int(b.danger) + int(Game.s.lap))]
	if not rt.is_empty():
		info = Loc.t("%.1f กม. · ~%d นาที · ") % [float(rt.km), int(ceil(float(rt.km) / maxf(0.01, rate)))] + info
	_dest_info.text = info
	var note := ""
	match str(n.type):
		"landmark":
			note = str(Expedition.SITES[n.site].goal) + (Loc.t(" (สำรวจแล้วรอบนี้)") if Expedition.is_done(str(n.site)) else "")
		"rumor":
			note = Loc.t("รายงานทางวิทยุ: มีสัญญาณแปลก ๆ แต่ยังไม่รู้ว่าคืออะไร") if not bool(WorldMap.world().visited.get(id, false)) else Loc.t("เคยมาแล้ว ไม่มีอะไรเหลือ")
		"exit":
			note = Loc.t("ผ่านทางออก = เริ่มรอบใหม่ในโลกใหม่ ต้องปราบบอสด่านตรวจของพื้นที่นี้ก่อน")
		_:
			note = Loc.t("ทางแยกบนถนน")
	var why := WorldMap.drive_block(id)
	if map_view.locked(id):
		why = Loc.t("ต้องการ Mobile Vault Lv.%d") % int(b.req)
	if why != "":
		note = why + " · " + note
	_dest_note.text = note
	drive_btn.disabled = why != ""


func _drive() -> void:
	var id := map_view.selected
	if id == "" or not WorldMap.drive_to(id):
		return
	if not Game.s.traveling:
		Game.set_traveling(true)
	refresh()
