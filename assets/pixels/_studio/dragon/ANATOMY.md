# 龙族解剖硬规则（出图 / 筛选）

- **龙人 (longren)**：必须 **2 手 + 2 脚**（可有翅膀），直立侧视/3/4；禁止三腿、缺肢、多臂。
- **幼龙 (whelp)**：小型龙形，**正好 4 短腿**，翅膀可选。
- **亚龙 (drake)**：中型龙形。**每张只能选一种体态**：
  - 四足：正好 **4 腿** + **1 对翅膀** + **1 头 1 尾**（无手臂）
  - 或双足：正好 **2 臂 2 腿** + **1 对翅膀** + **1 头 1 尾**
  - 禁止：双头、连体、人头龙身堆肢、髋部长翼、腿/翼数量混乱
- **成龙 (adult)**：大型四足/巨龙体型，翅膀或经典龙形。

**权威范本**：`_studio/dragon/templates/*_sil.png` + 程序像素  
`python tools/gen/draw_dragon_anatomy.py --ship`  
剪影上色：`python tools/gen/gen_from_silhouette.py --class longren`

筛选时肢体重于画风；肢错误直接丢弃，不要 promote。
