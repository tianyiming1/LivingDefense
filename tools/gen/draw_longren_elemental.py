"""程序像素绘制 5 种龙人亚种（色板 + 剪影双差）。

美术总监方案：fire / ice / storm / stone / jade
锚点：pick_004 晶体块鳞 + ANATOMY 背翼分离；96×108 真像素。

  python tools/gen/draw_longren_elemental.py
  python tools/gen/draw_longren_elemental.py --preview
  python tools/gen/draw_longren_elemental.py --modes fire,ice
"""
from __future__ import annotations

import argparse
import os
import sys
import tempfile

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from archive_candidates import archive_pair  # noqa: E402

W, H = 96, 108
FOOT = 100

# —— 色板：美术总监 hex → RGBA ——
PALETTES = {
    "fire": {
        "ol": (20, 6, 8, 255),
        "b1": (255, 92, 58, 255),   # #FF5C3A
        "b2": (196, 32, 36, 255),   # #C42024
        "b3": (88, 10, 16, 255),    # #580A10
        "b4": (255, 150, 90, 255),
        "m1": (110, 50, 100, 255),
        "m2": (42, 16, 58, 255),    # #2A103A
        "m3": (28, 10, 40, 255),
        "m4": (80, 36, 78, 255),
        "eye": (255, 236, 110, 255),
        "mouth": (48, 12, 18, 255),
    },
    "ice": {
        "ol": (18, 28, 48, 255),
        "b1": (230, 242, 250, 255),  # #E6F2FA 霜白高（禁纯白）
        "b2": (168, 198, 220, 255),  # #A8C6DC
        "b3": (72, 102, 138, 255),   # #48668A
        "b4": (210, 230, 245, 255),
        "m1": (60, 90, 150, 255),
        "m2": (28, 48, 92, 255),     # #1C305C
        "m3": (20, 32, 64, 255),
        "m4": (48, 72, 120, 255),
        "eye": (160, 240, 255, 255),
        "mouth": (30, 40, 70, 255),
    },
    "storm": {
        "ol": (10, 10, 12, 255),
        "b1": (201, 162, 39, 255),   # #C9A227 硫金高光
        "b2": (61, 53, 40, 255),     # #3D3528
        "b3": (26, 24, 20, 255),     # #1A1814
        "b4": (230, 200, 90, 255),
        "m1": (40, 50, 80, 255),
        "m2": (14, 20, 36, 255),     # #0E1424
        "m3": (8, 12, 22, 255),
        "m4": (30, 38, 60, 255),
        "eye": (255, 250, 180, 255),
        "mouth": (20, 18, 16, 255),
    },
    "stone": {
        "ol": (24, 16, 10, 255),
        "b1": (196, 166, 106, 255),  # #C4A66A
        "b2": (139, 106, 61, 255),   # #8B6A3D
        "b3": (62, 42, 24, 255),     # #3E2A18
        "b4": (210, 185, 130, 255),
        "m1": (90, 70, 48, 255),
        "m2": (42, 28, 18, 255),     # #2A1C12
        "m3": (30, 20, 12, 255),
        "m4": (70, 52, 34, 255),
        "eye": (240, 200, 120, 255),
        "mouth": (36, 24, 14, 255),
    },
    "jade": {
        "ol": (8, 28, 22, 255),
        "b1": (126, 191, 154, 255),  # #7EBF9A
        "b2": (31, 122, 92, 255),    # #1F7A5C
        "b3": (15, 61, 50, 255),     # #0F3D32
        "b4": (160, 210, 180, 255),
        "m1": (40, 80, 60, 255),
        "m2": (18, 36, 28, 255),     # #12241C
        "m3": (12, 24, 18, 255),
        "m4": (32, 64, 48, 255),
        "eye": (200, 255, 220, 255),
        "mouth": (10, 36, 28, 255),
    },
}

ALL_MODES = ("fire", "ice", "storm", "stone", "jade")


def box(d, x, y, c, w=1, h=1):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def facet(d, x, y, lo, mid, hi):
    box(d, x, y, lo, 2, 2)
    box(d, x, y, mid, 1, 1)
    box(d, x + 1, y, hi, 1, 1)


