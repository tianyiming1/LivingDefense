"""
3/4 侧视像素精灵（64×72）：相机偏南，面朝 +X。
脚底锚点 FOOT_Y=66，供 Godot Sprite2D.offset 对齐。
"""
import math
import os
from PIL import Image, ImageDraw

from draw_unit_sprite import (  # noqa: E402
    C_BODY, C_DARK, C_STAR, C_BLADE, C_BLADE_EDGE, C_HELMET, C_HELMET_HI,
    C_SHIELD, C_SHIELD_BOSS, C_OUTLINE, C_GRIP, C_GUARD, C_GUARD_DK,
    _px, _outline_rect, _draw_sword,
)

W, H = 64, 72
FOOT_Y = 66
CX = 32


def _canvas():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def _leg(d, x, y, col, fwd=0):
    _px(d, x, y, col, 4, 6)
    _px(d, x + fwd, y + 5, C_OUTLINE, 5, 2)


# ── 人族 ──────────────────────────────────────────────

def draw_human_infantry_34(segment=1):
    """剑盾步兵：侧视可见头盔、盾、剑、腿。"""
    img = _canvas()
    d = ImageDraw.Draw(img)
    cy = 38
    # 后腿
    _leg(d, 22, 52, C_DARK, 1)
    # 躯干
    _outline_rect(d, [20, 28, 36, 52], C_BODY)
    _px(d, 22, 32, C_DARK, 10, 14)
    # 披风后摆
    _px(d, 16, 34, (55, 70, 110), 6, 18)
    # 前腿
    _leg(d, 28, 52, C_BODY)
    # 盾（左侧鼓起）
    d.ellipse([8, 30, 24, 54], fill=C_SHIELD, outline=C_OUTLINE)
    d.ellipse([12, 38, 20, 46], fill=C_SHIELD_BOSS, outline=C_OUTLINE)
    # 头盔侧视
    d.ellipse([24, 14, 40, 30], fill=C_HELMET, outline=C_OUTLINE)
    _px(d, 34, 20, C_HELMET_HI, 5, 3)
    _px(d, 36, 22, C_OUTLINE, 4, 2)  # 面甲缝
    _px(d, 26, 18, C_HELMET, 3, 4)   # 盔后
    # 剑（身前）
    _draw_sword(d, 38, 36)
    _px(d, 36, 38, C_BODY, 4, 5)  # 右手
    # 段星
    for i in range(segment):
        sx = 26 + i * 5
        _px(d, sx, 36, C_STAR, 3, 3)
    _px(d, 26, 62, C_DARK, 6, 4)
    _px(d, 32, 62, C_DARK, 6, 4)
    return img


def draw_human_musketeer_34():
    img = _canvas()
    d = ImageDraw.Draw(img)
    _outline_rect(d, [22, 30, 36, 52], (77, 106, 168))
    d.ellipse([24, 14, 38, 28], fill=C_HELMET, outline=C_OUTLINE)
    _leg(d, 22, 52, C_DARK, 1)
    _leg(d, 28, 52, C_BODY)
    # 火枪
    _px(d, 36, 34, (50, 40, 30), 22, 4)
    _px(d, 54, 33, C_OUTLINE, 4, 6)
    _px(d, 38, 32, C_DARK, 6, 2)
    _px(d, 28, 36, C_STAR, 3, 3)
    _px(d, 30, 38, C_STAR, 2, 2)
    return img


def draw_human_mortar_34():
    img = _canvas()
    d = ImageDraw.Draw(img)
    _outline_rect(d, [18, 40, 42, 58], (90, 70, 50))
    _px(d, 14, 44, (60, 45, 30), 6, 8)
    _px(d, 20, 44, (60, 45, 30), 6, 8)
    # 炮管
    _px(d, 36, 36, (45, 35, 25), 20, 6)
    _px(d, 52, 34, C_OUTLINE, 6, 10)
    _px(d, 28, 46, C_STAR, 3, 3)
    _px(d, 30, 48, C_STAR, 2, 2)
    _px(d, 32, 47, C_STAR, 2, 2)
    return img


