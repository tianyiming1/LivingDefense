# 变更单 CO-012：人族教学怪「铁皮」护甲兵（B 路线）

- **状态**：实施中
- **日期**：2026-09-03
- **批准**：用户选 B（三怪+1 新怪）+ 推荐护甲 +「做」
- **生效**：`config.ENEMIES` id3 + `wave_composition` + `enemy.apply_damage` 伤害类型抗性

## 为什么变

人族打磨需要「怪有身份」：现有小兵/跑者/坦克仍偏数量曲线。加 **1** 个护甲怪，逼出「近战刮不动 → 上火枪/迫击/齐射」的决策（参考 WC3 TD / Kingdom Rush 抗性课），不引入空军（工程更大，延后）。

## 规格

| 项 | 值 |
| --- | --- |
| id | 3 |
| 名 | 铁皮 / Armored |
| HP | 90（随波 ×1.12） |
| 速度 | 55 |
| 奖励 | $16 |
| 攻击 | 14 / 1.0s |
| 近战承伤 | ×0.32 |
| 单体远程 | ×1.0 |
| 溅射 | ×1.2 |
| DoT/通用 | ×1.0 |
| 出场 | 波 ≥4：`armored = max(0, wave-3)` 尾段加入队列 |

## 影响

- `scripts/config.gd`、`enemy.gd`、`projectile.gd`、`unit.gd`（近战/飞击传 dmg_kind）
- `translations/strings.csv`
- S1Autoplay：构成变难一点，以通关为准

## 不做

空军怪、BOSS、全族新抗性表重构
