# 四族单位像素精灵（3/4 侧视；默认 96×108，脚底按比例锚点）
class_name UnitSprites
extends RefCounted

## 规范分辨率（导入脚本默认）。旧 64×72 贴图仍可加载，脚底按高度比例对齐。
const SPRITE_TEX_W := 96.0
const SPRITE_TEX_H := 108.0
const SPRITE_FOOT_RATIO := 66.0 / 72.0  # 脚底约在贴图 91.7% 高度
const SPRITE_SCALE := 0.78  # 相对旧 64@1.15，屏幕占地接近不变、细节更多

static func texture_path(race: String, unit_id: int) -> String:
	return "res://assets/pixels/%s/unit_%d.png" % [race, unit_id]

static func enemy_texture_path(enemy_id: int) -> String:
	return "res://assets/pixels/enemies/enemy_%d.png" % enemy_id

static func load_texture(race: String, unit_id: int) -> Texture2D:
	var p := texture_path(race, unit_id)
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	# 龙族进化形态复用同系幼龙贴图（0/4/7→0，1/5/8→1，2/6/9→2，3/10/11→0）
	if race == "dragon":
		var fallback := 0
		if unit_id in [1, 5, 8]:
			fallback = 1
		elif unit_id in [2, 6, 9]:
			fallback = 2
		elif unit_id in [3, 10, 11]:
			fallback = 0
		p = texture_path(race, fallback)
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	return null

static func load_enemy_texture(enemy_id: int) -> Texture2D:
	var p := enemy_texture_path(enemy_id)
	if not ResourceLoader.exists(p):
		return null
	return load(p) as Texture2D

# 分帧目录：assets/pixels/{race}/unit_{id}_anim/{idle|walk|attack}_N.png
static func anim_dir(race: String, unit_id: int) -> String:
	return "res://assets/pixels/%s/unit_%d_anim" % [race, unit_id]

static func load_anim_frames(race: String, unit_id: int) -> Dictionary:
	var out := {}
	if unit_id < 0:
		return out
	var base := anim_dir(race, unit_id)
	for anim in ["idle", "walk", "attack"]:
		var frames: Array = []
		for i in range(0, 8):
			var p := "%s/%s_%d.png" % [base, anim, i]
			if ResourceLoader.exists(p):
				var tex := load(p) as Texture2D
				if tex != null:
					frames.append(tex)
			else:
				break
		if not frames.is_empty():
			out[anim] = frames
	return out

static func foot_offset(tex: Texture2D = null) -> Vector2:
	# Sprite2D 默认以中心对齐；脚底约在贴图高度 * SPRITE_FOOT_RATIO。
	var h: float = SPRITE_TEX_H
	if tex != null:
		h = float(tex.get_height())
	var foot_y: float = minf(h * SPRITE_FOOT_RATIO, h - 2.0)
	return Vector2(0.0, h * 0.5 - foot_y)

static func scale_for_radius(radius: float) -> float:
	return SPRITE_SCALE * (radius / 11.0)

# 脚底为原点时，枪口相对偏移（侧视：抬高胸口 + 朝向伸出）
static func muzzle_local(facing_right: bool, radius: float = 11.0) -> Vector2:
	var s: float = scale_for_radius(radius)
	var side: float = 1.0 if facing_right else -1.0
	return Vector2(side * 22.0 * s, -30.0 * s)

static func depth_z(world_y: float) -> int:
	return int(world_y)

static func attack_kind(kind: String) -> String:
	match kind:
		"melee", "wall", "burst", "explode":
			return "melee"
		"single", "splash", "aa", "spike":
			return "ranged"
		"fly":
			return "breath"
		"charge":
			return "charge"
		"aura":
			return "aura"
		_:
			return "idle"

static func sfx_for_attack(kind: String, race: String) -> Dictionary:
	match attack_kind(kind):
		"melee":
			return {"wind": "sword_swish", "hit": "impact_med", "foot": "foot_armor"}
		"ranged":
			return {"wind": "ranged_shot", "hit": "", "foot": "foot_light"}
		"breath":
			return {"wind": "charge_release", "hit": "impact_light", "foot": "fly_whoosh"}
		"charge":
			return {"wind": "charge_release", "hit": "impact_med", "foot": "crystal_clink"}
		"aura":
			return {"wind": "aura_tick", "hit": "", "foot": "spore_idle"}
		_:
			if race == "fungus":
				return {"wind": "spore_pop", "hit": "impact_light", "foot": "spore_idle"}
			return {"wind": "sword_swish", "hit": "impact_med", "foot": "foot_armor"}
