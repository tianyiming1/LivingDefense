"""
CO-ART-PROD-001 W4：人族编制 96×108 程序像素（自有，可商用）。
身份可读：步兵剑盾 / 弓手长弓 / 箭塔 / 牧师 / 农民 / 补给站 / 法师法杖。
用法：python tools/gen/draw_human_roster_w4.py
"""
from __future__ import annotations

import json
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "pixels", "human")

W, H = 96, 108
FOOT_Y = 99
CX = 48

# VISUAL_DESIGN 人族色板
STEEL = (107, 130, 184)
STEEL_DK = (77, 106, 168)
STEEL_OUT = (40, 52, 78)
GOLD = (255, 220, 80)
BLADE = (230, 235, 245)
GRIP = (90, 70, 45)
SHIELD = (90, 105, 140)
SHIELD_BOSS = (160, 180, 210)
ROBE = (230, 232, 245)
WOOD = (120, 85, 45)
GREEN = (90, 140, 70)
PURPLE = (120, 80, 200)
SKIN = (200, 170, 140)


def _canvas() -> Image.Image:
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def _px(d: ImageDraw.ImageDraw, x: int, y: int, col, w: int = 1, h: int = 1) -> None:
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=col)


def _outline_rect(d, box, fill) -> None:
    d.rectangle(box, fill=fill, outline=STEEL_OUT)


def _legs(d, x: int = 40) -> None:
    _px(d, x, 78, STEEL_DK, 7, 16)
    _px(d, x + 12, 78, STEEL, 7, 16)
    _px(d, x - 1, 92, STEEL_OUT, 9, 4)
    _px(d, x + 11, 92, STEEL_OUT, 9, 4)


def _helmet(d, x0: int = 38, y0: int = 18) -> None:
    d.ellipse([x0, y0, x0 + 22, y0 + 20], fill=STEEL, outline=STEEL_OUT)
    _px(d, x0 + 12, y0 + 8, (150, 170, 210), 7, 4)
    _px(d, x0 + 14, y0 + 10, STEEL_OUT, 6, 3)  # 面甲缝


def draw_infantry() -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    _legs(d, 38)
    _px(d, 28, 48, (55, 70, 110), 8, 28)  # 披风
    _outline_rect(d, [34, 40, 58, 78], STEEL)
    _px(d, 38, 46, STEEL_DK, 14, 20)
    d.ellipse([18, 42, 42, 74], fill=SHIELD, outline=STEEL_OUT)
    d.ellipse([24, 52, 36, 64], fill=SHIELD_BOSS, outline=STEEL_OUT)
    _helmet(d, 36, 16)
    # 剑朝 +X
    _px(d, 58, 50, GRIP, 5, 6)
    _px(d, 60, 48, GOLD, 4, 4)
    _px(d, 62, 42, BLADE, 22, 5)
    _px(d, 82, 41, STEEL_OUT, 4, 7)
    _px(d, 42, 52, GOLD, 4, 4)  # 段星
    return img


def draw_archer() -> Image.Image:
    """弓手：长弓剪影，禁止火枪。"""
    img = _canvas()
    d = ImageDraw.Draw(img)
    _legs(d, 40)
    _outline_rect(d, [38, 42, 56, 78], (90, 130, 85))
    _px(d, 40, 48, (60, 100, 70), 12, 18)
    d.ellipse([40, 18, 58, 36], fill=(100, 140, 90), outline=STEEL_OUT)
    _px(d, 50, 26, STEEL_OUT, 5, 3)
    # 长弓（身前弧）
    d.arc([54, 28, 90, 78], 270, 90, fill=WOOD, width=4)
    _px(d, 72, 48, (200, 190, 160), 14, 2)  # 弦/箭
    _px(d, 84, 46, GOLD, 6, 2)
    _px(d, 44, 54, GOLD, 3, 3)
    return img


