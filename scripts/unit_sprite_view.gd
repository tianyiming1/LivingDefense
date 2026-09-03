# 单位侧视精灵：DNF 风格待机/跑动/攻击分姿态（有分帧则切图，否则程序姿态）
extends Node2D

const ATTACK_DURATION := 0.48
const HIT_PHASE := 0.52
const AFTERIMAGE_LIFE := 0.18

var _sprite: Sprite2D
var _shadow: Sprite2D
var _base_scale := 0.62
var _facing_right := true
var _attack_mode := "melee"
var _stationary := false
var _race := ""
var _unit_id := -1
var _sfx: Dictionary = {}
var state := "idle"
var walk_phase := 0.0
var attack_left := 0.0
var _hit_fired := false
var _on_hit: Callable = Callable()
var _last_foot_phase := 0.0
var idle_phase := 0.0
var _base_tex: Texture2D = null
var _frames: Dictionary = {} # "idle"|"walk"|"attack" -> Array[Texture2D]
var _frame_t := 0.0
var _afterimages: Array = [] # {node, life}


func setup(tex: Texture2D, kind: String, radius: float, p_race: String, stationary: bool, unit_id: int = -1) -> void:
	_base_scale = UnitSprites.scale_for_radius(radius)
	_attack_mode = UnitSprites.attack_kind(kind)
	_stationary = stationary
	_race = p_race
	_unit_id = unit_id
	_sfx = UnitSprites.sfx_for_attack(kind, p_race)
	_base_tex = tex
	_frames = UnitSprites.load_anim_frames(p_race, unit_id)
	z_index = 3
	if _shadow == null:
		_shadow = Sprite2D.new()
		_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_shadow)
		move_child(_shadow, 0)
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
	_set_tex(tex)
	_apply_facing_scale()
	_apply_shadow()


func _set_tex(tex: Texture2D) -> void:
	if tex == null:
		return
	_sprite.texture = tex
	_shadow.texture = tex
	_sprite.offset = UnitSprites.foot_offset(tex)
	_shadow.offset = _sprite.offset


func has_sprite() -> bool:
	return _sprite != null and _sprite.texture != null


func is_attacking() -> bool:
	return state == "attack"


func facing_right() -> bool:
	return _facing_right


func set_facing_toward(world_pos: Vector2) -> void:
	var dir: Vector2 = world_pos - global_position
	if absf(dir.x) > 0.4:
		_facing_right = dir.x >= 0.0
		_apply_facing_scale()


func set_moving(moving: bool) -> void:
	if state == "attack" or _stationary:
		return
	var next := "walk" if moving else "idle"
	if state != next:
		state = next
		_frame_t = 0.0


func start_attack(on_hit: Callable) -> void:
	state = "attack"
	attack_left = ATTACK_DURATION if _is_dnf_style() else 0.27
	_hit_fired = false
	_on_hit = on_hit
	_frame_t = 0.0
	var wind: String = str(_sfx.get("wind", "sword_swish"))
	if wind != "":
		AudioController.play(wind, global_position)


func start_shoot() -> void:
	state = "attack"
	attack_left = 0.22 if _is_dnf_style() else 0.16
	_hit_fired = true
	_on_hit = Callable()
	_frame_t = 0.0
	var wind: String = str(_sfx.get("wind", "ranged_shot"))
	if wind != "":
		AudioController.play(wind, global_position)


func _is_dnf_style() -> bool:
	return _race == "dragon" or _frames.size() > 0


func _process(delta: float) -> void:
	_tick_afterimages(delta)
	if state == "attack":
		_tick_attack(delta)
	elif state == "walk":
		_tick_walk(delta)
	elif _stationary:
		_tick_idle_pulse(delta)
	else:
		_tick_idle(delta)


func _apply_facing_scale() -> void:
	if _sprite == null:
		return
	var sx := _base_scale if _facing_right else -_base_scale
	_sprite.scale = Vector2(sx, absf(_sprite.scale.y) if _sprite.scale.y != 0.0 else _base_scale)
	if absf(_sprite.scale.y) < 0.01:
		_sprite.scale.y = _base_scale
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


func _pick_frame(anim: String, phase: float) -> void:
	if not _frames.has(anim):
		return
	var arr: Array = _frames[anim]
	if arr.is_empty():
		return
	var idx := int(floor(phase)) % arr.size()
	var tex: Texture2D = arr[idx] as Texture2D
	if tex != null and _sprite.texture != tex:
		_set_tex(tex)


func _spawn_afterimage() -> void:
	if not _is_dnf_style() or _sprite == null or _sprite.texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = _sprite.texture
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.offset = _sprite.offset
	ghost.scale = _sprite.scale
	ghost.position = _sprite.position
	ghost.modulate = Color(1.0, 0.55, 0.25, 0.45)
	ghost.z_index = 0
	add_child(ghost)
	move_child(ghost, 1)
	_afterimages.append({"node": ghost, "life": AFTERIMAGE_LIFE})


