# The Living Rampart（活体防线）— 塔防可玩原型

Godot 4 (4.5.1) 塔防原型 · 单局 12 波可完整通关 · 5 种塔 / 3 种敌人

定位：Steam 上架路线图的 **M1 里程碑**（完整路线图见 `docs/DESIGN.md`）。

## 运行

需要 Godot 4.2+（本机已装 4.5.1 并验证）：

- 编辑器：Godot → Import → 选择本项目 `project.godot` → 打开后按 `F5` 运行
- 命令行冒烟测试（无窗口，检查有无脚本报错）：
  `"D:\softwares\Godot_v4.5.1-stable_win64.exe" --headless --path "D:\GameWorkSpace\TowerDefenseProto" --quit`

## 操作

| 操作 | 说明 |
| --- | --- |
| 点右侧塔按钮 | 进入建造模式（金币不足自动置灰） |
| 左键点草地 | 放置（绿色=可放，红色=不可放，显示射程圈） |
| 右键 / ESC | 取消建造 / 取消选中 |
| 左键点已建塔 | 选中并显示信息面板：Upgrade（升级）/ Sell（出售） |
| Start Wave | 开始下一波（战斗中禁用） |
| 1x / 2x | 游戏速度切换 |

## 数值

所有数值（塔表、敌兵表、波次成长、经济曲线）都集中在 `scripts/config.gd`，
改完按 F5 即生效 —— 调平衡不需要碰任何其它文件。

## 文件结构

- `project.godot` / `main.tscn` — 项目入口
- `scripts/config.gd` — 数值单一来源（改它 = 改游戏）
- `scripts/main.gd` — 状态机 / 经济 / 波次 / 建造 / 胜负结算
- `scripts/hud.gd` — 界面与交互（只发信号，不做逻辑）
- `scripts/map.gd` / `enemy.gd` / `tower.gd` / `projectile.gd` / `placement_ghost.gd` — 玩法实体
- 美术 / 音效零依赖：全部程序绘制占位，后续直接替换正式资源

## 导出 Windows exe（上架前奏）

编辑器 → Project → Export → 添加 Windows Desktop 预设
（首次需在 Editor → Manage Export Templates… 下载对应版本模板）
→ 确保使用 gl_compatibility（项目已默认）→ Export Project。

## 已知简化（M1 范围外的 TODO）

- 单图单局、无存档、无音效/音乐、无设置项
- 美术为程序绘制占位，无动画 / 粒子特效
- 无 Boss 波、无塔种类解锁、无难度选择
- 平衡性只经过简单推演，尚未多人试玩校准
