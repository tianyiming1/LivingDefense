"""保结构重上色：以 pick_004 像素明暗/分区为底，铺火红或冰蓝白多档色。

create-game-assets：真像素定稿靠保留晶体明暗结构，禁止整图 Hue/纯白抹平。

  python tools/gen/recolor_longren_structure.py
  python tools/gen/recolor_longren_structure.py --src assets/pixels/_studio/dragon/picks/pick_004_flame_drake_game.png
"""
from __future__ import annotations

import argparse
import os
import sys
import tempfile

from PIL import Image, ImageDraw, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from archive_candidates import archive_pair  # noqa: E402

DEFAULT_GAME = os.path.join(
    ROOT, "assets", "pixels", "_studio", "dragon", "picks", "pick_004_flame_drake_game.png"
)
DEFAULT_RAW = os.path.join(
    ROOT, "assets", "pixels", "_studio", "dragon", "picks", "pick_004_flame_drake_raw.png"
)

# 火：红系体表 6 档 + 紫系辅色 4 档
FIRE_BODY = [
    (72, 8, 14),
    (120, 16, 22),
    (168, 28, 32),
    (210, 42, 38),
    (235, 70, 48),
    (255, 120, 72),
]
FIRE_MEM = [
    (28, 10, 36),
    (48, 18, 58),
    (78, 32, 88),
    (110, 50, 115),
]
FIRE_EYE = (255, 236, 110)

# 冰：蓝白打底 6 档（最高也带蓝）+ 深蓝辅色
ICE_BODY = [
    (58, 82, 118),     # 钢蓝最暗（块鳞凹）
    (92, 122, 158),
    (130, 162, 192),
    (168, 198, 220),   # 冰蓝中
    (200, 222, 238),
    (228, 240, 248),   # 霜白高光 — 禁止 255,255,255
]
ICE_MEM = [
    (16, 28, 58),
    (28, 44, 88),
    (42, 66, 118),
    (70, 100, 150),
]
ICE_EYE = (160, 240, 255)

# 雷：炭金晶体（体暗 + 硫金高光）
STORM_BODY = [
    (18, 16, 14),
    (36, 32, 26),
    (58, 50, 38),
    (92, 78, 48),
    (170, 140, 55),
    (220, 190, 90),
]
STORM_MEM = [
    (10, 12, 22),
    (18, 22, 38),
    (28, 34, 55),
    (48, 56, 80),
]
STORM_EYE = (255, 245, 170)

# 岩：砂岩褐
STONE_BODY = [
    (42, 28, 16),
    (72, 50, 28),
    (110, 78, 44),
    (148, 112, 68),
    (180, 148, 96),
    (210, 180, 130),
]
STONE_MEM = [
    (28, 18, 12),
    (44, 30, 18),
    (62, 44, 28),
    (88, 64, 42),
]
STONE_EYE = (240, 200, 110)

# 碧：玉绿（避开菌亮绿）
JADE_BODY = [
    (12, 40, 32),
    (18, 68, 52),
    (28, 102, 78),
    (48, 138, 108),
    (90, 170, 140),
    (140, 200, 170),
]
JADE_MEM = [
    (10, 22, 18),
    (16, 34, 26),
    (24, 48, 36),
    (40, 70, 52),
]
JADE_EYE = (200, 255, 220)

PALETTES = {
    "fire": (FIRE_BODY, FIRE_MEM, FIRE_EYE, (18, 6, 8)),
    "ice": (ICE_BODY, ICE_MEM, ICE_EYE, (14, 22, 40)),
    "storm": (STORM_BODY, STORM_MEM, STORM_EYE, (8, 8, 10)),
    "stone": (STONE_BODY, STONE_MEM, STONE_EYE, (22, 14, 8)),
    "jade": (JADE_BODY, JADE_MEM, JADE_EYE, (8, 24, 18)),
}


