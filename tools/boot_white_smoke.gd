extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("BOOT_SMOKE start")
	var packed: PackedScene = load("res://main.tscn")
	if packed == null:
		print("BOOT_FAIL main.tscn null")
		quit(2)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	for i in range(12):
		await process_frame
	print("BOOT main class=", main.get_class(), " children=", main.get_child_count())
	var host = main.get("_battle_host")
	var view = main.get("_battle_view")
	var world = main.get("world_root")
	var cam = main.get("battle_cam")
	var hud = main.get("hud")
	var mapl = main.get("map_layer")
	print("BOOT host=", host, " size=", host.size if host else null)
	print("BOOT view=", view, " size=", view.size if view else null)
	print("BOOT world=", world, " child=", world.get_child_count() if world else -1)
	print("BOOT cam=", cam, " current=", cam.is_current() if cam else false, " pos=", cam.position if cam else null)
	print("BOOT hud=", hud, " map=", mapl)
	if view != null:
		print("BOOT view.world_2d=", view.world_2d)
		print("BOOT view.transparent=", view.transparent_bg)
	print("BOOT_SMOKE_OK")
	quit(0)
