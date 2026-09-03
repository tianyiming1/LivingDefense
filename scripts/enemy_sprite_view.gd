# 敌人 3/4 侧视精灵
extends Node2D

var _sprite: Sprite2D
var _shadow: Sprite2D
var _base_scale := 0.48
var _facing_right := true
var _enemy_id := 0
var walk_phase := 0.0
var _last_foot := 0.0
var attack_left := 0.0
var _moving := false

func setup(tex: Texture2D, enemy_id: int) -> void:
	_enemy_id = enemy_id
	_base_scale = 0.50
	if enemy_id == 1:
		_base_scale = 0.44
	elif enemy_id == 2:
		_base_scale = 0.58
	elif enemy_id == 3:
		_base_scale = 0.64
	z_index = 2
	if _shadow == null:
		_shadow = Sprite2D.new()
		_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_shadow)
		move_child(_shadow, 0)
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
	_sprite.texture = tex
	_shadow.texture = tex
	_sprite.offset = UnitSprites.foot_offset(tex)
	_shadow.offset = _sprite.offset
	_apply_facing_scale()
	_apply_shadow()

func has_sprite() -> bool:
	return _sprite != null and _sprite.texture != null

func set_facing_toward(world_pos: Vector2) -> void:
	var dir: Vector2 = world_pos - global_position
	if absf(dir.x) > 0.3:
		_facing_right = dir.x >= 0.0
		_apply_facing_scale()

func set_moving(m: bool) -> void:
	_moving = m

func play_bite() -> void:
	attack_left = 0.18
	var sfx: String = "impact_med"
	if _enemy_id == 1:
		sfx = "impact_light"
	elif _enemy_id == 2:
		sfx = "impact_heavy"
	AudioController.play(sfx, global_position)

func play_hit() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(1.4, 1.2, 1.2, 1.0)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.12)

func play_death() -> void:
	var sfx := "death"
	if _enemy_id == 1:
		sfx = "death_runner"
	elif _enemy_id == 2 or _enemy_id == 3:
		sfx = "death_heavy"
	AudioController.play(sfx, global_position, 0.85 if _enemy_id >= 2 else 1.0)

func _process(delta: float) -> void:
	if attack_left > 0.0:
		attack_left -= delta
		var p := 1.0 - clampf(attack_left / 0.18, 0.0, 1.0)
		var sign: float = 1.0 if _facing_right else -1.0
		_sprite.position = Vector2(sign * sin(p * PI) * 5.0, 0)
	if _moving:
		var spd: float = 14.0
		if _enemy_id == 1:
			spd = 14.0
		elif _enemy_id == 2:
			spd = 6.0
		else:
			spd = 9.0
		walk_phase += delta * spd
		var bob: float = 2.0
		if _enemy_id == 2:
			bob = 1.0
		_sprite.position.y = sin(walk_phase) * bob
		var foot: float = floorf(walk_phase / PI)
		if foot > _last_foot:
			_last_foot = foot
			var f: String = "foot_creature"
			if _enemy_id == 1:
				f = "fly_whoosh"
			var vol: float = 0.9
			if _enemy_id == 1:
				vol = 1.2
			AudioController.play(f, global_position, vol)
	elif attack_left <= 0.0:
		_sprite.position = Vector2.ZERO

func _apply_facing_scale() -> void:
	if _sprite == null:
		return
	_sprite.scale = Vector2(_base_scale if _facing_right else -_base_scale, _base_scale)
	_apply_shadow()

func _apply_shadow() -> void:
	if _shadow == null or _sprite == null:
		return
	var s: float = absf(_sprite.scale.x)
	_shadow.scale = Vector2(s * 0.85, s * 0.22)
	_shadow.modulate = Color(0, 0, 0, 0.35)
	_shadow.position = Vector2(0, 4)
	_shadow.z_index = -1
	_sprite.z_index = 1
	_sprite.visible = true
	_shadow.visible = true
