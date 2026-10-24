class_name MapPanel
extends ModalPanel
## Route map: biome stages, checkpoints (vault level gates), lap, weather, travel toggle.

var _list: VBoxContainer
var _summary: Label
var _go: Button


func _build() -> void:
	set_title("WASTELAND ROUTE / แผนที่เส้นทาง")
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
	_list = make_list(3)


func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var w := Game.weather_def()
	_summary.text = "รอบที่ %d · ระยะรวม %.1f กม. · ความเร็ว %d km/h · อากาศ: %s (อีก ~%ds)\n%s" % [
		int(Game.s.lap) + 1, float(Game.s.stats.km_total), int(Game.speed_kmh()), w.th, int(Game.s.weather_t),
		("สถานะ: " + Game.blocked_reason()) if Game.blocked_reason() != "" else "ทางโล่ง รถกำลังวิ่ง"]
	_go.text = "จอด" if Game.s.traveling else "ออกรถ"
	_go.icon = Atlas.icon("pause" if Game.s.traveling else "play")
	# hazards now
	var rep := Env.report()
	_list.add_child(UIKit.header("HAZARDS", "ภัยตอนนี้" if not rep.is_empty() else "ไม่มีภัยพิเศษตอนนี้"))
	for hz in rep:
		var hp := UIKit.panel(UIKit.C_BG2, Color(hz.col).darkened(0.4))
		var hh := UIKit.hbox(4)
		hp.add_child(hh)
		hh.add_child(UIKit.icon_rect(hz.icon, 16))
		var hv := UIKit.vbox(0)
		hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hv.add_child(UIKit.label("%s Lv%d" % [hz.th, int(hz.lvl)], UIKit.FS_SMALL, Color(hz.col)))
		hv.add_child(UIKit.wrap_label(hz.tip, UIKit.FS_SMALL, UIKit.C_TEXT))
		hv.add_child(UIKit.wrap_label("รับมือ: " + hz.fix, UIKit.FS_SMALL))
		hh.add_child(hv)
		_list.add_child(hp)
	if Env.level("cold") > 0:
		_list.add_child(UIKit.label("ใช้เชื้อเพลิงทำความร้อน %.1f/นาที" % Env.heating_fuel_pm(), UIKit.FS_SMALL, UIKit.C_ORANGE))
	_list.add_child(UIKit.header("ROUTE", "เส้นทาง · จุดสำรวจ"))
	for i in Data.BIOMES.size():
		var b: Dictionary = Data.BIOMES[i]
		var cur := i == int(Game.s.biome)
		var done := i < int(Game.s.biome)
		var locked := int(b.req) > int(Game.s.vault_level)
		var col := UIKit.C_GOLD if cur else (UIKit.C_LINE_DIM if done else (UIKit.C_RED if locked else UIKit.C_LINE))
		var p := UIKit.panel(UIKit.C_BG2, col.darkened(0.3))
		var h := UIKit.hbox(4)
		p.add_child(h)
		var tex: Texture2D
		if not Background.v2_layout(b.id).is_empty():
			tex = load(Background.V2_DIR + "%s_thumb.png" % b.id)
		else:
			var at := AtlasTexture.new()
			at.atlas = load("res://assets/bg/%s_far.png" % b.id)
			at.region = Rect2(150, 230, 56, 56)
			tex = at
		var thumb := UIKit.tex_rect(tex, Vector2(56, 56))
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
		v.add_child(UIKit.wrap_label("%.0f กม. · เศษเหล็ก +%.1f/นาที · อันตราย %d · %s" % [b.length, b.scrap_pm, int(b.danger) + int(Game.s.lap), ", ".join(wnames)], UIKit.FS_SMALL, UIKit.C_DIM))
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
			sites.append(Expedition.SITES[sid].th + (" (สำรวจแล้ว)" if Expedition.is_done(sid) else ""))
		v.add_child(UIKit.wrap_label(("ภัย: %s · " % ", ".join(hz_names) if not hz_names.is_empty() else "") + "จุดสำรวจ: " + ", ".join(sites), UIKit.FS_SMALL, UIKit.C_GOLD))
		_list.add_child(p)
	_list.add_child(UIKit.wrap_label("เมื่อผ่านมหานครแห่งสัญญาณ รถบ้านจะวนกลับซากนิคมอุตสาหกรรมในรอบใหม่ — ศัตรูอันตรายขึ้นแต่รางวัลมากขึ้น"))
	_list.add_child(UIKit.header("NEXT GENERATION", "รุ่นที่ %d · %s · แต้มวิจัย %d" % [Meta.generation(), Meta.vehicle_name(), int(Meta.m().get("legacy", 0))]))
	var rb := UIKit.button("ปลดระวางรถ → สร้างรุ่นถัดไป", "red", "hammer")
	rb.disabled = not Meta.can_retire()
	rb.pressed.connect(func():
		close()
		(get_parent() as HUD).open_nextgen(false))
	_list.add_child(rb)
	if not Meta.can_retire():
		_list.add_child(UIKit.wrap_label("ปลดล็อกหลังปราบบอสด่านตรวจแรก · ถ้ารถพังถาวร (ตัวถัง 0% เกิน 2 นาที) จะเข้าสู่รุ่นถัดไปอัตโนมัติ"))
