class_name ExpeditionFeed
extends Control
## Live "helmet-cam" feed of a scavenging squad inside the site, shown in the expedition panel while the
## team is out. Everything is a pure function of the real elapsed time + a seed taken from the expedition's
## start time, so closing / reopening the panel, or coming back from offline, shows the same story.
##
## Timeline: walk in (Expedition.WALK_SEC) -> beats of BEAT seconds (push deeper, then everyone does
## something: search shelves, the site's special job, guard, carry a crate, catch a breath; some beats a
## creature shambles in and the best fighter shoots or brawls it) -> walk back out carrying the haul.
## Dark sites get a darkness layer and the crew's head-torches (additive pixel cones, like room blackouts).

const FL := 86.0                # feet line inside the 100 px backdrop
const BEAT := 10.0
const MOVE := 2.5               # first part of a beat: the squad pushes deeper
const STEP := 46.0              # px deeper per beat
const GAP := 22.0               # spacing between members
const KIND := {"market": "store", "mall": "store", "hospital": "hospital", "stilt_town": "ruins", "ranger": "ruins",
	"depot": "bunker", "gas_stop": "plant", "chem_plant": "plant", "sat_base": "plant", "lab": "lab", "polar": "lab",
	"helios": "lab", "mine": "mine"}
const DARK_KINDS := ["store", "hospital", "bunker", "lab", "mine"]
const SPECIAL := {"market": "ลากรถเข็นกวาดของบนชั้น", "mall": "รื้อโกดังหลังร้าน", "hospital": "งัดตู้ยา",
	"stilt_town": "ตะโกนหาผู้รอดชีวิต", "ranger": "ซ่อมวิทยุสื่อสาร", "depot": "ตัดกุญแจคลังอาวุธ",
	"gas_stop": "สูบน้ำมันจากถังใต้ดิน", "chem_plant": "ปิดวาล์วที่รั่ว", "sat_base": "ถอดแผงวงจรจากจาน",
	"lab": "กู้ข้อมูลจากเซิร์ฟเวอร์", "polar": "ขุดหิมะออกจากโรงจอด", "helios": "แฮ็กประตูนิรภัย",
	"mine": "ขนแร่ใส่รถราง", "": "รื้อซากรถข้างทาง"}
const SEARCH := ["ค้นชั้นวาง", "รื้อกองเศษซาก", "งัดลิ้นชัก", "ส่องไฟหาของในมุมมืด", "เปิดลังที่ถูกทิ้ง"]
const MARK := [Color("e0b048"), Color("86a8bc"), Color("98c050")]

var site := ""
var _kind := "ruins"
var _dark_site := false
var _bg: Texture2D
var _start := 0.0
var _seed := 0                  # stable per expedition (drives the scripted beats)
var _dur := 1.0
var _team: Array = []           # dweller dictionaries
var _loot_keys: Array = []
var _mobs: Array = []
var _chance := 0.8
var _plans := {}                # beat -> plan
var cam_x := 0.0
var _t := 0.0

var _world: Node2D
var _actors: Array = []         # AnimatedSprite2D per member
var _crates: Array = []         # Sprite2D per member
var _zombie: AnimatedSprite2D
var _zombie_beat := -99
var _dark: ColorRect
var _front: Node2D            # threats are drawn above the darkness so they read in a dim feed
var _cones: Node2D
var _fx: Node2D
var _status: Array = []         # Thai text per member, what they are doing right now
static var _add_mat: CanvasItemMaterial


func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(0, 100)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_world = Node2D.new()
	add_child(_world)
	_dark = ColorRect.new()
	_dark.color = Color(0.015, 0.012, 0.02, 0.32)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dark)
	_front = Node2D.new()
	add_child(_front)
	_cones = Node2D.new()
	add_child(_cones)
	_fx = Node2D.new()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_zombie = AnimatedSprite2D.new()
	_zombie.centered = false
	_zombie.visible = false
	_front.add_child(_zombie)
	setup()


