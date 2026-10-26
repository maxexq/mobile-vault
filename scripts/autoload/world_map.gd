extends Node
## Seeded world map (MV-500 epic; this is phase 1, MV-129: generation + save + GOD, nothing visible yet).
## Replaces the fixed six-map itinerary with one spatial road map per world: six regions (the existing biomes, same
## Vault gates 1..6), each a small loop of stops (entry junction, its existing expedition landmarks, an unknown-signal
## report; industrial has the start instead), joined to the next region by one gated border road. Approved direction:
## tools/art/micro/previews/seeded-map-v1 (the browser preview is a prototype, not a contract).
##  * one world per run AND per lap (Parames 2026-10-26): reaching the exit of Signal Metropolis makes a new world for
##    lap + 1 (phase 2). A world never changes while you are on it: opening the map, selecting a stop, loading a save
##    or reading a report never regenerates it.
##  * the whole generated graph is saved in Game.s.world (seed + generator version + nodes + edges + regions), so a
##    later generator change can never move an existing player's roads; ids are stable strings.
##  * border roads carry the Vault level of the region they lead into and the warlord of the region they leave:
##    the checkpoint sits on that road (phase 2 drives it).
##  * km: inside a region a road's length follows its drawn length, scaled so crossing the region is about that
##    biome's old length (Data.BIOMES.length); border roads take the mean of both regions. Tune world.km_scale.
## Switch seeded_world_map (off = the old itinerary; off in config until the map screen ships). GOD → โลก → WORLD MAP.
## Autotest --only=world_map.

signal world_changed

const GEN_VERSION := 1
const CANVAS := Vector2i(336, 360)       # native map canvas (handoff); stop positions are in these pixels
const REGION_STEP := Vector2i(168, 120)
const REGION_ORIGIN := Vector2i(84, 60)
const NODE_OFF := Vector2i(31, 29)
const CROSS_PX := 120.0                  # drawn px of a typical crossing of one region (km scaling)
const SEED_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ"


func _ready() -> void:
	Game.game_started.connect(func(): ensure())


func on() -> bool:
	return Features.on("seeded_world_map")


# =================================================================== state
## the current world ({} = none yet, or the switch is off)
func world() -> Dictionary:
	if Game.s.is_empty() or not (Game.s.get("world") is Dictionary):
		return {}
	return Game.s.world


## make the world for this run if there is none yet (never replaces an existing one)
func ensure() -> Dictionary:
	if not on() or Game.s.is_empty():
		return {}
	if not world().is_empty():
		return world()
	return create(random_seed())


## a new world for this run / lap from a seed: the only place a world is (re)generated
func create(seed_text: String) -> Dictionary:
	var w := generate(seed_text, int(Game.s.get("lap", 0)))
	Game.s["world"] = w
	Trace.rec("travel", "world created", {"seed": w.seed, "gen": w.gen, "lap": w.lap})
	world_changed.emit()
	return w


func random_seed() -> String:
	var r := RandomNumberGenerator.new()
	r.randomize()
	var s := ""
	for i in 3:
		s += SEED_CHARS[r.randi() % SEED_CHARS.length()]
	return "%s-%03d" % [s, r.randi() % 1000]


static func fnv1a(text: String) -> int:
	var h := 2166136261
	for b in text.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	return h


