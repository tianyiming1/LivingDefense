"""像素化转制：概念图 -> 64x64 游戏 sprite（色板量化 + 最近邻缩放 + 去底）"""
import argparse
import os
from PIL import Image, ImageDraw

PALETTES = {
    "human": [
        (107, 130, 184), (77, 106, 168), (255, 220, 80),
        (200, 200, 210), (60, 50, 40), (30, 30, 40),
        (140, 160, 200), (217, 217, 242),
    ],
    "fungus": [
        (138, 92, 191), (111, 191, 74), (60, 140, 40),
        (40, 80, 20), (64, 89, 38), (30, 30, 30),
    ],
    "dragon": [
        (216, 87, 42), (232, 161, 60), (180, 50, 20),
        (255, 200, 100), (40, 20, 10), (120, 30, 15),
    ],
    "silicon": [
        (111, 211, 231), (245, 249, 255), (80, 180, 200),
        (40, 100, 120), (20, 40, 60), (160, 220, 240),
    ],
    "enemy": [
        (191, 74, 47), (58, 143, 198), (110, 90, 115),
        (60, 40, 30), (200, 200, 200), (40, 30, 25),
    ],
    "ui": [
        (92, 72, 48), (58, 48, 38), (140, 110, 70),
        (180, 160, 110), (40, 36, 30), (200, 175, 80),
        (70, 90, 55), (160, 60, 50), (120, 100, 80),
    ],
}

BG_KEYS = {
    "human": (26, 58, 26),
    "fungus": (20, 40, 15),
    "dragon": (30, 15, 10),
    "silicon": (15, 30, 40),
    "enemy": (30, 20, 20),
    "ui": (0, 0, 0),
}


def _nearest_color(rgb, palette):
    r, g, b = rgb[:3]
    best, best_d = palette[0], 1e9
    for pr, pg, pb in palette:
        d = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2
        if d < best_d:
            best_d = d
            best = (pr, pg, pb)
    return best


def quantize(img, palette):
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            px[x, y] = _nearest_color(px[x, y], palette) + (px[x, y][3],)
    return img


def remove_bg(img, bg_rgb, tol=55):
    px = img.load()
    w, h = img.size
    br, bg, bb = bg_rgb
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if abs(r - br) + abs(g - bg) + abs(b - bb) < tol:
                px[x, y] = (r, g, b, 0)
    return img


def add_outline(img, color=(0, 0, 0)):
    src = img.load()
    w, h = img.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] < 20:
                continue
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] < 20:
                    opx[nx, ny] = color + (200,)
    out = Image.alpha_composite(out, img)
    return out


def crop_subject(src, frac=0.62, top_frac=0.14):
    w, h = src.size
    side = int(min(w, h) * frac)
    left = (w - side) // 2
    top = max(0, (h - side) // 2 - int(h * (0.5 - top_frac)))
    return src.crop((left, top, left + side, top + side))


def crop_full_body(im, bg_rgb, tol=110, pad_frac=0.12):
    """按非背景像素包围盒裁全身（带边距），避免把头像裁成半身。"""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    br, bg, bb = bg_rgb
    min_x, min_y, max_x, max_y = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 20:
                continue
            if abs(r - br) + abs(g - bg) + abs(b - bb) < tol:
                continue
            if x < min_x:
                min_x = x
            if y < min_y:
                min_y = y
            if x > max_x:
                max_x = x
            if y > max_y:
                max_y = y
    if max_x < 0:
        return crop_subject(im.convert("RGB"), 0.85, 0.45).convert("RGBA")
    bw = max_x - min_x + 1
    bh = max_y - min_y + 1
    pad = int(max(bw, bh) * pad_frac)
    # 正方形框包住全身，略偏下以保留脚
    side = max(bw, bh) + pad * 2
    cx = (min_x + max_x) // 2
    cy = (min_y + max_y) // 2 + bh // 10
    left = max(0, min(w - side, cx - side // 2))
    top = max(0, min(h - side, cy - side // 2))
    if side > w or side > h:
        side = min(w, h)
        left = max(0, (w - side) // 2)
        top = max(0, (h - side) // 2)
    return im.crop((left, top, left + side, top + side))


def detect_bg_rgb(im):
    """从四角采样背景色（AI 出图常用纯色底）。"""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    pts = [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)]
    rs = gs = bs = 0
    for x, y in pts:
        r, g, b, _a = px[x, y]
        rs += r
        gs += g
        bs += b
    n = len(pts)
    return (rs // n, gs // n, bs // n)


def pixelize(src_path, out_path, palette_name="human", size=64, outline=True, preview=4,
             bg_rgb=None, flip_x=False, out_h=None, do_quantize=True, retro=False):
    palette = PALETTES[palette_name]
    im = Image.open(src_path).convert("RGBA")
    if flip_x:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    # 必须在裁剪前采样背景：裁剪后四角常混入主体，导致去底失败、整图像「带边框照片」
    if bg_rgb is None:
        bg_key = detect_bg_rgb(im)
    else:
        bg_key = bg_rgb
    if max(im.size) > 128:
        im = crop_full_body(im, bg_key, tol=110, pad_frac=0.14)
    # retro：先大幅缩小再量化，打掉「高清伪像素」的渐变
    if retro:
        crush = max(48, size)
        im = im.resize((crush, crush), Image.NEAREST)
        im = quantize(im, palette)
        target_h = out_h if out_h else size
        im = im.resize((size, target_h), Image.NEAREST)
    else:
        mid = max(128, size * 4) if do_quantize else max(96, size * 2)
        im = im.resize((mid, mid), Image.NEAREST)
        if do_quantize:
            im = quantize(im, palette)
        target_h = out_h if out_h else size
        im = im.resize((size, target_h), Image.NEAREST)
    im = remove_bg(im, bg_key, tol=110)
    if outline:
        im = add_outline(im)
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    im.save(out_path, optimize=True)
    if preview > 1:
        big = im.resize((size * preview, target_h * preview), Image.NEAREST)
        d = ImageDraw.Draw(big)
        d.text((6, 6), "%dpx %s" % (size, palette_name), fill=(255, 255, 255, 230))
        big.save(out_path.replace(".png", "_preview4x.png"), optimize=True)
    print("DONE ->", out_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--palette", default="human", choices=list(PALETTES.keys()))
    ap.add_argument("--size", type=int, default=64)
    ap.add_argument("--no-outline", action="store_true")
    args = ap.parse_args()
    pixelize(args.src, args.out, args.palette, args.size, not args.no_outline)


if __name__ == "__main__":
    main()
