# Probe: Unit path + pixel content advance (not just Texture2D object identity)
extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _pixel_digest(tex: Texture2D) -> String:
	if tex == null:
		return "null"
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return "noimg_%s_%dx%d" % [tex.get_class(), tex.get_width(), tex.get_height()]
	# sample grid hash
	var h := 0
	var w := img.get_width()
	var ht := img.get_height()
	for y in range(0, ht, 4):
		for x in range(0, w, 4):
			var c: Color = img.get_pixel(x, y)
			h = int((h * 131 + int(c.r * 255) + int(c.g * 255) * 3 + int(c.b * 255) * 7 + int(c.a * 255) * 11) % 2147483647)
	return "%s_%dx%d_h%d" % [tex.get_class(), w, ht, h]


func _content_changed(a: Texture2D, b: Texture2D) -> bool:
	return _pixel_digest(a) != _pixel_digest(b)


func _advance_content(root: Node, n: int = 40, dt: float = 0.08) -> Dictionary:
	var tex0: Texture2D = root.get("_sprite").texture
	var obj_changed := false
	var content_changed := false
	var digests: Array = [_pixel_digest(tex0)]
	for _i in range(n):
		root._process(dt)
		var cur: Texture2D = root.get("_sprite").texture
		if cur != tex0:
			obj_changed = true
		if _content_changed(tex0, cur):
			content_changed = true
			digests.append(_pixel_digest(cur))
			break
	return {
		"obj": obj_changed,
		"content": content_changed,
		"digests": digests,
		"state": root.get("state"),
		"frame_t": root.get("_frame_t"),
	}


func _run() -> void:
	print("=== disk frames visual uniqueness ===")
	for uid in [14, 15, 16, 17]:
		var frames: Dictionary = UnitSprites.load_anim_frames("dragon", uid)
		var fly: Array = frames.get("fly", [])
		var digs: Array = []
		for t in fly:
			digs.append(_pixel_digest(t))
		var uniq := {}
		for d in digs:
			uniq[d] = true
		print("unit_%d fly_n=%d unique_content=%d digests=%s" % [uid, fly.size(), uniq.size(), str(digs)])

	print("=== UnitSprites.load_texture vs fly_0 ===")
	for uid in [14, 15, 16, 17]:
		var base: Texture2D = UnitSprites.load_texture("dragon", uid)
		var frames2: Dictionary = UnitSprites.load_anim_frames("dragon", uid)
		var fly0: Texture2D = (frames2["fly"] as Array)[0] as Texture2D
		print("unit_%d base=%s fly0=%s same_content=%s" % [
			uid, _pixel_digest(base), _pixel_digest(fly0), str(not _content_changed(base, fly0))
		])

	print("=== Unit.gd spawn path ===")
	var unit_script: Script = load("res://scripts/unit.gd") as Script
	var ok := true
	for uid in [14, 15, 16, 17]:
		var def: Dictionary = Config.unit_at("dragon", uid).duplicate(true)
		print("unit_%d def keys can_fly_move=%s hover_idle=%s kind=%s race_field_n/a stationary_flag=%s" % [
			uid, str(def.get("can_fly_move")), str(def.get("hover_idle")), str(def.get("kind")), str(def.get("stationary", false))
		])
		var u: Node = unit_script.new()
		get_root().add_child(u)
		u.setup(def, Node2D.new(), Node2D.new(), Node2D.new(), null, "dragon")
		var sv: Node = u.get("_sprite_view")
		if sv == null:
			push_error("no sprite_view unit_%d" % uid)
			ok = false
			u.queue_free()
			continue
		var stationary_arg: bool = sv.get("_stationary")
		var puppet: bool = sv.get("_use_puppet")
		var still: bool = sv.call("_dream_still_pose")
		var flap: bool = sv.call("_dream_has_flap")
		var frames3: Dictionary = sv.get("_frames")
		var nfly: int = (frames3.get("fly", []) as Array).size()
		print("unit_%d sv stationary=%s puppet=%s still=%s flap=%s fly=%d process=%s" % [
			uid, stationary_arg, puppet, still, flap, nfly, str(sv.is_processing())
		])
		if puppet or still or not flap or nfly < 4:
			ok = false
			push_error("bad flags unit_%d" % uid)

		# idle content advance WITHOUT set_moving
		var r_idle: Dictionary = _advance_content(sv)
		print("unit_%d idle_advance obj=%s content=%s state=%s digests=%s" % [
			uid, r_idle["obj"], r_idle["content"], r_idle["state"], str(r_idle["digests"])
		])
		if not r_idle["content"]:
			ok = false
			push_error("idle content DID NOT change unit_%d" % uid)

		# simulate path follow: set_moving like unit._sprite_set_moving
		u.set("_order", "move")
		u.set("_order_fly", true)
		u.call("_sprite_set_moving", true)
		print("unit_%d after set_moving state=%s want_fly=%s" % [uid, sv.get("state"), sv.get("_want_fly")])
		if sv.get("state") != "fly":
			ok = false
			push_error("expected fly state unit_%d got %s" % [uid, sv.get("state")])
		var r_fly: Dictionary = _advance_content(sv)
		print("unit_%d fly_advance obj=%s content=%s digests=%s" % [
			uid, r_fly["obj"], r_fly["content"], str(r_fly["digests"])
		])
		if not r_fly["content"]:
			ok = false
			push_error("fly content DID NOT change unit_%d" % uid)

		u.queue_free()

	print("=== ResourceLoader vs disk for fly_0..1 ===")
	for uid in [14]:
		var p0 := "res://assets/pixels/dragon/unit_%d_anim/fly_0.png" % uid
		var p1 := "res://assets/pixels/dragon/unit_%d_anim/fly_1.png" % uid
		var disk0: Texture2D = UnitSprites.load_disk_tex(p0, true)
		var disk1: Texture2D = UnitSprites.load_disk_tex(p1, true)
		var rl0: Texture2D = null
		var rl1: Texture2D = null
		if ResourceLoader.exists(p0):
			rl0 = load(p0) as Texture2D
		if ResourceLoader.exists(p1):
			rl1 = load(p1) as Texture2D
		print("RL exists0=%s exists1=%s" % [ResourceLoader.exists(p0), ResourceLoader.exists(p1)])
		print("disk content differ=%s dig0=%s dig1=%s" % [
			_content_changed(disk0, disk1), _pixel_digest(disk0), _pixel_digest(disk1)
		])
		if rl0 != null and rl1 != null:
			print("RL content differ=%s dig0=%s dig1=%s" % [
				_content_changed(rl0, rl1), _pixel_digest(rl0), _pixel_digest(rl1)
			])
			print("RL0 vs disk0 same=%s" % str(not _content_changed(rl0, disk0)))

	print("PROBE %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
