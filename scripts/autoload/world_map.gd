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
## Phase 2 (MV-130): driving. drive_to(stop) commits a validated route (selecting a stop alone does nothing); the
## trip (world.trip: route, road index, km done on that road, destination) is saved, so park / resume / reload carry on
## from the same spot with no free distance. Game drives it with its normal speed / power / fuel / scrap / event rules
## (step()); entering a region switches the biome; an unvisited landmark parks the vehicle once through the normal
## expedition flow (offline: drives past, as before); the vehicle waits before a closed border road (Game.at_checkpoint:
## the warlord / peaceful toll work as today) and parks at the destination; the exit = lap + 1 in a new world.
## Phase 4 (MV-514): old saves and the switch flipped off / on. reconcile() (on every game start, cloud load and
## switch change) makes the saved world agree with the run, and changes nothing when it already does, so running it
## twice is a no-op. No world yet, or one from another lap: a new world for this lap (the lap rule is unchanged: only
## the far exit starts a lap). The vehicle's stop must be in the run's biome: if it isn't (an old biome / km / lap save,
## or progress made on the old road while the switch was off) place() puts it there by one fixed rule:
##   parked at a landmark (at_site)        -> that landmark's stop
##   standing at the old biome's checkpoint -> the stop on the border road out of the region (it waits there as before)
##   anywhere else in the biome             -> the region's entry stop (where the border road from the previous one lands)
## Every stop of earlier regions, that stop, and each landmark already done this lap are marked visited; a trip that no
## longer fits is dropped (the vehicle waits for a destination). Resources, crew, bosses beaten, Vault level,
## sites_done, an expedition, km and lap are never touched and nothing is granted. With the switch off the old road
## drives on s.km, which map driving keeps inside the current biome (Game._drive_map). A world this build doesn't know
## (newer save version / generator) is kept as it is and the old road drives (usable() = false).
## Switch seeded_world_map (off = the old itinerary; off in config until the map screen ships). GOD → โลก → WORLD MAP.
## Autotest --only=world_map, --only=world_travel, --only=world_migrate.

signal world_changed

## MV-542: the destination reached during the offline catch-up (its arrival toast is skipped there), for the
## "while you were away" summary; "" = none. Game._offline_progress reads and clears it
var offline_arrival := ""

const GEN_VERSION := 2      # 2 (MV-515): the exit sits clear of its neighbour stop. Saved worlds keep their own graph
const SAVE_VERSION := 1                  # Game.s.world.v this build reads
const PLACE_VERSION := 1                 # MV-514 placement rule (recorded in world.placed)
const CANVAS := Vector2i(336, 360)       # native map canvas (handoff); stop positions are in these pixels
const REGION_STEP := Vector2i(168, 120)
const REGION_ORIGIN := Vector2i(84, 60)
const NODE_OFF := Vector2i(31, 29)
const CROSS_PX := 120.0                  # drawn px of a typical crossing of one region (km scaling)
const SEED_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ"


func _ready() -> void:
	Game.game_started.connect(func(): reconcile())
	Features.changed.connect(func():
		if Game.started:
			reconcile())


func on() -> bool:
	return Features.on("seeded_world_map")


# =================================================================== state
## the current world ({} = none yet, or the switch is off)
func world() -> Dictionary:
	if Game.s.is_empty() or not (Game.s.get("world") is Dictionary):
		return {}
	return Game.s.world


## make the world for this run if there is none yet (never replaces an existing one of this lap)
func ensure() -> Dictionary:
	if not on() or Game.s.is_empty():
		return {}
	reconcile()
	return world()


## a world this build can drive (the save version and generator it knows)
func supported(w: Dictionary) -> bool:
	return int(w.get("v", 0)) == SAVE_VERSION and int(w.get("gen", 0)) >= 1 and int(w.get("gen", 0)) <= GEN_VERSION 		and w.get("nodes") is Array and w.get("edges") is Array and w.get("visited") is Dictionary


