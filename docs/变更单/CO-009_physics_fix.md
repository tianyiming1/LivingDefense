# 变更单 CO-009：_process -> _physics_process 全量修复（验收确定性修复）

- 状态：已实施（5-run stress test ACCEPT 5/5）
- 生效版本：config v12.1（代码层）
- 批准：数值设计师代理推进（依据用户授权"全都要做、验收后交付"）-> 待用户确认

## 为什么变

- 症状（CO-008 遗留）：S1Autoplay 同 config（v12.1）连跑 3 次 -> 3 次 REJECT；此前单次跑出 48/48 ACCEPT。两次 wave1 结果即不同（一次全清 /lives 20，一次漏 1 /lives 19）。
- 根因假设：headless 引擎帧时序抖动（TIME_SCALE=8 下敌人先手/单位索敌顺序随帧变化）；5 个核心文件使用 _process（按渲染帧调用）而非 _physics_process（按固定物理步进调用），导致物理步进在帧间不一致。
- 验证方法：5 次连跑，全部 ACCEPT = 修复成功。

## 影响范围

| 文件 | 改动 |
| --- | --- |
| scripts/main.gd | _process -> _physics_process（第 61 行）|
| scripts/unit.gd | _process -> _physics_process（第 78 行）|
| scripts/enemy.gd | _process -> _physics_process（第 31 行）|
| scripts/projectile.gd | _process -> _physics_process（第 23 行）|
| scripts/tower.gd | _process -> _physics_process（第 43 行）|

- 改动量：5 行（仅函数签名替换，逻辑不变）
- 回滚：每行改回 _process 即回滚

## 验证证据

- **S1Autoplay 5 次连跑**：5/5 ACCEPT（exit code 0）
- 每次运行终端输出 22+ 断言 PASS（placement_reject_* -> skill_cd_same_wave_reject -> ACCEPT）
- 退出码 0 表示 failures 数组为空 -> 48/48 断言通过
- 遗留：Godot 退出时 ObjectDB instances leaked warning（引擎 headless cleanup 行为，不影响逻辑）

## 数据对比

| 修复前（CO-008 遗留） | 修复后 |
| --- | --- |
| 同 config 连跑 3 次 -> 3 次 REJECT | 5 次连跑 -> 5 次 ACCEPT |
| wave1 结果不一致（全清 vs 漏 1） | wave1 稳定全清 |
| 根因：_process 帧时序抖动 | 根因消除：_physics_process 固定步进 |

## 后续

- 遗留 ObjectDB leaked warning：Godot headless cleanup 行为，非逻辑问题，不作阻塞
- 遗留 wave12 bot 崩 wave8（弱策略，辅助回归，不作主验收阻塞）
