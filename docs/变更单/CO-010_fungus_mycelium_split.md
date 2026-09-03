# 变更单 CO-010：四族可玩原型 + 菌族菌丝/分裂/平衡

- **状态**：已实施（用户试玩验收中）
- **生效版本**：config 菌族表 + 分裂常量（2026-09-02 晚）
- **批准**：用户口头需求（菌族攻击力过高 → 下调 + 自动分裂且代数越高攻击越低）

## 为什么变

1. **内容里程碑**：CO-001 定稿四族后，需可进游戏选族试玩，验证 `resource_rule` 抽象与各行为差异。
2. **菌族手感迭代**（多轮用户反馈）：
   - 菌毯不应直接扣血 → 改为 debuff（减速、孢子暴露、攻速降低）。
   - 蘑菇固定守位（`stationary`），菌丝从每个放置单位径向蔓延（`carpet.gd`）。
   - 菌毯上的敌人可被任意菌族单位攻击（菌网索敌，`unit._can_hit`）。
   - 攻击力仍偏高 → 再下调基础数值 + 引入**分裂代数惩罚**（数量换单体输出）。
3. **纪律**：设计/数值变更须落变更单 + kb，禁止口头改设计。

## 影响范围

### 新增/核心文件

| 文件 | 职责 |
| --- | --- |
| `scripts/carpet.gd` | 菌丝源 `sources[]`、径向生长、`covers(pos)`、视觉脉冲 |
| `scripts/attack_vfx.gd` | 远程攻击枪口/弹道 VFX |

### 修改文件

| 文件 | 改动摘要 |
| --- | --- |
| `scripts/config.gd` | `FUNGUS_UNITS` / `DRAGON_UNITS` / `SILICON_UNITS` / `RACES`；菌毯 debuff 常量；分裂常量 |
| `scripts/main.gd` | 选族、购买/放置/技能分支；`register_fungus_source`；`find_fungus_bud_spot` / `spawn_fungus_bud` / `_on_split` |
| `scripts/unit.gd` | 四族行为；菌族固定守位；分裂 `split_tier`、攻击/毒伤衰减；自动分裂计时 |
| `scripts/enemy.gd` | 毒/烧/麻痹/感染；菌毯 debuff（`apply_spore_debuff` / `apply_carpet_aura`） |
| `scripts/hud.gd` / `menu.gd` | 种族面板、技能文案、信息面板「分裂」按钮 |
| `scripts/projectile.gd` | VFX + `from_fungus` 伤害标记 |
| `translations/strings.csv` | 四族单位名、菌族 stat/split 文案 |

## 菌族机制定稿（实现层）

### 菌丝（mycelium）

- **来源**：仅由已放置蘑菇注册源点（`main.register_fungus_source`），开局不铺毯。
- **生长**：每源点半径随时间/波次向外扩（`CARPET_SPREAD_SPEED`、`CARPET_MAX_RADIUS`）。
- **踩毯效果**（`enemy.gd`，无直接 HP 损失）：
  - 移速 −22%（`CARPET_SLOW`）
  - 攻速 −18%（`CARPET_ATTACK_SLOW`）
  - 受菌族攻击额外 +8%（`CARPET_SPORE_VULN`）
- **菌毯蘑菇光环**：范围内额外减速（`aura_slow`），不直接伤害。

### 蘑菇单位（`FUNGUS_UNITS`，代数 0 基础面板）

| id | 单位 | cost | hp | dmg | rate | kind | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 毒蘑菇 | 60 | 110 | 5 | 0.75 | melee | 毒 1.2 dps / 3s |
| 1 | 爆孢蘑菇 | 100 | 90 | 4 | 0.8 | splash | 溅射 r65，感染 r90 |
| 2 | 菌毯蘑菇 | 70 | 75 | 0 | 0 | aura | 铺毯倍率 ×1.8 |
| 3 | 麻痹蘑菇 | 80 | 85 | 5 | 0.6 | single | 麻痹 1.5s，CD 5s |

- 全部 `stationary: true`，`speed: 0`，无进化链（`evolves_to: -1`）。

### 分裂（budding）

| 常量 | 值 | 含义 |
| --- | --- | --- |
| `FUNGUS_SPLIT_MAX` | 3 | 最大代数（0~3，共可分裂 3 次） |
| `FUNGUS_SPLIT_ATTACK_MULT` | 0.62 | 每升 1 代，攻击与毒伤 ×0.62 |
| `FUNGUS_SPLIT_HP_MULT` | 0.88 | 分裂后双方生命 ×0.88 |
| `FUNGUS_SPLIT_FIRST_DELAY` | 10s | 开战后首次自动分裂等待 |
| `FUNGUS_SPLIT_INTERVAL` | 20s | 战斗中自动分裂间隔 |

- **自动分裂**：战斗中计时触发，附近有空地则 `spawn_fungus_bud`。
- **手动分裂**：布防阶段选中蘑菇 → HUD「分裂」按钮（免费）。
- **子代**：`split_tier = parent.split_tier + 1`；父代 `after_bud_as_parent()` 同步升代。
- **UI**：信息面板显示 `stat_line_fungus`（代数 / 实际伤害 / 实际攻速），非配置表原始值。

### 主动技能（菌族）

- **菌毯沸腾**（`SKILL_FUNGUS`）：菌丝减速额外加强（`carpet_fever_slow_bonus`），CD 3 波。
- 孢子爆发常量保留，当前主技能入口为沸腾。

## 有效伤害公式（菌族）

```
effective_damage = def.damage × chain_bonus × pow(0.62, split_tier)
effective_poison = poison_dps × pow(0.62, split_tier)
```

代数 3 时攻击约为代数 0 的 **14.8%**（0.62³）。

## 验证

| 项 | 结果 |
| --- | --- |
| `tools/chase_test.gd` | CHASE_TEST_PASS |
| 游戏启动 | `Godot --path ... res://menu.tscn` |
| S1Autoplay | 未回归（人族基线，本次未改人族表） |
| S2 菌族 autoplay | 暂无专用验收脚本 |

## 与 kb/03 原稿差异（须同步）

| 原稿（RACES v0.7） | 当前实现 |
| --- | --- |
| 菌毯持续伤害 | **已取消**，改为纯 debuff |
| 蘑菇移速 40 蠕动 | **固定守位** speed=0 |
| 菌毯蔓延「每波 +2 格」 | **径向生长**（源点半径扩张） |
| 成长 = 蘑菇升级 | **分裂代数**（无进化链） |
| 技能菌毯伤害 ×3 | **减速加强**（非伤害倍率） |

## 回滚

- 分裂：删除 `unit.gd` 分裂逻辑 + `main` bud 接口 + config 分裂常量。
- 菌族整体：选族回 human-only，保留 `FUNGUS_UNITS` 数据常量即可。

## 后续待办

1. 用户试玩反馈 → 微调 `FUNGUS_SPLIT_ATTACK_MULT` / 基础 dmg。
2. S2 专用 autoplay + 12 波菌族平衡赛跑。
3. 更新 `docs/RACE_FUNGUS.md` 与 kb/03 正式对齐（本 CO 为权威）。
