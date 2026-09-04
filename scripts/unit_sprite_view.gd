# 单位侧视精灵：
# 1) 真分帧：只切贴图 + 朝向 + 恒定升力（禁整图果冻）
# 2) Path A 木偶：占位分帧时用 body+wing 部件旋转（扇翅/迈步/咏唱/倾倒）
extends Node2D

const ATTACK_DURATION := 0.48
const DREAM_ATTACK_DURATION := 0.52
const HIT_PHASE := 0.52
const AFTERIMAGE_LIFE := 0.16
const DREAM_AFTERIMAGE := Color(0.608, 0.549, 1.0, 0.4) # #9B8CFF
const FPS_IDLE := 5.0
const FPS_WALK := 10.0
const FPS_FLY := 12.0
const FPS_DREAM_FLAP := 8.0  # ~125ms/帧；整圈约 1.0s（原 12.5/80ms 太赶，眼检要更长）
const LIFT_HOVER := 6.0
const LIFT_FLY := 8.0

var _sprite: Sprite2D
var _shadow: Sprite2D
var _wing: Sprite2D ## fallback single wing
var _wing_l: Sprite2D
var _wing_r: Sprite2D
var _base_scale := 0.62
var _facing_right := true
var _attack_mode := "melee"
var _stationary := false
var _hover_idle := false
var _race := ""
var _unit_id := -1
var _sfx: Dictionary = {}
var state := "idle"
var walk_phase := 0.0
var attack_left := 0.0
var _hit_fired := false
var _on_hit: Callable = Callable()
var _last_foot_phase := 0.0
var _base_tex: Texture2D = null
var _frames: Dictionary = {}
var _frame_t := 0.0
var _afterimages: Array = []
var _want_fly := false
## Path A：部件木偶（真分帧优先；占位分帧时启用）
var _use_puppet := false
var _dual_wing := false
var _full_body_bob := false ## 整图 body：只浮空点头，不叠转翅（防镂空/紫噪）
var _shoulder := Vector2(48.0, 60.0)
var _puppet_t := 0.0
var _death_spin := 0.0
## 梦龙扇翅独立相位：禁止因 idle↔fly 抖动把 _frame_t 清零卡在第 0 帧（那就是「平移」）
var _flap_t := 0.0
var _flap_idx := -1
## GIF 级扇翅：整表 AtlasTexture 改 region（比换 ImageTexture 更稳，GPU 必刷新）
var _flap_atlas: AtlasTexture = null
var _flap_n := 0
var _flap_cw := 96


