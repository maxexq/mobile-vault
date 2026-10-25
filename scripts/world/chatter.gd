class_name Chatter
extends Node2D
## Idle chatter: every so often a survivor says a context-aware line (Lore.pick_line) in a little
## green terminal speech bubble above their head. Bubbles sit on a screen-space layer of the world
## viewport (always 1:1 pixels, even while the camera is zoomed into a room) and track the speaker.
## MV-427 situational lines ("barks", Lore.BARKS): said when something happens: raid warning / start / won, a boss
## entrance, a hero badly hurt, kills, heals, the van hit, a reserve tagging in, the squad wiped, an expedition
## leaving / back, a landmark, a weather change, a new area, a room finished, a Vault level. The right person says
## it (the hurt hero, someone on the roof for fight lines, someone inside for "the van got hit", someone who stayed
## behind when the team leaves). Each kind waits barks.cooldown s before it repeats, chatty kinds (kills, van hits,
## heals) only fire sometimes, and a bark may push out the oldest bubble (max BARK_MAX on screen). Switch barks.

const MIN_GAP := 9.0
const MAX_GAP := 20.0
const LIFE := 4.2
const MAX_W := 128
const BARK_COOL := 12.0       # s before the same kind of bark again (tune barks.cooldown)
const BARK_GAP := 1.5         # s between any two barks
const BARK_MAX := 3           # bubbles on screen when a bark comes in (idle chatter stops at 2)
const HURT_AT := 0.35         # a hero below this share of HP says a "hurt" line
## who says it: "combat" = a fighter on the roof deck, "aboard" = someone inside, "any" = whoever is in view;
## chance < 1 for kinds that would otherwise talk over every hit
const BARK_RULES := {
	"raid_warn": ["aboard", 1.0], "raid_start": ["combat", 1.0], "raid_won": ["combat", 1.0], "boss": ["combat", 1.0],
	"hurt": ["combat", 1.0], "kill": ["combat", 0.25], "healed": ["combat", 0.3], "van_hit": ["aboard", 0.25],
	"tag_in": ["combat", 1.0], "wiped": ["aboard", 1.0], "site": ["aboard", 1.0], "expedition_out": ["aboard", 1.0],
	"expedition_ok": ["any", 1.0], "expedition_fail": ["any", 1.0], "new_area": ["any", 1.0], "built": ["aboard", 1.0],
	"level_up": ["any", 1.0], "weather": ["any", 1.0],
}

var vehicle: Vehicle
var combat_view: CombatView
var focus_slot := -1          # during a room close-up only that room talks
var _t := 6.0
var _rng := RandomNumberGenerator.new()
var _bubbles: Array = []      # [{node, actor, t}]
var _cool := {}               # bark kind -> seconds left before it may fire again
var _bark_gap := 0.0
var _phase := "quiet"         # last Threat phase seen (a raid that ends without a wipe = "raid_won")
var _wiped := false
var last_bark := ""           # "<kind>|<line>" of the last bark said (autotest, GOD)
static var _tex: Texture2D
static var _tail: Texture2D


func _ready() -> void:
	_rng.randomize()
	z_index = 60
	if _tex == null:
		_tex = load("res://assets/ui/bubble.png")
		_tail = load("res://assets/ui/bubble_tail.png")
	# MV-427: the moments that make someone speak up
	Threat.phase_changed.connect(_on_phase)
	Combat.entrance.connect(func(_e): bark("boss"))
	Combat.hit.connect(_on_hit)
	Combat.enemy_removed.connect(func(_id, killed): if killed: bark("kill"))
	Combat.tagged_in.connect(func(_slot, did, _out): bark("tag_in", did))
	Combat.squad_wiped.connect(_on_wiped)
	Expedition.site_reached.connect(func(_id): bark("site"))
	Expedition.expedition_started.connect(func(): bark("expedition_out"))
	Expedition.expedition_finished.connect(func(r): bark("expedition_ok" if bool(r.get("ok", false)) else "expedition_fail"))
	Game.weather_changed.connect(func(w): bark("weather", -1, "weather:" + str(w)))
	Game.biome_changed.connect(func(_i, instant): if not instant: bark("new_area"))
	Game.construction_finished.connect(func(slot, _kind): bark("built", _builder(slot)))
	Game.vault_level_changed.connect(func(_l): if Game.started: bark("level_up"))


