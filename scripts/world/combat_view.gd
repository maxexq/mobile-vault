class_name CombatView
extends Node2D
## Renders the Combat simulation: enemies running after the convoy, squad on the roof / rear deck,
## tracers, hit flashes, damage numbers, skill effects, loot chests flying into the vault — plus the juice:
## pixel blood + gibs that splat on the road and slide away, brass casings tinkling onto the asphalt,
## acid globs, explosions, screen shake, boss mechanic tells, and road zombies the vehicle ploughs through.

const MAX_NUMBERS := 28
## The simulation (Combat) keeps its own coordinate space (deck at x=350, ground y=168) so balance is
## untouched; the view compresses it next to the truck's rear deck.
const SIM_DECK_X := 350.0
const VIEW_DECK_X := 272.0
const ROAD_SURFACE := 296.0
const ROAD_PX_PER_SEC := 90.0
## the convoy's rear moves back with every hitched trailer
static var rear_shift := 0.0
const X_K := 0.42
const VIEW_GROUND_Y := 300.0
## where each squad role stands on the truck (feet position, truck-local)
const HERO_VIEW := [Vector2(238, 36), Vector2(266, 260), Vector2(176, 36)]
const TURRET_MUZZLE := Vector2(271, 116)
## roof heroes / the roof turret follow the roof up on taller chassis
static var roof_shift := 0.0


static func hero_view(slot: int) -> Vector2:
	if slot == 1:
		return HERO_VIEW[1] + Vector2(rear_shift, 0)
	return HERO_VIEW[slot] + Vector2(0, roof_shift)

var vehicle: Vehicle
var enemy_nodes: Dictionary = {}   # id -> EnemyActor
var hero_nodes: Array = [null, null, null]
var deck: Sprite2D
var turret: Sprite2D
var spikes: Sprite2D
var _numbers := 0
var debris: Array = []          # [sprite, vel, landed, life]
var _ram_t := 4.0
var _road_zombies: Array = []


static func sim_to_view(p: Vector2) -> Vector2:
	var x := VIEW_DECK_X + rear_shift + (p.x - SIM_DECK_X) * X_K
	var y := VIEW_GROUND_Y - (Combat.GROUND_Y - p.y) * 0.9
	return Vector2(round(x), round(y))


func setup(v: Vehicle) -> void:
	vehicle = v
	turret = Sprite2D.new()
	turret.centered = false
	turret.position = Vehicle.TURRET_POS
	vehicle.body.add_child(turret)
	spikes = Sprite2D.new()
	spikes.texture = Atlas.tex("spikes")
	spikes.centered = false
	spikes.position = Vehicle.SPIKES_POS
	vehicle.body.add_child(spikes)
	Combat.enemy_spawned.connect(_on_spawn)
	Combat.enemy_removed.connect(_on_removed)
	Combat.hit.connect(_on_hit)
	Combat.shot.connect(_on_shot)
	Combat.skill_cast.connect(_on_skill)
	Combat.loot_dropped.connect(_on_loot)
	Combat.heroes_changed.connect(_sync_heroes)
	Combat.supply_found.connect(_on_supply)
	Combat.boss_event.connect(_on_boss_event)
	Game.gear_changed.connect(_sync_vault_parts)
	Meta.generation_started.connect(func(_g): _sync_heroes())
	Game.game_started.connect(func():
		_sync_heroes()
		_sync_vault_parts())
	_sync_vault_parts()


# ------------------------------------------------------------------ vault parts
func _sync_vault_parts() -> void:
	if Game.s.is_empty() or not Game.s.has("van_gear"):
		turret.visible = false
		spikes.visible = false
		return
	var t := Loot.van_equipped("turret")
	turret.visible = not t.is_empty()
	if turret.visible:
		turret.texture = Atlas.tex("turret_" + str(Loot.base(t).get("sprite", "mg")))
		turret.modulate = Color.WHITE.lerp(Loot.rar_color(t), 0.25)
	spikes.visible = not Loot.van_equipped("spikes").is_empty()


