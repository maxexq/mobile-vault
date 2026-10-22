class_name LootPanel
extends ModalPanel
## Loot / stash window: gear grid (filter + rarity sort), item detail (compare, equip, enhance,
## lock, salvage), consumables, and the Forge (3->1 synthesis, bulk salvage, auto-salvage).

var tab := "gear"                 # gear | items | forge
var filter := "all"               # all | weapon | armor | gadget | van
var detail_uid := -1              # stash item shown in detail
var detail_equipped := {}         # {"item":Dictionary,"did":int(-2 = vault)} when showing an equipped item
var pick_slot := ""               # set when opened from a gear slot
var pick_did := -1                # dweller id for pick mode (-2 = vault)
var _tabs: HBoxContainer
var _list: VBoxContainer
var _comp_label: Label
var _amounts := {}                # res/item id -> amount Label on the items tab (updated in place)
var _sig := ""                    # layout signature of the open tab, see _layout_sig()

const FILTERS := [["all", "ALL"], ["weapon", "rifle"], ["armor", "armor"], ["helmet", "helmet"], ["boots", "boots"], ["backpack", "backpack"], ["gadget", "chip"], ["van", "engine"]]
const AUTO_SALV := [[-1, "ปิด"], [0, "ทั่วไป"], [1, "ทั่วไป+ดี"]]


func _build() -> void:
	set_title("LOOT / คลังอุปกรณ์")
	_tabs = UIKit.hbox(3)
	body.add_child(_tabs)
	_list = make_list(4)
	Game.gear_changed.connect(func(): if is_open: refresh())
	Game.resources_changed.connect(_on_resources_changed)


## resources_changed fires every simulation frame. Rebuilding here would free the tab buttons
## between touch-down and touch-up, so taps on the other tabs never registered. Only rebuild
## when the layout changes; otherwise just retext the numbers.
func _on_resources_changed() -> void:
	if not is_open:
		return
	if tab != "gear" and _layout_sig() != _sig:
		refresh()
		return
	if is_instance_valid(_comp_label):
		_comp_label.text = str(int(Game.s.items.get("components", 0)))
	for k in _amounts:
		var l: Label = _amounts[k]
		if is_instance_valid(l):
			l.text = _amount_text(k)


## What decides the tab's widgets (not just their numbers); a change here needs a rebuild.
func _layout_sig() -> String:
	match tab:
		"items":
			var ids: Array = []
			for id in Game.s.items:
				var it: Dictionary = Data.ITEMS.get(id, {})
				if not it.is_empty() and not (it.kind in ["weapon", "armor"]):
					ids.append(str(id))
			ids.sort()
			return "items:" + ",".join(ids) + ":%d" % box.size.x
		"forge":
			var bits := "forge:%d:" % int(Game.s.combat.get("auto_salvage", -1))
			for r in range(Loot.RARITY.size() - 1):
				bits += "1" if float(Game.s.res.scrap) >= 15 * (r + 1) else "0"
			return bits
	return tab


func _amount_text(k: String) -> String:
	if Game.s.res.has(k):
		return "%d / %d" % [int(Game.s.res[k]), int(Game.cap(k))]
	return "x%d" % int(Game.s.items.get(k, 0))


func open_pick(slot: String, did: int) -> void:
	pick_slot = slot
	pick_did = did
	tab = "gear"
	detail_uid = -1
	detail_equipped = {}
	open()


func open_equipped(item: Dictionary, did: int) -> void:
	pick_slot = item.slot
	pick_did = did
	tab = "gear"
	detail_uid = -1
	detail_equipped = {"item": item, "did": did}
	open()


func close() -> void:
	pick_slot = ""
	pick_did = -1
	detail_uid = -1
	detail_equipped = {}
	super.close()


func refresh() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_amounts = {}
	for t in [["gear", "%d/%d" % [Loot.stash().size(), Loot.STASH_CAP], "chest"], ["items", "ไอเทม", "can"], ["forge", "หลอม", "cog"]]:
		var b := UIKit.button(t[1], "yellow" if tab == t[0] else "gray", t[2])
		var key: String = t[0]
		b.pressed.connect(func():
			tab = key
			detail_uid = -1
			detail_equipped = {}
			refresh())
		_tabs.add_child(b)
	_tabs.add_child(UIKit.spacer())
	var comp := UIKit.hbox(4)
	comp.add_child(UIKit.icon_rect("cog", 16))
	var cl := UIKit.label(str(int(Game.s.items.get("components", 0))), UIKit.FP, UIKit.C_GOLD, true)
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	comp.add_child(cl)
	_comp_label = cl
	_tabs.add_child(comp)
	match tab:
		"gear":
			if not detail_equipped.is_empty():
				_build_detail(detail_equipped.item, true)
			elif detail_uid >= 0 and not _find(detail_uid).is_empty():
				_build_detail(_find(detail_uid), false)
			else:
				_build_grid()
		"items":
			_build_items()
		"forge":
			_build_forge()
	_sig = _layout_sig()