func _process(delta: float) -> void:
	_bark_gap = maxf(0.0, _bark_gap - delta)
	for k in _cool.keys():
		_cool[k] = float(_cool[k]) - delta
		if float(_cool[k]) <= 0.0:
			_cool.erase(k)
	for b in _bubbles.duplicate():
		b.t -= delta
		var actor = b.actor
		if b.t <= 0.0 or not is_instance_valid(actor) or not (actor as Node2D).is_visible_in_tree():
			_free_bubble(b)
			continue
		_place(b)
	if not Game.started or Game.s.is_empty() or Game.active_event != "":
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = _rng.randf_range(MIN_GAP, MAX_GAP)
	say_random()


func _candidates() -> Array:
	var out := []
	for rv in vehicle.room_views:
		if focus_slot >= 0 and rv.slot != focus_slot:
			continue
		for did in rv.actors:
			out.append([did, rv.actors[did]])
	if vehicle.cab_view and (focus_slot < 0 or focus_slot == Data.CAB_SLOT):
		for did in vehicle.cab_view.actors:
			out.append([did, vehicle.cab_view.actors[did]])
	if focus_slot < 0:
		for n in combat_view.hero_nodes:
			if n and not n.dead:
				out.append([n.did, n])
	return out


func say_random() -> void:
	var c := _candidates().filter(func(x): return not _talking(x[1]))   # never talk over someone mid-line (MV-427)
	if c.is_empty() or _bubbles.size() >= 2:
		return
	var pick: Array = c[_rng.randi() % c.size()]
	var d := Game.dweller_by_id(int(pick[0]))
	if d.is_empty():
		return
	var line := Lore.pick_line(d, _rng)
	if line != "":
		say(pick[1], line)


# =================================================================== MV-427 barks
## a situational line for this moment. did >= 0 = that person says it (if they are in view); line_kind lets one rule
## ("weather") use many line sets ("weather:rain"); force skips the cooldown and the chance (GOD, tests).
## Returns true when a bubble went up.
func bark(kind: String, did: int = -1, line_kind: String = "", force: bool = false) -> bool:
	if not Features.on("barks") or not Game.started or Game.s.is_empty() or Game.active_event != "":
		return false
	var rule: Array = BARK_RULES.get(kind, ["any", 1.0])
	if not force and (_cool.has(kind) or _bark_gap > 0.0 or _rng.randf() >= float(rule[1])):
		return false
	var speaker := _speaker(did, str(rule[0]))
	if speaker.is_empty():
		return false
	var d := Game.dweller_by_id(int(speaker[0]))
	var line := Lore.pick_bark(line_kind if line_kind != "" else kind, d, _rng)
	if line == "":
		return false
	while _bubbles.size() >= BARK_MAX:
		_free_bubble(_bubbles[0])
	say(speaker[1], line)
	_cool[kind] = Features.num("barks.cooldown", BARK_COOL)
	_bark_gap = BARK_GAP
	_t = maxf(_t, 4.0)        # idle chatter waits a little after a bark
	last_bark = "%s|%s" % [kind, line]
	return true


## [did, actor] of who says it: that person when they are in view, else someone from the pool ("combat" falls back to
## anyone in view when nobody is on the roof); [] = nobody to say it
func _speaker(did: int, pool: String) -> Array:
	var all := _candidates()
	if did >= 0:
		for c in all:
			if int(c[0]) == did:
				return c
	# whoever isn't mid-line already, so one bubble never replaces another (everyone talking = anyone)
	var free := all.filter(func(c): return not _talking(c[1]))
	if not free.is_empty():
		all = free
	var fighters := all.filter(func(c): return combat_view != null and combat_view.hero_nodes.has(c[1]))
	var picks: Array = all
	if pool == "combat" and not fighters.is_empty():
		picks = fighters
	elif pool == "aboard":
		var inside := all.filter(func(c): return not fighters.has(c))
		if not inside.is_empty():
			picks = inside
	if picks.is_empty():
		return []
	return picks[_rng.randi() % picks.size()]