func setup(tex: Texture2D, kind: String, radius: float, p_race: String, stationary: bool, unit_id: int = -1, hover_idle: bool = false) -> void:
	_base_scale = UnitSprites.scale_for_radius(radius)
	# 梦龙要对齐 WorkBuddy GIF 可读扇翅：略放大，禁糊成噪点
	if unit_id in [14, 15, 16, 17]:
		_base_scale = clampf(_base_scale * 1.15, 0.72, 1.15)
	_attack_mode = UnitSprites.attack_kind(kind)
	_stationary = stationary
	_hover_idle = hover_idle
	_race = p_race
	_unit_id = unit_id
	_sfx = UnitSprites.sfx_for_attack(kind, p_race)
	if unit_id in [14, 15, 16, 17]:
		_sfx["wind"] = "arcane_cast"
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
	_try_enable_puppet(p_race, unit_id)
	_flap_t = 0.0
	_flap_idx = -1
	_setup_dream_flap_atlas(p_race, unit_id)
	if not _use_puppet and _dream_has_flap():
		_apply_dream_flap(0.0) # 立刻落在扇翅第 0 帧，禁 base 静帧
	elif not _use_puppet and _has_clip("idle"):
		_pick_frame("idle", 0.0)
	_lock_pose(LIFT_HOVER if _hover_idle else 0.0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func _setup_dream_flap_atlas(race: String, unit_id: int) -> void:
	_flap_atlas = null
	_flap_n = 0
	if unit_id not in [14, 15, 16, 17]:
		return
	var sheet_path := "%s/fly_sheet.png" % UnitSprites.anim_dir(race, unit_id)
	var sheet: Texture2D = UnitSprites.load_disk_tex(sheet_path, true)
	if sheet == null:
		# 无表则用离散 fly 帧拼不出 atlas；仍走 _frames
		return
	_flap_cw = 96
	_flap_n = maxi(1, int(sheet.get_width() / _flap_cw))
	_flap_atlas = AtlasTexture.new()
	_flap_atlas.filter_clip = true
	_flap_atlas.atlas = sheet
	_flap_atlas.region = Rect2(0, 0, _flap_cw, sheet.get_height())
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_set_tex(_flap_atlas)


func _set_tex(tex: Texture2D) -> void:
	if tex == null:
		return
	_sprite.texture = tex
	_shadow.texture = tex
	_sprite.offset = UnitSprites.foot_offset(tex)
	_shadow.offset = _sprite.offset


func _puppet_dir(race: String, unit_id: int) -> String:
	return "res://assets/pixels/%s/unit_%d_puppet" % [race, unit_id]


func _anim_frames_are_placeholder() -> bool:
	if not _has_clip("idle"):
		return true
	if _base_tex == null:
		return true
	var idle0: Texture2D = (_frames["idle"] as Array)[0] as Texture2D
	if not _textures_nearly_equal(idle0, _base_tex):
		return false
	if _has_clip("walk"):
		var w0: Texture2D = (_frames["walk"] as Array)[0] as Texture2D
		if not _textures_nearly_equal(w0, idle0):
			return false
	return true


func _textures_nearly_equal(a: Texture2D, b: Texture2D) -> bool:
	if a == null or b == null:
		return a == b
	if a == b:
		return true
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return false
	var ia: Image = a.get_image()
	var ib: Image = b.get_image()
	if ia == null or ib == null:
		return false
	if ia.get_data() == ib.get_data():
		return true
	var w := ia.get_width()
	var h := ia.get_height()
	var diff := 0
	var samples := 0
	var step_x := maxi(8, int(w / 8))
	var step_y := maxi(8, int(h / 8))
	for yy in range(4, h, step_y):
		for xx in range(4, w, step_x):
			samples += 1
			if ia.get_pixel(xx, yy) != ib.get_pixel(xx, yy):
				diff += 1
	if samples <= 0:
		return true
	return float(diff) / float(samples) < 0.04


func _clear_wing_nodes() -> void:
	for n in [_wing, _wing_l, _wing_r]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_wing = null
	_wing_l = null
	_wing_r = null


func _make_wing_sprite(tex: Texture2D) -> Sprite2D:
	var w := Sprite2D.new()
	w.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	w.texture = tex
	w.centered = true
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	w.offset = Vector2(tw * 0.5 - _shoulder.x, th * 0.5 - _shoulder.y)
	_sprite.add_child(w)
	return w


func _try_enable_puppet(race: String, unit_id: int) -> void:
	_use_puppet = false
	_dual_wing = false
	_full_body_bob = false
	_clear_wing_nodes()
	var meta_path := "%s/meta.json" % _puppet_dir(race, unit_id)
	if not FileAccess.file_exists(meta_path):
		return
	var meta := _load_puppet_meta(meta_path)
	# 真分帧交付后：meta.prefer_frames = true
	if bool(meta.get("prefer_frames", false)):
		return
	# 非梦龙：仅占位分帧时启用
	if not _is_dream_beast() and not _anim_frames_are_placeholder():
		return
	var body_tex: Texture2D = UnitSprites.load_disk_tex("%s/body.png" % _puppet_dir(race, unit_id))
	if body_tex == null:
		push_warning("puppet body missing for unit_%d" % unit_id)
		return
	if meta.has("shoulder"):
		var s: Array = meta["shoulder"]
		_shoulder = Vector2(float(s[0]), float(s[1]))
	_set_tex(body_tex)
	_full_body_bob = bool(meta.get("full_body", false)) or str(meta.get("mode", "")) == "path_a_full_body_bob"
	# 兜底：body 与立绘几乎同图 → 禁止再叠翅（否则必然「两对翅膀」）
	if not _full_body_bob and _base_tex != null and _textures_nearly_equal(body_tex, _base_tex):
		_full_body_bob = true
	if _full_body_bob:
		# 整图可读优先：浮空点头即可，禁止叠转翅
		_clear_wing_nodes()
		_use_puppet = true
		_puppet_t = 0.0
		_death_spin = 0.0
		return
	var wl_tex: Texture2D = UnitSprites.load_disk_tex("%s/wing_l.png" % _puppet_dir(race, unit_id))
	var wr_tex: Texture2D = UnitSprites.load_disk_tex("%s/wing_r.png" % _puppet_dir(race, unit_id))
	if wl_tex != null and wr_tex != null:
		_wing_l = _make_wing_sprite(wl_tex)
		_wing_r = _make_wing_sprite(wr_tex)
		_dual_wing = true
	else:
		var wing_tex: Texture2D = UnitSprites.load_disk_tex("%s/wing.png" % _puppet_dir(race, unit_id))
		if wing_tex == null:
			# 无翅部件：仍可浮空点头，勿失败退回导致叠影
			_full_body_bob = true
			_use_puppet = true
			_puppet_t = 0.0
			_death_spin = 0.0
			return
		_wing = _make_wing_sprite(wing_tex)
	_place_wing_on_body()
	_use_puppet = true
	_puppet_t = 0.0
	_death_spin = 0.0


func _load_puppet_meta(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		return data
	return {}


func _place_wing_on_body() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var tw := float(_sprite.texture.get_width())
	var th := float(_sprite.texture.get_height())
	var pos := _sprite.offset + Vector2(_shoulder.x - tw * 0.5, _shoulder.y - th * 0.5)
	for n in [_wing, _wing_l, _wing_r]:
		if n != null and is_instance_valid(n):
			n.position = pos


func _set_wing_rotations(amp: float) -> void:
	## amp>0：右翼上扬、左翼下压（对拍）
	if _dual_wing:
		if _wing_l != null:
			_wing_l.rotation = -amp
			_wing_l.visible = state != "dead"
		if _wing_r != null:
			_wing_r.rotation = amp
			_wing_r.visible = state != "dead"
	elif _wing != null:
		_wing.rotation = amp
		_wing.visible = state != "dead"
	_place_wing_on_body()


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


func set_moving(moving: bool, use_fly: bool = false) -> void:
	if state == "attack" or state == "death" or state == "dead" or _stationary:
		return
	_want_fly = use_fly
	var next := "idle"
	if moving:
		# 梦龙有扇翅真帧时，移动一律 fly（禁 walk 静帧）
		if _dream_has_flap():
			next = "fly"
		elif use_fly and (_frames.has("fly") or _is_dream_beast() or _attack_mode == "breath"):
			next = "fly"
		else:
			next = "walk"
	if state != next:
		state = next
		# 梦龙扇翅相位独立，禁止在 idle↔fly 间清零（抖动清零 = 永卡第 0 帧 = 平移）
		if not _dream_has_flap():
			_frame_t = 0.0
		walk_phase = 0.0
		_last_foot_phase = -1.0


func start_attack(on_hit: Callable) -> void:
	state = "attack"
	attack_left = DREAM_ATTACK_DURATION if _is_dream_beast() else (ATTACK_DURATION if _is_dnf_style() else 0.27)
	_hit_fired = false
	_on_hit = on_hit
	if not _dream_has_flap():
		_frame_t = 0.0
	var wind: String = str(_sfx.get("wind", "sword_swish"))
	if wind != "":
		AudioController.play(wind, global_position)


func start_shoot() -> void:
	state = "attack"
	attack_left = DREAM_ATTACK_DURATION if _is_dream_beast() else (0.22 if _is_dnf_style() else 0.16)
	_hit_fired = true
	_on_hit = Callable()
	if not _dream_has_flap():
		_frame_t = 0.0
	var wind: String = str(_sfx.get("wind", "ranged_shot"))
	if wind != "":
		AudioController.play(wind, global_position)


func play_death() -> void:
	state = "death"
	_frame_t = 0.0
	_death_spin = 0.0
	var n := 3
	if not _use_puppet and _has_clip("death"):
		n = maxi(1, (_frames["death"] as Array).size())
		_pick_frame_clamped("death", 0.0)
	attack_left = 0.14 * float(n) + 0.08
	_on_hit = Callable()


func _is_dnf_style() -> bool:
	return _race == "dragon" or _frames.size() > 0


func _is_dream_beast() -> bool:
	return _unit_id in [14, 15, 16, 17]


## 梦龙是否已装完整扇翅/动作真帧（≥8；完整动作为 16）
func _dream_has_flap() -> bool:
	if not _is_dream_beast():
		return false
	if _flap_atlas != null and _flap_n >= 8:
		return true
	if _has_clip("fly") and (_frames["fly"] as Array).size() >= 8:
		return true
	if _has_clip("idle") and (_frames["idle"] as Array).size() >= 8:
		return true
	return false


## 仅无真扇翅时才静帧。有扇翅则永远禁止锁 base——那就是「平移怪」根因。
func _dream_still_pose() -> bool:
	if not _is_dream_beast() or _use_puppet:
		return false
	if _dream_has_flap():
		return false
	return true


func _lock_dream_still(lift: float) -> void:
	if _base_tex != null:
		_set_tex(_base_tex)
	elif _has_clip("idle"):
		_set_tex((_frames["idle"] as Array)[0] as Texture2D)
	_lock_pose(lift, 0.0, 0.0, 0.0)


func _has_clip(anim: String) -> bool:
	return _frames.has(anim) and not (_frames[anim] as Array).is_empty()


## 扇翅剪辑名：优先 fly，否则 idle
func _dream_flap_anim() -> String:
	if _has_clip("fly") and (_frames["fly"] as Array).size() >= 4:
		return "fly"
	return "idle"


## 强制切扇翅帧；相位独立；优先 Atlas region（对齐 GIF）
func _apply_dream_flap(_delta: float) -> void:
	if _use_puppet or not _dream_has_flap():
		return
	_flap_t += _delta * FPS_DREAM_FLAP
	var n := _flap_n if (_flap_atlas != null and _flap_n > 0) else 0
	if n <= 0:
		var anim := _dream_flap_anim()
		n = (_frames[anim] as Array).size()
	var idx := int(floor(_flap_t)) % maxi(1, n)
	if idx == _flap_idx:
		return
	_flap_idx = idx
	if _flap_atlas != null and _flap_n > 0:
		var h: float = float(_flap_atlas.atlas.get_height())
		_flap_atlas.region = Rect2(float(idx * _flap_cw), 0.0, float(_flap_cw), h)
		# 强制 Sprite 认新 region（部分驱动不刷新 mutate）
		_sprite.texture = null
		_sprite.texture = _flap_atlas
		_shadow.texture = _flap_atlas
		_sprite.offset = UnitSprites.foot_offset(_flap_atlas)
		_shadow.offset = _sprite.offset
		_sprite.queue_redraw()
		return
	var anim2 := _dream_flap_anim()
	var arr: Array = _frames[anim2]
	var tex: Texture2D = arr[idx] as Texture2D
	if tex != null:
		_set_tex(tex)


## 真分帧：禁整图果冻。Path A：允许翼旋转 + 轻位移（部件级）。
func _lock_pose(lift: float = 0.0, body_dx: float = 0.0, body_bob: float = 0.0, wing_rot: float = 0.0) -> void:
	if _sprite == null:
		return
	if _use_puppet and state == "death":
		_sprite.rotation = _death_spin
	else:
		_sprite.rotation = 0.0
	_sprite.position = Vector2(body_dx, -lift + body_bob)
	_apply_facing_scale()
	_apply_shadow(lift)
	if _use_puppet:
		_set_wing_rotations(wing_rot)
	else:
		for n in [_wing, _wing_l, _wing_r]:
			if n != null:
				n.visible = false


func _apply_facing_scale() -> void:
	if _sprite == null:
		return
	var sx := _base_scale if _facing_right else -_base_scale
	_sprite.scale = Vector2(sx, _base_scale)


func _apply_shadow(hover_lift: float = 0.0) -> void:
	if _shadow == null or _sprite == null:
		return
	var s: float = _base_scale
	var hover_t: float = clampf(hover_lift / 10.0, 0.0, 1.0)
	_shadow.scale = Vector2(s * (0.85 - hover_t * 0.25), s * (0.22 - hover_t * 0.06))
	var a: float = 0.35 - hover_t * 0.15
	if _is_dream_beast():
		a *= 0.55 # 梦龙影淡一点，别糊成脚下黑团
	_shadow.modulate = Color(0, 0, 0, a)
	_shadow.position = Vector2(0, 4 + hover_lift * 0.35)
	_shadow.z_index = -1
	_sprite.z_index = 1


func _pick_frame(anim: String, phase: float) -> void:
	if _use_puppet:
		return
	if not _has_clip(anim):
		return
	var arr: Array = _frames[anim]
	var idx := int(floor(phase)) % arr.size()
	var tex: Texture2D = arr[idx] as Texture2D
	if tex == null:
		return
	# 必须换贴图；勿用引用相等短路（磁盘 ImageTexture 每帧对象不同但内容可能被缓存糊住）
	if _sprite.texture != tex:
		_set_tex(tex)


func _pick_frame_clamped(anim: String, phase: float) -> void:
	if _use_puppet:
		return
	if not _has_clip(anim):
		return
	var arr: Array = _frames[anim]
	var idx := clampi(int(floor(phase)), 0, arr.size() - 1)
	var tex: Texture2D = arr[idx] as Texture2D
	if tex != null and _sprite.texture != tex:
		_set_tex(tex)


func _process(delta: float) -> void:
	_tick_afterimages(delta)
	_puppet_t += delta
	if state == "death" or state == "dead":
		_tick_death(delta)
		return
	# 梦龙：与 loco state 解耦，每帧必扇翅（禁平移）
	if _dream_has_flap():
		_apply_dream_flap(delta)
		var lift := 0.0
		if state == "fly":
			lift = LIFT_FLY
		elif _hover_idle:
			lift = LIFT_HOVER
		_lock_pose(lift, 0.0, 0.0, 0.0)
		if state == "attack":
			_tick_attack_logic_only(delta)
		return
	match state:
		"attack":
			_tick_attack(delta)
		"fly":
			_tick_fly(delta)
		"walk":
			_tick_walk(delta)
		_:
			_tick_idle(delta)


## 梦龙扇翅时攻击只跑命中计时；贴图由 _apply_dream_flap 负责
func _tick_attack_logic_only(delta: float) -> void:
	var dur := DREAM_ATTACK_DURATION
	attack_left -= delta
	var p := 1.0 - clampf(attack_left / dur, 0.0, 1.0)
	if not _hit_fired and _on_hit.is_valid() and p >= 0.42:
		_hit_fired = true
		_on_hit.call()
		_on_hit = Callable()
		_sprite.modulate = Color(1.2, 1.15, 1.45, 1.0)
	else:
		_sprite.modulate = _sprite.modulate.lerp(Color.WHITE, clampf(delta * 8.0, 0.0, 1.0))
	if attack_left <= 0.0:
		state = "idle"
		_sprite.modulate = Color.WHITE
		_frame_t = 0.0


func _tick_idle(_delta: float) -> void:
	if _dream_still_pose():
		_lock_dream_still(LIFT_HOVER if _hover_idle else 0.0)
		return
	var dream_flap := _dream_has_flap()
	var fps := FPS_DREAM_FLAP if dream_flap else FPS_IDLE
	_frame_t += _delta * fps
	if not _use_puppet:
		if dream_flap:
			_pick_frame(_dream_flap_anim(), _frame_t)
		elif _has_clip("idle"):
			_pick_frame("idle", _frame_t)
		elif _base_tex != null:
			_set_tex(_base_tex)
	var lift: float = LIFT_HOVER if _hover_idle else 0.0
	var wing_r := sin(_puppet_t * 2.8) * 0.38 if (_use_puppet and not _full_body_bob) else 0.0
	var bob := 0.0
	if _use_puppet:
		bob = sin(_puppet_t * 2.8) * 1.1 if _hover_idle else sin(_puppet_t * 1.8) * 0.5
	if _is_dream_beast():
		wing_r = 0.0
		bob = 0.0
	_lock_pose(lift, 0.0, bob, wing_r)


func _tick_fly(_delta: float) -> void:
	if _dream_still_pose():
		# 恒定升力即可；禁帧间 ±1px 抖动当飞
		_lock_dream_still(LIFT_FLY)
		return
	var fps := FPS_DREAM_FLAP if _is_dream_beast() else FPS_FLY
	_frame_t += _delta * fps
	if not _use_puppet:
		if _dream_has_flap():
			_pick_frame(_dream_flap_anim(), _frame_t)
		elif _has_clip("fly"):
			_pick_frame("fly", _frame_t)
		elif _has_clip("walk"):
			_pick_frame("walk", _frame_t)
	var wing_r := sin(_puppet_t * 10.0) * 0.85 if (_use_puppet and not _full_body_bob) else 0.0
	var bob := sin(_puppet_t * 10.0) * 0.9 if _use_puppet else 0.0
	# 梦龙真分帧：只换贴图 + 恒定升力，禁止点头果冻
	if _is_dream_beast():
		wing_r = 0.0
		bob = 0.0
	_lock_pose(LIFT_FLY, 0.0, bob, wing_r)


func _tick_walk(_delta: float) -> void:
	if _dream_still_pose():
		_lock_dream_still(0.0)
		return
	# 梦龙有扇翅：walk 状态也播 fly 扇翅（Shift 贴地走也不能平移）
	if _dream_has_flap():
		_frame_t += _delta * FPS_DREAM_FLAP
		if not _use_puppet:
			_pick_frame(_dream_flap_anim(), _frame_t)
		_lock_pose(0.0, 0.0, 0.0, 0.0)
		return
	_frame_t += _delta * FPS_WALK
	walk_phase += _delta * FPS_WALK
	if not _use_puppet:
		_pick_frame("walk", _frame_t)
	var wing_r := 0.0
	var bob := 0.0
	var dx := 0.0
	if _use_puppet:
		bob = absf(sin(walk_phase)) * 2.4
		wing_r = 0.0 if _full_body_bob else sin(walk_phase) * 0.28
		dx = sin(walk_phase) * 1.4
	if _is_dream_beast():
		wing_r = 0.0
		bob = 0.0
		dx = 0.0
	_lock_pose(0.0, dx, bob, wing_r)
	var foot: float = floorf(walk_phase / 2.0)
	if foot > _last_foot_phase:
		_last_foot_phase = foot
		var f: String = str(_sfx.get("foot", ""))
		if f != "" and not _is_dream_beast():
			AudioController.play(f, global_position)


func _tick_attack(delta: float) -> void:
	var dream := _is_dream_beast()
	var dur := DREAM_ATTACK_DURATION if dream else (ATTACK_DURATION if _is_dnf_style() else 0.27)
	attack_left -= delta
	var p := 1.0 - clampf(attack_left / dur, 0.0, 1.0)
	var pose := 0
	if p < 0.30:
		pose = 0
	elif p < 0.62:
		pose = 1
	else:
		pose = 2
	if _dream_still_pose():
		_lock_dream_still(LIFT_HOVER if _hover_idle else 0.0)
	else:
		# 梦龙扇翅真帧：攻击中也继续扇翅，不用烂 attack 静帧当平移
		if dream and _dream_has_flap():
			_frame_t += delta * FPS_DREAM_FLAP
			if not _use_puppet:
				_pick_frame(_dream_flap_anim(), _frame_t)
			_lock_pose(LIFT_HOVER if _hover_idle else 0.0, 0.0, 0.0, 0.0)
		else:
			if not _use_puppet and _has_clip("attack"):
				_pick_frame("attack", float(pose))
			var lift: float = LIFT_HOVER if (_hover_idle and dream) else 0.0
			var wing_r := 0.0
			var dx := 0.0
			if _use_puppet:
				if _full_body_bob:
					if pose == 0:
						dx = -3.5
					elif pose == 1:
						dx = 6.0
					else:
						dx = 1.0
					wing_r = 0.0
				elif pose == 0:
					dx = -3.5
					wing_r = -0.45
				elif pose == 1:
					dx = 6.0
					wing_r = 0.7
				else:
					dx = 1.0
					wing_r = 0.2
			if dream:
				wing_r = 0.0
				dx = 0.0
			_lock_pose(lift, dx, 0.0, wing_r)

	if dream:
		if not _hit_fired and _on_hit.is_valid() and p >= 0.42:
			_hit_fired = true
			_on_hit.call()
			_on_hit = Callable()
			# 静帧占位：禁止 modulate 闪成果冻高光
			if not _dream_still_pose():
				_sprite.modulate = Color(1.2, 1.15, 1.45, 1.0)
		elif not _dream_still_pose():
			_sprite.modulate = _sprite.modulate.lerp(Color.WHITE, clampf(delta * 8.0, 0.0, 1.0))
	else:
		if not _hit_fired and _attack_mode in ["melee", "breath", "charge"] and p >= HIT_PHASE:
			_hit_fired = true
			if _on_hit.is_valid():
				_on_hit.call()
			_on_hit = Callable()
			var hit: String = str(_sfx.get("hit", "impact_med"))
			if hit != "":
				AudioController.play(hit, global_position)
			_sprite.modulate = Color(1.5, 1.2, 0.9, 1.0)
			if _is_dnf_style() and not dream:
				_spawn_afterimage()
		else:
			_sprite.modulate = _sprite.modulate.lerp(Color.WHITE, clampf(delta * 10.0, 0.0, 1.0))

	if attack_left <= 0.0:
		state = "idle"
		_sprite.modulate = Color.WHITE
		_frame_t = 0.0
		if _dream_still_pose():
			_lock_dream_still(LIFT_HOVER if _hover_idle else 0.0)
		else:
			_lock_pose(LIFT_HOVER if _hover_idle else 0.0)


func _tick_death(delta: float) -> void:
	if state == "dead":
		return
	attack_left -= delta
	_frame_t += delta * 7.0
	if _use_puppet:
		var n := 3.0
		var total := 0.14 * n + 0.08
		var u := 1.0 - clampf(attack_left / maxf(total, 0.01), 0.0, 1.0)
		_death_spin = lerpf(0.0, PI * 0.5, smoothstep(0.0, 1.0, u))
		_lock_pose(0.0, u * 4.0, u * 2.0, lerpf(0.25, 1.0, u))
		if _sprite != null:
			_sprite.modulate = Color(0.85, 0.8, 0.95, clampf(1.0 - u * 0.55, 0.25, 1.0))
	else:
		if _has_clip("death"):
			_pick_frame_clamped("death", _frame_t)
		_lock_pose(0.0)
		if _sprite != null:
			_sprite.modulate = Color(0.85, 0.8, 0.95, clampf(attack_left / 0.5, 0.15, 1.0))
	if attack_left <= 0.0:
		state = "dead"
		if not _use_puppet and _has_clip("death"):
			var arr: Array = _frames["death"]
			_set_tex(arr[arr.size() - 1] as Texture2D)
		if _sprite != null:
			_sprite.modulate = Color(0.7, 0.65, 0.8, 0.2)
		for n in [_wing, _wing_l, _wing_r]:
			if n != null:
				n.visible = false


func _spawn_afterimage() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = _sprite.texture
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.offset = _sprite.offset
	ghost.scale = _sprite.scale
	ghost.position = _sprite.position
	ghost.modulate = DREAM_AFTERIMAGE if _is_dream_beast() else Color(1.0, 0.55, 0.25, 0.4)
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
			n.modulate.a = clampf(float(it["life"]) / AFTERIMAGE_LIFE, 0.0, 1.0) * 0.4
		if float(it["life"]) <= 0.0:
			if is_instance_valid(n):
				n.queue_free()
			_afterimages.remove_at(i)
		else:
			_afterimages[i] = it
			i += 1