# =================================================================== generation (pure: same seed + version = same world)
static func generate(seed_text: String, lap: int = 0) -> Dictionary:
	var sd := seed_text.strip_edges().left(32)
	if sd == "":
		sd = "ASH-271"
	var r := RandomNumberGenerator.new()
	r.seed = fnv1a("%s/v%d" % [sd, GEN_VERSION])
	var n_reg := Data.BIOMES.size()
	# 1. regions on a 2 x 3 grid, in an order where every region borders the next (so each border road is short)
	var slots := _region_path(r, n_reg)
	var regions := []
	for i in n_reg:
		var b: Dictionary = Data.BIOMES[i]
		regions.append({"i": i, "id": str(b.id), "req": int(b.req),
			"x": REGION_ORIGIN.x + (slots[i] % 2) * REGION_STEP.x + _jit(r, 7),
			"y": REGION_ORIGIN.y + (slots[i] / 2) * REGION_STEP.y + _jit(r, 5)})
	# 2. four stops per region in a loop (2 x 2 around the region centre), plus an optional diagonal shortcut
	var nodes := []
	var edges := []
	var by_id := {}
	for reg in regions:
		var stops := _region_stops(int(reg.i))
		for k in stops.size():
			var st: Dictionary = stops[k]
			var n := {"id": st.id, "type": st.type, "biome": int(reg.i),
				"x": int(reg.x) + (NODE_OFF.x if k % 2 == 1 else -NODE_OFF.x) + _jit(r, 7),
				"y": int(reg.y) + (NODE_OFF.y if k > 1 else -NODE_OFF.y) + _jit(r, 4)}
			if st.has("site"):
				n["site"] = st.site
			nodes.append(n)
			by_id[n.id] = n
		var ids: Array = stops.map(func(s): return s.id)
		for pair in [[0, 1], [1, 3], [3, 2], [2, 0]]:
			_link(edges, by_id, ids[pair[0]], ids[pair[1]], 0, -1, r)
		if r.randf() < 0.55:
			_link(edges, by_id, ids[1], ids[2], 0, -1, r)
	# 3. one border road from each region to the next, between their closest stops: the checkpoint
	for i in range(1, n_reg):
		var best := []
		var bd := INF
		for a in nodes.filter(func(x): return int(x.biome) == i - 1):
			for c in nodes.filter(func(x): return int(x.biome) == i):
				var d := Vector2(a.x, a.y).distance_to(Vector2(c.x, c.y))
				if d < bd:
					bd = d
					best = [a.id, c.id]
		_link(edges, by_id, best[0], best[1], int(regions[i].req), i - 1, r)
	# 4. the far exit of the last region (phase 2: lap + 1 = a new world)
	var last := nodes.filter(func(x): return int(x.biome) == n_reg - 1)
	var far: Dictionary = last[0]
	for x in last:
		if int(x.x) + int(x.y) > int(far.x) + int(far.y):
			far = x
	var ex := {"id": "world_exit", "type": "exit", "biome": n_reg - 1,
		"x": mini(CANVAS.x - 8, int(far.x) + 22), "y": mini(CANVAS.y - 8, int(far.y) + 18)}
	nodes.append(ex)
	by_id[ex.id] = ex
	_link(edges, by_id, far.id, ex.id, 0, -1, r)
	for e in edges:
		_set_km(e, by_id)
	return {"v": 1, "gen": GEN_VERSION, "seed": sd, "lap": lap, "regions": regions, "nodes": nodes, "edges": edges,
		"at": "start", "visited": {"start": true}}


static func _jit(r: RandomNumberGenerator, n: int) -> int:
	return int(round((r.randf() - 0.5) * float(n) * 2.0))


## a walk over the 2 x 3 slots that visits every slot once, each step to a neighbouring slot
static func _region_path(r: RandomNumberGenerator, n: int) -> Array:
	var starts := range(6)
	_shuffle(r, starts)
	for s in starts:
		var p := _walk(r, [s], n)
		if not p.is_empty():
			return p
	return range(n)


static func _walk(r: RandomNumberGenerator, path: Array, n: int) -> Array:
	if path.size() == n:
		return path
	var at: int = path[-1]
	var nb := [at - 1 if at % 2 == 1 else at + 1, at - 2, at + 2].filter(func(j): return j >= 0 and j < 6 and not path.has(j))
	_shuffle(r, nb)
	for j in nb:
		var p := _walk(r, path + [j], n)
		if not p.is_empty():
			return p
	return []


