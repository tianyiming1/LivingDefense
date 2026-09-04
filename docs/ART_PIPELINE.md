# 美术产出流程规范（ART_PIPELINE）

> 适用于本项目的所有 AI 工具（DSH agent、Cursor、ComfyUI、任何生图渠道）。
> 原则：**先定规范 → 按规范生成 → 管线转像素 → 验收才交付**。AI 是笔，不是最终答案。

## 0. 已有美术上下文（先读）
- `docs/ART_GUIDE.md` — 美术方向与色板（硅基/菌族/dragon 等）
- `kb/08-美术方向.md` — 知识库美术章节
- `docs/ai_concepts/` — 历史概念图；`docs/ai_concepts/approve/` — 已批准
- `tools/gen/prompts_external.json` — 现有资产清单；`tools/gen/pixelize.py` PALETTES — 各族色板

## 1. 风格锁定（每次生成前确认 5 项）
1. **风格定位**：本项目目标 = DNF 式精细像素精灵（16-bit：明暗层次 + 细节 + 硬像素边缘 + 深色描边；非 8-bit 粗颗粒、非照片写实）
2. **线条**：清晰硬朗、深色/黑色描边
3. **上色**：cel / 分层明暗，低色阶，无平滑渐变
4. **色板**：符合所属种族色板（见 pixelize.py PALETTES）
5. **细节密度**：中——轮廓可读优先

## 2. 生成（AI 出草稿）
- prompt 模板（英文）：`pixel art / 16-bit game sprite, <角色描述>, <色板词>, side view, full body, single character, thick dark outline, flat shading, limited palette, <姿势>`
- 负向词：`photorealistic, realistic photo, 3d render, 8-bit chunky, smooth gradient, blurry, multiple characters, spritesheet, text, watermark, deformed`
- 一次多 seed 出 3-5 张候选，不逐张碰运气
- 渠道：ComfyUI 本地免费（写实/大场景强）、Cursor 云端（像素指令理解强）、DSH 会话走规范

## 3. 转像素（AI 图 → 游戏精灵，必走项目管线）
1. 选一张草稿
2. `python tools/gen/import_ai_sprite.py --id <race>/<unit> --retro`（裁主体→量化色板→96×108→描边）
3. 多帧动画（行走/攻击）：用像素工具（Aseprite/LibreSprite）按网格+色板重绘保证帧间一致
4. 产物进 `assets/pixels/{race}/`，F5 预览

## 4. 验收关（交付前逐项打勾）
- [ ] 色板符合该种族（对照 PALETTES）
- [ ] 轮廓在 96×108 可读
- [ ] 角色特征完整（对照资产 brief）
- [ ] 无破损部位
- [ ] Godot 预览正常
不过关 → 回到第 1/2 步迭代，禁止"多跑几张碰运气"。

## 5. 记录
- 产出记 模型/seed/提示词/后处理路径（tools/gen 候选库）
- 批准资产进 `docs/ai_concepts/approve/` + asset 清单
- 每个任务按项目惯例写 CO 变更单
