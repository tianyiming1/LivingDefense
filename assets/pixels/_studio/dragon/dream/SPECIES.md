## 分帧状态（2026-09-04）

| 项 | 裁定 |
|----|------|
| 立绘 / 源 | **自有过审** `dream/approved/042_game.png`（**禁用 WorkBuddy**） |
| **飞行 idle/fly ×16** | `tools/gen/gen_dream_self_flap.py` 自生成完整扇翅（升→降→升）；8 FPS / ~125ms；整圈约 2s |
| **walk** | = fly 拷贝 |
| **attack/death** | 自扇翅相位抽样 |
| 运行时 | `prefer_frames: true` + `fly_sheet` AtlasTexture；禁 WorkBuddy 路径 |
| 证据 | `dream/self_flap/SELF_FLAP_GATE_17.gif` · `SELF_FLAP_STRIP.png` |

安装：
```bash
python tools/gen/gen_dream_self_flap.py --units 14,15,16,17
```