# ------------------------------------------------------------------ heroes
func _sync_heroes() -> void:
	roof_shift = vehicle.roof_dy()
	rear_shift = vehicle.rear_shift()
	spikes.position = Vehicle.SPIKES_POS + Vector2(rear_shift, 0)
	for i in Combat.ROLES.size():
		var h: Dictionary = Combat.heroes[i] if i < Combat.heroes.size() else {}
		var node: HeroActor = hero_nodes[i]
		if h.is_empty():
			if node:
				node.queue_free()
				hero_nodes[i] = null
			continue
		var d := Game.dweller_by_id(int(h.did))
		if node == null or node.did != int(h.did):
			if node:
				node.queue_free()
			node = HeroActor.new()
			vehicle.body.add_child(node)
			node.setup(d, i)
			hero_nodes[i] = node
		node.set_dead(not h.alive)
		node.position = hero_view(i)


func _process(delta: float) -> void:
	if rear_shift != vehicle.rear_shift() or roof_shift != vehicle.roof_dy():
		_sync_heroes()
	_tick_debris(delta)
	_tick_ram(delta)
	for i in hero_nodes.size():
		var node: HeroActor = hero_nodes[i]
		if node and i < Combat.heroes.size() and not Combat.heroes[i].is_empty():
			var h: Dictionary = Combat.heroes[i]
			node.hp_ratio = float(h.hp) / maxf(1.0, float(h.max))
			if node.dead != (not h.alive):
				node.set_dead(not h.alive)
	for e in Combat.enemies:
		var n: EnemyActor = enemy_nodes.get(int(e.id))
		if n:
			n.target = sim_to_view(Vector2(float(e.x), float(e.y)))
			n.hp_ratio = float(e.hp) / maxf(1.0, float(e.max))
			n.stunned = float(e.stun) > 0.0
			n.visible = not e.get("burrowed", false)
			n.enraged = e.get("enraged", false)


func hero_global(slot: int) -> Vector2:
	return vehicle.body.to_global(hero_view(slot) + Vector2(0, -9))


# ------------------------------------------------------------------ enemies
func _on_spawn(e: Dictionary) -> void:
	var n := EnemyActor.new()
	add_child(n)
	n.setup(e)
	enemy_nodes[int(e.id)] = n


func _on_removed(id: int, killed: bool) -> void:
	var n: EnemyActor = enemy_nodes.get(id)
	if n == null:
		return
	enemy_nodes.erase(id)
	if killed:
		var c := n.global_position + Vector2(0, -n.height() * 0.5)
		_poof(c, n.is_boss)
		_gore(c, 10 if not n.is_boss else 34, true)
		_splat(n.global_position)
		if n.is_boss:
			get_tree().call_group("shake", "shake", 6.0)
			_boom(c)
	n.die(killed)


func _on_hit(kind: String, id: int, amount: float, crit: bool) -> void:
	match kind:
		"enemy":
			var n: EnemyActor = enemy_nodes.get(id)
			if n:
				n.flash()
				_number(n.global_position + Vector2(randi_range(-4, 4), -n.height() - 6), amount, Color("ffefc0") if not crit else Color("ff9a1a"), crit)
				_gore(n.global_position + Vector2(0, -n.height() * 0.6), 2 if not crit else 5, false)
				if n.is_boss and crit:
					get_tree().call_group("shake", "shake", 1.5)
		"hero":
			var hn: HeroActor = hero_nodes[id] if id >= 0 and id < hero_nodes.size() else null
			if hn:
				hn.flash()
				_number(hero_global(id) + Vector2(0, -8), amount, Color("f0644a"), false)
		"dodge":
			if id >= 0 and id < hero_nodes.size() and hero_nodes[id]:
				_text(hero_global(id) + Vector2(-8, -12), "MISS", Color("8cfff6"))
		"heal":
			if id >= 0 and id < hero_nodes.size() and hero_nodes[id]:
				_number(hero_global(id) + Vector2(0, -10), amount, Color("98c050"), false, "+")
		"van":
			if randf() < 0.5:
				_number(vehicle.body.to_global(Vector2(randi_range(246, 260), randi_range(120, 240))), amount, Color("f0644a"), false)
			vehicle.spark()