def scatter_facets(d, x0, y0, w, h, p, step=3):
    b1, b2, b3, b4 = p["b1"], p["b2"], p["b3"], p["b4"]
    i = 0
    for y in range(y0, y0 + h, step):
        for x in range(x0, x0 + w, step):
            pick = (i + x + y) % 3
            if pick == 0:
                facet(d, x, y, b3, b2, b1)
            elif pick == 1:
                facet(d, x, y, b2, b1, b4)
            else:
                facet(d, x, y, b3, b2, b4)
            i += 1


def thick_claw(d, hx, hy, p, side="L"):
    m2, m3, m4, ol = p["m2"], p["m3"], p["m4"], p["ol"]
    box(d, hx + 1, hy - 3, p["b3"], 6, 4)
    box(d, hx, hy, m2, 9, 6)
    box(d, hx + 1, hy + 1, m4, 6, 3)
    box(d, hx - 1, hy, ol, 1, 6)
    box(d, hx + 9, hy, ol, 1, 6)
    if side == "L":
        box(d, hx - 4, hy - 1, m2, 4, 4)
        box(d, hx - 5, hy, m3, 3, 3)
        for dx, dy in ((-1, 6), (2, 6), (5, 6)):
            box(d, hx + dx, hy + dy, m2, 3, 7)
            box(d, hx + dx, hy + dy + 6, m3, 3, 3)
            box(d, hx + dx, hy + dy + 8, ol, 2, 1)
    else:
        box(d, hx + 8, hy - 1, m2, 4, 4)
        box(d, hx + 10, hy, m3, 3, 3)
        for dx, dy in ((-1, 6), (2, 6), (5, 6)):
            box(d, hx + dx, hy + dy, m2, 3, 7)
            box(d, hx + dx, hy + dy + 6, m3, 3, 3)
            box(d, hx + dx + 1, hy + dy + 8, ol, 2, 1)


