# 冒烟：确认梦龙/龙人分帧能被 ResourceLoader 找到
extends SceneTree

func _init() -> void:
	var fails: Array[String] = []
	for uid in [3, 14, 15, 16, 17]:
		var frames: Dictionary = UnitSprites.load_anim_frames("dragon", uid)
		for clip in ["idle", "walk", "fly", "attack", "death"]:
			if not frames.has(clip):
				fails.append("u%d_missing_%s" % [uid, clip])
			else:
				var n: int = (frames[clip] as Array).size()
				if n < 2:
					fails.append("u%d_%s_short_%d" % [uid, clip, n])
				print("OK u", uid, " ", clip, " n=", n)
	if fails.is_empty():
		print("VERIFY_ACCEPT anim_frames_loaded")
		quit(0)
	else:
		print("VERIFY_REJECT ", ",".join(fails))
		quit(1)
