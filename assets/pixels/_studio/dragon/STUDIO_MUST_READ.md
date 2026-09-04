# 龙族 Studio 开工必读（game-studio / 美术线）

> **做之前必看。** 未 Read 本清单列出的现行纪律文件 = 不得出图、不得过审、不得删改裁定、不得 promote。  
> 总则：**除非用户或规格明文例外，否则下列文件全部条款强制执行。**

## 1. 每次龙族/像素任务先读

| 顺序 | 路径 | 用途 |
|:----:|------|------|
| 0 | **本文件** | 索引 |
| 1 | `ANATOMY.md` | 肢/翼/尾/互斥/女装男壮/纪律总则 |
| 2 | `STYLE_GATE_pick004.md` | PASS/FAIL 闸门 |
| 3 | `longren/WHERE.md` | 用户只看哪里、否决锚 |
| 4 | `longren/ART_REVIEW.md` | 当前过审状态 |
| 5 | `longren/PASS_RATE_ROOT_CAUSE.md` | 女角通过率根因（出女图前必读） |
| 6 | 相关 `longren/{id}/SPECIES.md` | 亚种色/体/装 |
| 7 | 飞龙任务另加 `drake/INDEX.md` + `drake/{id}/SPECIES.md` | |
| 8 | 梦龙任务另加 `dream/SPECIES.md` + `dream/WHERE.md` | 兽体梦龙（非龙人）；睡眠单位 |

Skills（概念，仍须打开 SKILL.md）：`directing-game-visuals`、`create-game-assets`、`asset-architecture`。

## 2. 硬条速查（细节以 ANATOMY / STYLE_GATE 为准）

- 仅 **1 对背翼**（禁髋副翼）
- 默认仅 **1 条尾巴**（明文多尾才可例外）
- **女体 XOR 龙头**
- 女：漂亮脸 + 大胸 + 轻甲胸装+裙；着装亚种可分；禁全裸、禁尖刺丑甲、禁武器
- 男：强壮 + 龙吻；无女体
- 管线：`candidates` → 过审 → `approved` → 用户点头 → `picks` → ship
- 否决参考（禁止当生成锚）：`longren/_refs/ref_REJECT_*.png`

## 3. 材质锚注意

`dragon/picks/pick_004_flame_drake_*` = 晶体鳞材质参考；**不可当翼数/尾数规范**（004 含旧髋翼）。

## 4. game-studio 自检

开工回复须能回答：已读 ANATOMY / STYLE_GATE / WHERE（及本任务 SPECIES）——否则审核官判 **Skill 合规 FAIL**。
