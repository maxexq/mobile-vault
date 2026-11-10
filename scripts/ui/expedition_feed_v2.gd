class_name ExpeditionFeedV2
extends ExpeditionFeed
## MV-758 (switch "exp_scene_v2"): the new expedition scene. Same story engine as ExpeditionFeed (pure function of the
## elapsed time + the expedition seed, so reopening / offline shows the same thing, same beats, same field log), drawn
## with the approved art instead of the old 256x100 tiles and 14x20 dwellers:
## - the 7 approved interior strips (MV-678 / MV-682, 1536x200, loop horizontally) + their ambient loop (lamp flicker,
##   dust, sparks, drips: overlay atlas from tools/exp_scene_import.py) + the whole-scene ash / snow drawn in code
## - the team as ref v3 crew at full pixel size (crew pixel = strip pixel, rule MV-679 strip x2 / crew x2)
## - each beat the squad moves to the next group of hotspots (format 2: stand + action) and works them with the
##   approved expedition clips (MV-686 / MV-688 / MV-692): torchwalk (beam from the lens) in dark sites, gunwalk in
##   lit ones, search / wall (high shelves, back to camera) / work / construct at the hotspot, carrywalk with crates,
##   shoot at the creature (v2 monster art), carrywalk home with the haul.

const DIR := "res://assets/exp/v2/"
const H := 176.0                 # shown height: strip rows 0..175 (floor lip 160, void below)
const FEET := 153.0              # hotspot stand line (feet)
const BEAT2 := 16.0
const MOVE2 := 7.0               # walking part of a beat (arrive earlier = start working earlier)
const SPEED := 26.0              # strip px / s (walk clips are drawn for ~16 px/s, played faster to match)
const SPREAD := 28.0             # members sharing a hotspot stand this far apart
const CLUSTER := 110.0           # hotspots closer than this (stand x) form one stop of the squad
const HIGH := 130                # hotspot rect bottom above this row = wall shelf / cabinet -> "wall" clip (back view)
const CONSTRUCT := ["force_door", "mine_ore", "salvage"]
const WORK := ["hack_terminal", "take_fuel", "collect_sample"]
const BEAM_LEN := 104.0
const BEAM_HALF := 30.0

static var _scenes: Dictionary = {}

var _scene: Dictionary = {}
var _strip: Texture2D
var _amb_tex: Texture2D
var _sw := 1536.0
var _stops: Array = []           # [[hotspot, ...], ...] sorted by x
var _crew: Array = []            # AnimatedSprite2D per member
var _cid: Array = []             # v3 crew id per member
var _px: Array = []              # current x per member (strip px, unwrapped)
var _parts: Array = []           # [[x, y, k, i], ...] per particles effect
var _beams: Node2D
var _mob: AnimatedSprite2D
var _mob_beat := -99
var _mob_info: Dictionary = {}
var _mat: ShaderMaterial
var _tcache: Dictionary = {}     # beat -> member targets


static func scenes() -> Dictionary:
	if _scenes.is_empty():
		var f := FileAccess.open(DIR + "scenes.json", FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_scenes = d.get("scenes", {})
	return _scenes


## the switch is on and the imported art is there
static func ok() -> bool:
	return Features.on("exp_scene_v2") and not scenes().is_empty() and V3Art.ok()


## old expedition kind (store / hospital / ...) of a site
static func kind_of(site_id: String) -> String:
	return KIND.get(site_id, "ruins")


static func scene(kind: String) -> Dictionary:
	return scenes().get(kind, scenes().get("ruins", {}))


## the hotspot groups the squad works through, left to right (only hotspots with a stand point; hazards have none)
static func stops_of(sc: Dictionary) -> Array:
	var hs: Array = []
	for h in sc.get("hotspots", []):
		if (h as Dictionary).has("stand") and str(h.get("kind", "")) != "hazard":
			hs.append(h)
	hs.sort_custom(func(a, b): return float(a.stand[0]) < float(b.stand[0]))
	var out: Array = []
	for h in hs:
		if out.is_empty() or float(h.stand[0]) - float((out[-1] as Array)[0].stand[0]) > CLUSTER:
			out.append([h])
		else:
			(out[-1] as Array).append(h)
	return out


## which approved clip a crew member plays at this hotspot
static func clip_for(h: Dictionary) -> String:
	var act := str(h.get("action", "search"))
	if act in CONSTRUCT:
		return "construct"
	if act in WORK:
		return "work"
	var r: Array = h.get("rect", [0, 0, 0, 0])
	if int(r[1]) + int(r[3]) < HIGH:
		return "wall"
	return "search"


## a still crop of the scene for the report window (320 wide)
static func report_tex(site_id: String) -> Texture2D:
	var sc := scene(kind_of(site_id))
	var tex: Texture2D = load(DIR + str(sc.get("file", "")))
	if tex == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, 0, 320, H)
	return at


