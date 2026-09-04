"""龙人眼睛：3/4 侧视水平亮缝（火琥珀 / 冰青白），禁止乱点、胸上假眼。

  python tools/gen/fix_longren_eyes.py --target picks
  python tools/gen/fix_longren_eyes.py --target 065,074
  python tools/gen/fix_longren_eyes.py --rebuild
"""
from __future__ import annotations

import argparse
import os
import shutil
import sys
import tempfile

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

PICKS = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "picks")
LONGREN = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "longren")
GAME = os.path.join(PICKS, "pick_004_flame_drake_game.png")
PREV = os.path.join(PICKS, "pick_004_flame_drake_game_preview4x.png")

# 火：琥珀缝；冰：青白缝
FIRE_SOCKET = (28, 12, 22, 255)
FIRE_SLIT = (255, 220, 90, 255)
FIRE_GLOW = (255, 250, 200, 255)
FIRE_PUPIL = (40, 18, 12, 255)

ICE_SOCKET = (16, 28, 52, 255)
ICE_SLIT = (170, 235, 255, 255)
ICE_GLOW = (230, 250, 255, 255)
ICE_PUPIL = (20, 36, 60, 255)


def _find_eye_anchor(im: Image.Image) -> tuple[int, int]:
    """在头区找侧视脸：偏左上方的局部暗窝旁亮带。"""
    px = im.load()
    w, h = im.size
    y0, y1 = int(h * 0.20), int(h * 0.38)
    x0, x1 = int(w * 0.42), int(w * 0.72)
    best = (int(w * 0.52), int(h * 0.28))
    best_score = -1e9
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = px[x, y]
            if a < 180:
                continue
            # 偏好：周围有暗（眼窝）且自身中等偏暗的脸侧
            dark_n = 0
            bright_n = 0
            for dy in range(-2, 3):
                for dx in range(-3, 4):
                    xx, yy = x + dx, y + dy
                    if not (0 <= xx < w and 0 <= yy < h):
                        continue
                    rr, gg, bb, aa = px[xx, yy]
                    if aa < 100:
                        continue
                    L = 0.3 * rr + 0.5 * gg + 0.2 * bb
                    if L < 55:
                        dark_n += 1
                    if L > 160:
                        bright_n += 1
            L0 = 0.3 * r + 0.5 * g + 0.2 * b
            # 眼窝：邻域有暗、点不太亮；略偏头左侧（朝左 3/4）
            score = dark_n * 3.0 - abs(L0 - 70) * 0.15 - bright_n * 0.5 - (x - x0) * 0.02
            if score > best_score:
                best_score = score
                best = (x, y)
    return best


def paint_eye_slit(im: Image.Image, mode: str = "fire") -> tuple[int, int]:
    """画 水平亮缝 + 暗窝 + 瞳。返回锚点。"""
    im = im.convert("RGBA")
    d = ImageDraw.Draw(im)
    ax, ay = _find_eye_anchor(im)
    if mode == "ice":
        sock, slit, glow, pup = ICE_SOCKET, ICE_SLIT, ICE_GLOW, ICE_PUPIL
    else:
        sock, slit, glow, pup = FIRE_SOCKET, FIRE_SLIT, FIRE_GLOW, FIRE_PUPIL

    # 暗窝 7×5
    d.rectangle([ax - 3, ay - 2, ax + 3, ay + 2], fill=sock)
    # 主亮缝 5×2
    d.rectangle([ax - 2, ay - 1, ax + 2, ay], fill=slit)
    # 高光 1px
    d.point((ax - 1, ay - 1), fill=glow)
    # 瞳孔
    d.point((ax + 1, ay), fill=pup)
    return ax, ay


def apply_file(path: str, mode: str) -> tuple[int, int]:
    im = Image.open(path).convert("RGBA")
    anchor = paint_eye_slit(im, mode)
    im.save(path)
    return anchor


def rebuild_variants() -> None:
    from recolor_longren_structure import recolor
    from morph_ice_from_004 import morph_ice
    from archive_candidates import archive_pair

    base = Image.open(GAME).convert("RGBA")
    # 先保证 004 眼正确，再派生
    paint_eye_slit(base, "fire")
    base.save(GAME)
    base.resize((base.width * 4, base.height * 4), Image.NEAREST).save(PREV)

    fire = recolor(base, "fire", contrast=1.4)
    paint_eye_slit(fire, "fire")
    ice = morph_ice(base)
    # morph 自带眼，再强制覆盖正确缝
    paint_eye_slit(ice, "ice")

    with tempfile.TemporaryDirectory() as td:
        for mode, img, note in (
            ("fire", fire, "structure_recolor_fire_eyefix"),
            ("ice", ice, "morph_ice_shape_eyefix"),
        ):
            rp = os.path.join(td, f"{mode}_raw.png")
            gp = os.path.join(td, f"{mode}_game.png")
            img.resize((img.width * 4, img.height * 4), Image.NEAREST).save(rp)
            img.save(gp)
            entry = archive_pair(
                "dragon/longren",
                rp,
                gp,
                note=note,
                source="fix_longren_eyes",
            )
            print(mode, "->", entry["tag"], note)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", default="picks", help="picks | rebuild | tag list")
    ap.add_argument("--mode", default="fire", choices=["fire", "ice"])
    args = ap.parse_args()

    if args.target == "rebuild":
        rebuild_variants()
        return

    if args.target == "picks":
        bak = os.path.join(PICKS, "pick_004_flame_drake_game_before_eyefix.png")
        if os.path.isfile(GAME) and not os.path.isfile(bak):
            shutil.copy2(GAME, bak)
        ax, ay = apply_file(GAME, "fire")
        im = Image.open(GAME)
        im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(PREV)
        print("fixed pick_004_game eye at", ax, ay)
        print("OPEN", PREV)
        return

    for tag in args.target.split(","):
        tag = tag.strip()
        path = os.path.join(LONGREN, f"{tag}_game.png")
        if not os.path.isfile(path):
            print("missing", path)
            continue
        mode = "ice" if args.mode == "ice" or "ice" in tag else "fire"
        # heuristic from catalog note would be better; allow --mode
        if tag.isdigit():
            # 074 ice morph family
            mode = "ice" if int(tag) in (66, 74) or args.mode == "ice" else args.mode
        ax, ay = apply_file(path, mode)
        print("fixed", tag, "eye", ax, ay, mode)


if __name__ == "__main__":
    main()
