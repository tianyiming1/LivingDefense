# M2-A：程序音效（步兵样例）。Headless 自动静音。
extends Node

const _Synth = preload("res://scripts/audio_synth.gd")

var _rng := RandomNumberGenerator.new()
var _streams: Dictionary = {}
var _last_play_ms: Dictionary = {}
const COOLDOWN_MS := 45

func _ready() -> void:
	_rng.randomize()
	_cache_streams()
	_ensure_buses()

func _headless() -> bool:
	return DisplayServer.get_name() == "headless"

func play(event_id: String, _world_pos: Vector2 = Vector2.ZERO, pitch_scale: float = 1.0) -> void:
	if _headless():
		return
	var now := Time.get_ticks_msec()
	if _last_play_ms.has(event_id) and now - int(_last_play_ms[event_id]) < COOLDOWN_MS:
		return
	_last_play_ms[event_id] = now
	if not _streams.has(event_id):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[event_id]
	p.bus = "SFX"
	p.pitch_scale = pitch_scale * _rng.randf_range(0.96, 1.04)
	p.volume_db = -4.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _ensure_buses() -> void:
	if _headless():
		return
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")

func _cache_streams() -> void:
	_streams["foot_armor"] = _make_tone(140.0, 0.07, "square", 0.22)
	_streams["foot_light"] = _make_tone(180.0, 0.05, "triangle", 0.18)
	_streams["foot_creature"] = _make_tone(110.0, 0.08, "square", 0.2)
	_streams["sword_swish"] = _make_swish()
	_streams["ranged_shot"] = _make_tone(420.0, 0.06, "square", 0.28)
	_streams["impact_med"] = _make_tone(95.0, 0.11, "square", 0.35)
	_streams["impact_light"] = _make_tone(160.0, 0.07, "triangle", 0.25)
	_streams["impact_heavy"] = _make_tone(70.0, 0.14, "square", 0.4)
	_streams["fly_whoosh"] = _make_swish()
	_streams["charge_release"] = _make_tone(280.0, 0.1, "triangle", 0.3)
	_streams["crystal_clink"] = _make_tone(520.0, 0.05, "triangle", 0.22)
	_streams["spore_idle"] = _make_tone(220.0, 0.04, "sine", 0.12)
	_streams["spore_pop"] = _make_tone(340.0, 0.05, "triangle", 0.2)
	_streams["aura_tick"] = _make_tone(300.0, 0.03, "sine", 0.15)
	_streams["lightning_crack"] = _make_lightning()
	_streams["death"] = _make_tone(120.0, 0.15, "square", 0.28)
	_streams["death_heavy"] = _make_tone(70.0, 0.2, "square", 0.35)
	_streams["death_runner"] = _make_tone(200.0, 0.1, "triangle", 0.22)

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
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

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
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

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
