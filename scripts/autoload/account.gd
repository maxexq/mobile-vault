extends Node
## Persistent player account (MV-114 / MV-159, design: docs/design/persistent_account.md).
## The save on disk / in the cloud is an envelope {v: 2, account: {...}, main: {...vehicle...}}.
##  * `a` = the account: lives forever, survives every Next Generation (meta = research points, perks,
##    blueprints; logbook lore; memorial; tutorial; difficulty setting; room for events, skill tree, places)
##  * Game.s = the active vehicle (one generation's run), exactly as before
##  * a.pid = the owner's short public player id (Cloud.player_id, MV-115), written on every save once known
## The account keys in SHARED are also put into Game.s as references to the same Dictionary / Array, so code
## that reads Game.s.meta or Game.s.lore keeps working; save() stores them once, in the account.
## A save without "v" is a v1 save (one dictionary per run) and is migrated on load.

const V := 2
## account data that the rest of the game reads through Game.s.<key>
const SHARED := ["meta", "lore", "memorial", "tutorial"]

var a: Dictionary = {}


func _ready() -> void:
	Save.wiped.connect(func(): a = {})


func diff() -> String:
	return str(a.get("settings", {}).get("diff", "normal"))


## the rules of the main vehicle: always standard, at the player's difficulty
func main_mode() -> Dictionary:
	var md := Modes.make("standard", diff())
	md.started_at = float(a.get("created_at", Cloud.now()))
	return md


## difficulty is a setting of the account (not ranked), changeable any time
func set_diff(d: String) -> void:
	if not Modes.DIFFS.has(d):
		return
	_ensure()
	a.settings.diff = d
	if not Game.s.is_empty():
		Game.s.mode = main_mode()
		Modes.apply()
	Trace.rec("meta", "difficulty", {"diff": d})


func _ensure() -> void:
	if a.is_empty():
		a = {"created_at": Cloud.now()}
	for k in ["settings", "events", "tree", "life"]:
		if not a.get(k) is Dictionary:
			a[k] = {}
	if not a.get("places") is Array:
		a["places"] = []
	if not a.settings.has("diff"):
		a.settings["diff"] = "normal"


## simulated seconds over the account's whole life (online + offline catch-up). The server compares how much
## this grew between two uploads with how much real time passed (MV-174, 0006_anticheat.sql), so it can never
## grow faster than the clock without the save being flagged.
func add_sim_time(dt: float) -> void:
	var life = a.get("life")
	if life is Dictionary:
		life["sim_sec"] = float(life.get("sim_sec", 0.0)) + dt


## put the account's shared data into a vehicle (load, new game, next generation)
func attach(veh: Dictionary) -> void:
	_ensure()
	for k in SHARED:
		if a.has(k):
			veh[k] = a[k]


## take the shared keys from a vehicle into the account (whatever object the vehicle holds now, e.g. a
## logbook list Lore created after the load)
func collect(veh: Dictionary) -> void:
	_ensure()
	for k in SHARED:
		if veh.has(k):
			a[k] = veh[k]


## envelope for Save.write: the account once, the vehicle without the shared keys
func envelope(veh: Dictionary) -> Dictionary:
	collect(veh)
	# the save carries its owner's public id (MV-115) so an exported / pasted save can be traced to a player
	var pid := Cloud.player_id()
	if pid != "":
		a["pid"] = pid
	var main := {}
	for k in veh:
		if not SHARED.has(k):
			main[k] = veh[k]
	return {"v": V, "account": a, "main": main}


## save from disk / cloud -> {account, main}; v1 saves are migrated (see migrate_v1)
func unwrap(d: Dictionary) -> Dictionary:
	if d.is_empty():
		return {}
	if int(d.get("v", 1)) >= 2:
		return {"account": d.get("account", {}) if d.get("account") is Dictionary else {},
			"main": d.get("main", {}) if d.get("main") is Dictionary else {}}
	return migrate_v1(d.duplicate(true))


## v1 = one run per save, picked with mode / difficulty / mutators on NEW RUN. Everything is kept: the run
## becomes the main vehicle of a new account, peaceful / mutators turn into a standard run and the picked
## difficulty becomes the account setting.
func migrate_v1(s: Dictionary) -> Dictionary:
	var old: Dictionary = s.get("mode", {}) if s.get("mode") is Dictionary else {}
	var acc := {"created_at": float(old.get("started_at", s.get("saved_at", 0.0))), "settings": {}, "events": {},
		"tree": {}, "life": {}, "places": []}
	for k in SHARED:
		if s.has(k):
			acc[k] = s[k]
			s.erase(k)
	var d := str(old.get("diff", "normal"))
	acc.settings["diff"] = d if Modes.DIFFS.has(d) else "normal"
	if str(old.get("id", "standard")) != "standard" or not (old.get("mut", []) as Array).is_empty():
		acc["legacy_mode"] = old      # kept for support; the player gets a one-time notice
	s.mode = {"id": "standard", "diff": acc.settings.diff, "mut": [], "started_at": acc.created_at}
	return {"account": acc, "main": s}


## a one-time toast for runs that were peaceful / had mutators before the account
func take_mode_notice() -> bool:
	if not a.has("legacy_mode") or bool(a.get("seen", {}).get("mode_notice", false)):
		return false
	if not a.get("seen") is Dictionary:
		a["seen"] = {}
	a.seen["mode_notice"] = true
	return true


## settings / conflict rows: the vehicle and account of any save (v1 or v2) without migrating it
func vehicle_of(d: Dictionary) -> Dictionary:
	return d.get("main", {}) if int(d.get("v", 1)) >= 2 and d.get("main") is Dictionary else d


func account_of(d: Dictionary) -> Dictionary:
	return d.get("account", {}) if int(d.get("v", 1)) >= 2 and d.get("account") is Dictionary else d
