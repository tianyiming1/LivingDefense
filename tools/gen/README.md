# 本地 AI 出图管线（tools/gen/）
> 环境：RTX 4060 8GB / Python 3.12 / torch+diffusers（装入工作区 .pyenv，沙箱只允许写工作区）
> 用途：生成四族概念图（当前：硅基流动主线）供美术定稿参考

## 脚本
- `download_model.py` — 下载 LCM Dreamshaper v7 权重（断点续传）→ `D:\AI_models\lcm_dreamshaper_v7\`
- `gen_unit_local.py` — 像素精灵本地出图 → `D:\AI_models\pixel_sprite\`
- `txt2img_silicon.py` — 单张出图：`python txt2img_silicon.py --prompt "..." --out out.png`
- `txt2img_batch.py` — 批量出图：读 prompts_silicon.json，场景×seed 循环，输出 docs/ai_concepts/
- `prompts_silicon.json` — 硅基 7 场景 + 菌族对照 1 场景；negative + style_suffix 公共

## 运行约定
- 所有 python 用：python312（C:\Users\asus\AppData\Local\Programs\Python\Python312\python.exe）
- PYTHONPATH 需包含 .pyenv（pip --target 安装区），或脚本放 .pyenv 同级以 sys.path 注入
- 权重统一目录 = `D:\AI_models\`（不写入项目）
  - LCM：`D:\AI_models\lcm_dreamshaper_v7\`（HF: SimianLuo/LCM_Dreamshaper_v7）
  - 像素精灵：`D:\AI_models\pixel_sprite\`（HF: Onodofthenorth/SD_PixelArt_SpriteSheet_Generator）

## 验收口径（美术线）
- 出图 ≠ 定稿：人工审 → 按 ART_GUIDE §2 精确色板（硅基 #6FD3E7/#F5F9FF/#A8E8F5）比对 → 可用的进 docs/ai_concepts/approve/
- 引擎落地仍以 draw_* 等价公式为准（AI 图只做风格参考，不进引擎管线）
