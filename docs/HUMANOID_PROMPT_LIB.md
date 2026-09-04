# 人形角色生成提示词库 + 审核规范（HUMANOID PROMPT LIB & QA）

> 用于生成 DNF 风格"人形"角色图（男性/女性 战士、施法者、头目等）。
> 每个种族都有明确风格基因；男性强壮、女性丰满美型；**肢体完整性是硬红线**。
> 流程：填此库的 prompt → 生成 3-5 候选 → 按本文 §5 审核 → 过审才入库。

## 0. 固定模板（生成时必带）
**正向模板**：
`16-bit DNF-style game character, <种族基因>, <性别体型>, <职业/身份>, <特征细节>, side view facing right, full body, single character, thick dark outline, flat cel shading, limited palette, <姿势>`

**固定负向词（防肢体错乱，勿删）**：
`extra fingers, extra arms, extra legs, missing fingers, deformed hands, claw hands on humans, broken anatomy, fused limbs, dislocated joints, wrong arm count, wrong leg count, extra eyes, extra head, conjoined, mutated extra limb, distorted body, bad hands, bad feet, asymmetrical limbs, photorealistic, 3d render, blurry, multiple characters, text, watermark, chibi`

## 1. 种族基因（必带，体现种族差异）
| 种族 | 基因关键词 |
|---|---|
| 人族 human | `human, normal skin tone, steel-blue + white medieval fantasy armor, knight/cleric aesthetic` |
| 龙族 dragon | `dragon-kin (dragonborn), crimson/orange scales, horns, tail, draconic claws, reptilian eyes, wings optional` |
| 硅基 silicon | `crystal golem, cyan #6FD3E7 glassy shards, glowing energy core in chest, geometric faceted body, angular limbs` |
| 菌族 fungus | `fungal humanoid, mushroom-cap crown, mossy/dotted cap skin, spores, root-like hands` |
| 敌族 enemy | `brutal orc/beast kin, rust-red #BF4A2F, hulking, tusks, heavy armor chunks` |

## 2. 性别体型（按需选）
- **女性 female**：`voluptuous curvy fit female warrior, large breasts, slim waist, attractive face, armor shaped to female form`
- **男性 male**：`massive broad-shouldered muscular male warrior, barrel chest, thick arms, strong jaw, heavy armor`

## 3. 人形提示词库（示例；按需套用）
### 人族
- 女剑士：`female human knight, large breasts, slim waist, long hair, silver sword, round shield, blue steel plate armor`
- 男重战：`male human paladin, massive muscles, two-handed greatsword, steel armor, cloak`
- 女法：`female human sorceress, large breasts, elegant robes, staff, arcane glow`
- 男牧：`male human priest, muscular build, heavy book, golden staff, white robes`
### 龙族
- 男龙战士：`male dragonborn warrior, crimson scales, huge muscles, horns, tail, dragon claws, greatsword`
- 女龙术士：`female dragonborn sorceress, crimson scales, large breasts, curved horns, dragon wings, spellfire`
### 硅基
- 晶核女体：`female crystal golem, cyan shard curves suggesting feminine form, energy core chest`
- 晶岩男体：`male crystal golem, massive angular shard body, heavy crystal arms`
### 菌族
- 菌女祭司：`female fungal humanoid, mushroom-cap crown, dotted cap skin, spore robes`
- 菌男领主：`male fungal humanoid lord, huge mushroom crown, root muscle arms, mycelium cloak`
### 敌族（兽人）
- 女兽人战：`female orc warrior, muscular curvy, tusks, heavy axe, battle scars`
- 男兽人头目：`male orc warlord, colossal muscles, double axe, spiked armor, horned helmet`

## 4. 姿势/动作
`standing idle` / `walking` / `charging attack` / `casting spell` / `victory pose`

## 5. 审核清单（每张过审，缺一不可）
- [ ] **肢体完整**：双手双脚各 2、手指 5 正常、无双臂/缺臂/融合（负向词兜底 + 肉眼/视觉模型复核）
- [ ] 女：胸型自然丰满、无畸形；男：肌肉结构合理、不夸张到畸形
- [ ] **种族特征明显**：龙=鳞+角+尾；硅=晶+发光核心；菌=菇冠+孢子；兽=獠牙+粗壮
- [ ] 朝向/构图：侧面朝右、全身、无裁切
- [ ] 色板符合该族（pixelize PALETTES）
- [ ] 像素层级正确（16-bit 精细，非写实非 8-bit）
- [ ] 单角色、无多余文字/水印/多人物

## 6. 使用
1. 挑 §3 模板 + §1 种族基因 + §2 性别 → 拼成完整 prompt（按 ART_PIPELINE）
2. ComfyUI / Cursor 生成 3-5 seed
3. 用视觉模型（deepseek-vision）或人工按 §5 逐项审
4. 过审 → import_ai_sprite.py → Godot
