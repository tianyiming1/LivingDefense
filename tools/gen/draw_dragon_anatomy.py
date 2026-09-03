"""
龙族保肢程序像素 + 剪影范本（清晰 3/4 侧视、可数肢）。

  python tools/gen/draw_dragon_anatomy.py          # 只写 studio + templates
  python tools/gen/draw_dragon_anatomy.py --ship   # 另写 unit_0/1/2 + provenance
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from archive_candidates import archive_pair, _dir, _save_catalog  # noqa: E402

W, H = 64, 72
FOOT = 66
OL = (18, 8, 6, 255)
O1 = (230, 110, 40, 255)
O2 = (200, 70, 28, 255)
O3 = (150, 45, 18, 255)
P1 = (110, 50, 100, 255)
P2 = (70, 30, 65, 255)
CR = (245, 210, 150, 255)
EY = (255, 230, 90, 255)
BG = (48, 24, 56)
SIL = (240, 120, 60)


def _c():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def _box(d, x, y, w, h, fill, outline=True):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=fill, outline=OL if outline else None)


def _foot(d, x, y):
    _box(d, x, y, 7, 3, P2)


def _claw_hand(d, x, y):
    _box(d, x, y, 5, 4, P2)
    _box(d, x + 5, y + 1, 2, 2, P2, outline=False)


def draw_longren() -> Image.Image:
    """2 臂 + 2 腿 + 1 对翼 + 1 头 1 尾。朝右 3/4。"""
    img = _c()
    d = ImageDraw.Draw(img)
    # 远翼（后）
    d.polygon([(20, 22), (6, 8), (10, 26), (22, 34)], fill=P2, outline=OL)
    # 尾（后）
    d.polygon([(18, 44), (4, 56), (8, 62), (22, 50)], fill=O2, outline=OL)
    _box(d, 6, 56, 4, 4, O1, outline=False)
    # 后腿
    _box(d, 22, 48, 6, 16, O3)
    _foot(d, 20, FOOT - 1)
    # 躯干（略厚，3/4）
    _box(d, 24, 24, 16, 26, O1)
    _box(d, 28, 28, 8, 18, P1, outline=False)
    # 前腿
    _box(d, 32, 48, 7, 16, O2)
    _foot(d, 31, FOOT - 1)
    # 近翼
    d.polygon([(36, 20), (54, 4), (58, 14), (42, 30)], fill=P1, outline=OL)
    _box(d, 44, 12, 8, 3, P2, outline=False)
    # 后臂（贴身，可见）
    _box(d, 20, 30, 5, 12, O3)
    _claw_hand(d, 18, 40)
    # 前臂伸出
    _box(d, 38, 28, 6, 14, O1)
    _claw_hand(d, 42, 40)
    # 颈 + 头
    _box(d, 34, 14, 8, 12, O1)
    d.ellipse([38, 6, 54, 22], fill=O1, outline=OL)
    _box(d, 48, 12, 3, 3, EY, outline=False)
    _box(d, 52, 14, 4, 2, OL, outline=False)
    _box(d, 40, 4, 3, 6, O1)  # 角
    _box(d, 45, 3, 2, 5, O1)
    return img


def draw_whelp() -> Image.Image:
    """幼龙：4 短腿 + 小翼。"""
    img = _c()
    d = ImageDraw.Draw(img)
    d.polygon([(24, 32), (14, 20), (26, 36)], fill=P1, outline=OL)
    d.polygon([(38, 30), (50, 18), (42, 36)], fill=P1, outline=OL)
    d.ellipse([16, 34, 48, 54], fill=O1, outline=OL)
    _box(d, 24, 40, 14, 6, CR, outline=False)
    for x in (18, 26, 34, 42):
        _box(d, x, 50, 4, 14, O3)
        _foot(d, x - 1, FOOT - 2)
    d.polygon([(16, 42), (4, 50), (8, 54), (18, 46)], fill=O2, outline=OL)
    d.ellipse([42, 20, 58, 36], fill=O1, outline=OL)
    _box(d, 52, 26, 3, 2, EY, outline=False)
    _box(d, 55, 28, 3, 2, OL, outline=False)
    _box(d, 46, 18, 2, 4, O1)
    return img


def draw_drake() -> Image.Image:
    """亚龙：4 腿 + 1 对翼，无手臂。"""
    img = _c()
    d = ImageDraw.Draw(img)
    d.polygon([(18, 24), (2, 6), (8, 28), (20, 34)], fill=P2, outline=OL)
    d.ellipse([12, 30, 50, 54], fill=O1, outline=OL)
    _box(d, 22, 38, 18, 8, CR, outline=False)
    d.polygon([(32, 20), (56, 2), (58, 14), (38, 30)], fill=P1, outline=OL)
    for i, x in enumerate((14, 24, 34, 44)):
        col = O3 if i % 2 == 0 else O2
        _box(d, x, 48 + (i % 2), 6, 16 - (i % 2), col)
        _foot(d, x - 1, FOOT - 1)
    d.polygon([(12, 40), (0, 54), (6, 60), (16, 46)], fill=O2, outline=OL)
    d.ellipse([42, 12, 60, 32], fill=O1, outline=OL)
    _box(d, 40, 26, 8, 8, O1)
    _box(d, 54, 18, 3, 3, EY, outline=False)
    _box(d, 57, 20, 4, 2, OL, outline=False)
    _box(d, 46, 8, 3, 6, O1)
    _box(d, 51, 7, 2, 5, O1)
    return img


def draw_adult() -> Image.Image:
    """成龙：4 粗腿 + 大翼。"""
    img = _c()
    d = ImageDraw.Draw(img)
    d.polygon([(16, 22), (0, 0), (6, 26), (18, 34)], fill=P2, outline=OL)
    d.ellipse([8, 28, 52, 58], fill=O3, outline=OL)
    d.ellipse([12, 32, 48, 54], fill=O1, outline=None)
    _box(d, 20, 40, 18, 8, CR, outline=False)
    d.polygon([(30, 16), (60, 0), (62, 12), (36, 28)], fill=P1, outline=OL)
    for i, x in enumerate((10, 22, 34, 44)):
        _box(d, x, 48 + (i % 2), 8, 16, O3)
        _foot(d, x - 1, FOOT - 1)
    d.polygon([(10, 42), (0, 58), (6, 64), (14, 48)], fill=O2, outline=OL)
    d.ellipse([44, 8, 62, 30], fill=O1, outline=OL)
    _box(d, 54, 14, 4, 3, EY, outline=False)
    _box(d, 58, 16, 5, 3, OL, outline=False)
    _box(d, 48, 4, 4, 7, O1)
    _box(d, 54, 3, 3, 6, O1)
    _box(d, 36, 34, 8, 4, (255, 140, 50, 255), outline=False)
    return img


DRAWERS = {
    "longren": draw_longren,
    "whelp": draw_whelp,
    "drake": draw_drake,
    "adult": draw_adult,
}


def to_silhouette(sprite: Image.Image, size: int = 512) -> Image.Image:
    big = sprite.resize((size, size), Image.NEAREST)
    out = Image.new("RGB", (size, size), BG)
    sp, op = big.load(), out.load()
    for y in range(size):
        for x in range(size):
            if sp[x, y][3] > 40:
                op[x, y] = SIL
    return out


def colored_preview(sprite: Image.Image, size: int = 512) -> Image.Image:
    bg = Image.new("RGBA", (size, size), BG + (255,))
    bg.alpha_composite(sprite.resize((size, size), Image.NEAREST))
    return bg.convert("RGB")


def reset_catalog(asset_id: str) -> None:
    d = _dir(asset_id)
    for name in list(os.listdir(d)):
        if name.endswith(".png") or name == "catalog.json":
            os.remove(os.path.join(d, name))
    _save_catalog(asset_id, {"asset_id": asset_id, "items": []})


def write_ship(sprites: dict) -> None:
    ship = os.path.join(ROOT, "assets", "pixels", "dragon")
    os.makedirs(ship, exist_ok=True)
    mapping = [
        ("unit_0.png", sprites["whelp"], "dragon/unit_0", "procedural whelp 4-leg"),
        ("unit_1.png", sprites["longren"], "dragon/unit_1", "procedural longren 2arm2leg"),
        ("unit_2.png", sprites["adult"], "dragon/unit_2", "procedural adult 4-leg"),
    ]
    for name, img, pid, note in mapping:
        path = os.path.join(ship, name)
        img.save(path, optimize=True)
        print("SHIP", path)
        subprocess.run(
            [
                sys.executable,
                os.path.join(os.path.dirname(__file__), "record_provenance.py"),
                "--id", pid, "--source", "procedural",
                "--tool", "tools/gen/draw_dragon_anatomy.py",
                "--commercial-ok", "--path", f"dragon/{name}", "--notes", note,
            ],
            check=False,
        )
    # 同步最简 idle：用 unit_1 填 anim，避免旧 AI 帧错位
    anim = os.path.join(ship, "unit_1_anim")
    os.makedirs(anim, exist_ok=True)
    base = sprites["longren"]
    for name in ("idle_0.png", "idle_1.png"):
        base.save(os.path.join(anim, name), optimize=True)
    # 轻微下移作 walk 占位
    for i, dy in enumerate((0, 1, 0, 1)):
        fr = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        fr.paste(base, (0, dy), base)
        fr.save(os.path.join(anim, f"walk_{i}.png"), optimize=True)
    for i, dx in enumerate((0, 2, 0)):
        fr = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        fr.paste(base, (dx, 0), base)
        fr.save(os.path.join(anim, f"attack_{i}.png"), optimize=True)
    print("SHIP anim placeholders ->", anim)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ship", action="store_true")
    ap.add_argument("--keep-catalog", action="store_true")
    args = ap.parse_args()

    tmpl = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "templates")
    os.makedirs(tmpl, exist_ok=True)
    sprites = {k: fn() for k, fn in DRAWERS.items()}

    for key, sprite in sprites.items():
        sil = to_silhouette(sprite)
        prev = colored_preview(sprite)
        sil.save(os.path.join(tmpl, f"{key}_sil.png"))
        prev.save(os.path.join(tmpl, f"{key}_preview.png"))
        sprite.save(os.path.join(tmpl, f"{key}_game.png"))
        print("template", key)

        asset_id = f"dragon/{key}"
        if not args.keep_catalog:
            # 保留已有 sil_i2i 候选：只在空目录时 reset；有文件则追加 procedural 为新号
            existing = [f for f in os.listdir(_dir(asset_id)) if f.endswith("_game.png")]
            if not existing:
                reset_catalog(asset_id)
        archive_pair(
            asset_id,
            os.path.join(tmpl, f"{key}_preview.png"),
            os.path.join(tmpl, f"{key}_game.png"),
            note="procedural_anatomy_v2",
            source="draw_dragon_anatomy",
            prompt="procedural guaranteed limbs v2",
        )

    with open(os.path.join(tmpl, "README.md"), "w", encoding="utf-8") as f:
        f.write(
            "# 龙族剪影范本\n\n"
            "| 文件 | 体态 |\n|------|------|\n"
            "| longren_sil | 2臂2腿+翼 |\n| whelp_sil | 4短腿+小翼 |\n"
            "| drake_sil | 4腿+翼无手臂 |\n| adult_sil | 4粗腿+大翼 |\n\n"
            "出图: `python tools/gen/gen_from_silhouette.py --class longren`\n"
            "保肢重绘: `python tools/gen/draw_dragon_anatomy.py --ship`\n"
        )

    picks = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "picks")
    os.makedirs(picks, exist_ok=True)
    sprites["drake"].save(os.path.join(picks, "procedural_drake_game.png"))

    if args.ship:
        write_ship(sprites)
    print("DONE")


if __name__ == "__main__":
    main()
