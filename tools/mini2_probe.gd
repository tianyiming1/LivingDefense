extends SceneTree
var _log: FileAccess

func _init() -> void:
	_log = FileAccess.open("res://tools/mini2_probe.txt", FileAccess.WRITE)
	_log.store_line("A1 init reached")
	_log.flush()
	Engine.time_scale = 5.0
	print("A2 before await")
	await _frames(2)
	print("A3 after await")
	_log.store_line("A4 await ok")
	_log.flush()
	_log.close()
	quit(0)

func _frames(n: int) -> void:
	for i in n:
		await process_frame