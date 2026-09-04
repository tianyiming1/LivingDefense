# Headless smoke: Path A puppet loads + cycles states; dumps stills.
# Usage: Godot --headless --path <project> --script res://tools/smoke_dream_puppet.gd
extends SceneTree

const OUT := "res://assets/pixels/_studio/dragon/dream/hand_anim/PUPPET_SMOKE"

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	var script: Script = load("res://scripts/unit_sprite_view.gd") as Script
	var ok_all := true
	for uid in [14, 15, 16, 17]:
		var meta_p := "res://assets/pixels/dragon/unit_%d_puppet/meta.json" % uid
		var body_p := "res://assets/pixels/dragon/unit_%d_puppet/body.png" % uid
		print("check %d meta=%s body=%s" % [uid, FileAccess.file_exists(meta_p), FileAccess.file_exists(body_p)])
		var tex: Texture2D = UnitSprites.load_texture("dragon", uid)
		if tex == null:
			push_error("missing base tex %d" % uid)
			ok_all = false
			continue
		var root := Node2D.new()
		root.name = "smoke_%d" % uid
		root.set_script(script)
		get_root().add_child(root)
		root.setup(tex, "spell", 11.0, "dragon", false, uid, true)
		var use_puppet: bool = root.get("_use_puppet")
		var dual: bool = root.get("_dual_wing")
		print("unit_%d puppet=%s dual=%s" % [uid, use_puppet, dual])
		if not use_puppet:
			push_error("puppet not enabled for %d" % uid)
			ok_all = false
		for st in ["idle", "walk", "fly", "attack"]:
			if st == "walk" or st == "fly":
				root.set_moving(true, st == "fly")
			elif st == "attack":
				root.start_shoot()
			else:
				root.set_moving(false, false)
			for _i in range(8):
				root._process(0.05)
			var f := FileAccess.open("%s/u%d_%s.txt" % [dir, uid, st], FileAccess.WRITE)
			if f:
				f.store_string("state=%s puppet=%s\n" % [str(root.get("state")), str(use_puppet)])
				f.close()
		root.queue_free()
	print("SMOKE %s" % ("PASS" if ok_all else "FAIL"))
	quit(0 if ok_all else 1)
