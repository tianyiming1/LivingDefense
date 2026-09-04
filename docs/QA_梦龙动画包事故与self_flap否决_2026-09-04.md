# QA 简报：self_flap 否决裁定 & 梦龙动画包事故（2026-09-04）

## 一、SELF_FLAP_GATE_17.gif 否决裁定：**FAIL（路线判死）**

用户目测"完全不行" + 像素级量化，双重否决：

| 指标 | 实测 | 合格线 | 判定 |
|------|------|--------|------|
| 相邻帧 diff 率 | 15%~21.4% 无规律波动 | 匀速正弦式渐变 | FAIL（帧间抖动=逐帧重新想象整只龙） |
| 首尾循环接缝 | LAST→0 diff 21.4% | ≤10% | FAIL（循环肉眼看跳变） |
| 变化分区 | 全身（含躯干/头/尾）大范围变化 | 只有翅膀角度变化 | FAIL（肢体错乱，非扇翅） |

**结论**：AI 整帧自扇翅（self_flap）路线判死，不再投入。梦龙飞行动画只能走：
- **首选**：`hand_anim/unit_14..17` 手绘模板源帧 → `promote_dream_hand_anim.py` 组装 → `audit_anim_pack.py` 过审（引擎已验证丝滑）
- 备选：Path B Atlas 条带（fly_sheet 等宽 cell + region 切换）

## 二、同日事故记录（正式资产被反复破坏）

| 时间 | 提交/事件 | 内容 |
|------|-----------|------|
| 11:41 | baseline 戳 | 4 包打 baseline_v1 approved（当时内容完好） |
| 11:45 | 无提交 | Cursor 会话把 4 正式包覆盖为同图垃圾（16 png 全同 MD5、fly 砍到 4 帧），门禁被旧戳绕过 |
| 11:50:43 | `0ff1ad7` | 垃圾版入库 |
| 11:54:02 | `dd5e5aa` | 删 hand_anim 源帧（标注 "FAIL / WorkBuddy"）与正式包 |
| 11:55:18 | `0c23bc4` | WorkBuddy 从 001a3d4 抢救恢复源帧 4×89 png 入库 |
| 11:55:58 | audit | unit_14 重建并过审 APPROVED（0 reasons）+ S1 冒烟 0 错 |
| 11:56:23/41 | `68b7e7c`/`f467dd5` | Cursor 会话把 unit_14 重建成果打包提交后又整体 purge（"menglong delete, user FAIL"） |

**用户裁决（2026-09-04 12:00）**：否决范围 = **仅 self_flap 动画路线**；梦龙（menglong）形象与 hand_anim 帧包保留。
- 已执行：unit_14_anim 重建上线（promote PASS → palette → audit APPROVED → S1 冒烟 0 错，提交 `e52b938`）
- 返工清单：unit_15/16（death_2 扁平度不足：0.97/0.91，需 ≥ idle×1.15）；unit_17（大量顶部裁切 top_clip≤81px、fly 锚点高于 idle 的关系不成立——需整体下移重锚）
- 分工规矩（用户确认）：**Cursor 管生成（WIP 限 `_studio/`），WorkBuddy 管审核/正式目录/引擎/git**；删除正式资产必须用户确认

## 三、已落防线

1. `.cursor/rules/agent-audit-gate.mdc` 新增"资产删除红线"：删除已入库正式资产须用户确认；异议挂起裁决，禁止物理删除对方产出；promote 后必须立即 audit 同步提交。
2. hand_anim 源帧 4×89 png 已单独入库（`0c23bc4`），任何一方再删均可从 git 恢复。