func _ready() -> void:
	_beams = Node2D.new()
	super._ready()
	custom_minimum_size = Vector2(0, H)
	_world.draw.connect(_draw_shadows)
	_beams.draw.connect(_draw_beams)
	_beams.material = _add_mat
	add_child(_beams)
	move_child(_beams, _fx.get_index())
	_mob = AnimatedSprite2D.new()
	_mob.centered = false
	_mob.visible = false
	_front.add_child(_mob)
	_mat = ShaderMaterial.new()
	_mat.shader = CrewV3Actor.BLEND
	_mat.set_shader_parameter("grade", 0.0)
	_mat.set_shader_parameter("lift", CrewV3Actor.lift_k())
	_mat.set_shader_parameter("soft_outline", CrewV3Actor.outline_k())
	for s in _crew:
		(s as AnimatedSprite2D).material = _mat


func _beat() -> float:
	return BEAT2


func _move() -> float:
	return MOVE2


func setup() -> void:
	if not Expedition.active():
		return
	var e := Expedition.state()
	site = str(e.site)
	_kind = kind_of(site)
	_dark_site = _kind in DARK_KINDS
	_scene = scene(_kind)
	_strip = load(DIR + str(_scene.get("file", "")))
	var amb: Dictionary = _scene.get("amb", {})
	_amb_tex = load(DIR + str(amb.get("file", ""))) if amb.has("file") else null
	_sw = float((_scene.get("size", [1536, 200]) as Array)[0])
	_stops = stops_of(_scene)
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
	# only monsters with v2 art (drawn at crew v3 density) can walk into this scene
	var biome: String = str(Expedition.SITES[site].biome) if Expedition.SITES.has(site) else Combat.biome_id()
	_mobs = []
	for m in Combat.BIOME_MOBS_V2.get(biome, Combat.BIOME_MOBS_V2.industrial):
		if EnemiesV2.meta().has(m) and not m in _mobs:
			_mobs.append(m)
	_plans = {}
	_tcache = {}
	_mob_beat = -99
	_hide_zombie()
	if _mob:
		_mob.visible = false
	for a in _crew:
		a.queue_free()
	_crew = []
	_actors = []
	_crates = []
	_cid = []
	_px = []
	_status = []
	for i in _team.size():
		var cid := V3Art.crew_for(_team[i])
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = V3Art.crew_frames(cid)
		spr.centered = false
		spr.offset = V3Art.FEET
		spr.material = _mat
		_world.add_child(spr)
		_crew.append(spr)
		_cid.append(cid)
		_px.append(0.0)
		_status.append("")
	_dark.visible = false
	_parts = []
	var rng := RandomNumberGenerator.new()
	for pe in amb.get("particles", []):
		rng.seed = int(pe.get("seed", 1))
		var ar: Array = pe.area
		var pts := []
		for i in int(pe.get("n", 40)):
			pts.append([rng.randf_range(float(ar[0]), float(ar[2])), rng.randf_range(float(ar[1]), float(ar[3])), 1 + rng.randi() % 2, i])
		_parts.append({"e": pe, "pts": pts})


