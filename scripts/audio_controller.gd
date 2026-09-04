# M2-A / CO-ART-PROD-001 W1：程序音效 + 循环 BGM。Headless 自动静音。合规：零外部采样。
extends Node

const _Synth = preload("res://scripts/audio_synth.gd")

var _rng := RandomNumberGenerator.new()
var _streams: Dictionary = {}
var _last_play_ms: Dictionary = {}
const COOLDOWN_MS := 45

var _music: AudioStreamPlayer
var _bgm_mode: String = ""  # menu | planning | combat | ""

func _ready() -> void:
	_rng.randomize()
	_cache_streams()
	_ensure_buses()
	if not _headless():
		_music = AudioStreamPlayer.new()
		_music.name = "MusicPlayer"
		_music.bus = "Music"
		_music.volume_db = -16.0
		add_child(_music)

func _headless() -> bool:
	return DisplayServer.get_name() == "headless"

# ---------- 公共 API ----------
func play(event_id: String, _world_pos: Vector2 = Vector2.ZERO, pitch_scale: float = 1.0) -> void:
	if _headless():
		return
	var now := Time.get_ticks_msec()
	if _last_play_ms.has(event_id) and now - int(_last_play_ms[event_id]) < COOLDOWN_MS:
		return
	_last_play_ms[event_id] = now
	if not _streams.has(event_id):
		return
	var bus := "UI" if event_id.begins_with("ui") or event_id in ["win", "lose"] else "SFX"
	var p := AudioStreamPlayer.new()
	p.stream = _streams[event_id]
	p.bus = bus
	p.pitch_scale = pitch_scale * _rng.randf_range(0.96, 1.04)
	p.volume_db = -2.0 if bus == "UI" else -4.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func start_bgm(mode: String) -> void:
	if _headless() or _music == null:
		return
	if mode == _bgm_mode and _music.playing:
		return
	_bgm_mode = mode
	var key := "bgm_%s" % mode
	if not _streams.has(key):
		key = "bgm_planning"
	_music.stream = _streams[key]
	_music.volume_db = -18.0 if mode == "combat" else -16.0
	_music.play()

func stop_bgm() -> void:
	_bgm_mode = ""
	if _music != null and is_instance_valid(_music):
		_music.stop()

func set_bus_linear(bus_name: String, linear_01: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear_01, 0.0001, 1.0)))

# ---------- 总线 ----------
func _ensure_buses() -> void:
	if _headless():
		return
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("UI")

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")

# ---------- 缓存 ----------
func _cache_streams() -> void:
	_streams["foot_armor"] = _make_tone(140.0, 0.07, "square", 0.22)
	_streams["foot_light"] = _make_tone(180.0, 0.05, "triangle", 0.18)
	_streams["foot_creature"] = _make_tone(110.0, 0.08, "square", 0.2)
	_streams["sword_swish"] = _make_swish()
	_streams["ranged_shot"] = _make_tone(420.0, 0.06, "square", 0.28)
	_streams["ranged_boom"] = _make_boom()
	_streams["impact_med"] = _make_tone(95.0, 0.11, "square", 0.35)
	_streams["impact_light"] = _make_tone(160.0, 0.07, "triangle", 0.25)
	_streams["impact_heavy"] = _make_tone(70.0, 0.14, "square", 0.4)
	_streams["fly_whoosh"] = _make_swish()
	_streams["charge_up"] = _make_charge_up()
	_streams["charge_release"] = _make_tone(280.0, 0.1, "triangle", 0.3)
	_streams["crystal_clink"] = _make_tone(520.0, 0.05, "triangle", 0.22)
	_streams["spore_idle"] = _make_tone(220.0, 0.04, "sine", 0.12)
	_streams["spore_pop"] = _make_tone(340.0, 0.05, "triangle", 0.2)
	_streams["aura_tick"] = _make_tone(300.0, 0.03, "sine", 0.15)
	_streams["lightning_crack"] = _make_lightning()
	_streams["dragon_breath"] = _make_dragon_breath()
	_streams["death"] = _make_tone(120.0, 0.15, "square", 0.28)
	_streams["death_heavy"] = _make_tone(70.0, 0.2, "square", 0.35)
	_streams["death_runner"] = _make_tone(200.0, 0.1, "triangle", 0.22)
	_streams["heal_chime"] = _make_tone(660.0, 0.09, "sine", 0.28)
	_streams["sleep_chime"] = _make_two_tone(523.0, 392.0, 0.07, 0.24)
	_streams["arcane_cast"] = _make_arcane_cast()
	_streams["supply_tick"] = _make_tone(380.0, 0.06, "triangle", 0.22)
	_streams["wall_shatter"] = _make_lightning()
	# W1 核心事件
	_streams["spawn"] = _make_two_tone(220.0, 330.0, 0.12, 0.26)
	_streams["kill"] = _make_tone(180.0, 0.08, "square", 0.3)
	_streams["leak"] = _make_leak()
	_streams["upgrade"] = _make_two_tone(392.0, 523.0, 0.1, 0.28)
	_streams["ui"] = _make_tone(640.0, 0.03, "square", 0.2)
	_streams["win"] = _make_fanfare(true)
	_streams["lose"] = _make_fanfare(false)
	# BGM 循环（自有程序合成）
	_streams["bgm_menu"] = _make_bgm_loop(0)
	_streams["bgm_planning"] = _make_bgm_loop(1)
	_streams["bgm_combat"] = _make_bgm_loop(2)

