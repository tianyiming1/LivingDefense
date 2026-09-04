# Capture rendered SubViewport pixels while UnitSpriteView flaps — proves GPU shows frame change
extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _snap(vp: SubViewport) -> Image:
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# force draw
	await_process()
	await_process()
	var tex: ViewportTexture = vp.get_texture()
	return tex.get_image()


func await_process() -> void:
	# SceneTree helper: one idle frame
	var done := false
	process_frame.connect(func(): done = true, CONNECT_ONE_SHOT)
	while not done:
		pass


func _run() -> void:
	# Can't busy-wait process_frame in _init path easily — use timer + deferred chain
	_run_async()


func _run_async() -> void:
	var root_win := get_root()
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = true
	vp.handle_input_locally = false
	root_win.add_child(vp)

	var script: Script = load("res://scripts/unit_sprite_view.gd") as Script
	var view := Node2D.new()
	view.set_script(script)
	view.position = Vector2(64, 90)
	vp.add_child(view)

	var tex: Texture2D = UnitSprites.load_texture("dragon", 17)
	view.setup(tex, "spell", 17.0, "dragon", false, 17, true)
	view.set_moving(true, true)
	print("setup state=%s flap=%s puppet=%s fly_n=%d" % [
		view.get("state"), view.call("_dream_has_flap"), view.get("_use_puppet"),
		(view.get("_frames").get("fly", []) as Array).size()
	])

	# settle one frame then snap A
	await get_tree_process()
	await get_tree_process()
	var img_a: Image = vp.get_texture().get_image()
	var dig_a := _digest(img_a)

	# advance ~0.64s of fly anim (8 frames @ 12.5fps ≈ full cycle)
	for _i in range(40):
		view._process(0.08)
	await get_tree_process()
	await get_tree_process()
	var img_b: Image = vp.get_texture().get_image()
	var dig_b := _digest(img_b)

	var out_dir := "res://assets/pixels/_studio/dragon/dream/workbuddy"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var pa := "%s/PROBE_VP_A.png" % out_dir
	var pb := "%s/PROBE_VP_B.png" % out_dir
	img_a.save_png(ProjectSettings.globalize_path(pa))
	img_b.save_png(ProjectSettings.globalize_path(pb))

	var diff := 0
	var n := img_a.get_width() * img_a.get_height()
	for y in range(img_a.get_height()):
		for x in range(img_a.get_width()):
			if img_a.get_pixel(x, y) != img_b.get_pixel(x, y):
				diff += 1
	var frac := float(diff) / float(n)
	print("VP digest A=%s B=%s diff_px=%d frac=%.4f" % [dig_a, dig_b, diff, frac])
	print("sprite tex class A-time was ImageTexture cycle; current=%s" % view.get("_sprite").texture.get_class())
	var ok := frac > 0.002
	print("VP_RENDER %s" % ("PASS" if ok else "FAIL — GPU/viewport shows no change"))
	quit(0 if ok else 1)


func get_tree_process() -> void:
	await process_frame


func _digest(img: Image) -> String:
	if img == null or img.is_empty():
		return "empty"
	var h := 0
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			var c := img.get_pixel(x, y)
			h = int((h * 131 + int(c.r*255) + int(c.g*255)*3 + int(c.b*255)*7 + int(c.a*255)*11) % 2147483647)
	return "h%d" % h
