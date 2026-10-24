class_name EventPopup
extends ModalPanel
## Random-event decision terminal (blinking red alarm frame, 160x80 illustration shown at x2,
## danger skulls, choices, defender selection for fights, outcome + logbook unlocks).

var event_id := ""
var _choice := -1
var _selected: Array = []
var _t := 0.0
var _alarm: StyleBoxFlat
var _outcome_ok := -1   # -1 deciding, 0 failed, 1 survived

## fired when the outcome screen opens (hook for a good/bad stinger once sfx exist)
signal outcome_shown(ok: bool)


func _build() -> void:
	frame_color = UIKit.C_RED
	_alarm = UIKit.card_style(Color("160a08f4"), UIKit.C_RED, 6)
	_alarm.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", _alarm)
	title_lbl.add_theme_color_override("font_color", UIKit.C_RED)
	close_btn.visible = false


func _on_backdrop_tap() -> void:
	pass   # events must be answered


func show_event(id: String) -> void:
	event_id = id
	_outcome_ok = -1
	_choice = -1
	_selected = []
	decide_total = Game.event_decide_sec(id)
	decide_left = decide_total if decide_total > 0.0 else -1.0
	open()


# ------------------------------------------------------------------ quick-time timer (MV-134)
const IDLE_SEC := 20.0
var decide_total := 0.0
var decide_left := -1.0       # seconds left to decide, -1 = no timer
var since_input := 999.0      # seconds since the player last pressed anything (any window)
var _timer_bar: ProgressBar
var _timer_lbl: Label


## every press, before the GUI eats it: the clock only runs for a player who is actually there
func _input(e: InputEvent) -> void:
	if (e is InputEventMouseButton or e is InputEventScreenTouch or e is InputEventKey) and e.pressed:
		since_input = 0.0


## the clock runs while the player is deciding and has touched the screen in the last IDLE_SEC: idle play or a
## dark screen leaves the event waiting (the vehicle stays parked), like before
func clock_running() -> bool:
	return is_open and decide_left > 0.0 and _outcome_ok == -1 and since_input < IDLE_SEC


func _tick_timer(delta: float) -> void:
	if clock_running():
		decide_left -= delta
		if decide_left <= 0.0:
			time_out()
			return
	if _timer_bar and is_instance_valid(_timer_bar):
		_timer_bar.value = decide_left / maxf(decide_total, 0.01)
		var auto: Dictionary = Data.EVENTS[event_id].choices[Game.event_auto_choice(event_id)]
		_timer_lbl.text = (Loc.t("ตัดสินใจภายใน %d วิ · หมดเวลา = %s") % [int(ceilf(decide_left)), Loc.t(str(auto.th))]) if clock_running() \
			else Loc.t("เวลาหยุดรอ แตะจอเพื่อเดินต่อ · หมดเวลา = %s") % Loc.t(str(auto.th))


## time is up: the crew does the cautious thing (Game.event_auto_choice); a fight goes out with the two strongest
func time_out() -> void:
	if not is_open or _outcome_ok != -1:
		return
	var i := _choice if _choice >= 0 else Game.event_auto_choice(event_id)
	var ch: Dictionary = Data.EVENTS[event_id].choices[i]
	if str(ch.action) == "fight" and _selected.is_empty():
		_selected = Game.auto_defenders()
	decide_left = -1.0
	Trace.rec("event", "time out %s -> #%d %s" % [event_id, i, str(ch.action)])
	Game.toast.emit(Loc.t("หมดเวลา! ลูกเรือตัดสินใจเอง: %s") % Loc.t(str(ch.th)), "warn")
	_resolve(i)


func _process(delta: float) -> void:
	since_input += delta
	if not is_open:
		return
	_tick_timer(delta)
	_t += delta
	match _outcome_ok:
		1: _alarm.border_color = UIKit.C_GREEN if int(_t * 1.5) % 2 == 0 else UIKit.C_LINE
		0: _alarm.border_color = UIKit.C_RED if int(_t * 6.0) % 2 == 0 else Color("3a0c08")
		_: _alarm.border_color = UIKit.C_RED if int(_t * 4.0) % 2 == 0 else UIKit.C_GOLD