func _on_shot(from_kind: String, from_id: int, to_kind: String, to_id: int, style: String) -> void:
	var a: Vector2
	var b: Vector2
	match from_kind:
		"hero":
			a = hero_global(from_id) + Vector2(5, 1)
			var hn: HeroActor = hero_nodes[from_id]
			if hn:
				hn.attack(style == "melee")
			if style == "bullet":
				_casing(a)
		"turret":
			a = vehicle.body.to_global(TURRET_MUZZLE)
			_casing(a)
		"roof":
			a = vehicle.body.to_global(Vector2(222, Vehicle.ROOF_Y + vehicle.roof_dy() - 12))
			_casing(a)
		"enemy":
			var en: EnemyActor = enemy_nodes.get(from_id)
			if en == null:
				return
			a = en.global_position + Vector2(-4, -en.height() * 0.6)
	match to_kind:
		"enemy":
			var tn: EnemyActor = enemy_nodes.get(to_id)
			if tn == null:
				return
			b = tn.global_position + Vector2(0, -tn.height() * 0.5)
		"hero":
			b = hero_global(to_id)
		"van":
			b = vehicle.body.to_global(Vector2(randi_range(248, 254) + rear_shift, randi_range(int(vehicle.roof_y()) + 10, 250)))
		"solar":
			b = vehicle.body.to_global(Vector2(randi_range(66, 118), Vehicle.SOLAR_Y + vehicle.roof_dy() + 8))
	if style == "melee":
		_spark(b)
		return
	if style == "acid":
		_glob(a, b)
		return
	var col: Color = {"bullet": Color(1, 0.95, 0.6, 0.95), "turret": Color(1, 0.7, 0.3, 0.95), "enemy": Color(1, 0.35, 0.3, 0.9)}.get(style, Color.WHITE)
	_tracer(a, b, col, 1.0 if style != "turret" else 1.5)


func _on_skill(slot: int, skill: String) -> void:
	var hn: HeroActor = hero_nodes[slot]
	if hn:
		hn.shout()
	match skill:
		"slam":
			var r := Sprite2D.new()
			r.texture = Atlas.tex("slam")
			r.centered = false
			r.position = Vector2(VIEW_DECK_X + 4, VIEW_GROUND_Y - 8)
			add_child(r)
			var tw := r.create_tween()
			tw.tween_property(r, "position:x", VIEW_DECK_X + 40, 0.3)
			tw.parallel().tween_property(r, "modulate:a", 0.0, 0.3)
			tw.tween_callback(r.queue_free)
			get_tree().call_group("shake", "shake", 3.0)
		"patch":
			for i in hero_nodes.size():
				if hero_nodes[i]:
					var p := FX.particles({"tex": Atlas.tex("pt_spark"), "amount": 8, "lifetime": 0.9, "dir": Vector2.UP, "spread": 40.0,
						"vmin": 14.0, "vmax": 26.0, "smin": 1.0, "smax": 1.0, "color": Color(0.3, 1, 0.45, 1), "explosiveness": 0.9})
					p.one_shot = true
					p.position = hero_global(i)
					add_child(p)
					p.emitting = true
					get_tree().create_timer(1.5).timeout.connect(p.queue_free)
		"volley":
			pass