## the switch is on and there is a world this build can drive
func usable() -> bool:
	return on() and not world().is_empty() and supported(world())


## MV-514: make the saved world agree with the run; "" = it already did (nothing changed), else what it did:
## "created" (a new world for this lap), "placed" (the vehicle moved into the run's biome), "unsupported" (kept as is)
func reconcile() -> String:
	if not on() or Game.s.is_empty():
		return ""
	var w := world()
	if not w.is_empty() and not supported(w):
		Trace.rec("travel", "world kept: unsupported", {"v": w.get("v"), "gen": w.get("gen")})
		return "unsupported"
	if w.is_empty() or int(w.get("lap", 0)) != int(Game.s.get("lap", 0)):
		create(random_seed())
		return "created"
	if fits():
		return ""
	place(w)
	return "placed"


## the world's stop is in the run's biome, and the vehicle parked at a landmark is at that landmark's stop
func fits() -> bool:
	var n := node(here())
	if n.is_empty() or int(n.biome) != int(Game.s.biome):
		return false
	var site := Expedition.at_site()
	return site == "" or str(n.get("site", "")) == site or _site_node(site) == ""


## a new world for this run / lap from a seed: the only place a world is (re)generated
func create(seed_text: String) -> Dictionary:
	var w := generate(seed_text, int(Game.s.get("lap", 0)))
	Game.s["world"] = w
	if int(Game.s.get("biome", 0)) != 0 or Expedition.at_site() != "":
		place(w)          # a run already under way (old save, GOD new world mid-run): put the vehicle where it is
	Trace.rec("travel", "world created", {"seed": w.seed, "gen": w.gen, "lap": w.lap, "at": w.at})
	world_changed.emit()
	return w


## MV-514: put the vehicle into the run's biome by the fixed rule (see the top of this file); returns the rule used
func place(w: Dictionary) -> String:
	var b := clampi(int(Game.s.get("biome", 0)), 0, Data.BIOMES.size() - 1)
	var entry := _entry_stop(w, b)
	var at := entry
	var rule := "entry"
	var site := Expedition.at_site()
	if site != "" and _site_node(site, w) != "":
		at = _site_node(site, w)
		rule = "landmark"
	elif float(Game.s.get("km", 0.0)) >= Data.biome_start_km(b + 1) - 0.001:
		at = _exit_stop(w, b)
		rule = "checkpoint"
	for n in w.nodes:
		var id := str(n.id)
		if int(n.biome) < b and str(n.type) != "exit" or id == entry or id == at 				or int(n.biome) == b and n.has("site") and Expedition.is_done(str(n.site)):
			w.visited[id] = true
	w.at = at
	w.erase("trip")
	w["placed"] = {"v": PLACE_VERSION, "rule": rule, "biome": b, "km": snappedf(float(Game.s.get("km", 0.0)), 0.01),
		"lap": int(Game.s.get("lap", 0)), "at": at}
	Trace.rec("travel", "world placed", w.placed)
	world_changed.emit()
	return rule


## where the border road from the previous region lands in region b (the start in the first)
static func _entry_stop(w: Dictionary, b: int) -> String:
	if b == 0:
		return "start"
	return _border_end(w, b - 1, b)


## the stop of region b on the border road out of it (to the next region, or to the exit in the last)
static func _exit_stop(w: Dictionary, b: int) -> String:
	return _border_end(w, b, b)


## the end in region `side` of the road whose warlord is region `boss`
static func _border_end(w: Dictionary, boss: int, side: int) -> String:
	var by := {}
	for n in w.nodes:
		by[str(n.id)] = n
	for e in w.edges:
		if int(e.get("boss", -1)) != boss:
			continue
		for id in [str(e.a), str(e.c)]:
			if by.has(id) and int(by[id].biome) == side and str(by[id].type) != "exit":
				return id
	for n in w.nodes:
		if int(n.biome) == side and str(n.type) != "exit":
			return str(n.id)
	return "start"


