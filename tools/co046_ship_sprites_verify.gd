# CO-046 / W5 冒烟：龙族 ship 立绘存在
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fails: Array[String] = []
	var need: Array[String] = [
		"res://assets/pixels/dragon/unit_3.png",
		"res://assets/pixels/dragon/unit_14.png",
		"res://assets/pixels/dragon/unit_15.png",
		"res://assets/pixels/dragon/unit_16.png",
		"res://assets/pixels/dragon/unit_17.png",
		"res://assets/pixels/dragon/unit_3_anim/idle_0.png",
		"res://assets/pixels/dragon/unit_14_anim/idle_0.png",
		"res://assets/pixels/dragon/unit_17_anim/attack_0.png",
	]
	for p in need:
		var ok: bool = ResourceLoader.exists(p) or FileAccess.file_exists(p)
		print("VERIFY ", p, " ", ok)
		if not ok:
			fails.append("missing:" + p)
	var t3: Texture2D = UnitSprites.load_texture("dragon", 3)
	var t14: Texture2D = UnitSprites.load_texture("dragon", 14)
	var t17: Texture2D = UnitSprites.load_texture("dragon", 17)
	if t3 == null:
		fails.append("load_unit_3_null")
	if t14 == null:
		fails.append("load_unit_14_null")
	if t17 == null:
		fails.append("load_unit_17_null")
	if fails.is_empty():
		print("VERIFY_ACCEPT")
		quit(0)
	else:
		print("VERIFY_FAIL ", ",".join(fails))
		quit(1)
