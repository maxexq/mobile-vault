extends Node
## Threat director (v4.5): enemies come because something drew them in, not on a timer.
## THREAT (0-100) builds up from engine noise, lit / noisy rooms, night, biome, cargo and fresh blood;
## storms and fog mask it. When the roll fires the road goes through a cycle:
##   quiet (no enemies, roadside scavenging) -> warning (a few seconds of signs) -> raid (3-5 waves
##   back to back) -> salvage (search the bodies) -> quiet.
## Raid kills pay more so XP / scrap / gear per hour stay close to the old non-stop waves: the bonus is
## TARGET_PAY / (share of time spent fighting), measured over the last ~15 min, so it holds for strong
## squads (short raids) and weak ones (long raids) alike.
## Settings "pacing" = "classic" switches back to the old Taskbar-Hero style continuous waves.
## Pure simulation, driven by Combat.tick(); the HUD reads phase / threat / rate_parts().

signal phase_changed(phase: String)

const ROLL_EVERY := 5.0          # seconds between raid rolls while quiet
const ROLL_K := 0.30             # chance per roll = ROLL_K * ((threat - ROLL_FLOOR) / (100 - ROLL_FLOOR))^2
const ROLL_FLOOR := 15.0
const RATE_SCALE := 2.2          # all sources x this (per minute)
const MIN_QUIET := 25.0          # a raid never follows another one sooner than this
const WARN_SEC := 8.0
const SALVAGE_SEC := 10.0
const RAID_GAP := 1.8            # pause between the waves of one raid
const AFTER_RAID := 0.35         # threat kept after a raid is beaten
const AFTER_WIPE := 0.5
const TARGET_PAY := 0.75         # raid pay x fight share = this x classic (salvage + scavenging on top)
const MULT_MIN := 1.2
const MULT_MAX := 4.0
const SHARE_TAU := 900.0         # seconds: how fast the measured fight share follows play
const SALVAGE_SHARE := 0.15     # salvage scrap = raid scrap x this
const SALVAGE_ITEM := 0.3        # chance of one extra gear roll from the bodies
const SCAV_EVERY := 30.0         # roadside scavenging while driving quietly

## per-minute threat from rooms, per level. NOISE always, LIGHT mostly at night
const NOISE := {"workshop": 0.4, "refinery": 0.4, "engine": 0.3, "armory": 0.2, "radio": 0.2}
const LIGHT := {"hydroponics": 0.4, "science": 0.2, "medical": 0.2, "quarters": 0.1}
## weather that hides the vault (multiplies the whole rate)
const MASK := {"storm": 0.6, "fog": 0.6, "sandstorm": 0.5, "snow": 0.8, "rain": 0.85, "ashfall": 0.8}

const PHASE_TH := {"quiet": "เดินทางเงียบ", "warning": "มีสัญญาณ!", "raid": "ถูกบุก", "salvage": "เก็บกวาดซาก"}
const SIGNS := [
	"พบรอยเท้าสดๆ ข้างทาง… มีอะไรตามมา",
	"เสียงหอนดังมาจากเนินเขา",
	"ไฟฉายวูบวาบบนสันเขา มีคนเห็นเราแล้ว",
	"ฝูงนกแตกตื่นบินขึ้นด้านหลังรถ",
	"วิทยุจับเสียงรบกวนใกล้ๆ",
	"กลิ่นเหม็นเน่าลอยมากับลม",
]

var phase := "quiet"
var phase_t := 0.0          # time left in warning / salvage, time spent in quiet
var raid_left := 0          # waves still to come in this raid
var _gap := 0.0
var _roll_t := 0.0
var _scav_t := 0.0
var _blood := 0.0
var _raid_kills := 0
var _raid_time := 0.0
var _raid_scrap := 0.0
var _last_sign := -1
var rng := RandomNumberGenerator.new()
var stats := {"kill_scrap": 0.0, "salvage": 0.0, "scavenge": 0.0}   # this session, for the balance check


func _ready() -> void:
	rng.randomize()
	Game.game_started.connect(reset)


func classic() -> bool:
	return str(Settings.get_value("pacing")) == "classic"


func threat() -> float:
	if Game.s.is_empty():
		return 0.0
	return float(Game.s.combat.get("threat", 0.0))


func _set_threat(v: float) -> void:
	Game.s.combat.threat = clampf(v, 0.0, 100.0)


