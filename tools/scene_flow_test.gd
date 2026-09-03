extends SceneTree

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _init() -> void:
	# 1) 菜单：默认中文
	var scn: PackedScene = load("res://menu.tscn")
	var menu: Node = scn.instantiate()
	root.add_child(menu)
	await _frames(2)
	print("M1 title = ", menu.title_label.text)
	print("M1 start = ", menu.start_button.text)
	print("M1 lang  = ", menu.lang_button.text)
	if menu.title_label.text != "活体防线":
		print("FLOW_FAIL default zh title")
		quit(1)
		return
	# 2) 菜单点语言按钮 → 英文
	menu.lang_button.pressed.emit()
	await _frames(1)
	print("M2 lang  = ", menu.lang_button.text)
	if menu.lang_button.text != "Language: English":
		print("FLOW_FAIL lang switch")
		quit(1)
		return
	# 3) 开始游戏 → main.tscn
	menu.start_button.pressed.emit()
	await _frames(4)
	var main: Node = root.get_node_or_null("Main")
	if main == null:
		print("FLOW_FAIL main scene not loaded")
		quit(1)
		return
	print("G1 money = ", main.hud.money_label.text)
	if main.hud.money_label.text != "Money: $300":
		print("FLOW_FAIL language not kept in game")
		quit(1)
		return
	# 4) 游戏内菜单按钮 → 返回 menu.tscn
	main.hud.menu_button.pressed.emit()
	await _frames(4)
	var menu2: Node = root.get_node_or_null("Menu")
	if menu2 == null:
		print("FLOW_FAIL back to menu not loaded")
		quit(1)
		return
	print("M3 lang  = ", menu2.lang_button.text)
	if menu2.lang_button.text != "Language: English":
		print("FLOW_FAIL language not kept on return")
		quit(1)
		return
	print("FLOW_PASS")
	quit(0)