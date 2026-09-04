# 本地 AI 出图管线（tools/gen/）
> 环境：RTX 4060 8GB / Python 3.12 / torch+diffusers + **ComfyUI SDXL**
> 龙人定稿风格锚点：`_studio/dragon/picks/pick_004_flame_drake_*`（熔岩橙鳞 + 紫翅爪）

## 主路径（推荐）：ComfyUI SDXL + 像素 LoRA → `_studio`

```bat
tools\gen\comfy_pixel_gen.cmd
python tools/gen/comfy_pixel_gen.py --preset flame_drake --n 4 --open
python tools/gen/comfy_pixel_gen.py --list-presets
python tools/gen/comfy_pixel_gen.py --ingest D:\GameWorkSpace\dragonman --archive dragon/longren
```

- 引擎：`D:\softwares\ComfyUI`（脚本可自动拉起 8188）
- 权重：`Juggernaut-XL_v9` + LoRA `pixel-art-lora-sdxl`（也可用 `--ckpt zavychromaxl_v100.safetensors`）
- 预设：`tools/gen/prompts_comfy.json`（默认 `flame_drake` = pick_004 风格）
- 产出：只进 `assets/pixels/_studio/dragon/longren/`（`NNN_raw` / `NNN_game`），**不写 ship**
- 选定后：`python tools/gen/archive_candidates.py --promote dragon/longren N`

旧入口 `D:\GameWorkSpace\生图.cmd` 仍可用；项目内请用上面命令，保证进 `_studio`。

## 其它脚本
- `download_model.py` — LCM / 其它 HF 权重 → `D:\AI_models\`
- `gen_unit_local.py` — `pixel_sprite` 真像素侧视（肢易乱，备选）
- `txt2img_silicon.py` / `txt2img_batch.py` — LCM 概念图
- `import_ai_sprite.py` — 手动把 raw 放 `_studio/incoming/` 再导入
- `reimport_pick004.py` — pick_004 干净重导入

## 运行约定
- Python：`C:\Users\asus\AppData\Local\Programs\Python\Python312\python.exe`
- 权重：`D:\AI_models\`（diffusers）+ `D:\softwares\ComfyUI\models\`（SDXL）
- 出图 ≠ 定稿：先审肢（`ANATOMY.md`）再 promote；`commercial_ok` 写 PROVENANCE