def wing_pair(d, p, style: str):
    """style: fire|ice|storm|stone|jade — 背翼根同在肩胛，形状差。"""
    m1, m2, m3, m4, ol = p["m1"], p["m2"], p["m3"], p["m4"], p["ol"]
    # 左翼根（背）
    box(d, 30, 34, m3, 9, 7)
    box(d, 33, 36, m2, 6, 5)

    if style == "stone":
        # 短阔低展
        d.polygon(
            [(36, 42), (28, 36), (14, 32), (8, 40), (10, 48), (22, 50), (34, 46)],
            fill=m2,
            outline=ol,
        )
        box(d, 12, 36, m1, 5, 4)
    elif style == "storm":
        # 尖撕缘
        tips = [(2, 4), (0, 20), (4, 36), (10, 44)]
        elbow = (20, 26)
        for tx, ty in tips:
            d.line([elbow, (tx, ty)], fill=ol, width=2)
        d.polygon(
            [(36, 40), (28, 32), (14, 18), (2, 4), (0, 12), (0, 22), (4, 36), (10, 46), (28, 46), (36, 42)],
            fill=m2,
            outline=ol,
        )
        for tx, ty in tips:
            box(d, tx, ty, m3, 2, 3)
            box(d, tx + 1, ty + 2, b_tear(p), 2, 2)
    elif style == "jade":
        # 修长
        d.polygon(
            [(36, 40), (30, 32), (16, 18), (0, 2), (-2, 10), (2, 24), (6, 42), (18, 50), (32, 48), (36, 42)],
            fill=m2,
            outline=ol,
        )
        box(d, 6, 14, m1, 4, 3)
        box(d, 8, 28, m4, 4, 3)
    elif style == "ice":
        tips = [(4, 8), (2, 22), (6, 40)]
        elbow = (20, 26)
        for tx, ty in tips:
            d.line([elbow, (tx, ty)], fill=ol, width=2)
            box(d, tx, ty, m3, 3, 3)
        d.polygon(
            [(36, 40), (30, 34), (18, 24), (4, 8), (2, 14), (2, 22), (4, 32), (6, 40), (16, 46), (28, 46), (36, 42)],
            fill=m2,
            outline=ol,
        )
        for wx, wy in ((4, 10), (3, 20)):
            box(d, wx, wy, p["b4"], 2, 4)
            box(d, wx, wy + 3, ol, 2, 1)
    else:
        # fire default
        tips = [(4, 8), (2, 22), (6, 40)]
        elbow = (20, 26)
        for tx, ty in tips:
            d.line([elbow, (tx, ty)], fill=ol, width=2)
            box(d, tx, ty, m3, 3, 3)
        d.polygon(
            [(36, 40), (30, 34), (18, 24), (4, 8), (2, 14), (2, 22), (4, 32), (6, 40), (16, 46), (28, 46), (36, 42)],
            fill=m2,
            outline=ol,
        )
        box(d, 8, 16, m1, 4, 3)
        box(d, 7, 26, m1, 4, 3)

    # 右翼根
    box(d, 54, 30, m3, 9, 7)
    box(d, 51, 33, m1, 6, 5)

    if style == "stone":
        d.polygon(
            [(52, 38), (58, 30), (72, 28), (80, 36), (78, 46), (64, 48), (54, 44)],
            fill=m1,
            outline=ol,
        )
        box(d, 68, 34, m4, 5, 4)
    elif style == "storm":
        tips = [(90, 0), (94, 12), (92, 26), (82, 40)]
        wrist = (72, 18)
        for tx, ty in tips:
            d.line([wrist, (tx, ty)], fill=ol, width=2)
        d.polygon(
            [(51, 36), (56, 28), (70, 14), (90, 0), (94, 6), (94, 16), (90, 28), (82, 40), (66, 46), (54, 42)],
            fill=m1,
            outline=ol,
        )
        for tx, ty in tips:
            box(d, tx, ty, m3, 2, 3)
    elif style == "jade":
        d.polygon(
            [(51, 36), (56, 28), (72, 12), (94, -2), (96, 8), (94, 22), (88, 38), (72, 50), (56, 48), (52, 40)],
            fill=m1,
            outline=ol,
        )
        box(d, 80, 8, m4, 5, 3)
        box(d, 84, 20, m4, 4, 3)
    elif style == "ice":
        tips = [(88, 2), (92, 14), (90, 28), (78, 42)]
        wrist = (72, 20)
        for tx, ty in tips:
            d.line([wrist, (tx, ty)], fill=ol, width=2)
            box(d, tx, ty, m3, 3, 3)
        d.polygon(
            [(51, 36), (54, 30), (66, 18), (88, 2), (92, 6), (93, 16), (90, 28), (84, 36), (78, 42), (66, 46), (54, 42)],
            fill=m1,
            outline=ol,
        )
        for wx, wy in ((88, 4), (92, 16), (90, 30)):
            box(d, wx, wy, p["b4"], 2, 4)
            box(d, wx, wy + 3, ol, 2, 1)
    else:
        tips = [(88, 2), (92, 14), (90, 28), (78, 42)]
        wrist = (72, 20)
        for tx, ty in tips:
            d.line([wrist, (tx, ty)], fill=ol, width=2)
            box(d, tx, ty, m3, 3, 3)
        d.polygon(
            [(51, 36), (54, 30), (66, 18), (88, 2), (92, 6), (93, 16), (90, 28), (84, 36), (78, 42), (66, 46), (54, 42)],
            fill=m1,
            outline=ol,
        )
        box(d, 78, 10, m4, 5, 3)
        box(d, 80, 18, m4, 4, 3)
        # 焦缘
        box(d, 4, 12, p["b3"], 3, 2)
        box(d, 90, 8, p["b3"], 3, 2)


def b_tear(p):
    return p["b4"]


def draw_tail(d, p, species: str):
    b1, b2, b3, b4, ol = p["b1"], p["b2"], p["b3"], p["b4"], p["ol"]
    if species == "ice":
        d.polygon([(30, 68), (14, 78), (6, 98), (12, 100), (22, 84), (34, 72)], fill=b2, outline=ol)
        for i, (sx, sy) in enumerate(((8, 86), (12, 92), (16, 80), (20, 88), (24, 76))):
            box(d, sx, sy, b4 if i % 2 == 0 else b1, 3, 8)
            box(d, sx + 1, sy + 7, ol, 1, 2)
    elif species == "storm":
        # 细鞭 + 箭簇
        d.polygon([(32, 70), (18, 78), (8, 92), (14, 94), (24, 82), (34, 72)], fill=b2, outline=ol)
        box(d, 6, 90, b3, 4, 8)
        box(d, 4, 96, b1, 8, 3)
        box(d, 6, 98, ol, 4, 2)
        box(d, 2, 94, b4, 3, 3)
        box(d, 12, 94, b4, 3, 3)
    elif species == "stone":
        # 棒锤多节
        d.polygon([(34, 72), (16, 80), (10, 92), (18, 98), (28, 90), (36, 76)], fill=b2, outline=ol)
        box(d, 8, 88, b3, 14, 10)
        box(d, 10, 90, b1, 10, 6)
        scatter_facets(d, 10, 90, 10, 6, p, step=3)
        box(d, 12, 84, b3, 8, 5)
        box(d, 14, 78, b2, 6, 5)
    elif species == "jade":
        # 长叶刃尾
        d.polygon([(34, 68), (20, 76), (4, 88), (0, 100), (8, 102), (18, 90), (30, 78), (38, 70)], fill=b2, outline=ol)
        box(d, 2, 92, b1, 4, 8)
        box(d, 8, 86, b4, 3, 10)
        box(d, 14, 80, b1, 3, 8)
        box(d, 0, 98, ol, 6, 2)
    else:
        # fire 粗熔岩尾
        d.polygon([(28, 70), (8, 82), (4, 96), (14, 98), (32, 80), (34, 72)], fill=b2, outline=ol)
        box(d, 10, 88, b4, 6, 6)
        box(d, 16, 78, b1, 5, 5)
        scatter_facets(d, 10, 82, 18, 12, p, step=4)


