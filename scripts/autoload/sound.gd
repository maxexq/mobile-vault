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
##  - MV-555 (switch audio_clean): a loop is played by two players that take turns, overlapping over the file's
##    LOOP_TAIL (the cycle's first seconds repeated after its end, identical audio, so the crossfade is exact). The web
##    build then keeps every loop on browser samples; MV-536 forced them onto Godot's mixer, which a single-threaded
##    web build runs on the main thread, and every frame hitch underran it (the hiss / crackle). A hard limiter sits
##    on Master for whatever Godot mixes itself.
##  - MV-555 cues (switch audio_cues): resources in, road event good / bad, expedition out / encounter / home / failed /
##    haul unpacked
## Switches: audio_ambience (beds + weather), audio_sfx (effects + UI), audio_bgm (title music), audio_clean, audio_cues.
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
	"engine_start", "engine_stall", "radio", "depart", "return", "checkpoint", "knock", "wreck", "toast_good", "toast_bad",
	"res_gain", "event_good", "event_bad", "exp_start", "exp_encounter", "exp_home", "exp_fail", "exp_loot"]
## MV-555 cue sounds (switch audio_cues, level audio.cue_gain); a cue keeps the toast that comes with it quiet
const CUES := ["res_gain", "event_good", "event_bad", "exp_start", "exp_encounter", "exp_home", "exp_fail", "exp_loot"]
const UI := ["tap", "confirm", "cancel", "open"]
## GOD MODE preview groups (Dev.sound_group)
const GROUPS := {
	"combat": ["shot", "shot_heavy", "shot_energy", "hit", "hit_crit", "hit_metal", "hit_hero", "enemy_die", "heal", "skill"],
	"boss": ["alarm", "boss_roar"],
	"build": ["build", "build_done", "demolish"],
	"loot": ["loot", "loot_rare"],
	"engine": ["engine_start", "engine_stall"],
	"road": ["radio", "knock", "checkpoint", "wreck", "thunder_1", "thunder_2"],
	"expedition": ["exp_start", "exp_encounter", "exp_home", "exp_loot", "exp_fail", "depart", "return"],
	"events": ["res_gain", "event_good", "event_bad", "radio"],
	"ui": ["tap", "confirm", "cancel", "open", "toast_good", "toast_bad"],
}
## per-sound level (dB) so the set sits together; the files are loudness-matched only roughly
## (MV-536 ear check: the bright and signal-like sounds sit lower so they never sting)
const TRIM := {
	"engine": -9.0, "alarm": -12.0, "toast_bad": -10.0, "toast_good": -9.0, "shot": -7.0, "shot_heavy": -5.0,
	"shot_energy": -11.0, "hit": -7.0, "hit_crit": -6.0, "hit_metal": -7.0, "hit_hero": -7.0, "enemy_die": -7.0,
	"heal": -10.0, "skill": -8.0, "loot": -8.0, "loot_rare": -3.0, "radio": -4.0, "tap": -14.0, "confirm": -11.0,
	"cancel": -11.0, "open": -13.0, "knock": -2.0, "thunder_1": -2.0, "thunder_2": -2.0,
	"res_gain": -15.0, "event_good": -7.0, "event_bad": -6.0, "exp_start": -4.0, "exp_encounter": -6.0,
	"exp_home": -5.0, "exp_fail": -6.0, "exp_loot": -6.0,
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
## a GOD preview ends by itself after this long, so a forgotten one never plays over the game (MV-538)
const PREVIEW_SEC := 45.0
## MV-555: seconds of each loop file repeated after its cycle (tools/gen_audio.py LOOP_TAIL) = the A/B crossfade
const LOOP_TAIL := 0.5
const RES_GAP := 1.5          # resources-in plays at most this often (audio.res_gap)
const CUE_GAIN := 1.0
const LIMITER_DB := -1.0      # Master hard-limiter ceiling (audio.limiter_db)
const TOAST_HUSH_MS := 600    # a toast within this long of a cue stays quiet (the cue already said it)

var unlocked := false
var layers := {}             # id -> {"p": player now leading, "q": the other (clean mode), "cur", "target", "pitch",
                             #        "pos": seconds into the cycle of p, "xf": seconds into a handover (-1 = none)}
var played := {}             # sound id -> times started (autotest / GOD readout)
var last_sfx := ""
var preview := {}            # GOD: {"bed": id} / {"weather": id} overrides what the game asks for
var preview_left := 0.0      # seconds until the preview ends (PREVIEW_SEC)
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
var _clean := false          # the loop mode the current layers were built for (audio_clean)
var _real_us := 0            # Time.get_ticks_usec of the last frame (loops run on real time, not Engine.time_scale)
var _cue_at := -100000       # ticks msec of the last cue (a toast right after it stays quiet)
var _toast := ""             # a toast sound waiting for the end of the frame
var _limiter: AudioEffectHardLimiter


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
	Expedition.expedition_started.connect(_on_expedition_started)
	Expedition.expedition_finished.connect(_on_expedition_finished)
	Encounter.encounter_ready.connect(func(_id: String): cue("exp_encounter"))   # the team found something
	Encounter.encounter_resolved.connect(func(_id: String, r: Dictionary): cue("event_good" if bool(r.get("ok", true)) else "event_bad"))
	Game.event_resolved.connect(_on_event_resolved)
	Game.floating_text.connect(_on_floating_text)
	Inspection.queue_changed.connect(_on_strangers)
	Meta.wrecked.connect(func(): sfx("wreck"))
	Features.changed.connect(_refresh)
	_real_us = Time.get_ticks_usec()
	_clean = clean_on()
	_limiter = AudioEffectHardLimiter.new()
	AudioServer.add_bus_effect(0, _limiter)
	_sync_limiter()


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


func clean_on() -> bool:
	return Features.on("audio_clean")


func cues_on() -> bool:
	return Features.on("audio_cues") and sfx_on()


## the Master limiter follows audio_clean and audio.limiter_db
func _sync_limiter() -> void:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) == _limiter:
			AudioServer.set_bus_effect_enabled(0, i, clean_on())
	_limiter.ceiling_db = Features.num("audio.limiter_db", LIMITER_DB)


