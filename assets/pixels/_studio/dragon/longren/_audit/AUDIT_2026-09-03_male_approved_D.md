# AUDIT — male approved + female armor wave 2026-09-03 ~18:40

## Gate snapshot
- STYLE_GATE + ANATOMY：**女体 XOR 龙头**；**恰好 1 尾**；女装 **铠胸罩+战裙**；禁尖刺丑甲；禁多尾锚
- frost/002 picks：**已删**（裸装规 + 多尾否决样）— 正确
- `ref_frost_002_hero`：**磁盘不存在**；`ref_REJECT_frost_002_multitail` 在册 — **禁止再当生成锚**
- `PASS_RATE_ROOT_CAUSE.md` §纠正办法#1（用 002 hero i2i）与 `WHERE.md`/`ANATOMY.md` **冲突** → 以 WHERE/ANATOMY 为准，**该条作废**

---

## 男亚种 `approved/`（持续审核补签）

| 对象 | 互斥/翼/肢 | 色板 SPECIES | 黑底/干净 | 1 尾 | 结论 |
|------|------------|--------------|-----------|------|------|
| magma/011 | PASS（龙吻男壮，1 对背翼） | **弱** warm≈9%（偏黑炭，非猩红主调） | game 透明角 OK；观感灰底 | 需目视确认单尾 | **CONDITIONAL** — 可留 approved，**不建议 picks**；宜补更红主调稿 |
| magma/022 | PASS | **可** warm≈39% | **岩座+脚底火** 非干净全身立绘 | 单尾可读 | **CONDITIONAL** — 可留 approved；进 picks 前建议去底座/地火 |
| storm/002 | PASS | 炭金 **弱**（金高光少） | **灰地面圆台** 非纯黑 | 单尾 | **CONDITIONAL** — 可留；扣色板与地面 |
| stone/002 | PASS 肢翼 | **FAIL** 非砂岩褐（炭黑主导，brown≈3%） | OK | 单尾 | **CONDITIONAL FAIL 色板** — **建议移出 approved** 或标 `near/`；ART_REVIEW「砂岩褐」证据不足 |

**统一：禁止自动进 `picks/` / ship。** 用户终审前男稿全部停在 approved。

---

## 女亚种状态

| 项 | 状态 |
|----|------|
| frost/jade `approved`/`picks` | **空** — 符合清库 |
| ART_REVIEW「保留 011–019」 | **过时** — 磁盘现为 frost `024–038`，jade 至 `039` |
| frost `035–038` 抽样 | 冰蓝 OK；1 对背翼 OK；有胸甲+胯帘/裙感 → 服装 **可能近规**；仍有漂浮冰晶 FX；须逐张确认 **恰好 1 尾** + 明确铠胸罩（非鳞糊胸）后才能 approved |
| jade `037–039` 抽样 | 偏霜白/青，绿种差弱；服装同样待硬审；**勿 promote** |

---

## 流程纪律

| 项 | 结果 |
|----|------|
| 女装清库删 picks | PASS |
| 多尾否决入库 | PASS |
| ART_REVIEW 与磁盘编号同步 | **FAIL**（011–019 清单过时） |
| PASS_RATE 与 WHERE 锚点指令 | **FAIL 冲突**（须改 PASS_RATE） |
| 监听 watcher | 已死 → 本回合重启 |

---

## 审核裁定汇总
- 对象：magma 011/022 · storm 002 · stone 002 · frost/jade 新候选
- Skill 合规：CONDITIONAL（门禁文档已演进；PASS_RATE 未对齐）
- 纪律/闸门：CONDITIONAL
- 结论：**CONDITIONAL**（男稿可留 approved 除 stone 色板质疑；女稿禁 promote）
- 处置：
  1. **禁止**任何 `picks/`
  2. stone/002 **建议降级**（色板不符）
  3. 修正 `ART_REVIEW.md` 保留清单 + `PASS_RATE` 锚点段落
  4. 女角用 beauty board / 新单尾轻甲 PASS 作锚，**禁用** multitail reject 图