static func _shuffle(r: RandomNumberGenerator, a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## the four stops of a region: industrial = start + its three landmarks; the others = entry junction, two
## landmarks and an unknown-signal report. Landmarks come from Expedition.SITES (all 13, in road order).
static func _region_stops(i: int) -> Array:
	var bid := str(Data.biome(i).id)
	var sites := []
	for id in Expedition.SITES:
		if str(Expedition.SITES[id].biome) == bid:
			sites.append(id)
	sites.sort_custom(func(a, b): return float(Expedition.SITES[a].at) < float(Expedition.SITES[b].at))
	var out := []
	if i == 0:
		out.append({"id": "start", "type": "start"})
	else:
		out.append({"id": bid + "_junction", "type": "junction"})
	for id in sites:
		out.append({"id": id, "type": "landmark", "site": id})
	if i > 0:
		out.append({"id": bid + "_signal", "type": "rumor"})
	while out.size() < 4:
		out.append({"id": "%s_stop%d" % [bid, out.size()], "type": "stop"})
	return out.slice(0, 4)


static func _link(edges: Array, by_id: Dictionary, a: String, c: String, gate: int, boss: int, r: RandomNumberGenerator) -> void:
	var ids := [a, c]
	ids.sort()
	var id := "%s~%s" % ids
	for e in edges:
		if e.id == id:
			return
	edges.append({"id": id, "a": ids[0], "c": ids[1], "gate": gate, "boss": boss, "dirt": r.randf() < 0.35})


static func _set_km(e: Dictionary, by_id: Dictionary) -> void:
	var a: Dictionary = by_id[e.a]
	var c: Dictionary = by_id[e.c]
	var px := Vector2(a.x, a.y).distance_to(Vector2(c.x, c.y))
	var kpp := (float(Data.biome(int(a.biome)).length) + float(Data.biome(int(c.biome)).length)) * 0.5 / CROSS_PX
	e["km"] = maxf(0.1, snappedf(px * kpp, 0.1))


# =================================================================== queries
func node(id: String) -> Dictionary:
	for n in world().get("nodes", []):
		if str(n.id) == id:
			return n
	return {}


func edges_of(id: String) -> Array:
	return world().get("edges", []).filter(func(e): return str(e.a) == id or str(e.c) == id)


## stops reachable at this Vault level (a border road opens at its gate level; warlords are phase 2)
func reachable(from: String, vault: int) -> Dictionary:
	var seen := {from: true}
	var todo := [from]
	while not todo.is_empty():
		var u: String = todo.pop_back()
		for e in edges_of(u):
			if int(e.gate) > vault:
				continue
			var v: String = str(e.c) if str(e.a) == u else str(e.a)
			if not seen.has(v):
				seen[v] = true
				todo.append(v)
	return seen


## shortest drivable route: {ids: [from .. to], edges: [edge ids], km}; {} if there is none at this Vault level
func route(from: String, to: String, vault: int) -> Dictionary:
	var w := world()
	if w.is_empty() or node(from).is_empty() or node(to).is_empty():
		return {}
	var dist := {from: 0.0}
	var prev := {}
	var done := {}
	while true:
		var u := ""
		var best := INF
		for k in dist:
			if not done.has(k) and float(dist[k]) < best:
				best = float(dist[k])
				u = k
		if u == "" or u == to:
			break
		done[u] = true
		for e in edges_of(u):
			if int(e.gate) > vault:
				continue
			var v: String = str(e.c) if str(e.a) == u else str(e.a)
			var d := best + float(e.km)
			if not dist.has(v) or d < float(dist[v]):
				dist[v] = d
				prev[v] = [u, str(e.id)]
	if not dist.has(to):
		return {}
	var ids := [to]
	var eids := []
	while ids[0] != from:
		var p: Array = prev[ids[0]]
		eids.push_front(p[1])
		ids.push_front(p[0])
	return {"ids": ids, "edges": eids, "km": snappedf(float(dist[to]) * Features.num("world.km_scale", 1.0), 0.1)}


## one-line summary (GOD, trace)
func summary() -> String:
	var w := world()
	if w.is_empty():
		return "ยังไม่มีโลก" if on() else "สวิตช์ seeded_world_map ปิด"
	return "seed %s · v%d · รอบ %d · %d จุด · %d ถนน · อยู่ที่ %s" % [w.seed, int(w.gen), int(w.lap) + 1,
		(w.nodes as Array).size(), (w.edges as Array).size(), str(w.at)]