def _luma(r: int, g: int, b: int) -> float:
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _is_bg(a: int, r: int, g: int, b: int) -> bool:
    return a < 18 or (r + g + b) < 16


def _role(r: int, g: int, b: int) -> str:
    """warm=熔岩体表；mem=腹/翅膜/爪紫系；shadow=近黑描边。"""
    L = _luma(r, g, b)
    if L < 26:
        return "shadow"
    mx = max(r, g, b)
    mn = min(r, g, b)
    sat = 0.0 if mx == 0 else (mx - mn) / mx
    # HSV 粗算 hue（度）
    if mx == mn:
        hue = 0.0
    elif mx == r:
        hue = (60 * ((g - b) / (mx - mn)) + 360) % 360
    elif mx == g:
        hue = 60 * ((b - r) / (mx - mn)) + 120
    else:
        hue = 60 * ((r - g) / (mx - mn)) + 240
    # 紫/品红/靛膜：hue 靠近红紫或蓝紫，且不太亮
    if sat > 0.12 and L < 155 and (
        hue >= 250 or hue <= 20 and b > g + 5 and r < 160
        or (b > r + 3 and b > g and r < 130)
        or (r > 40 and b > 40 and g < min(r, b) * 0.85 and L < 130)
    ):
        return "mem"
    # 暖熔岩体表
    if hue <= 55 or hue >= 340:
        if r >= g and r >= b * 0.9:
            return "warm"
    if r > g + 6 and r > b + 4:
        return "warm"
    if L < 50:
        return "shadow"
    # 暗部褐紫偏膜
    if b + 8 >= r and g < r:
        return "mem"
    return "warm"


