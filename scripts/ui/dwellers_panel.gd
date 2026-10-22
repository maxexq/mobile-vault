class_name DwellersPanel
extends ModalPanel
## Crew roster (sort / filter) + per-dweller management: bio (lore), 6 gear slots, squad role,
## room, stimpack / radaway, send to the wasteland.

var sort_key := "lvl"
var filter := "all"
var managing := -1
var _list: VBoxContainer
var _sort_btn: Button
var _filter_btn: Button
var _top: HBoxContainer

const SORTS := ["lvl", "str", "int", "agi", "hp"]
const FILTERS := ["all", "work", "idle", "away"]
const FILTER_TH := {"all": "ทั้งหมด", "work": "ทำงาน", "idle": "ว่าง", "away": "ออกสำรวจ"}


func _build() -> void:
	_top = UIKit.hbox(4)
	body.add_child(_top)
	_sort_btn = UIKit.button("", "blue", "up")
	_sort_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sort_btn.pressed.connect(func():
		sort_key = SORTS[(SORTS.find(sort_key) + 1) % SORTS.size()]
		refresh())
	_top.add_child(_sort_btn)
	_filter_btn = UIKit.button("", "blue", "people")
	_filter_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_btn.pressed.connect(func():
		filter = FILTERS[(FILTERS.find(filter) + 1) % FILTERS.size()]
		refresh())
	_top.add_child(_filter_btn)
	_list = make_list(3)
	Game.dwellers_changed.connect(func(): if is_open: refresh())
	Game.gear_changed.connect(func(): if is_open: refresh())
	Game.squad_changed.connect(func(): if is_open: refresh())


func manage(did: int) -> void:
	managing = did
	refresh()


func close() -> void:
	managing = -1
	super.close()


func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if managing >= 0 and not Game.dweller_by_id(managing).is_empty():
		_top.visible = false
		_build_manage(Game.dweller_by_id(managing))
		return
	managing = -1
	_top.visible = true
	set_title("CREW %d/%d / รายชื่อผู้ลี้ภัย" % [Game.s.dwellers.size(), Game.pop_cap()])
	_sort_btn.text = "เรียง: %s" % sort_key.to_upper()
	_filter_btn.text = FILTER_TH[filter]
	var arr: Array = []
	for d in Game.s.dwellers:
		var away := Game.is_away(d)
		match filter:
			"work":
				if away or int(d.room) < 0: continue
			"idle":
				if away or int(d.room) >= 0: continue
			"away":
				if not away: continue
		arr.append(d)
	var key := sort_key
	arr.sort_custom(func(a, b): return float(a[key]) > float(b[key]))
	for d in arr:
		_list.add_child(_row(d))
	if arr.is_empty():
		_list.add_child(UIKit.wrap_label("ไม่มีผู้ลี้ภัยในหมวดนี้"))


func _where(d: Dictionary) -> Array:
	if Game.is_away(d):
		var left := maxf(0.0, float(d.away_until) - Time.get_unix_time_from_system())
		return ["EXPEDITION %dM%02dS" % [int(left) / 60, int(left) % 60], UIKit.C_ORANGE]
	if Game.squad_role(d) >= 0:
		return [Combat.ROLES[Game.squad_role(d)].en, UIKit.C_RED]
	if Game.is_deck(d):
		return ["ROOF DECK", UIKit.C_RED]
	if int(d.room) >= 0:
		if Game.is_constructing(int(d.room)):
			return ["BUILDING " + Data.room_def(Game.s.rooms[int(d.room)].type).en, UIKit.C_ORANGE]
		return [Data.room_def(Game.s.rooms[int(d.room)].type).en, UIKit.C_GOLD]
	return ["IDLE", UIKit.C_DIM]


func _row(d: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 30)
	b.focus_mode = Control.FOCUS_NONE
	UIKit.style_button(b, "gray")
	b.disabled = Game.is_away(d)
	var h := UIKit.hbox(4)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 3
	h.offset_right = -3
	h.offset_top = 3
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(UIKit.tex_rect(Atlas.tex("pt_" + d.variant), Vector2(20, 20)))
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label("%s%s" % [d.name, ("  [%s]" % Crew.ROLES[Crew.role(d)].th) if Crew.ROLES.has(Crew.role(d)) else ""], UIKit.FS_SMALL, UIKit.C_TEXT))
	var w := _where(d)
	v.add_child(UIKit.label("LV%d · %s" % [d.lvl, w[0]], UIKit.FP, w[1], true))
	h.add_child(v)
	var st := UIKit.label("S%d I%d A%d" % [d.str, d.int, d.agi], UIKit.FP, UIKit.C_DIM, true)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(st)
	var hp := UIKit.progress(UIKit.C_RED if float(d.hp) < float(d.max_hp) * 0.35 else UIKit.C_GREEN, 3)
	hp.value = float(d.hp) / float(d.max_hp)
	hp.custom_minimum_size.x = 24
	hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(hp)
	h.add_child(UIKit.icon_rect("happy" if float(d.happy) >= 50 else "sad", 16))
	b.add_child(h)
	var did: int = d.id
	b.pressed.connect(func(): manage(did))
	return b