func refresh() -> void:
	clear_body()
	var ev: Dictionary = Data.EVENTS[event_id]
	set_title("ALERT: %s / %s" % [ev.en, ev.th])
	var v := media_layout(load("res://assets/events/%s.png" % ev.image), UIKit.C_GOLD)
	v.add_child(UIKit.wrap_label(ev.desc, UIKit.FS, UIKit.C_TEXT))
	var dh := UIKit.hbox(3)
	var danger := Game.event_danger(event_id)
	var dtxt: String = [Loc.t("ปลอดภัย"), Loc.t("ต่ำ"), Loc.t("ปานกลาง"), Loc.t("สูง"), Loc.t("สูงมาก"), Loc.t("อันตรายถึงชีวิต"), Loc.t("หายนะ")][clampi(danger, 0, 6)]
	var dl := UIKit.label("DANGER", UIKit.FP, UIKit.C_RED, true)
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dh.add_child(dl)
	if danger > 0:
		dh.add_child(UIKit.skulls(danger))
	var dt := UIKit.wrap_label(dtxt, UIKit.FS_SMALL, UIKit.C_RED)
	dt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dh.add_child(dt)
	v.add_child(dh)
	_timer_bar = null
	if decide_left > 0.0:
		var th := UIKit.hbox(3)
		var tl := UIKit.label("TIME", UIKit.FP, UIKit.C_ORANGE, true)
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		th.add_child(tl)
		_timer_bar = UIKit.progress(UIKit.C_ORANGE, 4)
		_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		th.add_child(_timer_bar)
		v.add_child(th)
		_timer_lbl = UIKit.wrap_label("", UIKit.FS_SMALL, UIKit.C_ORANGE)
		v.add_child(_timer_lbl)
		_tick_timer(0.0)
	if _choice < 0:
		for i in ev.choices.size():
			v.add_child(_choice_button(ev.choices[i], i))
	else:
		_build_defenders(v, ev.choices[_choice])


func _choice_button(ch: Dictionary, i: int) -> ChoiceButton:
	var b := ChoiceButton.new(ch.th, ch.en, ch.get("sub", ""), ch.get("color", "green"))
	if ch.has("lore") and not Lore.is_unlocked(str(ch.lore)):
		b.add_badge(Atlas.icon("book"), Loc.t("ปลดล็อกบันทึกใหม่"))
	if ch.has("cost"):
		b.disabled = not Game.can_afford(ch.cost)
	b.pressed.connect(func():
		if ch.action == "fight":
			_choice = i
			refresh()
		else:
			_resolve(i))
	return b


