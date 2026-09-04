# AUDIT — banned hero i2i wave + idle state 2026-09-03 ~18:45

## Process FAIL (严重)

Terminal `HERO_I2I` 日志：

```
img2img ref .../longren/_refs/ref_frost_002_hero.png denoise 0.48~0.55
```

产出：
- frost `035–038`（i2i）
- jade `037–039`（i2i）

该 hero 即旧 frost 002，已否决为 `ref_REJECT_frost_002_multitail.png`（同体积 1132133）。  
`ANATOMY.md` / `WHERE.md` / `STUDIO_MUST_READ.md`：**禁止当生成锚**。

根因脚本仍写死 hero：

`tools/gen/_fix_female_presets.py` → `ref_frost_002_hero.png`

### 处置
- 本波 **禁止** `approved/` / `picks/`
- 建议整波标 `audit_fail_banned_hero_i2i` 或删；若保留须**逐张**验恰好 1 尾 + 铠胸罩+战裙 + 无漂浮道具
- 生成侧必须改掉 hero ref（beauty board 或新合法单尾轻甲 PASS）

---

## 抽样视觉（不改变上条 FAIL）

| id | 观察 | 相对门禁 |
|----|------|----------|
| frost/037 raw | 女人脸、似 1 尾、胸装+开衩裙、漂浮冰晶图标 | 服装近规；FX 扣分；**血统仍 FAIL** |
| frost/038 game | 冰蓝、1 对翼、小裙帘 | 同左 |
| jade/039 | 偏霜白/青非玉绿主调；漂浮法球 | 色板弱 + 血统 FAIL |

---

## 库存稳态（本心跳无新文件）

| 区 | 状态 |
|----|------|
| frost/jade approved+picks | 空（正确） |
| magma 011/022 · storm 002 | CONDITIONAL 可留 approved，禁 picks |
| stone 002 | 色板质疑，建议降级 |
| 候选计数 | magma11 / frost15 / storm8 / stone8 / jade24 |
| 自 18:34 后 | **无新** game（HERO 波已落盘完毕） |

---

## 文档/脚本合规

| 项 | 结果 |
|----|------|
| STUDIO_MUST_READ 存在 | PASS |
| WHERE 停用 002 锚 | PASS |
| `_fix_female_presets.py` 仍指向 hero | **FAIL** |
| ART_REVIEW 清单过时 | FAIL（未修） |

---

## 审核裁定
- 对象：HERO_I2I frost035–038 + jade037–039；男 approved 无变化
- Skill 合规：**FAIL**（违禁锚出图）
- 纪律/闸门：**FAIL**
- 结论：**FAIL**（该波）
- 处置：禁 promote；修 preset；重启监听