# ------------------------------------------------------------------ timeline
## stop index of a beat (the squad keeps going deeper; the strip loops, so stops repeat one strip further on)
func _stop(beat: int) -> Array:
	if _stops.is_empty():
		return [{"stand": [80 + beat * 120, FEET], "action": "search", "rect": [0, 140, 10, 10]}]
	return _stops[posmod(beat, _stops.size())]


func _lap(beat: int) -> float:
	return 0.0 if _stops.is_empty() else floorf(float(beat) / _stops.size()) * _sw


## member i's hotspot + stand x in beat b (members never stand closer than SPREAD: two 60 px people on one spot
## read as one blob)
func target(beat: int, i: int) -> Dictionary:
	var key := maxi(0, beat)
	if not _tcache.has(key):
		var st := _stop(key)
		var out: Array = []
		for m in maxi(1, _team.size()):
			var h: Dictionary = st[m % st.size()]
			out.append({"h": h, "x": float(h.stand[0]) + _lap(key)})
		var order := range(out.size())
		order.sort_custom(func(a, b): return float(out[a].x) < float(out[b].x) or (float(out[a].x) == float(out[b].x) and a < b))
		for k in range(1, order.size()):
			var prev: Dictionary = out[order[k - 1]]
			var cur: Dictionary = out[order[k]]
			if float(cur.x) - float(prev.x) < SPREAD:
				cur.x = float(prev.x) + SPREAD
		_tcache[key] = out
	var arr: Array = _tcache[key]
	return arr[clampi(i, 0, arr.size() - 1)]


func _anchor(beat: int) -> float:
	return float(target(beat, 0).x)


func plan(beat: int) -> Dictionary:
	if _plans.has(beat):
		return _plans[beat]
	var p := super.plan(beat)
	if p.fight:
		# the creature only shows up once the squad got to the stop
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([_seed, beat, site, "v2"])
		p.spawn = _arrive_all(beat) + rng.randf_range(0.3, 1.2)
		p.die = minf(p.spawn + rng.randf_range(3.6, 5.0), BEAT2 - 1.6)
	return p


func _arrive(beat: int, i: int) -> float:
	if beat <= 0:
		return 0.0
	return minf(MOVE2, absf(float(target(beat, i).x) - float(target(beat - 1, i).x)) / SPEED)


func _arrive_all(beat: int) -> float:
	var t := 0.0
	for i in _team.size():
		t = maxf(t, _arrive(beat, i))
	return t


func _walk_clip(i: int) -> String:
	return "torchwalk" if _dark_site and i % 2 == 0 else "gunwalk"


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	if not is_visible_in_tree() or not Expedition.active() or _team.is_empty():
		return
	_t += delta
	var el := elapsed()
	var wi := _walk_in()
	var wo := _walk_out_at()
	var site_th: String = Expedition.site_def(site).th
	if el < wi:
		var k := el / wi
		for i in _crew.size():
			var x1 := float(target(0, i).x)
			_pose2(i, lerpf(x1 - 150.0 - i * 26.0, x1, k), _walk_clip(i), false, Loc.t("เดินเข้าไปใน ") + site_th)
		_mob.visible = false
	elif el >= wo:
		var last := int((wo - wi) / BEAT2)
		var k := clampf((el - wo) / maxf(0.1, _dur - wo), 0.0, 1.0)
		for i in _crew.size():
			var x0 := float(target(last, i).x)
			_pose2(i, lerpf(x0, x0 - 190.0 - i * 26.0, k), "carrywalk", true, Loc.t("แบกของกลับรถ"))
		_mob.visible = false
	else:
		var beat := int((el - wi) / BEAT2)
		var lt := (el - wi) - beat * BEAT2
		var p := plan(beat)
		for i in _crew.size():
			var x1 := float(target(beat, i).x)
			var ta := _arrive(beat, i)
			if lt < ta:
				var x0 := float(target(beat - 1, i).x)
				_pose2(i, lerpf(x0, x1, lt / ta), _walk_clip(i), x1 < x0, Loc.t("บุกลึกเข้าไป"))
			else:
				_act2(i, p, beat, x1, lt)
		_update_mob(beat, p, lt)
	var sum := 0.0
	for x in _px:
		sum += float(x)
	cam_x = roundf(sum / maxf(1.0, _px.size()) - size.x * 0.42)
	_world.position.x = -cam_x
	_front.position.x = -cam_x
	_world.queue_redraw()
	_beams.queue_redraw()
	_fx.queue_redraw()
	queue_redraw()


