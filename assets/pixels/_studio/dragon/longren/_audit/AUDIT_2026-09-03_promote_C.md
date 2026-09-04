# AUDIT — promote gate + Wave C (txt2img) 2026-09-03 ~17:48

## Standing gates (current)
`STYLE_GATE_pick004.md` + `ANATOMY.md` + **女体 XOR 龙头** + SPECIES.md  
剪影 `longren_ref_1024` 路线已废弃（Wave A/B FAIL 有效）。本波为 **txt2img** — 流程方向正确。

---

## 1) frost `approved/002` → `picks/pick_frost_shuangling_*`

| 条款 | 结果 |
|------|------|
| 色（cool≈81%，warm=0%） | PASS |
| 女路径互斥（女人脸、无龙吻） | PASS |
| 1 对背翼 / 2臂2腿 | PASS |
| 胸/沙漏可读 | PASS |
| 材质 vs pick_004 晶体块鳞 | **CONDITIONAL**（偏光滑插画冰甲，锯齿块鳞弱） |
| 漂浮 FX（raw 双冰晶图标；game 小冰晶） | **CONDITIONAL**（建议定稿清漂浮） |
| 用户终审 → picks | PASS（`ART_REVIEW.md` / `WHERE.md` 记录夸奖定稿） |

### 审核裁定（frost pick）
- **结论：CONDITIONAL PASS** — **允许保留** `picks/`（用户已终审）
- 不要求撤回；后续变体以本 pick 为女龙人锚时，优先加强晶体块鳞、去掉漂浮道具

---

## 2) jade `approved/001`

| 条款 | 结果 |
|------|------|
| 色（green≈56%） | PASS |
| 女路径互斥 | PASS |
| 1 对背翼 / 2臂2腿 | PASS |
| 材质晶体块鳞 | **CONDITIONAL**（偏有机光滑鳞） |
| 膜色 SPECIES `#12241C` | **CONDITIONAL**（偏浅绿半透） |
| picks | **未进** — 正确，等用户点头 |

### 审核裁定（jade approved）
- **结论：CONDITIONAL PASS** — **允许留在 `approved/`**
- **禁止** 未经用户点头拷 `picks/` / ship
- 用户若嫌材质偏插画，可要求补量后再终审

---

## 3) 流程纪律

| 项 | 结果 |
|----|------|
| 废弃错误剪影 ref | PASS |
| 美术硬验收写 `ART_REVIEW.md` | PASS |
| frost catalog 仍写 `no picks promote` 但磁盘已有 picks | **FAIL 诚实性**（需改 catalog 与 ART_REVIEW 头行「未 promote」矛盾） |
| 持续审核官同期签字 | 缺失 → 本文件补签 |

---

## 4) 候选库存（未 promote，抽样）

| 位置 | 初判 |
|------|------|
| frost `003–006` | 色对；需逐张互斥/肢翼硬审；**勿自动进 approved** |
| jade `002–009` | 色偏绿；`008` 疑盔甲/髋飘带 → **倾向 FAIL** |
| magma `001–020` | 仍无 approved；`020` 可读性较好但仍需男龙头路径硬审；暖色占比偏弱者 FAIL |
| storm `001–004` | 炭金方向；`002` 有灰地面非纯黑底 → 扣分 |
| stone `001–004` | 偏炭黑，缺砂岩褐 → 色板 **FAIL 居多** |

`magma/storm/stone` **approved 仍应为空**（除非新硬审 PASS）。

---

## 处置总表
- frost picks：**保留（CONDITIONAL PASS）**
- jade approved：**保留（CONDITIONAL）；禁 picks**
- 新 candidates：**禁止批量 promote**；FAIL 肢/翼/互斥/盔甲者删除
- 下一心跳：继续扫 `candidates` 增删