func reset() -> void:
	_set_phase("quiet")
	raid_left = 0
	_gap = 0.0
	_roll_t = 0.0
	_blood = 0.0


func _set_phase(p: String) -> void:
	phase = p
	phase_t = 0.0
	phase_changed.emit(p)


## sources of threat per minute, already scaled; "mask" is the weather multiplier
func rate_parts() -> Dictionary:
	var p := {"biome": 0.0, "engine": 0.0, "parked": 0.0, "night": 0.0, "rooms": 0.0, "cargo": 0.0, "blood": 0.0, "mask": 1.0}
	if Game.s.is_empty():
		return p
	var night := Game.is_night()
	p.biome = 1.0 + float(Data.biome(int(Game.s.biome)).get("danger", 1))
	if Game.is_moving():
		p.engine = 0.12 * Game.speed_kmh()
	else:
		p.parked = 2.0
	if night:
		p.night = 3.0
	var rooms := 0.0
	for slot in Game.s.rooms.size():
		var r: Dictionary = Game.s.rooms[slot]
		if r.type == "empty" or Game.is_site(slot) or not Game.is_slot_unlocked(slot):
			continue
		var lv := float(r.get("level", 1)) * Game.room_span(slot)   # a knocked-through room is as loud as its cells
		rooms += float(NOISE.get(r.type, 0.0)) * lv
		rooms += float(LIGHT.get(r.type, 0.0)) * lv * (2.0 if night else 0.25)
	p.rooms = rooms
	p.cargo = 4.0 * clampf((Haul.load_ratio() - 0.7) / 0.3, 0.0, 1.0) if Game.trailers() > 0 else 0.0
	p.blood = _blood
	p.mask = float(MASK.get(str(Game.s.get("weather", "clear")), 1.0))
	for k in ["biome", "engine", "parked", "night", "rooms", "cargo", "blood"]:
		p[k] = float(p[k]) * Features.num("threat.rate_scale", RATE_SCALE)
	return p


func rate_pm() -> float:
	var p := rate_parts()
	var t := 0.0
	for k in ["biome", "engine", "parked", "night", "rooms", "cargo", "blood"]:
		t += float(p[k])
	return t * float(p.mask)


func raid_chance() -> float:
	var x := clampf((threat() - ROLL_FLOOR) / (100.0 - ROLL_FLOOR), 0.0, 1.0)
	return 1.0 if threat() >= 99.9 else Features.num("threat.roll_k", ROLL_K) * x * x


## called every combat step; returns true when Combat should start a wave now
func tick(dt: float) -> bool:
	_blood = maxf(0.0, _blood - _blood * dt / 180.0)
	if classic():
		return false
	var wave_active: bool = Combat.wave_active
	var sh := fight_share()
	Game.s.combat.fight_share = sh + ((1.0 if wave_active else 0.0) - sh) * dt / SHARE_TAU
	if wave_active:
		if phase == "raid":
			_raid_time += dt
		return false
	if Combat.warlord_due():
		# the checkpoint warlord does not wait for noise: the blockade is right in front of us
		_start_raid(1, false)
		return true
	if not Features.on("raids"):
		# raids switched off: a quiet road (the warlord above still blocks the checkpoint)
		if phase != "quiet":
			_set_phase("quiet")
		raid_left = 0
		_set_threat(0.0)
		return false
	match phase:
		"quiet":
			phase_t += dt
			_set_threat(threat() + rate_pm() * dt / 60.0)
			if Game.is_moving():
				_scav_t += dt
				if _scav_t >= SCAV_EVERY:
					_scav_t = 0.0
					_scavenge()
			_roll_t += dt
			if _roll_t >= ROLL_EVERY:
				_roll_t = 0.0
				if phase_t >= Features.num("threat.min_quiet", MIN_QUIET) and rng.randf() < raid_chance():
					_warn()
		"warning":
			phase_t += dt
			_set_threat(threat() + rate_pm() * dt / 60.0)
			if phase_t >= WARN_SEC:
				var n := 3 + (1 if threat() >= 60.0 else 0) + (1 if threat() >= 85.0 else 0)
				_start_raid(n, true)
				return true
		"raid":
			if raid_left > 0:
				_gap -= dt
				if _gap <= 0.0:
					raid_left -= 1
					return true
			else:
				_end_raid()
		"salvage":
			phase_t += dt
			if phase_t >= SALVAGE_SEC:
				_set_phase("quiet")
	return false


