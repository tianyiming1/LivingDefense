# 菌丝网络：以每个菌族单位为圆心向四周扩散；踩丝减速+掉血；菌丝内敌人可被攻击
extends Node2D

var sources: Array[Dictionary] = []  # {pos, radius, grow_mult}
var fever_slow_bonus := 0.0  # 菌毯沸腾：额外减速
var active := false
var _pulse := 0.0
var _edge_sparks: Array[Dictionary] = []

func activate() -> void:
	active = true
	set_process(true)

func seed_from_unit(pos: Vector2, grow_mult: float = 1.0) -> void:
	activate()
	for s in sources:
		if s["pos"].distance_to(pos) < 12.0:
			s["grow_mult"] = maxf(float(s.get("grow_mult", 1.0)), grow_mult)
			queue_redraw()
			return
	sources.append({
		"pos": pos,
		"radius": Config.CARPET_UNIT_SEED_RADIUS,
		"grow_mult": grow_mult,
	})
	_edge_sparks.append({"pos": pos, "life": 0.6, "r": Config.CARPET_UNIT_SEED_RADIUS})
	queue_redraw()

func boost_at(pos: Vector2, mult: float) -> void:
	for s in sources:
		if s["pos"].distance_to(pos) < 20.0:
			s["grow_mult"] = maxf(float(s.get("grow_mult", 1.0)), mult)

# 兼容旧接口
func add_patch(pos: Vector2, radius: float) -> void:
	seed_from_unit(pos, 1.2)
	for s in sources:
		if s["pos"].distance_to(pos) < 20.0:
			s["radius"] = maxf(float(s["radius"]), radius * 0.5)

func spread(wave: int) -> void:
	if not active:
		return
	var bonus: float = float(Config.CARPET_SPREAD_PER_WAVE) * 8.0 + float(wave) * 6.0
	for s in sources:
		s["radius"] = minf(Config.CARPET_MAX_RADIUS, float(s["radius"]) + bonus)
	queue_redraw()

func covers(pos: Vector2) -> bool:
	if not active:
		return false
	for s in sources:
		if pos.distance_to(s["pos"]) <= float(s["radius"]):
			return true
	return false

func effect_at(pos: Vector2) -> Dictionary:
	if not covers(pos):
		return {"on_carpet": false, "slow": 1.0}
	var slow_pct: float = minf(0.5, Config.CARPET_SLOW + fever_slow_bonus)
	return {
		"on_carpet": true,
		"slow": 1.0 - slow_pct,
		"spore": true,
	}

func set_fever(slow_bonus: float) -> void:
	fever_slow_bonus = slow_bonus
	queue_redraw()

func boost_spread(mult: float, _duration: float = 0.0) -> void:
	for s in sources:
		s["grow_mult"] = maxf(float(s.get("grow_mult", 1.0)), mult)

func _process(delta: float) -> void:
	if not active or sources.is_empty():
		return
	_pulse += delta
	for s in sources:
		var grow: float = Config.CARPET_SPREAD_SPEED * float(s.get("grow_mult", 1.0)) * delta
		var prev_r: float = float(s["radius"])
		s["radius"] = minf(Config.CARPET_MAX_RADIUS, prev_r + grow)
		if s["radius"] - prev_r > 0.4 and randf() < 0.08:
			var ang := randf() * TAU
			var edge: Vector2 = s["pos"] + Vector2(cos(ang), sin(ang)) * float(s["radius"])
			_edge_sparks.append({"pos": edge, "life": 0.45, "r": 5.0})
	_tick_sparks(delta)
	queue_redraw()

func _tick_sparks(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for sp in _edge_sparks:
		sp["life"] = float(sp["life"]) - delta
		if float(sp["life"]) > 0.0:
			kept.append(sp)
	_edge_sparks = kept

func _draw() -> void:
	if not active:
		return
	var pulse_a: float = 0.55 + 0.45 * sin(_pulse * 5.0)
	for s in sources:
		var c: Vector2 = s["pos"]
		var r: float = float(s["radius"])
		# 外圈菌丝
		draw_circle(c, r, Color(0.14, 0.42, 0.1, 0.28))
		draw_arc(c, r, 0.0, TAU, 64, Color(0.38, 0.82, 0.25, 0.42 * pulse_a), 2.0, true)
		# 内圈脉络
		if r > 18.0:
			draw_arc(c, r * 0.55, 0.0, TAU, 48, Color(0.45, 0.9, 0.32, 0.15 * pulse_a), 1.2, true)
		# 菌株圆心
		draw_circle(c, 10.0, Color(0.22, 0.55, 0.14, 0.55))
		draw_circle(c, 5.0, Color(0.5, 0.95, 0.38, 0.7 * pulse_a))
		# 扩散前沿脉冲
		draw_arc(c, r, _pulse * 2.0, _pulse * 2.0 + PI * 0.6, 24, Color(0.65, 1.0, 0.45, 0.5 * pulse_a), 3.0, true)
	for sp in _edge_sparks:
		var a: float = float(sp["life"]) / 0.5
		draw_circle(sp["pos"], float(sp["r"]) * a, Color(0.75, 1.0, 0.55, 0.7 * a))
