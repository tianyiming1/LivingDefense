extends SceneTree

func _init() -> void:
	TranslationServer.set_locale("zh_CN")
	print("zh unit_0 = ", tr("unit_0"))
	print("zh hud_start = ", tr("hud_start"))
	print("zh stat_line = ", tr("stat_line"))
	TranslationServer.set_locale("en")
	print("en unit_4 = ", tr("unit_4"))
	print("en overlay_defeat = ", tr("overlay_defeat"))
	quit()