func _find(uid: int) -> Dictionary:
	for it in Loot.stash():
		if int(it.uid) == uid:
			return it
	return {}


func _owner_name(did: int) -> String:
	if did == -2:
		return "รถบ้าน"
	var d := Game.dweller_by_id(did)
	return d.name if not d.is_empty() else "?"


# ------------------------------------------------------------------ grid
func _build_grid() -> void:
	if pick_slot != "":
		set_title("SELECT %s / %s" % [pick_slot.to_upper(), _owner_name(pick_did)])
		var cur := _current_equipped()
		var h := UIKit.hbox(4)
		h.add_child(UIKit.label("ใส่อยู่:", UIKit.FS_SMALL, UIKit.C_DIM))
		var t := UIKit.gear_tile(cur, pick_slot, 30)
		t.pressed.connect(func():
			if not cur.is_empty():
				detail_equipped = {"item": cur, "did": pick_did}
				refresh())
		h.add_child(t)
		var cn := UIKit.label(Loot.item_name(cur) if not cur.is_empty() else "ว่าง", UIKit.FS_SMALL, Loot.rar_color(cur) if not cur.is_empty() else UIKit.C_DIM)
		cn.clip_text = true
		cn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(cn)
		var all := UIKit.button("ทั้งหมด", "gray")
		all.pressed.connect(func():
			pick_slot = ""
			pick_did = -1
			refresh())
		h.add_child(all)
		_list.add_child(h)
	else:
		set_title("LOOT / คลังอุปกรณ์")
		var fh := UIKit.hbox(2)
		for f in FILTERS:
			var b := UIKit.button(f[1], "blue" if filter == f[0] else "gray") if f[0] == "all" else UIKit.button("", "blue" if filter == f[0] else "gray", f[1])
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size.x = 26
			b.add_theme_font_override("font", UIKit.font_pixel)
			b.add_theme_font_size_override("font_size", UIKit.FP)
			var key: String = f[0]
			b.pressed.connect(func():
				filter = key
				refresh())
			fh.add_child(b)
		_list.add_child(fh)
	var items: Array = []
	for it in Loot.stash():
		if pick_slot != "":
			if it.slot != pick_slot:
				continue
		elif filter == "van":
			if not Loot.VAN_SLOTS.has(it.slot):
				continue
		elif filter != "all" and it.slot != filter:
			continue
		items.append(it)
	items.sort_custom(func(a, b):
		if int(a.rar) != int(b.rar):
			return int(a.rar) > int(b.rar)
		return Loot.power_score(a) > Loot.power_score(b))
	if items.is_empty():
		_list.add_child(UIKit.wrap_label("ยังไม่มีอุปกรณ์ในหมวดนี้ — ศัตรูดรอปของเมื่อถูกกำจัด (บอสดรอปแน่นอน) หรือผลิตที่ห้องอาวุธ"))
		return
	var grid := GridContainer.new()
	var w := box.size.x - 24.0
	grid.columns = maxi(5, int(w / 40.0))
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var cur_score := Loot.power_score(_current_equipped()) if pick_slot != "" else 0.0
	for it in items:
		var t := UIKit.gear_tile(it, it.slot, 36)
		if pick_slot != "" and Loot.power_score(it) > cur_score:
			var up := TextureRect.new()
			up.texture = Atlas.icon("up")
			up.position = Vector2(20, -2)
			up.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.add_child(up)
		var uid: int = it.uid
		t.pressed.connect(func():
			detail_uid = uid
			refresh())
		grid.add_child(t)
	_list.add_child(grid)


func _current_equipped() -> Dictionary:
	if pick_slot == "":
		return {}
	if pick_did == -2 or Loot.VAN_SLOTS.has(pick_slot):
		return Loot.van_equipped(pick_slot)
	var d := Game.dweller_by_id(pick_did)
	return Loot.equipped_on(d, pick_slot) if not d.is_empty() else {}


