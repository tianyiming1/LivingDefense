# 梦龙动画管线（现行 · 过审强制）

> **2026-09-04 裁定：`gen_dream_self_flap.py`（mesh / pivot）= FAIL**（用户：拖影 +「根本不行」）。  
> 坏帧已隔离：`dream/self_flap/_FAIL_quarantine/`。  
> **现行可玩：Path A 木偶**（`prefer_frames: false`）+ 静帧立绘；**禁用**自生成 16f 当真交付。  
> **禁用 WorkBuddy**。真 16 帧只接受手绘 promote。

## 现行（可玩占位）

```bash
# 立绘：size_ladder unit_*_s*.png → ship unit_{id}.png
# 木偶：
python tools/gen/gen_dream_puppet_parts.py --units 14,15,16,17
# meta.prefer_frames 必须 false
```

| 状态 | 表现 |
|------|------|
| 14/15 | Path A 双翅运行时旋转扇翅 |
| 16/17 | 抠翅过空 → full_body 仅浮空 bob（禁叠影翅） |
| 真分帧 | **未过审**；禁止再装 self_flap |

## 手绘（唯一真分帧出口）

```bash
python tools/gen/gen_dream_hand_templates.py --units 14
python tools/gen/promote_dream_hand_anim.py --unit 14
```

见 `KEYFRAMES.md`（满配约 16 帧/阶）。

## 已清除（不得再出现）

- WorkBuddy 安装路径当交付  
- `SIL_POSE_*` / Comfy 锁站姿 / 整图果冻  
- **self_flap mesh/pivot 16f 当真交付**（拖影/掏空身体/叠影）