## (re)reads the active expedition; cheap, call when the panel opens
func setup() -> void:
	if not Expedition.active():
		return
	var e := Expedition.state()
	site = str(e.site)
	_kind = KIND.get(site, "ruins")
	_dark_site = _kind in DARK_KINDS
	_bg = load("res://assets/exp/exp_%s.png" % _kind)
	_start = float(e.start)
	_seed = int(e.get("seed", int(_start)))
	_dur = maxf(1.0, float(e.dur))
	_team = Expedition.team()
	_chance = Expedition.success_chance(site, _team, e.get("sup", {}))
	var def := Expedition.site_def(site)
	_loot_keys = []
	var loot: Dictionary = def.loot
	for k in loot.get("res", {}):
		_loot_keys.append(k)
	for k in loot.get("items", {}):
		_loot_keys.append(k)
	if _loot_keys.is_empty():
		_loot_keys = ["scrap"]
	var biome: String = str(Expedition.SITES[site].biome) if Expedition.SITES.has(site) else Combat.biome_id()
	_mobs = (Combat.BIOME_MOBS.get(biome, Combat.BIOME_MOBS.industrial) as Array).duplicate()
	_mobs.append_array(Combat.MUTANT_POOL.get(biome, []))
	_plans = {}
	_zombie_beat = -99
	for a in _actors:
		a.queue_free()
	_actors = []
	_crates = []
	_status = []
	for i in _team.size():
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = Atlas.dweller_frames(_team[i].variant)
		spr.centered = false
		spr.offset = Vector2(-Atlas.DW_W / 2, -Atlas.DW_H)
		spr.play("walk")
		_world.add_child(spr)
		_world.move_child(spr, 0)
		var cr := Sprite2D.new()
		cr.texture = Atlas.tex("exp_crate")
		cr.centered = false
		cr.position = Vector2(-5, -Atlas.DW_H - 7)
		cr.visible = false
		spr.add_child(cr)
		_actors.append(spr)
		_crates.append(cr)
		_status.append("")
	for c in _cones.get_children():
		c.queue_free()
	if _dark_site:
		for i in _team.size():
			var s := Sprite2D.new()
			s.material = _add_mat
			s.centered = false
			_cones.add_child(s)
	_dark.visible = _dark_site


# ------------------------------------------------------------------ timeline
func elapsed() -> float:
	return clampf(Time.get_unix_time_from_system() - _start, 0.0, _dur)


func _walk_in() -> float:
	return minf(Expedition.WALK_SEC, _dur * 0.2)


func _walk_out_at() -> float:
	return _dur - minf(Expedition.WALK_SEC, _dur * 0.2)


func _anchor(beat: int) -> float:
	return 60.0 + beat * STEP


func plan(beat: int) -> Dictionary:
	if _plans.has(beat):
		return _plans[beat]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, beat, site])
	var p := {"acts": [], "jit": [], "fight": false}
	var danger := float(Expedition.site_def(site).danger)
	var fight_p := clampf(0.18 + 0.05 * danger + (1.0 - _chance) * 0.3, 0.15, 0.65)
	if beat > 0 and rng.randf() < fight_p and not _mobs.is_empty():
		var mob_id: String = _mobs[rng.randi() % _mobs.size()]
		var best := 0
		var best_v := -1.0
		for i in _team.size():
			var d: Dictionary = _team[i]
			var v := float(d.get("str", 1)) + float(d.get("agi", 1)) + rng.randf()
			if v > best_v:
				best_v = v
				best = i
		var fd: Dictionary = _team[best] if best < _team.size() else {}
		p.fight = true
		p.fighter = best
		p.mob = mob_id
		p.melee = float(fd.get("str", 1)) > float(fd.get("agi", 1)) + 1.0
		p.spawn = MOVE + rng.randf_range(0.2, 1.4)
		p.die = p.spawn + rng.randf_range(3.6, 5.4)
		p.hurt = rng.randf() < (1.0 - _chance) * 0.8
	for i in _team.size():
		var a := "search"
		if p.fight and int(p.get("fighter", -1)) == i:
			a = "fight"
		else:
			var r := rng.randf()
			if r < 0.38:
				a = "search"
			elif r < 0.55:
				a = "special"
			elif r < 0.72:
				a = "guard"
			elif r < 0.88:
				a = "carry"
			else:
				a = "rest" if not p.fight else "guard"
		p.acts.append(a)
		p.jit.append(rng.randf_range(-6.0, 6.0))
		p["txt_%d" % i] = Loc.t(SEARCH[rng.randi() % SEARCH.size()])
		p["loot_%d" % i] = _loot_keys[rng.randi() % _loot_keys.size()]
	_plans[beat] = p
	return p