func _site_node(site: String, w: Dictionary = {}) -> String:
	for n in (w if not w.is_empty() else world()).get("nodes", []):
		if str(n.get("site", "")) == site:
			return str(n.id)
	return ""


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
	# the exit goes next to its stop but clear of every frame: the nearest spot (34 / 44 / 56 px, 8 directions,
	# inside the map) whose box gap to every other stop is at least 30 px; if none, the roomiest one
	var ex_at := Vector2i(int(far.x), int(far.y)) + Vector2i(0, 34)
	var best_gap := -1
	var found := false
	for d in [34, 44, 56]:
		if found:
			break
		for dir in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
			var step: Vector2i = dir
			var at: Vector2i = Vector2i(int(far.x), int(far.y)) + step * (d if step.x == 0 or step.y == 0 else int(d * 0.75))
			if at.x < 17 or at.y < 17 or at.x > CANVAS.x - 17 or at.y > CANVAS.y - 17:
				continue
			var gap := 1 << 20
			for x in nodes:
				gap = mini(gap, maxi(absi(at.x - int(x.x)), absi(at.y - int(x.y))))
			if gap >= 30:
				ex_at = at
				found = true
				break
			if gap > best_gap:
				best_gap = gap
				ex_at = at
	var ex := {"id": "world_exit", "type": "exit", "biome": n_reg - 1, "x": ex_at.x, "y": ex_at.y}
	nodes.append(ex)
	by_id[ex.id] = ex
	_link(edges, by_id, far.id, ex.id, int(regions[n_reg - 1].req), n_reg - 1, r)   # needs the last warlord
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
	if not supported(w):
		return "โลกเวอร์ชันใหม่กว่าเกมนี้ (v%s gen %s): เก็บไว้เหมือนเดิม ใช้ถนนแบบเดิม" % [str(w.get("v")), str(w.get("gen"))]
	var pl: Dictionary = w.get("placed", {})
	return "seed %s · v%d · รอบ %d · %d จุด · %d ถนน · อยู่ที่ %s%s" % [w.seed, int(w.gen), int(w.lap) + 1,
		(w.nodes as Array).size(), (w.edges as Array).size(), str(w.at),
		"" if pl.is_empty() else " · ย้ายจากเซฟเก่า (%s)" % str(pl.rule)]


# =================================================================== phase 2 (MV-130): driving along the roads
func trip() -> Dictionary:
	var t = world().get("trip", {})
	return t if t is Dictionary else {}


func driving() -> bool:
	return not trip().is_empty()


func edge(id: String) -> Dictionary:
	for e in world().get("edges", []):
		if str(e.id) == id:
			return e
	return {}


## where the vehicle is: the stop it is at, or the stop it left on the current road
func here() -> String:
	var t := trip()
	if t.is_empty():
		return str(world().get("at", "start"))
	return str(t.ids[int(t.i)])


## why the vehicle can't set off for this stop ("" = it can)
func drive_block(dest: String) -> String:
	if not on() or world().is_empty():
		return "แผนที่โลกปิดอยู่"
	if node(dest).is_empty():
		return "ไม่มีจุดนี้"
	var from := _route_start()
	if dest == from and float(trip().get("prog", 0.0)) <= 0.0:
		return "อยู่ที่นี่แล้ว"
	if route(from, dest, int(Game.s.vault_level)).is_empty():
		return "ไปไม่ถึง: ต้องอัปเกรด Mobile Vault ก่อน"
	return ""


## mid-road a new destination starts from the end of the current road (no turning round for free distance)
func _route_start() -> String:
	var t := trip()
	if t.is_empty() or float(t.prog) <= 0.0:
		return here()
	return str(t.ids[int(t.i) + 1])


