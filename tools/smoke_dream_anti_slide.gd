# Anti-平移 gate: flap must advance even when set_moving idle↔fly oscillates every frame
extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	var script: Script = load("res://scripts/unit_sprite_view.gd") as Script
	var root := Node2D.new()
	root.set_script(script)
	get_root().add_child(root)
	var tex: Texture2D = UnitSprites.load_texture("dragon", 17)
	root.setup(tex, "spell", 17.0, "dragon", false, 17, true)
	if not bool(root.call("_dream_has_flap")):
		push_error("no flap")
		ok = false
	# 模拟战场：位移阈值抖动 → set_moving 每帧翻 idle/fly
	var seen: Dictionary = {}
	for i in range(48):
		root.set_moving(i % 2 == 0, true) # oscillate
		root._process(0.08) # 一帧约一索引 @12.5fps
		var idx: int = int(root.get("_flap_idx"))
		seen[idx] = true
		print("i=%d state=%s flap_idx=%d" % [i, root.get("state"), idx])
	var uniq: int = seen.size()
	print("unique_flap_idx=%d" % uniq)
	if uniq < 6:
		push_error("oscillating set_moving froze flap — 平移 root still present")
		ok = false
	# unit.gd path with sep-like tiny moves
	var def: Dictionary = Config.unit_at("dragon", 17)
	var u: Node = load("res://scripts/unit.gd").new()
	get_root().add_child(u)
	u.setup(def, null, null, null, null, "dragon")
	u.set("_order", "move")
	u.set("_order_pos", u.position + Vector2(300, 0))
	u.set("_order_fly", true)
	u.set("_combat", true)
	var sv: Node = u.get("_sprite_view")
	var seen2: Dictionary = {}
	for i in range(60):
		# alternate large / tiny displacement like sep jitter
		if i % 3 == 0:
			u.position += Vector2(0.2, 0) # below moving threshold
		else:
			u.position += Vector2(4.0, 0)
		u._physics_process(0.05)
		sv._process(0.05)
		seen2[int(sv.get("_flap_idx"))] = true
	print("unit_path unique_flap_idx=%d" % seen2.size())
	if seen2.size() < 6:
		push_error("unit path flap frozen")
		ok = false
	print("ANTI_SLIDE %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
