# 梦龙 · 最少可玩关键帧

> 对齐 CO-046。引擎：`unit_{id}_anim/{idle|walk|fly|attack|death}_N.png` · 96×108 · 脚底锚 · 黑底全身。  
> **不会画画也可以**——见下方「不会画画怎么办」。禁止程序整图拧弯当真动画。

## 不会画画怎么办（按推荐顺序）

| 方案 | 你要做什么 | 说明 |
|------|------------|------|
| **A. Path A 部件木偶（现行）** | 无 | `gen_dream_puppet_parts.py` + 运行时扇翅；占位分帧时自动启用 |
| **B. 手绘关键帧** | Aseprite 按本表画 | 终局质量；promote 后门禁 |
| **C. Agent 候选 + 你终审** | 只点行/不行 | 易 FAIL，不优先 |
| **D. 占位可玩** | 无 | 仅立绘；已被 A 覆盖「平移假动作」 |

外包/Spine 等中后期再议。

## 推荐顺序（有画手时）

1. **只做 unit_14（幼龙）** 全套关键帧 → 进局验状态机  
2. 15/16/17：同姿态按体型梯缩放重绘  
3. 过 `promote_dream_hand_anim.py` 门禁再 ship  

## MVP 帧数（可玩）

| 剪辑 | MVP | 满配（CO-046） | 一眼须能辨 |
|------|-----|----------------|------------|
| idle | **2** | 2 | 翅收 ↔ 翅开 |
| walk | **2**（先画 0/2；1/3 可镜像或补） | 4 | 左右交替抬腿 |
| fly | **2**（先画 0/2） | 4 | 翅上扬 ↔ 翅下压；**脚离地同高** |
| attack | **3** | 3 | 蓄力后仰 → 前冲喷弧 → 收招 |
| death | **2**（0 倾倒 + 2 横躺；1 可插） | 3 | 末帧 **横躺扁平** |

**幼龙 MVP 合计：2+2+2+3+2 = 11 帧**（满配 16）。  
四阶满配：64 帧；四阶 MVP：约 44 帧。

## 姿态规格（画的时候对照）

### idle
- `idle_0`：贴地/微浮，翅半收  
- `idle_1`：同脚位，翅明显张开（轮廓变高）  
- 禁止：原地跑步感

### walk（梦步，不是冲刺）
- `walk_0`：左前+右后抬起  
- `walk_2`：右前+左后抬起（与 0 对称）  
- 脚底 Y 稳定；翅半展平衡  
- 禁止：整图倾斜当走路、矩形切层

### fly
- 四脚**收起离地**；影子可缩小  
- `fly_0`：翅上扬；`fly_2`：翅下压  
- **飞帧脚底 Y 必须一致**（CO-046：禁帧间蹦跳）

### attack（咏唱，kind=spell）
- `attack_0`：后仰蓄力，口鼻冰蓝点  
- `attack_1`：前冲释放（头前压）  
- `attack_2`：回位  
- 禁止：火焰橙；禁止上下半身错位拼贴

### death
- `death_0`：侧倾失衡  
- `death_2`：侧躺扁平（宽≫高）  
- 禁止：站着当死亡

## 目录（手绘 WIP）

```
dream/hand_anim/
  unit_14/   ← 先填这里
  unit_15/
  unit_16/
  unit_17/
  README.md
```

命名与 ship 相同：`idle_0.png` …  
画完后：`python tools/gen/promote_dream_hand_anim.py --unit 14`（过目检才写 ship）。

## 参考锚（DNA）

| 阶 | 立绘参考 |
|----|----------|
| 14 | `whelp/approved/006_game.png` |
| 15 | `drake/approved/003_game.png` |
| 16/17 | `picks/pick_dream_menglong_game.png` / `approved/042_game.png` |

洋葱皮：可用 `hand_anim/unit_14/_templates/` 里的半透明底稿。

## 验收（过才 ship）

- [ ] 黑底全身，无雾底、无矩形挖空  
- [ ] idle / walk / fly / attack / death **剪影一眼不同**  
- [ ] fly 脚底同高；death_2 扁平  
- [ ] 1 对背翼、1 尾；梦色板  
- [ ] 对照条：`hand_anim/COMPARE_u{id}.png`（用脚本生成）

## 明确 FAIL（已删除，勿再做）

- 程序剪影拼贴（矩形挖空、错层）
- Comfy 锁站姿假分帧
- 未过 `promote` 门禁的任何帧

## 与引擎

`UnitSprites.load_anim_frames` 按文件名连续加载；缺帧会断在该动画。  
MVP 可只放 walk_0/walk_2（引擎会播到有的帧）；满配再补 1/3。

**过审铁律**：手绘帧必须过 `promote_dream_hand_anim.py` GATE（尺寸、非空、跨态差异、fly 高度、death 扁平）才允许进 ship。占位帧 ≠ PASS。
