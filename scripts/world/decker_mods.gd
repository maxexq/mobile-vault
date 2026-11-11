class_name DeckerMods
extends RefCounted
## MV-760 (switch decker_mods): the approved Decker exterior mods (MV-739 designs) drawn on the bus through ShellMods.
## Layers: assets/vehicles/decker_v3/mods/ (tools/art/decker_mods/build.py). Mod -> art: spike_ram L1-3, fuel_tanks L1-3,
## armor_plates L1-3 (skirt plates), roof_turret L1-3 = the rear-wall sponson gun (hidden while the squad fights from the
## gunner room, MV-727), rad_shield L1-2 = lead on the front of both decks, heater L1-2 = the roof flue, solar = the two roof
## panels (L1 makeshift, +1 with solar_covers, +1 at 4 panels). Off-road wheels and suspension come later on the new stock tyre.

const DIR := "res://assets/vehicles/decker_v3/"


static func on() -> bool:
	return Features.on("decker_mods")


## the art level each part shows right now (0 = not drawn)
static func levels() -> Dictionary:
	var out := {}
	for id in ShellMods.ids(DIR):
		var lv := 0
		if id == "solar":
			var sol: Dictionary = Game.s.get("solar", {}) if not Game.s.is_empty() else {}
			lv = 1 + (1 if Mods.level("solar_covers") > 0 else 0) + (1 if int(sol.get("panels", 1)) >= 4 else 0)
		elif id == "roof_turret" and Combat.room_mode():
			lv = 0                    # MV-727: the squad fights from the rear gunner room, no outside gun
		else:
			lv = Mods.level(id)
		out[id] = clampi(lv, 0, ShellMods.max_art(DIR, id))
	return out


static func pos(id: String, lv: int, floors: int) -> Vector2:
	return ShellMods.pos(DIR, id, lv, floors)


static func attach(shell: Sprite2D, floors: int, show: bool) -> int:
	return ShellMods.attach(shell, DIR, floors, levels(), show and on())
