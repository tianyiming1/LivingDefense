# 12 娉㈣嚜鍔ㄨ禌璺戝洖褰?v6 鈥斺€?绋嬪簭鍖栨壘鐐癸紙_can_place 鏉冨▉锛夛紜鏀剧疆鏍￠獙锛屾潨缁濇閿?extends SceneTree

const LOG_PATH := "res://tools/wave12_progress.log"

var main: Node
var _log: FileAccess
var _stall_frames := 0
var _last_key := ""
var spots: Array[Vector2] = []

func _init() -> void:
	Engine.time_scale = 5.0
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_log.store_line("T0=" + str(Time.get_ticks_msec()))
	_log.flush()
	var scn: PackedScene = load("res://main.tscn")
	if scn == null:
		_wl("FAIL load main.tscn")
		quit(1)
		return
	main = scn.instantiate()
	root.add_child(main)
	await _frames(3)
	if main == null or main.hud == null:
		_wl("FAIL main not ready")
		quit(1)
		return
	_find_spots()
	if spots.size() < 10:
		_wl("FAIL only " + str(spots.size()) + " legal spots found")
		quit(1)
		return
	_run()

func _find_spots() -> void:
	# v10 甯冮槻甯︼細璐磋矾寰勫缂?offset=50(<姝ュ叺灏勭▼55), 鍏ㄧ▼ 8 娈靛悇鍙?2 涓?t 涓や晶
	# CO-008-B4锛氫慨澶嶆彁鍓?break鈥斺€斿師 10 涓婇檺璁╁墠 3 娈靛婊″悗 5 娈甸浂闃诧紱鏀规瘡娈甸厤棰?2 渚т絾鍏ㄧ▼瑕嗙洊
	var pts: Array = Config.PATH_POINTS
	var min_dist: float = float(Config.TOWER_MIN_DIST) + 6.0
	var offset: float = float(Config.PATH_HALF_WIDTH) + float(Config.UNIT_RADIUS) + 4.0
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d: Vector2 = (b - a).normalized()
		var n: Vector2 = Vector2(-d.y, d.x)
		var seg_len: float = a.distance_to(b)
		for t in [seg_len * 0.25, seg_len * 0.7]:
			for side in [1.0, -1.0]:
				var p: Vector2 = a + d * t + n * (offset * side)
				if not main._can_place(p):
					continue
				var far_enough := true
				for s in spots:
					if p.distance_to(s) < min_dist:
						far_enough = false
						break
				if far_enough:
					spots.append(p)
					_wl('spot ' + str(spots.size()) + ' = ' + str(p) + '  seg=' + str(i))
func _wl(s: String) -> void:
	_log.store_line(s)
	_log.flush()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _place(unit_id: int, pos: Vector2) -> bool:
	if main.money < int(Config.HUMAN_UNITS[unit_id]["cost"]):
		return false
	var before: int = main.units_layer.get_child_count()
	main._on_buy_requested(unit_id)
	main._try_place(pos)
	main._cancel_placement()
	await _frames(1)
	return main.units_layer.get_child_count() == before + 1