func _mob_def(id: String) -> Dictionary:
	return Combat.MOBS.get(id, {"th": Loc.t("ซอมบี้"), "sprite": "en_walker"})


## activity log up to now: [{t, text, col}]
func log_lines(max_lines: int = 3) -> Array:
	var out := []
	var el := elapsed()
	out.append({"t": 0.0, "text": Loc.t("ทีมเข้าไปใน %s") % Expedition.site_def(site).th, "col": UIKit.C_DIM})
	var wi := _walk_in()
	var last_beat := int((minf(el, _walk_out_at()) - wi) / BEAT)
	for b in range(0, last_beat + 1):
		var p := plan(b)
		var t0 := wi + b * BEAT
		for i in _team.size():
			var a: String = p.acts[i]
			var nm: String = _team[i].name
			if a == "search" or a == "special":
				var te := t0 + BEAT - 1.5
				if te <= el and te < _walk_out_at():
					var what := Data.item_name(str(p["loot_%d" % i]))
					out.append({"t": te, "text": Loc.t("%s เจอ %s") % [nm, what], "col": UIKit.C_TEXT})
		if p.fight:
			var nm2: String = _team[int(p.fighter)].name
			var mob := _mob_def(str(p.mob))
			if t0 + float(p.spawn) <= el:
				out.append({"t": t0 + float(p.spawn), "text": Loc.t("%s โผล่มา!") % mob.th, "col": UIKit.C_ORANGE})
			if bool(p.hurt) and t0 + float(p.die) - 1.0 <= el:
				out.append({"t": t0 + float(p.die) - 1.0, "text": Loc.t("%s โดนข่วน!") % nm2, "col": UIKit.C_RED})
			if t0 + float(p.die) <= el:
				out.append({"t": t0 + float(p.die), "text": Loc.t("%s จัดการ%sได้") % [nm2, mob.th], "col": UIKit.C_GREEN})
	if el >= _walk_out_at():
		out.append({"t": _walk_out_at(), "text": Loc.t("ทีมแบกของออกมา กำลังกลับรถ"), "col": UIKit.C_GOLD})
	out.sort_custom(func(a, b): return float(a.t) < float(b.t))
	return out.slice(maxi(0, out.size() - max_lines))


func member_status(i: int) -> String:
	return _status[i] if i < _status.size() else ""


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	if not is_visible_in_tree() or not Expedition.active() or _team.is_empty():
		return
	_t += delta
	_dark.size = size
	var el := elapsed()
	var wi := _walk_in()
	var wo := _walk_out_at()
	var site_th: String = Expedition.site_def(site).th
	if el < wi:
		# walking in from the left edge
		var k := el / wi
		cam_x = _anchor(0) - _lead()
		for i in _actors.size():
			_pose(i, lerpf(cam_x - 20.0 - i * GAP, _anchor(0) - i * GAP, k), "walk", false, Loc.t("เดินเข้าไปใน ") + site_th)
		_hide_zombie()
	elif el >= wo:
		# hauling the loot back out
		var last := int((wo - wi) / BEAT)
		var k := clampf((el - wo) / maxf(0.1, _dur - wo), 0.0, 1.0)
		var ax := _anchor(last)
		cam_x = ax - _lead()
		for i in _actors.size():
			var x := lerpf(ax - i * GAP, cam_x - 30.0 - i * GAP, k)
			_pose(i, x, "walk", true, Loc.t("แบกของกลับรถ"))
			(_crates[i] as Sprite2D).visible = true
		_hide_zombie()
	else:
		var beat := int((el - wi) / BEAT)
		var lt := (el - wi) - beat * BEAT
		var p := plan(beat)
		var a0 := _anchor(maxi(0, beat - 1)) if beat > 0 else _anchor(0)
		var a1 := _anchor(beat)
		var moving := lt < MOVE and beat > 0
		var ax := lerpf(a0, a1, clampf(lt / MOVE, 0.0, 1.0)) if moving else a1
		cam_x = ax - _lead()
		for i in _actors.size():
			var bx: float = ax - i * GAP + float(p.jit[i])
			if moving:
				_pose(i, ax - i * GAP, "walk", false, Loc.t("บุกลึกเข้าไป"))
				continue
			_act(i, p, bx, lt)
		_update_zombie(beat, p, lt, ax)
	cam_x = roundf(cam_x)
	_world.position.x = -cam_x
	_front.position.x = -cam_x
	_update_cones()
	_fx.queue_redraw()
	queue_redraw()