def draw_human_arbalest_34():
    img = _canvas()
    d = ImageDraw.Draw(img)
    _outline_rect(d, [22, 32, 34, 52], (140, 140, 158))
    d.ellipse([24, 16, 36, 28], fill=(120, 120, 135), outline=C_OUTLINE)
    _leg(d, 23, 52, C_DARK)
    _leg(d, 28, 52, C_DARK, 1)
    # 弩
    _px(d, 34, 30, C_DARK, 18, 2)
    _px(d, 34, 38, C_DARK, 18, 2)
    _px(d, 48, 32, C_BLADE_EDGE, 8, 1)
    _px(d, 36, 34, (90, 70, 50), 4, 6)
    return img


def draw_human_cleric_34():
    img = _canvas()
    d = ImageDraw.Draw(img)
    # 白袍
    d.polygon([(32, 12), (18, 58), (46, 58)], fill=(230, 230, 245), outline=C_OUTLINE)
    d.arc([20, 8, 44, 24], 180, 360, fill=(255, 240, 180), width=2)
    _px(d, 28, 28, (255, 220, 120), 8, 10)  # 十字
    _px(d, 30, 32, (200, 180, 80), 4, 2)
    _px(d, 32, 30, (200, 180, 80), 2, 6)
    d.ellipse([26, 54, 38, 62], fill=(200, 200, 220), outline=C_OUTLINE)
    return img


# ── 菌族 ──────────────────────────────────────────────

def draw_mushroom_34(cap, spot, stem, wide=False, spore=False):
    img = _canvas()
    d = ImageDraw.Draw(img)
    sw = 10 if not wide else 14
    # 茎
    _px(d, 28, 38, stem, sw, 24)
    _px(d, 30, 42, (max(0, stem[0] - 20), max(0, stem[1] - 15), max(0, stem[2] - 10)), sw - 4, 18)
    # 伞盖侧视（半椭圆鼓起）
    d.ellipse([10, 8, 54, 42], fill=cap, outline=C_OUTLINE)
    d.ellipse([14, 12, 50, 36], fill=tuple(min(255, c + 25) for c in cap), outline=None)
    _px(d, 20, 18, spot, 8, 5)
    _px(d, 34, 22, spot, 6, 4)
    if spore:
        for ox in (48, 52, 56):
            _px(d, ox, 20, (200, 255, 150), 2, 2)
    return img


# ── 龙族 ──────────────────────────────────────────────

def draw_dragon_34(body, wing, size="small"):
    img = _canvas()
    d = ImageDraw.Draw(img)
    # 后腿
    _px(d, 18, 50, body, 5, 10)
    _px(d, 26, 52, body, 5, 8)
    # 身体
    d.ellipse([16, 32, 42, 54], fill=body, outline=C_OUTLINE)
    # 翼（后）
    d.polygon([(14, 28), (4, 12), (18, 32)], fill=wing, outline=C_OUTLINE)
    d.polygon([(14, 40), (6, 52), (18, 38)], fill=wing, outline=C_OUTLINE)
    # 颈+头
    d.ellipse([34, 18, 52, 36], fill=body, outline=C_OUTLINE)
    _px(d, 46, 24, (255, 200, 80), 3, 3)  # 眼
    _px(d, 50, 26, C_OUTLINE, 4, 2)  # 吻
    if size != "small":
        _px(d, 38, 30, (255, 120, 40), 6, 4)  # 火焰喉
    if size == "large":
        d.ellipse([12, 34, 48, 58], fill=tuple(max(0, c - 30) for c in body), outline=C_OUTLINE)
        _px(d, 14, 48, wing, 8, 6)
    return img


# ── 硅基 ──────────────────────────────────────────────

