"""一次性整理 assets/pixels：去重、分类、建立 ship/_studio 架构。"""
from __future__ import annotations

import hashlib
import json
import os
import shutil
from datetime import date

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PIXELS = os.path.join(ROOT, "assets", "pixels")
OLD_CAND = os.path.join(PIXELS, "_candidates")
OLD_IN = os.path.join(PIXELS, "_incoming")
STUDIO = os.path.join(PIXELS, "_studio")


def md5(path: str) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def ensure(p: str) -> str:
    os.makedirs(p, exist_ok=True)
    return p


def copy_unique(src: str, dst_dir: str, name: str, seen: dict) -> str | None:
    if not os.path.isfile(src):
        return None
    digest = md5(src)
    if digest in seen:
        print("skip dup", name, "->", seen[digest])
        return None
    ensure(dst_dir)
    dst = os.path.join(dst_dir, name)
    shutil.copy2(src, dst)
    seen[digest] = dst.replace(ROOT + os.sep, "").replace("\\", "/")
    print("keep", seen[digest])
    return dst


def rebuild_catalog(folder: str, asset_id: str) -> None:
    items = []
    files = sorted(f for f in os.listdir(folder) if f.endswith(".png"))
    # group by NNN prefix
    tags = sorted({f[:3] for f in files if len(f) >= 3 and f[:3].isdigit()})
    for tag in tags:
        raw = os.path.join(folder, f"{tag}_raw.png")
        game = os.path.join(folder, f"{tag}_game.png")
        entry = {
            "index": int(tag),
            "tag": tag,
            "created": str(date.today()),
            "note": "",
            "source": "reorganized",
            "seed": None,
            "prompt": "",
            "flip_x": False,
            "raw": None,
            "game": None,
        }
        if os.path.isfile(raw):
            entry["raw"] = os.path.relpath(raw, ROOT).replace("\\", "/")
        if os.path.isfile(game):
            entry["game"] = os.path.relpath(game, ROOT).replace("\\", "/")
        items.append(entry)
    with open(os.path.join(folder, "catalog.json"), "w", encoding="utf-8") as f:
        json.dump({"asset_id": asset_id, "items": items}, f, ensure_ascii=False, indent=2)
        f.write("\n")


