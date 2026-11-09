class_name PetsV3
extends RefCounted
## MV-733: the approved realistic-size pets (MV-601: 3 dogs, 3 cats, 3 chickens) in the v3 room cells (world v2 body
## and the v3 interior view). tools/pets_v3_import.py cut them into assets/v3/pets/<breed>.png (32x24 frames: 0 still,
## 1..8 walk, feet = bottom centre, facing east) + assets/v3/pets.json. Pets are drawn at room pixel scale (the art
## was made at the v2/v3 room scale, 14-20 px tall beside the ~40 px crew), so no 2/3 crew scaling.
## Every adopted pet (Game.s.pets) stays in one room for a while, then hops to another room with something in it,
## preferring rooms with people; every RoomV3Cell asks pets_in(slot) and keeps a PetV3Actor per pet it holds.
## Switch pets_v3 (off = the old 16-bit pets on the old van view; the world v2 body then shows none).

const DIR := "res://assets/v3/"
const STAY := Vector2(14.0, 32.0)        # seconds in one room before the next hop (x tune pets_v3.stay)
## the story pets keep a fixed breed: the dog from the stray dog event, the orange cat, the hen
const STORY := {"ข้าวตัง": "dog_mutt", "ส้มจี๊ด": "cat_ginger", "ไข่ดาว": "hen_brown"}

static var _data := {}
static var _loaded := false
static var _sheets := {}
static var _where := {}                  # pet index -> slot
static var _until := {}                  # pet index -> Time.get_ticks_msec() of the next hop


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + "pets.json")) if FileAccess.file_exists(DIR + "pets.json") else null
	if d is Dictionary:
		_data = d


static func ok() -> bool:
	_load()
	return not (_data.get("pets", {}) as Dictionary).is_empty()


## in use right now: switch on, art imported, a game running
static func on() -> bool:
	return Features.on("pets_v3") and ok() and not Game.s.is_empty()


static func breeds(kind: String = "") -> Array:
	_load()
	if kind == "":
		var out := []
		for k in _data.get("kinds", {}):
			out.append_array(_data.kinds[k])
		return out
	return (_data.get("kinds", {}) as Dictionary).get(kind, [])


static func info(breed: String) -> Dictionary:
	_load()
	return (_data.get("pets", {}) as Dictionary).get(breed, {})


## which breed plays this pet: its own "breed" (GOD / later adoption picks), the story pet's fixed look, or a stable
## pick from the name so a save always shows the same animal
static func breed_of(p: Dictionary) -> String:
	var kind := str(p.get("kind", "dog"))
	var list := breeds(kind)
	if list.is_empty():
		return ""
	var b := str(p.get("breed", ""))
	if list.has(b):
		return b
	var n := str(p.get("name", ""))
	if STORY.has(n) and list.has(STORY[n]):
		return STORY[n]
	return str(list[absi(n.hash()) % list.size()])


static func sheet(breed: String) -> Texture2D:
	if _sheets.has(breed):
		return _sheets[breed]
	var e := info(breed)
	var p := DIR + "pets/" + str(e.get("file", ""))
	var t: Texture2D = load(p) if not e.is_empty() and ResourceLoader.exists(p) else null
	_sheets[breed] = t
	return t


## rooms a pet may be in: built main-body rooms (no locked cell, building site, empty cell or large-room annex)
static func rooms() -> Array:
	var out := []
	if Game.s.is_empty():
		return out
	for slot in Game.main_slots():
		if slot >= Game.s.rooms.size() or not Game.is_slot_unlocked(slot) or Game.is_site(slot) or Game.is_annex(slot):
			continue
		var t := str(Game.s.rooms[Game.room_anchor(slot)].type)
		if t == "empty" or t == "locked":
			continue
		out.append(slot)
	return out


## the room pet `i` is in now (hops when its stay is over or its room went away); -1 = nowhere to be
static func slot_of(i: int) -> int:
	var now := Time.get_ticks_msec()
	var cur := int(_where.get(i, -1))
	var ok_rooms := rooms()
	if ok_rooms.is_empty():
		return -1
	if cur >= 0 and ok_rooms.has(cur) and now < int(_until.get(i, 0)):
		return cur
	var cands := []
	for slot in ok_rooms:
		if slot != cur or ok_rooms.size() == 1:
			cands.append(slot)
			if not Game.room_occupants(slot).is_empty():
				cands.append(slot)          # prefers rooms with people in them
	var pick := int(cands[randi() % cands.size()])
	_where[i] = pick
	_until[i] = now + int(1000.0 * randf_range(STAY.x, STAY.y) * Features.num("pets_v3.stay", 1.0))
	return pick


## [{i, breed, name, kind}] of the pets in this room right now
static func pets_in(slot: int) -> Array:
	var out := []
	if not on():
		return out
	var pets: Array = Game.s.get("pets", [])
	for i in pets.size():
		var p: Dictionary = pets[i]
		var b := breed_of(p)
		if b != "" and slot_of(i) == slot:
			out.append({"i": i, "breed": b, "name": str(p.get("name", "")), "kind": str(p.get("kind", ""))})
	return out


## GOD / tests: move every pet now (or pet `i` into `slot`)
static func hop_all() -> void:
	_until.clear()


static func put(i: int, slot: int, sec: float = 60.0) -> void:
	_where[i] = slot
	_until[i] = Time.get_ticks_msec() + int(sec * 1000.0)


static func reset() -> void:
	_where.clear()
	_until.clear()