func limiter_on() -> bool:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) == _limiter:
			return AudioServer.is_bus_effect_enabled(0, i)
	return false


func stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path := _path(id)
	var st: AudioStream = load(path) if path != "" and ResourceLoader.exists(path) else null
	if st is AudioStreamWAV and _is_loop(id):
		# MV-555: a loop file is its cycle + LOOP_TAIL; clean mode plays it once per turn (no loop, the next player
		# takes over), the MV-536 fallback loops a copy over the cycle alone
		st.loop_mode = AudioStreamWAV.LOOP_DISABLED
		var fb := st.duplicate() as AudioStreamWAV
		fb.loop_mode = AudioStreamWAV.LOOP_FORWARD
		fb.loop_begin = 0
		fb.loop_end = int(cycle_sec(id, st) * st.mix_rate)
		_streams[id + "#loop"] = fb
	_streams[id] = st
	return st


## the stream the MV-536 fallback loops (the cycle without the tail)
func loop_stream(id: String) -> AudioStream:
	stream(id)
	return _streams.get(id + "#loop")


## seconds of one loop cycle (the file minus its LOOP_TAIL)
func cycle_sec(id: String, st: AudioStream = null) -> float:
	st = st if st != null else stream(id)
	return maxf(0.5, st.get_length() - LOOP_TAIL) if st != null else 0.0


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
		var bus := "Music" if id in MUSIC else "Ambience"
		var p := _player(bus)
		p.volume_db = -80.0
		# "on" is ours, not p.playing, so a bed is started once and never re-triggered by a stale `playing`
		var L := {"p": p, "q": null, "cur": 0.0, "target": 0.0, "pitch": 1.0, "on": false, "pos": 0.0, "xf": -1.0}
		if _clean:
			# MV-555: both players keep the default playback type (browser samples on the web)
			p.stream = st
			var q := _player(bus)
			q.stream = st
			q.volume_db = -80.0
			L.q = q
		else:
			# MV-536 fallback: the web's sample playback drops the loop (it restarts from the play() offset after
			# an 'ended' gap), so Godot's own mixer loops it
			p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
			p.stream = loop_stream(id)
			# finished re-arms a loop that really ended
			p.finished.connect(func():
				if layers.has(id) and layers[id].on and not _clean:
					p.play())
		layers[id] = L
	layers[id].target = t


## audio_clean switched: every layer is rebuilt for the other loop mode (they fade back in)
func _rebuild_layers() -> void:
	for id in layers:
		for k in ["p", "q"]:
			if layers[id][k] != null:
				(layers[id][k] as AudioStreamPlayer).queue_free()
	layers.clear()
	_clean = clean_on()
	_sync_limiter()
	_refresh()


func _process(dt: float) -> void:
	var now_us := Time.get_ticks_usec()
	var real := clampf(float(now_us - _real_us) / 1000000.0, 0.0, 0.25)
	_real_us = now_us
	if _clean != clean_on():
		_rebuild_layers()
	_poll -= dt
	if _poll <= 0.0:
		_poll = 0.25
		_watch()
		_refresh()
		_sync_limiter()
	if not preview.is_empty():
		preview_left -= dt
		if preview_left <= 0.0:
			preview_clear()
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
				L.xf = -1.0
				p.stop()
				if L.q != null:
					(L.q as AudioStreamPlayer).stop()
			continue
		if id == "engine":
			L.pitch = move_toward(float(L.pitch), 1.0 if _engine_now() == "run" else IDLE_PITCH, dt * 0.4)
			p.pitch_scale = float(L.pitch)
			if L.q != null:
				(L.q as AudioStreamPlayer).pitch_scale = float(L.pitch)
		var db := linear_to_db(maxf(0.0001, float(L.cur))) + float(TRIM.get(id, 0.0))
		if not L.on:
			# start beds at a random spot so two loops of the same length don't line up
			L.on = true
			L.xf = -1.0
			L.pos = randf() * maxf(0.0, cycle_sec(id) - 0.5)
			p.play(float(L.pos))
		if L.q == null:
			p.volume_db = db
			continue
		_turn(id, L, real * float(L.pitch), db)
	_thunder(dt)
	if _toast != "":
		if Time.get_ticks_msec() - _cue_at > TOAST_HUSH_MS:
			sfx(_toast, 0.0)
		_toast = ""


