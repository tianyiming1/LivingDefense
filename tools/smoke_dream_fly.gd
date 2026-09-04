# Smoke: dream idle/fly/walk all advance textures; still-lock off; puppet off
extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _advance(root: Node, n: int = 24, dt: float = 0.08) -> bool:
	var idx0: int = int(root.get("_flap_idx"))
	var changed := false
	for _i in range(n):
		root._process(dt)
		var idx: int = int(root.get("_flap_idx"))
		if idx != idx0:
			changed = true
			break
	return changed


func _run() -> void:
	var script: Script = load("res://scripts/unit_sprite_view.gd") as Script
	var ok := true
	for uid in [14, 15, 16, 17]:
		var tex: Texture2D = UnitSprites.load_texture("dragon", uid)
		var root := Node2D.new()
		root.set_script(script)
		get_root().add_child(root)
		root.setup(tex, "spell", 11.0, "dragon", false, uid, true)
		var puppet: bool = root.get("_use_puppet")
		var frames: Dictionary = root.get("_frames")
		var nfly := 0
		var nidle := 0
		var nwalk := 0
		if frames.has("fly"):
			nfly = (frames["fly"] as Array).size()
		if frames.has("idle"):
			nidle = (frames["idle"] as Array).size()
		if frames.has("walk"):
			nwalk = (frames["walk"] as Array).size()
		var still: bool = root.call("_dream_still_pose")
		var has_flap: bool = root.call("_dream_has_flap")
		print("unit_%d puppet=%s fly=%d idle=%d walk=%d still=%s flap=%s" % [
			uid, puppet, nfly, nidle, nwalk, still, has_flap
		])
		if puppet or nfly < 8 or nidle < 8 or still or not has_flap:
			ok = false
			push_error("bad setup unit_%d" % uid)
		# 完整动作应为 16 帧（fly+land）
		if nfly < 16:
			push_warning("unit_%d fly_frames=%d want 16 complete action" % [uid, nfly])
			ok = false
			push_error("incomplete action unit_%d" % uid)

		# idle flap
		root.set_moving(false, false)
		if not _advance(root):
			push_error("idle did not advance unit_%d" % uid)
			ok = false
		else:
			print("unit_%d idle OK" % uid)

		# fly flap (default move)
		root.set_moving(true, true)
		if root.get("state") != "fly":
			push_error("move+fly expected state=fly got %s unit_%d" % [root.get("state"), uid])
			ok = false
		if not _advance(root):
			push_error("fly did not advance unit_%d" % uid)
			ok = false
		else:
			print("unit_%d fly OK" % uid)

		# Shift-style walk request → must still flap (state fly via set_moving)
		root.set_moving(true, false)
		if root.get("state") != "fly":
			push_error("dream move must force fly, got %s unit_%d" % [root.get("state"), uid])
			ok = false
		if not _advance(root):
			push_error("walk-path did not advance unit_%d" % uid)
			ok = false
		else:
			print("unit_%d walk→fly OK" % uid)

		root.queue_free()
	print("SMOKE %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
