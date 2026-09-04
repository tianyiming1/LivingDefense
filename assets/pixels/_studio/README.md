# pixels 资源架构（ship / studio）

## 正式进游戏（ship）
引擎只读这些路径，禁止把候选图直接堆进来：

```
assets/pixels/
  human|fungus|dragon|silicon/unit_N.png
  dragon/unit_N_anim/{idle|walk|attack}_K.png
  enemies/enemy_N.png
  map/*.png
  PROVENANCE.json
```

## 工作室候选（studio）
全部 AI/筛选工作都在 `_studio/`，按龙族四类归档：

```
_studio/
  incoming/           # 临时投放，用完即清
  dragon/
    longren/          # 龙人：双手双脚
    whelp/            # 幼龙：小龙形
    drake/            # 亚龙：中型龙形
    adult/            # 成龙：大型四足/巨龙
    picks/            # 已选中的定稿参考（如 004）
    refs/             # 合集/参考图
    anim_wip/         # 动画实验帧（未进 ship）
  enemies/ref/
```

命名：`NNN_raw.png` / `NNN_game.png` + `catalog.json`

## 出图入口（pick_004 熔岩龙人风格）
```bat
python tools/gen/comfy_pixel_gen.py --preset flame_drake --n 4 --open
```
ComfyUI + Juggernaut-XL + pixel LoRA；产出只进 `_studio/dragon/longren/`，审肢后再 promote。

## 规则
1. 出图 → 只写入 `_studio/...`，编号递增，不覆盖。
2. 用户选定后 → promote 到 ship 的 `unit_N.png`，并写 PROVENANCE。
3. `_incoming` / 旧 `_candidates` 已废弃。
4. ship 目录禁止放 preview、raw、重复副本。