def main():
    # wipe studio rebuild
    if os.path.isdir(STUDIO):
        shutil.rmtree(STUDIO)
    ensure(STUDIO)
    ensure(os.path.join(STUDIO, "incoming"))
    open(os.path.join(STUDIO, "incoming", ".gitkeep"), "w").close()

    cats = {
        "longren": os.path.join(STUDIO, "dragon", "longren"),
        "whelp": os.path.join(STUDIO, "dragon", "whelp"),
        "drake": os.path.join(STUDIO, "dragon", "drake"),
        "adult": os.path.join(STUDIO, "dragon", "adult"),
        "picks": os.path.join(STUDIO, "dragon", "picks"),
        "refs": os.path.join(STUDIO, "dragon", "refs"),
        "anim_wip": os.path.join(STUDIO, "dragon", "anim_wip"),
    }
    for p in cats.values():
        ensure(p)

    seen: dict[str, str] = {}

    # 1) category folders from old candidates (authoritative unique sets)
    for key in ("longren", "whelp", "drake", "adult"):
        src_dir = os.path.join(OLD_CAND, "dragon", key)
        if not os.path.isdir(src_dir):
            continue
        for f in sorted(os.listdir(src_dir)):
            if not f.endswith(".png"):
                continue
            copy_unique(os.path.join(src_dir, f), cats[key], f, seen)

    # merge dragon_man unique into longren with new indices (pair raw+game)
    dm = os.path.join(OLD_CAND, "dragon", "dragon_man")
    if os.path.isdir(dm):
        existing = [f for f in os.listdir(cats["longren"]) if f.endswith("_raw.png")]
        next_i = 1 + max([int(f[:3]) for f in existing], default=0)
        tags_in_dm = sorted({f[:3] for f in os.listdir(dm) if f.endswith(".png") and f[:3].isdigit()})
        for old_tag in tags_in_dm:
            raw_src = os.path.join(dm, f"{old_tag}_raw.png")
            game_src = os.path.join(dm, f"{old_tag}_game.png")
            # skip if raw already present by hash
            if os.path.isfile(raw_src) and md5(raw_src) in seen:
                continue
            if os.path.isfile(game_src) and not os.path.isfile(raw_src) and md5(game_src) in seen:
                continue
            tag = f"{next_i:03d}"
            next_i += 1
            if os.path.isfile(raw_src):
                copy_unique(raw_src, cats["longren"], f"{tag}_raw.png", seen)
            if os.path.isfile(game_src):
                copy_unique(game_src, cats["longren"], f"{tag}_game.png", seen)

    # 2) picks: keep unique batch 004 / 007
    batch = os.path.join(OLD_CAND, "dragon", "batch")
    if os.path.isdir(batch):
        for tag, label in (("004", "pick_004_flame_drake"), ("007", "pick_007_longren_spear")):
            for kind in ("raw", "game"):
                src = os.path.join(batch, f"{tag}_{kind}.png")
                if os.path.isfile(src):
                    copy_unique(src, cats["picks"], f"{label}_{kind}.png", seen)

    # 3) refs
    for folder, prefix in (("sheet", "sheet"), ("anim_sheet", "anim_sheet"),):
        d = os.path.join(OLD_CAND, "dragon", folder)
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith(".png"):
                copy_unique(os.path.join(d, f), cats["refs"], f"{prefix}_{f}", seen)
    eref = os.path.join(OLD_CAND, "enemies", "ref")
    if os.path.isdir(eref):
        for f in sorted(os.listdir(eref)):
            if f.endswith(".png"):
                copy_unique(os.path.join(eref, f), os.path.join(STUDIO, "enemies", "ref"), f, seen)

    # 4) anim_wip: only AI cand raws worth keeping; ship anim stays in dragon/unit_1_anim without cand
    anim_ship = os.path.join(PIXELS, "dragon", "unit_1_anim")
    if os.path.isdir(anim_ship):
        for f in list(os.listdir(anim_ship)):
            if "_cand" in f or f.endswith(".md"):
                src = os.path.join(anim_ship, f)
                if f.endswith(".png"):
                    copy_unique(src, cats["anim_wip"], f, seen)
                    os.remove(src)
                    print("moved cand out of ship", f)
                elif f.endswith(".md"):
                    pass

    # 5) rebuild catalogs
    for key in ("longren", "whelp", "drake", "adult"):
        rebuild_catalog(cats[key], f"dragon/{key}")

    # 6) README
    readme = """# pixels 资源架构（ship / studio）

## 正式进游戏（ship）
引擎只读这些路径，禁止把候选图直接堆进来：

```
assets/pixels/
  human|fungus|dragon|silicon/unit_N.png
  dragon/unit_N_anim/{idle|walk|attack}_K.png
  enemies/enemy_N.png
  map/*.png
  PROVENANCE.json
```

## 工作室候选（studio）
全部 AI/筛选工作都在 `_studio/`，按龙族四类归档：

```
_studio/
  incoming/           # 临时投放，用完即清
  dragon/
    longren/          # 龙人：双手双脚
    whelp/            # 幼龙：小龙形
    drake/            # 亚龙：中型龙形
    adult/            # 成龙：大型四足/巨龙
    picks/            # 已选中的定稿参考（如 004）
    refs/             # 合集/参考图
    anim_wip/         # 动画实验帧（未进 ship）
  enemies/ref/
```

命名：`NNN_raw.png` / `NNN_game.png` + `catalog.json`

## 规则
1. 出图 → 只写入 `_studio/...`，编号递增，不覆盖。
2. 用户选定后 → promote 到 ship 的 `unit_N.png`，并写 PROVENANCE。
3. `_incoming` / 旧 `_candidates` 已废弃。
4. ship 目录禁止放 preview、raw、重复副本。
"""
    with open(os.path.join(PIXELS, "README.md"), "w", encoding="utf-8") as f:
        f.write(readme)
    with open(os.path.join(STUDIO, "README.md"), "w", encoding="utf-8") as f:
        f.write(readme)

    # 7) remove obsolete trees
    if os.path.isdir(OLD_IN):
        shutil.rmtree(OLD_IN)
        print("removed _incoming")
    if os.path.isdir(OLD_CAND):
        shutil.rmtree(OLD_CAND)
        print("removed _candidates")

    # clean stray .import next to missing png in ship anim
    print("DONE studio at", STUDIO)


if __name__ == "__main__":
    main()
