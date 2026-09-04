# ANIMB-001 敌族动画帧包（grunt 打头，随后 runner/tank/boss）

> 状态：READY（引擎通道已就绪，等出包过审） · 契约：`docs/动画_素材契约与审核_v1.md` · 审核：`tools/gen/audit_anim_pack.py`
> 顺序铁律：**只做一个兵种、过审一个**，禁止四个一起裸出。

## 背景（为什么现在能做）

- 引擎此前敌兵只有程序化上下弹跳，**无帧通道** → 2026-09-04 已补：`UnitSprites.enemy_anim_dir()` + `load_enemy_anim_frames()`，视图按 `idle/walk/attack` 播放，与单位同款 REVIEW 门禁（未过审不播放）。
- 敌族静态底图：`assets/pixels/enemies/enemy_{0..3}.png`（程序绘制，owned）。动画帧包放 `assets/pixels/enemies/enemy_{id}_anim/`。
- 色板：敌族 rust-red（`#BF4A2F` 系），audit 已支持 `enemies→PALETTES.enemy` 映射；若不严合，可在包目录放 `palette.json` 覆盖（参考梦龙 14-17 做法）。

## 目标（第一包：enemy_0 grunt）

`assets/pixels/enemies/enemy_0_anim/`：
- `idle_0..1.png`（2 帧呼吸；禁两帧完全同图）
- `walk_0..3.png`（**先做 4 帧**；脚底行全帧同一 y；首末帧剪影重合，循环无缝）
- `attack_0..2.png`（3 段姿态：蓄力/扑咬/收势，与引擎 pose 映射一致）
- 画布 96×108 全包统一、透明背景、无裁切、锚点脚底中心

## 生成步骤（严格按契约）

1. 读 `docs/动画_素材契约与审核_v1.md` §1-§3 + `.cursor/rules/art-direction.mdc` §四甲（帧间描述逐字锁定，只换姿势槽）。
2. 以 `assets/pixels/enemies/enemy_0.png` 为基准形象 → 首帧定锚 → 逐帧对照，禁止自由发挥体型/配色。
3. WIP 先放 `assets/pixels/_studio/enemies/enemy_0_anim/`，验收后拷入正式目录。
4. 过审（强制，不过审引擎不认）：
   ```bash
   python tools/gen/audit_anim_pack.py --race enemies --unit 0
   ```
   PASS（REVIEW.json=approved）→ 下一步；FAIL → 按 reasons 返工。
5. Godot 实际播放验收：`--scene res://tests/S1Autoplay.tscn` 敌人波肉眼无跳变/滑步。

## 质量标尺（对齐历史最佳：梦龙扇翅/人族 walk）

- 丝滑 = 帧循环无缝（walk 首末 IoU ≥0.65，理想 ≥0.75）+ 脚底稳定（std ≤2px）+ 程序化 bob 叠加。
- 禁止：占位伪帧（idle=walk 同图）、4 帧循环接缝可见、脚底漂移、色板漂移 >20%。
- 参考在册达标包：`human/unit_0_anim`、`dragon/unit_14_anim`（fly_sheet）。

## 验收清单

- [ ] enemy_0_anim 三动作帧齐、命名连续、画布统一
- [ ] `audit_anim_pack.py` PASS 且 REVIEW.json=approved
- [ ] S1 实战播放：grunt 走路循环无缝、攻击三姿态连贯
- [ ] 敌族其余兵种（1 runner 飞/2 tank 重/3 boss 大）另开 ANIMB-002/3/4，每个独立过审
