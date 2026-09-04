"""FAIL rollback: restore dream unit_14-17 from approved; kill shredded anim.
Anim clips temporarily = readable stills (1px nudge only). NOT art-pass for motion.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
from PIL import Image
from pixelize import remove_bg

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHIP = os.path.join(ROOT, "assets", "pixels", "dragon")
DREAM = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "dream")
CW, CH = 96, 108
FOOT = int(CH * 0.92)
FOG = [
    (166, 160, 203), (165, 159, 202), (156, 163, 183),
    (140, 135, 175), (120, 115, 155), (99, 85, 162), (180, 175, 210),
]


def clean_fog(im: Image.Image, tol: int = 75) -> Image.Image:
    im = im.convert("RGBA")
    for k in FOG:
        im = remove_bg(im, k, tol=tol)
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0 and r + g + b < 16:
                px[x, y] = (0, 0, 0, 0)
    return im


def bbox(im: Image.Image):
    px = im.load()
    w, h = im.size
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 50 and r + g + b > 50:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def fit(im: Image.Image, scale: float) -> Image.Image:
    im = clean_fog(im)
    bb = bbox(im)
    if not bb:
        raise RuntimeError("empty after clean")
    crop = im.crop(bb)
    th = max(12, int(100 * scale))
    tw = max(12, int(crop.size[0] * (th / float(crop.size[1]))))
    if tw > CW - 4:
        tw = CW - 4
        th = max(12, int(crop.size[1] * (tw / float(crop.size[0]))))
    r = crop.resize((tw, th), Image.NEAREST)
    c = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    c.alpha_composite(r, ((CW - tw) // 2, max(2, FOOT - th)))
    return clean_fog(c, tol=60)


def nudge(im: Image.Image, dx: int, dy: int) -> Image.Image:
    c = Image.new("RGBA", im.size, (0, 0, 0, 0))
    c.alpha_composite(im, (dx, dy))
    return c


def write_static_anim(uid: int, base_im: Image.Image) -> str:
    out = os.path.join(SHIP, "unit_%d_anim" % uid)
    if os.path.isdir(out):
        for n in os.listdir(out):
            if n.endswith(".png"):
                os.remove(os.path.join(out, n))
    else:
        os.makedirs(out, exist_ok=True)
    clips = {
        "idle": [base_im, nudge(base_im, 0, -1)],
        "walk": [nudge(base_im, -1, 0), base_im, nudge(base_im, 1, 0), base_im],
        "fly": [nudge(base_im, 0, -1), nudge(base_im, 0, -2), nudge(base_im, 0, -1), base_im],
        "attack": [nudge(base_im, -1, 0), nudge(base_im, 1, -1), base_im],
        "death": [base_im, nudge(base_im, 0, 1), nudge(base_im, 0, 2)],
    }
    for anim, frames in clips.items():
        for i, fr in enumerate(frames):
            fr.save(os.path.join(out, "%s_%d.png" % (anim, i)))
    return out


def main() -> None:
    srcs = {
        14: (os.path.join(DREAM, "whelp", "approved", "006_game.png"), 0.50),
        15: (os.path.join(DREAM, "drake", "approved", "003_game.png"), 0.68),
        16: (os.path.join(DREAM, "approved", "042_game.png"), 0.82),
        17: (os.path.join(DREAM, "approved", "042_game.png"), 1.00),
    }
    for uid, (path, sc) in srcs.items():
        fr = fit(Image.open(path), sc)
        nt = sum(1 for p in fr.getdata() if p[3] > 50)
        print("restore", uid, "opaque", nt)
        if nt < 300:
            raise SystemExit("restore too empty %d" % uid)
        fr.save(os.path.join(SHIP, "unit_%d.png" % uid))
        write_static_anim(uid, fr)
        print("  static placeholder anim (readable; motion FAIL)")
    # quarantine note on broken generator
    ban = os.path.join(os.path.dirname(__file__), "gen_unit_action_frames.FAIL.txt")
    with open(ban, "w", encoding="utf-8") as f:
        f.write(
            "FAIL 2026-09-03: band-split pose generator shredded silhouettes.\n"
            "Do not ship its output. Rebuild anim via Comfy pose sheets or hand frames.\n"
        )
    print("DONE")


if __name__ == "__main__":
    main()