def draw_arrow_tower() -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    _px(d, 28, 70, STEEL_DK, 40, 22)
    _outline_rect(d, [34, 38, 62, 72], (140, 145, 160))
    _px(d, 30, 30, STEEL_OUT, 8, 14)
    _px(d, 58, 30, STEEL_OUT, 8, 14)
    _px(d, 42, 22, STEEL, 12, 18)
    # 弩臂
    _px(d, 52, 36, WOOD, 28, 4)
    _px(d, 52, 46, WOOD, 28, 4)
    _px(d, 76, 38, BLADE, 10, 2)
    _px(d, 44, 52, GOLD, 4, 4)
    return img


def draw_cleric() -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    d.polygon([(48, 16), (28, 88), (68, 88)], fill=ROBE, outline=STEEL_OUT)
    d.arc([34, 10, 62, 28], 180, 360, fill=GOLD, width=3)
    _px(d, 44, 40, GOLD, 8, 14)
    _px(d, 46, 44, (200, 170, 60), 4, 3)
    _px(d, 47, 42, (200, 170, 60), 2, 10)
    d.ellipse([40, 88, 56, 98], fill=(200, 200, 220), outline=STEEL_OUT)
    return img


def draw_farmer() -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    _legs(d, 40)
    _outline_rect(d, [38, 44, 58, 78], (150, 120, 55))
    d.ellipse([40, 22, 58, 40], fill=(180, 140, 70), outline=STEEL_OUT)
    _px(d, 36, 20, WOOD, 24, 6)  # 草帽檐
    _px(d, 58, 48, WOOD, 5, 22)  # 锄
    _px(d, 54, 46, STEEL_OUT, 12, 5)
    return img


def draw_depot() -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    _px(d, 22, 58, WOOD, 52, 28)
    _outline_rect(d, [26, 36, 70, 62], GREEN)
    _px(d, 30, 42, (200, 180, 80), 14, 10)  # 袋
    _px(d, 50, 42, (200, 180, 80), 14, 10)
    _px(d, 42, 28, WOOD, 12, 12)
    _px(d, 44, 24, GOLD, 8, 6)
    return img


def draw_mage() -> Image.Image:
    img = _canvas()
    d = ImageDraw.Draw(img)
    _legs(d, 40)
    d.polygon([(48, 18), (30, 82), (66, 82)], fill=PURPLE, outline=STEEL_OUT)
    d.ellipse([40, 14, 56, 30], fill=(90, 60, 150), outline=STEEL_OUT)
    _px(d, 36, 12, GOLD, 24, 4)  # 帽檐
    # 法杖 + 球
    _px(d, 62, 36, WOOD, 5, 48)
    d.ellipse([58, 24, 74, 40], fill=(180, 140, 255), outline=STEEL_OUT)
    _px(d, 64, 30, (240, 220, 255), 4, 4)
    return img


def draw_mortar_placeholder() -> Image.Image:
    """不直购，保留文件以免旧引用空。"""
    img = _canvas()
    d = ImageDraw.Draw(img)
    _px(d, 28, 58, (90, 70, 50), 40, 24)
    _px(d, 48, 40, (50, 40, 30), 28, 10)
    _px(d, 72, 36, STEEL_OUT, 8, 16)
    return img


SPECS = [
    (0, draw_infantry),
    (1, draw_archer),
    (2, draw_mortar_placeholder),
    (3, draw_arrow_tower),
    (4, draw_cleric),
    (5, draw_farmer),
    (6, draw_depot),
    (8, draw_mage),
]


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    # 清理误放的人族 unit_7（火枪残留）
    junk = os.path.join(OUT, "unit_7.png")
    if os.path.isfile(junk):
        os.remove(junk)
        print("removed stale", junk)
    for uid, fn in SPECS:
        path = os.path.join(OUT, "unit_%d.png" % uid)
        img = fn()
        img.save(path, optimize=True)
        print("wrote", path, img.size)
    # 同步 provenance 片段提示
    print("W4 human roster done — update PROVENANCE.json commercial_ok procedural")


if __name__ == "__main__":
    main()
