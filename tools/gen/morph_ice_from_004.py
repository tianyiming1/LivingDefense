"""从 pick_004 做「冰长相」：先保结构冰蓝白上色，再改剪影（角/体瘦/冰锥尾/翼齿）。

火龙人定稿仍用 004/#065；冰必须剪影可分，不能只换色。

  python tools/gen/morph_ice_from_004.py --preview
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
from recolor_longren_structure import recolor  # noqa: E402

SRC = os.path.join(
    ROOT, "assets", "pixels", "_studio", "dragon", "picks", "pick_004_flame_drake_game.png"
)
SRC_RAW = os.path.join(
    ROOT, "assets", "pixels", "_studio", "dragon", "picks", "pick_004_flame_drake_raw.png"
)

ICE_HI = (228, 240, 248, 255)
ICE_MID = (168, 198, 220, 255)
ICE_LO = (88, 120, 158, 255)
ICE_NAVY = (22, 36, 78, 255)
ICE_EYE = (160, 240, 255, 255)
OL = (14, 22, 40, 255)


def _bbox(im: Image.Image) -> tuple[int, int, int, int]:
    a = im.split()[-1]
    return a.getbbox() or (0, 0, im.width, im.height)


def lean_body(im: Image.Image, factor: float = 0.86) -> Image.Image:
    """水平压瘦，增高一点，形成更削的冰剪影。"""
    x0, y0, x1, y1 = _bbox(im)
    crop = im.crop((x0, y0, x1, y1))
    nw = max(8, int(crop.width * factor))
    nh = max(8, int(crop.height * 1.06))
    slim = crop.resize((nw, nh), Image.NEAREST)
    canvas = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ox = x0 + (crop.width - nw) // 2
    oy = max(0, y0 - (nh - crop.height) // 2)
    canvas.paste(slim, (ox, oy), slim)
    return canvas


def paint_ice_horns(im: Image.Image) -> None:
    """直冰棱角（盖住原焰形弯角区域）。"""
    d = ImageDraw.Draw(im)
    w, h = im.size
    # 头区大致在上 12%–38%
    base_y = int(h * 0.14)
    # 左中右三柱冰棱
    spikes = [
        (int(w * 0.52), base_y, 3, int(h * 0.16)),
        (int(w * 0.58), base_y - 2, 4, int(h * 0.20)),
        (int(w * 0.66), base_y, 3, int(h * 0.17)),
        (int(w * 0.72), base_y + 1, 3, int(h * 0.14)),
    ]
    for x, y, bw, bh in spikes:
        d.rectangle([x, y, x + bw - 1, y + bh - 1], fill=ICE_HI)
        d.rectangle([x, y, x, y + bh - 1], fill=OL)
        d.rectangle([x + bw - 1, y, x + bw - 1, y + bh - 1], fill=ICE_LO)
        # 尖顶
        d.rectangle([x, y - 2, x + bw - 1, y - 1], fill=ICE_MID)
        d.point((x + bw // 2, y - 3), fill=ICE_HI)


def paint_icicle_tail(im: Image.Image) -> None:
    """左下改为冰锥串刺尾。"""
    d = ImageDraw.Draw(im)
    w, h = im.size
    # 清掉原尾左下一块再画锥
    x0, y0 = int(w * 0.02), int(h * 0.55)
    x1, y1 = int(w * 0.32), int(h * 0.98)
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = im.getpixel((x, y))
            if a > 20:
                im.putpixel((x, y), (0, 0, 0, 0))
    # 尾根连向髋
    hx, hy = int(w * 0.30), int(h * 0.62)
    d.polygon(
        [(hx, hy), (hx - 6, hy + 8), (int(w * 0.18), int(h * 0.78)), (hx - 2, hy + 4)],
        fill=ICE_MID,
        outline=OL,
    )
    # 一串尖锥
    cones = [
        (int(w * 0.20), int(h * 0.72), 5, 14),
        (int(w * 0.14), int(h * 0.78), 4, 16),
        (int(w * 0.08), int(h * 0.84), 4, 14),
        (int(w * 0.16), int(h * 0.86), 3, 12),
        (int(w * 0.10), int(h * 0.90), 3, 10),
    ]
    for x, y, bw, bh in cones:
        d.polygon(
            [(x, y + bh), (x + bw // 2, y), (x + bw, y + bh)],
            fill=ICE_HI,
            outline=OL,
        )
        d.line([(x + bw // 2, y), (x + bw // 2, y + bh - 2)], fill=ICE_LO)


def paint_wing_frost_teeth(im: Image.Image) -> None:
    d = ImageDraw.Draw(im)
    w, h = im.size
    teeth = [
        (int(w * 0.04), int(h * 0.18)),
        (int(w * 0.02), int(h * 0.28)),
        (int(w * 0.06), int(h * 0.36)),
        (int(w * 0.90), int(h * 0.08)),
        (int(w * 0.94), int(h * 0.16)),
        (int(w * 0.92), int(h * 0.26)),
        (int(w * 0.88), int(h * 0.34)),
    ]
    for x, y in teeth:
        d.polygon([(x, y + 5), (x + 2, y), (x + 4, y + 5)], fill=ICE_HI, outline=OL)


def boost_eye(im: Image.Image) -> None:
    from fix_longren_eyes import paint_eye_slit

    paint_eye_slit(im, "ice")


def morph_ice(src: Image.Image) -> Image.Image:
    iced = recolor(src, "ice", contrast=1.45)
    iced = lean_body(iced, 0.84)
    paint_ice_horns(iced)
    paint_icicle_tail(iced)
    paint_wing_frost_teeth(iced)
    boost_eye(iced)
    return iced


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    args = ap.parse_args()
    if not os.path.isfile(SRC):
        raise SystemExit(f"missing {SRC}")

    game = morph_ice(Image.open(SRC))
    raw = morph_ice(Image.open(SRC_RAW)) if os.path.isfile(SRC_RAW) else game.resize(
        (game.width * 4, game.height * 4), Image.NEAREST
    )

    with tempfile.TemporaryDirectory() as td:
        raw_p = os.path.join(td, "ice_raw.png")
        game_p = os.path.join(td, "ice_game.png")
        raw.save(raw_p)
        game.save(game_p)
        entry = archive_pair(
            "dragon/longren",
            raw_p,
            game_p,
            note="morph_ice_shape_from_004",
            source="morph_ice_from_004",
        )
        print("ice ->", entry["tag"], "morph_ice_shape_from_004")

    picks = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "picks")
    paths = [
        (SRC, "004 fire shape"),
        (os.path.join(ROOT, "assets/pixels/_studio/dragon/longren/065_game.png"), "065 fire color"),
        (os.path.join(ROOT, f"assets/pixels/_studio/dragon/longren/{entry['tag']}_game.png"), f"{entry['tag']} ice SHAPE"),
    ]
    cells = []
    for p, lab in paths:
        if os.path.isfile(p):
            im = Image.open(p).convert("RGBA")
            cells.append((lab, im.resize((im.width * 4, im.height * 4), Image.NEAREST)))
    pad, gap, lh = 16, 12, 28
    cw = max(i.width for _, i in cells)
    ch = max(i.height for _, i in cells)
    sheet = Image.new(
        "RGB",
        (pad * 2 + len(cells) * cw + (len(cells) - 1) * gap, pad * 2 + ch + lh),
        (12, 12, 16),
    )
    dr = ImageDraw.Draw(sheet)
    for i, (lab, im) in enumerate(cells):
        x = pad + i * (cw + gap)
        sheet.paste(im, (x + (cw - im.width) // 2, pad + (ch - im.height) // 2), im)
        dr.text((x, pad + ch + 4), lab, fill=(220, 200, 160))
    out = os.path.join(picks, "_preview_shape_fire_vs_ice.png")
    sheet.save(out)
    print("preview", out)
    if args.preview:
        os.startfile(out)  # type: ignore[attr-defined]


if __name__ == "__main__":
    main()
