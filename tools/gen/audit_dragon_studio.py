"""按人工筛选清单，把不合格候选移到 *_rejected，并写 verdict 到 REVIEW.json。不碰 ship。"""
from __future__ import annotations

import json
import os
import shutil
from datetime import date

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DRAGON = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon")

# verdict: reject | weak | keep
# 仅审核 studio 候选；ship 单独记录在 REVIEW.json 的 ship 段
VERDICTS = {
    "longren": {
        "001": ("reject", "正面站、左右半色裂，非 3/4 龙人侧视"),
        "002": ("reject", "肢体重噪、手臂不可读"),
        "003": ("reject", "臂翼粘连、手脚糊成团"),
        "004": ("reject", "右臂/翼融合 + 大块灰影噪点"),
        "005": ("reject", "体态偏四足喷火龙，非龙人；腿数混乱、底边裁切伪影"),
        "006": ("reject", "前视；小臂再生翼，手/翼粘连"),
        "007": ("reject", "前视；髋部长翼，手糊"),
        "008": ("reject", "四翼+幻影肢"),
        "009": ("reject", "尾巴末端长第二头"),
        "010": ("reject", "下半身多条线状肢，不可读"),
    },
    "whelp": {
        "001": ("reject", "细线肢、轮廓不可读"),
        "002": ("reject", "抽象噪点块，无幼龙形"),
        "003": ("reject", "翼/身糊成一团"),
        "004": ("reject", "下半身溶解，无脚"),
    },
    "drake": {
        "001": ("reject", "竖条糊肢，无四足/双足结构"),
        "002": ("reject", "raw 腿数/翼附混乱（见 raw）"),
        "003": ("reject", "raw 胸出臂+腿错位"),
        "004": ("reject", "raw 多前爪叠肢"),
        "005": ("reject", "臂翼粘连、髋部残翼；i2i 仍乱"),
        "006": ("reject", "双对翼+前臂翼膜"),
        "007": ("reject", "四足腿位错、鬼肢"),
        "008": ("reject", "臂翼粘连、四翼"),
    },
    "adult": {
        "001": ("reject", "细线乱肢，无巨龙体"),
        "002": ("reject", "噪点乱团，无轮廓"),
        "003": ("reject", "腿断线、翼糊"),
        "004": ("reject", "中段横翼/肢混乱"),
    },
    "picks": {
        "pick_004_flame_drake": (
            "weak",
            "历史选定参考（曾进 unit_1）；像素级仍有翼不对称/胸空洞，仅作风格参照勿当解剖范本",
        ),
    },
}

SHIP = {
    "dragon/unit_0.png": ("reject", "正面乱肢，不可读，建议换"),
    "dragon/unit_1.png": ("weak", "当前 ship；可读为双足火龙但翼/腿像素仍糊，仅过渡"),
    "dragon/unit_2.png": ("reject", "极简斑点+乱线，不像单位，建议换"),
}


def move_reject(category: str, tag: str, reason: str) -> None:
    src_dir = os.path.join(DRAGON, category)
    dst_dir = os.path.join(DRAGON, f"{category}_rejected")
    os.makedirs(dst_dir, exist_ok=True)
    moved = []
    for kind in ("raw", "game"):
        name = f"{tag}_{kind}.png"
        src = os.path.join(src_dir, name)
        if os.path.isfile(src):
            dst = os.path.join(dst_dir, name)
            if os.path.isfile(dst):
                # 避免覆盖：加 audit 后缀
                dst = os.path.join(dst_dir, f"{tag}_{kind}_audit.png")
            shutil.move(src, dst)
            moved.append(name)
    # picks 特殊文件名
    if category == "picks":
        for kind in ("raw", "game"):
            name = f"{tag}_{kind}.png"
            src = os.path.join(src_dir, name)
            # keep weak picks in place
    note = os.path.join(dst_dir, f"{tag}_NOTE.txt")
    with open(note, "w", encoding="utf-8") as f:
        f.write(reason + "\n")
    print(f"REJECT {category}/{tag}: {moved or '(already gone)'} — {reason}")


def rebuild_catalog(category: str, kept: dict) -> None:
    from archive_candidates import _save_catalog  # type: ignore

    items = []
    d = os.path.join(DRAGON, category)
    if not os.path.isdir(d):
        return
    tags = sorted({f[:3] for f in os.listdir(d) if f.endswith(".png") and f[:3].isdigit()})
    for tag in tags:
        raw = os.path.join(d, f"{tag}_raw.png")
        game = os.path.join(d, f"{tag}_game.png")
        v = kept.get(tag, ("keep", ""))
        items.append(
            {
                "index": int(tag),
                "tag": tag,
                "created": str(date.today()),
                "note": v[1],
                "verdict": v[0],
                "source": "audit",
                "raw": os.path.relpath(raw, ROOT).replace("\\", "/") if os.path.isfile(raw) else None,
                "game": os.path.relpath(game, ROOT).replace("\\", "/") if os.path.isfile(game) else None,
            }
        )
    _save_catalog(f"dragon/{category}", {"asset_id": f"dragon/{category}", "items": items})


def main():
    review = {"date": str(date.today()), "rules": "ANATOMY.md — limbs > style", "categories": {}, "ship": SHIP}
    for cat, entries in VERDICTS.items():
        review["categories"][cat] = {}
        kept = {}
        for tag, (verdict, reason) in entries.items():
            review["categories"][cat][tag] = {"verdict": verdict, "reason": reason}
            if cat == "picks":
                continue  # weak pick stays
            if verdict == "reject":
                move_reject(cat, tag, reason)
            else:
                kept[tag] = (verdict, reason)
        if cat != "picks":
            rebuild_catalog(cat, kept)

    out = os.path.join(DRAGON, "REVIEW.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(review, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("wrote", out)

    # summary counts
    for cat, entries in VERDICTS.items():
        n = len(entries)
        r = sum(1 for v, _ in entries.values() if v == "reject")
        w = sum(1 for v, _ in entries.values() if v == "weak")
        k = n - r - w
        print(f"{cat}: reject={r} weak={w} keep={k} / {n}")


if __name__ == "__main__":
    main()
