extends Node
## Sound (MV-536): ambience beds, weather layers and sound effects, all synthesised in-repo by tools/gen_audio.py
## (assets/audio/amb|weather|sfx|ui/*.wav, imported as QOA).
##  - beds: one looping player per biome (Data.BIOMES id) + the engine, bus "Ambience"
##  - weather: one looping player per Data.WEATHER id that has a sound (clear has none), bus "Ambience";
##    a storm also rolls thunder every audio.thunder_gap seconds
##  - every layer fades its own gain toward a target (audio.fade_sec), so a biome or weather change crossfades
##  - sfx(id) on bus "SFX" from a small voice pool, ui(id) on bus "UI"; every BaseButton in the tree taps
##    (meta "sfx" picks another sound, "" = silent)
## Browsers only allow sound after a tap, so on the web nothing plays until the first input (unlocked).
##  - music: the cozy lo-fi title theme on bus "Music" while the title screen shows (switch audio_bgm)
## Switches: audio_ambience (beds + weather), audio_sfx (effects + UI), audio_bgm (title music).
## Volumes: Settings master / music / ambience / sfx / ui.

const AMB_DIR := "res://assets/audio/amb/"
const WEATHER_DIR := "res://assets/audio/weather/"
const SFX_DIR := "res://assets/audio/sfx/"
const UI_DIR := "res://assets/audio/ui/"
const MUSIC_DIR := "res://assets/audio/music/"
const MUSIC := ["title_lofi"]      # title-screen BGM, cozy lo-fi (bus "Music", switch audio_bgm)
const WEATHER_SOUNDS := ["overcast", "rain", "storm", "sandstorm", "snow", "fog", "acid_rain", "ashfall"]
const SFX := ["thunder_1", "thunder_2", "shot", "shot_heavy", "shot_energy", "hit", "hit_crit", "hit_metal", "hit_hero",
	"enemy_die", "heal", "skill", "boss_roar", "alarm", "build", "build_done", "demolish", "loot", "loot_rare",
	"engine_start", "engine_stall", "radio", "depart", "return", "checkpoint", "knock", "wreck", "toast_good", "toast_bad"]
const UI := ["tap", "confirm", "cancel", "open"]
## GOD MODE preview groups (Dev.sound_group)
const GROUPS := {
	"combat": ["shot", "shot_heavy", "shot_energy", "hit", "hit_crit", "hit_metal", "hit_hero", "enemy_die", "heal", "skill"],
	"boss": ["alarm", "boss_roar"],
	"build": ["build", "build_done", "demolish"],
	"loot": ["loot", "loot_rare"],
	"engine": ["engine_start", "engine_stall"],
	"road": ["radio", "knock", "checkpoint", "wreck", "thunder_1", "thunder_2"],
	"expedition": ["depart", "return"],
	"ui": ["tap", "confirm", "cancel", "open", "toast_good", "toast_bad"],
}
## per-sound level (dB) so the set sits together; the files are loudness-matched only roughly
## (MV-536 ear check: the bright and signal-like sounds sit lower so they never sting)
const TRIM := {
	"engine": -9.0, "alarm": -12.0, "toast_bad": -10.0, "toast_good": -9.0, "shot": -7.0, "shot_heavy": -5.0,
	"shot_energy": -11.0, "hit": -7.0, "hit_crit": -6.0, "hit_metal": -7.0, "hit_hero": -7.0, "enemy_die": -7.0,
	"heal": -10.0, "skill": -8.0, "loot": -8.0, "loot_rare": -3.0, "radio": -4.0, "tap": -14.0, "confirm": -11.0,
	"cancel": -11.0, "open": -13.0, "knock": -2.0, "thunder_1": -2.0, "thunder_2": -2.0,
}
const SFX_VOICES := 10
const UI_VOICES := 3
const PER_SOUND_MAX := 3      # one sound id playing at most this many times at once

## default tunables (Features.TUNE "audio.*" can change them remotely)
const FADE_SEC := 3.0
const BED_GAIN := 1.0
const WEATHER_GAIN := 1.0
const ENGINE_GAIN := 0.8
const THUNDER_GAP := 22.0
const SFX_GAP := 0.06
const IDLE_PITCH := 0.72
const BGM_GAIN := 1.0

