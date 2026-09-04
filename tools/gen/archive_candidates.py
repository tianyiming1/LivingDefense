"""
候选图编号存档：每次生成/导入都保留 raw + 导入结果，不覆盖。

目录（工作室区，不进引擎）：
  assets/pixels/_studio/{asset_id}/
    001_raw.png
    001_game.png
    catalog.json

用法：
  from archive_candidates import archive_pair, next_index, list_candidates
"""
from __future__ import annotations

import json
import os
import shutil
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CANDIDATES = os.path.join(ROOT, "assets", "pixels", "_studio")
# 兼容旧名
STUDIO = CANDIDATES


def _dir(asset_id: str) -> str:
    d = os.path.join(CANDIDATES, asset_id.replace("/", os.sep))
    os.makedirs(d, exist_ok=True)
    return d


def _catalog_path(asset_id: str) -> str:
    return os.path.join(_dir(asset_id), "catalog.json")


def _load_catalog(asset_id: str) -> dict:
    p = _catalog_path(asset_id)
    if os.path.isfile(p):
        with open(p, encoding="utf-8-sig") as f:
            return json.load(f)
    return {"asset_id": asset_id, "items": []}


def _save_catalog(asset_id: str, data: dict) -> None:
    with open(_catalog_path(asset_id), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def next_index(asset_id: str) -> int:
    cat = _load_catalog(asset_id)
    if not cat["items"]:
        return 1
    return max(int(it["index"]) for it in cat["items"]) + 1


def archive_pair(
    asset_id: str,
    raw_src: str | None,
    game_src: str | None,
    *,
    note: str = "",
    seed: int | None = None,
    prompt: str = "",
    source: str = "",
    flip_x: bool = False,
) -> dict:
    """把 raw / game 各存一份带编号文件，返回条目。"""
    idx = next_index(asset_id)
    tag = "%03d" % idx
    d = _dir(asset_id)
    entry = {
        "index": idx,
        "tag": tag,
        "created": datetime.now().isoformat(timespec="seconds"),
        "note": note,
        "source": source,
        "seed": seed,
        "prompt": prompt,
        "flip_x": flip_x,
        "raw": None,
        "game": None,
    }
    if raw_src and os.path.isfile(raw_src):
        raw_dst = os.path.join(d, "%s_raw.png" % tag)
        shutil.copy2(raw_src, raw_dst)
        entry["raw"] = os.path.relpath(raw_dst, ROOT).replace("\\", "/")
    if game_src and os.path.isfile(game_src):
        game_dst = os.path.join(d, "%s_game.png" % tag)
        shutil.copy2(game_src, game_dst)
        entry["game"] = os.path.relpath(game_dst, ROOT).replace("\\", "/")
    cat = _load_catalog(asset_id)
    cat["items"].append(entry)
    _save_catalog(asset_id, cat)
    print("ARCHIVED", asset_id, "#%s" % tag, entry.get("note", ""))
    return entry


def promote(asset_id: str, index: int, flip_x: bool = False, retro: bool = False) -> str:
    """把某编号候选导入正式游戏路径。"""
    import sys

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from import_ai_sprite import import_one, _load_manifest, _out_path

    cat = _load_catalog(asset_id)
    item = next((it for it in cat["items"] if int(it["index"]) == int(index)), None)
    if not item:
        raise FileNotFoundError("no candidate #%s for %s" % (index, asset_id))
    # 优先用 raw 再导入（可重新抠图）；否则直接复制 game
    raw = item.get("raw")
    if raw:
        raw_abs = os.path.join(ROOT, raw.replace("/", os.sep))
        manifest = _load_manifest()
        import_one(raw_abs, asset_id, manifest, 96, 108, True, flip_x=flip_x, retro=retro)
        # 再存一份 promote 结果（编号递增）
        archive_pair(
            asset_id,
            raw_abs,
            _out_path(asset_id),
            note="promoted_from_%03d" % index,
            source="promote",
            flip_x=flip_x,
        )
        return _out_path(asset_id)
    game = item.get("game")
    if not game:
        raise FileNotFoundError("candidate #%s has no raw/game file" % index)
    game_abs = os.path.join(ROOT, game.replace("/", os.sep))
    out = _out_path(asset_id)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    shutil.copy2(game_abs, out)
    print("PROMOTED", asset_id, "<-", game_abs)
    return out


def list_candidates(asset_id: str = "") -> None:
    if asset_id:
        ids = [asset_id]
    else:
        if not os.path.isdir(CANDIDATES):
            print("(empty)")
            return
        ids = []
        for root, _dirs, files in os.walk(CANDIDATES):
            if "catalog.json" in files:
                rel = os.path.relpath(root, CANDIDATES).replace("\\", "/")
                ids.append(rel)
        ids.sort()
    for aid in ids:
        cat = _load_catalog(aid)
        print("=== %s (%d) ===" % (aid, len(cat["items"])))
        for it in cat["items"]:
            print(
                "  #%s  %s  note=%s  raw=%s  game=%s"
                % (
                    it["tag"],
                    it.get("created", ""),
                    it.get("note", ""),
                    "Y" if it.get("raw") else "-",
                    "Y" if it.get("game") else "-",
                )
            )


if __name__ == "__main__":
    import argparse

    ap = argparse.ArgumentParser(description="Numbered candidate archive")
    ap.add_argument("--list", nargs="?", const="", default=None)
    ap.add_argument("--promote", nargs=2, metavar=("ASSET_ID", "INDEX"))
    ap.add_argument("--flip-x", action="store_true")
    ap.add_argument("--retro", action="store_true")
    args = ap.parse_args()
    if args.list is not None:
        list_candidates(args.list)
    elif args.promote:
        promote(args.promote[0], int(args.promote[1]), flip_x=args.flip_x, retro=args.retro)
    else:
        ap.print_help()