## commit a route to dest; true when it starts. Mid-road the current road is finished first.
func drive_to(dest: String) -> bool:
	if drive_block(dest) != "":
		return false
	var t := trip()
	var keep_edge := ""
	var keep_prog := 0.0
	var from := _route_start()
	if not t.is_empty() and float(t.prog) > 0.0:
		keep_edge = str(t.edges[int(t.i)])
		keep_prog = float(t.prog)
	var rt := route(from, dest, int(Game.s.vault_level))
	var ids: Array = rt.ids.duplicate()
	var eids: Array = rt.edges.duplicate()
	if keep_edge != "":
		ids.push_front(str(t.ids[int(t.i)]))
		eids.push_front(keep_edge)
	world()["trip"] = {"ids": ids, "edges": eids, "i": 0, "prog": keep_prog, "dest": dest}
	Trace.rec("travel", "drive to %s" % dest, {"from": ids[0], "stops": ids.size(), "km": rt.km})
	world_changed.emit()
	Game.travel_changed.emit()
	return true


func cancel_trip() -> void:
	var t := trip()
	if t.is_empty() or float(t.prog) > 0.0:
		return       # mid-road it finishes the road first (drive_to its end)
	world().erase("trip")
	world_changed.emit()
	Game.travel_changed.emit()


## the road the trip is about to take is a closed border road: the vehicle waits here (the checkpoint)
func at_gate() -> bool:
	var t := trip()
	if t.is_empty() or float(t.prog) > 0.0:
		return false
	return _gate_closed(edge(str(t.edges[int(t.i)])), str(t.ids[int(t.i)]), str(t.ids[int(t.i) + 1]))


## the Vault level the border road ahead needs (0 = none ahead)
func gate_ahead() -> int:
	var t := trip()
	if t.is_empty():
		return 0
	var e := edge(str(t.edges[int(t.i)]))
	return int(e.get("gate", 0)) if _forward(e, str(t.ids[int(t.i)]), str(t.ids[int(t.i) + 1])) else 0


## leaving a region over its border road (or out through the exit) needs that region's warlord + the next Vault level
func _forward(e: Dictionary, from: String, to: String) -> bool:
	if int(e.get("boss", -1)) < 0:
		return false
	return int(node(to).biome) > int(node(from).biome) or str(node(to).type) == "exit"


func _gate_closed(e: Dictionary, from: String, to: String) -> bool:
	if not _forward(e, from, to):
		return false
	var boss := int(e.boss)
	var beaten := Combat.boss_beaten(boss)
	return not beaten or int(Game.s.vault_level) < int(e.gate)


## drive km along the trip; returns the km actually driven. Stops for good at an unvisited landmark (parked), a
## closed border road, the destination or the exit (lap + 1).
func step(km: float, offline: bool) -> float:
	var used := 0.0
	while km > 0.0:
		var t := trip()
		if t.is_empty() or at_gate():
			break
		var e := edge(str(t.edges[int(t.i)]))
		var left := float(e.km) - float(t.prog)
		if km < left:
			t.prog = float(t.prog) + km
			used += km
			break
		used += left
		km -= left
		t.prog = 0.0
		t.i = int(t.i) + 1
		if _arrive(str(t.ids[int(t.i)]), offline):
			break
	_cache_drive(used)
	return used


## reached a stop; true = stop driving for this step (parked / destination / new world)
func _arrive(id: String, offline: bool) -> bool:
	var w := world()
	var n := node(id)
	var t := trip()
	w.at = id
	w.visited[id] = true
	if int(n.biome) != int(Game.s.biome):
		Game.s.biome = int(n.biome)
		Game.s.km = Data.biome_start_km(int(n.biome))
		Game.biome_changed.emit(int(Game.s.biome), offline)
		if not offline:
			Game.toast.emit("เข้าสู่ %s / %s" % [Data.biome(Game.s.biome).th, Data.biome(Game.s.biome).en], "biome")
	if str(n.type) == "exit":
		Trace.rec("travel", "world exit", {"lap": int(Game.s.lap)})
		Game._finish_lap()
		return true
	var last := id == str(t.dest)
	if last:
		w.erase("trip")
		if not offline:
			Game.toast.emit("ถึงปลายทางแล้ว รถจอดรอคำสั่ง", "info")
		else:
			offline_arrival = str(Expedition.SITES[n.site].th) if n.has("site") else Loc.t("ปลายทาง")
	elif int(t.i) >= (t.ids as Array).size() - 1:
		w.erase("trip")
	_cache_arrive(id, offline)      # MV-546: after the trip is settled (it redraws the map)
	Trace.rec("travel", "arrived %s" % id, {"dest": last})
	world_changed.emit()
	if n.has("site") and not Expedition.is_done(str(n.site)):
		Expedition.arrive(str(n.site))
		if offline:
			Expedition.skip_site()   # nobody there to send a team: drive on, as on the old road
		else:
			Game.toast.emit("พบสถานที่สำคัญ: %s! รถจอด — ส่งทีมสำรวจหรือขับผ่าน" % Expedition.SITES[n.site].th, "biome")
			return true
	return last


