---
name: skill-designer
description: Creative SKILL / ability design for games — invents unit, tower, or character abilities (active/passive/ultimate) that create meaningful decisions, read clearly in gameplay, and obey the host game's balance and fantasy rules. For tower-defense: abilities must fit a race's resource engine and the "moving units" combat (no free buttons, no trivial spam), with readable feedback and counterplay. Includes verb×target creativity matrices, anti-"god button" checks, and a skill-sheet template feeding the balance model.
---

# Skill Designer（技能设计师）

为单位/塔设计"值得按、记得住、不破坏平衡"的技能。铁律（本项目 RACES 规范）：
**效果量 ≤ 该单位 DPS 需求约 30% · 主动技能 CD ≥ 2 波量级 · 禁止"无敌按钮"**。
技能是"让玩家做决定"，不是"数值礼包"。

## 工作流
1. **摸清宿主**：读该单位所在种族的资源引擎与规范（本项目：RACES.md 各族的 晶能/菌毯/时间轴/经济；技能规范见 docs/skill_system.md；数值见 BALANCE_MODEL + config.gd）。
   技能的成本必须接入本族资源（如硅基技能耗晶能、菌族带 CD/传染条件），不能另起一套资源。
2. **先定"玩家这技能要解决什么局面"**：技能 = 对某类压力局的"花式解法"，先列该单位最怕的 2-3 种压力（高血单体/海量/偷家/远程/控场），技能从中选一，禁止"全解"。
3. **发散：动词×目标矩阵**（3 个方向）：动词（爆发/位移/召唤/转换/延迟/增益/清场/复制）× 目标（单体/群体/自身/场地/经济/下一波）取 3 个最"意外但可用"的组合。
4. **收敛写卡**：一句话效果 + 成本 + 节奏（何时该用/何时不能用）+ 反馈与反制。
5. **过规自检 + 数值粗估**（对照 R2 规范与 config.gd 单位 DPS 档）。

## 设计要点
- **成本进本族引擎**：技能消耗要与"该族怎么攒资源"同源（晶能链长度决定能放几次 → 放技能=取舍）。CD 技能给 2 波级节奏，能量技能给波内多段小节奏。
- **读得懂**：一句话讲清"什么时候按、会怎样"；图标/特效要让玩家在混战中认得出是自己放的。
- **有反制与代价**：要么耗资源、要么有前摇/后摇、要么放弃别的事——按一次技能意味着"没做别的"才算决策。
- **别替代普攻**：技能不该变成"更快的普攻循环"，否则只是数值。
- **协同 > 单卡强**：好技能与同类/同族其他技能有连锁（触发条件/组合收益），引导组队思考。

## 反"无敌按钮"自检
- [ ] 效果有上限（不瞬间清波/不永久无敌/不无限资源）
- [ ] 有使用时机约束（不是"好了就按"）
- [ ] 数值符合 ≤30% DPS 或同量级、CD ≥ 2 波（或经数值复核偏离有理由）
- [ ] 特效/反馈能看清
- [ ] 与同族资源引擎咬合，不另起炉灶

## 技能卡模板
- 名（3 候选）· 归属单位/种族 · 类型（主动/被动/触发/进化技）
- 一句话效果（可验证，禁止"强大/强力"形容词）
- 成本与节奏（资源量 或 CD 波数 · 何时可用/不可用）
- 应对局面（它专克哪种压力）· 弱点（什么局它是废卡）
- 反馈（特效/声音/数字）· 反制（敌人如何对抗它）
- 数值粗估（对照 config.gd DPS 档，给方向值）
- 协同（与哪些技能/单位连锁）· 教学时机（在哪波让玩家第一次用）

## 逻辑纪律（必读 · 与 design-logic 技能配合）
设计产出过"基本逻辑五关"再交付：①概念定义一致 ②机制/数值自洽（无矛盾、账能算平）③结论前先找反例与退化打法 ④每个断言可验证（给精确值/形状/时机，禁"更强/更爽"）⑤标确定度（事实/假设/口味）。加载 design-logic 技能获得完整方法与谬误速查。
