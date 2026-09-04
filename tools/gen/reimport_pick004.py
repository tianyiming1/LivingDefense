"""还原为干净重导入（无手动画臂/爪），同步 ship。"""
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
W, H = 96, 108


def fill_tiny(im: Image.Image) -> Image.Image:
    px = im.load()
    fixes = []
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if px[x, y][3] >= 20:
                continue
            cols = [
                px[x + dx, y + dy][:3]
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))
                if px[x + dx, y + dy][3] >= 40
            ]
            if len(cols) == 4:
                fixes.append(
                    (
                        x,
                        y,
                        (
                            sum(c[0] for c in cols) // 4,
                            sum(c[1] for c in cols) // 4,
                            sum(c[2] for c in cols) // 4,
                            255,
                        ),
                    )
                )
    for x, y, c in fixes:
        px[x, y] = c
    return im


def main():
    im = Image.open(RAW).convert("RGBA")
    bg = detect_bg_rgb(im)
    im = crop_full_body(im, bg, tol=90, pad_frac=0.22)
    im = im.resize((384, 384), Image.LANCZOS)
    im = im.resize((W, H), Image.NEAREST)
    im = remove_bg(im, bg, tol=55)
    im = fill_tiny(im)
    im = add_outline(im)

    game = os.path.join(PICKS, "pick_004_flame_drake_game.png")
    im.save(game, optimize=True)
    im.save(SHIP, optimize=True)

    big = im.resize((W * 4, H * 4), Image.NEAREST)
    bg_im = Image.new("RGBA", big.size, (200, 200, 210, 255))
    bg_im.alpha_composite(big)
    bg_im.convert("RGB").save(os.path.join(PICKS, "pick_004_flame_drake_game_preview4x.png"), optimize=True)

    anim = os.path.join(ROOT, "assets", "pixels", "dragon", "unit_1_anim")
    os.makedirs(anim, exist_ok=True)
    for name in ("idle_0.png", "idle_1.png"):
        im.save(os.path.join(anim, name), optimize=True)
    for i in range(4):
        im.save(os.path.join(anim, f"walk_{i}.png"), optimize=True)
    for i in range(3):
        im.save(os.path.join(anim, f"attack_{i}.png"), optimize=True)

    archive_pair(
        "dragon/longren",
        RAW,
        game,
        note="96x108_clean_restore_no_hand_paint",
        source="reimport_hires",
        prompt="restore clean downsample; stop boxy hand overlays",
    )

    for tmp in ("_tmp_hand_R.png", "_tmp_hand_L.png", "_tmp_clean_base.png"):
        p = os.path.join(PICKS, tmp)
        if os.path.isfile(p):
            os.remove(p)

    print("RESTORED clean", game)


if __name__ == "__main__":
    main()
