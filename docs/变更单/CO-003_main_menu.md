# 变更单 CO-003：主页面（主菜单）+ 场景切换

- 状态：已批准 → **已实施并验收通过**（本会话）
- 生效版本：S1 人族（当前原型）
- 需求来源：用户 —— "要有主页面"

## 为什么变
- 当前启动直接进战场（main.tscn 即主场景），无入口/出口流程，作为"游戏"不完整。
- 主菜单是中英双语玩家与发售（M4/M5）的必备导航层，架构期补一次到位。

## 影响范围
- 新增：menu.tscn + menu.gd（主菜单场景，脚本构建 UI，与现有 demo 模式一致）
- 修改：project.godot (run/main_scene → res://menu.tscn)、translations/strings.csv（菜单键）、hud.gd（底栏加"菜单"按钮 + 信号）、main.gd（连接并切场景）
- 不修改：玩法/数值/战斗逻辑（菜单只做入口与出口）

## 技术决策
- 方案：独立场景 menu.tscn 作为主场景；开始按钮 `change_scene_to_file("res://main.tscn")`；游戏内"菜单"按钮返回
- 语言：菜单放语言按钮（当前语言显示，点击切换，全局 TranslationServer 生效并带入游戏）；游戏内保留 T 键热切
- 默认语言：启动强制 zh_CN（与 CO-002 验收标准 1 一致）
- 中止游戏回菜单：不保存进度（原型阶段明确行为，波次中直接退出）

## 验收标准（可验证行为）
1. 启动显示主菜单（默认中文），标题 + 开始游戏 + 语言按钮 + 控制说明 + 退出
2. 开始游戏进入战场；游戏内底栏"菜单"按钮任意时刻返回主菜单
3. 菜单语言按钮点击立即切换中/英，且切回游戏后仍保持该语言
4. 无控制台报错
## 实施结果（工程线返档，文档与实现一致）

- `menu.tscn`（主场景）+ `scripts/menu.gd`：深色渐变背景 / 标题 / 副标题 / 开始游戏 / 语言按钮 / 退出 / 底部控制说明，全部 tr() 双语，语言按钮点击即切（全局 TranslationServer）
- `project.godot`：`run/main_scene` → `res://menu.tscn`
- `hud.gd`：新增 `menu_requested` 信号 + 底栏"菜单"按钮（refresh_texts 同步重刷）
- `main.gd`：连接 `menu_requested` → `_on_menu()` 切回菜单；**移除 _ready 强制 set_locale**（语言入口收敛到菜单，避免覆盖玩家选择）
- translations/strings.csv 增补 9 键（menu_title/menu_subtitle/menu_start/menu_language/lang_zh/lang_en/menu_quit/menu_controls/hud_menu）
- 遗留：游戏中返回菜单不保存进度（原型阶段明确行为）

## 验收证据（可复现）

`tools/scene_flow_test.gd`（注入场景流转）：
```
M1 title = 塔防原型：四族战场   ← 启动默认中文 ✓
M1 lang  = 语言：中文
M2 lang  = Language: English    ← 菜单语言按钮即切 ✓
G1 money = Money: $200          ← 进游戏后保持英文 ✓
M3 lang  = Language: English    ← 返回菜单语言保持 ✓
FLOW_PASS
```
- 10 个脚本 --check-only 全过；menu.tscn 主场景 900 帧冒烟无报错
- 验收标准 1-4 全部满足