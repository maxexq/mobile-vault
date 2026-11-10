class_name DeckerMods
extends RefCounted
## MV-760 (switch decker_mods): the approved Decker exterior mods (MV-739 designs) drawn on the bus. Each part is a trimmed
## PNG in assets/vehicles/decker_v3/mods/ (tools/art/decker_mods/build.py) placed in shell_f2 pixels from mods.json; "body"
## parts move down one deck (112 px) per deck above 2, "roof" parts stay on the roof. They are children of the shell sprite,
## so they ride every hop and lurch. Mod -> art: spike_ram L1-3, fuel_tanks L1-3, armor_plates L1-3 (skirt plates),
## roof_turret L1-3 = the rear-wall sponson gun, rad_shield L1-2 = lead on the front of both decks, heater L1-2 = the roof
## flue, solar = the two roof panels (L1 makeshift, +1 with solar_covers, +1 at 4 panels). Off-road wheels and suspension
## come later on the new stock tyre (MV-759).

const DIR := "res://assets/vehicles/decker_v3/mods/"
const DECK_H := 112
const NODE := "DeckerMods"
static var _meta: Dictionary = {}


static func on() -> bool:
	return Features.on("decker_mods")


static func meta() -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists(DIR + "mods.json"):
		var j = JSON.parse_string(FileAccess.get_file_as_string(DIR + "mods.json"))
		if j is Dictionary:
			_meta = j
	return _meta


## highest art level drawn for a mod
static func max_art(id: String) -> int:
	var n := 0
	for k in (meta().get(id, {}) as Dictionary):
		if str(k).is_valid_int():
			n = maxi(n, int(k))
	return n


## the art level each part shows right now (0 = not drawn)
static func levels() -> Dictionary:
	var out := {}
	for id in meta():
		var lv := 0
		if id == "solar":
			var sol: Dictionary = Game.s.get("solar", {}) if not Game.s.is_empty() else {}
			lv = 1 + (1 if Mods.level("solar_covers") > 0 else 0) + (1 if int(sol.get("panels", 1)) >= 4 else 0)
		elif id == "roof_turret" and Combat.room_mode():
			lv = 0                    # MV-727: the squad fights from the rear gunner room, no outside gun
		else:
			lv = Mods.level(id)
		out[id] = clampi(lv, 0, max_art(id))
	return out


## shell-pixel position of a part at the given deck count
static func pos(id: String, lv: int, floors: int) -> Vector2:
	var m: Dictionary = meta().get(id, {})
	var p: Array = m.get(str(lv), [0, 0])
	var dy := float(DECK_H * maxi(0, floors - 2)) if str(m.get("anchor", "body")) == "body" else 0.0
	return Vector2(float(p[0]), float(p[1]) + dy)


## (re)build the parts under the Decker's shell sprite; show=false (other vehicles) or the switch off hides them.
## Returns how many parts are drawn.
static func attach(shell: Sprite2D, floors: int, show: bool) -> int:
	if shell == null:
		return 0
	var root := shell.get_node_or_null(NODE) as Node2D
	if root == null:
		if not (show and on()):
			return 0
		root = Node2D.new()
		root.name = NODE
		shell.add_child(root)
	for ch in root.get_children():
		root.remove_child(ch)
		ch.queue_free()
	root.visible = show and on() and shell.texture != null
	if not root.visible:
		return 0
	var lv := levels()
	for id in lv:
		if int(lv[id]) <= 0:
			continue
		var f := DIR + "%s_L%d.png" % [id, lv[id]]
		if not ResourceLoader.exists(f):
			continue
		var sp := Sprite2D.new()
		sp.name = id
		sp.centered = false
		sp.texture = load(f)
		sp.position = pos(id, int(lv[id]), floors)
		root.add_child(sp)
	return root.get_child_count()
