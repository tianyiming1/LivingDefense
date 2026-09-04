# 变更单 CO-018：反馈音效补点

- **状态**：已实施
- **日期**：2026-09-03
- **派工**：WP-AUD1

## 事件表

| 事件 id | 触发 | 说明 |
| --- | --- | --- |
| `heal_chime` | 牧师治疗成功 | 短高音 |
| `supply_tick` | 农民产补给 +N | 与产间隔同频，非每帧 |
| `impact_heavy` | 铁皮受击 | 既有厚重撞击 |
| `dragon_breath` | 龙焰技能 | 既有咆哮 |
| `wall_shatter` | 晶壁碎（进再凝） | 复用闪电噪 |
| `crystal_clink` | 晶壁再凝完成 | 既有晶鸣 |
| `spore_pop` / `spore_idle` | 菌技能/踩毯提示 | 既有 |

## 影响文件

`audio_controller.gd`、`unit.gd`、`enemy.gd`、`main.gd`
