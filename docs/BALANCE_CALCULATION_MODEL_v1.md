# 平衡计算模型 v1（BALANCE_CALCULATION_MODEL）

> **定位**：从 `config.gd` 常量出发，用公式推导攻击力、防御力、兵种配置、波次难度与经济是否闭合。  
> **Owner**：数值设计师；每次 CO 数值变更须附本模型重算页。  
> **实现层单一来源**：`scripts/config.gd`；本文件为推导方法，不替代 config。

---

## 0. 计算流水线（工作室标准作业）

```
① 读 config 常量 → ② 波次矩阵 → ③ DPS/承伤/EHP → ④ 经济收支 → ⑤ 种族对称检查
        ↓                                                              ↓
⑥ 参考策略 PLAN 闭合性检查                              ⑦ S1/S2 Autoplay 5-run 验证
```

**工具**：`tools/balance_calc.py`（离线推演，无需 Godot）

---

## 1. 符号表

| 符号 | 含义 |
|------|------|
| \(w\) | 波次 1..12 |
| \(\text{HP}_e(w)\) | 敌人血量 `enemy_hp(id, w)` |
| \(\text{DPS}_u\) | 单位面板秒伤 `damage × rate` |
| \(\text{EHP}_u\) | 单位有效生命（见 §3） |
| \(\text{DPS}_{\text{req}}(w)\) | 波次最低输出需求 |
| \(I(w)\) | 波次金币收入 |
| \(E(w)\) | 波次金币支出 |
| \(F(w)\) | 波次食物收入（人族/菌/龙） |
| \(O(w)\) | 波次矿石收入（硅基） |

---

## 2. 战斗层：攻击与击杀时间

### 2.1 面板 DPS

\[
\text{DPS}_{\text{panel}} = \text{damage} \times \text{rate} \times \text{as\_buff} \times \text{aura\_mult}
\]

- `as_buff`：技能 Rally Fire = 1.5（8s 窗口内）
- `aura_mult`：牧师光环 = 1.15
- 菌族分裂：`damage × 0.62^{split\_tier}`

### 2.2 有效 DPS（机制补偿）

\[
\text{DPS}_{\text{eff}} = \text{DPS}_{\text{panel}} \times (1 + \sum \text{mech\_bonus})
\]

| 机制 | 折算方法（估算） |
|------|------------------|
| 菌毯减速 22% | \(t_{\text{in\_range}} \times 1/0.78 \approx +28\%\) 等效输出 |
| 毒 DOT 1.2/s × 3s | 每命中 +3.6 伤害，折算入 DPS |
| 溅射多目标 | \(\text{DPS} \times \min(N_{\text{cluster}}, N_{\text{cap}})\)，\(N_{\text{cap}}=3\) 保守 |
| 近战卡位 | 不增 DPS，增 \(t_{\text{exposed}}\)（敌人停步） |

### 2.3 击杀时间约束（骨架铁律）

\[
T_{\text{kill}} \in [2.5,\ 5.0]\ \text{秒（单怪在有效射程内）}
\]

\[
\text{DPS}_{\text{req}}(w) = \frac{\sum_{i \in \text{wave}(w)} \text{HP}_i(w)}{T_{\text{kill}}}
\]

**波次总血量**（config 公式）：

```text
HP(w, id) = ENEMIES[id].hp × (1 + (w-1) × 0.16)
wave(w): grunts = 3+w, runners = max(0, (w-2)×1.5), tanks = floor((w-1)/4)
```

### 2.4 防线持有条件

\[
\sum_{u \in \text{units}} \text{DPS}_{\text{eff},u} \times t_{\text{overlap},u}(w) \geq \text{TotalHP}(w)
\]

\(t_{\text{overlap}}\)：该波战斗时长内单位对怪群有输出的时间。保守估计：

\[
t_{\text{wave}} \approx N_{\text{enemies}} \times \text{spawn\_interval}(w) + L_{\text{path}} / v_{\text{avg}}
\]

