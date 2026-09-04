# CO-044：龙族隐藏解锁（纯静态模块，preload 使用）
extends Object

const SAVE_PATH := "user://living_rampart_secrets.cfg"
const SECTION := "secrets"

static var _dragon_unlocked: bool = false
static var _easter_units_unlocked: bool = false
static var _loaded: bool = false

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		_dragon_unlocked = bool(cf.get_value(SECTION, "dragon_unlocked", false))
		_easter_units_unlocked = bool(cf.get_value(SECTION, "easter_units_unlocked", false))

static func is_dragon_unlocked() -> bool:
	ensure_loaded()
	return _dragon_unlocked

static func is_easter_units_unlocked() -> bool:
	ensure_loaded()
	return _easter_units_unlocked

static func unlock_dragon() -> bool:
	ensure_loaded()
	if _dragon_unlocked:
		return false
	_dragon_unlocked = true
	_save()
	return true

static func unlock_easter_units() -> bool:
	ensure_loaded()
	if _easter_units_unlocked:
		return false
	_easter_units_unlocked = true
	_save()
	return true

static func _save() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value(SECTION, "dragon_unlocked", _dragon_unlocked)
	cf.set_value(SECTION, "easter_units_unlocked", _easter_units_unlocked)
	cf.save(SAVE_PATH)

static func debug_set(dragon: bool, easter: bool) -> void:
	_loaded = true
	_dragon_unlocked = dragon
	_easter_units_unlocked = easter
	_save()
