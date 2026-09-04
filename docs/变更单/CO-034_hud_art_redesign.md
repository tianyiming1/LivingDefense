# 变更单 CO-034：HUD 美术改版（Dota2 映射 · 布局冻结 · 资产清单）

- **状态**：待工程接入（**v2 · Dota2 布局**，废止左竖栏商店草案）
- **日期**：2026-09-03
- **Owner**：美术总监（拍板）
- **协作**：UI·UX 设计师（布局）· 概念美术（资产清单）· 工程线（约束举证，不改设计方向）
- **视口**：`Config.VIEW_SIZE` = **1280×720**（坐标均为相对此分辨率的像素）
- **不改代码**：本单只冻结设计；实现另开工程任务

## 为什么变

1. **事实**：`scripts/hud.gd` 用绝对坐标散落 Label/Button，无面板质感（顶栏 `(14,10)`、商店 `Vector2(1280-124, 84)`、底栏 `(14, 720-62)`、信息板 `(1280-330, 720-158)`）。
2. **冲突**：大本营在路径终点右侧（Map A 钳位后约 **x≈1240**，`hq.gd` 命中盒约 `56×64`）；单位商店贴右缘 **x∈[1156, 1266]**，与 HQ 世界点击区水平重叠 → 点大本营科研 vs 点部署互抢。
3. **玩法依赖**：人族要点大本营开科研（CO-032）；部署兵将从大本营走出（CO-033）——HQ 必须可稳定点中，且右侧出兵视线不被商店挡住。
4. **用户新约束（本版拍板）**：页面布局参考 **Dota 2** 信息架构（顶栏比分区 / 左下小地图位 / 底中英雄栏 / 右下小簇），映射到本游戏资源·商店·单位栏·波次簇。

## 工程约束（只读，本单不改方向）

| 约束 | 来源 | 设计对策 |
| --- | --- | --- |
| 视口固定 1280×720 | `Config.VIEW_SIZE` | 布局表按此冻结；缩放另议 |
| HQ 在 PATH 末点外推后钳进视口 | CO-032 / `hq.gd` | 安全带要求工程将 HQ 中心 **x** 钳入下表区间 |
| 科研仅 HQ 选中时显 | CO-032 | **点 HQ 弹出**科研面板（对标 Dota 点商店开面板）；矩形仍冻结，关闭时整矩形不可点 |
| 出图管道 | `comfy_pixel_gen.py` + `prompts_comfy.json` → `_studio/` | UI 候选进 `_studio/ui/`；ship 契约见 `assets/pixels/README.md` |
| 商店按钮数随种族变化 | `Config.shop_units` | **左下**商店用网格/横排槽位，槽尺寸固定，溢出可换行或页签（实现细节归工程） |

---

## A. Dota2 → 本游戏映射（必须遵守）

| Dota2 | 本游戏 | 冻结锚点 |
| --- | --- | --- |
| 顶栏比分 / 时间 | **顶栏居中**：金钱、补给、大本营 HP、波次、战损 | 顶栏 |
| 左下小地图 | **左下：部署商店**（单位购买按钮网格 / 横排） | 商店 |
| 底中英雄面板 + 技能栏 | **底中：选中单位信息 + 进化 / 出售 / 分裂 + 种族技能** | 单位栏 |
| 右下商店按钮 | **右下仅**「开始波次 / 变速 / 菜单」**小簇**；真正科研用 **点大本营弹出** | 波次簇 + 科研弹层 |
| 战场中央 / 两侧净空 | **右缘大本营世界区 x ≥ 1100 禁止常驻大块 UI**（HQ 可点） | 禁带 |

**硬约束（拍板）**

1. **大本营在路径右端**；HQ 世界点击区与任何常驻可点 UI 矩形 **零重叠**。
2. **商店不得与 HQ 点击区重叠**；商店整面板落在左下，右缘 **≤ 336**。
3. **右侧世界禁带**：x ∈ **[1100, 1280]** **禁止常驻大块 UI**（商店、单位信息板、科研常驻位均不得进入）。顶栏文字若延伸至此带，必须 `MOUSE_FILTER_IGNORE`。
4. **右下波次簇**允许贴底进入 x≥1100（高度 ≤ 48、宽度 ≤ 172），因其与 HQ 命中盒 **纵向分离**（簇 y≥664；HQ 命中建议 y∈[220,360]）；不得放大成面板。
5. **科研面板**仅 HQ 选中时显；关闭后不可点；打开时矩形仍 **不得**与 HQ 命中盒相交（贴在禁带左侧）。