func _on_loot(item: Dictionary, at: Vector2) -> void:
	var c := Sprite2D.new()
	c.texture = Atlas.tex("chest")
	c.modulate = Loot.rar_color(item)
	c.position = sim_to_view(at) + Vector2(0, -10)
	c.z_index = 20
	add_child(c)
	if int(item.rar) >= 2:
		var glow := Sprite2D.new()
		glow.texture = Atlas.tex("ring")
		glow.modulate = Loot.rar_color(item)
		c.add_child(glow)
		var gt := glow.create_tween().set_loops()
		gt.tween_property(glow, "modulate:a", 0.3, 0.25)
		gt.tween_property(glow, "modulate:a", 1.0, 0.25)
	var dest := vehicle.body.to_global(Vector2(260, 250))
	var tw := c.create_tween()
	tw.tween_property(c, "position:y", c.position.y - 14, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position:y", c.position.y - 2, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(c, "position", dest, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(c.queue_free)
	if int(item.rar) >= 3:
		get_tree().call_group("shake", "shake", 2.0)


# ------------------------------------------------------------------ fx helpers
func _tracer(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var l := Line2D.new()
	l.points = PackedVector2Array([a, b])
	l.width = w
	l.default_color = col
	l.z_index = 15
	add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(0.05)
	tw.tween_property(l, "modulate:a", 0.0, 0.06)
	tw.tween_callback(l.queue_free)
	_spark(b)


func _spark(at: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = Atlas.tex("pt_spark")
	s.position = at.round()
	s.z_index = 16
	add_child(s)
	var tw := s.create_tween()
	tw.tween_interval(0.08)
	tw.tween_callback(s.queue_free)


func _poof(at: Vector2, big: bool) -> void:
	var p := FX.particles({"tex": Atlas.tex("pt_smoke"), "amount": 14 if big else 7, "lifetime": 0.6, "dir": Vector2.UP, "spread": 180.0,
		"vmin": 12.0, "vmax": 36.0 if big else 22.0, "smin": 1.0, "smax": 2.0 if big else 1.0, "color": Color(0.85, 0.85, 0.85, 0.9), "explosiveness": 1.0, "damping": 30.0})
	p.one_shot = true
	p.position = at
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _number(at: Vector2, amount: float, col: Color, crit: bool, prefix: String = "") -> void:
	if _numbers >= MAX_NUMBERS or amount < 0.5:
		return
	_numbers += 1
	var l := Label.new()
	l.text = prefix + (UIKit.fmt(amount) if amount >= 10 else "%d" % int(ceil(amount))) + ("!" if crit else "")
	l.add_theme_font_override("font", UIKit.font_pixel)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("0b0a10"))
	l.add_theme_constant_override("outline_size", 2)
	l.position = (at - Vector2(6, 4)).round()
	l.z_index = 30
	add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - (14 if crit else 10), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.4)
	tw.chain().tween_callback(func():
		_numbers -= 1
		l.queue_free())


func _text(at: Vector2, txt: String, col: Color) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", UIKit.font_pixel)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("0b0a10"))
	l.add_theme_constant_override("outline_size", 2)
	l.position = at.round()
	l.z_index = 30
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 8, 0.5)
	tw.tween_callback(l.queue_free)


