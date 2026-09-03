"""从 pick_004 raw 导入 96×108（更大分辨率保五官），并点红色龙眼。"""
from __future__ import annotations

import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from archive_candidates import archive_pair  # noqa: E402
from pixelize import add_outline, crop_full_body, detect_bg_rgb, remove_bg  # noqa: E402

RAW = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "picks", "pick_004_flame_drake_raw.png")
PICKS = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "picks")
SHIP = os.path.join(ROOT, "assets", "pixels", "dragon", "unit_1.png")

# 新规范：96×108（相对旧 64×72 的 1.5×）
W, H = 96, 108


def reimport(src: str, out: str, *, pad: float = 0.20, mid: int = 384, outline: bool = True, bg_tol: int = 95):
    im = Image.open(src).convert("RGBA")
    bg = detect_bg_rgb(im)
    im = crop_full_body(im, bg, tol=bg_tol, pad_frac=pad)
    im = im.resize((mid, mid), Image.LANCZOS)
    im = im.resize((W, H), Image.NEAREST)
    im = remove_bg(im, bg, tol=max(bg_tol, 100))
    if outline:
        im = add_outline(im)
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    im.save(out, optimize=True)
    return im


def paint_red_eye(im: Image.Image) -> Image.Image:
    """高对比红色龙眼（黑眶+亮红），适配 96×108。"""
    px = im.load()
    w, h = im.size

    def put(x, y, c):
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = c

    # 头部位于上半；按比例约在旧 27,10 → 新 ~40,15
    ex, ey = 40, 15
    BLK = (0, 0, 0, 255)
    RED = (255, 28, 28, 255)
    HOT = (255, 90, 70, 255)
    PUP = (20, 0, 5, 255)

    # 6×5 眼
    for dx in range(-1, 6):
        put(ex + dx, ey - 1, BLK)
        put(ex + dx, ey + 4, BLK)
    for dy in range(0, 4):
        put(ex - 1, ey + dy, BLK)
        put(ex + 5, ey + dy, BLK)
    for dx in range(0, 5):
        for dy in range(0, 4):
            put(ex + dx, ey + dy, RED)
    put(ex + 1, ey, HOT)
    put(ex + 2, ey, HOT)
    put(ex + 1, ey + 1, HOT)
    put(ex + 2, ey + 1, HOT)
    put(ex + 2, ey + 2, PUP)
    put(ex + 3, ey + 2, PUP)
    put(ex + 1, ey + 3, PUP)
    return im


def gray_preview(im: Image.Image, path: str, scale: int = 3):
    big = im.resize((W * scale, H * scale), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (55, 55, 62, 255))
    bg.alpha_composite(big)
    bg.convert("RGB").save(path, optimize=True)


def main():
    assert os.path.isfile(RAW), RAW
    out_c = os.path.join(PICKS, "pick_004_reimport_C_roomy.png")
    im = reimport(RAW, out_c, pad=0.22, mid=384, outline=True, bg_tol=90)
    im = paint_red_eye(im)

    game = os.path.join(PICKS, "pick_004_flame_drake_game.png")
    im.save(out_c, optimize=True)
    im.save(game, optimize=True)
    im.save(SHIP, optimize=True)
    gray_preview(im, os.path.join(PICKS, "LOOK_AT_ME_pick004.png"))
    gray_preview(im, os.path.join(PICKS, "pick_004_flame_drake_game_preview4x.png"))
    gray_preview(im, os.path.join(PICKS, "pick_004_reimport_C_roomy_preview4x.png"))

    archive_pair(
        "dragon/longren",
        RAW,
        game,
        note="reimport_96x108_C_red_eye",
        source="reimport_hires",
        prompt="pick_004 raw @96x108",
    )

    anim = os.path.join(ROOT, "assets", "pixels", "dragon", "unit_1_anim")
    os.makedirs(anim, exist_ok=True)
    for name in ("idle_0.png", "idle_1.png"):
        im.save(os.path.join(anim, name), optimize=True)
    for i in range(4):
        im.save(os.path.join(anim, f"walk_{i}.png"), optimize=True)
    for i in range(3):
        im.save(os.path.join(anim, f"attack_{i}.png"), optimize=True)

    print("DONE %dx%d" % (W, H), "->", SHIP)
    print("preview:", os.path.join(PICKS, "LOOK_AT_ME_pick004.png"))


if __name__ == "__main__":
    main()
