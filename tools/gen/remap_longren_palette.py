"""从 pick_004 锚点做火红 / 冰蓝白 色板重映射（保剪影与背翼）。

美术规格（directing-game-visuals + STYLE_GATE）：
  火：猩红晶体块鳞 + 深紫腹/翅膜；高光可略橙红，禁止整身黄橙。
  冰：蓝白打底（霜白高光 + 冰蓝中调 + 钢蓝暗部）+ 深蓝翅膜/腹；
      禁止一片纯白（#056 FAIL）。

用法：
  python tools/gen/remap_longren_palette.py
  python tools/gen/remap_longren_palette.py --modes ice
"""
from __future__ import annotations

import argparse
import os
import sys
import tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from archive_candidates import archive_pair  # noqa: E402
from pixelize import pixelize  # noqa: E402

DEFAULT_SRC = os.path.join(
    ROOT, "assets", "pixels", "_studio", "dragon", "picks", "pick_004_flame_drake_raw.png"
)

# —— 角色色板（96×108 可读）——
# Fire
FIRE_BODY_LO = (88, 10, 16)       # #580A10 深红暗
FIRE_BODY_MID = (196, 32, 36)     # #C42024 猩红
FIRE_BODY_HI = (255, 92, 58)      # #FF5C3A 高光（略暖，非黄）
FIRE_MEMBRANE = (42, 16, 58)      # #2A103A 深紫翅膜/腹
FIRE_CLAW = (28, 12, 40)
FIRE_EYE = (255, 230, 120)

# Ice — 蓝白打底（有层次，非纯白）
ICE_BODY_LO = (72, 102, 138)      # #48668A 钢蓝暗部（块鳞凹面）
ICE_BODY_MID = (168, 198, 220)    # #A8C6DC 冰蓝中调
ICE_BODY_HI = (230, 242, 250)     # #E6F2FA 霜白高光（仍带蓝，禁止 255,255,255）
ICE_MEMBRANE = (28, 48, 92)       # #1C305C 深蓝翅膜/腹
ICE_CLAW = (22, 36, 70)
ICE_EYE = (180, 240, 255)


def _is_bg(a: int, rgb: tuple[int, int, int]) -> bool:
    return a < 20 or (rgb[0] + rgb[1] + rgb[2]) < 18


def _classify(r: int, g: int, b: int) -> str:
    mx = max(r, g, b)
    mn = min(r, g, b)
    s = 0.0 if mx == 0 else (mx - mn) / mx
    v = mx / 255.0
    if r < 90 and b > r and g < 80 and v < 0.55:
        return "purple"
    if r < 70 and g < 70 and b < 70:
        return "shadow"
    if r > g and r > b and r > 60:
        return "warm"
    if s < 0.15 and v > 0.55:
        return "warm"
    return "other"


def _lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


def _warm_luma_t(r: int, g: int, b: int) -> float:
    """用原图亮度分出块鳞明暗，避免压成单色。"""
    return max(0.0, min(1.0, (0.35 * r + 0.45 * g + 0.20 * b) / 255.0))


def remap(im: Image.Image, mode: str) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if _is_bg(a, (r, g, b)):
                op[x, y] = (0, 0, 0, 0) if a < 20 else (0, 0, 0, a)
                continue
            role = _classify(r, g, b)
            t = _warm_luma_t(r, g, b)
            if mode == "fire":
                if role == "warm":
                    if t < 0.45:
                        c = _lerp(FIRE_BODY_LO, FIRE_BODY_MID, t / 0.45)
                    else:
                        c = _lerp(FIRE_BODY_MID, FIRE_BODY_HI, (t - 0.45) / 0.55)
                    op[x, y] = (*c, a)
                elif role == "purple":
                    op[x, y] = (*FIRE_MEMBRANE, a)
                elif role == "shadow":
                    op[x, y] = (*FIRE_CLAW, a)
                else:
                    c = _lerp(FIRE_BODY_LO, FIRE_BODY_MID, t)
                    op[x, y] = (*c, a)
            else:  # ice — 蓝白打底
                if role == "warm":
                    # 三段：暗钢蓝 → 冰蓝 → 霜白（封顶 ICE_BODY_HI，永不纯白）
                    if t < 0.40:
                        c = _lerp(ICE_BODY_LO, ICE_BODY_MID, t / 0.40)
                    else:
                        c = _lerp(ICE_BODY_MID, ICE_BODY_HI, (t - 0.40) / 0.60)
                    op[x, y] = (*c, a)
                elif role == "purple":
                    op[x, y] = (*ICE_MEMBRANE, a)
                elif role == "shadow":
                    op[x, y] = (*ICE_CLAW, a)
                else:
                    c = _lerp(ICE_BODY_LO, ICE_BODY_MID, t)
                    op[x, y] = (*c, a)
    return out


def _boost_eye(game_path: str, mode: str) -> None:
    g = Image.open(game_path).convert("RGBA")
    gp = g.load()
    w, h = g.size
    eye = (*FIRE_EYE, 255) if mode == "fire" else (*ICE_EYE, 255)
    for y in range(int(h * 0.18), int(h * 0.38)):
        xs = [x for x in range(w) if gp[x, y][3] > 200 and max(gp[x, y][:3]) > 40]
        if len(xs) < 8:
            continue
        cx = xs[len(xs) // 3]
        gp[cx, y] = eye
        if cx + 1 < w:
            gp[cx + 1, y] = eye
        if y + 1 < h:
            gp[cx, y + 1] = eye
        break
    g.save(game_path)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=DEFAULT_SRC)
    ap.add_argument("--modes", default="fire,ice")
    args = ap.parse_args()
    if not os.path.isfile(args.src):
        raise SystemExit(f"missing src: {args.src}")
    for mode in [m.strip() for m in args.modes.split(",") if m.strip()]:
        raw = remap(Image.open(args.src), mode)
        with tempfile.TemporaryDirectory() as td:
            raw_p = os.path.join(td, f"{mode}_raw.png")
            game_p = os.path.join(td, f"{mode}_game.png")
            raw.save(raw_p)
            pixelize(raw_p, game_p, "dragon", 96, True, preview=0, out_h=108, do_quantize=False)
            _boost_eye(game_p, mode)
            note = (
                "palette_remap_fire_red"
                if mode == "fire"
                else "palette_remap_ice_bluewhite_artgate"
            )
            entry = archive_pair(
                "dragon/longren",
                raw_p,
                game_p,
                note=note,
                source="palette_remap_pick004_artdir",
            )
            print(mode, "->", entry["tag"], note)


if __name__ == "__main__":
    main()