def draw_silicon_34(col, core=False, bulky=False):
    img = _canvas()
    d = ImageDraw.Draw(img)
    w = 14 if not bulky else 18
    # 腿（晶体柱）
    _px(d, 22, 48, col, 5, 16)
    _px(d, 32, 48, col, 5, 16)
    # 躯干六棱
    pts = [(CX, 20), (CX + w, 28), (CX + w, 44), (CX, 50), (CX - w, 44), (CX - w, 28)]
    d.polygon(pts, fill=col, outline=C_OUTLINE)
    if core:
        d.ellipse([24, 28, 40, 42], fill=(245, 249, 255), outline=C_OUTLINE)
        _px(d, 28, 32, (111, 211, 231), 8, 6)
    if bulky:
        _px(d, 14, 24, (60, 90, 110), 6, 28)
        _px(d, 44, 24, (60, 90, 110), 6, 28)
    return img


# ── 敌人 ──────────────────────────────────────────────

def draw_enemy_grunt_34():
    img = _canvas()
    d = ImageDraw.Draw(img)
    col, dk = (191, 74, 47), (140, 50, 30)
    _leg(d, 20, 52, dk)
    _leg(d, 28, 52, dk, 1)
    _outline_rect(d, [18, 28, 38, 52], col)
    d.ellipse([20, 10, 38, 28], fill=col, outline=C_OUTLINE)
    _px(d, 32, 18, (255, 230, 80), 4, 3)
    _px(d, 34, 22, C_OUTLINE, 5, 2)
    _px(d, 14, 30, dk, 5, 8)  # 驼背
    _px(d, 38, 34, (60, 40, 35), 6, 6)  # 拳
    _px(d, 40, 42, (60, 40, 35), 5, 5)
    return img


def draw_enemy_runner_34():
    img = _canvas()
    d = ImageDraw.Draw(img)
    col, hi = (58, 143, 198), (120, 190, 240)
    # 四足奔跑兽
    d.ellipse([20, 30, 48, 48], fill=col, outline=C_OUTLINE)
    d.ellipse([40, 22, 56, 38], fill=col, outline=C_OUTLINE)
    _px(d, 48, 26, (255, 230, 80), 3, 2)
    _px(d, 52, 28, C_OUTLINE, 4, 2)
    for lx, ly in [(18, 46), (26, 50), (34, 48), (42, 52)]:
        _px(d, lx, ly, hi, 3, 6)
    _px(d, 10, 36, hi, 8, 2)  # 尾
    return img


def draw_enemy_tank_34():
    img = _canvas()
    d = ImageDraw.Draw(img)
    col, dk = (110, 90, 115), (70, 55, 80)
    _px(d, 16, 50, dk, 8, 12)
    _px(d, 36, 50, dk, 8, 12)
    d.ellipse([12, 24, 52, 56], fill=col, outline=C_OUTLINE)
    d.ellipse([18, 30, 46, 50], fill=dk, outline=C_OUTLINE)
    d.ellipse([22, 12, 42, 32], fill=col, outline=C_OUTLINE)
    _px(d, 32, 18, (255, 230, 80), 5, 4)
    _px(d, 10, 28, dk, 6, 10)
    _px(d, 48, 28, dk, 6, 10)
    return img


def draw_enemy_boss_34():
    img = _canvas()
    d = ImageDraw.Draw(img)
    col = (90, 25, 35)
    _outline_rect(d, [12, 20, 52, 58], col)
    d.ellipse([18, 4, 46, 28], fill=col, outline=C_OUTLINE)
    _px(d, 10, 8, (50, 15, 25), 5, 12)
    _px(d, 48, 8, (50, 15, 25), 5, 12)
    _px(d, 36, 14, (255, 200, 60), 6, 4)
    _px(d, 50, 36, (40, 25, 30), 8, 8)
    _px(d, 50, 48, (40, 25, 30), 8, 8)
    for pad in (28, 32, 36):
        d.ellipse([CX - pad, 30 - pad // 2, CX + pad, 58 + pad // 3],
                  outline=(40, 15, 25, 120), width=2)
    return img


def save_preview(img, path):
    img.save(path, optimize=True)
    prev = img.resize((256, 288), Image.NEAREST)
    prev.save(path.replace(".png", "_preview4x.png"), optimize=True)


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out = os.path.join(root, "assets", "pixels")
    os.makedirs(out, exist_ok=True)
    print("3/4 sprites FOOT_Y=", FOOT_Y)
