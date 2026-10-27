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
var salvage_pick := false         # MV-554: grid taps tick items for salvage instead of opening them
var salvage_sel := {}             # MV-554: ticked uid -> true
var _footer: PanelContainer       # MV-554: sticky bar under the list: count, value, salvage button

const FILTERS := [["all", "ALL"], ["weapon", "rifle"], ["armor", "armor"], ["helmet", "helmet"], ["boots", "boots"], ["backpack", "backpack"], ["gadget", "chip"], ["van", "engine"]]
const AUTO_SALV := [[-1, "ปิด"], [0, "ทั่วไป"], [1, "ทั่วไป+ดี"]]


func _build() -> void:
	set_title(Loc.t("LOOT / คลังอุปกรณ์"))
	_tabs = UIKit.hbox(3)
	body.add_child(_tabs)
	_list = make_list(4)
	_footer = UIKit.panel(UIKit.C_BG2, UIKit.C_RED.darkened(0.4))
	_footer.name = "SalvageFooter"
	_footer.visible = false
	body.add_child(_footer)
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
			return "items:" + ",".join(ids) + ":%d" % box.custom_minimum_size.x
		"forge":
			var bits := "forge:%d:" % int(Game.s.combat.get("auto_salvage", -1))
			for r in range(Loot.RARITY.size() - 1):
				bits += "1" if Game.can_afford(Loot.synth_cost(r)) else "0"
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
	_salvage_reset()
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
	for t in [["gear", "%d/%d" % [Loot.stash().size(), Loot.STASH_CAP], "chest"], ["items", Loc.t("ไอเทม"), "can"], ["forge", Loc.t("หลอม"), "cog"]]:
		var b := UIKit.button(t[1], "yellow" if tab == t[0] else "gray", t[2])
		var key: String = t[0]
		b.pressed.connect(func():
			tab = key
			detail_uid = -1
			detail_equipped = {}
			_salvage_reset()
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
	_build_salvage_footer()
	_sig = _layout_sig()
	if is_open:
		_layout()        # a narrower tab / grid lets the window shrink back to its size for this screen


func _find(uid: int) -> Dictionary:
	for it in Loot.stash():
		if int(it.uid) == uid:
			return it
	return {}


func _owner_name(did: int) -> String:
	if did == -2:
		return Loc.t("รถบ้าน")
	var d := Game.dweller_by_id(did)
	return d.name if not d.is_empty() else "?"


# ------------------------------------------------------------------ grid
func _build_grid() -> void:
	if pick_slot != "":
		set_title("SELECT %s / %s" % [pick_slot.to_upper(), _owner_name(pick_did)])
		var cur := _current_equipped()
		var h := UIKit.hbox(UIKit.gear_gap(4))
		h.add_child(UIKit.label(Loc.t("ใส่อยู่:"), UIKit.FS_SMALL, UIKit.C_DIM))
		var t := UIKit.gear_tile(cur, pick_slot, 30)
		t.pressed.connect(func():
			if not cur.is_empty():
				detail_equipped = {"item": cur, "did": pick_did}
				refresh())
		h.add_child(t)
		var cn := UIKit.label(Loot.item_name(cur) if not cur.is_empty() else Loc.t("ว่าง", "slot"), UIKit.FS_SMALL, Loot.rar_color(cur) if not cur.is_empty() else UIKit.C_DIM)
		cn.clip_text = true
		cn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(cn)
		var all := UIKit.button(Loc.t("ทั้งหมด"), "gray")
		all.pressed.connect(func():
			pick_slot = ""
			pick_did = -1
			refresh())
		h.add_child(all)
		_list.add_child(h)
	else:
		set_title(Loc.t("LOOT / คลังอุปกรณ์"))
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
		if Features.on("multi_salvage"):
			var sh := UIKit.hbox(3)
			var tg := UIKit.button(Loc.t("เลิกเลือก") if salvage_pick else Loc.t("เลือกแยกหลายชิ้น"), "gray" if salvage_pick else "red", "close" if salvage_pick else "cog")
			tg.name = "MultiSalvageToggle"
			tg.pressed.connect(func():
				salvage_pick = not salvage_pick
				salvage_sel = {}
				refresh())
			sh.add_child(tg)
			if salvage_pick:
				var hint := UIKit.wrap_label(Loc.t("แตะอุปกรณ์เพื่อเลือก · ของล็อกเลือกไม่ได้"))
				hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				sh.add_child(hint)
			_list.add_child(sh)
		if Features.on("loot_pity"):
			var pl := UIKit.label(Loc.t("การันตี: มหากาพย์ในอีก %d ดรอป · ตำนานในอีก %d ดรอป") % [Loot.pity_left(3), Loot.pity_left(4)], UIKit.FS_SMALL, UIKit.C_DIM)
			pl.name = "PityLine"
			_list.add_child(pl)
	var items := _filtered_stash()
	items.sort_custom(func(a, b):
		if int(a.rar) != int(b.rar):
			return int(a.rar) > int(b.rar)
		return Loot.power_score(a) > Loot.power_score(b))
	if items.is_empty():
		_list.add_child(UIKit.wrap_label(Loc.t("ยังไม่มีอุปกรณ์ในหมวดนี้ — ศัตรูดรอปของเมื่อถูกกำจัด (บอสดรอปแน่นอน) หรือผลิตที่ห้องอาวุธ")))
		return
	var grid := GridContainer.new()
	# the width _layout gives the window on this screen (MV-266/113): box.size is still stretched by the last build's
	# grid, so a grid built on a wide screen kept its columns after the screen got narrower and ran past the edge
	var w := box.custom_minimum_size.x - 24.0
	var gap := UIKit.gear_gap(4)
	if gap > 4:
		w -= 2.0 * UIKit.GEAR_AURA          # gear_pad's margins
	grid.columns = maxi(5, int((w + gap) / float(36 + gap)))
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", gap)
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
		if salvage_pick and pick_slot == "" and Features.on("multi_salvage"):
			t.disabled = it.lock
			if salvage_sel.has(uid):
				t.add_child(_picked_mark(36))
			t.pressed.connect(func():
				_toggle_sel(uid)
				refresh())
		else:
			t.pressed.connect(func():
				detail_uid = uid
				refresh())
		grid.add_child(t)
	_list.add_child(UIKit.gear_pad(grid))


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
	var back := UIKit.button(Loc.t("< กลับ"), "gray")
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
	# stats + compare
	var owner_did: int = detail_equipped.get("did", pick_did)
	var cur := {}
	if not equipped:
		if Loot.VAN_SLOTS.has(item.slot):
			cur = Loot.van_equipped(item.slot)
		elif pick_did >= 0:
			cur = Loot.equipped_on(Game.dweller_by_id(pick_did), item.slot)
	if Features.on("gear_detail_v2"):
		_stats_table(item, cur)
	else:
		_stats_legacy(item, cur)
	# actions
	var acts := UIKit.flow(3)
	if equipped:
		var un := UIKit.button(Loc.t("ถอดออก"), "gray", "close")
		un.pressed.connect(func():
			if owner_did == -2:
				Loot.unequip({}, item.slot)
			else:
				Loot.unequip(Game.dweller_by_id(owner_did), item.slot)
			detail_equipped = {}
			refresh())
		acts.add_child(un)
	elif Loot.VAN_SLOTS.has(item.slot):
		var eqv := UIKit.button(Loc.t("ติดตั้งบนรถบ้าน"), "green", "up")
		var uid: int = item.uid
		eqv.pressed.connect(func():
			Loot.equip_from_stash(uid)
			Game.toast.emit(Loc.t("ติดตั้ง %s แล้ว") % Loot.item_name(item), "good")
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
			var b2 := UIKit.button(Loc.t("ให้ %s%s") % [d.name, " *" if role >= 0 else ""], "green" if int(did) == pick_did or role >= 0 else "gray", "up")
			var uid2: int = item.uid
			var did2: int = int(did)
			b2.pressed.connect(func():
				Loot.equip_from_stash(uid2, Game.dweller_by_id(did2))
				Game.toast.emit(Loc.t("%s สวม %s") % [Game.dweller_by_id(did2).name, Loot.item_name(item)], "good")
				_after_equip())
			acts.add_child(b2)
	_list.add_child(acts)
	var acts2 := UIKit.flow(3)
	if Loot.can_enhance(item):
		var c := Loot.enhance_cost(item)
		var en := UIKit.button(Loc.t("ตีบวก +%d (%d ชส. %d เศษ)") % [int(item.plus) + 1, c.components, c.scrap], "yellow", "wrench")
		en.disabled = not Game.can_afford(c)
		en.pressed.connect(func():
			if Loot.enhance(item):
				Game.toast.emit(Loc.t("ตีบวกสำเร็จ! %s +%d") % [Loot.item_name(item), item.plus], "good")
			refresh())
		acts2.add_child(en)
	else:
		acts2.add_child(UIKit.label(Loc.t("ตีบวกเต็มแล้ว"), UIKit.FS_SMALL, UIKit.C_GOLD))
	if not equipped:
		var lk := UIKit.button(Loc.t("ปลดล็อก") if item.lock else Loc.t("ล็อก"), "blue", "lock")
		lk.pressed.connect(func():
			item.lock = not item.lock
			refresh())
		acts2.add_child(lk)
		var sv2 := Loot.salvage_value(item)
		var sal := UIKit.button(Loc.t("แยก +%d") % sv2.components, "red", "cog")
		sal.name = "SalvageButton"
		sal.disabled = item.lock
		sal.pressed.connect(func(): _request_salvage(item))
		acts2.add_child(sal)
	_list.add_child(acts2)


func _after_equip() -> void:
	detail_uid = -1
	if pick_slot != "":
		close()
	else:
		refresh()


# ------------------------------------------------------------------ MV-552 stat table
const STAT_ICON := {"dmg": "sword", "aspd": "ammo", "range": "zoom", "splash": "acid", "hp": "heal", "def": "shield",
	"regen": "medkit", "crit": "eye", "critd": "fist", "aspd_pct": "ammo", "dodge": "dodge", "loot": "chest",
	"supply": "supply", "hull": "hull", "speed": "fuel", "power": "power", "thorns": "spikes", "lifesteal": "pill",
	"scrap": "scrap", "xp": "xp", "turret": "turret"}
const BASE_PCT := ["crit", "aspd_pct", "loot", "supply", "dodge", "speed"]


func _stats_legacy(item: Dictionary, cur: Dictionary) -> void:
	var rar := Loot.rarity(int(item.rar))
	var sp := UIKit.panel()
	var sv := UIKit.vbox(1)
	sp.add_child(sv)
	for row in Loot.describe(item):
		sv.add_child(UIKit.label("%s: %s" % [row[0], row[1]], UIKit.FS_SMALL, UIKit.C_TEXT))
	for a in item.aff:
		sv.add_child(UIKit.label("+ " + Loot.affix_text(a, int(item.plus)), UIKit.FS_SMALL, rar.col.lightened(0.2)))
	if item.aff.is_empty():
		sv.add_child(UIKit.wrap_label(Loc.t("(ไม่มีคุณสมบัติพิเศษ — ระดับสูงขึ้นจะได้ 1-4 อย่าง)")))
	_list.add_child(sp)
	if not cur.is_empty():
		var pct := _power_pct(item, cur)
		_list.add_child(UIKit.wrap_label(Loc.t("เทียบกับที่ใส่อยู่ (%s): %+.0f%% พลัง") % [Loot.item_name(cur), pct], UIKit.FS_SMALL, UIKit.C_GREEN if pct >= 0 else UIKit.C_RED))


## every stat line of the item next to cur (same slot, {} = nothing to compare): {key, name, text, diff (item - cur),
## cmp, affix, lost (only cur has it)}; base stats first, then affixes
func _stat_rows(item: Dictionary, cur: Dictionary) -> Array:
	var rows: Array = []
	var cmp := not cur.is_empty()
	var melee: bool = Loot.base(item).get("melee", false) or (cmp and Loot.base(cur).get("melee", false))
	var seen := {}
	for row in Loot.describe(item):
		if row.size() < 3:
			continue
		var k: String = row[2]
		seen[k] = true
		var d := Loot.base_stat(item, k) - (Loot.base_stat(cur, k) if cmp else 0.0)
		rows.append({"key": k, "name": Loc.t(row[0]), "text": row[1], "diff": d, "cmp": cmp and not (k == "range" and melee), "affix": false, "lost": false})
	if cmp:
		for row in Loot.describe(cur):
			if row.size() >= 3 and not seen.has(row[2]):
				rows.append({"key": row[2], "name": Loc.t(row[0]), "text": "-", "diff": -Loot.base_stat(cur, row[2]), "cmp": true, "affix": false, "lost": true})
	var mine := _affix_sums(item)
	var theirs := _affix_sums(cur)
	for k in mine:
		rows.append({"key": k, "name": _affix_name(k), "text": _affix_val(k, mine[k]), "diff": float(mine[k]) - float(theirs.get(k, 0.0)), "cmp": cmp, "affix": true, "lost": false})
	for k in theirs:
		if not mine.has(k):
			rows.append({"key": k, "name": _affix_name(k), "text": "-", "diff": -float(theirs[k]), "cmp": true, "affix": true, "lost": true})
	return rows


## rows without a stat key (melee note, engine type)
func _stat_notes(item: Dictionary) -> Array:
	var out: Array = []
	for row in Loot.describe(item):
		if row.size() < 3:
			out.append("%s: %s" % [Loc.t(row[0]), Loc.t(row[1])])
	return out


func _affix_sums(item: Dictionary) -> Dictionary:
	var out := {}
	if item.is_empty():
		return out
	for a in item.aff:
		var k: String = a.k
		out[k] = float(out.get(k, 0.0)) + float(a.v) * (1.0 + 0.05 * int(item.plus))
	return out


func _affix_name(k: String) -> String:
	return Loc.t(str(Loot.AFFIXES.get(k, ["?"])[0]))


func _affix_pct(k: String) -> bool:
	return bool(Loot.AFFIXES.get(k, ["?", 0, 0, false, [], false])[5])


func _affix_val(k: String, v: float) -> String:
	return ("+%.1f%%" % v) if _affix_pct(k) else ("+%.1f" % v)


func _diff_text(r: Dictionary) -> String:
	if not r.cmp:
		return ""
	var d: float = r.diff
	var k: String = r.key
	if absf(d) < 0.005:
		return "="
	if r.affix:
		return ("%+.1f%%" % d) if _affix_pct(k) else ("%+.1f" % d)
	if k == "aspd":
		return "%+.2f" % d
	if BASE_PCT.has(k):
		return "%+.1f%%" % d if absf(d) < 1.0 else "%+d%%" % roundi(d)
	if k in ["range", "splash", "hp", "hull"]:
		return "%+d" % roundi(d)
	return "%+.1f" % d


func _diff_color(r: Dictionary) -> Color:
	if not r.cmp or absf(float(r.diff)) < 0.005:
		return UIKit.C_DIM
	return UIKit.C_GREEN if float(r.diff) > 0.0 else UIKit.C_RED


func _value_color(r: Dictionary, item: Dictionary) -> Color:
	if r.lost:
		return UIKit.C_DIM
	return Loot.rar_color(item).lightened(0.2) if r.affix else UIKit.C_WHITE


func _power_pct(item: Dictionary, cur: Dictionary) -> float:
	return (Loot.power_score(item) / maxf(Loot.power_score(cur), 0.01) - 1.0) * 100.0


func _cell(text: String, size: int, col: Color, w: int) -> Label:
	var l := UIKit.label(text, size, col)
	l.custom_minimum_size.x = w
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _name_cell(text: String, col: Color) -> Label:
	var l := UIKit.wrap_label(text, UIKit.FS_SMALL, col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## "compared with the equipped one" strip: its tile, name and the power change, or why there is nothing to compare
func _compare_bar(item: Dictionary, cur: Dictionary) -> Control:
	if cur.is_empty():
		var why := UIKit.wrap_label(Loc.t("ไม่มีของที่ใส่อยู่ให้เทียบ · เปิดจากช่องอุปกรณ์ของลูกเรือเพื่อดูส่วนต่าง"))
		why.name = "CompareBar"
		return why
	var pct := _power_pct(item, cur)
	var p := PanelContainer.new()
	p.name = "CompareBar"
	p.add_theme_stylebox_override("panel", UIKit.card_style(UIKit.C_BG2, UIKit.C_GREEN.darkened(0.4) if pct >= 0 else UIKit.C_RED.darkened(0.4), 3))
	var h := UIKit.hbox(4)
	p.add_child(h)
	h.add_child(_name_cell(Loc.t("เทียบกับที่ใส่อยู่"), UIKit.C_DIM))
	var t := UIKit.gear_tile(cur, cur.slot, 28)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	var cn := UIKit.label(Loot.item_name(cur), UIKit.FS_SMALL, Loot.rar_color(cur))
	cn.clip_text = true
	cn.custom_minimum_size.x = 40
	cn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cn)
	h.add_child(_cell(Loc.t("พลัง %+.0f%%") % pct, UIKit.FS_BIG, UIKit.C_GREEN if pct >= 0 else UIKit.C_RED, 0))
	return p


func _no_affix_note(item: Dictionary, parent: Control) -> void:
	if item.aff.is_empty():
		parent.add_child(UIKit.wrap_label(Loc.t("(ไม่มีคุณสมบัติพิเศษ — ระดับสูงขึ้นจะได้ 1-4 อย่าง)")))
	for n in _stat_notes(item):
		parent.add_child(UIKit.wrap_label(n, UIKit.FS_SMALL, UIKit.C_GOLD))


## one table, icon · name · value · +/- against the equipped item, striped rows, affixes under their own heading
func _stats_table(item: Dictionary, cur: Dictionary) -> void:
	if detail_equipped.is_empty():
		_list.add_child(_compare_bar(item, cur))
	var rows := _stat_rows(item, cur)
	var cmp := not cur.is_empty()
	var col := Loot.rar_color(item)
	var sp := UIKit.panel()
	sp.name = "StatTable"
	var sv := UIKit.vbox(0)
	sp.add_child(sv)
	var head := UIKit.hbox(4)
	var hn := UIKit.label(Loc.t("ค่าสถานะ"), UIKit.FS_SMALL, UIKit.C_DIM)
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hn)
	head.add_child(_cell(Loc.t("ของนี้"), UIKit.FS_SMALL, UIKit.C_DIM, 64))
	if cmp:
		head.add_child(_cell("+/-", UIKit.FS_SMALL, UIKit.C_DIM, 56))
	sv.add_child(head)
	sv.add_child(UIKit.divider(UIKit.C_LINE_DIM))
	var i := 0
	var in_affix := false
	for r in rows:
		if r.affix and not in_affix:
			in_affix = true
			var ah := UIKit.label(Loc.t("คุณสมบัติพิเศษ"), UIKit.FS_SMALL, col)
			sv.add_child(ah)
		var stripe := PanelContainer.new()
		var bg := UIKit.C_BG if i % 2 == 0 else UIKit.C_BG2.lightened(0.04)
		stripe.add_theme_stylebox_override("panel", UIKit.card_style(bg, bg, 2))
		var h := UIKit.hbox(4)
		stripe.add_child(h)
		var ic := UIKit.icon_rect(STAT_ICON.get(r.key, "gear"), 16)
		if r.lost:
			ic.modulate = Color(1, 1, 1, 0.4)
		h.add_child(ic)
		h.add_child(_name_cell(r.name, UIKit.C_DIM if r.lost else (col.lightened(0.2) if r.affix else UIKit.C_TEXT)))
		h.add_child(_cell(r.text, UIKit.FS, _value_color(r, item), 64))
		if cmp:
			h.add_child(_cell(_diff_text(r), UIKit.FS_SMALL, _diff_color(r), 56))
		sv.add_child(stripe)
		i += 1
	_no_affix_note(item, sv)
	_list.add_child(sp)


# ------------------------------------------------------------------ items & forge
func _build_items() -> void:
	set_title(Loc.t("ITEMS / ไอเทมและทรัพยากร"))
	var grid := GridContainer.new()
	grid.columns = 2 if box.custom_minimum_size.x < 500 else 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["power", "water", "food"] + (Data.RAW_KEYS if Data.raw_food() else []) + ["scrap"]:
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
		var b := UIKit.button(Loc.t("ใช้"), "green")
		b.pressed.connect(func(): Game.use_item(use_id))
		h.add_child(b)
	return p


func _build_forge() -> void:
	set_title(Loc.t("FORGE / เตาหลอม"))
	_list.add_child(UIKit.wrap_label(Loc.t("หลอมอุปกรณ์ระดับเดียวกัน 3 ชิ้น (ไม่ล็อก ตัวอ่อนสุดก่อน) → 1 ชิ้นระดับสูงขึ้น · ใช้ชิ้นส่วนจากการแยกอุปกรณ์เป็นค่าหลอม")))
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
		h.add_child(UIKit.label(Loc.t("มี%d") % c.size(), UIKit.FS_SMALL, UIKit.C_DIM))
		var cost := Loot.synth_cost(r)
		var b := UIKit.button("%d" % int(cost.components), "yellow", "cog")
		b.disabled = c.size() < 3 or not Game.can_afford(cost)
		var rr: int = r
		b.name = "Synthesize%d" % r
		b.pressed.connect(func(): _request_synthesize(rr))
		h.add_child(b)
		_list.add_child(row)
	_list.add_child(UIKit.header("BULK SALVAGE", Loc.t("แยกทีละมาก (ข้ามของล็อก)")))
	var bh := UIKit.flow(3)
	for r in 3:
		var b := UIKit.button("≤ %s" % Loot.rarity(r).th, "red", "cog")
		var rr: int = r
		b.name = "BulkSalvage%d" % r
		b.pressed.connect(func(): _request_bulk_salvage(rr))
		bh.add_child(b)
	_list.add_child(bh)
	_list.add_child(UIKit.header("AUTO SALVAGE", Loc.t("แยกอัตโนมัติเมื่อดรอป")))
	var ah := UIKit.hbox(3)
	var cur := int(Game.s.combat.get("auto_salvage", -1))
	for opt in AUTO_SALV:
		var b2 := UIKit.button(Loc.t(opt[1]), "yellow" if cur == int(opt[0]) else "gray")
		var val: int = opt[0]
		b2.pressed.connect(func(): _request_auto_salvage(val))
		ah.add_child(b2)
	_list.add_child(ah)


func _gear_available(targets: Array) -> bool:
	for target in targets:
		var found := false
		for item in Loot.stash():
			if is_same(item, target) and not item.lock:
				found = true
				break
		if not found:
			return false
	return true


func _request_salvage(item: Dictionary) -> void:
	var value := Loot.salvage_value(item)
	ConfirmPanel.ask(self, Loc.t("แยกอุปกรณ์"), Loc.t("%s จะหายไปถาวร ได้ %d ชิ้นส่วน และ %d เศษเหล็ก ย้อนคืนไม่ได้") % [Loot.item_name(item), value.components, value.scrap], Loc.t("ยืนยันแยกอุปกรณ์"), func():
		Loot.salvage(int(item.uid))
		detail_uid = -1
		refresh(), func(): return _gear_available([item]))


func _request_bulk_salvage(rar: int) -> void:
	var targets: Array = []
	var ids: Array = []
	var components := 0
	var scrap := 0
	for item in Loot.stash():
		if int(item.rar) <= rar and not item.lock:
			targets.append(item)
			ids.append(int(item.uid))
			var value := Loot.salvage_value(item)
			components += int(value.components)
			scrap += int(value.scrap)
	if targets.is_empty():
		Game.toast.emit(Loc.t("ไม่มีอุปกรณ์ที่แยกได้"), "info")
		return
	ConfirmPanel.ask(self, Loc.t("แยกอุปกรณ์หลายชิ้น"), Loc.t("อุปกรณ์ไม่ล็อกระดับ ≤ %s จำนวน %d ชิ้นจะหายไปถาวร ได้ %d ชิ้นส่วน และ %d เศษเหล็ก ย้อนคืนไม่ได้") % [Loot.rarity(rar).th, targets.size(), components, scrap], Loc.t("ยืนยันแยก %d ชิ้น") % targets.size(), func():
		var total := Loot.salvage_bulk(rar, ids)
		Game.toast.emit(Loc.t("แยก %d ชิ้น ได้ %d ชิ้นส่วน + %d เศษเหล็ก") % [total.count, total.components, total.scrap], "good")
		refresh(), func(): return _gear_available(targets))


func _same_synthesis(rar: int, targets: Array) -> bool:
	var current := Loot.synth_candidates(rar)
	if current.size() < 3 or not _gear_available(targets):
		return false
	for i in 3:
		if not is_same(current[i], targets[i]):
			return false
	return true


func _request_synthesize(rar: int) -> void:
	var targets := Loot.synth_candidates(rar).slice(0, 3)
	if targets.size() < 3:
		return
	var names: Array = []
	for item in targets:
		names.append(Loot.item_name(item))
	ConfirmPanel.ask(self, Loc.t("หลอมอุปกรณ์"), Loc.t("ใช้ %d ชิ้นส่วน และทำลายอุปกรณ์ 3 ชิ้นนี้เพื่อสุ่มของระดับ %s ย้อนคืนไม่ได้:\n%s") % [int(Loot.synth_cost(rar).components), Loot.rarity(rar + 1).th, "\n".join(names)], Loc.t("ยืนยันหลอม 3 ชิ้น"), func():
		var out := Loot.synthesize(rar)
		if not out.is_empty():
			Game.toast.emit(Loc.t("หลอมสำเร็จ! ได้ %s [%s]") % [Loot.item_name(out), Loot.rarity(int(out.rar)).th], "biome" if int(out.rar) >= 3 else "good")
		refresh(), func(): return _same_synthesis(rar, targets))


func _request_auto_salvage(value: int) -> void:
	var state := Game.s
	var apply := func():
		Game.s.combat.auto_salvage = value
		refresh()
	if value > int(Game.s.combat.get("auto_salvage", -1)):
		ConfirmPanel.ask(self, Loc.t("เปิดแยกอัตโนมัติ"), Loc.t("อุปกรณ์ที่ดรอปใหม่ระดับ ≤ %s จะถูกแยกเป็นวัสดุทันทีและเก็บคืนไม่ได้ ของที่อยู่ในคลังตอนนี้ยังอยู่") % Loot.rarity(value).th, Loc.t("เปิดแยกอัตโนมัติ"), apply, func(): return is_same(Game.s, state))
	else:
		apply.call()


# ------------------------------------------------------------------ MV-554 multi-salvage
func _salvage_reset() -> void:
	salvage_pick = false
	salvage_sel = {}


## the stash items the grid shows for the current pick slot / filter
func _filtered_stash() -> Array:
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
	return items


func _toggle_sel(uid: int) -> void:
	if salvage_sel.has(uid):
		salvage_sel.erase(uid)
	else:
		salvage_sel[uid] = true


## red veil + X in the corner of a ticked tile
func _picked_mark(px: int) -> Control:
	var c := Control.new()
	c.name = "PickedMark"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(UIKit.C_RED, 0.35)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(veil)
	var x := UIKit.icon_rect("close", 16)
	x.position = Vector2(px - 14, -2)        # the lock's corner (a ticked item is never locked), icon stays visible
	c.add_child(x)
	return c


## ticked items still in the stash and unlocked (a drop, a lock or a salvage elsewhere can change the set)
func _salvage_targets() -> Array:
	var out: Array = []
	for it in Loot.stash():
		if not it.lock and salvage_sel.has(int(it.uid)):
			out.append(it)
	return out


func _salvage_total(targets: Array) -> Dictionary:
	var t := {"components": 0, "scrap": 0}
	for it in targets:
		var v := Loot.salvage_value(it)
		t.components += int(v.components)
		t.scrap += int(v.scrap)
	return t


## sticky bar under the grid in select mode: count, what it gives, select all shown / clear, salvage
func _build_salvage_footer() -> void:
	for c in _footer.get_children():
		_footer.remove_child(c)
		c.queue_free()
	_footer.visible = Features.on("multi_salvage") and tab == "gear" and salvage_pick and pick_slot == "" and detail_uid < 0 and detail_equipped.is_empty()
	if not _footer.visible:
		return
	var targets := _salvage_targets()
	var tot := _salvage_total(targets)
	var v := UIKit.vbox(3)
	_footer.add_child(v)
	var line := UIKit.hbox(4)
	line.add_child(UIKit.icon_rect("cog", 16))
	var ll := UIKit.wrap_label(Loc.t("เลือก %d ชิ้น · ได้ %d ชิ้นส่วน + %d เศษเหล็ก") % [targets.size(), tot.components, tot.scrap], UIKit.FS_SMALL, UIKit.C_TEXT)
	ll.name = "SalvageTotal"
	line.add_child(ll)
	v.add_child(line)
	var h := UIKit.hbox(3)
	var all := UIKit.button(Loc.t("เลือกทั้งหมด"), "gray")
	all.name = "SalvageSelectAll"
	all.pressed.connect(func():
		for it in _filtered_stash():
			if not it.lock:
				salvage_sel[int(it.uid)] = true
		refresh())
	h.add_child(all)
	var clr := UIKit.button(Loc.t("ล้าง"), "gray")
	clr.name = "SalvageClear"
	clr.pressed.connect(func():
		salvage_sel = {}
		refresh())
	h.add_child(clr)
	h.add_child(UIKit.spacer())
	var go := UIKit.button(Loc.t("แยก %d ชิ้น") % targets.size(), "red", "cog")
	go.name = "MultiSalvageGo"
	go.disabled = targets.is_empty()
	go.pressed.connect(func(): _request_multi_salvage(_salvage_targets()))
	h.add_child(go)
	v.add_child(h)


func _request_multi_salvage(targets: Array) -> void:
	if targets.is_empty():
		return
	var ids: Array = []
	for it in targets:
		ids.append(int(it.uid))
	var tot := _salvage_total(targets)
	ConfirmPanel.ask(self, Loc.t("แยกอุปกรณ์หลายชิ้น"), Loc.t("อุปกรณ์ที่เลือก %d ชิ้นจะหายไปถาวร ได้ %d ชิ้นส่วน และ %d เศษเหล็ก ย้อนคืนไม่ได้") % [targets.size(), tot.components, tot.scrap], Loc.t("ยืนยันแยก %d ชิ้น") % targets.size(), func():
		var total := Loot.salvage_bulk(Loot.RARITY.size(), ids)
		Game.toast.emit(Loc.t("แยก %d ชิ้น ได้ %d ชิ้นส่วน + %d เศษเหล็ก") % [total.count, total.components, total.scrap], "good")
		salvage_sel = {}
		refresh(), func(): return _gear_available(targets))