---

## B. 布局冻结表（1280×720）

坐标系：原点左上；矩形写 **左上角 (x,y) + 宽×高**；锚点描述便于工程改 Control 锚定。

| 区块 | 锚点 | 冻结矩形 (x, y, w, h) | 备注 |
| --- | --- | --- | --- |
| **顶栏（居中）** | 顶中 | **(240, 6, 800, 36)** | 金钱 / 补给 / HQ HP / 波次 / 战损；水平居中视觉；右缘 = 1040 **&lt; 1100** |
| **状态行** | 顶栏下居中 | **(240, 44, 800, 24)** | `status_label` 单行提示；可点过滤 IGNORE |
| **部署商店** | 左下（小地图位） | **(8, 568, 320, 144)** | 槽位约 **72×56**，横排 4 或 2×N 网格，separation 8；**禁止**再使用 `(1156,84)` / 左竖栏通高 |
| **单位信息 + 操作 + 技能** | 底中（英雄栏位） | **(340, 568, 560, 144)** | 左半：选中单位名/HP/伤；中：进化/出售/分裂；右：种族技能键位；无选中时可缩为仅技能或半透明空态 |
| **波次 / 变速 / 菜单小簇** | 右下 | **(1100, 668, 172, 44)** | 三钮横排约 52×36；**仅此小簇**可驻右下；禁止扩成商店或信息板 |
| **科研弹层** | HQ 选中时，禁带左侧 | **(900, 160, 190, 300)** | 对标 Dota 点商店开面板；仅人族 + HQ 选中；关闭时整矩形不可点；右缘 = 1090 **&lt; 1100** |
| **大本营世界安全区** | 世界坐标 | **HQ 中心 x ∈ [1120, 1232]**（`[VIEW_W−160, VIEW_W−48]`）；命中盒建议 ≤ `56×64` 且整体落在 **x∈[1092, 1260], y∈[220, 360]**（Map A 终点高度附近可随 PATH 微移 y，**x 钳位不可破**） | 该区无常驻大块 UI hit；与商店 / 单位栏 / 科研弹层矩形相交面积 = 0 |

### 布局关系（一句话）

**顶栏居中资源战报，左下部署商店，底中单位信息与技能，右下仅波次小簇；科研点 HQ 弹出；右缘 x≥1100 净空给大本营。**

```
0                              640                             1280
┌──────────── 顶栏居中 (240,6)–(1040,42) ──────────────────────┐████┐
│              状态 (240,44)–(1040,68)                          │禁带│
│                                                              │x≥  │
│                         战场                                 │1100│
│                                           ★ HQ               │    │
│                              ┌科研弹层(HQ选中)┐               │    │
│                              │(900,160) 190w │               │    │
│┌商店 320w────────┐┌──── 单位栏 560w ────────────┐┌波次簇────┐│    │
││(8,568) 144h     ││(340,568)                    ││(1100,668)││    │
││网格/横排购买    ││信息+进化出售分裂+种族技能   ││44h 小簇  ││    │
└──────────────────┴──────────────────────────────┴───────────┴████┘
```

### 相对现状 / 旧草案的强制迁移

| 旧位置（含 CO-034 v1 左竖栏） | 新位置（Dota2 映射） |
| --- | --- |
| 商店 `(1156, 84)` 右缘 **或** `(8, 80)` 左竖栏通高 | **(8, 568, 320, 144)** 左下横/网格 |
| 科研 `(14, 78)` / `(188, 80)` 常驻左 | **(900, 160, 190, 300)** HQ 选中弹层 |
| 信息 `(950, 562)` 右下 **或** `(8, 560)` 左下 | **(340, 568, 560, 144)** 底中并入操作+技能 |
| 底栏开始/变速/菜单贴左 `(8, 658)` | **(1100, 668, 172, 44)** 右下小簇 |
| 顶栏左贴 `(8, 6, 1000, 36)` | **(240, 6, 800, 36)** 居中 |
| HQ ≈ x=1240（`VIEW_W-40`） | 钳入 **[1120, 1232]** |