func _pick_gear(did: int, slot: String) -> void:
	var hud := get_parent() as HUD
	var it := Loot.equipped_on(Game.dweller_by_id(did), slot)
	if it.is_empty():
		hud.open_loot_pick(slot, did)
	else:
		hud.open_loot_equipped(it, did)


func _build_manage(d: Dictionary) -> void:
	set_title("%s / %s" % ["DOSSIER LV%d" % d.lvl, d.name])
	var back := UIKit.button("< กลับ", "gray")
	back.pressed.connect(func():
		managing = -1
		refresh())
	_list.add_child(back)
	# --- bio card
	var bio := Lore.bio(d)
	var top := UIKit.hbox(6)
	top.add_child(UIKit.portrait(d.variant, true))
	var info := UIKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.label(bio.role, UIKit.FS_SMALL, UIKit.C_GOLD))
	info.add_child(UIKit.label("HP %d/%d RAD %d PWR %d" % [d.hp, d.max_hp, d.rads, Game.dweller_power(d)], UIKit.FP, UIKit.C_TEXT, true))
	var xp := UIKit.progress(UIKit.C_GOLD, 3)
	xp.value = float(d.xp) / Game.xp_needed(int(d.lvl))
	info.add_child(xp)
	for st in ["str", "int", "agi"]:
		info.add_child(UIKit.stat_bar(st, int(d[st])))
	top.add_child(info)
	_list.add_child(top)
	var bc := UIKit.panel()
	var bv := UIKit.vbox(1)
	bc.add_child(bv)
	bv.add_child(UIKit.wrap_label(bio.text, UIKit.FS_SMALL, UIKit.C_DIM))
	if str(bio.likes) != "-":
		bv.add_child(UIKit.wrap_label("ชอบ: %s · กลัว: %s" % [bio.likes, bio.fear], UIKit.FS_SMALL, UIKit.C_LINE_DIM))
	_list.add_child(bc)
	# --- traits, status, skills
	_list.add_child(UIKit.header("TRAITS", "นิสัย/ความถนัด"))
	var tf := UIKit.flow(3)
	var chips: Array = []
	if Crew.ROLES.has(Crew.role(d)):
		var rd: Dictionary = Crew.ROLES[Crew.role(d)]
		chips.append({"icon": rd.icon, "th": "อาชีพ: " + str(rd.th), "desc": rd.desc})
	for t in Crew.traits(d):
		chips.append(Crew.TRAITS[t])
	chips.append({"icon": "hammer", "th": "ความเร็วก่อสร้าง x%.2f" % (Crew.build_speed(d) / 0.6), "desc": "เทียบกับคนทั่วไป (STR ช่วยแบกคาน)"})
	for td in chips:
		var chip := UIKit.panel(UIKit.C_BG2, UIKit.C_RED if td.get("bad", false) else UIKit.C_LINE_DIM)
		var ch := UIKit.hbox(2)
		chip.add_child(ch)
		ch.add_child(UIKit.icon_rect(td.icon, 16))
		var cv := UIKit.vbox(0)
		cv.add_child(UIKit.label(td.th, UIKit.FS_SMALL, UIKit.C_TEXT))
		var dl := UIKit.label(td.desc, UIKit.FS_SMALL, UIKit.C_DIM)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 120
		cv.add_child(dl)
		ch.add_child(cv)
		tf.add_child(chip)
	_list.add_child(tf)
	if Crew.is_infected(d):
		var ib := UIKit.hbox(4)
		ib.add_child(UIKit.label("ติดเชื้อ %d%% — เสียเลือดเรื่อยๆ ผลิตลดลง" % int(d.infection), UIKit.FS_SMALL, UIKit.C_RED))
		if Game.has_item("antibiotics"):
			var cure := UIKit.button("ให้ยาปฏิชีวนะ", "green", "medkit")
			cure.pressed.connect(func(): Game.use_item_on(d, "antibiotics"))
			ib.add_child(cure)
		_list.add_child(ib)
	if float(d.rads) > 5.0:
		_list.add_child(UIKit.label("รังสีสะสม %d" % int(d.rads), UIKit.FS_SMALL, UIKit.C_ORANGE))
	var sk := UIKit.hbox(4)
	var skl := UIKit.label("SKILLS %s" % ("(%d แต้มว่าง)" % Skills.points_free(d) if Skills.points_free(d) > 0 else ""), UIKit.FP, UIKit.C_GOLD, true)
	skl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sk.add_child(skl)
	var bl := UIKit.label(Skills.build_label(d), UIKit.FS_SMALL, UIKit.C_DIM)
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sk.add_child(bl)
	var skb := UIKit.button("ผังสกิล", "yellow" if Skills.points_free(d) > 0 else "blue", "xp")
	var sdid: int = d.id
	skb.pressed.connect(func(): (get_parent() as HUD).open_skills(sdid))
	sk.add_child(skb)
	_list.add_child(sk)
	# --- gear: 6 slots, 2 rows of 3
	_list.add_child(UIKit.header("GEAR", "อุปกรณ์ 6 ชิ้น (แตะเพื่อเปลี่ยน)"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 3)
	for slot in Loot.HERO_SLOTS:
		var it := Loot.equipped_on(d, slot)
		var h := UIKit.hbox(3)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tile := UIKit.gear_tile(it, slot, 28)
		var sl: String = slot
		var did: int = d.id
		tile.pressed.connect(func(): _pick_gear(did, sl))
		h.add_child(tile)
		var cap := UIKit.label(Loot.item_name(it) if not it.is_empty() else Loot.SLOT_TH[slot], UIKit.FS_SMALL, Loot.rar_color(it) if not it.is_empty() else UIKit.C_DIM)
		cap.custom_minimum_size.x = 64
		cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cap.clip_text = true
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(cap)
		grid.add_child(h)
	_list.add_child(grid)
	var hs := Combat.hero_stats(d, maxi(0, Game.squad_role(d)))
	_list.add_child(UIKit.label("DODGE %d%%  LOOT +%d%%  SUPPLY +%d%%" % [int(hs.get("dodge", 0)), int(hs.loot), int(hs.get("supply", 0))], UIKit.FP, UIKit.C_BLUE, true))
	# --- squad role
	_list.add_child(UIKit.header("DEFENCE SQUAD", "ทีมป้องกัน"))
	var sq := UIKit.flow(3)
	var cur_role := Game.squad_role(d)
	for i in Combat.ROLES.size():
		var role: Dictionary = Combat.ROLES[i]
		var locked := i >= Combat.slots_unlocked()
		var b := UIKit.button(("%s (Lv.%d)" % [role.th, role.unlock]) if locked else role.th, "yellow" if cur_role == i else "green")
		b.disabled = locked or cur_role == i
		var ri: int = i
		var did2: int = d.id
		b.pressed.connect(func(): Game.set_squad(ri, did2))
		sq.add_child(b)
	if Mods.level("roof_deck") > 0:
		var on_deck := Game.is_deck(d)
		var db := UIKit.button("ตัวสำรองดาดฟ้า", "yellow" if on_deck else "green")
		db.disabled = on_deck
		var did3: int = d.id
		db.pressed.connect(func(): Game.set_deck(did3))
		sq.add_child(db)
		if on_deck:
			var off := UIKit.button("ลงจากดาดฟ้า", "gray")
			off.pressed.connect(func(): Game.set_deck(-1))
			sq.add_child(off)
	if cur_role >= 0:
		var out := UIKit.button("ออกจากทีม", "gray")
		out.pressed.connect(func(): Game.set_squad(cur_role, -1))
		sq.add_child(out)
	_list.add_child(sq)
	# --- consumables
	_list.add_child(UIKit.header("USE", "ใช้ไอเทม"))
	var fl := UIKit.flow(3)
	var any := false
	for id in ["stimpack", "radaway"]:
		if Game.has_item(id):
			any = true
			var it2: Dictionary = Data.ITEMS[id]
			var b2 := UIKit.button("%s x%d" % [it2.th, Game.s.items[id]], "green", it2.icon)
			var iid: String = id
			b2.pressed.connect(func(): Game.use_item_on(d, iid))
			fl.add_child(b2)
	if not any:
		fl.add_child(UIKit.label("ไม่มียา — ผลิตได้ที่ห้องพยาบาล", UIKit.FS_SMALL, UIKit.C_DIM))
	_list.add_child(fl)
	# --- room assignment
	_list.add_child(UIKit.header("ASSIGN ROOM", "ย้ายห้อง (* = เหมาะ)"))
	var rooms := UIKit.flow(3)
	for i in Game.s.rooms.size():
		var r: Dictionary = Game.s.rooms[i]
		if r.type == "empty" or r.type == "annex" or not Game.is_slot_unlocked(i):
			continue
		var def := Data.room_def(r.type)
		var n := Game.room_workers(i).size()
		var here: bool = int(d.room) == i
		var good: bool = Game._best_stat(d) == def.stat
		var cap := Game.room_capacity(i)
		var b := UIKit.button("%s%s %d/%d%s" % [def.th, (" x%d" % Game.room_span(i)) if Game.room_span(i) > 1 else "", n, cap, "*" if good else ""], "yellow" if here else ("green" if good else "gray"))
		b.disabled = here or n >= cap
		var slot: int = i
		b.pressed.connect(func(): Game.assign(d, slot))
		rooms.add_child(b)
	var idle := UIKit.button("พักงาน", "gray")
	idle.disabled = int(d.room) < 0
	idle.pressed.connect(func(): Game.assign(d, -1))
	rooms.add_child(idle)
	_list.add_child(rooms)
	# --- expeditions
	_list.add_child(UIKit.header("EXPEDITION", "ส่งทีมสำรวจ (รถจะจอดรอ)"))
	var ex := UIKit.button("วางแผนทีมสำรวจ", "orange", "explore")
	ex.disabled = Expedition.active()
	ex.pressed.connect(func():
		var site := Expedition.at_site() if Expedition.at_site() != "" else "scav"
		close()
		(get_parent() as HUD).open_expedition(site))
	_list.add_child(ex)