# ------------------------------------------------------------------ detail
func _build_detail(item: Dictionary, equipped: bool) -> void:
	var rar := Loot.rarity(int(item.rar))
	set_title("%s / %s" % [rar.en, Loot.item_name(item)])
	var back := UIKit.button("< กลับ", "gray")
	back.pressed.connect(func():
		detail_uid = -1
		detail_equipped = {}
		refresh())
	_list.add_child(back)
	var top := UIKit.hbox(6)
	top.add_child(UIKit.gear_tile(item, item.slot, 40))
	var v := UIKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.item_title(item, UIKit.FS_BIG))
	v.add_child(UIKit.label("%s · %s · Lv.%d · MAX +%d" % [rar.th, Loot.SLOT_TH[item.slot], item.ilvl, rar.max_plus], UIKit.FS_SMALL, rar.col))
	v.add_child(UIKit.label(Loot.base(item).get("en", ""), UIKit.FP, UIKit.C_DIM, true))
	top.add_child(v)
	_list.add_child(top)
	# stats
	var sp := UIKit.panel()
	var sv := UIKit.vbox(1)
	sp.add_child(sv)
	for row in Loot.describe(item):
		sv.add_child(UIKit.label("%s: %s" % [row[0], row[1]], UIKit.FS_SMALL, UIKit.C_TEXT))
	for a in item.aff:
		sv.add_child(UIKit.label("+ " + Loot.affix_text(a, int(item.plus)), UIKit.FS_SMALL, rar.col.lightened(0.2)))
	if item.aff.is_empty():
		sv.add_child(UIKit.wrap_label("(ไม่มีคุณสมบัติพิเศษ — ระดับสูงขึ้นจะได้ 1-4 อย่าง)"))
	_list.add_child(sp)
	# compare
	var owner_did: int = detail_equipped.get("did", pick_did)
	if not equipped:
		var cur := {}
		if Loot.VAN_SLOTS.has(item.slot):
			cur = Loot.van_equipped(item.slot)
			owner_did = -2
		elif pick_did >= 0:
			cur = Loot.equipped_on(Game.dweller_by_id(pick_did), item.slot)
		var a := Loot.power_score(item)
		var b := Loot.power_score(cur)
		if not cur.is_empty():
			var pct := (a / maxf(b, 0.01) - 1.0) * 100.0
			_list.add_child(UIKit.wrap_label("เทียบกับที่ใส่อยู่ (%s): %+.0f%% พลัง" % [Loot.item_name(cur), pct], UIKit.FS_SMALL, UIKit.C_GREEN if pct >= 0 else UIKit.C_RED))
	# actions
	var acts := UIKit.flow(3)
	if equipped:
		var un := UIKit.button("ถอดออก", "gray", "close")
		un.pressed.connect(func():
			if owner_did == -2:
				Loot.unequip({}, item.slot)
			else:
				Loot.unequip(Game.dweller_by_id(owner_did), item.slot)
			detail_equipped = {}
			refresh())
		acts.add_child(un)
	elif Loot.VAN_SLOTS.has(item.slot):
		var eqv := UIKit.button("ติดตั้งบนรถบ้าน", "green", "up")
		var uid: int = item.uid
		eqv.pressed.connect(func():
			Loot.equip_from_stash(uid)
			Game.toast.emit("ติดตั้ง %s แล้ว" % Loot.item_name(item), "good")
			_after_equip())
		acts.add_child(eqv)
	else:
		var who: Array = []
		if pick_did >= 0:
			who.append(pick_did)
		for did in Game.s.squad:
			if int(did) >= 0 and not who.has(int(did)):
				who.append(int(did))
		for d in Game.s.dwellers:
			if not who.has(int(d.id)) and not Game.is_away(d):
				who.append(int(d.id))
		for did in who.slice(0, 6):
			var d := Game.dweller_by_id(int(did))
			var role := Game.squad_role(d)
			var b2 := UIKit.button("ให้ %s%s" % [d.name, " *" if role >= 0 else ""], "green" if int(did) == pick_did or role >= 0 else "gray", "up")
			var uid2: int = item.uid
			var did2: int = int(did)
			b2.pressed.connect(func():
				Loot.equip_from_stash(uid2, Game.dweller_by_id(did2))
				Game.toast.emit("%s สวม %s" % [Game.dweller_by_id(did2).name, Loot.item_name(item)], "good")
				_after_equip())
			acts.add_child(b2)
	_list.add_child(acts)
	var acts2 := UIKit.flow(3)
	if Loot.can_enhance(item):
		var c := Loot.enhance_cost(item)
		var en := UIKit.button("ตีบวก +%d (%d ชส. %d เศษ)" % [int(item.plus) + 1, c.components, c.scrap], "yellow", "wrench")
		en.disabled = not Game.can_afford(c)
		en.pressed.connect(func():
			if Loot.enhance(item):
				Game.toast.emit("ตีบวกสำเร็จ! %s +%d" % [Loot.item_name(item), item.plus], "good")
			refresh())
		acts2.add_child(en)
	else:
		acts2.add_child(UIKit.label("ตีบวกเต็มแล้ว", UIKit.FS_SMALL, UIKit.C_GOLD))
	if not equipped:
		var lk := UIKit.button("ปลดล็อก" if item.lock else "ล็อก", "blue", "lock")
		lk.pressed.connect(func():
			item.lock = not item.lock
			refresh())
		acts2.add_child(lk)
		var sv2 := Loot.salvage_value(item)
		var sal := UIKit.button("แยก +%d" % sv2.components, "red", "cog")
		sal.disabled = item.lock
		var uid3: int = item.uid
		sal.pressed.connect(func():
			Loot.salvage(uid3)
			detail_uid = -1
			refresh())
		acts2.add_child(sal)
	_list.add_child(acts2)