var unlocked := false
var layers := {}             # id -> {"p": AudioStreamPlayer, "cur": float, "target": float, "pitch": float}
var played := {}             # sound id -> times started (autotest / GOD readout)
var last_sfx := ""
var preview := {}            # GOD: {"bed": id} / {"weather": id} overrides what the game asks for
var _streams := {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _ui_i := 0
var _last_at := {}           # sound id -> ticks msec of its last start
var _fast_fade := 0.0        # seconds left of a quick fade (instant biome change)
var _thunder_in := 8.0
var _engine_state := ""
var _at_checkpoint := false
var _strangers := 0
var _poll := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	unlocked = not OS.has_feature("web")
	for i in SFX_VOICES:
		_sfx_pool.append(_player("SFX"))
	for i in UI_VOICES:
		_ui_pool.append(_player("UI"))
	get_tree().node_added.connect(_on_node_added)
	Game.biome_changed.connect(func(_i: int, instant: bool):
		if instant:
			_fast_fade = 0.6
		_refresh())
	Game.weather_changed.connect(func(_w: String): _refresh())
	Game.game_started.connect(_refresh)
	Game.construction_started.connect(func(_s: int, _k: String): sfx("build"))
	Game.construction_finished.connect(func(_s: int, _k: String): sfx("build_done"))
	Game.event_triggered.connect(func(_id: String): sfx("radio"))
	Game.toast.connect(_on_toast)
	Combat.shot.connect(_on_shot)
	Combat.hit.connect(_on_hit)
	Combat.enemy_removed.connect(func(_id: int, killed: bool):
		if killed:
			sfx("enemy_die", 0.12))
	Combat.skill_cast.connect(func(_s: int, _k: String): sfx("skill"))
	Combat.loot_dropped.connect(func(item: Dictionary, _at: Vector2): sfx("loot_rare" if int(item.get("rar", 0)) >= 3 else "loot"))
	Combat.supply_found.connect(func(_k: String, _a: float, _at: Vector2): sfx("loot"))
	Combat.entrance.connect(func(_e: Dictionary):
		sfx("alarm")
		sfx("boss_roar", 0.0))
	Combat.boss_event.connect(func(kind: String, _e: Dictionary):
		if kind == "enrage":
			sfx("boss_roar", 0.05))
	Expedition.expedition_started.connect(func(): sfx("depart"))
	Expedition.expedition_finished.connect(func(_r: Dictionary): sfx("return"))
	Inspection.queue_changed.connect(_on_strangers)
	Meta.wrecked.connect(func(): sfx("wreck"))
	Features.changed.connect(_refresh)


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


# =================================================================== queries
func ambience_on() -> bool:
	return Features.on("audio_ambience")


func sfx_on() -> bool:
	return Features.on("audio_sfx")


func stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path := _path(id)
	var st: AudioStream = load(path) if path != "" and ResourceLoader.exists(path) else null
	if st is AudioStreamWAV and _is_loop(id) and st.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		# the 'smpl' chunk normally sets this on import; a re-import without it must not stop the bed
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = int(st.get_length() * st.mix_rate)
	_streams[id] = st
	return st


func _path(id: String) -> String:
	if id == "engine" or Data.BIOMES.any(func(b): return b.id == id):
		return AMB_DIR + id + ".wav"
	if id in WEATHER_SOUNDS:
		return WEATHER_DIR + id + ".wav"
	if id in SFX:
		return SFX_DIR + id + ".wav"
	if id in UI:
		return UI_DIR + id + ".wav"
	if id in MUSIC:
		return MUSIC_DIR + id + ".wav"
	return ""


func _is_loop(id: String) -> bool:
	return _path(id).begins_with(AMB_DIR) or id in WEATHER_SOUNDS or id in MUSIC


## every sound id the game can play (autotest checks each one loads)
func all_ids() -> Array:
	var out: Array = ["engine"]
	for b in Data.BIOMES:
		out.append(b.id)
	return out + WEATHER_SOUNDS + SFX + UI + MUSIC


func bgm_on() -> bool:
	return Features.on("audio_bgm")


## the music the game wants right now: the lo-fi theme on the title screen, nothing in a run ("" = none)
func want_bgm() -> String:
	if preview.has("bgm"):
		return str(preview.bgm)
	if not preview.is_empty() or Game.started:
		return ""
	return MUSIC[0]


func layer(id: String) -> Dictionary:
	return layers.get(id, {"cur": 0.0, "target": 0.0, "playing": false})


func is_playing(id: String) -> bool:
	return layers.has(id) and bool(layers[id].on)


## the bed / weather the game wants right now ("" = none)
func want_bed() -> String:
	if preview.has("bed"):
		return str(preview.bed)
	if Game.s.is_empty():
		return Data.BIOMES[0].id
	return str(Data.biome(int(Game.s.biome)).id)


func want_weather() -> String:
	if preview.has("weather"):
		return str(preview.weather)
	if preview.has("bed"):
		return ""         # a bed preview plays alone
	if not Game.started or Game.s.is_empty():
		return ""
	var w := str(Game.s.get("weather", "clear"))
	return w if w in WEATHER_SOUNDS else ""


# =================================================================== layers
func _refresh() -> void:
	var amb := ambience_on() and unlocked
	var bed := want_bed()
	var weather := want_weather()
	var targets := {}
	var bgm := want_bgm() if bgm_on() and unlocked else ""
	for m in MUSIC:
		targets[m] = Features.num("audio.bgm_gain", BGM_GAIN) if m == bgm else 0.0
	# on the title the biome bed sits quietly under the music
	var title_bed := 0.3 if bgm != "" else 0.6
	for b in Data.BIOMES:
		targets[b.id] = Features.num("audio.bed_gain", BED_GAIN) * (1.0 if Game.started or preview.has("bed") else title_bed) if amb and b.id == bed else 0.0
	for w in WEATHER_SOUNDS:
		targets[w] = Features.num("audio.weather_gain", WEATHER_GAIN) if amb and w == weather else 0.0
	targets["engine"] = _engine_target() if amb else 0.0
	for id in targets:
		_set_target(id, targets[id])


func _engine_target() -> float:
	if not Game.started or Game.s.is_empty() or preview.has("bed") or preview.has("weather"):
		return 0.0
	var st := _engine_now()
	if st == "off":
		return 0.0
	var g := Features.num("audio.engine_gain", ENGINE_GAIN)
	return g if st == "run" else g * 0.6


## run (driving) | idle (parked, ticking over) | off (rested / broken / stalled / wrecked)
func _engine_now() -> String:
	if not Game.started or Game.s.is_empty():
		return "off"
	if EngineBay.on():
		var k := EngineBay.state_key()
		if k == "broken" or EngineBay.resting():
			return "off"
		return "run" if Game.is_moving() else "idle"
	return "run" if Game.is_moving() else "idle"


func _set_target(id: String, t: float) -> void:
	if t <= 0.0 and not layers.has(id):
		return
	if not layers.has(id):
		var st := stream(id)
		if st == null:
			return
		var p := _player("Music" if id in MUSIC else "Ambience")
		# the web build plays through browser samples by default, and those drop the loop (the bed stopped at the
		# end of the file and restarted from the same spot); Godot's own mixer loops it (MV-536 web fix)
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		p.stream = st
		p.volume_db = -80.0
		# "on" is ours, not p.playing, so a bed is started once and never re-triggered by a stale `playing`;
		# finished re-arms a loop that really ended (a re-import without the loop chunk).
		layers[id] = {"p": p, "cur": 0.0, "target": 0.0, "pitch": 1.0, "on": false}
		p.finished.connect(func():
			if layers[id].on:
				p.play())
	layers[id].target = t


func _process(dt: float) -> void:
	_poll -= dt
	if _poll <= 0.0:
		_poll = 0.25
		_watch()
		_refresh()
	var fade := 0.6 if _fast_fade > 0.0 else Features.num("audio.fade_sec", FADE_SEC)
	_fast_fade = maxf(0.0, _fast_fade - dt)
	var step := dt / maxf(0.05, fade)
	for id in layers:
		var L: Dictionary = layers[id]
		L.cur = move_toward(float(L.cur), float(L.target), step)
		var p: AudioStreamPlayer = L.p
		if L.cur <= 0.001 and L.target <= 0.0:
			if L.on:
				L.on = false
				p.stop()
			continue
		if id == "engine":
			L.pitch = move_toward(float(L.pitch), 1.0 if _engine_now() == "run" else IDLE_PITCH, dt * 0.4)
			p.pitch_scale = float(L.pitch)
		p.volume_db = linear_to_db(maxf(0.0001, float(L.cur))) + float(TRIM.get(id, 0.0))
		if not L.on:
			# start beds at a random spot so two loops of the same length don't line up
			L.on = true
			p.play(randf() * maxf(0.0, p.stream.get_length() - 0.5))
	_thunder(dt)


## edges the game has no signal for: engine start / stall, arriving at a checkpoint
func _watch() -> void:
	var st := _engine_now()
	if _engine_state != "" and Game.started:
		if _engine_state == "off" and st != "off":
			sfx("engine_start")
		elif _engine_state != "off" and st == "off" and not Meta.is_wrecked():
			sfx("engine_stall")
	_engine_state = st
	var cp := Game.started and not Game.s.is_empty() and Game.at_checkpoint()
	if cp and not _at_checkpoint:
		sfx("checkpoint")
	_at_checkpoint = cp


func _thunder(dt: float) -> void:
	if want_weather() != "storm" or not ambience_on() or not unlocked:
		return
	_thunder_in -= dt
	if _thunder_in > 0.0:
		return
	var gap := Features.num("audio.thunder_gap", THUNDER_GAP)
	_thunder_in = randf_range(gap * 0.5, gap * 1.5)
	var p := _voice(_sfx_pool, "thunder")
	_start(p, "thunder_1" if randf() < 0.6 else "thunder_2", "Ambience", randf_range(0.85, 1.1))


# =================================================================== effects
## plays a sound effect; spread = random pitch +- (0 = exact)
func sfx(id: String, spread: float = 0.06) -> bool:
	if not sfx_on() or not unlocked or not _ready_for(id):
		return false
	var p := _voice(_sfx_pool, id)
	return _start(p, id, "SFX", 1.0 + randf_range(-spread, spread))


func ui(id: String) -> bool:
	if not sfx_on() or not unlocked or not _ready_for(id):
		return false
	return _start(_voice(_ui_pool, id), id, "UI", 1.0)


func _ready_for(id: String) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_last_at.get(id, -100000)) < int(Features.num("audio.sfx_gap", SFX_GAP) * 1000.0):
		return false
	var busy := 0
	for p in _sfx_pool + _ui_pool:
		if p.playing and p.get_meta("id", "") == id:
			busy += 1
	return busy < PER_SOUND_MAX


