class_name SquadPanel
extends ModalPanel
## Defence squad (3 roles, 6 gear slots each) + vault parts. Tap a gear slot to open the loot window.

var tab := "squad"     # squad | vault
var choosing := -1     # role index while picking a dweller (DECK = the roof-deck reserve)
const DECK := 99
var _tabs: HBoxContainer
var _list: VBoxContainer


func _build() -> void:
	_tabs = UIKit.hbox(3)
	body.add_child(_tabs)
	_list = make_list(4)
	for sig in [Game.gear_changed, Game.squad_changed, Game.dwellers_changed]:
		sig.connect(func(): if is_open: refresh())


func close() -> void:
	choosing = -1
	super.close()


func _hud() -> HUD:
	return get_parent() as HUD


func refresh() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for t in [["squad", "ทีมป้องกัน", "sword"], ["vault", "ชิ้นส่วนรถ", "engine"]]:
		var b := UIKit.button(t[1], "yellow" if tab == t[0] else "gray", t[2])
		var key: String = t[0]
		b.pressed.connect(func():
			tab = key
			choosing = -1
			refresh())
		_tabs.add_child(b)
	_tabs.add_child(UIKit.spacer())
	var auto := UIKit.button("AUTO", "green", "up")
	auto.tooltip_text = "สวมของดีที่สุดให้ทั้งทีมอัตโนมัติ"
	auto.pressed.connect(func():
		var n := Loot.auto_equip_squad()
		Game.toast.emit("เปลี่ยนอุปกรณ์ %d ชิ้น" % n if n > 0 else "ใส่ของดีที่สุดอยู่แล้ว", "good"))
	_tabs.add_child(auto)
	if tab == "vault":
		_build_vault()
	elif choosing >= 0:
		_build_chooser()
	else:
		_build_squad()


func _build_squad() -> void:
	set_title("SQUAD W%d DPS%d / ทีมป้องกันรถบ้าน" % [Combat.wave(), int(Combat.squad_dps())])
	for i in Combat.ROLES.size():
		_list.add_child(_role_card(i))
	_list.add_child(_deck_card())
	_list.add_child(UIKit.wrap_label("ศัตรูไล่ตามจากท้ายรถเป็นเวฟ · ทุก 10 เวฟมีบอส · ท้ายแต่ละพื้นที่มีบอสด่านตรวจ · ของดรอปเข้าคลังอัตโนมัติ · กระเป๋าดี = ศัตรูดรอปเสบียง", UIKit.FS_SMALL))


func _role_card(i: int) -> Control:
	var role: Dictionary = Combat.ROLES[i]
	var locked := i >= Combat.slots_unlocked()
	var did := int(Game.s.squad[i])
	var d := Game.dweller_by_id(did) if did >= 0 else {}
	var p := UIKit.panel(UIKit.C_BG2, UIKit.C_LINE_DIM if not d.is_empty() else UIKit.C_LINE_DARK)
	var v := UIKit.vbox(3)
	p.add_child(v)
	var hh := UIKit.hbox(4)
	hh.add_child(UIKit.icon_rect({"gunner": "rifle", "bruiser": "fist", "medic": "heal"}[role.id], 16))
	hh.add_child(UIKit.label(role.en, UIKit.FP, UIKit.C_GOLD, true))
	hh.add_child(UIKit.label("%s · %s" % [role.th, role.stat.to_upper()], UIKit.FS_SMALL, UIKit.C_DIM))
	v.add_child(hh)
	if locked:
		v.add_child(UIKit.wrap_label("ปลดล็อกเมื่อ Mobile Vault Lv.%d" % role.unlock, UIKit.FS_SMALL, UIKit.C_ORANGE))
		return p
	if d.is_empty():
		var add := UIKit.button("+ เลือกคน", "green", "people")
		add.pressed.connect(func():
			choosing = i
			refresh())
		v.add_child(add)
		v.add_child(UIKit.wrap_label("สกิล: %s — %s" % [role.skill, role.skill_desc], UIKit.FS_SMALL))
		return p
	var st := Combat.hero_stats(d, i)
	var dh := UIKit.hbox(4)
	dh.add_child(UIKit.portrait(d.variant))
	var info := UIKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.label("%s  Lv.%d" % [d.name, d.lvl], UIKit.FS_SMALL))
	var xp := UIKit.progress(UIKit.C_GOLD, 3)
	xp.value = float(d.xp) / Game.xp_needed(int(d.lvl))
	info.add_child(xp)
	dh.add_child(info)
	var sw := UIKit.button("เปลี่ยน", "blue")
	sw.pressed.connect(func():
		choosing = i
		refresh())
	dh.add_child(sw)
	var rm := UIKit.button("", "gray", "close")
	rm.pressed.connect(func(): Game.set_squad(i, -1))
	dh.add_child(rm)
	v.add_child(dh)
	var stats := "HP%d ATK%.0f %.1f/S DEF%.0f CRIT%d%% DODGE%d%% DPS%d" % [st.hp, st.dmg, st.aspd, st.def, int(st.crit), int(st.get("dodge", 0)), int(st.dps)]
	if role.id == "medic":
		stats += " HEAL%d" % int(st.heal)
	var sl := UIKit.label(stats, UIKit.FP, UIKit.C_TEXT, true)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size.x = 100
	v.add_child(sl)
	var gh := UIKit.hbox(2)
	for slot in Loot.HERO_SLOTS:
		var it := Loot.equipped_on(d, slot)
		var tile := UIKit.gear_tile(it, slot, 30)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.tooltip_text = Loot.SLOT_TH[slot]
		var sl2: String = slot
		var did2: int = did
		tile.pressed.connect(func():
			if it.is_empty():
				_hud().open_loot_pick(sl2, did2)
			else:
				_hud().open_loot_equipped(it, did2))
		gh.add_child(tile)
	v.add_child(gh)
	return p


