extends Node
## Per-survivor skill tree: 3 branches x 5 nodes. 1 point per level (from Lv.2) + legacy bonus.
## Each node has ranks; `val(d, key)` sums the effect of everything a survivor has learned.

## key: what the node feeds (read by val()), per: value per rank, req: any of these must have >= 1 rank
const TREE := {
	"combat": {"th": "ต่อสู้", "en": "COMBAT", "col": "f0644a", "nodes": ["c1", "c2", "c3", "c4", "c5"]},
	"survival": {"th": "เอาตัวรอด", "en": "SURVIVAL", "col": "5fae70", "nodes": ["s1", "s2", "s3", "s4", "s5"]},
	"craft": {"th": "ช่าง & ผลิต", "en": "CRAFT", "col": "ffcc6a", "nodes": ["p1", "p2", "p3", "p4", "p5"]},
}
const NODES := {
	"c1": {"th": "เล็งนิ่ง", "en": "STEADY AIM", "icon": "rifle", "max": 3, "key": "dmg", "per": 0.08, "req": [], "desc": "ดาเมจ +8%/ระดับ"},
	"c2": {"th": "หนังหนา", "en": "THICK SKIN", "icon": "armor", "max": 3, "key": "hp", "per": 0.10, "req": [], "desc": "HP +10%/ระดับ"},
	"c3": {"th": "ว่องไว", "en": "SWIFT STRIKES", "icon": "agi", "max": 3, "key": "aspd", "per": 0.06, "req": ["c1"], "desc": "ความเร็วโจมตี +6%/ระดับ"},
	"c4": {"th": "หลบหลีก", "en": "EVASION", "icon": "dodge", "max": 2, "key": "dodge", "per": 4.0, "req": ["c2"], "desc": "หลบหลีก +4%/ระดับ"},
	"c5": {"th": "ท่าไม้ตาย", "en": "SIGNATURE MOVE", "icon": "crown", "max": 1, "key": "signature", "per": 1.0, "req": ["c3", "c4"], "desc": "สกิลประจำตำแหน่งแรงขึ้น 40% และคูลดาวน์ -20%"},
	"s1": {"th": "กระเพาะเหล็ก", "en": "IRON STOMACH", "icon": "food", "max": 2, "key": "stomach", "per": 0.15, "req": [], "desc": "กินอาหาร/น้ำ -15%/ระดับ"},
	"s2": {"th": "ภูมิต้านรังสี", "en": "RAD TOLERANCE", "icon": "rad", "max": 2, "key": "radres", "per": 0.25, "req": [], "desc": "รับรังสี -25%/ระดับ"},
	"s3": {"th": "ตาเหยี่ยว", "en": "SCAVENGER EYE", "icon": "explore", "max": 3, "key": "scav", "per": 0.10, "req": [], "desc": "ของจากการสำรวจ +10%/ระดับ"},
	"s4": {"th": "รักษาไว", "en": "FAST HEALER", "icon": "heal", "max": 2, "key": "medic", "per": 0.15, "req": ["s2"], "desc": "ฮีล/หายติดเชื้อเร็วขึ้น +15% · ติดเชื้อยากขึ้น"},
	"s5": {"th": "ผู้รอดชีวิต", "en": "SURVIVOR", "icon": "skull", "max": 1, "key": "survivor", "per": 1.0, "req": ["s3", "s4"], "desc": "สำรวจสำเร็จ +20% · โอกาสตายลด 60%"},
	"p1": {"th": "ขยัน", "en": "DILIGENT", "icon": "hammer", "max": 3, "key": "prod", "per": 0.08, "req": [], "desc": "ผลผลิตในห้อง +8%/ระดับ"},
	"p2": {"th": "นักประดิษฐ์", "en": "TINKERER", "icon": "gear", "max": 3, "key": "craft", "per": 0.10, "req": [], "desc": "ความเร็วการผลิต +10%/ระดับ"},
	"p3": {"th": "พี่เลี้ยง", "en": "MENTOR", "icon": "people", "max": 2, "key": "mentor", "per": 0.05, "req": ["p1"], "desc": "เพื่อนร่วมห้องผลิต +5%/ระดับ · XP เพื่อน +10%"},
	"p4": {"th": "ช่างซ่อม", "en": "HANDYMAN", "icon": "wrench", "max": 2, "key": "repair", "per": 1.0, "req": ["p2"], "desc": "ซ่อมตัวถัง +1/นาที/ระดับ เมื่ออยู่ห้องเครื่อง/โรงช่าง"},
	"p5": {"th": "ปรมาจารย์", "en": "MASTER", "icon": "xp", "max": 1, "key": "master", "per": 1.0, "req": ["p3", "p4"], "desc": "โบนัสนิสัยที่ตรงกับห้องเพิ่มเป็น 2 เท่า"},
}


func ranks(d: Dictionary) -> Dictionary:
	if not d.has("skills"):
		d["skills"] = {}
	return d.skills


func rank(d: Dictionary, node: String) -> int:
	return int(ranks(d).get(node, 0))


func points_total(d: Dictionary) -> int:
	return maxi(0, int(d.lvl) - 1) + 2 * Meta.perk("skill_spark")


func points_spent(d: Dictionary) -> int:
	var n := 0
	for k in ranks(d):
		n += int(ranks(d)[k])
	return n


func points_free(d: Dictionary) -> int:
	return points_total(d) - points_spent(d)


func can_learn(d: Dictionary, node: String) -> bool:
	var nd: Dictionary = NODES[node]
	if rank(d, node) >= int(nd.max) or points_free(d) <= 0:
		return false
	if (nd.req as Array).is_empty():
		return true
	for r in nd.req:
		if rank(d, r) > 0:
			return true
	return false


func learn(d: Dictionary, node: String) -> bool:
	if not can_learn(d, node):
		return false
	ranks(d)[node] = rank(d, node) + 1
	Game.dwellers_changed.emit()
	return true


func respec_cost(d: Dictionary) -> int:
	return 30 * int(d.lvl)


func respec(d: Dictionary) -> bool:
	if points_spent(d) == 0 or not Game.pay({"scrap": respec_cost(d)}):
		return false
	d.skills = {}
	Game.dwellers_changed.emit()
	return true


## summed effect of every learned node feeding `key`
func val(d: Dictionary, key: String) -> float:
	var v := 0.0
	var r := ranks(d)
	for n in r:
		var nd: Dictionary = NODES.get(n, {})
		if nd.get("key", "") == key:
			v += float(nd.per) * int(r[n])
	return v


## short build label shown on cards, e.g. "ต่อสู้ 5 · ช่าง 2"
func build_label(d: Dictionary) -> String:
	var parts := []
	for b in TREE:
		var n := 0
		for node in TREE[b].nodes:
			n += rank(d, node)
		if n > 0:
			parts.append("%s %d" % [TREE[b].th, n])
	return " · ".join(parts)
