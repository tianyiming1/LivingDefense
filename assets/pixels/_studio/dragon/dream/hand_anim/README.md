# 手绘梦龙动画帧

规格见上级 `KEYFRAMES.md` + `docs/变更单/CO-046_dream_dragon_animation.md`。

## 用法（手绘）

1. 看 `_templates/` 洋葱皮底稿（半透明立绘）  
2. 在 Aseprite / 像素工具新建 96×108，脚底约 y=99  
3. 导出到本目录对应 `unit_{id}/`，文件名与 ship 一致  
4. 自检后运行 promote（勿直接覆盖 ship 除非过审）

```bash
python tools/gen/gen_dream_hand_templates.py --units 14
# 画完…
python tools/gen/promote_dream_hand_anim.py --unit 14 --dry-run
python tools/gen/promote_dream_hand_anim.py --unit 14
```

## 方案 C 免费候选（固体木偶 · 非手绘）

整图常驻立绘 + 翼膜叠加（**禁止**抠洞分体）。产出仅 WIP：

```bash
python tools/gen/gen_dream_cutout_frames.py --units 14,15,16,17 --install
# 目检 CUTOUT_EYE_*_x2.png / compare_u*.png
python tools/gen/promote_dream_hand_anim.py --unit 14 --dry-run
# 仅你目检 PASS 后才去掉 --dry-run
```

机检 PASS ≠ 能用。未过审禁止拷入 `assets/pixels/dragon/unit_*_anim/`。