---

## C. 视觉方向 + 角色色

**方向一句**：扁平面板木石堡垒 HUD——高对比色块分区、像素描边可读、图内永不烧字。

| 角色 | Hex | RGB (0–1 约) | 用途 |
| --- | --- | --- | --- |
| 金币 | `#FFD866` | (1.00, 0.85, 0.40) | 金钱数字、钱袋图标 |
| 大本营危 | `#F24444` | (0.95, 0.27, 0.27) | HQ HP≤20% / 漏怪警示 |
| 补给 | `#7ACC5C` | (0.48, 0.80, 0.36) | 人族补给条与标签 |
| 中性木石 | `#6B5B45` 面板 / `#2A261F` 底 | (0.42,0.36,0.27) / (0.16,0.15,0.12) | 九宫边框、槽底 |
| 强调 | `#E8B84A` | (0.91, 0.72, 0.29) | 选中描边、主按钮、HQ 选中环 |

族专属点缀（不进本单主五色，实现时沿用 CO-017）：晶能青 `#73D9FF`、龙巢橙 `#FF8C47`。

---

## D. 像素 UI 资产清单 → `_studio/ui/`

命名建议：`NNN_raw.png` / `NNN_game.png`（与 studio 编号惯例一致）；下列为逻辑名，归档时加序号。

| # | 建议文件名（game） | 用途 | 建议尺寸 | 生成方式 |
| --- | --- | --- | --- | --- |
| 1 | `panel_frame_9slice.png` | 顶栏 / 商店 / 单位栏 / 科研底板九宫 | **96×96**（中心透明或深色，边 12px 可切） | **优先程序九宫**（`StyleBoxFlat` / 手绘 9-slice）；Comfy 仅当需要纹理噪点时补一张参考 |
| 2 | `shop_slot.png` | 部署商店单槽底 | **72×56**（可九宫拉伸至槽格） | **Comfy** |
| 3 | `shop_slot_disabled.png` | 锁定 / 买不起槽 | **72×56** | 程序压暗 `shop_slot` **或** Comfy 变体一张 |
| 4 | `btn_primary.png` | 开始波次 / 主操作 | **96×32**（九宫或三态 stretch） | **Comfy** |
| 5 | `btn_secondary.png` | 变速、菜单、出售 | **96×32** | **程序**（同主按钮降饱和）即可 |
| 6 | `btn_icon_money.png` | 顶栏金币图标 | **32×32** | **Comfy** |
| 7 | `btn_icon_supply.png` | 顶栏补给图标 | **32×32** | **Comfy** |
| 8 | `btn_icon_hq.png` | 顶栏 HQ HP 图标 | **32×32** | **Comfy** |
| 9 | `hq_plaque.png` | HQ 选中环旁铭牌 / 科研弹层顶饰（对标商店招牌） | **64×32** | **Comfy** |
| 10 | `tech_slot.png` | 科研条目底 | **96×28** | **程序**复用 `shop_slot` 缩放即可 |

**优先生成（概念美术本周）**：`shop_slot`、`btn_primary`、`btn_icon_money`、`hq_plaque`；`panel_frame` 默认程序九宫，不堵工程。

**Studio 路径**：`assets/pixels/_studio/ui/`（可分子夹 `frame/` `slot/` `btn/` `icon/`）；**禁止**直接写入 ship。Promote 进游戏时另开单约定 `assets/pixels/ui/` ship 契约（本单不建 ship 路径）。

**条数**：清单 **10** 项（Comfy 必出优先 **4**：2、4、6、9；程序 **4–5**）。

---

## E. Comfy 出图 prompt 草稿（英文 · 可贴 `prompts_comfy.json` preset）

公共负向追加：`text, letters, numbers, watermark, ui mockup screenshot, blurry, soft airbrush, 3d render, photo, thick bevel chrome, purple glow`

建议 defaults 覆盖：`img2img: false`，`game_w/game_h` 按表，`archive_id: "ui"`（工具若需目录则映射 `_studio/ui/`）。

