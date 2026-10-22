extends Node
## Power & weight balance.
## Every built room, room level, armour plate, exterior mod, hitched trailer and stored ton of scrap adds weight.
## The engine (vehicle tier + engine tune + suspension + off-road wheels + the engine room's level/crew +
## the equipped engine part) has a capacity. Overloaded rigs drive slower and burn much more fuel; the player
## has to keep upgrading the drivetrain as the base grows.

const ROOM_W := 2.5            # tons per built room
const LEVEL_W := 1.0           # per extra room level
const TRAILER_W := 14.0
const MOD_W := {"armor_plates": 4.0, "spike_ram": 1.5, "roof_turret": 2.0, "fuel_tanks": 1.5, "tracks": 6.0,
	"rad_shield": 3.0, "rain_catcher": 0.5, "solar_covers": 0.5, "storage_racks": 1.0, "repair_bay": 1.5,
	"heater": 1.0, "insulation": 1.0, "water_recycler": 1.0, "air_filter": 0.5}
const FUEL_PER_TON := 0.006    # fuel per minute per ton while driving (x overload)


func weight() -> float:
	if Game.s.is_empty():
		return 0.0
	var w := float(Game.vehicle_def().weight) + TRAILER_W * Game.trailers()
	for i in Game.s.rooms.size():
		var r: Dictionary = Game.s.rooms[i]
		if r.type != "empty" and r.type != "engine":
			w += ROOM_W + LEVEL_W * float(int(r.level) - 1)
	for id in MOD_W:
		w += float(MOD_W[id]) * Mods.level(id)
	w += float(Game.s.res.get("scrap", 0.0)) / 1000.0
	w += float(Game.s.dwellers.size()) * 0.1
	return w


## drivetrain capacity in tons
func capacity() -> float:
	if Game.s.is_empty():
		return 1.0
	var c := float(Game.vehicle_def().engine)
	c *= 1.0 + 0.2 * Mods.level("engine_tune")
	c += 10.0 * Mods.level("suspension") + 7.0 * Mods.level("offroad_wheels")
	var eng: Dictionary = Game.s.rooms[Data.ENGINE_SLOT] if Game.s.rooms.size() > 0 else {}
	if not eng.is_empty():
		c += 4.0 * float(int(eng.level) - 1)
		c += 3.0 * Game.room_workers(Data.ENGINE_SLOT).size()
	c += float(Combat.van_stats().get("speed", 0.0)) * 0.2
	return c


func load_ratio() -> float:
	return weight() / maxf(1.0, capacity())


## 1.0 up to 80% load, then drops: 100% -> 0.85, 130% -> 0.55, floor 0.35. Off-road wheels add grip.
func speed_mult() -> float:
	if Game.s.is_empty():
		return 1.0
	var r := load_ratio()
	var m := 1.0
	if r > 0.8:
		m = clampf(1.0 - (r - 0.8) * 0.75, 0.35, 1.0)
	m *= 1.0 + 0.04 * Mods.level("offroad_wheels")
	if float(Game.s.res.get("fuel", 0.0)) <= 0.0:
		m *= 0.5          # out of fuel: crawling on battery
	return m


func fuel_pm() -> float:
	if Game.s.is_empty():
		return 0.0
	var r := load_ratio()
	var over := 1.0 if r <= 1.0 else 1.0 + (r - 1.0) * 2.0
	return weight() * FUEL_PER_TON * over


func status_text() -> String:
	var r := load_ratio()
	if r > 1.15:
		return "น้ำหนักเกินมาก! รถช้าและกินน้ำมันหนัก — อัปเกรดเครื่อง/ช่วงล่าง/ล้อ"
	if r > 1.0:
		return "น้ำหนักเกิน — ความเร็วลดลง"
	if r > 0.8:
		return "ใกล้เต็มพิกัด"
	return "สมดุลดี"