def draw_horns_head(d, p, species: str):
    b1, b2, b3, b4, ol = p["b1"], p["b2"], p["b3"], p["b4"], p["ol"]
    eye, mouth = p["eye"], p["mouth"]
    lean = species in ("ice", "jade", "storm")
    stocky = species == "stone"

    hw = 11 if lean else (16 if stocky else 14)
    hh = 15 if lean else (16 if stocky else 18)
    hx = 47 if lean else (34 if stocky else 48)
    if stocky:
        hx = 40
    box(d, hx, 22 if not stocky else 26, b1, hw, hh)
    box(d, hx + 2, 24 if not stocky else 28, b2, hw - 4, hh - 4)

    if species == "ice":
        d.polygon([(54, 12), (78, 8), (80, 28), (56, 30)], fill=b1, outline=ol)
        box(d, 58, 14, b2, 16, 12)
        scatter_facets(d, 58, 12, 14, 12, p, step=2)
        box(d, 58, 0, b4, 4, 14)
        box(d, 57, 0, ol, 1, 14)
        box(d, 70, 0, b4, 4, 16)
        box(d, 74, 0, ol, 1, 16)
        box(d, 64, 2, b1, 3, 10)
        ex, ey = 66, 16
    elif species == "storm":
        # 折线电冠
        d.polygon([(50, 18), (72, 14), (76, 28), (54, 30)], fill=b2, outline=ol)
        scatter_facets(d, 54, 16, 16, 10, p, step=2)
        # zigzag left
        d.polygon([(54, 16), (48, 6), (52, 6), (56, 12), (60, 2), (64, 2), (58, 14)], fill=b1, outline=ol)
        d.polygon([(66, 14), (62, 4), (66, 4), (70, 10), (76, 0), (80, 0), (72, 14)], fill=b4, outline=ol)
        box(d, 56, 0, ol, 2, 2)
        box(d, 74, 0, ol, 2, 2)
        ex, ey = 64, 18
    elif species == "stone":
        # 向前钝夯角
        d.ellipse([42, 18, 74, 40], fill=b1, outline=ol)
        box(d, 48, 24, b2, 18, 12)
        scatter_facets(d, 48, 22, 16, 10, p, step=3)
        d.polygon([(44, 22), (28, 18), (24, 26), (30, 30), (46, 28)], fill=b2, outline=ol)
        d.polygon([(70, 20), (86, 14), (90, 22), (84, 28), (72, 26)], fill=b3, outline=ol)
        box(d, 26, 20, b1, 6, 6)
        box(d, 84, 16, b1, 6, 6)
        ex, ey = 58, 24
    elif species == "jade":
        # 分叉枝角
        d.polygon([(52, 16), (70, 12), (74, 26), (56, 28)], fill=b1, outline=ol)
        box(d, 56, 16, b2, 12, 10)
        scatter_facets(d, 56, 14, 12, 10, p, step=2)
        # antlers
        box(d, 54, 2, b2, 3, 14)
        box(d, 52, 4, b1, 3, 3)
        box(d, 48, 6, b4, 5, 2)
        box(d, 68, 0, b2, 3, 16)
        box(d, 70, 2, b1, 3, 3)
        box(d, 72, 4, b4, 5, 2)
        box(d, 66, 6, b1, 3, 4)
        box(d, 60, 4, b4, 2, 6)
        ex, ey = 64, 16
    else:
        # fire 弯焰角
        d.ellipse([50, 8, 82, 34], fill=b1, outline=ol)
        box(d, 54, 14, b2, 20, 14)
        scatter_facets(d, 54, 12, 18, 12, p, step=3)
        box(d, 56, 2, b4, 6, 10)
        box(d, 55, 2, ol, 1, 9)
        box(d, 68, 1, b4, 6, 11)
        box(d, 73, 1, ol, 1, 10)
        ex, ey = 66, 16

    box(d, ex, ey, ol, 10, 7)
    box(d, ex + 2, ey + 1, eye, 7, 4)
    box(d, ex + 4, ey + 2, ol, 3, 2)
    box(d, ex, ey - 2, b3, 8, 2)
    snout_w = 8 if lean else 10
    box(d, ex + 8, ey + 4, b3, snout_w, 8 if not lean else 6)
    box(d, ex + 10, ey + 5, b2, 7, 5)
    box(d, ex + 12, ey + 6, ol, 3, 1)
    box(d, ex + 10, ey + 10, mouth, 8, 3)
    box(d, ex + 8, ey + 13, b3, 7, 3)
    # 颈肩小刺
    box(d, 39 if not stocky else 36, 34 if not stocky else 38, b4, 4, 4)
    box(d, 54 if not stocky else 58, 34 if not stocky else 38, b4, 4, 4)