func _voice(pool: Array[AudioStreamPlayer], _id: String) -> AudioStreamPlayer:
	if pool == _sfx_pool:
		_sfx_i = (_sfx_i + 1) % pool.size()
		for k in pool.size():          # a free voice first, else the oldest one is cut
			var p: AudioStreamPlayer = pool[(_sfx_i + k) % pool.size()]
			if not p.playing:
				return p
		return pool[_sfx_i]
	_ui_i = (_ui_i + 1) % pool.size()
	return pool[_ui_i]


func _start(p: AudioStreamPlayer, id: String, bus: String, pitch: float) -> bool:
	var st := stream(id)
	if st == null:
		return false
	p.stream = st
	p.bus = bus
	p.pitch_scale = pitch
	p.volume_db = float(TRIM.get(id, 0.0))
	p.set_meta("id", id)
	p.play()
	_last_at[id] = Time.get_ticks_msec()
	played[id] = int(played.get(id, 0)) + 1
	last_sfx = id
	return true


func _on_toast(_text: String, kind: String) -> void:
	match kind:
		"good":
			sfx("toast_good", 0.0)
		"bad", "warn":
			if Time.get_ticks_msec() - int(_last_at.get("toast_bad", -100000)) > 1500:
				sfx("toast_bad", 0.0)


