extends SceneTree

func _init() -> void:
	var f: FileAccess = FileAccess.open("res://tools/mini_probe.txt", FileAccess.WRITE)
	if f == null:
		print("MINI_FAIL open")
		quit(1)
		return
	f.store_line("MINI_ALIVE t=" + str(Time.get_ticks_msec()))
	f.flush()
	f.close()
	print("MINI_PRINT_OK")
	quit(0)