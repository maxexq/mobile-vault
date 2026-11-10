class_name AmbulanceMods
extends RefCounted
## MV-763 (switch ambulance_mods): the approved Dr. Ren ambulance exterior mods (MV-731 designs) drawn on the van's
## ambulance shell through ShellMods. Layers: assets/vehicles/ambulance_v3/mods/ (tools/art/ambulance_mods/build.py).
## spike_ram L1-3 in front of the nose, roof_turret L1-3 on the rear roof (hidden while the squad fights from the gunner
## room, MV-727), armor_plates L1-3 on the lower body (+ armor_roof = the L3 roof band), rad_shield L1-2 on the cab
## (L2 covers the cab window, so Dr. Ren at the wheel is hidden), suspension L1-3 = coil shocks on every rear wheel,
## fuel_tanks L1-3 under the body (only the tanks that fit between the wheels: 3 / 2 / 1 at 1 / 2 / 3+ floors, the rest
## go to the fuel_rack on the rear wall), offroad_wheels L1-3 = bigger round tyres: AmbulanceMotion spins them on the
## road and the body rides higher by R - 22.5 px; without the wheel animation a still per-floor layer is drawn.
## RULE (Parames): no part covers a wheel at any floor count (layers are clipped per floor count by build.py).

const DIR := "res://assets/vehicles/ambulance_v3/"
const FUEL_FIT := {1: 3, 2: 2, 3: 1, 4: 1, 5: 1}
const STOCK_R := 22.5


static func on() -> bool:
	return Features.on("ambulance_mods")


static func _lv(id: String) -> int:
	return Mods.level(id) if not Game.s.is_empty() else 0


## the art level each part shows right now (0 = not drawn). spin_tyres: AmbulanceMotion draws the tyres (no still layer)
static func levels(floors: int, spin_tyres := false) -> Dictionary:
	var out := {}
	for id in ShellMods.ids(DIR):
		out[id] = 0
	if not on():
		return out
	var fit := int(FUEL_FIT.get(clampi(floors, 1, 5), 1))
	var fuel := _lv("fuel_tanks")
	for id in out:
		var lv := 0
		match id:
			"fuel_tanks":
				lv = mini(fuel, fit)
			"fuel_rack":
				lv = maxi(0, fuel - fit)
			"armor_roof":
				lv = _lv("armor_plates")
			"roof_turret":
				lv = 0 if Combat.room_mode() else _lv("roof_turret")   # MV-727: no outside gun with the room squad
			"offroad_wheels":
				lv = 0 if spin_tyres else _lv("offroad_wheels")
			_:
				lv = _lv(id)
		out[id] = clampi(lv, 0, ShellMods.max_art(DIR, id))
	return out


static func pos(id: String, lv: int, floors: int) -> Vector2:
	return ShellMods.pos(DIR, id, lv, floors)


## off-road tyre level shown (0 = stock tyres)
static func wheel_level() -> int:
	return clampi(_lv("offroad_wheels"), 0, ShellMods.max_art(DIR, "offroad_wheels")) if on() else 0


## off-road tyre radius in shell px (stock 22.5)
static func wheel_r(lv: int) -> float:
	var r: Dictionary = (ShellMods.meta(DIR).get("offroad_wheels", {}) as Dictionary).get("r", {})
	return float(r.get(str(lv), STOCK_R)) if lv > 0 else STOCK_R


## shell px the body rides higher on off-road tyres
static func lift() -> float:
	return wheel_r(wheel_level()) - STOCK_R


static var _spin: Dictionary = {}


## spin frames of the off-road tyre (AtlasTextures over the strip), empty = stock tyres
static func spin_frames(lv: int) -> Array:
	if lv <= 0:
		return []
	if not _spin.has(lv):
		var m: Dictionary = ShellMods.meta(DIR).get("offroad_wheels", {})
		var f := DIR + "mods/offroad_wheels_L%d_spin.png" % lv
		var arr: Array = []
		if ResourceLoader.exists(f):
			var strip: Texture2D = load(f)
			var s := int(m.get("size", 64))
			for i in int(m.get("spin", 48)):
				var a := AtlasTexture.new()
				a.atlas = strip
				a.region = Rect2(s * i, 0, s, s)
				arr.append(a)
		_spin[lv] = arr
	return _spin[lv]


## the rad shield's L2 plate covers the cab window
static func driver_hidden() -> bool:
	return on() and _lv("rad_shield") >= 2


## (re)build the parts under the ambulance shell; show=false (another vehicle) hides them. Returns parts drawn.
static func attach(shell: Sprite2D, floors: int, show: bool, spin_tyres := false) -> int:
	return ShellMods.attach(shell, DIR, floors, levels(floors, spin_tyres), show and on())
