# 经济公式文档 (ECONOMY FORMULA v1.0)

> 状态：所有数值自 BALANCE_MODEL v1 直接推导；极限检查依据 BALANCE_MODEL §2.2
> Owner：数值设计师
> 交付时附：每族极限策略重算表

## 1. 收入公式（Income）

- **单次击杀奖励**：KILL_REWARD = 基准值（见 BALANCE_MODEL §3.5，默认值经 S1 验证通过）
- **每波清波奖励**：WAVE_BONUS(w) = 40 + 6 × w，其中 w = 波次号 (1..12)
- **总收入公式**：
  I_total = Σ_{kills} KILL_REWARD + Σ_{w=1}^{12} (40 + 6w)
  - 等差数列求和：Σ_{w=1}^{12} (40 + 6w) = 12×40 + 6×(1+2+...+12) = 480 + 6×78 = 480 + 468 = 948
  - 所以总固定波次奖励 = 948 金钱

## 2. 支出公式（Expenditure）

- **单位造价**：COST(unit_id) = config.gd 面板价格
- **进化/升级费**：EVO_COST = BASE_COST × 0.8 × 段数（人族：段数 1..2）
- **出售返还**：SELL_RETURN = COST × 60%
- **每波经济上限**：WAVE_ECONOMIC_LIMIT = 投入总额 × 120%（防止“送死流”刷钱）
- **损耗率目标**：LOSS_RATE ≤ 每波投入的 20%（见 BALANCE_MODEL §3.9）

## 3. 净收益公式（Net Profit per Wave）

- **每波净收益**：
  NP(w) = I(w) - E(w)
  其中：
  - I(w) = KILL_REWARD × monster_count(w) + (40 + 6w)
  - E(w) = Σ单位造价 + 进化/升级费
- **累计净收益**：
  CNP = Σ_{w=1}^{12} NP(w)

## 4. 极限策略检查（LIMIT CHECK）

**核心准则（BALANCE_MODEL §2.2）**：
> 最优策略 vs 最差策略的每波净收益差 ≤ 3×
> 超出即调奖励系数或单位面板，禁止靠砍怪血量掩盖

**检查步骤**：
1. 确定“最优策略”：玩家既有操作又有技能，每波收益最高的打法
2. 确定“最差策略”：玩家无操作、全程基础单位、无技能释放
3. 计算两者每波净收益差：Δ(w) = NP_optimal(w) - NP_worst(w)
4. 验证：max(Δ(w)) ≤ 3 × min(Δ(w))（或 Δ 在可接受阈值范围内）
5. 若未通过：调整 KILL_REWARD 或单位 COST，重新计算

## 5. 参数口径（Data Crib）

| 参数 | 来源 | 备注 |
|------|------|------|
| KILL_REWARD | BALANCE_MODEL §3.6 | 每怪固定金钱 |
| START_MONEY | BALANCE_MODEL §3.10 | 初始  |
| WAVE_BONUS_base | BALANCE_MODEL §3.1 |  |
| WAVE_BONUS_growth | BALANCE_MODEL §3.1 | /波 |
| START_LIVES | BALANCE_MODEL §3.10 | 初始生命值 |
| EVO_MULTIPLIER | BALANCE_MODEL §3.18 | 0.8（人族进化费系数）|
| SELL_RATIO | BALANCE_MODEL §3.19 | 60%（出售返还比例）|

## 5. 交付评审清单

- [ ] 每个种族交付时附带“极限策略重算表”
- [ ] 面板 DPS/金币 对称 ±10%（BALANCE_MODEL §4）
- [ ] 单位生存 HP/移速/体积 符合克制矩阵（RACES.md §5）
- [ ] 每波净收益差 Δ(w) 在可接受阈值内
- [ ] 无“单位造价 > 同级怪总奖励的 120%”违规

---

## 6. 波次经济示例（w=1 与 w=12 对比）

