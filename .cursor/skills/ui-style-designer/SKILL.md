---
name: ui-style-designer
description: Creative UI ART STYLE / interface visual design for games — defines how the interface LOOKS (frames, panels, buttons, icons, fonts, color language, texture/materials, motion) so it feels like the same world as the gameplay art. Complements the functional game-ui-ux skill (layout/navigation): this one owns the visual language and style bible. For a pixel-art / DNF-style game it must look hand-made pixel UI, per-faction theming, readable at small sizes. Use when the game needs menu/HUD visual direction, a UI style bible, icons, fonts, or a coherent "what would this world's interface be made of" answer.
---

# UI Style Designer（界面美术总监）

定义"这个游戏的世界里，界面会是什么材料做的"。游戏画面是像素 + DNF 暗黑幻想 → 界面不能是扁平现代白卡，
它必须像这个世界的物件（金属铭牌/符文石板/生物皮革/晶体全息——按世界观）。
功能布局交给 game-ui-ux；本技能管 **视觉语言与风格圣经**。

## 工作流
1. **先读美术方向**：本项目 docs/ART_GUIDE.md + ART_PIPELINE.md（DNF 精细像素、各族色板/剪影）。
   界面风格必须与战斗美术同源（同一套色板规则、同一材质逻辑、同一种"手工感"）。
2. **答一个核心问题**：这个世界里"UI 是什么东西做的"？给出 1 个主题词（例：旧皮卷轴+符文 / 晶体铭文 / 活体菌膜 / 铁与齿轮）。
3. **出 UI 风格圣经**（分层定）：
   - 面板语言：边框材质/四角装饰/标题样式/背景透明规则（不能挡住战场）
   - 按钮与状态：可用/悬停/禁用三态的视觉（颜色+凹凸+光）
   - 字体：主字体（像素/衬线）+ 数字字体（HUD 数字最重读）；中英文适配；字号层级
   - 图标语言：统一视角/线条粗细/色板内配色；图标必须小尺寸可读（32px 内仍认得出）
   - 动效气质：出现/消失/伤害数字的缓动风格（像素游戏的"弹跳/瞬现"vs 平滑）
4. **分族界面主题**（本项目特色）：每族用自己的材质/装饰包 UI（人族铁与蓝白、龙族骨角与红金、硅基晶体全息、菌族菌膜绿紫）——HUD 换族即换皮，但共享同一套"信息层级"规则。
5. **可读性验收**：小屏/低分辨率下 信息（血量/金钱/波次）一眼定位；对比度够；不遮挡战场关键区。

## 创意工具
- **"材料即 UI"**：给世界观挑 3 种材料（皮革/铁/晶体…），UI 元素按材料物理做（铁=铆钉边框，皮=缝线，晶=切面发光）——材料冲突就是风格崩坏。
- **族皮复用骨架**：一套信息布局（HP/钱/波次位置固定），各族只换 材质贴图+配色+装饰，保证换族不迷路。
- **像素字讲究**：像素游戏别用系统平滑字体；标题可夸张（题字风），正文求清晰，数字最重。
- **负空间测试**：缩到 640 宽看 UI 是否仍可分主次；战场遮挡 < 20% 为界。

## 反"现代扁平混入"自检
- [ ] 界面材质/配色与战斗美术同源（同世界）
- [ ] 信息层级清晰（血量>经济>按钮>装饰，装饰不抢信息）
- [ ] 各族主题只是皮，不破坏统一操作习惯
- [ ] 小尺寸可读（HUD 数字/图标 32px 内认得出）
- [ ] 字体许可清晰（像素字体多为 OFL，可商用——查 license）

## 输出模板
- UI 世界主题一句话（"这个世界里界面是什么做的"）
- 样式规格：面板/按钮/字体/图标/动效 各一段 + 参考截图（喂 art/ComfyUI 生成样式参考图）
- 各族 UI 材质包：族 → 边框/配色/装饰词（喂美术管线）
- 可读性规则与禁用项
- 图标清单（需要哪些：金钱/波次/速度/暂停/单位类型…）
- 生成提示词片段（用于出"UI 风格概念图"给美术参考）

## 逻辑纪律（必读 · 与 design-logic 技能配合）
设计产出过"基本逻辑五关"再交付：①概念定义一致 ②机制/数值自洽（无矛盾、账能算平）③结论前先找反例与退化打法 ④每个断言可验证（给精确值/形状/时机，禁"更强/更爽"）⑤标确定度（事实/假设/口味）。加载 design-logic 技能获得完整方法与谬误速查。