func _pose2(i: int, x: float, clip: String, face_left: bool, status: String, frozen := false) -> void:
	var spr: AnimatedSprite2D = _crew[i]
	_px[i] = x
	spr.position = Vector2(roundf(x), FEET)
	spr.flip_h = face_left
	var c := clip if spr.sprite_frames.has_animation(clip) else "idle"
	if spr.animation != c:
		spr.play(c)
	if frozen:
		spr.pause()
		spr.frame = 0
	elif not spr.is_playing():
		spr.play(c)
	spr.speed_scale = SPEED / 16.0 if c.ends_with("walk") and not frozen else 1.0
	_status[i] = status


func _act2(i: int, p: Dictionary, beat: int, x: float, lt: float) -> void:
	var a: String = p.acts[i]
	var h: Dictionary = target(beat, i).h
	match a:
		"search":
			_pose2(i, x, clip_for(h) if clip_for(h) in ["search", "wall"] else "search", false, str(p["txt_%d" % i]))
		"special":
			var c := clip_for(h)
			_pose2(i, x, c if c in ["work", "construct"] else "work", false, Loc.t(SPECIAL.get(site, SPECIAL[""])))
		"guard":
			# stands watch: torch on in the dark (beam sweeps slowly), pistol out in lit sites
			_pose2(i, x, "torchwalk" if _dark_site else "gunwalk", i % 2 == 1, Loc.t("คุ้มกันทีม ส่องไฟระวังหลัง"), true)
		"carry":
			# hauls crates back to the pile a little behind the stop and returns, over and over
			var period := 50.0 / 16.0 * 2.0
			var ph := fmod(lt, period) / period
			var back := ph < 0.5
			var d := (ph * 2.0 if back else (1.0 - ph) * 2.0) * 50.0
			_pose2(i, x - d, "carrywalk", back, Loc.t("แบกลังของไปกองรวม"))
		"rest":
			_pose2(i, x, "idle", false, Loc.t("นั่งพักหายใจ"))
		"fight":
			var mob := _mob_def(str(p.mob))
			var fx := _fighter_x(p, lt, x)
			if lt < float(p.spawn):
				_pose2(i, fx, "gunwalk", false, Loc.t("ได้ยินเสียงอะไรบางอย่าง..."), true)
			elif lt < float(p.die):
				if bool(p.melee):
					var zx := _zombie_x(p, lt, x)
					if zx - fx > 34.0:
						_pose2(i, fx, "gunwalk", false, Loc.t("พุ่งเข้าตะลุมบอน ") + mob.th)
					else:
						_pose2(i, fx, "construct", false, Loc.t("ตะลุมบอน ") + mob.th)
				else:
					_pose2(i, fx, "shoot", false, Loc.t("ยิงสู้ ") + mob.th)
			else:
				_pose2(i, fx, "idle", false, Loc.t("เคลียร์พื้นที่แล้ว"))


## a brawler closes in on the creature (and stays there once it drops)
func _fighter_x(p: Dictionary, lt: float, bx: float) -> float:
	if not bool(p.melee) or lt < float(p.spawn):
		return bx
	var t := minf(lt, float(p.die))
	var zx := _zombie_x(p, t, bx)
	return clampf(minf(zx - 30.0, bx + (t - float(p.spawn)) * SPEED), bx, bx + 70.0)