func _build_defenders(v: VBoxContainer, _ch: Dictionary) -> void:
	v.add_child(UIKit.header("DEFENDERS", Loc.t("เลือกคนออกไปจัดการ (สูงสุด 2)")))
	var list: Array = []
	for d in Game.s.dwellers:
		if not Game.is_away(d):
			list.append(d)
	list.sort_custom(func(a, b): return Game.dweller_power(a) > Game.dweller_power(b))
	for d in list:
		var did: int = d.id
		var sel := _selected.has(did)
		var row := UIKit.panel(UIKit.C_BG2, UIKit.C_GREEN if sel else UIKit.C_LINE_DARK)
		var h := UIKit.hbox(4)
		row.add_child(h)
		h.add_child(UIKit.portrait(d.variant))
		var info := UIKit.vbox(1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.label(Loc.t("%s Lv%d  พลัง %.0f") % [d.name, d.lvl, Game.dweller_power(d)], UIKit.FS_SMALL))
		var hp := UIKit.progress(UIKit.C_RED, 3)
		hp.value = float(d.hp) / float(d.max_hp)
		info.add_child(hp)
		h.add_child(info)
		var b := UIKit.button(Loc.t("เลือก") if not sel else Loc.t("ยกเลิก"), "green" if not sel else "gray")
		b.disabled = not sel and _selected.size() >= 2
		b.pressed.connect(func():
			if _selected.has(did):
				_selected.erase(did)
			elif _selected.size() < 2:
				_selected.append(did)
			refresh())
		h.add_child(b)
		v.add_child(row)
	var total := Game.armory_bonus()
	for did in _selected:
		total += Game.dweller_power(Game.dweller_by_id(did))
	var need := 8.0 + Game.event_danger(event_id) * 6.0
	v.add_child(UIKit.wrap_label(Loc.t("พลังทีม %.0f vs อันตราย ~%.0f (ห้องอาวุธ +%.0f)") % [total, need, Game.armory_bonus()], UIKit.FS_SMALL, UIKit.C_GREEN if total >= need else UIKit.C_ORANGE))
	var hb := UIKit.hbox(4)
	var back := UIKit.button(Loc.t("< กลับ"), "gray")
	back.pressed.connect(func():
		_choice = -1
		refresh())
	hb.add_child(back)
	var go := UIKit.button(Loc.t("ส่งทีมออกไปรบ!"), "red", "skull")
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.disabled = _selected.is_empty()
	go.pressed.connect(func(): _resolve(_choice))
	hb.add_child(go)
	v.add_child(hb)


## outcome stamp per action: [EN ok, TH ok, EN fail, TH fail]; a choice's own "stamp" wins (success only)
const STAMPS := {
	"fight": ["VICTORY", "ชนะแล้ว", "DEFEATED", "พ่ายแพ้"],
	"flee": ["ESCAPED", "หนีพ้น"],
	"pay": ["PAID", "จ่ายแล้ว"],
	"repair": ["REPAIRED", "ซ่อมเสร็จ"],
	"ram": ["RAMMED", "ชนฝ่าไปได้"],
	"push": ["MADE IT", "ฝ่ามาได้"],
	"loot": ["LOOTED", "ได้ของมา"],
	"recruit": ["NEW FACE", "มีคนมาเพิ่ม"],
	"gift": ["SHARED", "แบ่งปันแล้ว"],
	"trade": ["DEAL", "ตกลงกันได้"],
	"shelter": ["SHELTERED", "หลบทันแล้ว"],
	"check": ["SUCCESS", "สำเร็จ", "FAILED", "พลาดท่า"],
	"gamble": ["JACKPOT", "ถูกรางวัล", "BUST", "แพ้พนัน"],
	"adopt": ["NEW PET", "สมาชิกใหม่"],
	"detour": ["DETOUR", "อ้อมไปอีกทาง"],
	"ignore": ["MOVED ON", "ไปต่อ"],
}


static func stamp_text(choice: Dictionary, ok: bool) -> Array:
	if ok and choice.has("stamp"):
		return choice.stamp
	var st: Array = STAMPS.get(str(choice.get("action", "")), ["DONE", Loc.t("เรียบร้อย")])
	return [st[0], Loc.t(st[1])] if ok or st.size() < 4 else [st[2], Loc.t(st[3])]


func _resolve(i: int) -> void:
	var before := _snapshot()
	var res := Game.resolve_event(event_id, i, _selected)
	if not res.ok and Game.active_event != "":
		Game.toast.emit(res.text, "warn")
		return
	_show_outcome(res, _changes(before, _snapshot()), Data.EVENTS[event_id].choices[i])


## everything an event can touch, so the outcome screen can show what actually changed
func _snapshot() -> Dictionary:
	var crew := {}
	for d in Game.s.dwellers:
		crew[int(d.id)] = {"hp": float(d.hp), "rads": float(d.rads), "happy": float(d.happy), "xp": float(d.xp)}
	return {"res": (Game.s.res as Dictionary).duplicate(), "items": (Game.s.items as Dictionary).duplicate(),
		"hull": float(Game.s.hull), "gear": Loot.stash().size(), "stall": float(Game.s.stall), "crew": crew}