# ---------- 合成器 ----------
func _make_dragon_breath() -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.38
	var n := int(rate * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env: float = _Synth.sfx_envelope(t, duration, 0.04, 0.45)
		var roar: float = _Synth.triangle(t * lerpf(90.0, 55.0, t / duration)) * 0.45
		var hiss: float = _Synth.noise(_rng) * 0.35
		var crack: float = _Synth.square(t * 40.0) * 0.15
		_write_sample(data, i, int(clampf((roar + hiss + crack) * env, -1.0, 1.0) * 30000.0))
	return _wav(data, rate)

func _make_lightning() -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.22
	var n := int(rate * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env: float = _Synth.sfx_envelope(t, duration, 0.01, 0.15)
		var s: float = _Synth.noise(_rng) * 0.7 + _Synth.square(t * 60.0) * 0.3
		_write_sample(data, i, int(clampf(s * env, -1.0, 1.0) * 30000.0))
	return _wav(data, rate)

func _make_boom() -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.18
	var n := int(rate * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env: float = _Synth.sfx_envelope(t, duration, 0.02, 0.55)
		var s: float = _Synth.noise(_rng) * 0.55 + _Synth.sine(t * lerpf(90.0, 40.0, t / duration)) * 0.45
		_write_sample(data, i, int(clampf(s * env, -1.0, 1.0) * 29000.0))
	return _wav(data, rate)

func _make_charge_up() -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.22
	var n := int(rate * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env: float = _Synth.sfx_envelope(t, duration, 0.15, 0.2)
		var freq := lerpf(180.0, 480.0, t / duration)
		var s: float = _Synth.sine(t * freq) * 0.55
		_write_sample(data, i, int(clampf(s * env, -1.0, 1.0) * 26000.0))
	return _wav(data, rate)

func _make_leak() -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.2
	var n := int(rate * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env: float = _Synth.sfx_envelope(t, duration, 0.05, 0.4)
		var freq := lerpf(280.0, 90.0, t / duration)
		var s: float = _Synth.square(t * freq) * 0.4 + _Synth.noise(_rng) * 0.25
		_write_sample(data, i, int(clampf(s * env, -1.0, 1.0) * 28000.0))
	return _wav(data, rate)

func _make_two_tone(f1: float, f2: float, half: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var duration := half * 2.0
	var n := int(rate * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env: float = _Synth.sfx_envelope(t, duration, 0.08, 0.35)
		var freq := f1 if t < half else f2
		var s: float = _Synth.triangle(t * freq) * vol
		_write_sample(data, i, int(clampf(s * env, -1.0, 1.0) * 30000.0))
	return _wav(data, rate)

func _make_fanfare(victory: bool) -> AudioStreamWAV:
	var rate := 22050
	var notes: Array = [392.0, 494.0, 587.0, 784.0] if victory else [330.0, 294.0, 247.0, 196.0]
	var step := 0.12
	var duration := step * float(notes.size())
	var n := int(rate * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var idx := mini(notes.size() - 1, int(t / step))
		var local_t := t - float(idx) * step
		var env: float = _Synth.sfx_envelope(local_t, step, 0.1, 0.45)
		var s: float = _Synth.triangle(t * float(notes[idx])) * (0.32 if victory else 0.28)
		_write_sample(data, i, int(clampf(s * env, -1.0, 1.0) * 28000.0))
	return _wav(data, rate)

func _make_tone(freq: float, duration: float, wave: String, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := maxi(1, int(rate * duration))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env: float = _Synth.sfx_envelope(t, duration, 0.05, 0.35)
		var phase := t * freq
		var s := 0.0
		match wave:
			"square":
				s = _Synth.square(phase)
			"triangle":
				s = _Synth.triangle(phase)
			_:
				s = _Synth.sine(phase)
		_write_sample(data, i, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	return _wav(data, rate)

func _make_arcane_cast() -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.16
	var n := int(rate * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env: float = _Synth.sfx_envelope(t, duration, 0.04, 0.35)
		var freq := lerpf(420.0, 620.0, t / duration)
		var s: float = _Synth.sine(t * freq) * 0.35 + _Synth.triangle(t * freq * 2.0) * 0.2
		_write_sample(data, i, int(clampf(s * env, -1.0, 1.0) * 26000.0))
	return _wav(data, rate)

func _make_swish() -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.09
	var n := int(rate * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env: float = _Synth.sfx_envelope(t, duration, 0.02, 0.5)
		var freq := lerpf(900.0, 220.0, t / duration)
		var s: float = _Synth.triangle(t * freq) * 0.55 + _Synth.noise(_rng) * 0.25
		_write_sample(data, i, int(clampf(s * env, -1.0, 1.0) * 28000.0))
	return _wav(data, rate)

## 几何剪影风循环：小调琶音 + 低频方波底。variant 0菜单 / 1规划 / 2战斗。
func _make_bgm_loop(variant: int) -> AudioStreamWAV:
	var rate := 22050
	var bpm := 96.0 if variant == 2 else 84.0
	var beat := 60.0 / bpm
	var bars := 4
	var beats_per_bar := 4
	var duration := beat * float(bars * beats_per_bar)
	var n := int(rate * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	# A 小调五声音阶（Hz）
	var scale: Array = [220.0, 261.63, 293.66, 329.63, 392.0, 440.0]
	var root := 110.0 if variant != 0 else 98.0
	for i in n:
		var t := float(i) / float(rate)
		var beat_f := t / beat
		var beat_i := int(beat_f)
		var note_idx := (beat_i * (2 if variant == 2 else 1) + variant) % scale.size()
		var freq: float = float(scale[note_idx])
		if variant == 2 and beat_i % 2 == 1:
			freq *= 1.5
		var local := fmod(t, beat)
		var note_env: float = clampf(1.0 - local / beat, 0.0, 1.0)
		note_env = pow(note_env, 0.55)
		var lead: float = _Synth.triangle(t * freq) * 0.16 * note_env
		var bass_env: float = 0.55 + 0.45 * sin(beat_f * TAU * 0.25)
		var bass: float = _Synth.square(t * root * (1.0 if beat_i % 4 < 2 else 1.5), 0.35) * 0.08 * bass_env
		var pad: float = _Synth.sine(t * (root * 2.0)) * 0.04
		if variant == 2:
			pad += _Synth.noise(_rng) * 0.008 * note_env
		var s: float = (lead + bass + pad) * 0.85
		_write_sample(data, i, int(clampf(s, -1.0, 1.0) * 22000.0))
	var stream := _wav(data, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = n
	return stream

func _wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

func _write_sample(data: PackedByteArray, i: int, v: int) -> void:
	var s := clampi(v, -32768, 32767)
	data[i * 2] = s & 0xFF
	data[i * 2 + 1] = (s >> 8) & 0xFF
