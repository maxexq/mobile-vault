extends Node
## Room synergy: what a room's direct neighbours (left / right on the same floor, above / below in the same
## column, same unit only) do to it. Positive pairs speed things up, bad neighbours cost output or morale.
##   engine + quarters  -> crew in the quarters can't sleep (morale -10)
##   engine + workshop  -> maintenance +15% (hull repair) and workshop +15%
##   kitchen + hydroponics / water -> kitchen +10% each
##   hydroponics + water -> hydroponics +15%
##   medical + quarters -> medical +10%, quarters morale +5
##   science + radio -> both +10%      science + medical -> medical +10%
##   refinery + engine -> refinery +15%    refinery + quarters / kitchen -> fumes (morale -8 / kitchen -10%)
##   radio + engine -> radio -15% (interference)    armory + workshop -> armory +15%

## [room, neighbour] -> {mult (production of `room`), happy (morale of crew living/working in `room`), th}
const RULES := {
	"quarters|engine": {"happy": -10.0, "th": "เสียงเครื่องยนต์ดัง พักผ่อนไม่เต็มที่"},
	"engine|workshop": {"mult": 0.15, "repair": 0.15, "th": "ซ่อมบำรุงเร็วขึ้น 15%"},
	"workshop|engine": {"mult": 0.15, "th": "ช่างอยู่ติดห้องเครื่อง +15%"},
	"kitchen|hydroponics": {"mult": 0.10, "th": "ผักสดส่งตรงถึงครัว +10%"},
	"kitchen|water": {"mult": 0.10, "th": "น้ำสะอาดใกล้มือ +10%"},
	"hydroponics|water": {"mult": 0.15, "th": "รดน้ำสะดวก +15%"},
	"medical|quarters": {"mult": 0.10, "th": "คนไข้พักใกล้หมอ +10%"},
	"quarters|medical": {"happy": 5.0, "th": "อุ่นใจมีหมออยู่ข้างห้อง"},
	"science|radio": {"mult": 0.10, "th": "แลกข้อมูลกับวิทยุ +10%"},
	"radio|science": {"mult": 0.10, "th": "นักวิทย์ช่วยถอดรหัส +10%"},
	"medical|science": {"mult": 0.10, "th": "ห้องแล็บช่วยวิจัยยา +10%"},
	"refinery|engine": {"mult": 0.15, "th": "ท่อน้ำมันสั้น +15%"},
	"quarters|refinery": {"happy": -8.0, "th": "ไอน้ำมันเหม็น นอนไม่หลับ"},
	"kitchen|refinery": {"mult": -0.10, "th": "ไอน้ำมันปนอาหาร -10%"},
	"radio|engine": {"mult": -0.15, "th": "คลื่นรบกวนจากเครื่องยนต์ -15%"},
	"armory|workshop": {"mult": 0.15, "th": "โรงช่างช่วยประกอบอาวุธ +15%"},
}


## v4.4: a large room touches everything around all of its cells; neighbours are reported once per room
## (by their anchor cell), so a 3-wide kitchen under a 3-wide hydroponics still counts as one pairing.
func neighbours(slot: int) -> Array:
	var out := []
	if Game.s.is_empty() or not Game.has_room(slot) or slot < 0:
		return out
	# v4.6: the cab's engine room touches the bottom-left cell of the body (slot 0)
	if slot == Data.CAB_SLOT:
		return [Game.room_anchor(Data.ENGINE_SLOT)] if Game.s.rooms.size() > Data.ENGINE_SLOT else out
	var cells := Game.room_cells(slot)
	var own := Game.room_anchor(slot)
	var unit := Game.slot_unit(slot)
	for c in cells:
		var cell := Game.slot_cell(c)
		for other in Game.s.rooms.size():
			if other in cells or Game.slot_unit(other) != unit:
				continue
			var oc := Game.slot_cell(other)
			if absi(oc.x - cell.x) + absi(oc.y - cell.y) == 1:
				var a := Game.room_anchor(other)
				if a != own and not a in out:
					out.append(a)
	if Data.ENGINE_SLOT in cells:
		out.append(Data.CAB_SLOT)
	return out


## list of {other, type, th, mult, happy, repair} that apply to `slot` (for the UI and the maths)
func effects(slot: int) -> Array:
	var out := []
	if not Game.has_room(slot):
		return out
	var t: String = Game.room(slot).type
	if t == "empty" or t == "annex" or Game.is_site(slot):
		return out
	for o in neighbours(slot):
		if not Game.is_slot_unlocked(o) or Game.is_site(o):
			continue
		var ot: String = Game.room(o).type
		var key := "%s|%s" % [t, ot]
		if RULES.has(key):
			var r: Dictionary = RULES[key]
			out.append({"other": o, "type": ot, "th": r.th, "mult": float(r.get("mult", 0.0)),
				"happy": float(r.get("happy", 0.0)), "repair": float(r.get("repair", 0.0))})
	return out


func room_mult(slot: int) -> float:
	var m := 1.0
	for e in effects(slot):
		m += float(e.mult)
	return maxf(0.3, m)


func happy_mod(slot: int) -> float:
	var h := 0.0
	for e in effects(slot):
		h += float(e.happy)
	return h


func repair_bonus() -> float:
	return 1.0 + (0.0 if Game.s.is_empty() else _sum("repair", Data.CAB_SLOT))


func _sum(k: String, slot: int) -> float:
	var v := 0.0
	for e in effects(slot):
		v += float(e[k])
	return v


## preview for build placement: what would `room_type` get at `slot`, and what would it do to the neighbours
func preview(slot: int, room_type: String) -> Dictionary:
	var good := 0
	var bad := 0
	for o in neighbours(slot):
		var ot: String = Game.room(o).type
		for key in ["%s|%s" % [room_type, ot], "%s|%s" % [ot, room_type]]:
			if RULES.has(key):
				var r: Dictionary = RULES[key]
				if float(r.get("mult", 0.0)) + float(r.get("happy", 0.0)) > 0.0:
					good += 1
				else:
					bad += 1
	return {"good": good, "bad": bad}
