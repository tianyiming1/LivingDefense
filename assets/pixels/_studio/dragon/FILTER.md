# 龙族筛选 / 保肢基线（2026-09-03）

## 已完成
1. **删 rejected**：`*_rejected` 已清空释放空间  
2. **程序保肢**：`tools/gen/draw_dragon_anatomy.py`  
   - ship：`unit_0`=幼龙(4腿) / `unit_1`=龙人(2臂2腿) / `unit_2`=成龙(4腿)  
   - studio：`dragon/{longren,whelp,drake,adult}/` 归档 `procedural_anatomy_v2`  
   - 剪影：`_studio/dragon/templates/*_sil.png`  
3. **剪影再生成**：`gen_from_silhouette.py --all --count 2` → 各类 #002/#003（需人工筛，肢错仍丢）

## 权威体态
以 **程序像素 #001 / templates** 为准，不以 LCM 盲出为准。

## 命令
```powershell
python tools/gen/draw_dragon_anatomy.py --ship
python tools/gen/gen_from_silhouette.py --class longren --count 4 --strength 0.35
python tools/gen/archive_candidates.py --list
```