func _warn() -> void:
	_set_phase("warning")
	var i := rng.randi() % SIGNS.size()
	if i == _last_sign:
		i = (i + 1) % SIGNS.size()
	_last_sign = i
	Game.toast.emit("%s (%d วิ)" % [SIGNS[i], int(WARN_SEC)], "warn")
	Trace.rec("threat", "warning", {"threat": snappedf(threat(), 0.1)})


## n waves in this raid, the first one starts right away
func _start_raid(n: int, counted: bool) -> void:
	_set_phase("raid")
	raid_left = n - 1
	_gap = RAID_GAP
	_raid_kills = 0
	_raid_time = 0.0
	_raid_scrap = 0.0
	if counted:
		Game.toast.emit("ถูกบุก! ศัตรู %d ระลอก" % n, "bad")
	Trace.rec("threat", "raid", {"waves": n, "threat": snappedf(threat(), 0.1)})


## Combat: a wave of this raid was cleared
func on_wave_cleared() -> void:
	if classic():
		return
	if phase != "raid":
		# a wave started by the god panel / tests outside a raid: just go back to quiet
		_set_phase("quiet")
		return
	_gap = RAID_GAP


func on_wipe() -> void:
	if classic() or phase != "raid":
		return
	raid_left = 0
	_set_threat(threat() * AFTER_WIPE)
	_record_kpm()
	_set_phase("quiet")


func on_kill(scrap: float) -> void:
	_blood = minf(_blood + 0.4, 10.0)
	stats.kill_scrap += scrap
	if phase == "raid":
		_raid_kills += 1
		_raid_scrap += scrap


func _end_raid() -> void:
	_set_threat(threat() * AFTER_RAID)
	_record_kpm()
	var scrap := _raid_scrap * SALVAGE_SHARE
	if scrap > 0.0:
		Game._add_res("scrap", scrap)
		stats.salvage += scrap
	var txt := "เก็บกวาดซาก: +%d เศษเหล็ก" % int(scrap)
	if _raid_kills > 0 and rng.randf() < SALVAGE_ITEM:
		var item := Loot.roll_random(Combat.enemy_level(), 0.0, 0)
		if Loot.add_to_stash(item):
			Game.gear_changed.emit()
			txt += " · %s" % Loot.item_name(item)
	Game.toast.emit(txt, "good")
	Trace.rec("threat", "salvage", {"kills": _raid_kills, "scrap": int(scrap)})
	_set_phase("salvage")


func _record_kpm() -> void:
	if _raid_time < 5.0 or _raid_kills <= 0:
		return
	var kpm := float(_raid_kills) / (_raid_time / 60.0)
	var old := float(Game.s.combat.get("raid_kpm", 0.0))
	Game.s.combat.raid_kpm = kpm if old <= 0.0 else lerpf(old, kpm, 0.4)


func _scavenge() -> void:
	var L := float(Combat.enemy_level())
	Game._add_res("scrap", 0.3 + L * 0.12)
	stats.scavenge += 0.3 + L * 0.12


## god panel / tests: skip straight to the warning signs
func force_warning() -> void:
	if classic() or Combat.wave_active:
		return
	_set_threat(maxf(threat(), 60.0))
	_warn()


## god panel / tests: a raid of n waves starts on the next combat step (no warning)
func force_raid(n: int = 2) -> void:
	if classic() or Combat.wave_active:
		return
	_start_raid(n, true)
	raid_left = n
	_gap = 0.0


## share of combat time spent fighting with threat pacing (starts at a typical 0.3)
func fight_share() -> float:
	if Game.s.is_empty():
		return 0.3
	return clampf(float(Game.s.combat.get("fight_share", 0.3)), 0.05, 1.0)


func reward_mult() -> float:
	return 1.0 if classic() else clampf(TARGET_PAY / fight_share(), MULT_MIN, MULT_MAX)


## offline: kills per minute to pay while the game was closed
func offline_kpm(classic_kpm: float) -> float:
	if classic():
		return classic_kpm
	var k := float(Game.s.combat.get("raid_kpm", 0.0))
	if k <= 0.0:
		k = maxf(classic_kpm, 4.0)
	return minf(k, 30.0) * fight_share() * reward_mult()
