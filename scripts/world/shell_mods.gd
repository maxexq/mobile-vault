class_name ShellMods
extends RefCounted
## MV-760: shared layer for exterior mod parts drawn on a world-v2 / v3 shell sprite (Decker first; ambulance and road
## train add their own data). Per vehicle folder: <dir>mods/<mod>_L<n>.png (trimmed RGBA) + <dir>mods/mods.json:
##   {"_deck_h": 112, "_base_floors": 2, "<mod>": {"anchor": "body"|"roof", "<n>": [x, y], ...}, ...}
## [x, y] = top-left in the shell's pixels at _base_floors decks. "body" parts move down _deck_h per deck above
## _base_floors (shells that grow upward), "roof" parts stay put. A per-deck override "<n>@<floors>": [x, y] wins.
## MV-763 optional extras: a third element names another file in mods/ for that entry ([x, y, "armor_plates_L2_f3"]: a
## layer clipped clear of that deck count's wheels), and "z": n on a mod draws it n z-steps over the shell's other
## overlays (the ambulance's roof gun over the animated plant pots).
## Parts are children of the shell sprite (node "ShellMods"), so they ride every hop and lurch. The caller decides which
## art level each mod shows (levels: {mod: n}, 0 = none) and whether the vehicle shows mods at all.

const NODE := "ShellMods"
static var _meta: Dictionary = {}


static func meta(dir: String) -> Dictionary:
	if not _meta.has(dir):
		var f := dir + "mods/mods.json"
		var j = JSON.parse_string(FileAccess.get_file_as_string(f)) if FileAccess.file_exists(f) else {}
		_meta[dir] = j if j is Dictionary else {}
	return _meta[dir]


## mods that have art for this vehicle
static func ids(dir: String) -> Array:
	return meta(dir).keys().filter(func(k): return not str(k).begins_with("_"))


## highest art level drawn for a mod
static func max_art(dir: String, id: String) -> int:
	var n := 0
	for k in (meta(dir).get(id, {}) as Dictionary):
		if str(k).is_valid_int():
			n = maxi(n, int(k))
	return n


## the entry ([x, y] or [x, y, file]) a part uses at the given deck count
static func _entry(dir: String, id: String, lv: int, floors: int) -> Array:
	var m: Dictionary = meta(dir).get(id, {})
	var over := "%d@%d" % [lv, floors]
	return m[over] if m.has(over) else m.get(str(lv), [0, 0])


## layer file of a part at the given deck count (MV-763: an entry may name its own clipped file)
static func file(dir: String, id: String, lv: int, floors: int) -> String:
	var e := _entry(dir, id, lv, floors)
	return dir + "mods/" + (str(e[2]) if e.size() > 2 else "%s_L%d" % [id, lv]) + ".png"


## shell-pixel position of a part at the given deck count
static func pos(dir: String, id: String, lv: int, floors: int) -> Vector2:
	var m: Dictionary = meta(dir).get(id, {})
	var over := "%d@%d" % [lv, floors]
	if m.has(over):
		return Vector2(float(m[over][0]), float(m[over][1]))
	var p: Array = m.get(str(lv), [0, 0])
	var base := int(meta(dir).get("_base_floors", 2))
	var dh := float(meta(dir).get("_deck_h", 112))
	var dy := dh * float(maxi(0, floors - base)) if str(m.get("anchor", "body")) == "body" else 0.0
	return Vector2(float(p[0]), float(p[1]) + dy)


## (re)build the parts under a shell sprite; show=false hides them (other vehicle, switch off). Returns parts drawn.
static func attach(shell: Sprite2D, dir: String, floors: int, levels: Dictionary, show: bool) -> int:
	if shell == null:
		return 0
	var root := shell.get_node_or_null(NODE) as Node2D
	if root == null:
		if not show:
			return 0
		root = Node2D.new()
		root.name = NODE
		shell.add_child(root)
	for ch in root.get_children():
		root.remove_child(ch)
		ch.queue_free()
	root.visible = show and shell.texture != null
	if not root.visible:
		return 0
	for id in levels:
		var lv := clampi(int(levels[id]), 0, max_art(dir, id))
		if lv <= 0:
			continue
		var f := file(dir, id, lv, floors)
		if not ResourceLoader.exists(f):
			continue
		var sp := Sprite2D.new()
		sp.name = id
		sp.centered = false
		sp.texture = load(f)
		sp.position = pos(dir, id, lv, floors)
		sp.z_index = int((meta(dir).get(id, {}) as Dictionary).get("z", 0))
		root.add_child(sp)
	return root.get_child_count()