## roof rest deck: one reserve rests on the cot and jumps in for whoever falls first in a wave
func _deck_card() -> Control:
	var lv := Mods.level("roof_deck")
	var d := Game.deck_dweller()
	var p := UIKit.panel(UIKit.C_BG2, UIKit.C_LINE_DIM if not d.is_empty() else UIKit.C_LINE_DARK)
	var v := UIKit.vbox(3)
	p.add_child(v)
	var hh := UIKit.hbox(4)
	hh.add_child(UIKit.icon_rect("moon", 16))
	hh.add_child(UIKit.label("ROOF DECK RESERVE", UIKit.FP, UIKit.C_GOLD, true))
	hh.add_child(UIKit.label("ตัวสำรองบนดาดฟ้า%s" % (" Lv.%d" % lv if lv > 0 else ""), UIKit.FS_SMALL, UIKit.C_DIM))
	v.add_child(hh)
	if lv <= 0:
		v.add_child(UIKit.wrap_label("สร้าง \"ดาดฟ้าพักทีมป้องกัน\" ที่เมนู MODS ก่อน: ที่พักบนหลังคาให้ตัวสำรอง 1 คน", UIKit.FS_SMALL, UIKit.C_ORANGE))
		return p
	var tag := "ลงไปแทนคนที่ล้มในเวฟภายใน %.1f วิ (HP %d%%) · ระหว่างรอ: ฟื้น HP, ความสุข +, ได้ XP %d%%" % [
		Combat.DECK_TAG_DELAY[mini(lv, 3)], int(Combat.DECK_TAG_HP[mini(lv, 3)] * 100.0), int(Combat.DECK_RESERVE_XP * 100.0)]
	if d.is_empty():
		var add := UIKit.button("+ เลือกตัวสำรอง", "green", "people")
		add.pressed.connect(func():
			choosing = DECK
			refresh())
		v.add_child(add)
		v.add_child(UIKit.wrap_label(tag, UIKit.FS_SMALL))
		return p
	var dh := UIKit.hbox(4)
	dh.add_child(UIKit.portrait(d.variant))
	var info := UIKit.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var state := "กำลังสู้แทน!" if not Combat.sub.is_empty() else "นอนพักบนเปล"
	info.add_child(UIKit.label("%s  Lv.%d · %s" % [d.name, d.lvl, state], UIKit.FS_SMALL))
	var hp := UIKit.progress(UIKit.C_GREEN, 3)
	hp.value = float(d.hp) / maxf(1.0, float(d.max_hp))
	info.add_child(hp)
	dh.add_child(info)
	var sw := UIKit.button("เปลี่ยน", "blue")
	sw.pressed.connect(func():
		choosing = DECK
		refresh())
	dh.add_child(sw)
	var rm := UIKit.button("", "gray", "close")
	rm.pressed.connect(func(): Game.set_deck(-1))
	dh.add_child(rm)
	v.add_child(dh)
	v.add_child(UIKit.wrap_label(tag, UIKit.FS_SMALL))
	return p


func _build_chooser() -> void:
	if choosing == DECK:
		_build_deck_chooser()
		return
	var role: Dictionary = Combat.ROLES[choosing]
	set_title("SELECT %s / เลือก%s" % [role.stat.to_upper(), role.th])
	var back := UIKit.button("< กลับ", "gray")
	back.pressed.connect(func():
		choosing = -1
		refresh())
	_list.add_child(back)
	_list.add_child(UIKit.wrap_label("คนในทีมจะออกจากห้องที่ทำงานอยู่ (ห้องจะผลิตช้าลง)", UIKit.FS_SMALL, UIKit.C_ORANGE))
	var arr: Array = []
	for d in Game.s.dwellers:
		if not Game.is_away(d):
			arr.append(d)
	var st: String = role.stat
	arr.sort_custom(func(a, b): return int(a[st]) * 10 + int(a.lvl) > int(b[st]) * 10 + int(b.lvl))
	for d in arr:
		var cur := Game.squad_role(d)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 28)
		b.focus_mode = Control.FOCUS_NONE
		UIKit.style_button(b, "yellow" if cur == choosing else ("gray" if cur >= 0 or int(d.room) >= 0 else "green"))
		var h := UIKit.hbox(4)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 3
		h.offset_top = 3
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(UIKit.tex_rect(Atlas.tex("pt_" + d.variant), Vector2(20, 20)))
		var where := "ว่าง"
		if cur >= 0:
			where = Combat.ROLES[cur].th
		elif int(d.room) >= 0:
			where = Data.room_def(Game.room(int(d.room)).type).th
		var l := UIKit.label("%s Lv%d %s%d (%s)" % [d.name, d.lvl, st.to_upper(), d[st], where], UIKit.FS_SMALL)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		b.add_child(h)
		var did: int = d.id
		var ri := choosing
		b.pressed.connect(func():
			Game.set_squad(ri, did)
			choosing = -1
			refresh())
		_list.add_child(b)