## where the squad leader stands on screen: about a third in, leaving room for whatever comes from the dark
func _lead() -> float:
	return clampf(floorf(size.x * 0.36), 60.0, 160.0)


func _pose(i: int, x: float, anim: String, face_left: bool, status: String) -> void:
	var spr: AnimatedSprite2D = _actors[i]
	var nx := roundf(x)
	spr.position = Vector2(nx, FL)
	spr.flip_h = face_left
	if spr.animation != anim or not spr.is_playing():
		spr.play(anim)
	(_crates[i] as Sprite2D).visible = false
	_status[i] = status


func _act(i: int, p: Dictionary, bx: float, lt: float) -> void:
	var a: String = p.acts[i]
	match a:
		"search":
			_pose(i, bx, "work", i % 2 == 1, str(p["txt_%d" % i]))
		"special":
			_pose(i, bx, "work", false, Loc.t(SPECIAL.get(site, SPECIAL[""])))
		"guard":
			_pose(i, bx, "idle", false, Loc.t("คุ้มกันทีม ส่องไฟระวังหลัง"))
		"carry":
			_pose(i, bx, "idle", true, Loc.t("แบกลังของไปกองรวม"))
			(_crates[i] as Sprite2D).visible = true
		"rest":
			_pose(i, bx, "sit", false, Loc.t("นั่งพักหายใจ"))
		"fight":
			var mob := _mob_def(str(p.mob))
			var fx := _fighter_x(p, lt, bx)
			var zx := _zombie_x(p, lt, bx)
			if lt < float(p.spawn):
				_pose(i, fx, "idle", false, Loc.t("ได้ยินเสียงอะไรบางอย่าง..."))
			elif lt < float(p.die):
				if bool(p.melee):
					if zx - fx > 15.0:
						_pose(i, fx, "walk", false, Loc.t("พุ่งเข้าตะลุมบอน ") + mob.th)
					else:
						_pose(i, fx, "work", false, Loc.t("ตะลุมบอน ") + mob.th)
				else:
					var reload: bool = (_actors[i] as AnimatedSprite2D).sprite_frames.has_animation("clean") and fmod(lt, 2.4) > 2.0
					_pose(i, fx, "clean" if reload else "idle", false, (Loc.t("บรรจุกระสุน") if reload else Loc.t("ยิงสู้ ")) + ("" if reload else mob.th))
			else:
				_pose(i, fx, "idle", false, Loc.t("เคลียร์พื้นที่แล้ว"))


## a brawler closes the gap to meet the creature (and stays there once it drops)
func _fighter_x(p: Dictionary, lt: float, bx: float) -> float:
	if not bool(p.melee) or lt < float(p.spawn):
		return bx
	var t := minf(lt, float(p.die))
	var zx := _zombie_x(p, t, bx)
	return clampf(minf(zx - 13.0, bx + (t - float(p.spawn)) * 18.0), bx, bx + 30.0)


func _zombie_x(p: Dictionary, lt: float, fighter_x: float) -> float:
	var start_x := cam_x + size.x + 14.0
	var stop := fighter_x + (44.0 if bool(p.melee) else 14.0)
	return maxf(stop, start_x - (lt - float(p.spawn)) * 30.0)