func _changes(a: Dictionary, b: Dictionary) -> Dictionary:
	var rows := []
	for k in b.res:
		var dv := int(round(float(b.res[k]) - float(a.res.get(k, 0.0))))
		if dv != 0:
			rows.append({"icon": Data.item_icon(k), "name": Data.item_name(k), "n": dv})
	var keys: Array = (a.items as Dictionary).keys()
	for k in b.items:
		if not keys.has(k):
			keys.append(k)
	for k in keys:
		var dv := int(b.items.get(k, 0)) - int(a.items.get(k, 0))
		if dv != 0:
			rows.append({"icon": Data.item_icon(str(k)), "name": Data.item_name(str(k)), "n": dv})
	if int(b.gear) > int(a.gear):
		rows.append({"icon": "chest", "name": Loc.t("อุปกรณ์ใหม่"), "n": int(b.gear) - int(a.gear)})
	var hd := int(round(float(b.hull) - float(a.hull)))
	if hd != 0:
		rows.append({"icon": "hull", "name": Loc.t("ตัวถัง"), "n": hd, "suffix": "%"})
	if float(b.stall) > float(a.stall) + 0.5:
		rows.append({"icon": "pause", "name": Loc.t("จอดรอ"), "n": int(b.stall), "suffix": Loc.t(" วิ"), "neutral": true})
	var crew := []
	for d in Game.s.dwellers:
		var id := int(d.id)
		var tags := []
		if not (a.crew as Dictionary).has(id):
			tags.append(["NEW", UIKit.C_GOLD])
		else:
			var o: Dictionary = a.crew[id]
			var c: Dictionary = b.crew[id]
			var dhp := int(round(c.hp - o.hp))
			if dhp != 0:
				tags.append(["%+d HP" % dhp, UIKit.C_GREEN if dhp > 0 else UIKit.C_RED])
			var drad := int(round(c.rads - o.rads))
			if drad > 0:
				tags.append(["+%d RAD" % drad, UIKit.C_ORANGE])
			var dxp := int(round(c.xp - o.xp))
			if dxp > 0:
				tags.append(["+%d XP" % dxp, UIKit.C_BLUE])
			var dh := int(round(c.happy - o.happy))
			if dh != 0:
				tags.append(["%+d :)" % dh, UIKit.C_GREEN if dh > 0 else UIKit.C_RED])
		if not tags.is_empty():
			crew.append({"d": d, "tags": tags})
	return {"rows": rows, "crew": crew}


func _show_outcome(res: Dictionary, ch: Dictionary, choice: Dictionary) -> void:
	_outcome_ok = 1 if res.ok else 0
	clear_body()
	set_title(Loc.t("OUTCOME / ผลลัพธ์"))
	var col := UIKit.C_GREEN if res.ok else UIKit.C_RED
	var ev: Dictionary = Data.EVENTS[event_id]
	var v := media_layout(load("res://assets/events/%s.png" % ev.image), col)
	var st := stamp_text(choice, res.ok)
	OutcomeKit.stamp(media, str(st[0]), str(st[1]), col, not res.ok)
	var l := UIKit.wrap_label(res.text, UIKit.FS_BIG, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var delay := OutcomeKit.lists(v, ch.rows, ch.crew, col, Loc.t("ทรัพยากรที่เปลี่ยนไป"), 0.35)
	var ok := UIKit.button(Loc.t("ตกลง  CONTINUE"), "green" if res.ok else "red", "play")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.custom_minimum_size.y = 32
	ok.pressed.connect(close)
	v.add_child(ok)
	OutcomeKit.fade_in(ok, delay)
	outcome_shown.emit(res.ok)
	if not res.ok:
		get_tree().call_group("shake", "shake", 6.0)