def draw_longren(p: dict, species: str = "fire") -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    b1, b2, b3 = p["b1"], p["b2"], p["b3"]

    # 体型参数
    if species == "stone":
        tw, th, tx, ty = 28, 34, 34, 40
        lw, rw = 13, 14
        lean = False
    elif species == "jade":
        tw, th, tx, ty = 16, 40, 40, 32
        lw, rw = 7, 8
        lean = True
    elif species == "storm":
        tw, th, tx, ty = 18, 36, 39, 34
        lw, rw = 8, 9
        lean = True
    elif species == "ice":
        tw, th, tx, ty = 18, 36, 39, 36
        lw, rw = 8, 9
        lean = True
    else:
        tw, th, tx, ty = 24, 38, 36, 36
        lw, rw = 11, 12
        lean = False

    wing_pair(d, p, species)
    draw_tail(d, p, species)

    # 左腿
    box(d, 30 if not species == "stone" else 28, 70 if not species == "stone" else 68, b3, lw, 18 if species != "stone" else 16)
    box(d, 32 if species != "stone" else 30, 84 if species != "stone" else 80, b2, max(6, lw - 2), 12)
    scatter_facets(d, 31 if species != "stone" else 29, 72 if species != "stone" else 70, max(6, lw - 2), 14, p, step=3)
    foot_w = 14 if not lean else 11
    if species == "stone":
        foot_w = 16
    box(d, 28, FOOT - 3, p["m2"], foot_w, 4)
    box(d, 27, FOOT, p["m1"], 3, 4)
    box(d, 32, FOOT, p["m1"], 3, 4)
    box(d, 37 if not lean else 35, FOOT, p["m1"], 3, 4)

    # 躯干
    box(d, tx, ty, b1, tw, th)
    box(d, tx + 3, ty + 3, b2, tw - 6, th - 6)
    scatter_facets(d, tx + 2, ty + 2, tw - 4, th - 8, p, step=3 if not lean else 2)
    belly_w = 10 if lean else (14 if species == "stone" else 12)
    box(d, tx + 5, ty + 6, p["m1"], belly_w, 22 if lean else 26)
    box(d, tx + 7, ty + 9, p["m2"], max(4, belly_w - 5), 16 if lean else 20)
    box(d, tx + 6, ty + 14, p["ol"], max(5, belly_w - 4), 1)
    box(d, tx + 6, ty + 20, p["ol"], max(5, belly_w - 4), 1)
    box(d, tx + 6, ty + 26, p["ol"], max(5, belly_w - 4), 1)

    # 右腿
    rx = 48 if not lean else (46 if species != "stone" else 50)
    if species == "stone":
        rx = 50
    box(d, rx, 70 if species != "stone" else 68, b1, rw, 18 if species != "stone" else 16)
    box(d, rx + 2, 84 if species != "stone" else 80, b2, max(6, rw - 2), 12)
    scatter_facets(d, rx + 1, 72 if species != "stone" else 70, max(6, rw - 2), 14, p, step=3)
    box(d, rx - 2, FOOT - 3, p["m2"], foot_w + 1, 4)
    box(d, rx - 3, FOOT, p["m1"], 3, 4)
    box(d, rx + 3, FOOT, p["m1"], 3, 4)
    box(d, rx + 9 if not lean else rx + 7, FOOT, p["m1"], 3, 4)

    # 臂（与背翼分离）
    aw = 7 if lean else (9 if species == "stone" else 8)
    box(d, 33, 42 if species != "stone" else 44, b3, aw, 7)
    box(d, 27, 46 if species != "stone" else 48, b3, aw + 1, 10)
    box(d, 22, 54 if species != "stone" else 56, b2, aw + 1, 9)
    scatter_facets(d, 24, 48 if species != "stone" else 50, 8, 12, p, step=3)
    thick_claw(d, 18, 62 if species != "stone" else 64, p, side="L")

    box(d, 54, 39 if species != "stone" else 42, b1, aw + 2, 7)
    box(d, 58, 45 if species != "stone" else 48, b1, aw + 2, 10)
    box(d, 63, 52 if species != "stone" else 54, b2, aw + 2, 9)
    scatter_facets(d, 56, 42 if species != "stone" else 44, 10, 14, p, step=3)
    thick_claw(d, 66, 60 if species != "stone" else 62, p, side="R")

    draw_horns_head(d, p, species)
    return img


