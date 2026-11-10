class_name RoadTrainMods
extends RefCounted
## MV-762 (switch road_train_mods): the approved road train exterior mods (MV-748 designs) drawn on the rig through the
## shared ShellMods layer (MV-760). Art + places: assets/vehicles/road_train_v3/mods/ (tools/art/road_train_mods/build.py).
## Body shell (tractor + lead trailer): spike_ram L1-3, armor_plates L1-3 on the cab (+ armor_rail on the lead trailer's
## side rail from L2), fuel_tanks L1-3 under the beam, solar_covers over the 3 roof panels, rad_shield L1-2 on the cab,
## heater L1-2 = the flue on the front roof corner. Container trailer: solar_covers_t, and roof_turret L1-3 on the REAR of
## the last trailer's roof facing back (the stock tyre stack + jerry cans there are cleared while it is built).
## Not ShellMods: heavy suspension (suspension / suspension_t) sits behind the tyres and off-road wheels swap the tyre
## spin strip (48 frames, MV-759); both go through AmbulanceMotion (rt_mods()).

const DIR := "res://assets/vehicles/road_train_v3/"
const BODY := ["spike_ram", "armor_plates", "armor_rail", "fuel_tanks", "solar_covers", "rad_shield", "heater"]
const TEX0 := "rt_mods_tex0"          # meta on a trailer sprite: its texture before the turret cleared the roof clutter


static func on() -> bool:
	return Features.on("road_train_mods")


static func _lv(id: String) -> int:
	if Game.s.is_empty():
		return 0
	return Mods.level(id)


## art level per body part right now (0 = not drawn)
static func body_levels() -> Dictionary:
	var out := {}
	for id in BODY:
		var src: String = "armor_plates" if id == "armor_rail" else id
		out[id] = clampi(_lv(src), 0, ShellMods.max_art(DIR, id))
	return out


## art level per container-trailer part; the turret only on the rearmost trailer, and not while the squad fights from
## the rear gunner room (MV-727, no outside gun)
static func trailer_levels(rear: bool) -> Dictionary:
	var gun := _lv("roof_turret") if rear and not Combat.room_mode() else 0
	return {"solar_covers_t": clampi(_lv("solar_covers"), 0, 1), "roof_turret": clampi(gun, 0, 3)}


static func wheel_level() -> int:
	return clampi(_lv("offroad_wheels"), 0, 3) if on() else 0


static func susp_level() -> int:
	return clampi(_lv("suspension"), 0, 3) if on() else 0


static func attach_body(shell: Sprite2D, floors: int, show: bool) -> int:
	return ShellMods.attach(shell, DIR, floors, body_levels(), show and on())


## parts on one container trailer sprite; with the turret built, the roof clutter it replaces is cleared from a copy of
## the sprite's texture (restored when the turret goes)
static func attach_trailer(sp: Sprite2D, floors: int, show: bool, rear: bool) -> int:
	if sp == null:
		return 0
	var lv := trailer_levels(rear)
	var want := show and on() and int(lv.roof_turret) > 0
	if sp.has_meta(TEX0):
		sp.texture = sp.get_meta(TEX0)
		sp.remove_meta(TEX0)
	if want and sp.texture != null:
		var r: Array = ShellMods.meta(DIR).get("_clear_turret", [])
		if r.size() == 4:
			var img := sp.texture.get_image()
			img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			img.fill_rect(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])), Color(0, 0, 0, 0))
			sp.set_meta(TEX0, sp.texture)
			sp.texture = ImageTexture.create_from_image(img)
	return ShellMods.attach(sp, DIR, floors, lv, show and on())


## heavy suspension behind the tyres + off-road tyre strips on one AmbulanceMotion unit of the road train
static func rt_mods(m: AmbulanceMotion, show: bool) -> void:
	if m == null:
		return
	m.set_wheel_level(wheel_level() if show else 0)
	var lv := susp_level() if show else 0
	var id := "suspension" if m.unit == "" else "suspension_t"
	var f := DIR + "mods/%s_L%d.png" % [id, lv]
	if lv > 0 and ResourceLoader.exists(f):
		m.set_under_part(load(f), ShellMods.pos(DIR, id, lv, m.floors))
	else:
		m.set_under_part(null, Vector2.ZERO)


## parts drawn on the road view right now (GOD row / autotest)
static func count(v: Node) -> int:
	var n := 0
	if v == null:
		return 0
	var shells: Array = [v.get("v2_shell")]
	shells.append_array(v.get("v2_tshells") if v.get("v2_tshells") != null else [])
	for s in shells:
		if s == null:
			continue
		var root := (s as Node).get_node_or_null(ShellMods.NODE) as Node2D
		if root != null and root.visible:
			n += root.get_child_count()
	return n
