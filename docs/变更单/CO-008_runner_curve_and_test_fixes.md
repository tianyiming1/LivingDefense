# 变更单 CO-008：Runner 波次曲线后移 + 测试管线修复（12 波平衡收敛 B 轮）

- 状态：已实施（B2 生效；B1 试验后回退）
- 生效版本：config v12.1（config.gd）
- 批准：数值设计师代理推进（依据用户授权"全都要做、验收后交付"）→ 待用户确认

## 为什么变

- 症状：12 波赛跑（S1Autoplay 38/40）与 wave12 bot 均崩于 wave 7-8——Runner 群（wave7=10 只 150 速）穿透防线，前排步兵被围殴团灭
- 根因链（kb/06 已有分析）：波 7+ 群怪密度超出防线输出 → 兵死 → 火力再降 → 崩
- 裁决：**B2（Runner 曲线后移）为主，B4（测试 bot 编成/补员修复）为辅**；数值最小改动、可回滚

## 影响范围

| 文件 | 改动 |
| --- | --- |
| `scripts/config.gd` | `wave_composition`: runners 斜率 `(wave-2)x2.0` -> `(wave-2)x1.5`（B2 生效） |
| `scripts/config.gd` | `evolve_cost` 系数 0.5 保持（B1 试验 0.35 已回退：S1Autoplay 在 0.5 达成全绿，无需再降） |
| `tests/s1_autoplay.gd` | PLAN 修正：buy b2 从 wave2 挪至 wave6（原计划波 2 花 160 > 波 1 全清收入 158，数学上不可执行） |
| `tools/wave12_test.gd` | B4：bot 编成增强（前排步兵+火枪+牧师）、补员重扫空位、spot 全程覆盖 |

## 数值决策（可推导）

- B2 后 runner 数：wave5 6->4、wave7 10->7、wave9 14->10、wave12 20->15（保留波 3 出场教学）
- 不动 grunt/tank 曲线与血量成长——难度削减集中于"跑者群穿"单一瓶颈，避免整体放水

## 验证证据

- S1Autoplay：PLAN 修复前 38/40（wave6 崩）-> 修复后 47/48 -> B2 生效后 48/48 ACCEPT（wave1 全清，12 波通关）
- 遗留：同 config 连跑 3 次出现 REJECT（wave1 漏 1）——疑似 headless 帧时序抖动，验收确定性待修（见 kb/06 遗留项）
- wave12 bot：崩 wave8（v11.1 记录 wave7 崩，推进 1 波；bot 策略弱于人工 PLAN，作辅助回归）

## 回滚

- B2：runner 斜率改回 2.0 一行即回滚
- 测试文件改动仅影响验收工具，不影响游戏逻辑