# CO-045 冒烟：梦龙 14→15→16→17 四阶 + 成龙群眠
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fails: Array[String] = []
	var u14: Dictionary = Config.unit_at("dragon", 14)
	var u15: Dictionary = Config.unit_at("dragon", 15)
	var u16: Dictionary = Config.unit_at("dragon", 16)
	var u17: Dictionary = Config.unit_at("dragon", 17)
	print("VERIFY u14=", u14.get("name"), " evo=", u14.get("evolves_to"))
	print("VERIFY u15=", u15.get("name"), " sleep=", u15.get("sleep_duration"), " evo=", u15.get("evolves_to"))
	print("VERIFY u16=", u16.get("name"), " sleep=", u16.get("sleep_duration"), " evo=", u16.get("evolves_to"))
	print("VERIFY u17=", u17.get("name"), " aoe=", u17.get("sleep_aoe_radius"), " n=", u17.get("sleep_aoe_max"))

	if u14.is_empty() or u15.is_empty() or u16.is_empty() or u17.is_empty():
		fails.append("missing_dream_defs")
	if int(u14.get("evolves_to", -1)) != 15:
		fails.append("whelp_not_to_drake")
	if int(u15.get("evolves_to", -1)) != 16:
		fails.append("drake_not_to_youth")
	if int(u16.get("evolves_to", -1)) != 17:
		fails.append("youth_not_to_adult")
	if int(u17.get("evolves_to", -1)) != -1:
		fails.append("adult_should_be_terminal")
	if not bool(u14.get("buyable", false)):
		fails.append("whelp_should_be_buyable")
	if bool(u15.get("buyable", true)) or bool(u16.get("buyable", true)) or bool(u17.get("buyable", true)):
		fails.append("evo_tiers_must_not_be_shop_buyable")
	if float(u15.get("sleep_duration", 0.0)) < 3.0:
		fails.append("drake_sleep_too_short")
	if float(u16.get("sleep_aoe_radius", 0.0)) > 0.0:
		fails.append("youth_should_not_have_group_aoe")
	if float(u17.get("sleep_aoe_radius", 0.0)) < 70.0:
		fails.append("adult_missing_aoe")
	if int(u17.get("sleep_aoe_max", 0)) < 4:
		fails.append("adult_aoe_max_too_low")
	if float(u17.get("sleep_duration", 0.0)) > 2.6:
		fails.append("adult_group_sleep_should_be_short_window")
	if float(u17.get("sleep_cd", 0.0)) < 7.0:
		fails.append("adult_cd_too_short_for_group")
	if float(u17.get("dream_mist_radius", 0.0)) < 1.0 or float(u17.get("dream_mist_slow", 0.0)) < 0.01:
		fails.append("adult_missing_mist")
	var shop_ids: Array = []
	for u in Config.shop_units("dragon"):
		shop_ids.append(int(u["id"]))
	print("VERIFY shop=", shop_ids)
	if 14 not in shop_ids:
		fails.append("dream_whelp_not_in_shop")
	if 15 in shop_ids or 16 in shop_ids or 17 in shop_ids:
		fails.append("evo_tiers_leaked_into_shop")

	if fails.is_empty():
		print("VERIFY_ACCEPT")
		quit(0)
	else:
		print("VERIFY_FAIL ", ",".join(fails))
		quit(1)
