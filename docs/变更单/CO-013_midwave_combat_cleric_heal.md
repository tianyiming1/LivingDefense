# 变更单 CO-013：波中部署进战斗 + 牧师耗蓝治疗

- **状态**：已实施
- **日期**：2026-09-03
- **批准**：用户试玩反馈（新兵不动；牧师应耗蓝加血）

## 变更

1. **波中部署**：`WAVING` 下 `_try_place` / 菌分裂 / 龙孵化后立即 `set_combat(true)`，新兵可移动交战。
2. **牧师**：`kind=healer`；蓝条 `mana_max/mana_cost/heal_amount/mana_regen`；战斗中寻受伤友军移动并治疗；头顶黄血条下显示蓝条。
3. **可读性**：选中显示蓝量/治疗；波 4 铁皮提示；含铁皮波次状态文案。

## 影响文件

`main.gd`、`unit.gd`、`config.gd`（HUMAN_UNITS id4）、`placement_ghost.gd`、`translations/strings.csv`