def build_contact_sheet(cells: list[tuple[str, Image.Image]], out_path: str) -> None:
    n = len(cells)
    cols = min(n, 5)
    rows = (n + cols - 1) // cols
    cell_w, cell_h = W * 4, H * 4
    pad, label_h = 12, 28
    sheet = Image.new(
        "RGB",
        (16 * 2 + cols * cell_w + (cols - 1) * pad, 16 * 2 + rows * (cell_h + label_h) + (rows - 1) * pad),
        (12, 12, 16),
    )
    dr = ImageDraw.Draw(sheet)
    for i, (lab, im) in enumerate(cells):
        r, c = divmod(i, cols)
        x = 16 + c * (cell_w + pad)
        y = 16 + r * (cell_h + label_h + pad)
        sheet.paste(im, (x, y), im if im.mode == "RGBA" else None)
        dr.text((x, y + cell_h + 4), lab[:28], fill=(220, 200, 160))
    sheet.save(out_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--modes", default=",".join(ALL_MODES), help="comma list of subspecies")
    ap.add_argument("--no-archive", action="store_true", help="only write preview, skip studio archive")
    args = ap.parse_args()

    modes = [m.strip() for m in args.modes.split(",") if m.strip()]
    for m in modes:
        if m not in PALETTES:
            raise SystemExit(f"unknown mode {m}; choose from {ALL_MODES}")

    picks = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "picks")
    os.makedirs(picks, exist_ok=True)
    tags = []
    for mode in modes:
        pal = PALETTES[mode]
        img = draw_longren(pal, species=mode)
        if args.no_archive:
            tags.append((mode, "local", img))
            print(mode, "drawn (no archive)")
            continue
        with tempfile.TemporaryDirectory() as td:
            raw_p = os.path.join(td, f"{mode}_raw.png")
            img.resize((W * 4, H * 4), Image.NEAREST).save(raw_p)
            game_p = os.path.join(td, f"{mode}_game.png")
            img.save(game_p)
            note = f"procedural_pixel_{mode}_5pack"
            entry = archive_pair(
                "dragon/longren",
                raw_p,
                game_p,
                note=note,
                source="draw_longren_elemental",
                prompt=f"species={mode} art_director_5pack",
            )
            tags.append((mode, entry["tag"], img))
            print(mode, "->", entry["tag"], note)

    cells = []
    ref = os.path.join(picks, "pick_004_flame_drake_game.png")
    if os.path.isfile(ref):
        im = Image.open(ref).convert("RGBA").resize((W * 4, H * 4), Image.NEAREST)
        cells.append(("004 anchor", im))
    for mode, tag, img in tags:
        cells.append((f"{tag} {mode}", img.resize((W * 4, H * 4), Image.NEAREST)))

    out = os.path.join(picks, "_preview_longren_5pack.png")
    build_contact_sheet(cells, out)
    print("preview", out)
    if args.preview:
        os.startfile(out)  # type: ignore[attr-defined]


if __name__ == "__main__":
    main()
