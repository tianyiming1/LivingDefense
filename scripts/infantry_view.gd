# 人族步兵像素视图：俯视走路 + 前冲挥砍（M2-A 样例）
extends Node2D

const TEX := preload("res://assets/pixels/human/human_infantry_idle_64.png")
const SPRITE_SCALE := 0.52
const ATTACK_DURATION := 0.27
const HIT_PHASE := 0.55

var _sprite: Sprite2D
var _shadow: Sprite2D
var state := "idle"
var walk_phase := 0.0
var attack_left := 0.0
var _hit_fired := false
var _on_hit: Callable = Callable()
var _last_foot_phase := 0.0

func _ready() -> void:
	z_index = 3
	_shadow = Sprite2D.new()
	_shadow.texture = TEX
	_shadow.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE) * 0.92
	_shadow.modulate = Color(0, 0, 0, 0.28)
	_shadow.position = Vector2(2, 3)
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

func has_sprite() -> bool:
	return _sprite != null and _sprite.texture != null

func is_attacking() -> bool:
	return state == "attack"

func set_moving(moving: bool) -> void:
	if state == "attack":
		return
	state = "walk" if moving else "idle"

func start_attack(on_hit: Callable) -> void:
	state = "attack"
	attack_left = ATTACK_DURATION
	_hit_fired = false
	_on_hit = on_hit
	AudioController.play("sword_swish", global_position)

func _process(delta: float) -> void:
	if state == "attack":
		_tick_attack(delta)
	elif state == "walk":
		_tick_walk(delta)
	else:
		_reset_pose()

func _reset_pose() -> void:
	_sprite.position = Vector2.ZERO
	_sprite.rotation = 0.0
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_shadow.position = Vector2(2, 3)
	_shadow.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE) * 0.92

func _tick_attack(delta: float) -> void:
	attack_left -= delta
	var p := 1.0 - clampf(attack_left / ATTACK_DURATION, 0.0, 1.0)
	var thrust := sin(p * PI)
	# 俯视挥砍：朝面向（本地 +X）前冲，不旋转整张图
	_sprite.position = Vector2(thrust * 7.0, -thrust * 1.5)
	_sprite.scale = Vector2(SPRITE_SCALE + thrust * 0.06, SPRITE_SCALE - thrust * 0.03)
	_shadow.position = Vector2(2 + thrust * 2.0, 3)
	if not _hit_fired and p >= HIT_PHASE:
		_hit_fired = true
		if _on_hit.is_valid():
			_on_hit.call()
		_on_hit = Callable()
		AudioController.play("impact_med", global_position)
	if attack_left <= 0.0:
		state = "idle"
		_reset_pose()

func _tick_walk(delta: float) -> void:
	walk_phase += delta * 10.0
	_sprite.position.y = sin(walk_phase) * 2.5
	_sprite.scale.y = SPRITE_SCALE + sin(walk_phase * 2.0) * 0.03
	_shadow.position.y = 3 + sin(walk_phase) * 1.0
	var foot := floor(walk_phase / PI)
	if foot > _last_foot_phase:
		_last_foot_phase = foot
		AudioController.play("foot_armor", global_position)