# =================================================================== MV-546: random blueprint caches on the map
## One cache at a time sits on a reachable stop; driving onto it (destination or passing through) grants one blueprint
## the account doesn't own yet, or a supply crate when every eligible one is owned. Approved numbers (Parames
## 2026-10-27): the first after bpcache.first_km driven in a world, then every bpcache.every_km a bpcache.chance roll,
## at most bpcache.max_per_lap per world; an unclaimed cache goes with its world. Every roll, the stop and the reward
## come from the world seed + lap + the saved counters (world.bpcache), so a reload never rerolls. Blueprints from the
## regions the Vault level opens plus one ahead; bp_train stays the OVERSEER reward. Switch map_blueprint_caches.
## GOD → โลก → BLUEPRINT CACHE. Autotest --only=bp_cache.
const BP_WEIGHT := {"bp_engine_tune": 3, "bp_air_filter": 3, "bp_roof_turret": 3, "bp_solar_covers": 3, "bp_heater": 3,
	"bp_rad_shield": 3, "bp_tracks": 3, "bp_workshop": 2, "bp_refinery": 2, "bp_repair_bay": 2, "bp_trailer": 2,
	"bp_bus": 1, "bp_rig": 1}
const SUPPLY := {"scrap": 80, "components": 10}

## blueprints found in caches while away (Game._offline_progress reads and clears it)
var offline_caches: Array = []


func caches_on() -> bool:
	return usable() and Features.on("map_blueprint_caches")


## the saved cache state of this world: n = caches spawned, km = driven since the last spawn / pickup, rolls = chance
## rolls made, at = the stop holding the cache ("" = none), got = what each pickup gave
func cache_state() -> Dictionary:
	var w := world()
	if w.is_empty():
		return {}
	if not (w.get("bpcache") is Dictionary):
		w["bpcache"] = {"n": 0, "km": 0.0, "rolls": 0, "at": "", "got": []}
	return w.bpcache


## the stop holding the cache ("" = none, or the switch is off)
func cache_at() -> String:
	return str(cache_state().get("at", "")) if caches_on() else ""


func _cache_rng(tag: String, a: int, b: int = 0) -> RandomNumberGenerator:
	var w := world()
	var r := RandomNumberGenerator.new()
	r.seed = fnv1a("%s/%d/bpc/%s/%d/%d" % [str(w.get("seed", "")), int(w.get("lap", 0)), tag, a, b])
	return r


## the region (biome index) whose landmark gives this blueprint
static func bp_region(bp: String) -> int:
	for id in Expedition.SITES:
		var s: Dictionary = Expedition.SITES[id]
		if (s.loot.get("bp", []) as Array).has(bp):
			for i in Data.BIOMES.size():
				if str(Data.BIOMES[i].id) == str(s.biome):
					return i
	return Data.BIOMES.size() - 1


## blueprints a cache can give now: weighted, from regions open at this Vault level + one ahead, not owned yet
func cache_pool() -> Dictionary:
	var out := {}
	var vault := int(Game.s.get("vault_level", 1))
	for bp in BP_WEIGHT:
		if not Meta.has_blueprint(bp) and int(Data.biome(bp_region(bp)).req) <= vault + 1:
			out[bp] = int(BP_WEIGHT[bp])
	return out