### preset `ui_shop_slot`

```
pixel art UI shop slot panel, 72x56 game asset, flat wooden stone rectangle, dark brown fill, light beige 2px border, empty center for unit icon, readable at small size, solid black background, no text, no numbers, single object centered
```

### preset `ui_btn_primary`

```
pixel art UI primary button face, 96x32, flat amber gold wood plank button, darker bottom edge, subtle stone corners, high contrast, game HUD, solid black background, no text, no letters, no numbers, single centered rectangle
```

### preset `ui_btn_icon_money`

```
pixel art coin pouch icon, 32x32, small gold coins and brown pouch, flat readable silhouette, game HUD icon, solid black background, no text, no numbers, single object centered
```

### preset `ui_btn_icon_supply`

```
pixel art supply crate icon, 32x32, wooden crate with green leaf mark, flat readable, game HUD icon, solid black background, no text, no numbers, single object centered
```

### preset `ui_btn_icon_hq`

```
pixel art fortress keep icon, 32x32, small stone castle gate tower, flat readable silhouette, game HUD icon, solid black background, no text, no numbers, single object centered
```

### preset `ui_hq_plaque`

```
pixel art HQ plaque nameplate, 64x32, short medieval stone fortress plaque bar, muted gold and brown, flat readable, game HUD ornament for selected keep, solid black background, no text, no letters, no crest symbols that look like letters, single object centered
```

### preset `ui_panel_frame`（可选；默认可不做）

```
pixel art UI nine-slice panel frame, 96x96, empty transparent center, wooden stone border 12px thick, corner studs, flat readable, solid magenta center for mask OR pure black center, no text, no ornaments blocking corners
```

---

## F. 验收标准（可打勾）

- [ ] **Dota2 映射位正确**：商店在左下、单位栏在底中、波次簇在右下、顶栏资源居中；无左竖栏通高商店、无右缘常驻商店。
- [ ] **商店矩形** = **(8, 568, 320, 144)**（或严格落在其内）；商店与 HQ 命中盒相交面积 = 0。
- [ ] **右侧禁带** x ∈ **[1100, 1280]** 内：无常驻大块 `MOUSE_FILTER_STOP` HUD（商店 / 单位栏 / 科研常驻位禁止）；允许的唯一常驻可点块为波次簇 **(1100, 668, 172, 44)**。
- [ ] **HQ 世界中心 x** 落在 **[VIEW_W−160, VIEW_W−48] = [1120, 1232]**；HQ `contains_point` 与商店 / 单位栏 / 科研弹层矩形相交面积 = 0。
- [ ] 人族：点 HQ → 科研出现在 **(900, 160, 190, 300)** 内且可点；再点商店槽 → 进入放置，不误触 HQ。
- [ ] 顶栏五色角色色已套用（金币 / 危 / 补给 / 木石底 / 强调选中）；图内资产无烧录文字。

---

## 变更影响范围

| 层 | 影响 |
| --- | --- |
| 设计 | HUD 改为 Dota2 映射；废止 CO-034 v1 左竖栏；CO-017 文案结构保留，仅换位与贴图 |
| 工程（待接入） | `hud.gd` 控件坐标 / 锚定；可选 `hq.gd` 钳位；Theme / 九宫；科研改为 HQ 弹层 |
| 美术 | `_studio/ui/` 出图与筛选（`panel` / `slot` / `btn` / `hq_plaque`） |
| 玩法数值 | **无**（不改 `config.gd` 经济公式） |
| 测试 | 手工点测 + 可选后续给 S1 加「禁带无大块 hit」断言 |

## 批准

| 项 | 值 |
| --- | --- |
| 设计批准 | 美术总监（本单） |
| 用户最终拍板 | 待确认 |
| 生效版本 | 工程接入并勾选 §F 后标「已实施」 |

## 派工建议（非本单范围）

1. 概念美术：按 §E 写入 `prompts_comfy.json` 并生成优先 4 张 → `_studio/ui/`。
2. 工程：按 §B 改 HUD 坐标与 HQ 钳位；面板可先用程序九宫，贴图后替换。
3. QA：按 §F 打勾；回归人族 HQ 科研 + 商店部署 + CO-033 出兵。