func _zombie_x(p: Dictionary, lt: float, fighter_x: float) -> float:
	var sum := 0.0
	for x in _px:
		sum += float(x)
	# enters from the right edge of the view the squad is looking at
	var start_x := sum / maxf(1.0, _px.size()) + size.x * 0.58 + 40.0
	var stop := fighter_x + (32.0 if bool(p.melee) else 120.0)
	return maxf(stop, start_x - (lt - float(p.spawn)) * 30.0)


func _hit_now(p: Dictionary, lt: float, fighter_x: float) -> bool:
	if lt < float(p.spawn) + 0.6 or lt > float(p.die):
		return false
	var zx := _zombie_x(p, lt, fighter_x)
	if bool(p.melee) and zx - _fighter_x(p, lt, fighter_x) > 36.0:
		return false
	var period := 0.5 if bool(p.melee) else 0.7
	return fmod(lt - float(p.spawn), period) < 0.1


func _update_mob(beat: int, p: Dictionary, lt: float) -> void:
	if not p.fight or lt < float(p.spawn) or lt >= float(p.die) + 0.05:
		_mob.visible = false
		return
	var fi := int(p.fighter)
	var bx := float(target(beat, fi).x)
	if _mob_beat != beat:
		_mob_beat = beat
		var id := str(p.mob)
		_mob_info = EnemiesV2.info(id)
		_mob.sprite_frames = EnemiesV2.frames(id)
		_mob.offset = -Vector2(float(_mob_info.get("ax", 0)), float(_mob_info.get("ay", 0)))
		if bool(_mob_info.get("air", false)):
			_mob.offset.y -= 30.0
		_mob.play("walk")
	var zx := _zombie_x(p, lt, bx)
	var stop := bx + (32.0 if bool(p.melee) else 120.0)
	var clip := "attack" if bool(p.melee) and zx <= stop + 0.5 else "walk"
	if _mob.animation != clip:
		_mob.play(clip)
	if clip == "attack" and not _mob.is_playing():
		_mob.play(clip)
	_mob.visible = true
	_mob.position = Vector2(roundf(zx), FEET)
	_mob.self_modulate = Color(3, 3, 3) if _hit_now(p, lt, bx) else Color.WHITE


# ------------------------------------------------------------------ drawing
func amb_frame() -> int:
	var amb: Dictionary = _scene.get("amb", {})
	return int(_t * float(amb.get("fps", 12.0))) % maxi(1, int(amb.get("n", 1)))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a0a0c"))
	if _strip == null:
		return
	var amb: Dictionary = _scene.get("amb", {})
	var f := amb_frame()
	var x := -fposmod(cam_x, _sw)
	while x < size.x:
		draw_texture(_strip, Vector2(x, 0))
		if _amb_tex != null:
			for r in amb.get("regions", []):
				var rc: Array = r.rect
				var w := float(rc[2])
				var h := float(rc[3])
				var dx := x + float(rc[0])
				if dx + w < 0.0 or dx > size.x:
					continue
				var cols := int(r.cols)
				var src := Rect2(float(r.at[0]) + (f % cols) * w, float(r.at[1]) + (f / cols) * h, w, h)
				draw_texture_rect_region(_amb_tex, Rect2(dx, float(rc[1]), w, h), src)
		for pe in _parts:
			_draw_particles(pe, x, f, int(amb.get("n", 48)))
		x += _sw