func _talking(actor) -> bool:
	return _bubbles.any(func(b): return b.actor == actor)


## someone who worked on the room that just finished (-1 = anyone inside)
func _builder(slot: int) -> int:
	for d in Game.s.dwellers:
		if int(d.get("room", -1)) == slot and not Game.is_away(d):
			return int(d.id)
	return -1


func _on_wiped() -> void:
	_wiped = true
	bark("wiped")


func _on_phase(p: String) -> void:
	match p:
		"warning":
			bark("raid_warn")
		"raid":
			_wiped = false
			bark("raid_start")
		"quiet":
			if _phase == "raid" and not _wiped:
				bark("raid_won")
	_phase = p


func _hero(slot: int) -> Dictionary:
	if slot < 0 or slot >= Combat.heroes.size() or not (Combat.heroes[slot] is Dictionary):
		return {}
	return Combat.heroes[slot]


func _on_hit(kind: String, id: int, _amount: float, _crit: bool) -> void:
	match kind:
		"hero":
			var h := _hero(id)
			var hp := float(h.get("hp", 0.0))
			if not h.is_empty() and bool(h.get("alive", true)) and hp > 0.0 and hp < float(h.get("max", 1.0)) * HURT_AT:
				bark("hurt", int(h.get("did", -1)))
		"heal":
			var h := _hero(id)
			if not h.is_empty():
				bark("healed", int(h.get("did", -1)))
		"van":
			bark("van_hit")


func say(actor: Node2D, text: String) -> void:
	for b in _bubbles:
		if b.actor == actor:
			_free_bubble(b)
			break
	var root := Node2D.new()
	add_child(root)
	var box := NinePatchRect.new()
	box.texture = _tex
	box.patch_margin_left = 3
	box.patch_margin_right = 3
	box.patch_margin_top = 3
	box.patch_margin_bottom = 3
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIKit.font_main)
	l.add_theme_font_size_override("font_size", UIKit.FS_SMALL)
	l.add_theme_color_override("font_color", UIKit.C_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# measure: single line if it fits, otherwise wrap at MAX_W
	var w := UIKit.font_main.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FS_SMALL).x
	l.custom_minimum_size.x = minf(ceilf(w) + 1.0, MAX_W)
	l.position = Vector2(4, 1)
	root.add_child(l)
	l.reset_size()
	var sz := (l.size + Vector2(8, 3)).ceil()
	box.size = sz
	var tail := Sprite2D.new()
	tail.texture = _tail
	tail.centered = false
	tail.position = Vector2(6, sz.y - 1)
	root.add_child(tail)
	var b := {"node": root, "actor": actor, "t": LIFE, "size": sz}
	_bubbles.append(b)
	_place(b)
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.15)


func _place(b: Dictionary) -> void:
	var actor: Node2D = b.actor
	var root: Node2D = b.node
	var sz: Vector2 = b.size
	var xf := actor.get_global_transform_with_canvas()
	var z := xf.get_scale().y
	var head := xf.origin + Vector2(-7.0 * z, -21.0 * z)
	var pos := head + Vector2(-2, -sz.y - 3)
	var vp := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 2, vp.x - sz.x - 2)
	pos.y = clampf(pos.y, 2, vp.y - sz.y - 2)
	# MV-427: two people side by side: the newer bubble stacks above the older one instead of covering it
	for o in _bubbles:
		if o == b:
			break
		var on: Node2D = o.node
		if not is_instance_valid(on):
			continue
		var other := Rect2(on.position, o.size)
		if Rect2(pos, sz).grow(1.0).intersects(other):
			pos.y = maxf(2.0, other.position.y - sz.y - 2.0)
	root.position = pos.round()


func _free_bubble(b: Dictionary) -> void:
	_bubbles.erase(b)
	var n: Node2D = b.node
	if is_instance_valid(n):
		var tw := n.create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 0.2)
		tw.tween_callback(n.queue_free)