---

## 3. 防御层：承伤与有效生命（EHP）

### 3.1 敌人对单位 DPS

\[
\text{DPS}_{e \to u} = \frac{\text{attack}}{\text{attack\_interval}} \times \mathbb{1}_{\text{in\_range}}
\]

当前：`attack_interval` 0.6~0.9s，近战射程 55。

### 3.2 单位生存时间

\[
T_{\text{survive}} = \frac{\text{hp}}{\text{DPS}_{e \to u} \times N_{\text{attackers}}}
\]

目标：\(T_{\text{survive}} \approx 15\text{s}\)（单怪单挑步兵，kb/02）。

### 3.3 有效生命 EHP（减伤/护盾）

\[
\text{EHP} = \text{hp} \times \frac{1}{1 - \text{dmg\_reduction}} + \text{shield\_hp}
\]

硅晶壁：`damage_reduction=0.5` 守位时 → EHP ≈ 2×hp。

### 3.4 漏怪与生命

\[
\text{lives}(w) = \text{lives}(w-1) - \text{leaks}(w)
\]

漏怪期望与「DPS 缺口」正相关：

\[
\text{leaks} \approx \max\left(0,\ \frac{\text{TotalHP}(w) - \text{DamageDealt}(w)}{\overline{\text{HP}}_{\text{leak}}}\right)
\]

---

## 4. 经济层：金币 + 第二资源

### 4.1 金币收入

\[
I_{\text{gold}}(w) = \sum_{\text{kills}} \text{reward}_i + \mathbb{1}_{\text{clear}} \cdot (40 + 6w)
\]

漏怪损失：未击杀怪的 `reward` 不得计入。

### 4.2 第二资源收入（CO-011 草案）

| 种族 | 公式 |
|------|------|
| 人族 | \(F(w) = N_{\text{farm}} \times (6 + 2 \times \text{agri\_tier})\) |
| 菌族 | \(F(w) = \sum_{\text{corpse on carpet}} \text{corpse\_food}(id)\) |
| 龙族 | \(F(w) = \sum_{\text{eaten corpses}} \text{corpse\_food}(id)\) |
| 硅基 | \(O(w) = N_{\text{mine}} \times (5 + 2 \times \text{mine\_tier})\) |

尸体食物：Grunt=3, Runner=2, Tank=8。

### 4.3 支出与库存

\[
B_{\text{gold}}(w) = B_{\text{gold}}(w-1) + I_{\text{gold}}(w) - E_{\text{gold}}(w)
\]

\[
B_{\text{food}}(w) = B_{\text{food}}(w-1) + F(w) - E_{\text{food}}(w)
\]

**闭合条件**（参考 PLAN 策略）：

\[
\forall w:\ B_{\text{gold}}(w) \geq 0 \land B_{\text{food}}(w) \geq 0
\]

### 4.4 成本-绩效对称

\[
\text{DPS\_per\_100g} = \frac{\text{DPS}_{\text{panel}}}{\text{gold\_cost}} \times 100
\]

全族目标区间：**[81, 99]**（基准 90，±10%）。

含第二资源时，定义**综合造价**：

\[
C_{\text{eff}} = \text{gold\_cost} + p_f \cdot \text{food\_cost} + p_o \cdot \text{ore\_cost}
\]

\(p_f, p_o\)：影子价格（每 1 食物/矿石折合多少金币），由稳态收入比推得：

\[
p_f \approx \frac{I_{\text{gold}}^{\text{avg}}}{F^{\text{avg}}} \quad (\text{保守取 2~4})
\]

---

## 5. 兵种配置：从需求反推编制

### 5.1 步骤

1. 算 \(\text{TotalHP}(w)\) 与 \(\text{DPS}_{\text{req}}(w)\)
2. 给定玩家该波可用 \(B_{\text{gold}}, B_{\text{food}}\)，枚举可买单位集合
3. 选编制使 \(\sum \text{DPS}_{\text{eff}} \geq \text{DPS}_{\text{req}}\) 且造价 ≤ 预算
4. 检查 Runner 子集：\(v=150\) 需足够控制/减速或远程火力

