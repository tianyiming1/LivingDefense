"""pick_004 v4：粗分指爪 + 拉开的蝠翼骨膜（不被身子挡住）。"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PICKS = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "picks")
OUT = os.path.join(PICKS, "pick_004_flame_drake_game.png")
ORIG = os.path.join(PICKS, "pick_004_flame_drake_game_original.png")

W, H = 64, 72
FOOT = 67

OL = (8, 2, 6, 255)
O1 = (236, 118, 48, 255)
O2 = (214, 78, 30, 255)
O3 = (168, 48, 20, 255)
O4 = (255, 186, 86, 255)
P1 = (118, 52, 102, 255)
P2 = (78, 30, 68, 255)
P3 = (148, 78, 128, 255)
P4 = (56, 20, 50, 255)
EY = (255, 236, 110, 255)
MOUTH = (48, 16, 20, 255)


def box(d, x, y, c, w=1, h=1):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def thick_claw(d, hx, hy, side="L"):
    """粗爪：掌 6x4 + 拇指 + 三指（每指 2px 宽）。"""
    # 腕
    box(d, hx + 1, hy - 2, O2 if side == "R" else O3, 4, 3)
    # 掌
    box(d, hx, hy, P2, 6, 4)
    box(d, hx + 1, hy + 1, P3, 4, 2)
    box(d, hx - 1, hy, OL, 1, 4)
    box(d, hx + 6, hy, OL, 1, 4)

    if side == "L":
        # 拇指朝左上
        box(d, hx - 3, hy - 1, P1, 3, 3)
        box(d, hx - 4, hy, P4, 2, 2)
        # 三指朝下（粗）
        box(d, hx - 1, hy + 4, P1, 2, 5)
        box(d, hx + 2, hy + 4, P1, 2, 6)
        box(d, hx + 5, hy + 4, P1, 2, 5)
        # 指尖甲
        box(d, hx - 1, hy + 8, P4, 2, 2)
        box(d, hx + 2, hy + 9, P4, 2, 2)
        box(d, hx + 5, hy + 8, P4, 2, 2)
        box(d, hx - 1, hy + 9, OL, 1, 1)
        box(d, hx + 2, hy + 10, OL, 1, 1)
        box(d, hx + 5, hy + 9, OL, 1, 1)
    else:
        box(d, hx + 6, hy - 1, P1, 3, 3)
        box(d, hx + 8, hy, P4, 2, 2)
        box(d, hx - 1, hy + 4, P1, 2, 5)
        box(d, hx + 2, hy + 4, P1, 2, 6)
        box(d, hx + 5, hy + 4, P1, 2, 5)
        box(d, hx - 1, hy + 8, P4, 2, 2)
        box(d, hx + 2, hy + 9, P4, 2, 2)
        box(d, hx + 5, hy + 8, P4, 2, 2)
        box(d, hx, hy + 9, OL, 1, 1)
        box(d, hx + 3, hy + 10, OL, 1, 1)
        box(d, hx + 6, hy + 9, OL, 1, 1)


def wing_left(d):
    """左侧蝠翼：从躯干肩胛连出去，不悬空。"""
    # 肩胛根（贴躯干 x=24）
    box(d, 20, 22, P4, 6, 5)
    box(d, 22, 24, P2, 4, 4)
    # 肘
    box(d, 12, 16, P4, 8, 4)
    tips = [(2, 4), (0, 14), (3, 26)]
    elbow = (14, 17)
    for tx, ty in tips:
        d.line([elbow, (tx, ty)], fill=OL, width=2)
        box(d, tx, ty, P4, 2, 2)
    d.polygon(
        [
            (24, 26),  # 接到躯干
            (20, 22),
            (12, 16),
            (2, 4),
            (0, 8),
            (0, 14),
            (1, 20),
            (3, 26),
            (10, 30),
            (18, 30),
            (24, 28),
        ],
        fill=P2,
        outline=OL,
    )
    for tx, ty in tips:
        d.line([elbow, (tx, ty)], fill=P4, width=1)
    box(d, 5, 10, P1, 3, 2)
    box(d, 4, 16, P3, 3, 2)
    box(d, 8, 22, P1, 3, 2)


def wing_right(d):
    """右侧蝠翼：肩胛贴右肩，伸向右上。"""
    # 肩胛根贴躯干右缘
    box(d, 36, 20, P4, 6, 5)
    box(d, 34, 22, P1, 4, 4)
    box(d, 44, 12, P4, 6, 3)
    wrist = (48, 13)
    tips = [(58, 1), (62, 8), (60, 18), (52, 28)]
    for tx, ty in tips:
        d.line([wrist, (tx, ty)], fill=OL, width=2)
        box(d, tx, ty, P4, 2, 2)
    d.polygon(
        [
            (34, 24),  # 接到躯干
            (36, 20),
            (44, 12),
            (58, 1),
            (62, 4),
            (63, 10),
            (60, 18),
            (56, 24),
            (52, 28),
            (44, 30),
            (36, 28),
        ],
        fill=P1,
        outline=OL,
    )
    for tx, ty in tips:
        d.line([wrist, (tx, ty)], fill=P4, width=1)
    box(d, 52, 6, P3, 4, 2)
    box(d, 54, 12, P3, 3, 2)
    box(d, 50, 18, P2, 4, 2)
    box(d, 46, 24, P3, 3, 2)


def draw() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # 先翅（后层）
    wing_left(d)

    # 尾
    d.polygon([(18, 46), (4, 54), (2, 64), (8, 66), (20, 54), (22, 48)], fill=O2, outline=OL)
    box(d, 6, 58, O4, 4, 4)
    box(d, 10, 52, O1, 3, 3)

    # 后腿
    box(d, 20, 46, O3, 7, 12)
    box(d, 21, 56, O2, 6, 9)
    box(d, 19, FOOT - 2, P2, 9, 3)
    box(d, 18, FOOT, P1, 2, 3)
    box(d, 21, FOOT, P1, 2, 3)
    box(d, 24, FOOT, P1, 2, 3)

    # 躯干（略收窄，给翅留空）
    box(d, 24, 24, O1, 16, 26)
    box(d, 26, 26, O2, 12, 22)
    box(d, 28, 28, P1, 8, 18)
    box(d, 30, 30, P3, 4, 14)
    box(d, 29, 34, OL, 6, 1)
    box(d, 29, 38, OL, 6, 1)
    box(d, 29, 42, OL, 6, 1)

    # 前腿
    box(d, 32, 46, O1, 8, 12)
    box(d, 33, 56, O2, 7, 9)
    box(d, 31, FOOT - 2, P2, 10, 3)
    box(d, 30, FOOT, P1, 2, 3)
    box(d, 34, FOOT, P1, 2, 3)
    box(d, 38, FOOT, P1, 2, 3)

    # 近翅（身子后）
    wing_right(d)

    # 左臂整条橙臂露在翅前 + 粗爪
    box(d, 22, 28, O3, 5, 5)   # 肩贴躯干
    box(d, 18, 31, O3, 6, 7)
    box(d, 15, 36, O2, 6, 6)
    thick_claw(d, 12, 41, side="L")

    # 右臂整条橙臂必须可见（别被翅紫盖住）
    box(d, 36, 26, O1, 7, 5)   # 肩
    box(d, 39, 30, O1, 7, 7)   # 上臂
    box(d, 42, 35, O2, 7, 6)   # 前臂
    thick_claw(d, 44, 40, side="R")

    # 颈头
    box(d, 32, 14, O1, 10, 14)
    box(d, 34, 16, O2, 7, 10)
    d.ellipse([34, 4, 56, 22], fill=O1, outline=OL)
    box(d, 36, 8, O2, 14, 10)
    box(d, 38, 1, O4, 4, 7)
    box(d, 37, 1, OL, 1, 6)
    box(d, 46, 0, O4, 4, 8)
    box(d, 49, 0, OL, 1, 7)
    box(d, 44, 9, OL, 7, 5)
    box(d, 45, 10, EY, 5, 3)
    box(d, 47, 11, OL, 2, 2)
    box(d, 44, 8, O3, 6, 1)
    box(d, 50, 12, O3, 7, 6)
    box(d, 52, 13, O2, 5, 4)
    box(d, 54, 13, OL, 2, 1)
    box(d, 52, 16, MOUTH, 6, 2)
    box(d, 53, 17, (90, 30, 25, 255), 4, 1)
    box(d, 50, 18, O3, 5, 2)
    box(d, 26, 22, O4, 3, 3)
    box(d, 36, 22, O4, 3, 3)

    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ship", action="store_true")
    args = ap.parse_args()

    if not os.path.isfile(ORIG) and os.path.isfile(OUT):
        shutil.copy2(OUT, ORIG)

    img = draw()
    img.save(OUT, optimize=True)
    prev = os.path.join(PICKS, "pick_004_flame_drake_game_preview4x.png")
    img.resize((W * 4, H * 4), Image.NEAREST).save(prev, optimize=True)
    print("wrote", OUT)
    print("OPEN THIS:", prev)

    if args.ship:
        ship = os.path.join(ROOT, "assets", "pixels", "dragon", "unit_1.png")
        img.save(ship, optimize=True)
        anim = os.path.join(ROOT, "assets", "pixels", "dragon", "unit_1_anim")
        os.makedirs(anim, exist_ok=True)
        for name in ("idle_0.png", "idle_1.png"):
            img.save(os.path.join(anim, name), optimize=True)
        for i, dy in enumerate((0, 1, 0, 1)):
            fr = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            fr.paste(img, (0, dy), img)
            fr.save(os.path.join(anim, f"walk_{i}.png"), optimize=True)
        for i, dx in enumerate((0, 2, 0)):
            fr = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            fr.paste(img, (dx, 0), img)
            fr.save(os.path.join(anim, f"attack_{i}.png"), optimize=True)
        subprocess.run(
            [
                sys.executable,
                os.path.join(os.path.dirname(__file__), "record_provenance.py"),
                "--id", "dragon/unit_1", "--source", "procedural",
                "--tool", "tools/gen/redraw_pick004.py",
                "--commercial-ok", "--path", "dragon/unit_1.png",
                "--notes", "pick_004 v4 thick claws + spread bat wings",
            ],
            check=False,
        )
        print("SHIP unit_1")


if __name__ == "__main__":
    main()