func _update_zombie(beat: int, p: Dictionary, lt: float, ax: float) -> void:
	if not p.fight or lt < float(p.spawn) or lt >= float(p.die) + 0.05:
		_hide_zombie()
		return
	if _zombie_beat != beat:
		_zombie_beat = beat
		var mob := _mob_def(str(p.mob))
		var sprite: String = mob.sprite
		if sprite.begins_with("dw_"):
			_zombie.sprite_frames = Atlas.dweller_frames(sprite)
			_zombie.offset = Vector2(-Atlas.DW_W / 2, -Atlas.DW_H)
			_zombie.flip_h = true
			_zombie.play("walk")
		else:
			var sf := SpriteFrames.new()
			sf.set_animation_speed("default", 5.0)
			sf.add_frame("default", Atlas.tex(sprite + "_0"))
			sf.add_frame("default", Atlas.tex(sprite + "_1"))
			_zombie.sprite_frames = sf
			var tex: Texture2D = sf.get_frame_texture("default", 0)
			var air := str(mob.get("kind", "")) == "air"
			_zombie.offset = Vector2(-tex.get_width() / 2, -tex.get_height() - (14 if air else 0))
			_zombie.flip_h = false
			_zombie.play("default")
		_zombie.modulate = Color(mob.tint) if mob.has("tint") else Color.WHITE
	var fi := int(p.fighter)
	var bx: float = ax - fi * GAP + float(p.jit[fi])
	_zombie.visible = true
	_zombie.position = Vector2(roundf(_zombie_x(p, lt, bx)), FL)
	# hit flash
	var hit := _hit_now(p, lt, bx)
	_zombie.self_modulate = Color(3, 3, 3) if hit else Color.WHITE


func _hide_zombie() -> void:
	_zombie.visible = false


## true on the frames a shot / blow lands
func _hit_now(p: Dictionary, lt: float, fighter_x: float) -> bool:
	if lt < float(p.spawn) + 0.6 or lt > float(p.die):
		return false
	var zx := _zombie_x(p, lt, fighter_x)
	if bool(p.melee) and zx - _fighter_x(p, lt, fighter_x) > 16.0:
		return false
	if not bool(p.melee) and zx - fighter_x > 150.0:
		return false
	var period := 0.5 if bool(p.melee) else 0.55
	return fmod(lt - float(p.spawn), period) < 0.1


func _update_cones() -> void:
	if not _dark_site:
		return
	_cones.position.x = -cam_x
	for i in mini(_cones.get_child_count(), _actors.size()):
		var cone: Sprite2D = _cones.get_child(i)
		var a: AnimatedSprite2D = _actors[i]
		var ph := int(_t * 1.3 + i * 0.9) % 4
		cone.texture = Atlas.tex("fx_flashlight_%d" % [0, 1, 0, 2][ph])
		var left := a.flip_h
		cone.flip_h = left
		var head := a.position + Vector2(0, -15)
		if a.animation == "sit":
			head.y += 5
		cone.position = Vector2(roundf(head.x - (44 if left else 0) + (-2 if left else 2)), roundf(head.y - 12))
		cone.modulate = Color(1, 0.92, 0.7, 0.5 + 0.12 * sin(_t * 9.0 + i))


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a0a0c"))
	if _bg == null:
		return
	var bw := float(_bg.get_width())
	var x := -fposmod(cam_x, bw)
	while x < size.x:
		draw_texture(_bg, Vector2(x, 0))
		x += bw
	if size.y > 100.0:
		draw_rect(Rect2(0, 100, size.x, size.y - 100), Color("0c0a0a"))


