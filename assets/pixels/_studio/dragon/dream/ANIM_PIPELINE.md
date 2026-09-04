# 梦龙动画管线（现行 · 过审强制）

> **现行可玩：自生成完整扇翅真帧**（`gen_dream_self_flap.py` ← `approved/042_game.png`）。  
> **禁用 WorkBuddy** 及其序列帧。  
> Path A 木偶仅作无真帧时的占位；真分帧 `prefer_frames:true` 后关闭。  
> 失败管线（silhouette / Comfy 锁站姿 / 整图拧弯 / WorkBuddy 直装）禁止复活。

## 自生成扇翅（现在）

```bash
python tools/gen/gen_dream_self_flap.py --units 14,15,16,17
# → unit_{id}_anim/{idle,fly,walk}_0..15 + fly_sheet.png
# 预览：res://tools/preview_dream_flap.tscn
# 证据：dream/self_flap/SELF_FLAP_GATE_17.gif
```

| 状态 | 表现 |
|------|------|
| idle/fly/walk | 16 帧完整扇翅（升→降→升）@ ~125ms |
| attack/death | 扇翅相位抽样 |
| 运行时 | AtlasTexture 切 `fly_sheet`；相位与 loco 解耦 |

## 手绘（终局可选）

```bash
python tools/gen/gen_dream_hand_templates.py --units 14
python tools/gen/promote_dream_hand_anim.py --unit 14
```

## 已清除（不得再出现）

- WorkBuddy 安装路径当交付  
- `SIL_POSE_*` / Comfy 锁站姿 / 整图果冻  
- 双翅叠影（body 残留膜 + 旋转翅）
