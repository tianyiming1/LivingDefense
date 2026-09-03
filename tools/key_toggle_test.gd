extends SceneTree

func _init() -> void:
	var scn: PackedScene = load("res://main.tscn")
	var main: Node = scn.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var hud: Node = main.hud
	print("ZH money = ", hud.money_label.text)
	print("ZH start  = ", hud.start_button.text)
	var ev := InputEventKey.new()
	ev.keycode = KEY_T
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	ev.pressed = false
	Input.parse_input_event(ev)
	await process_frame
	print("EN money = ", hud.money_label.text)
	print("EN start  = ", hud.start_button.text)
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_T
	ev2.pressed = true
	Input.parse_input_event(ev2)
	await process_frame
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await process_frame
	print("ZH2 money = ", hud.money_label.text)
	quit(0)