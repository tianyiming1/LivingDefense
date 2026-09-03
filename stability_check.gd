# ============================================================
# R-ENG2 验收稳定性验证（连跑 S1Autoplay）
# 运行：Godot --headless --path . -s res://stability_check.gd
# ============================================================
extends SceneTree

const RUNS := 5
var results := []
var current_run := 0

func _init():
    Engine.time_scale = 1.0
    _run_next()

func _run_next():
    if current_run >= RUNS:
        _analyze()
        return
    
    current_run += 1
    var scn := load("res://tests/s1_autoplay.tscn")
    if scn == null:
        print("FAIL: load s1_autoplay.tscn")
        _analyze()
        return
    
    var test := scn.instantiate()
    add_child(test)
    await get_tree().process_frame
    
    # 启动监控器
    var mon := _Monitor.new()
    mon.run_idx = current_run
    mon.test_scene = test
    mon.on_done.connect(_on_run_done)
    add_child(mon)

func _on_run_done(data: Dictionary):
    results.append(data)
    print("Run %d: %s (g=%d,l=%d)" % [data.run, data.status, data.w1g, data.lives])
    _run_next()

func _analyze():
    print("\n===== 稳定性验证结果 =====")
    var first := results[0]["status"] if results.size() > 0 else "?"
    var ok := true
    for r in results:
        if r["status"] != first:
            ok = false
            break
    for r in results:
        print("  Run %d: %s (g=%d,l=%d)" % [r.run, r.status, r.w1g, r.lives])
    if ok:
        print("一致性: PASS - 全部 %s" % first)
        print("判定: R-ENG2 根因已修复")
    else:
        print("一致性: FAIL - 不一致")
        print("判定: 根因未修复")
    get_tree().quit(0 if ok else 1)


class _Monitor extends Node:
    signal on_done(data: Dictionary)
    var run_idx := 0
    var test_scene := Node.new()
    var w1g := -1
    var lives_val := -1
    var status_val := "UNKNOWN"
    
    func _ready():
        _poll()
    
    func _poll():
        if test_scene and test_scene.has_node_or_null("main"):
            var m = test_scene.get_node("main")
            if m:
                w1g = _get_w1g(m)
                lives_val = _get_lives(m)
                status_val = _get_status(m)
                var data := {"run": run_idx, "status": status_val, "w1g": w1g, "lives": lives_val}
                on_done.emit(data)
                queue_free()
                return
        await get_tree().process_frame
        _poll()
    
    func _get_w1g(m):
        if m.has_method("_get_wave1_gold"):
            return m._get_wave1_gold()
        return -1
    
    func _get_lives(m):
        if m.has_method("get_lives"):
            return int(m.lives)
        return -1
    
    func _get_status(m):
        if m.has_node_or_null("autoplay"):
            var ap = m.get_node("autoplay")
            if ap and ap.has_method("_get_result"):
                return ap._get_result()
        return "UNKNOWN"
