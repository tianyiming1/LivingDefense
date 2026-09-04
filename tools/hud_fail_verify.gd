# 视口同一律 + 安全带/挡路验收（design-logic / CO-037）
# 运行：Godot --headless --path <project> -s res://tools/hud_fail_verify.gd
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fails: Array[String] = []

	# --- 同一律：Config ↔ project.godot ---
	var pw: int = int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var ph: int = int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	var aspect: String = str(ProjectSettings.get_setting("display/window/stretch/aspect", ""))
	print("VERIFY view_cfg=", Config.VIEW_SIZE, " project=", pw, "x", ph, " aspect=", aspect)
	print("VERIFY hud_bottom=", Config.HUD_BOTTOM_PX, " top_safe=", Config.HUD_TOP_SAFE_PX)
	if absf(Config.VIEW_SIZE.x - float(pw)) > 0.5 or absf(Config.VIEW_SIZE.y - float(ph)) > 0.5:
		fails.append("view_size_mismatch_project")
	if aspect != "keep":
		fails.append("stretch_aspect_not_keep")
	if Config.HUD_BOTTOM_PX > 120.0 + 0.01:
		fails.append("hud_bottom_exceeds_co037_120")
	var dock_top: float = Config.VIEW_SIZE.y - Config.HUD_BOTTOM_PX
	if dock_top < 600.0 - 0.01:
		fails.append("dock_top_below_600")
	print("VERIFY dock_top_y=", dock_top, " playfield_y=[", Config.HUD_TOP_SAFE_PX, ",", dock_top, "]")

	var packed: PackedScene = load("res://main.tscn")
	if packed == null:
		fails.append("load_main_tscn")
		_finish(fails)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	for _i in range(10):
		await process_frame

	if not (main is Node2D):
		fails.append("main_not_node2d")

	var cam: Camera2D = main.get("battle_cam") as Camera2D
	var hq: Node2D = main.get("hq") as Node2D
	var hud: Node = main.get("hud") as Node

	if cam == null:
		fails.append("no_camera")
	else:
		print("VERIFY cam.pos=", cam.position, " zoom=", cam.zoom, " offset=", cam.offset)
		if cam.zoom.x < 1.2:
			fails.append("zoom_too_wide")
		var usable := _usable_world_rect(cam)
		print("VERIFY usable_world=", usable)
		if hq != null:
			print("VERIFY hq=", hq.position)
			if not usable.grow(12.0).has_point(hq.position):
				fails.append("hq_not_in_usable_view")
		# 路径采样：落在可用视口内的点，其屏幕 y 必须在底栏上沿之上（矛盾律：可见∧不被常驻底栏盖）
		var path_in_view := 0
		var path_occluded := 0
		for p in Config.PATH_POINTS:
			if not usable.has_point(p):
				continue
			path_in_view += 1
			var screen_y: float = _world_to_screen_y(cam, p)
			print("VERIFY path_pt=", p, " screen_y=", snappedf(screen_y, 0.1))
			if screen_y >= dock_top - 1.0:
				path_occluded += 1
		print("VERIFY path_in_usable=", path_in_view, " occluded_by_dock=", path_occluded)
		if path_in_view == 0:
			fails.append("no_path_sample_in_usable_view")
		if path_occluded > 0:
			fails.append("path_screen_y_under_dock")

		# 南段走廊（常被挡）：把镜头移过去再测一次
		var south := Vector2(1320.0, 900.0)
		if cam.has_method("focus_world"):
			cam.call("focus_world", south)
			for _j in range(4):
				await process_frame
			usable = _usable_world_rect(cam)
			print("VERIFY south_focus usable=", usable, " cam=", cam.position)
			var south_ok := false
			for p2 in [Vector2(1080, 900), Vector2(1560, 900), south]:
				if not usable.grow(20.0).has_point(p2):
					continue
				var sy: float = _world_to_screen_y(cam, p2)
				print("VERIFY south_pt=", p2, " screen_y=", snappedf(sy, 0.1))
				if sy < dock_top - 1.0:
					south_ok = true
			if not south_ok:
				fails.append("south_path_still_under_dock")

	if hud == null:
		fails.append("no_hud")
	else:
		var info_title: Label = hud.get("info_title") as Label
		if info_title != null and str(info_title.text).find("hud_") >= 0:
			fails.append("raw_key")
		# 常驻底坞：dock_top 口径
		if hud.has_method("_dock_top_y"):
			var dy: float = float(hud.call("_dock_top_y"))
			print("VERIFY hud._dock_top_y=", dy)
			if absf(dy - dock_top) > 0.5:
				fails.append("hud_dock_top_mismatch")

	_finish(fails)

func _usable_world_rect(cam: Camera2D) -> Rect2:
	var vp: Vector2 = Config.VIEW_SIZE
	var hud: float = Config.HUD_BOTTOM_PX
	var z: float = maxf(cam.zoom.y, 0.01)
	var half := Vector2(vp.x * 0.5 / z, maxf(120.0, vp.y - hud) * 0.5 / z)
	# 与 battle_camera：可视中心 ≈ position（offset 只把底栏带让给 HUD）
	return Rect2(cam.position - half, half * 2.0)

func _world_to_screen_y(cam: Camera2D, world: Vector2) -> float:
	# 屏幕中心对应 cam.position + offset；y 向下为正
	var z: float = maxf(cam.zoom.y, 0.01)
	var center_world_y: float = cam.position.y + cam.offset.y
	return Config.VIEW_SIZE.y * 0.5 + (world.y - center_world_y) * z

func _finish(fails: Array[String]) -> void:
	if fails.is_empty():
		print("VERIFY_ACCEPT")
		quit(0)
	else:
		print("VERIFY_FAIL ", ",".join(fails))
		quit(1)