## falling ash / snow over the whole scene (MV-682 amb.py "particles": whole laps per loop -> seamless)
func _draw_particles(pe: Dictionary, ox: float, f: int, n: int) -> void:
	var e: Dictionary = pe.e
	var ar: Array = e.area
	var y0 := float(ar[1])
	var span := float(ar[3]) - y0
	var vx := float((e.get("v", [6, 18]) as Array)[0])
	var cc: Array = e.get("col", [200, 190, 185])
	var col := Color8(int(cc[0]), int(cc[1]), int(cc[2]), int(255.0 * float(e.get("a", 0.6))))
	for q in pe.pts:
		var px := ox + float(q[0]) + vx * sin(TAU * (float(f) / n + int(q[3]) * 0.37))
		if px < -2.0 or px > size.x + 2.0:
			continue
		var py := y0 + fposmod(float(q[1]) - y0 + float(q[2]) * f * span / n, span)
		draw_rect(Rect2(floorf(px), floorf(py), 1, 1), col)


## crisp pixel contact shadows under the crew (rule crew-room-blend), drawn under the sprites
func _draw_shadows() -> void:
	for spr in _crew:
		var p: Vector2 = (spr as AnimatedSprite2D).position
		for row in CrewV3Actor.SHADOW_ROWS:
			var w := int(row[1])
			_world.draw_rect(Rect2(p.x - w / 2, p.y + int(row[0]), w, 1), Color(0, 0, 0, 0.30))
		for row in CrewV3Actor.SHADOW_CORE:
			var w := int(row[1])
			_world.draw_rect(Rect2(p.x - w / 2, p.y + int(row[0]), w, 1), Color(0, 0, 0, 0.18))


## the lens point of a torchwalk frame in strip px (the beam starts at the flashlight mouth, rule MV-686)
func lens_point(i: int) -> Vector2:
	var spr: AnimatedSprite2D = _crew[i]
	var lens: Array = V3Art.clip_info(_cid[i], "torchwalk").get("lens", [])
	var lp := Vector2(44, 22)
	if not lens.is_empty():
		var l: Array = lens[spr.frame % lens.size()]
		lp = Vector2(float(l[0]), float(l[1]))
	var fx := lp.x if not spr.flip_h else 63.0 - lp.x
	return spr.position + V3Art.FEET + Vector2(fx, lp.y)


func _draw_beams() -> void:
	for i in _crew.size():
		var spr: AnimatedSprite2D = _crew[i]
		if spr.animation != "torchwalk":
			continue
		var o := lens_point(i) - Vector2(cam_x, 0)
		var dir := -1.0 if spr.flip_h else 1.0
		var sweep := 0.0 if spr.is_playing() else sin(_t * 0.9 + i) * 10.0
		var flick := 0.30 + 0.05 * sin(_t * 9.0 + i)
		var far := o + Vector2(dir * BEAM_LEN, 10.0 + sweep)
		var pts := PackedVector2Array([o, far + Vector2(0, -BEAM_HALF), far + Vector2(0, BEAM_HALF)])
		var c0 := Color(1.0, 0.9, 0.65, flick)
		var c1 := Color(1.0, 0.85, 0.55, 0.0)
		_beams.draw_polygon(pts, PackedColorArray([c0, c1, c1]))
		_beams.draw_rect(Rect2(o.round() - Vector2(1, 1), Vector2(2, 2)), Color(1, 0.95, 0.75, 0.8))


