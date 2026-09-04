---
name: visual-art-qa
description: Visual QA for game character/monster art using a vision model — checks body/anatomy integrity, body-type logic, per-race/per-monster feature completeness read from design docs or briefs (extensible to any race or monster without code changes), and cross-race distinction. Use to review any AI-generated or hand-made character sprite, concept, or monster art BEFORE it enters the asset pipeline.
---

# Visual Art QA（视觉美术审核）

用视觉模型（deepseek-vision）对"角色/怪物图"做三层审核，输出可入库/需返工的裁决。
覆盖所有种族与怪物；**新种族/新怪物无需加代码**——审核时读它的设计文档/Brief 即可。

## 何时使用
- 任何 AI 生成的角色/怪物/单位图要进游戏管线前（精灵、概念、图标）
- 用户对"种族特征对不对 / 有没有肢体错乱 / 能不能用"需要裁决时
- 批量审图（一次传多张分别跑）

## 前置
- Python 3 + 网络
- DeepSeek API key：`~/.dsh/.credentials.yaml` 的 `DEEPSEEK_API_KEY`（审核引擎）
- 视觉模型默认 `deepseek-v4-flash-vision-exp`

## 快速使用
```bash
python scripts/qa_vision.py --image <图路径> --race <种族> --monster "<怪物名>" [--brief <brief路径>] [--out <报告路径>]
```
例：
```bash
python scripts/qa_vision.py --image D:/out/dragonman.png --race dragon --monster "焰龙 Flame Drake" --brief D:/GameWorkSpace/TowerDefenseProto/docs/briefs/ARTB-001.md
```
agent 执行后把报告读给用户（或写入变更单）。

## 三层审核（qa_vision.py 已实现，无需手拼 prompt）
1. **LAYER 1 通用结构**（所有图必查）：肢体数量/完整性符合体型；无多/缺/融肢体、多眼多头；手指正常；无裁切/文字/水印；材质自洽（有机/晶体/植物/机械不混）。
2. **LAYER 2 体型逻辑**：先判定体型类别（人形/四足兽/植物体/晶体构装/飞行体/软体/复合），再按该体型的结构规则查。
3. **LAYER 3 Brief 特征核对**：读该怪物的设计文档/Brief（或 RACES/RACE_*.md 中该族条目），逐项验证图中有/无。
4. **EXTRA 族间区分**：该图是否会被误认成其他种族（晶体别像骨头/蘑菇别像肉团/龙族特征要显著）。
裁决：每层 pass/fail + 具体问题清单 + 最终"可入库 / 需返工"。

## 种族特征参考（启动表，非权威）
权威来源 = 项目文档（RACES.md、RACE_*.md、docs/briefs/*、pixelize.py 色板）。审核时若存在 Brief 一律以 Brief 为准；无 Brief 用下表兜底。
见 `references/race-features.md`（当前五族 + 敌族分型 + 材质通则 + 互斥提示）。

## 新种族/新怪物怎么接入（零代码）
1. 按项目习惯为它写一份 Brief（特征清单/色板/体型/互斥项）——见项目 `docs/briefs/ART-BRIEF-模板.md`
2. 审核命令加 `--brief <该Brief路径>` → LAYER 3 自动按它核对
3. 无 Brief 也可口头给 agent 特征描述，agent 加 `--monster` 描述一并核对

## Agent 工作流（DSH/Cursor 通用）
审 → 出报告（逐层过/不过）→ 不过则给具体返工点（如"改竖瞳/露爪/宝石发光"）→ 重生成/重画 → 复审 → 过审才允许进资产管线。

## 逻辑纪律（必读 · 与 design-logic 技能配合）
设计产出过"基本逻辑五关"再交付：①概念定义一致 ②机制/数值自洽（无矛盾、账能算平）③结论前先找反例与退化打法 ④每个断言可验证（给精确值/形状/时机，禁"更强/更爽"）⑤标确定度（事实/假设/口味）。加载 design-logic 技能获得完整方法与谬误速查。