### 5.2 Runner 专项

\[
N_{\text{runner}}(w) = \max(0, (w-2) \times 1.5)
\]

单 Runner 血量低但速度快，需满足：

\[
\text{DPS}_{\text{single-target}} \times t_{\text{window}} \geq \text{HP}_{\text{runner}}(w)
\]

或减速使 \(t_{\text{window}}\) 拉长 ≥ 22%。

### 5.3 溅射价值

\[
\text{Value}_{\text{splash}} = \text{damage} \times \mathbb{E}[N_{\text{in\_radius}}]
\]

半径 70 时，波 7+ 怪群 \(\mathbb{E}[N] \approx 3\) 则溅射等效 ×3。

---

## 6. 种族对称评审表（交付必附）

| 种族 | DPS/100g | 机制补偿 | EHP 倍率 | 第二资源压力 | 最优/最差净收益比 |
|------|----------|----------|----------|--------------|-------------------|
| 人族 | | 牧师/卡位 | 1.0 | 种田稳定 | ≤3× |
| 菌族 | | 菌毯/分裂 | 0.55 | 毯上噬尸 | ≤3× |
| 龙族 | | 飞行/噬尸回血 | 0.5 | 追尸机动 | ≤3× |
| 硅基 | | 蓄能/晶壁 | 1.4~2.0 | 挖矿 | ≤3× |

---

## 7. 极限策略检查

定义两种策略：

- **最优** \(\pi^*\)：S1/S2 Autoplay PLAN（或动态规划近似）
- **最差** \(\pi^-\)：只买最便宜战斗单位、不进化、不技能

\[
\frac{\text{NP}(\pi^*)}{\text{NP}(\pi^-)} \leq 3 \quad \text{（每波或全程）}
\]

\[
\text{NP}(w) = I(w) - E(w)
\]

超出 3× → 调奖励或面板，**禁止砍怪血掩盖**。

---

## 8. 技能数值约束

\[
\Delta \text{Damage}_{\text{skill}} \leq 0.3 \times \text{DPS}_{\text{req}}(w) \times T_{\text{skill}}
\]

Rally Fire：8s × 1.5 攻速 ≈ 对全军 +50% DPS 持续 8s → 等效额外伤害 ≤ 当前波需求 30%。

---

## 9. 调参顺序（禁止跳步）

1. `wave_composition` / `enemy_hp` 成长 — 难度曲线
2. 单位 `damage/rate/hp/range` — 战斗闭合
3. `reward` / 清波奖 — 经济闭合
4. 第二资源产出与 `food_cost` — 双资源闭合
5. 机制常量（减速、分裂衰减）— 种族差异
6. Autoplay 5-run — 实证校准

---

## 10. 与验收的关系

| 阶段 | 工具 | 通过标准 |
|------|------|----------|
| 纸上推演 | `tools/balance_calc.py` | PLAN 波 1-12 金币/食物库存 ≥ 0 |
| 战斗闭合 | 同上 + DPS 行 | \(\sum \text{DPS} \geq 0.85 \times \text{DPS}_{\text{req}}\) |
| 实证 | S1/S2 Autoplay | 5-run ACCEPT，波次日志与推演偏差 < 15% |

---

## 附录 A：人族步兵基准锚点

```
步兵：60g, 14 dmg, 1.0 rate → DPS=14, DPS/100g=23.3（含食物后 C_eff 更高）
敌人 Grunt w1：55 HP → T_kill = 55/14 ≈ 3.9s ✓ ∈ [2.5,5]
```

## 附录 B：config 索引

| 常量 | 文件 |
|------|------|
| HUMAN_UNITS, ENEMIES, wave_composition | config.gd |
| CO-011 食物/矿石/尸体（草案） | 待落地 |
