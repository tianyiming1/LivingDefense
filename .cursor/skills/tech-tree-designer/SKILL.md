---
name: tech-tree-designer
description: Creative TECH TREE / progression design for games — designs upgrade/evolution trees where nodes create real choices and build identity, paced against gameplay milestones, with costs that respect the economy. For tower-defense: trees tie to race evolution (unit evolution chain), wave pacing, and per-run or meta progression. Includes fantasy naming, meaningful-tradeoff methods, anti-linear-tree checks, and a tree template feeding balance and content docs.
---

# Tech Tree Designer（科技树设计师）

设计"让玩家纠结往哪走"的成长树。铁律：**树的价值 = 分叉带来的选择，不是把线性解锁画成树形**。
每条支线都是"一种玩法性格"；玩家点到哪，就承诺了哪种打法。

## 工作流
1. **摸清宿主成长结构**：本项目有 局内单位进化链（docs/evolution_chain.md、进化费用 CO-007）与 局内轻量装备（装备_局内轻量_v1.md）——先弄清：这个树是 单局内成长（每局重来）还是 跨局 meta（保留），两者节奏完全不同。也读 BALANCE_MODEL（经济曲线决定节点价格量级）与种族表（每族一棵特色树）。
2. **定树的三根主干（fantasy × 强度 × 风格）**：每族/每单位树给 3 条明显不同性格的支线（例：龙族= 喷吐流/翼袭流/熔核阵地流），每条支线一句话 fantasy + 一个核心机制承诺。
3. **设计节点**：层/级 ≤ 5，每层 2-3 选一；叶节点是"玩法变化"不是"+5%"。先画主干再补小节点。
4. **定价与节奏**：对照经济曲线与波次里程碑——关键节点出现在"玩家刚感到该压力"的波后；不该出现"第 2 层就点满 T0 毕业装"。
5. **收敛审计**：走一遍"最短路玩家 vs 全收集玩家"看是不是一边倒；保证没有必点不可替代的单节点。

## 创意工具
- **三性格法**：任何单位/种族先给 3 条支线的"性格词"（稳/险/巧…），支线命名与其玩法一致，让玩家光看名字就知道这路是什么玩法。
- **承诺制设计**：点支线 = 承诺打法，另一条支线的强卡必须对这套打法构成诱惑（制造"下一局想试另一种"的钩子）。
- **代价显形**：不是"选 A 就没有 B"，而是"选 A 后 B 类怪变难/某资源变贵"——让选择有可见代价。
- **名字即记忆**：节点名带幻想与动词（"熔核过载" 好过 "伤害+20%"），数值藏在名字下的具体规则里。

## 反线性树自检
- [ ] 存在真正互斥分叉（点了 A 就点不了同级 B，且 A/B 强度接近）
- [ ] 无"必点核心"单节点（每个节点都有替代路线）
- [ ] 支线性格可一句话说清，不同支线玩法有实质差异
- [ ] 价格与当前波次经济匹配（不卡死也不白给）
- [ ] 命名有记忆点，不与其它树撞名

## 树模板
- 归属（单位/种族/全局 meta）· 树名（3 候选）· 一句话幻想
- 三主干（各：性格词 / 核心机制承诺 / 首个关键节点）
- 节点明细：层→节点名 / 效果（可验证）/ 前置 / 价格（对照经济） / 出现波次
- 叶节点三思：是不是"玩法变化"？有没有替代？
- 节奏注记：哪个里程碑解锁哪层（喂 milestone/M0-M5 门禁）
- 反爬坑：若全收集更强太多，如何让"窄而深"路线也成立

## 逻辑纪律（必读 · 与 design-logic 技能配合）
设计产出过"基本逻辑五关"再交付：①概念定义一致 ②机制/数值自洽（无矛盾、账能算平）③结论前先找反例与退化打法 ④每个断言可验证（给精确值/形状/时机，禁"更强/更爽"）⑤标确定度（事实/假设/口味）。加载 design-logic 技能获得完整方法与谬误速查。