func _draw_fx() -> void:
	if not Expedition.active() or _team.is_empty():
		return
	var el := elapsed()
	var wi := _walk_in()
	var off := Vector2(-cam_x, 0)
	if el >= wi and el < _walk_out_at():
		var beat := int((el - wi) / BEAT2)
		var lt := (el - wi) - beat * BEAT2
		var p := plan(beat)
		# loot pops: an item icon floats up when a search finishes
		if lt >= BEAT2 - 1.5:
			var k := (lt - (BEAT2 - 1.5)) / 1.5
			for i in _team.size():
				var a: String = p.acts[i]
				if a == "search" or a == "special":
					var spr: AnimatedSprite2D = _crew[i]
					var tex: Texture2D = Atlas.icon(Data.item_icon(str(p["loot_%d" % i])))
					var pos := spr.position + off + Vector2(-8, -64 - 16 - roundf(k * 12.0))
					_fx.draw_texture(tex, pos.round(), Color(1, 1, 1, 1.0 - k * k))
		if p.fight:
			var fi := int(p.fighter)
			var bx := float(target(beat, fi).x)
			var fspr: AnimatedSprite2D = _crew[fi]
			var zx := _zombie_x(p, lt, bx) - cam_x
			if not bool(p.melee) and _hit_now(p, lt, bx):
				var gun := fspr.position + off + Vector2(26, -36)
				_fx.draw_line(gun, Vector2(zx - 6, FEET - 30), Color(1, 0.85, 0.5, 0.8), 1.0)
			if bool(p.hurt) and lt > float(p.die) - 1.0 and lt < float(p.die) - 0.2:
				_fx.draw_string(UIKit.font_pixel, fspr.position + off + Vector2(-10, -70), "OUCH", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FP, UIKit.C_RED)
			if lt >= float(p.die):
				var dt := lt - float(p.die)
				var zdx := roundf(_zombie_x(p, float(p.die), bx) - cam_x)
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([_seed, beat, "gore"])
				for n in 22:
					var vx := rng.randf_range(-30.0, 40.0)
					var vy := rng.randf_range(-70.0, -20.0)
					var t := minf(dt, 1.2)
					var gy := minf(FEET, FEET - 24.0 + vy * t + 120.0 * t * t)
					_fx.draw_rect(Rect2(roundf(zdx + vx * t), roundf(gy), 1 + n % 2, 1 + n % 2), Color("7c2218") if n % 3 else Color("a8372a"))
				for n in 10:
					_fx.draw_rect(Rect2(zdx - 10 + n * 2, FEET - 1 + (n % 2), 2, 1), Color("521612"))
	if _mob.visible:
		var top := _mob.position + off + Vector2(0, _mob.offset.y + float(_mob_info.get("ay", 0)) - float(_mob_info.get("h", 60)) - 6)
		var blink := int(_t * 4.0) % 2 == 0
		_fx.draw_rect(Rect2(top.x - 1, top.y - 6, 2, 4), UIKit.C_RED if blink else Color("7c2218"))
		_fx.draw_rect(Rect2(top.x - 1, top.y - 1, 2, 2), UIKit.C_RED if blink else Color("7c2218"))
	# member markers (match the coloured dots in the panel list)
	for i in _crew.size():
		var spr: AnimatedSprite2D = _crew[i]
		var top := spr.position + off + Vector2(0, -66)
		var col: Color = MARK[i % MARK.size()]
		var bob := 1.0 if int(_t * 2.0 + i) % 2 == 0 else 0.0
		_fx.draw_rect(Rect2(top.x - 2, top.y - bob, 5, 1), col)
		_fx.draw_rect(Rect2(top.x - 1, top.y + 1 - bob, 3, 1), col)
		_fx.draw_rect(Rect2(top.x, top.y + 2 - bob, 1, 1), col)
	if int(_t * 1.5) % 2 == 0:
		_fx.draw_rect(Rect2(5, 5, 4, 4), UIKit.C_RED)
	_fx.draw_string(UIKit.font_pixel, Vector2(12, 11), "LIVE  CAM-%02d" % (absi(_seed) % 89 + 10), HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FP, UIKit.C_WHITE)
	var tl := Expedition.time_left()
	_fx.draw_string(UIKit.font_pixel, Vector2(size.x - 40, 11), "%d:%02d" % [int(tl) / 60, int(tl) % 60], HORIZONTAL_ALIGNMENT_RIGHT, 36, UIKit.FP, UIKit.C_GOLD)
	for y in range(0, int(size.y), 3):
		_fx.draw_rect(Rect2(0, y, size.x, 1), Color(0, 0, 0, 0.10))
	_fx.draw_rect(Rect2(Vector2.ZERO, size), UIKit.C_LINE_DIM, false, 1.0)


## what member i is playing right now (autotest / GOD)
func member_clip(i: int) -> String:
	return str((_crew[i] as AnimatedSprite2D).animation) if i < _crew.size() else ""