func _after_equip() -> void:
	detail_uid = -1
	if pick_slot != "":
		close()
	else:
		refresh()


# ------------------------------------------------------------------ items & forge
func _build_items() -> void:
	set_title("ITEMS / ไอเทมและทรัพยากร")
	var grid := GridContainer.new()
	grid.columns = 2 if box.size.x < 500 else 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["power", "water", "food", "scrap"]:
		grid.add_child(_card(Data.item_icon(k), Data.item_name(k), k, "", ""))
	for id in Game.s.items:
		var it: Dictionary = Data.ITEMS.get(id, {})
		if it.is_empty() or it.kind in ["weapon", "armor"]:
			continue
		grid.add_child(_card(it.icon, it.th, str(id), it.get("desc", ""), id if id == "dried_meat" else ""))
	_list.add_child(grid)


func _card(icon: String, title: String, amount_key: String, desc: String, use_id: String) -> Control:
	var p := UIKit.panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UIKit.hbox(4)
	p.add_child(h)
	h.add_child(UIKit.icon_rect(icon, 32))
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl := UIKit.label(title, UIKit.FS_SMALL)
	tl.clip_text = true
	v.add_child(tl)
	var al := UIKit.label(_amount_text(amount_key), UIKit.FP, UIKit.C_GOLD, true)
	_amounts[amount_key] = al
	v.add_child(al)
	h.add_child(v)
	if use_id != "":
		var b := UIKit.button("ใช้", "green")
		b.pressed.connect(func(): Game.use_item(use_id))
		h.add_child(b)
	return p


func _build_forge() -> void:
	set_title("FORGE / เตาหลอม")
	_list.add_child(UIKit.wrap_label("หลอมอุปกรณ์ระดับเดียวกัน 3 ชิ้น (ไม่ล็อก ตัวอ่อนสุดก่อน) → 1 ชิ้นระดับสูงขึ้น · การแยกชิ้นส่วนให้ 'ชิ้นส่วน' ไว้ตีบวก"))
	for r in range(Loot.RARITY.size() - 1):
		var c := Loot.synth_candidates(r)
		var a: Dictionary = Loot.rarity(r)
		var nx: Dictionary = Loot.rarity(r + 1)
		var row := UIKit.panel(UIKit.C_BG2, a.col.darkened(0.4))
		var h := UIKit.hbox(4)
		row.add_child(h)
		var l := UIKit.label("3×%s → %s" % [a.th, nx.th], UIKit.FS_SMALL, nx.col)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		h.add_child(l)
		h.add_child(UIKit.label("มี%d" % c.size(), UIKit.FS_SMALL, UIKit.C_DIM))
		var b := UIKit.button("%d" % (15 * (r + 1)), "yellow", "cog")
		b.disabled = c.size() < 3 or float(Game.s.res.scrap) < 15 * (r + 1)
		var rr: int = r
		b.pressed.connect(func():
			var out := Loot.synthesize(rr)
			if not out.is_empty():
				Game.toast.emit("หลอมสำเร็จ! ได้ %s [%s]" % [Loot.item_name(out), Loot.rarity(int(out.rar)).th], "biome" if int(out.rar) >= 3 else "good")
			refresh())
		h.add_child(b)
		_list.add_child(row)
	_list.add_child(UIKit.header("BULK SALVAGE", "แยกทีละมาก (ข้ามของล็อก)"))
	var bh := UIKit.flow(3)
	for r in 3:
		var b := UIKit.button("≤ %s" % Loot.rarity(r).th, "red", "cog")
		var rr: int = r
		b.pressed.connect(func():
			var t := Loot.salvage_bulk(rr)
			Game.toast.emit("แยก %d ชิ้น ได้ %d ชิ้นส่วน + %d เศษเหล็ก" % [t.count, t.components, t.scrap], "good")
			refresh())
		bh.add_child(b)
	_list.add_child(bh)
	_list.add_child(UIKit.header("AUTO SALVAGE", "แยกอัตโนมัติเมื่อดรอป"))
	var ah := UIKit.hbox(3)
	var cur := int(Game.s.combat.get("auto_salvage", -1))
	for opt in AUTO_SALV:
		var b2 := UIKit.button(opt[1], "yellow" if cur == int(opt[0]) else "gray")
		var val: int = opt[0]
		b2.pressed.connect(func():
			Game.s.combat.auto_salvage = val
			refresh())
		ah.add_child(b2)
	_list.add_child(ah)
