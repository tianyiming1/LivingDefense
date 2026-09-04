# 梦龙 ART_REVIEW

| 字段 | 值 |
|------|-----|
| 日期 | 2026-09-04 |
| 规格 | CO-046 |

## 立绘

| 阶 | 裁定 |
|----|------|
| 14–17 | 已恢复 `size_ladder/unit_*_s*.png` → ship（96×108）；**勿用**空的 `clean_*.png` |

## 动作帧

| 项 | 裁定 | 说明 |
|----|------|------|
| WorkBuddy | **弃用** | 用户禁止 |
| self_flap mesh / pivot 16f | **FAIL** | 拖影、掏空身体、叠影；用户「根本不行」 |
| 坏帧 | 已隔离 | `self_flap/_FAIL_quarantine/` |
| Path A 木偶 | **现行占位** | `prefer_frames:false`；14/15 双翅；16/17 full_body bob |
| 真 16 帧 | **未交付** | 仅手绘 `KEYFRAMES.md` + promote 可过审 |

```
### 审核裁定
- 对象：梦龙自生成 16 帧扇翅（mesh + pivot）
- Skill 合规：PASS（已读必读）
- 纪律/闸门：FAIL（拖影/掏空/不可读；违反「禁双翅叠影」与可玩动画交付）
- 结论：FAIL
- 处置：已撤 ship 坏帧、回滚静帧+Path A；禁止再宣称 self_flap 过审；真动画改手绘或另开变更单
```
