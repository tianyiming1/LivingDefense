# 变更单 CO-022：第二可玩地图 Map B（WP-MAP1）

- **状态**：实施中 → 待冒烟验收
- **日期**：2026-09-03
- **生效版本**：MAP-B-1（`resources/maps/map_*.tres` + `Config.apply_map`）
- **需求来源**：派工 `docs/派工_WP_可玩性丰富度.md` WP-MAP1
- **并行约束**：不改波次公式 / 敌表；PATH 放独立 map 资源

## 为什么变

- 单图 S 形站位课打几局就腻；需要第二空间课形成复玩差异。
- Map B 用**更长走廊 + 双折窄口**，逼玩家在两处垂直颈口叠 DPS，而不是继续刷 Map A 内弯口袋。

## 影响范围

| 项 | 说明 |
| --- | --- |
| 新增 | `scripts/map_data.gd`（`MapData` Resource）；`resources/maps/map_a.tres` / `map_b.tres` |
| 新增 | `tools/map_b_smoke.gd`（人族 Map B 开波冒烟） |
| 修改 | `config.gd`：`PATH_POINTS` 改为可切换；`apply_map` / 默认 `map_a` |
| 修改 | `menu.gd`：地图选择行；`main.gd`：进局前 `apply_map` |
| 修改 | `translations/strings.csv`：地图键 |
| 不改 | 波次构成、经济常数、种族单位表 |

## 冻结规格

### Map A（默认，不变课）

- 现有 8 点 S 形；启动未选手动图时仍为 Map A。
- S1 Autoplay / 无 `selected_map` meta → Map A。

### Map B（双折窄口长廊）

| 项 | 规格 |
| --- | --- |
| id | `map_b` |
| 形状 | 底部长廊 → 右竖窄口 → 中段回折长廊 → 左竖窄口 → 顶部长廊出图 |
| 出生 / 终点 | 路径首点左侧外、末点右侧外；标记仍用 spawn/goal stamp |
| 站位课 | 两处垂直窄口为强制交火点；长廊段曝光时间更长；少 Map A 式内弯口袋 |
| 进入路径 | 主菜单地图按钮选 **窄口长廊** 后开始游戏 |

### 切换契约

```
菜单 set_meta("selected_map", id)
→ main._ready 最先 Config.apply_map(id)
→ map / enemy / unit / placement 读 Config.PATH_POINTS
```

## 验收标准

1. 默认开局仍是 Map A（PATH 与改前一致）。
2. 菜单可选 Map B；进局后走廊形状可见不同；出生/终点标记清晰。
3. 人族在 Map B 可开波、怪沿新 PATH 走，无崩溃。
4. 不改动波次公式；S1 默认路径仍 Map A。

## 交付摘要（填冒烟后）

- 选图：主菜单种族行下方地图按钮（默认「S 形」= Map A）
- PATH 差异：Map B 为双折窄口长廊，非 S 形内弯
- 冒烟：见实施结果
