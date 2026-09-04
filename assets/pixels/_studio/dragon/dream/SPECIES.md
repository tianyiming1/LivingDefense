## 分帧状态（2026-09-04）

| 项 | 裁定 |
|----|------|
| 立绘 / 源 | `size_ladder/unit_{14..17}_s*.png`；成年亦对齐 `approved/042_game.png` |
| 自生成 / Comfy / WorkBuddy 帧 | **FAIL · 已删除**（勿复活） |
| **现行可玩** | Path A 木偶 `prefer_frames: false` |
| **真分帧出口** | 仅手绘 → `promote_dream_hand_anim.py` |

```bash
python tools/gen/gen_dream_puppet_parts.py --units 14,15,16,17
```
