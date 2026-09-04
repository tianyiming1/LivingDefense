---
name: unit-designer
description: Creative UNIT / roster design for games — designs the playable units of a faction or race as a complementary ROSTER (roles, behaviors, stat directions, economy, counters) rather than isolated units. For tower-defense with moving units: units must fill threat-cover roles (anti-group/anti-tank/anti-air/utility), vary in movement/attack style, read visually, and cost-match their role. Coordinates with race-designer (race identity), skill-designer (abilities), monster-designer (enemy side), balance model, and art QA. Includes roster-coverage checks and a unit-sheet template.
---

# Unit Designer（兵种/单位设计师）

设计一个种族内部的**单位阵容**：单位不是孤立的"塔"，是一支各司其职、互相补位的队伍。
铁律：**阵容覆盖威胁面 · 单位行为差异 = 玩法差异 · 每单位有明确反制与代价**。
对"会动的塔"：行为（游猎/卡位/后排/拦截/铺地…）本身就是单位差异，别只靠数字。

## 工作流
1. **摸清宿主**：读该族设定（RACES.md / RACE_*.md）与战斗底座 BASE_COMBAT（会动的塔：单位可移动/自动攻击/有移速/可被反击）+ config.gd 数值档 + 该族资源引擎。
2. **威胁覆盖审计（先做）**：敌人有哪几类压力（海量低血/高血单体/空中/偷家/特殊机制）？现阵容覆盖了哪些、漏了哪些？单位设计先补漏。
3. **定阵容骨架**：一个健康阵容 ≈ 3-5 单位 = 前排/输出/功能 + 每个单位一两个"反制谁、被谁克"：
   - 前排/拦截位（卡位或硬挡）· 后排输出位（对群/对单/对空分型）· 功能位（控制/铺地/增益/经济）
4. **逐单位设计**：行为模式 → 数值方向 → 视觉 → 名字 → 反制关系（见单位卡模板）。
5. **协同与教学**：单位间连锁（组合收益）与"每族 3 问教学"（玩家何时该买它、何时不该）。
6. **过规审计**：不超经济（价格×性能≈同族其他单位）、不碾压同类（避免"XX 完全替代 YY"）、每单位有"这波不该出它"的局。

## 设计要点
- **行为即身份**：同族单位靠 行为+体型+射程 区分（短宽步兵卡位 vs 高瘦火枪后排），数字排第二。
- **数值分工清晰**：DPS 型/爆发型/持续型/坦度型/功能型，别把单位做成"全能微强"。
- **会动塔的代价**：单位会死 → 死了是损失（重购/再生规则由族定）→ 越贵越要有"别让它白送"的理由。
- **一眼可读**：单位剪影/色板在同族内也互不混淆（人：矮重步兵≠高瘦火枪；龙：幼龙≠焰龙≠泰坦）——喂 visual-art-qa。
- **可升级路径**：进化链（evolution_chain.md）给每单位一条"性格强化"方向，不是纯数值。

## 反"堆数值"自检（单位级）
- [ ] 阵容覆盖 3 类以上敌人压力（对群/对单/对空或功能）
- [ ] 无"上位替代"（每个单位有专属使用场景）
- [ ] 行为/射程/体型有实质差异，非换皮数值
- [ ] 价格×性能与该族经济自洽（对照 config.gd/BALANCE_MODEL）
- [ ] 有明确反制（某波/某怪让它难受）
- [ ] 视觉/名字与同族不撞

## 单位卡模板
- 名（3 候选）· 种族 · 阵容角色（前排/对群/对单/对空/功能/经济）
- 行为一句话（会动的塔：移动/攻击/拦截/技能行为）
- 数值方向（血/攻/速/射程/价格档，给相对档位：对比同族基准）
- 反制与代价（它怕什么 / 什么时候不该出）
- 与同族其他单位的组合/协同
- 进化方向（升级后性格怎么变）
- 视觉 DNA（体型词/剪影/色板提示，供美术）
- 教学时机（第几波/什么局面让玩家第一次买它）

## 与其它技能交接
种族 → race-designer 定引擎与行为轴；单位 → 本技能定阵容；单位技能 → skill-designer；
敌方威胁 → monster-designer；美术 → art 规范 + visual-art-qa；数值 → config.gd/BALANCE_MODEL。

## 逻辑纪律（必读 · 与 design-logic 技能配合）
设计产出过"基本逻辑五关"再交付：①概念定义一致 ②机制/数值自洽（无矛盾、账能算平）③结论前先找反例与退化打法 ④每个断言可验证（给精确值/形状/时机，禁"更强/更爽"）⑤标确定度（事实/假设/口味）。加载 design-logic 技能获得完整方法与谬误速查。
