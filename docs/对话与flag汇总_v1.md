# 对话点位与 Flag 汇总 v1（大撤退 · 双引擎落地表）

> 状态：v1（2026-09）。配合 CAMPAIGN §5.2（对话引擎）/ 关卡_逐关设计_v1.md。
> 原则：对话只出现在撤退节点/事件结算/关键关；每场 1-2 选项；只立 flag 不开新线；
> 无错误答案——每个选项都通向"继续撤退"，只是细节/结局不同（CAMPAIGN §5.2）。

---

## 1. Flag 总表（存档字段）

| flag | 含义 | 如何获得 | 影响 |
| --- | --- | --- | --- |
| `no_man_left` | 是否总选"殿后保人" | 关1 A / 关2 A / 关3 A 等反复选 | 结局倾向：光荣/牺牲者叙事 |
| `army_first` | 保兵优先 | 关1 B | 与 no_man_left 互斥倾向 |
| `town_trust` | 镇民信任 | 关2 B / 关3 B 等 | 入城时民众迎接冷暖；某些对话解锁 |
| `stubborn` | 倔强守军 | 关2 死守成功 | 结局语气（"他们不肯丢一寸土"） |
| `audacious` / `cautious` | 关4 突围风格 | 关4 对话 | 减员构成/出口方向 |
| `spore_alliance` | 菌族结盟 | 关5 A | 后续可部署菌单位；决战有菌援军 |
| `spore_alliance_failed` | 菌族沦陷 | 关5 B | 菌线关闭；决战无此援军 |
| `dragon_pact` | 龙族结盟 | 关6 A | 解锁龙族；决战有龙援军 |
| `dragon_pact_failed` | 龙族殿后 | 关6 B | 龙线关闭；但得 `secret_pass` |
| `secret_pass` | 崖下秘道 | 关6 B 附赠 | 后续某关有捷径（奖励不亏） |
| `silicon_treaty` | 硅族结盟 | 关7 A | 解锁硅族；决战有硅援军 |
| `silicon_treaty_failed` | 硅族只借护盾 | 关7 B | 硅线关闭；一次性护盾道具 |
| `empire_open` / `empire_side` | 大城入城方式 | 关8 | 决战协防 vs 绕行（少一波支援但安全） |
| `empire_fall_choice` | 决战主动再撤 | 关9 B | 触发开放式结局 |
| （暗线）`demon_truth_*` | 魔族内幕 | 后期隐藏对话 | 暗线真结局（停战/双方皆难民） |
| （隐藏）第5族 | 隐藏种族 | 剧情节点解锁 | 隐藏结局 |

> 汇合规则：结局结算 = 战况轴（满编/残兵/被救）× flag 轴（结盟数 + no_man_left 倾向 +
> 暗线/隐藏）。无单一"最好"组合——每种组合出一种结局语气（CAMPAIGN §6.1）。

---

## 2. 对话点位表（逐关）

| 关 | 对话场景 | 选项 | flag |
| --- | --- | --- | --- |
| 1 | 镇长撤退前 | A 能带多少带多少 / B 保兵要紧 | no_man_left+ / army_first+ |
| 2 | 军官讨论殿后 | A 民众先走 / B 一起走别死人 | no_man_left+ / town_trust+ |
| 3 | 渡口小孩（情感锚） | A 你走前面我殿后 / B 跟紧我 | no_man_left+ / town_trust+ |
| 4 | 侦察兵报告 | A 右侧林道突围 / B 就地筑垒 | audacious / cautious |
| 5 | 菌族族长交涉 | A 一起走护你们 / B 你们自己守 | spore_alliance / spore_alliance_failed |
| 6 | 龙族首领交涉 | A 合兵打督军 / B 你们断后 | dragon_pact / dragon_pact_failed(+secret_pass) |
| 7 | 硅族守卫长交涉 | A 以晶为誓共守 / B 借晶能冲出 | silicon_treaty / silicon_treaty_failed |
| 8 | 城门守将交涉 | A 开门一起守 / B 绕西门 | empire_open / empire_side |
| 9 | 城头最后对话 | A 城在人在（死守）/ B 留得青山（再撤） | （结局分叉）empire_fall_choice |
| 隐藏 | 魔族俘虏/逃兵对话 | 暗线选项 | demon_truth_*（见 §3） |

---

## 3. 暗线/隐藏对话（占位，魔族内幕）

- 触发点：中后期某关（如 8）战后，抓到魔族逃兵/听到魔族内部对话（条件：某 flag 组合）；
- 揭示方向（不写死，防"洗白反派"脸谱）：魔族也是被驱赶/被利用的群体——帝国与魔族
  的战争背后有第三只手（占位，主线细化后再定）；
- flag：`demon_truth_1/2/3`（碎片），攒满 → 暗线真结局（停战/看清没有赢家）。

---

## 4. 待细化

1. 【叙事 CO】每场对话具体台词（含状态句，CO-047 风格：一句归因不弹窗）。
2. 【设计】暗线碎片获取点具体化（§3）。
3. 【存档】flag 写入 run meta / PlayerSecrets（CO-047 的 API 沿用）。
