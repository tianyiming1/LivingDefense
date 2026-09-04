# CO-044 搁置期冒烟：四族公开 + 彩蛋可买 + 解锁事件未入池
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fails: Array[String] = []
	var pub: Array[String] = Config.public_race_ids()
	print("VERIFY public=", pub)
	if not pub.has("dragon"):
		fails.append("dragon_should_be_public_while_parked")
	if Config.is_race_hidden("dragon"):
		fails.append("dragon_hidden_flag_should_be_false")

	var shop: Array = Config.shop_units("dragon")
	var ids: Array = []
	for u in shop:
		ids.append(int(u["id"]))
	print("VERIFY shop=", ids)
	if 12 not in ids or 13 not in ids or 14 not in ids:
		fails.append("easter_units_should_be_buyable_while_parked")

	var pool_src := FileAccess.get_file_as_string("res://scripts/event_bus.gd")
	# POOL 数组段内不应再挂这两行（处理函数可保留）
	var pool_block := pool_src.substr(0, pool_src.find("func setup"))
	if pool_block.find("\"dragon_shadow_omen\"") >= 0 or pool_block.find("\"scale_vault\"") >= 0:
		fails.append("unlock_events_still_in_pool")

	var menu_src := FileAccess.get_file_as_string("res://scripts/menu.gd")
	if menu_src.find("SECRET_TITLE_CLICKS") >= 0 or menu_src.find("_on_title_gui_input") >= 0:
		fails.append("menu_title_click_must_stay_dead")

	if fails.is_empty():
		print("VERIFY_ACCEPT")
		quit(0)
	else:
		print("VERIFY_FAIL ", ",".join(fails))
		quit(1)