func _draw_fx() -> void:
	if not Expedition.active() or _team.is_empty():
		return
	var el := elapsed()
	var wi := _walk_in()
	var off := Vector2(-cam_x, 0)
	if el >= wi and el < _walk_out_at():
		var beat := int((el - wi) / BEAT)
		var lt := (el - wi) - beat * BEAT
		var p := plan(beat)
		var ax := _anchor(beat)
		# loot pops: an item icon floats up when a search finishes
		if lt >= BEAT - 1.5:
			var k := (lt - (BEAT - 1.5)) / 1.5
			for i in _team.size():
				var a: String = p.acts[i]
				if a == "search" or a == "special":
					var spr: AnimatedSprite2D = _actors[i]
					var tex: Texture2D = Atlas.icon(Data.item_icon(str(p["loot_%d" % i])))
					var pos := spr.position + off + Vector2(-8, -Atlas.DW_H - 18 - roundf(k * 10.0))
					_fx.draw_texture(tex, pos.round(), Color(1, 1, 1, 1.0 - k * k))
		if p.fight:
			var fi := int(p.fighter)
			var bx: float = ax - fi * GAP + float(p.jit[fi])
			var fspr: AnimatedSprite2D = _actors[fi]
			var zx := _zombie_x(p, lt, bx) - cam_x
			# shots: muzzle flash + tracer
			if not bool(p.melee) and _hit_now(p, lt, bx):
				var gun := fspr.position + off + Vector2(6, -11)
				_fx.draw_rect(Rect2(gun, Vector2(3, 3)), Color("fff0b0"))
				_fx.draw_rect(Rect2(gun + Vector2(3, 1), Vector2(2, 1)), Color("f0c060"))
				_fx.draw_line(gun + Vector2(5, 1), Vector2(zx - 2, FL - 10), Color(1, 0.85, 0.5, 0.8), 1.0)
			# hurt pop
			if bool(p.hurt) and lt > float(p.die) - 1.0 and lt < float(p.die) - 0.2:
				_fx.draw_string(UIKit.font_pixel, fspr.position + off + Vector2(-8, -Atlas.DW_H - 4), "OUCH", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FP, UIKit.C_RED)
			# death: blood burst + splat on the floor
			if lt >= float(p.die):
				var dt := lt - float(p.die)
				var zdx := roundf(_zombie_x(p, float(p.die), bx) - cam_x)
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([_seed, beat, "gore"])
				for n in 14:
					var vx := rng.randf_range(-22.0, 30.0)
					var vy := rng.randf_range(-48.0, -14.0)
					var t := minf(dt, 1.2)
					var gx := zdx + vx * t
					var gy := FL - 8.0 + vy * t + 90.0 * t * t
					if gy > FL:
						gy = FL
					_fx.draw_rect(Rect2(roundf(gx), roundf(gy), 1 + n % 2, 1 + n % 2), Color("7c2218") if n % 3 else Color("a8372a"))
				for n in 7:
					_fx.draw_rect(Rect2(zdx - 7 + n * 2, FL - 1 + (n % 2), 2, 1), Color("521612"))
	# threat marker
	if _zombie.visible:
		var zt := _zombie.position + off + Vector2(0, _zombie.offset.y - 5)
		var blink := int(_t * 4.0) % 2 == 0
		_fx.draw_rect(Rect2(zt.x - 1, zt.y - 6, 2, 4), UIKit.C_RED if blink else Color("7c2218"))
		_fx.draw_rect(Rect2(zt.x - 1, zt.y - 1, 2, 2), UIKit.C_RED if blink else Color("7c2218"))
	# member markers (match the coloured dots in the panel list)
	for i in _actors.size():
		var spr: AnimatedSprite2D = _actors[i]
		var top := spr.position + off + Vector2(0, -Atlas.DW_H - 4)
		if (_crates[i] as Sprite2D).visible:
			top.y -= 8
		if spr.animation == "sit":
			top.y += 5
		var col: Color = MARK[i % MARK.size()]
		var bob := 1.0 if int(_t * 2.0 + i) % 2 == 0 else 0.0
		_fx.draw_rect(Rect2(top.x - 2, top.y - bob, 5, 1), col)
		_fx.draw_rect(Rect2(top.x - 1, top.y + 1 - bob, 3, 1), col)
		_fx.draw_rect(Rect2(top.x, top.y + 2 - bob, 1, 1), col)
	# REC tag + timer, helmet-cam style
	if int(_t * 1.5) % 2 == 0:
		_fx.draw_rect(Rect2(5, 5, 4, 4), UIKit.C_RED)
	_fx.draw_string(UIKit.font_pixel, Vector2(12, 11), "LIVE  CAM-%02d" % (absi(_seed) % 89 + 10), HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FP, UIKit.C_WHITE)
	var tl := Expedition.time_left()
	_fx.draw_string(UIKit.font_pixel, Vector2(size.x - 40, 11), "%d:%02d" % [int(tl) / 60, int(tl) % 60], HORIZONTAL_ALIGNMENT_RIGHT, 36, UIKit.FP, UIKit.C_GOLD)
	# scanlines / frame
	for y in range(0, int(size.y), 3):
		_fx.draw_rect(Rect2(0, y, size.x, 1), Color(0, 0, 0, 0.12))
	_fx.draw_rect(Rect2(Vector2.ZERO, size), UIKit.C_LINE_DIM, false, 1.0)
