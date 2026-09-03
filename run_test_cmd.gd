# Simple test runner — run from command line via --script
extends SceneTree

func _init():
	print("[TEST] Starting S1Autoplay runner...")
	var scn = load("res://tests/S1Autoplay.tscn")
	if scn:
		var instance = scn.instantiate()
		get_root().add_child(instance)
		print("[TEST] Scene loaded and instanced successfully")
	else:
		print("[FAIL] Could not load S1Autoplay.tscn")
		quit(1)
	# Let the scene run; it calls quit() when done
	quit(0)
