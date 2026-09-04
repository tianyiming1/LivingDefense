# 天气系统（叠加层，不修改 map.gd / 单位逻辑）
# 阶段：M3-B 视觉 → M4 可选玩法挂钩（减速/视野/雷击伤害）
extends CanvasLayer

enum WeatherType { CLEAR, RAIN, WIND, SNOW, STORM, LIGHTNING }

signal weather_changed(kind: WeatherType)

@export var current: WeatherType = WeatherType.CLEAR

var _rain: GPUParticles2D
var _snow: GPUParticles2D
var _wind_streaks: ColorRect
var _flash: ColorRect
var _ambient_tint: ColorRect
var _lightning_cd := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	layer = 15
	_rng.randomize()
	_build_layers()
	set_weather(current)

func set_weather(kind: WeatherType) -> void:
	current = kind
	_apply_visibility(kind)
	weather_changed.emit(kind)

func _apply_visibility(kind: WeatherType) -> void:
	var rain_on := kind in [WeatherType.RAIN, WeatherType.STORM]
	var snow_on := kind == WeatherType.SNOW
	var wind_on := kind in [WeatherType.WIND, WeatherType.STORM]
	_rain.emitting = rain_on
	_snow.emitting = snow_on
	_wind_streaks.visible = wind_on
	match kind:
		WeatherType.CLEAR:
			_ambient_tint.color = Color(1, 1, 1, 0)
		WeatherType.RAIN:
			_ambient_tint.color = Color(0.75, 0.82, 0.95, 0.12)
		WeatherType.SNOW:
			_ambient_tint.color = Color(0.9, 0.95, 1.0, 0.18)
		WeatherType.WIND:
			_ambient_tint.color = Color(0.95, 0.92, 0.85, 0.06)
		WeatherType.STORM:
			_ambient_tint.color = Color(0.55, 0.6, 0.75, 0.22)
		WeatherType.LIGHTNING:
			_ambient_tint.color = Color(0.5, 0.55, 0.7, 0.25)

func _process(delta: float) -> void:
	if current not in [WeatherType.STORM, WeatherType.LIGHTNING]:
		return
	_lightning_cd -= delta
	if _lightning_cd <= 0.0:
		_lightning_cd = _rng.randf_range(4.0, 9.0)
		_trigger_lightning()

func _trigger_lightning() -> void:
	_flash.modulate.a = 0.85
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", 0.0, 0.18)
	if AudioController:
		AudioController.play("lightning_crack", Vector2.ZERO, _rng.randf_range(0.9, 1.1))

func _build_layers() -> void:
	_ambient_tint = ColorRect.new()
	_ambient_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ambient_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ambient_tint)

	_wind_streaks = ColorRect.new()
	_wind_streaks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wind_streaks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wind_streaks.visible = false
	add_child(_wind_streaks)

	_rain = _make_particles(Color(0.7, 0.8, 1.0, 0.55), 900, Vector2(0, 520), 12.0)
	add_child(_rain)
	_snow = _make_particles(Color(1, 1, 1, 0.75), 350, Vector2(40, 80), 4.0)
	add_child(_snow)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(0.92, 0.95, 1.0, 1.0)
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

func _make_particles(col: Color, amount: int, vel: Vector2, lifetime: float) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.explosiveness = 0.0
	p.randomness = 0.4
	p.visibility_rect = Rect2(-100, -100, Config.MAP_SIZE.x + 200, Config.MAP_SIZE.y + 200)
	p.position = Config.MAP_SIZE * 0.5
	p.process_material = _particle_mat(col, vel, lifetime)
	return p

func _particle_mat(col: Color, vel: Vector2, lifetime: float) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(vel.x, vel.y, 0).normalized()
	m.spread = 8.0
	m.initial_velocity_min = vel.length() * 0.85
	m.initial_velocity_max = vel.length() * 1.15
	m.gravity = Vector3.ZERO
	m.scale_min = 1.0
	m.scale_max = 2.5
	m.color = col
	m.lifetime_randomness = 0.3
	return m