## clean mode: the leading player p runs through its cycle; at the end the other player starts at the top and the
## two share the LOOP_TAIL (the same audio in both), p fading out as q fades in, then they swap roles
func _turn(id: String, L: Dictionary, adv: float, db: float) -> void:
	var p: AudioStreamPlayer = L.p
	var q: AudioStreamPlayer = L.q
	var cyc := cycle_sec(id)
	L.pos = float(L.pos) + adv
	if float(L.xf) < 0.0 and float(L.pos) >= cyc:
		# the handover: q starts where p's tail is now, so both play the same samples
		L.xf = float(L.pos) - cyc
		q.play(float(L.xf))
		L.p = q
		L.q = p
		L.pos = float(L.xf)
		p = L.p
		q = L.q
	elif float(L.xf) >= 0.0:
		L.xf = float(L.xf) + adv
	if float(L.xf) >= 0.0:
		var w := clampf(float(L.xf) / LOOP_TAIL, 0.0, 1.0)
		p.volume_db = db + linear_to_db(maxf(0.0001, w))
		q.volume_db = db + linear_to_db(maxf(0.0001, 1.0 - w))
		if w >= 1.0:
			L.xf = -1.0
			q.stop()
	else:
		p.volume_db = db


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


## MV-555: a toast's sound waits for the end of the frame, so a cue fired by the same moment (an expedition back,
## an encounter) speaks for it instead of both playing at once
func _on_toast(_text: String, kind: String) -> void:
	match kind:
		"good":
			_toast = "toast_good"
		"bad", "warn":
			if Time.get_ticks_msec() - int(_last_at.get("toast_bad", -100000)) > 1500:
				_toast = "toast_bad"


## MV-555: plays a cue sound when audio_cues is on (false = off or rate limited, the caller may fall back)
func cue(id: String, spread: float = 0.0, pitch: float = 1.0) -> bool:
	if not cues_on() or not unlocked or not _ready_for(id):
		return false
	var p := _voice(_sfx_pool, id)
	if not _start(p, id, "SFX", pitch * (1.0 + randf_range(-spread, spread))):
		return false
	p.volume_db += linear_to_db(maxf(0.0001, Features.num("audio.cue_gain", CUE_GAIN)))
	_cue_at = Time.get_ticks_msec()
	return true


## resources in: the "+N" a working room floats up, or a craft finishing. Rooms pay out all the time, so it is a
## quiet pluck at most every audio.res_gap seconds, its pitch stepping through a pentatonic scale
func _on_floating_text(_slot: int, text: String, icon: String) -> void:
	if not (text.begins_with("+") or (text == "DONE" and icon != "hammer")):
		return
	if Time.get_ticks_msec() - int(_last_at.get("res_gain", -100000)) < int(Features.num("audio.res_gap", RES_GAP) * 1000.0):
		return
	var semis: Array = [0, 2, 4, 7, 9]
	cue("res_gain", 0.0, pow(2.0, float(semis[randi() % semis.size()]) / 12.0))


func _on_event_resolved(_id: String, action: String, result: Dictionary) -> void:
	if action == "ignore":
		return              # driving on is neither a win nor a loss
	cue("event_good" if bool(result.get("ok", true)) else "event_bad")


func _on_expedition_started() -> void:
	if not cue("exp_start"):
		sfx("depart")


func _on_expedition_finished(rep: Dictionary) -> void:
	var ok := bool(rep.get("ok", false))
	if not cue("exp_home" if ok else "exp_fail"):
		sfx("return")
		return
	var haul := not (rep.get("gain", {}) as Dictionary).is_empty() or int(rep.get("gear", 0)) > 0
	if haul:
		# the haul comes off after the hatch closes
		get_tree().create_timer(1.4).timeout.connect(func(): cue("exp_loot"))


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
	preview_left = PREVIEW_SEC
	_fast_fade = 0.6
	_refresh()


func preview_weather(id: String) -> void:
	preview = {"bed": want_bed(), "weather": id}
	preview_left = PREVIEW_SEC
	_fast_fade = 0.6
	_refresh()


func preview_bgm() -> void:
	preview = {"bgm": MUSIC[0]}
	preview_left = PREVIEW_SEC
	_fast_fade = 0.6
	_refresh()


## back to what the game asks for; GodPanel calls this when it closes (MV-538: a weather preview, e.g. acid rain,
## used to keep playing over the industrial map after the panel was closed)
func preview_clear() -> void:
	preview = {}
	preview_left = 0.0
	_fast_fade = 0.6
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