## km driven on the map (step): count towards the next cache and roll when it is due
func _cache_drive(km: float) -> void:
	if not caches_on() or km <= 0.0:
		return
	var st := cache_state()
	if str(st.at) != "" or int(st.n) >= int(Features.num("bpcache.max_per_lap", 3.0)):
		return
	st.km = float(st.km) + km
	if int(st.n) == 0:
		if float(st.km) >= Features.num("bpcache.first_km", 3.0):
			spawn_cache()
		return
	var every := Features.num("bpcache.every_km", 2.0)
	while float(st.km) >= every and str(st.at) == "":
		st.km = float(st.km) - every
		var roll := _cache_rng("roll", int(st.n), int(st.rolls)).randf()
		st.rolls = int(st.rolls) + 1
		if roll < Features.num("bpcache.chance", 0.35):
			spawn_cache()


## put the next cache on a stop (true = placed). Prefers junctions / signal stops of this region and the next
## reachable one, then any reachable non-landmark, then landmarks; never the vehicle's stop, the start or the exit.
func spawn_cache() -> bool:
	var st := cache_state()
	if st.is_empty():
		return false
	var from := _route_start()
	var reach := reachable(from, int(Game.s.vault_level))
	var near := []
	var other := []
	var marks := []
	var b := int(Game.s.biome)
	for n in world().nodes:
		var id := str(n.id)
		if not reach.has(id) or id == from or id == here() or str(n.type) in ["start", "exit"] 				or int(Data.biome(int(n.biome)).req) > int(Game.s.vault_level):
			continue
		if str(n.type) == "landmark":
			marks.append(id)
		elif int(n.biome) == b or int(n.biome) == b + 1:
			near.append(id)
		else:
			other.append(id)
	var pick: Array = near if not near.is_empty() else (other if not other.is_empty() else marks)
	if pick.is_empty():
		return false
	pick.sort()
	var at: String = pick[_cache_rng("at", int(st.n)).randi() % pick.size()]
	st.at = at
	st.n = int(st.n) + 1
	st.km = 0.0
	Trace.rec("travel", "blueprint cache at %s" % at, {"n": st.n})
	world_changed.emit()
	return true


## the vehicle reached a stop: pick up the cache there; returns what it gave ("" = no cache here)
func _cache_arrive(id: String, offline: bool) -> String:
	if not caches_on() or cache_at() != id:
		return ""
	var st := cache_state()
	var pool := cache_pool()
	var got := ""
	if not pool.is_empty():
		var keys := pool.keys()
		keys.sort()
		var total := 0
		for k in keys:
			total += int(pool[k])
		var r := _cache_rng("bp", int(st.n)).randi() % total
		var bp: String = keys[0]
		for k in keys:
			r -= int(pool[k])
			if r < 0:
				bp = k
				break
		Meta.add_blueprint(bp)
		got = str(Mods.BLUEPRINT_TH.get(bp, bp))
		(st.got as Array).append(bp)
		if not offline:
			Game.toast.emit(Loc.t("เปิดกล่องพิมพ์เขียว! ได้%s") % got, "good")
	else:
		var m := 1.0 + 0.5 * float(int(node(id).get("biome", 0)))
		var rew := {}
		for k in SUPPLY:
			rew[k] = int(round(float(SUPPLY[k]) * m))
		got = Loc.t("กล่องเสบียง (%s)") % Game.give_rewards(rew)
		(st.got as Array).append("supply")
		if not offline:
			Game.toast.emit(Loc.t("มีพิมพ์เขียวครบแล้ว กล่องนี้ได้%s") % got, "good")
	if offline:
		offline_caches.append(got)
	st.at = ""
	st.km = 0.0
	Trace.rec("travel", "blueprint cache picked up at %s" % id, {"got": got, "offline": offline})
	world_changed.emit()
	return got
