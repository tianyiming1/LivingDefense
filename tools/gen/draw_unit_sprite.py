"""按 VISUAL_DESIGN.md + ART_GUIDE 绘制俯视几何剪影单位（程序像素，非 AI）。"""
import argparse
import os
from PIL import Image, ImageDraw

# ART_GUIDE 人族色板
C_BODY = (107, 130, 184)      # #6B82B8
C_DARK = (77, 106, 168)       # #4D6AA8
C_STAR = (255, 220, 80)       # 段星
C_BLADE = (191, 217, 255)     # 剑身亮线
C_BLADE_EDGE = (140, 160, 190)
C_HELMET = (90, 110, 160)     # 头盔主色（比躯干深）
C_HELMET_HI = (130, 150, 200) # 头盔高光
C_SHIELD = (70, 90, 130)
C_SHIELD_BOSS = (191, 217, 255)
C_OUTLINE = (30, 30, 40)
C_GRIP = (80, 60, 45)        # 剑柄
C_GUARD = (220, 185, 70)     # 护手金色（高对比，俯视可读）
C_GUARD_DK = (160, 120, 40)  # 护手暗边


def _px(draw, x, y, c, w=1, h=1):
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def _outline_rect(d, box, fill, outline=C_OUTLINE):
    d.rectangle(box, fill=fill, outline=outline, width=1)


def _draw_sword(d, hand_x, hand_y):
    """右手长剑：细刃 + 醒目十字护手 + 尖剑头。"""
    # 剑柄
    _px(d, hand_x, hand_y + 1, C_GRIP, 2, 4)
    _px(d, hand_x, hand_y, C_OUTLINE, 2, 1)
    guard_cx = hand_x + 3
    guard_cy = hand_y + 2
    # 十字护手（加粗加金，俯视清晰）
    _px(d, guard_cx - 3, guard_cy - 1, C_GUARD_DK, 8, 5)   # 暗底
    _px(d, guard_cx - 2, guard_cy, C_GUARD, 6, 3)          # 横条
    _px(d, guard_cx, guard_cy - 2, C_GUARD, 2, 7)           # 竖条
    _px(d, guard_cx, guard_cy, C_OUTLINE, 2, 1)            # 中心铆钉
    # 剑身
    blade_x = guard_cx + 3
    blade_y = guard_cy
    _px(d, blade_x, blade_y, C_BLADE, 16, 1)
    _px(d, blade_x, blade_y - 1, C_BLADE_EDGE, 14, 1)
    tip = blade_x + 16
    _px(d, tip, blade_y, C_BLADE, 1, 1)
    _px(d, tip + 1, blade_y - 1, C_BLADE, 1, 1)
    _px(d, tip + 1, blade_y, C_BLADE, 1, 1)


def draw_human_infantry(size=64, segment=1):
    """俯视步兵：头盔 + 左盾 + 右剑 + 胸甲段星。对齐 art_samples_v1 矩形剪影。"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2 + 2

    # --- 右剑（先画，在身体下层）---
    _draw_sword(d, cx + 6, cy + 1)

    # --- 躯干 ---
    body = [cx - 8, cy - 6, cx + 8, cy + 12]
    _outline_rect(d, body, C_BODY)

    # 肩甲条
    _px(d, cx - 9, cy - 5, C_DARK, 19, 2)

    # --- 左盾（持盾手，俯视见左侧大圆盾）---
    shield_cx, shield_cy = cx - 13, cy + 1
    d.ellipse([shield_cx - 7, shield_cy - 9, shield_cx + 5, shield_cy + 9], fill=C_SHIELD, outline=C_OUTLINE, width=1)
    d.ellipse([shield_cx - 3, shield_cy - 4, shield_cx + 1, shield_cy], fill=C_SHIELD_BOSS, outline=C_OUTLINE, width=1)
    _px(d, cx - 9, cy, C_DARK, 3, 4)  # 左臂连盾

    # --- 头盔（俯视圆顶 + 面甲缝）---
    helm = [cx - 7, cy - 16, cx + 7, cy - 5]
    _outline_rect(d, helm, C_HELMET)
    _px(d, cx - 6, cy - 15, C_HELMET_HI, 13, 2)  # 盔顶高光
    _px(d, cx + 2, cy - 10, C_OUTLINE, 5, 1)     # 面甲观察缝（朝右）

    # --- 右剑持握（身体前层：手）---
    _px(d, cx + 6, cy + 1, C_BODY, 3, 4)

    # --- 段星（胸甲）---
    for i in range(segment):
        sx = cx - (segment - 1) * 3 + i * 6
        sy = cy + 1
        _px(d, sx, sy, C_STAR, 3, 3)
        _px(d, sx + 1, sy - 1, C_STAR, 1, 1)
        _px(d, sx + 1, sy + 3, C_STAR, 1, 1)
        _px(d, sx - 1, sy + 1, C_STAR, 1, 1)
        _px(d, sx + 3, sy + 1, C_STAR, 1, 1)

    # 靴（俯视）
    _px(d, cx - 5, cy + 12, C_DARK, 4, 2)
    _px(d, cx + 2, cy + 12, C_DARK, 4, 2)

    return img


UNITS = {
    "human_infantry_idle": lambda: draw_human_infantry(64, 1),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--unit", default="human_infantry_idle")
    ap.add_argument("--out", default="")
    args = ap.parse_args()
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    out = args.out or os.path.join(root, "assets", "pixels", "human", "human_infantry_idle_64.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img = UNITS[args.unit]()
    img.save(out, optimize=True)
    prev = out.replace(".png", "_preview4x.png")
    big = img.resize((256, 256), Image.NEAREST)
    d = ImageDraw.Draw(big)
    d.text((8, 8), "64px infantry sword+shield", fill=(255, 255, 255, 230))
    big.save(prev, optimize=True)

    # 战场合成预览
    scene = Image.new("RGBA", (320, 320), (56, 100, 64, 255))
    sd = ImageDraw.Draw(scene)
    sd.rectangle([40, 140, 280, 180], fill=(199, 179, 128))
    scene.alpha_composite(img, (128, 128))
    scene_path = out.replace(".png", "_in_scene.png")
    scene.convert("RGB").save(scene_path, optimize=True)
    print("DONE ->", out)
    print("  preview:", prev)
    print("  in_scene:", scene_path)


if __name__ == "__main__":
    main()
