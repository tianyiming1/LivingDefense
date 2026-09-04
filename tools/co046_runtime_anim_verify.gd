# 冒烟：unit_sprite_view 移动时是否切 walk/fly 帧（非仅平移立绘）
extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var script: Script = load("res://scripts/unit_sprite_view.gd") as Script
	if script == null:
		print("VERIFY_REJECT no_script")
		quit(1)
		return
	var tex: Texture2D = UnitSprites.load_texture("dragon", 17)
	var view := Node2D.new()
	view.set_script(script)
	root.add_child(view)
	view.setup(tex, "spell", 17.0, "dragon", false, 17, true)
	view.set_moving(true, true)  # fly
	var seen: Dictionary = {}
	for i in range(24):
		view._process(1.0 / 12.0)
		var spr: Sprite2D = view.get("_sprite")
		if spr != null and spr.texture != null:
			seen[spr.texture.get_path()] = true
	view.set_moving(true, false)  # walk
	for i in range(24):
		view._process(1.0 / 12.0)
		var spr2: Sprite2D = view.get("_sprite")
		if spr2 != null and spr2.texture != null:
			seen[spr2.texture.get_path()] = true
	view.queue_free()
	var n: int = seen.size()
	print("VERIFY runtime_unique_textures=", n)
	for p in seen.keys():
		print("  ", p)
	if n >= 3:
		print("VERIFY_ACCEPT runtime_anim_switches")
		quit(0)
	else:
		print("VERIFY_REJECT runtime_anim_static")
		quit(1)
