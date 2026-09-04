# pixels 资源架构（ship / studio）

## 正式进游戏（ship）
引擎只读这些路径，禁止把候选图直接堆进来：

```
assets/pixels/
  human|fungus|dragon|silicon/unit_N.png
  dragon/unit_N_anim/{idle|walk|attack}_K.png
  enemies/enemy_N.png
  map/*.png
  ui/*.png                 # CO-034 HUD 木石面板
  PROVENANCE.json
```

## 工作室候选（studio）
全部 AI/筛选工作都在 `_studio/`。龙族大类 + **龙人五亚种**：

```
_studio/
  incoming/
  dragon/
    longren/                 # 龙人族
      INDEX.md / SPECIES.json
      magma/                 # 焰鳞 — 厚重
      frost/                 # 霜棱 — 瘦削
      storm/                 # 雷冠 — 偏瘦尖冠
      stone/                 # 岩夯 — 矮阔
      jade/                  # 碧枝 — 修长
        candidates/ picks/ pose/ anim/{idle,walk,attack}/ ui/
      （根目录 NNN_* = 未分类历史池，只读）
    whelp/ drake/ adult/
    picks/                   # 全族共享锚点（如 pick_004）
    refs/ anim_wip/ templates/
```

命名：`candidates/NNN_raw.png` / `NNN_game.png` + `catalog.json`  
归档 ID：`dragon/longren/{magma|frost|storm|stone|jade}`

## 规则
1. 出图 → 只写入对应亚种 `candidates/`，编号递增，不覆盖。
2. 用户选定后 → 拷入该种 `picks/`，再 promote 到 ship 的 `unit_N.png`，并写 PROVENANCE。
3. 动画 / UI / 姿态 → 只进该种 `anim/` `ui/` `pose/`，禁止堆回扁平 longren 根。
4. `_incoming` / 旧 `_candidates` 已废弃。
5. ship 目录禁止放 preview、raw、重复副本。