def _sample_ramp(ramp: list[tuple[int, int, int]], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    if len(ramp) == 1:
        return ramp[0]
    f = t * (len(ramp) - 1)
    i = int(f)
    if i >= len(ramp) - 1:
        return ramp[-1]
    u = f - i
    a, b = ramp[i], ramp[i + 1]
    return tuple(int(a[k] * (1 - u) + b[k] * u) for k in range(3))


def _percentile_map(values: list[float]) -> tuple[float, float]:
    if not values:
        return 40.0, 200.0
    vs = sorted(values)
    lo = vs[max(0, int(len(vs) * 0.08))]
    hi = vs[min(len(vs) - 1, int(len(vs) * 0.92))]
    if hi - lo < 20:
        hi = lo + 20
    return lo, hi


def recolor(im: Image.Image, mode: str, contrast: float = 1.35) -> Image.Image:
    """先略提对比保住晶体棱，再按角色分区映射到多档色板。"""
    im = im.convert("RGBA")
    # 只对 RGB 提对比，保留 alpha
    rgb = im.convert("RGB")
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    base = Image.merge("RGBA", (*rgb.split(), im.split()[-1]))
    px = base.load()
    w, h = base.size

    warm_L: list[float] = []
    mem_L: list[float] = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if _is_bg(a, r, g, b):
                continue
            role = _role(r, g, b)
            L = _luma(r, g, b)
            if role == "warm":
                warm_L.append(L)
            elif role == "mem":
                mem_L.append(L)

    w_lo, w_hi = _percentile_map(warm_L)
    m_lo, m_hi = _percentile_map(mem_L)

    if mode not in PALETTES:
        raise ValueError(f"unknown recolor mode {mode}; choose {tuple(PALETTES)}")
    body, mem, eye, ol = PALETTES[mode]

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if _is_bg(a, r, g, b):
                op[x, y] = (0, 0, 0, 0) if a < 18 else (0, 0, 0, a)
                continue
            role = _role(r, g, b)
            L = _luma(r, g, b)
            if role == "shadow":
                op[x, y] = (*ol, a)
            elif role == "mem":
                t = (L - m_lo) / (m_hi - m_lo)
                t = max(0.0, min(1.0, t))
                op[x, y] = (*_sample_ramp(mem, t), a)
            else:
                t = (L - w_lo) / (w_hi - w_lo)
                t = max(0.0, min(1.0, t))
                # 略压高光：冰不冲顶，火也不洗白
                t = t ** 0.92
                if mode in ("ice", "jade"):
                    t = min(t, 0.97)
                if mode == "storm":
                    # 压暗体、抬高光 → 炭金闪
                    t = (t ** 1.15) * 0.85 + (t ** 0.5) * 0.15
                op[x, y] = (*_sample_ramp(body, t), a)

    # 眼睛：在头部区域找原高亮点强化
    _boost_eyes(out, mode)
    return out


def _boost_eyes(im: Image.Image, mode: str) -> None:
    """统一水平亮缝（禁止最亮像素糊成假眼）。"""
    from fix_longren_eyes import paint_eye_slit

    eye_mode = {
        "fire": "fire",
        "ice": "ice",
        "storm": "fire",
        "stone": "fire",
        "jade": "ice",
    }.get(mode, "fire")
    paint_eye_slit(im, eye_mode)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=DEFAULT_GAME, help="game-size source (default pick_004 game)")
    ap.add_argument("--raw", default=DEFAULT_RAW)
    ap.add_argument("--modes", default="fire,ice")
    ap.add_argument("--contrast", type=float, default=1.4)
    ap.add_argument("--preview", action="store_true")
    args = ap.parse_args()

    if not os.path.isfile(args.src):
        raise SystemExit(f"missing {args.src}")

    picks = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "picks")
    os.makedirs(picks, exist_ok=True)
    results: list[tuple[str, str, Image.Image]] = []

    src_game = Image.open(args.src)
    for mode in [m.strip() for m in args.modes.split(",") if m.strip()]:
        game = recolor(src_game, mode, contrast=args.contrast)
        raw_img = game
        if os.path.isfile(args.raw):
            raw_img = recolor(Image.open(args.raw), mode, contrast=args.contrast)
        with tempfile.TemporaryDirectory() as td:
            raw_p = os.path.join(td, f"{mode}_raw.png")
            game_p = os.path.join(td, f"{mode}_game.png")
            raw_img.save(raw_p)
            game.save(game_p)
            note = f"structure_recolor_{mode}_multitone"
            entry = archive_pair(
                "dragon/longren",
                raw_p,
                game_p,
                note=note,
                source="recolor_longren_structure",
            )
            results.append((mode, entry["tag"], game))
            print(mode, "->", entry["tag"], note)

    # preview: 004 | fire | ice | 060 fail remap
    cells: list[tuple[str, Image.Image]] = [
        ("004 anchor", Image.open(DEFAULT_GAME).convert("RGBA")),
    ]
    for mode, tag, im in results:
        cells.append((f"{tag} {mode}", im.convert("RGBA")))
    fail060 = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "longren", "060_game.png")
    if os.path.isfile(fail060):
        cells.append(("060 flat FAIL", Image.open(fail060).convert("RGBA")))

    scale = 4
    cw = max(im.width for _, im in cells) * scale
    ch = max(im.height for _, im in cells) * scale
    pad, gap, lh = 16, 12, 28
    sheet = Image.new("RGB", (pad * 2 + len(cells) * cw + (len(cells) - 1) * gap, pad * 2 + ch + lh), (12, 12, 16))
    dr = ImageDraw.Draw(sheet)
    for i, (lab, im) in enumerate(cells):
        big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        x = pad + i * (cw + gap)
        sheet.paste(big, (x + (cw - big.width) // 2, pad + (ch - big.height) // 2), big)
        dr.text((x, pad + ch + 4), lab, fill=(220, 200, 160))
    out = os.path.join(picks, "_preview_structure_fire_ice.png")
    sheet.save(out)
    print("preview", out)
    if args.preview:
        os.startfile(out)  # type: ignore[attr-defined]


if __name__ == "__main__":
    main()