func _on_supply(kind: String, _amount: float, at: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = Atlas.icon(kind)
	s.position = sim_to_view(at) + Vector2(0, -12)
	s.z_index = 20
	add_child(s)
	var dest := vehicle.body.to_global(Vector2(260, 250))
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", s.position.y - 10, 0.25)
	tw.tween_interval(0.3)
	tw.tween_property(s, "position", dest, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)


# ------------------------------------------------------------------ gore / brass / acid / booms
func _gore(at: Vector2, n: int, kill: bool) -> void:
	if not bool(Settings.get_value("gore")):
		return
	for i in n:
		var s := Sprite2D.new()
		var r := randf()
		s.texture = Atlas.tex("pt_gib" if kill and r < 0.3 else ("pt_shard" if r > 0.92 else "pt_blood"))
		s.position = at.round()
		s.z_index = 14
		add_child(s)
		var v := Vector2(randf_range(-30, 50), randf_range(-70, -20) * (1.4 if kill else 0.8))
		debris.append([s, v, false, randf_range(3.0, 6.0)])


func _casing(at: Vector2) -> void:
	if debris.size() > 160:
		return
	var s := Sprite2D.new()
	s.texture = Atlas.tex("pt_casing")
	s.position = at.round()
	s.z_index = 14
	add_child(s)
	debris.append([s, Vector2(randf_range(-25, -5), randf_range(-45, -25)), false, randf_range(2.0, 4.0)])


func _splat(at: Vector2) -> void:
	if not bool(Settings.get_value("gore")):
		return
	var s := Sprite2D.new()
	s.texture = Atlas.tex("fx_splat_%d" % (randi() % 3))
	s.position = Vector2(at.x, ROAD_SURFACE).round()
	s.z_index = 2
	add_child(s)
	debris.append([s, Vector2.ZERO, true, 5.0])


func _glob(a: Vector2, b: Vector2) -> void:
	var g := Sprite2D.new()
	g.texture = Atlas.tex("pt_acid_glob")
	g.position = a.round()
	g.z_index = 15
	add_child(g)
	var mid := (a + b) * 0.5 + Vector2(0, -18)
	var tw := g.create_tween()
	tw.tween_method(func(t: float):
		var p := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
		g.position = p.round(), 0.0, 1.0, 0.45)
	tw.tween_callback(func():
		for k in 4:
			var d := Sprite2D.new()
			d.texture = Atlas.tex("pt_acid")
			d.position = b.round()
			d.z_index = 14
			add_child(d)
			debris.append([d, Vector2(randf_range(-30, 30), randf_range(-40, -10)), false, 1.2])
		g.queue_free())


func _boom(at: Vector2) -> void:
	var s := Sprite2D.new()
	s.position = at.round()
	s.z_index = 18
	add_child(s)
	var tw := s.create_tween()
	for k in 3:
		tw.tween_callback(func(): s.texture = Atlas.tex("fx_boom_%d" % k))
		tw.tween_interval(0.08)
	tw.tween_callback(s.queue_free)


## debris falls with gravity, lands on the road, then slides away with the asphalt and fades
func _tick_debris(delta: float) -> void:
	var road_v := ROAD_PX_PER_SEC * Game.speed_factor() if Game.started else 0.0
	for i in range(debris.size() - 1, -1, -1):
		var d: Array = debris[i]
		var s: Sprite2D = d[0]
		if not is_instance_valid(s):
			debris.remove_at(i)
			continue
		d[3] = float(d[3]) - delta
		if not d[2]:
			var v: Vector2 = d[1]
			v.y += 220.0 * delta
			d[1] = v
			var p := s.get_meta("fp", s.position) as Vector2
			p += v * delta
			if p.y >= ROAD_SURFACE + randf_range(-2.0, 2.0):
				p.y = ROAD_SURFACE + float(randi() % 3) - 1.0
				d[2] = true
			s.set_meta("fp", p)
			s.position = p.round()
		else:
			var p2 := s.get_meta("fp", s.position) as Vector2
			p2.x += road_v * delta
			s.set_meta("fp", p2)
			s.position = p2.round()
		if float(d[3]) < 0.6:
			s.modulate.a = maxf(0.0, float(d[3]) / 0.6)
		if float(d[3]) <= 0.0:
			s.queue_free()
			debris.remove_at(i)


# ------------------------------------------------------------------ boss tells
func _on_boss_event(kind: String, e: Dictionary) -> void:
	var n: EnemyActor = enemy_nodes.get(int(e.id))
	var at := n.global_position + Vector2(0, -n.height() * 0.5) if n else sim_to_view(Vector2(float(e.x), float(e.y)))
	match kind:
		"enrage":
			_text(at + Vector2(-10, -26), "RAGE!", Color("d4523c"))
			get_tree().call_group("shake", "shake", 4.0)
		"armor_break":
			_text(at + Vector2(-20, -26), "ARMOR BREAK", Color("e0b048"))
			for k in 8:
				var s := Sprite2D.new()
				s.texture = Atlas.tex("pt_shard")
				s.position = at.round()
				s.z_index = 14
				add_child(s)
				debris.append([s, Vector2(randf_range(-50, 50), randf_range(-80, -30)), false, 2.5])
			get_tree().call_group("shake", "shake", 2.5)
		"summon", "revive":
			_poof(at + Vector2(18, 0), true)
			_text(at + Vector2(-14, -26), "SUMMON" if kind == "summon" else "RISE!", Color("b090c0"))
		"burrow":
			_gore(Vector2(at.x, ROAD_SURFACE - 4), 10, false)
			_text(at + Vector2(-14, -20), "BURROW", Color("c8a46a"))
		"erupt":
			_boom(vehicle.body.to_global(Vector2(Vehicle.DECK.x + rear_shift, 280)))
			get_tree().call_group("shake", "shake", 5.0)
		"explode":
			_boom(at)
			_gore(at, 26, true)
			get_tree().call_group("shake", "shake", 4.0)
		"solar":
			_spark(vehicle.body.to_global(Vector2(randi_range(66, 118), Vehicle.SOLAR_Y + vehicle.roof_dy() + 6)))


# ------------------------------------------------------------------ road zombies the vehicle ploughs through
func _tick_ram(delta: float) -> void:
	var moving := Game.started and Game.is_moving()
	var road_v := ROAD_PX_PER_SEC * Game.speed_factor()
	if moving:
		_ram_t -= delta
		if _ram_t <= 0.0:
			_ram_t = randf_range(5.0, 12.0) / (1.0 + 0.3 * float(Game.s.get("biome", 0)))
			var z := AnimatedSprite2D.new()
			var sf := SpriteFrames.new()
			if not sf.has_animation("walk"):
				sf.add_animation("walk")
			sf.set_animation_speed("walk", 4.0)
			sf.add_frame("walk", Atlas.tex("en_walker_0"))
			sf.add_frame("walk", Atlas.tex("en_walker_1"))
			z.sprite_frames = sf
			z.centered = false
			z.offset = Vector2(-6, -20)
			z.play("walk")
			z.z_index = 6
			var fp := vehicle.to_global(Vector2(-90 - randf_range(0, 30), ROAD_SURFACE))
			z.set_meta("fp", fp)
			z.position = fp.round()
			add_child(z)
			_road_zombies.append(z)
	for i in range(_road_zombies.size() - 1, -1, -1):
		var z: AnimatedSprite2D = _road_zombies[i]
		var fp := z.get_meta("fp") as Vector2
		fp.x += (road_v + 8.0) * delta if moving else 8.0 * delta
		z.set_meta("fp", fp)
		z.position = fp.round()
		var front := vehicle.to_global(Vector2(-14 if Mods.level("spike_ram") > 0 else 0, 0)).x
		if fp.x >= front:
			_road_zombies.remove_at(i)
			var at := fp + Vector2(0, -10)
			_gore(at, 16, true)
			_splat(fp + Vector2(6, 0))
			get_tree().call_group("shake", "shake", 1.5 if Mods.level("spike_ram") == 0 else 2.5)
			vehicle.spark()
			var dmg := 0.6 * (1.0 - 0.25 * Mods.level("spike_ram"))
			Game.s.hull = maxf(0.0, float(Game.s.hull) - dmg)
			Game._add_res("scrap", 0.5 + Mods.level("spike_ram"))
			z.queue_free()


# =================================================================== actors
class EnemyActor extends Node2D:
	var spr: AnimatedSprite2D
	var target := Vector2.ZERO
	var hp_ratio := 1.0
	var stunned := false
	var is_boss := false
	var enraged := false
	var title := ""
	var _h := 16.0
	var _w := 14.0
	var _t := 0.0
	var _flash := 0.0
	var _base_mod := Color.WHITE

	func height() -> float:
		return _h

	func setup(e: Dictionary) -> void:
		is_boss = e.boss
		title = e.name if e.boss else ""
		position = CombatView.sim_to_view(Vector2(float(e.x), float(e.y)))
		target = position
		spr = AnimatedSprite2D.new()
		var sf: SpriteFrames
		var sprite: String = e.sprite
		spr.centered = false
		if sprite.begins_with("dw_"):
			sf = Atlas.dweller_frames(sprite)
			spr.flip_h = true
			spr.offset = Vector2(-Atlas.DW_W / 2, -Atlas.DW_H)
			_h = 16.0
			_w = 12.0
		else:
			sf = SpriteFrames.new()
			if not sf.has_animation("walk"):
				sf.add_animation("walk")
			sf.set_animation_speed("walk", 6.0)
			sf.add_frame("walk", Atlas.tex(sprite + "_0"))
			sf.add_frame("walk", Atlas.tex(sprite + "_1"))
			var r: Array = Atlas.regions[sprite + "_0"]
			_w = float(r[2])
			_h = float(r[3])
			spr.offset = Vector2(-floorf(_w / 2.0), -_h) if e.kind != "air" else Vector2(-floorf(_w / 2.0), -floorf(_h / 2.0))
		spr.sprite_frames = sf
		spr.play("walk")
		spr.frame = randi() % 2
		add_child(spr)
		if str(e.tint) != "":
			_base_mod = Color(str(e.tint))
		spr.modulate = _base_mod
		z_index = 5 if e.kind != "air" else 6
		if is_boss:
			z_index = 7

	func flash() -> void:
		_flash = 0.07

	func _process(delta: float) -> void:
		_t += delta
		var moving := position.distance_to(target) > 0.5
		position = position.lerp(target, clampf(delta * 10.0, 0.0, 1.0))
		spr.position = position.round() - position
		spr.speed_scale = 1.0 if moving else 0.4
		if stunned:
			spr.speed_scale = 0.0
		_flash -= delta
		var base := _base_mod
		if enraged and int(_t * 6.0) % 2 == 0:
			base = Color(1.6, 0.5, 0.45)
		spr.modulate = Color(4, 4, 4) if _flash > 0.0 else base
		queue_redraw()

	func _draw() -> void:
		var o := spr.position
		var w := maxf(14.0, _w) if not is_boss else maxf(30.0, _w)
		var y := -_h - 4.0
		var x0 := -floorf(w / 2.0)
		if hp_ratio < 0.999 and not is_boss:
			draw_rect(Rect2(o + Vector2(x0 - 1, y - 1), Vector2(w + 2, 4)), Color("0b0a10"))
			draw_rect(Rect2(o + Vector2(x0, y), Vector2(floorf(w * clampf(hp_ratio, 0, 1)), 2)), Color("f0644a") if not is_boss else Color("ff9a1a"))
		if stunned:
			for k in 3:
				var a := _t * 6.0 + k * TAU / 3.0
				draw_rect(Rect2(o + Vector2(round(cos(a) * 6), round(y - 4 + sin(a) * 2)), Vector2(1, 1)), Color("ffcc6a"))
		if is_boss:
			draw_texture(Atlas.icon("crown"), o + Vector2(-8, y - 17))

	func die(killed: bool) -> void:
		set_process(false)
		var tw := create_tween()
		if killed:
			spr.modulate = Color(4, 4, 4)
			tw.tween_interval(0.06)
			tw.tween_callback(func(): spr.modulate = Color(1, 0.3, 0.3))
			tw.tween_property(self, "modulate:a", 0.0, 0.18)
		else:
			tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(queue_free)


class HeroActor extends Node2D:
	var did := -1
	var slot := 0
	var spr: AnimatedSprite2D
	var hp_ratio := 1.0
	var dead := false
	var _atk := 0.0
	var _flash := 0.0
	var _shout := 0.0

	func setup(d: Dictionary, s: int) -> void:
		did = int(d.id)
		slot = s
		position = CombatView.hero_view(s)
		spr = AnimatedSprite2D.new()
		spr.sprite_frames = Atlas.dweller_frames(d.variant)
		spr.centered = false
		spr.offset = Vector2(-Atlas.DW_W / 2, -Atlas.DW_H)
		spr.play("idle")
		spr.flip_h = false
		add_child(spr)
		z_index = 8

	func set_dead(v: bool) -> void:
		dead = v
		spr.play("sit")
		spr.modulate = Color(0.45, 0.45, 0.5) if v else Color.WHITE
		if v:
			spr.pause()
		else:
			spr.play("idle")

	func attack(melee: bool) -> void:
		if dead:
			return
		_atk = 0.25
		if spr.animation != "work":
			spr.play("work")
		if melee:
			var tw := create_tween()
			tw.tween_property(spr, "position:x", 4.0, 0.06)
			tw.tween_property(spr, "position:x", 0.0, 0.12)

	func flash() -> void:
		_flash = 0.08

	func shout() -> void:
		_shout = 0.8

	func _process(delta: float) -> void:
		spr.position.x = round(spr.position.x)
		if dead:
			queue_redraw()
			return
		_atk -= delta
		_shout -= delta
		if _atk <= 0.0 and spr.animation != "idle":
			spr.play("idle")
		_flash -= delta
		spr.modulate = Color(3, 1.2, 1.2) if _flash > 0.0 else Color.WHITE
		queue_redraw()

	func _draw() -> void:
		var w := 12.0
		draw_rect(Rect2(-w / 2 - 1, -21, w + 2, 4), Color("0b0a10"))
		draw_rect(Rect2(-w / 2, -20, floorf(w * clampf(hp_ratio, 0, 1)), 2), Color("98c050") if hp_ratio > 0.35 else Color("f0644a"))
		if _shout > 0.0 and int(_shout * 8.0) % 2 == 0:
			draw_texture(Atlas.icon(["rifle", "fist", "heal"][slot]), Vector2(-8, -40))
		if dead:
			draw_string(UIKit.font_pixel, Vector2(-7, -24), "KO", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("f0644a"))
