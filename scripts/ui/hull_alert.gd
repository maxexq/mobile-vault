class_name HullAlert
extends Control
## MV-250: a warning that can't be missed before the vehicle breaks down. Three stages of hull left (tune
## hull_warning.warn / danger / critical, default 50 / 25 / 10 %):
##  * each time the hull drops into a worse stage: a toast saying what happens next, and alerted(stage) makes Main
##    shake the screen lightly (only with Settings "shake" on, scaled by fx.shake; DANGER and CRITICAL also buzz the
##    phone with Settings "vibrate"). The game has no sound yet, so the buzz stands in for a warning sound.
##  * DANGER and CRITICAL keep a red pulsing frame round the screen (slower than 2 flashes/s) and a strip above the
##    route bar with the hull %, what it means and a repair button (Game.repair_hull, the same price as the build
##    menu's); WARN shows the strip for a few seconds only
##  * the HUD hull bar now follows every hit and blinks while CRITICAL (HUD._update_hull_bar)
##  * a stage clears again only once the hull is 5 % above its line, so a hull hovering on 25 % doesn't re-alert
##  * the stage is not saved: after loading a damaged save the current stage alerts once, so it's never missed
##  * at 0 the existing wreck countdown (Meta) takes over; switch hull_warning off = none of this.
## GOD → รถ → hull 100/50/10/0 + "เตือนตัวถัง" previews. Autotest --only=hull_warning.

signal alerted(stage: int)

const WARN := 1
const DANGER := 2
const CRITICAL := 3
const HYST := 0.05            # share of max hull above a line before its stage clears
const WARN_SHOW := 8.0        # s the WARN strip stays up

var stage := 0
var _t := 0.0
var _strip_t := 0.0
var _edge: Control
var _strip: PanelContainer
var _lbl: Label
var _fix: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge = Control.new()
	_edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.draw.connect(_draw_edge)
	add_child(_edge)
	_strip = PanelContainer.new()
	_strip.name = "HullAlertStrip"
	_strip.add_theme_stylebox_override("panel", UIKit.card_style(Color(0.16, 0.03, 0.02, 0.94), UIKit.C_RED, 3))
	_strip.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := UIKit.hbox(4)
	_strip.add_child(h)
	h.add_child(UIKit.icon_rect("hull", 16))
	_lbl = UIKit.label("", UIKit.FS_SMALL, UIKit.C_RED.lightened(0.35))
	_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_lbl)
	_fix = UIKit.button("", "blue", "wrench")
	_fix.name = "HullAlertRepair"
	_fix.pressed.connect(func():
		if Game.repair_hull():
			Game.toast.emit(Loc.t("ซ่อมตัวถังเต็มแล้ว"), "good"))
	h.add_child(_fix)
	_strip.visible = false
	add_child(_strip)


func on() -> bool:
	return Features.on("hull_warning")


## the hull share where each stage starts
static func line(st: int) -> float:
	match st:
		WARN:
			return Features.num("hull_warning.warn", 0.5)
		DANGER:
			return Features.num("hull_warning.danger", 0.25)
		CRITICAL:
			return Features.num("hull_warning.critical", 0.1)
	return 1.0


static func ratio() -> float:
	return clampf(float(Game.s.hull) / maxf(1.0, Game.hull_max()), 0.0, 1.0)


## the stage for this hull share, given the stage it is in now (a stage clears HYST above its line)
static func stage_for(r: float, cur: int) -> int:
	var st := 0
	for s in [WARN, DANGER, CRITICAL]:
		var l := line(s)
		if r <= l or (cur >= s and r <= l + HYST):
			st = s
	return st


static func impact(st: int) -> String:
	match st:
		WARN:
			return Loc.t("ตัวถังเหลือ %d%% · ให้คนอยู่ห้องเครื่องช่วยซ่อม หรือซ่อมด้วยเศษเหล็ก")
		DANGER:
			return Loc.t("ตัวถังเหลือ %d%% อันตราย! โดนอีกไม่กี่ครั้งรถจะพัง ถ้าถึง 0 รถหยุดและมีเวลาซ่อมจำกัด")
		CRITICAL:
			return Loc.t("วิกฤต! ตัวถังเหลือ %d%% รถใกล้พัง ซ่อมเดี๋ยวนี้ ไม่งั้นอาจเสียรถถาวร")
	return ""


func _process(delta: float) -> void:
	var live := on() and Game.started and not Game.s.is_empty() and not bool(Game.s.get("wrecked", false))
	if not live:
		if stage != 0 or _strip.visible:
			stage = 0
			_strip.visible = false
			_edge.queue_redraw()
		return
	var st := stage_for(ratio(), stage)
	if st > stage:
		_raise(st)
	stage = st
	_t += delta
	_strip_t = maxf(0.0, _strip_t - delta)
	var show := stage >= DANGER or (stage == WARN and _strip_t > 0.0)
	_strip.visible = show
	if show:
		var txt := impact(stage) % int(round(ratio() * 100.0))
		if _lbl.text != txt:
			_lbl.text = txt
		var missing := Game.hull_max() - float(Game.s.hull)
		var cost := int(ceil(missing * 0.6))
		var ft := Loc.t("ซ่อม %d") % cost
		if _fix.text != ft:
			_fix.text = ft
		_fix.disabled = missing < 1.0 or not Game.can_afford({"scrap": cost})
	_edge.queue_redraw()


func _raise(st: int) -> void:
	_strip_t = WARN_SHOW
	Game.toast.emit(impact(st) % int(round(ratio() * 100.0)), "bad" if st >= DANGER else "warn")
	Trace.rec("travel", "hull warning stage %d" % st, {"hull": int(round(ratio() * 100.0))})
	alerted.emit(st)


## place the strip just above the route bar (HUD layout)
func place(x: float, bottom: float, w: float) -> void:
	_strip.custom_minimum_size.x = w
	_strip.size = Vector2(w, 0)
	_strip.reset_size()
	_strip.position = Vector2(floorf(x), floorf(bottom - _strip.size.y - 2.0))


## the pulsing red frame: three pixel bands, stronger and faster when CRITICAL
func pulse_alpha() -> float:
	if stage < DANGER:
		return 0.0
	var base := 0.55 if stage == CRITICAL else 0.3
	var hz := 1.2 if stage == CRITICAL else 0.6
	return base * (0.75 + 0.25 * sin(_t * TAU * hz))


func _draw_edge() -> void:
	var a := pulse_alpha()
	if a <= 0.0:
		return
	var r := Rect2(Vector2.ZERO, size)
	var w := 4.0 if stage == CRITICAL else 3.0
	for i in 3:
		var c := Color(UIKit.C_RED, a * (1.0 - 0.3 * i))
		var inset := w * i
		var o := r.grow(-inset)
		_edge.draw_rect(Rect2(o.position, Vector2(o.size.x, w)), c)
		_edge.draw_rect(Rect2(Vector2(o.position.x, o.end.y - w), Vector2(o.size.x, w)), c)
		_edge.draw_rect(Rect2(o.position + Vector2(0, w), Vector2(w, o.size.y - w * 2)), c)
		_edge.draw_rect(Rect2(Vector2(o.end.x - w, o.position.y + w), Vector2(w, o.size.y - w * 2)), c)