### 波次 1（开局）：
- 怪物数量：配置 Config.WAVE1_MONSTER_COUNT（典型值 2-3）
- 凶猛度：HP0 = 55（Grunt 基准），T_kill ∈ [2.5s, 5s]
- 收入：I(1) = KILL_REWARD × 3 + (40 + 6×1) = 3×KILL_REWARD + 46
- 支出：假设铺 2 步兵（人族），COST ≈ 2 × 100 = 200（见 BALANCE_MODEL §2 的每 100 金币 DPS 基准）
- 净收益：NP(1) = 3×KILL_REWARD + 46 - 200
- 已知 S1 验收通过，意味着 KILL_REWARD 调整后满足 NP(1) ≥ -30（约 10 波内不倒血量）

### 波次 12（终局）：
- 怪物数量：配置 Config.WAVE12_MONSTER_COUNT（典型值 8-10）
- 凶猛度：HP(12) = 55 × 1.10^11 ≈ 55 × 2.85 ≈ 157 单怪血量
- 收入：I(12) = KILL_REWARD × 9 + (40 + 6×12) = 9×KILL_REWARD + 112
- 支出：可能有进化单位 + 技能使用，E(12) ≈ 500（示例）
- 净收益：NP(12) = 9×KILL_REWARD + 112 - 500
- 关键点：此波若 NP(12) < 0 且连续多波为负，则需调 KILL_REWARD 或 WAVE_BONUS_growth

## 7. 关键公式一览表

| 公式 | 作用 | 备注 |
|------|------|------|
| HP(w) = HP0 × 1.10^(w-1) | 怪血成长 | 指数成防止后期消失压力（BALANCE_MODEL §2） |
| DPS_req(w) = Σ HP_i(w) / T_kill_i | DPS 需求 | 波内所有怪求和（BALANCE_MODEL §1） |
| η = 0.9 | 人族基准 DPS/金币 | 每投入 100 金币基准 DPS = 100 × 0.9（BALANCE_MODEL §2） |
| COST × 0.8 × 段数 | 进化费用 | 人族专属，段数 1..2（BALANCE_MODEL §3.18） |
| KILL_REWARD × monster_count + (40 + 6w) | 每波总收入 | 核心经济公式 |
| Loss_Rate ≤ 每波投入的 20% | 损耗率目标 | 防止经济失控（BALANCE_MODEL §3.9） |

---

## 8. 核心数值对照表（从 config.gd 直推）

| 变量 | config.gd 位置 | 推导公式 | 验收标准 |
|------|------|------|-----|
| KILL_REWARD | Config.KILL_REWARD | 经 S1 反推：确保 NP(w) 在可接受范围内 | S1 headless 冒烟 EXIT=0 |
| WAVE_BONUS_base | Config.WAVE_BONUS_BASE = 40 | 直接常数 | S1 12波结算金额匹配 |
| WAVE_BONUS_growth | Config.WAVE_BONUS_GROWTH = 6 | 直接常数 | S1 12波累计奖励 = 948 |
| START_MONEY | Config.START_MONEY = 200 | 初始金钱 | S1 开局生存验证 |
| START_LIVES | Config.START_LIVES = 100 | 初始生命 | S1 12波存活验证 |
| EVO_MULTIPLIER | Config.EVO_MULTIPLIER = 0.8 | 人族进化系数 | S1 进化树可用性验证 |
| SELL_RATIO | Config.SELL_RATIO = 0.6 | 出售返还比例 | S1 资源循环验证 |

## 9. 极限检查验收记录（模板）

> 填写时机：每种族交付前

| 波次 | 最优策略 NP | 最差策略 NP | 差值 Δ | 通过阈值 | 备注 |
|------|------|------|------|------|------|
| 1 | | | | | |
| 2 | | | | | |
| ... | | | | | |
| 12 | | | | | |

**结论**：
- [ ] 通过：Δ(w) 在可接受范围内，所有参数来源可追踪
- [ ] 返工：需调整 KILL_REWARD / COST / WAVE_BONUS，重上限检查

## 10. 结论

- 本模型是 R1-S3 实施的经济学推导基石；所有公式均来源于 BALANCE_MODEL v1
- Owner：数值设计师；交付：每种族交付页 + 此文档
- 下一步：R4（硅基/菌族/龙族）经济表按本模型重算，见 CO-001 实施步骤

---