func _on_shot(from_kind: String, _from_id: int, _to_kind: String, _to_id: int, style: String) -> void:
	match style:
		"bullet":
			sfx("shot")
		"turret":
			sfx("shot_heavy")
		"acid", "enemy":
			if from_kind == "enemy" and randf() < 0.35:
				sfx("shot_energy", 0.15)


func _on_hit(kind: String, _id: int, _amount: float, crit: bool) -> void:
	match kind:
		"enemy":
			sfx("hit_crit" if crit else "hit", 0.1)
		"van":
			sfx("hit_metal", 0.1)
		"hero":
			sfx("hit_hero", 0.1)
		"heal":
			sfx("heal", 0.0)


func _on_strangers() -> void:
	var count := Inspection.queue().size()
	if count > _strangers:
		sfx("knock", 0.03)
	_strangers = count


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("sfx_hooked"):
		n.set_meta("sfx_hooked", true)
		n.pressed.connect(func():
			var id := str(n.get_meta("sfx", "tap"))
			if id != "":
				ui(id))


func _input(event: InputEvent) -> void:
	if unlocked:
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		unlocked = true
		_refresh()


# =================================================================== GOD MODE previews
func preview_bed(id: String) -> void:
	preview = {"bed": id}
	_fast_fade = 0.6
	_refresh()


func preview_weather(id: String) -> void:
	preview = {"bed": want_bed(), "weather": id}
	_fast_fade = 0.6
	_refresh()


func preview_bgm() -> void:
	preview = {"bgm": MUSIC[0]}
	_fast_fade = 0.6
	_refresh()


func preview_clear() -> void:
	preview = {}
	_refresh()


## plays every sound of a GROUPS entry one after another
func play_group(group: String) -> void:
	var ids: Array = GROUPS.get(group, [])
	for i in ids.size():
		get_tree().create_timer(0.7 * i).timeout.connect(func():
			var id: String = ids[i]
			if id in UI:
				ui(id)
			else:
				sfx(id, 0.0))
