# Full-path smoke: unit.gd + UnitSprites disk load + visual dump
extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	# 1) UnitSprites.load_anim_frames must get 8 distinct fly images
	var frames: Dictionary = UnitSprites.load_anim_frames("dragon", 17)
	var fly: Array = frames.get("fly", []) as Array
	print("load_anim fly count=", fly.size())
	if fly.size() < 8:
		push_error("load_anim_frames failed — this is in-game 平移 root if true")
		ok = false
	else:
		var imgs: Array = []
		for i in range(fly.size()):
			var t: Texture2D = fly[i] as Texture2D
			var im: Image = t.get_image()
			imgs.append(im)
			print("fly_%d %dx%d bytes=%d" % [i, im.get_width(), im.get_height(), im.get_data().size()])
		# consecutive frames must differ
		for i in range(1, imgs.size()):
			if (imgs[i] as Image).get_data() == (imgs[0] as Image).get_data():
				push_error("fly_%d identical to fly_0" % i)
				ok = false
			elif (imgs[i] as Image).get_data() == (imgs[i - 1] as Image).get_data():
				push_error("fly_%d identical to fly_%d" % [i, i - 1])
				ok = false

	# 2) Full unit.gd setup path
	var def: Dictionary = Config.unit_at("dragon", 17)
	var u: Node = load("res://scripts/unit.gd").new()
	get_root().add_child(u)
	u.setup(def, null, null, null, null, "dragon")
	var sv: Node = u.get("_sprite_view")
	if sv == null:
		push_error("no sprite_view")
		ok = false
		quit(1)
		return
	var fr: Dictionary = sv.get("_frames")
	var nfly: int = (fr["fly"] as Array).size() if fr.has("fly") else 0
	var still: bool = sv.call("_dream_still_pose")
	var puppet: bool = sv.get("_use_puppet")
	var proc: bool = sv.is_processing()
	print("unit path: fly=%d still=%s puppet=%s processing=%s state=%s" % [nfly, still, puppet, proc, sv.get("state")])
	if nfly < 8 or still or puppet or not proc:
		ok = false
		push_error("unit sprite_view bad setup")

	# 3) Simulate move like physics_process would
	u.set("_order", "move")
	u.set("_order_pos", u.position + Vector2(400, 0))
	u.set("_order_fly", true)
	u.set("_combat", true)
	var tex_hashes: Array = []
	var changed := 0
	var last_h := -1
	for i in range(40):
		# drive unit physics + sprite _process
		u._physics_process(0.05)
		sv._process(0.05)
		var tex: Texture2D = sv.get("_sprite").texture
		var h: int = 0
		if tex != null:
			var im2: Image = tex.get_image()
			# sample center + corners as cheap fingerprint
			h = int(im2.get_pixel(48, 40).r * 255) * 1000000
			h += int(im2.get_pixel(30, 50).g * 255) * 1000
			h += int(im2.get_pixel(60, 55).b * 255)
		tex_hashes.append(h)
		if last_h >= 0 and h != last_h:
			changed += 1
		last_h = h
		print("t=%d state=%s fp=%d pos=%s" % [i, sv.get("state"), h, u.position])
	print("texture_changes=%d / 40" % changed)
	if changed < 4:
		push_error("moving unit texture barely changed — 平移 confirmed in unit path")
		ok = false

	# dump evidence strip
	var out_dir := "res://assets/pixels/_studio/dragon/dream/workbuddy"
	var abs_dir := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	# save current 8 fly frames as engine sees them
	if fly.size() >= 8:
		for i in range(8):
			var im: Image = (fly[i] as Texture2D).get_image()
			im.save_png(abs_dir.path_join("SMOKE_ENGINE_FLY_%d.png" % i))

	print("SMOKE_UNIT %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