func _tick_afterimages(delta: float) -> void:
	var i := 0
	while i < _afterimages.size():
		var it: Dictionary = _afterimages[i]
		it["life"] = float(it["life"]) - delta
		var n: Sprite2D = it["node"]
		if is_instance_valid(n):
			var a := clampf(float(it["life"]) / AFTERIMAGE_LIFE, 0.0, 1.0)
			n.modulate.a = a * 0.45
		if float(it["life"]) <= 0.0:
			if is_instance_valid(n):
				n.queue_free()
			_afterimages.remove_at(i)
		else:
			_afterimages[i] = it
			i += 1


func _tick_idle(delta: float) -> void:
	idle_phase += delta * 3.2
	_frame_t += delta * 4.0
	_pick_frame("idle", _frame_t)
	var breath := sin(idle_phase)
	if _is_dnf_style():
		# DNF 待机：呼吸起伏 + 翅膀感缩放
		_sprite.position = Vector2(0.0, breath * 1.2)
		_sprite.scale.y = _base_scale * (1.0 + breath * 0.035)
		_sprite.scale.x = (_base_scale if _facing_right else -_base_scale) * (1.0 - breath * 0.015)
		_sprite.rotation = breath * 0.02
	else:
		_sprite.position = Vector2.ZERO
		_sprite.rotation = 0.0
		_apply_facing_scale()
	_apply_shadow()


func _tick_idle_pulse(delta: float) -> void:
	_tick_idle(delta)


func _tick_walk(delta: float) -> void:
	walk_phase += delta * (12.0 if _is_dnf_style() else 10.0)
	_frame_t += delta * 8.0
	_pick_frame("walk", _frame_t)
	var bob := sin(walk_phase)
	var sign: float = 1.0 if _facing_right else -1.0
	if _is_dnf_style():
		# DNF 跑动：前倾 + 大步起伏 + 轻微挤压
		_sprite.position = Vector2(sign * 1.5, bob * 3.2)
		_sprite.rotation = sign * 0.08
		_sprite.scale.y = _base_scale * (1.0 + absf(bob) * 0.04)
		_sprite.scale.x = (_base_scale if _facing_right else -_base_scale) * (1.0 - absf(bob) * 0.03)
		if int(floor(walk_phase / (PI * 0.5))) != int(floor((walk_phase - delta * 12.0) / (PI * 0.5))):
			_spawn_afterimage()
	else:
		_sprite.position.y = bob * 2.0
		_sprite.rotation = 0.0
		_apply_facing_scale()
	var foot: float = floorf(walk_phase / PI)
	if foot > _last_foot_phase:
		_last_foot_phase = foot
		var f: String = str(_sfx.get("foot", "foot_armor"))
		if f != "":
			AudioController.play(f, global_position)
	_apply_shadow()


func _tick_attack(delta: float) -> void:
	var dur := ATTACK_DURATION if _is_dnf_style() else 0.27
	attack_left -= delta
	var p := 1.0 - clampf(attack_left / dur, 0.0, 1.0)
	var sign: float = 1.0 if _facing_right else -1.0
	# 三阶段：蓄力回拉 → 突进挥击 → 收招
	var pose := 0
	if p < 0.28:
		pose = 0
		var u := p / 0.28
		_sprite.position = Vector2(-sign * u * 8.0, -u * 2.0)
		_sprite.rotation = -sign * u * 0.18
		_sprite.scale.x = (_base_scale if _facing_right else -_base_scale) * (1.0 - u * 0.06)
		_sprite.scale.y = _base_scale * (1.0 + u * 0.05)
		_frame_t = 0.0
	elif p < 0.62:
		pose = 1
		var u := (p - 0.28) / 0.34
		var thrust := sin(u * PI)
		_sprite.position = Vector2(sign * thrust * 14.0, -thrust * 3.0)
		_sprite.rotation = sign * thrust * 0.12
		_sprite.scale.x = (_base_scale if _facing_right else -_base_scale) * (1.0 + thrust * 0.12)
		_sprite.scale.y = _base_scale * (1.0 - thrust * 0.05)
		if u > 0.35 and u < 0.55:
			_spawn_afterimage()
		_frame_t = 1.0
	else:
		pose = 2
		var u := (p - 0.62) / 0.38
		_sprite.position = Vector2(sign * (1.0 - u) * 4.0, 0)
		_sprite.rotation = sign * (1.0 - u) * 0.04
		_apply_facing_scale()
		_frame_t = 2.0
	_pick_frame("attack", float(pose))

	if not _hit_fired and _attack_mode in ["melee", "breath", "charge"] and p >= HIT_PHASE:
		_hit_fired = true
		if _on_hit.is_valid():
			_on_hit.call()
		_on_hit = Callable()
		var hit: String = str(_sfx.get("hit", "impact_med"))
		if hit != "":
			AudioController.play(hit, global_position)
		_sprite.modulate = Color(1.5, 1.2, 0.9, 1.0)
	else:
		_sprite.modulate = _sprite.modulate.lerp(Color.WHITE, clampf(delta * 10.0, 0.0, 1.0))

	if attack_left <= 0.0:
		state = "idle"
		_sprite.modulate = Color.WHITE
		_sprite.rotation = 0.0
		_frame_t = 0.0
		_apply_facing_scale()
		_sprite.position = Vector2.ZERO
	_apply_shadow()