func _build_vault() -> void:
	var vs := Combat.van_stats()
	set_title("VAULT PARTS / ชิ้นส่วนรถบ้าน")
	var sp := UIKit.panel()
	var sl := UIKit.label("HULL %d/%d DEF%.0f TURRET-DPS%d THORNS%.0f SPD+%d%% PWR+%.1f" % [
		Game.s.hull, Game.hull_max(), vs.def, int(vs.turret_dps), vs.thorns, int(vs.speed), vs.power], UIKit.FP, UIKit.C_TEXT, true)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size.x = 100
	sp.add_child(sl)
	_list.add_child(sp)
	var desc := {"turret": "ยิงศัตรูอัตโนมัติจากผนังท้ายรถ", "plating": "เพิ่มตัวถังสูงสุด ลดความเสียหาย", "engine": "เครื่องยนต์ในห้องเครื่องหน้ารถ (แตะห้องเครื่องเพื่อดูรายละเอียด)", "spikes": "ทำดาเมจศัตรูที่ประชิดท้ายรถ"}
	for slot in Loot.VAN_SLOTS:
		var it := Loot.van_equipped(slot)
		var p := UIKit.panel(UIKit.C_BG2, Loot.rar_color(it).darkened(0.3) if not it.is_empty() else UIKit.C_LINE_DARK)
		var h := UIKit.hbox(6)
		p.add_child(h)
		var tile := UIKit.gear_tile(it, slot, 32)
		var sl2: String = slot
		tile.pressed.connect(func():
			if it.is_empty():
				_hud().open_loot_pick(sl2, -2)
			else:
				_hud().open_loot_equipped(it, -2))
		h.add_child(tile)
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(Loot.SLOT_TH[slot], UIKit.FS_SMALL, UIKit.C_GOLD))
		v.add_child(UIKit.label(Loot.item_name(it) if not it.is_empty() else "ว่าง", UIKit.FS_SMALL, Loot.rar_color(it) if not it.is_empty() else UIKit.C_DIM))
		v.add_child(UIKit.wrap_label(desc[slot], UIKit.FS_SMALL))
		h.add_child(v)
		_list.add_child(p)


func _build_deck_chooser() -> void:
	set_title("SELECT RESERVE / เลือกตัวสำรองบนดาดฟ้า")
	var back := UIKit.button("< กลับ", "gray")
	back.pressed.connect(func():
		choosing = -1
		refresh())
	_list.add_child(back)
	_list.add_child(UIKit.wrap_label("ตัวสำรองไม่ทำงานในห้อง · จะลงไปแทนตำแหน่งของคนที่ล้มก่อน ใช้ค่าสเตตัสของตำแหน่งนั้น", UIKit.FS_SMALL, UIKit.C_ORANGE))
	var cur := Game.deck_dweller()
	var arr: Array = []
	for d in Game.s.dwellers:
		if not Game.is_away(d):
			arr.append(d)
	arr.sort_custom(func(a, b): return int(a.lvl) * 10 + int(a.str) + int(a.agi) + int(a.int) > int(b.lvl) * 10 + int(b.str) + int(b.agi) + int(b.int))
	for d in arr:
		var on := not cur.is_empty() and int(cur.id) == int(d.id)
		var role := Game.squad_role(d)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 28)
		b.focus_mode = Control.FOCUS_NONE
		UIKit.style_button(b, "yellow" if on else ("gray" if role >= 0 or int(d.room) >= 0 else "green"))
		var h := UIKit.hbox(4)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 3
		h.offset_top = 3
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(UIKit.tex_rect(Atlas.tex("pt_" + d.variant), Vector2(20, 20)))
		var where := "ว่าง"
		if on:
			where = "บนดาดฟ้า"
		elif role >= 0:
			where = Combat.ROLES[role].th
		elif int(d.room) >= 0:
			where = Data.room_def(Game.room(int(d.room)).type).th
		var l := UIKit.label("%s Lv%d S%d A%d I%d (%s)" % [d.name, d.lvl, d.str, d.agi, d.int, where], UIKit.FS_SMALL)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		b.add_child(h)
		var did: int = d.id
		b.pressed.connect(func():
			Game.set_deck(did)
			choosing = -1
			refresh())
		_list.add_child(b)
