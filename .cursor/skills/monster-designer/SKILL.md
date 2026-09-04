---
name: monster-designer
description: Creative MONSTER / enemy design for games — invents memorable creatures with a readable silhouette, a coherent body-plan and material logic, a clear threat ROLE in the gameplay loop (grunt/runner/tank/controller/siege/boss), and a visual identity that fits the faction or race it belongs to. Includes divergent creativity techniques (body-plan fusion, role×biome matrix, silhouette-first), anti-cliché and AI-artifact checks, and a monster-sheet template that feeds art QA and balance.
---

# Monster Designer（怪物设计师）

创作"玩家第一眼就懂怎么对付、且记得住"的怪物。三条铁律：
**剪影先于细节 · 体型逻辑自洽 · 每个怪逼出一个玩家决策**（不只换皮加数值）。

## 工作流
1. **摸清宿主**：读宿主敌方/生态体系（本项目：敌族资产清单 + 各玩家种族文档 + 数值模型 config/BALANCE_MODEL），确认它属于哪个势力、出现在哪波、在威胁谁。任何新怪必须能塞进波次与已有怪不抢戏。
2. **定角色（ROLE）先于外貌**：它在这波里扮演什么（grunt 消耗/runner 偷家/tank 压线/controller 干扰/siege 远程/boss 高潮）——角色决定它能做什么，外貌服务于角色。
3. **发散：剪影三连**（每个新怪先给 3 个剪影方向，只画轮廓词不给细节）：
   - 形状语言：敦厚(压线)/修长(快速)/多刺(威胁)/圆钝(嘲讽)…… 96×108 下一眼可分
   - 材质逻辑：皮肉/鳞甲/甲壳/晶体/植物/机械——和所属势力一致（别让硅基怪长蘑菇、菌族怪穿板甲，除非 Brief 明确混血）
   - 运动方式：走/爬/滚/飞/钻地/分裂——运动本身就是威胁信息
4. **收敛 1 个**，写怪物表。
5. **过审美关卡**：视觉自洽 + 不与玩家四族混淆 + 肢体结构完整（配合 visual-art-qa 审图）。

## 创意工具
- **角色×生态矩阵**：8 个生态种子（火山/冰原/菌沼/晶矿/废土/深海/天穹/梦境）× 8 个角色种子（肉盾/刺客/召唤/腐蚀/自爆/分裂/幻觉/寄生）交叉取意外格。
- **体型融合法**：两个动物的身体结构合（不是贴皮毛，是换"支撑结构"：如 蟹×蛇=移动堡垒？蜘蛛×鸟=织网掠食者？），保最可辨识器官各一。
- **反克制法**：先定"玩家哪套防线最怕什么"，再倒推怪（对空弱→造飞行；群伤强→造高血量单体……）——让怪不是独立炫技，而是补全威胁面。
- **进化心理**：给怪一个"生存理由"（为什么长这样/这样进攻），理由荒谬也没关系但要自洽——荒谬自洽反而出记忆点。
- **名字与叫声**：名字 3-5 候选（可玩性>文雅），叫声一句描述（喂音效）。

## 反陈词滥调 & AI 产物自检
- [ ] 角色定位清晰（玩家知道先打谁/怎么打）
- [ ] 与同波其他怪有"化学反应"（组合威胁，不是各打各）
- [ ] 不是常见怪换色（龙=喷火/史莱姆=黏人这种照搬要重做）
- [ ] 结构能过视觉 QA（无多腿/断肢/六指；四足就四足）
- [ ] 可生成性：描述里避免 AI 易翻车的点（复杂多手/密集小齿/细碎纹理→改大块特征）

## 怪物表模板（输出）
- 名（3-5 候选）· 势力归属（敌族/某玩家族变体）· 一句话威胁
- ROLE（grunt/runner/tank/controller/siege/boss）+ 行为模式一句话
- 外形：剪影词 / 体型类别（visual-art-qa LAYER2 用）/ 材质 / 主色板 / 标志性特征（1-2 个一眼可辨）
- 与玩家/其他怪的互动（它的出现逼出什么决策）
- 数值方向（血量/速度/攻击档位，粗给即可，细调走 config.gd）
- 波次定位（第几波第一次出现/哪个族任务线）
- 美术提示词片段（喂生成）+ 审图用特征清单（喂 visual-art-qa）
- 变体灵感（升级版/精英版怎么改一个维度）

## 逻辑纪律（必读 · 与 design-logic 技能配合）
设计产出过"基本逻辑五关"再交付：①概念定义一致 ②机制/数值自洽（无矛盾、账能算平）③结论前先找反例与退化打法 ④每个断言可验证（给精确值/形状/时机，禁"更强/更爽"）⑤标确定度（事实/假设/口味）。加载 design-logic 技能获得完整方法与谬误速查。