func _buy_plan() -> bool:
	# v11锛氳繘鍖栦紭鍏堬紝琛ュ叺鎹綅閲嶈瘯锛坰pot 琚嚜宸变汉鎴樹綅鎸″氨璇曚笅涓€涓級
	# CO-008-B4锛氱紪鎴愬寮衡€斺€斿墠 3 spot 鏀炬鍏?椤跺墠鎷︽埅)锛屽叾浣?spot 琛ョ伀鏋?175 杩滅▼绔欐々)锛?	# 瑙ｅ喅"绾鍏佃娉?-8 Grunt 缇ゆ鍥㈢伃銆佹棤杩滅▼鐏姏"鐨勭瓥鐣ョ己闄?	var evolved_any := true
	while evolved_any:
		evolved_any = false
		for u in main.units_layer.get_children():
			if int(u.def.get('evolves_to', -1)) >= 0:
				var cost: int = u.evolve_cost()
				if main.money >= cost:
					main._on_unit_click(u.position)
					main._on_evolve()
					await _frames(1)
					evolved_any = true
					break
	var front_count := 0
	for u in main.units_layer.get_children():
		if int(u.def.get("id", -1)) == 0:
			front_count += 1
	# 缂栨垚绛栫暐锛圕O-008-B4锛夛細
	# - 鍓嶆帓 2 姝ュ叺(椤跺墠鎷︽埅) + 涓悗鎺掔伀鏋?杩滅▼)锛屽崟浣嶆暟 >= 5 鏃惰ˉ 1 鐗у笀(鍏夌幆)
	# - 鍏ㄧ▼浼樺厛杩涘寲锛堟鍏碘啋鐏灙鈫掕揩鍑荤偖锛?	# - BUG 淇锛氳ˉ鍛樻瘡娆′粠 spot 0 閲嶆壂绗竴涓?褰撳墠鏃犱汉"鐨勭┖浣嶏紝姝讳骸鍗曚綅鑵惧嚭鐨勯槻绾垮繀琚洖琛?	#   锛堝師 idx=k+1 鍗曞悜閫掑 鈫?鍓嶆姝讳骸 spot 姘镐笉琛?鈫?闃茬嚎瓒婃墦瓒婅杽 鈫?娉?7-8 宕╋級
	var target_count: int = mini(spots.size(), 8)  # 闃茬嚎涓婇檺 8 鍗曚綅锛堢粡娴庝笌鐏姏骞宠　鐐癸級
	while main.units_layer.get_child_count() < target_count and main.money >= int(Config.HUMAN_UNITS[0]['cost']):
		var placed := false
		for k in range(spots.size()):
			var unit_id := 0  # 榛樿姝ュ叺
			if front_count >= 2:
				unit_id = 1  # 鐏灙
			var n_units: int = main.units_layer.get_child_count()
			if n_units >= 5 and not _has_cleric():
				unit_id = 4  # 鐗у笀锛堝厜鐜?+15% 鏀婚€燂級
			var cost := int(Config.HUMAN_UNITS[unit_id]['cost'])
			if main.money < cost:
				continue
			var ok: bool = await _place(unit_id, spots[k])
			if ok:
				placed = true
				if unit_id == 0:
					front_count += 1
				break
		if not placed:
			_wl('NO_FREE_SPOT money=' + str(main.money))
			break
	return true

func _has_cleric() -> bool:
	for u in main.units_layer.get_children():
		if int(u.def.get("id", -1)) == 4:
			return true
	return false
func _progress_key() -> String:
	var ec := 0
	for e in main.enemies_layer.get_children():
		if e.alive:
			ec += 1
	return "%d/%d/%d/%d" % [main.wave_index, main.lives, ec, main.units_layer.get_child_count()]

func _check_stall() -> void:
	var k: String = _progress_key()
	if k == _last_key:
		_stall_frames += 1
		if _stall_frames >= 1500:
			_wl("STALL " + _progress_key())
			quit(1)
	else:
		_last_key = k
		_stall_frames = 0

func _run() -> void:
	var t0: int = Time.get_ticks_msec()
	var frames := 0
	while main.state != main.GameState.WIN and main.state != main.GameState.GAME_OVER:
		if main.state == main.GameState.PLANNING:
			var ok: bool = await _buy_plan()
			if not ok:
				return
			await _frames(1)
			main._on_start_wave()
			await _frames(2)
			if main.state == main.GameState.WAVING:
				main._on_skill()
			_wl("wave " + str(main.wave_index) + " start  dt=" + str((Time.get_ticks_msec() - t0) / 1000.0) + "s money=" + str(main.money) + " lives=" + str(main.lives) + " units=" + str(main.units_layer.get_child_count()))
		frames += 1
		if frames % 900 == 0:
			_wl("hb " + str(frames) + " " + _progress_key())
		await process_frame
		_check_stall()
		if Time.get_ticks_msec() - t0 > 420000:
			_wl("FAIL timeout at wave " + str(main.wave_index))
			quit(1)
			return
		if frames >= 30000:
			_wl("FAIL frame cap")
			quit(1)
			return
	if main.state == main.GameState.WIN:
		_wl("PASS 12 waves cleared, lives=" + str(main.lives) + " lost=" + str(main.units_lost) + " dt=" + str((Time.get_ticks_msec() - t0) / 1000.0) + "s")
		quit(0)
	else:
		_wl("FAIL game over at wave " + str(main.wave_index) + " lost=" + str(main.units_lost))
		quit(1)