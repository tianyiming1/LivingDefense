# AUDIT Wave F — frost 039–042 / jade 040–043 (2026-09-03 ~18:52)

**Verdict: FAIL — not longren female; block all promote**

## Source
`PICK004_STYLE_BATCH` → `--preset ice_longren|jade_longren --txt2img`  
Catalog note: `comfy_t2i_*` but `source` still falsely `comfy_img2img_pick004`.

## Hard fails (all ids)

| id | 主因 |
|----|------|
| frost/039 | 兽形龙人/有吻感；非女人脸；无铠胸罩+战裙；非女路径 |
| frost/040 | 全兽龙人站姿+灰地面；非女美型；无轻甲 |
| frost/041 | **小飞龙/wyvern**；非双足女龙人；无服装 |
| frost/042 | **低模晶体龙**（raw）/ 小飞龙 game；非 longren 女角 |
| jade/040–042 | 悬浮幽灵/小翼兽；非女龙人轻甲；体量过碎 |
| jade/043 | 碎裂鬼影 + **橙膜**串味；非碧枝女装 |

共同：
- 缺 **漂亮女人脸 + 胸最大 + 铠胸罩+战裙**
- 更像 `drake` 小龙/精灵，误进 `longren/*/candidates`
- 禁止 `approved/` / `picks/`

## Color only (不足挽救)
- frost 039–042 cool 67–80%（色对身份错）
- jade 040–042 green≈51%（色对身份错）；043 green弱且 warm 19%

## Disposition
- FAIL 删除或隔离；勿与 HERO 波混谈（本波是 t2i 跑偏成龙/drake）
- 女角 prompt 需强化：`bipedal humanoid woman` / `pretty human face` / armored bra+skirt；负向加重 `quadruped, wyvern, small pet dragon, floating spirit`

## 男 approved
无变化；仍 CONDITIONAL；禁 picks。
