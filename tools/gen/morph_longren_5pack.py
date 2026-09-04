"""从 pick_004 保龙人身份，五亚种：只做色板 + 体型缩放。

禁止用 rectangle/polygon「补丁」画角尾——那会在身上留下不明色块。
角/尾差异留给正式出图或手工改；本脚本保证：无脏块、体型可分、色板可分。

  python tools/gen/morph_longren_5pack.py --preview
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from archive_candidates import archive_pair  # noqa: E402
from recolor_longren_structure import recolor  # noqa: E402

SRC_GAME = os.path.join(
    ROOT, "assets", "pixels", "_studio", "dragon", "picks", "pick_004_flame_drake_game.png"
)
SRC_RAW = os.path.join(
    ROOT, "assets", "pixels", "_studio", "dragon", "picks", "pick_004_flame_drake_raw.png"
)

# id → (recolor mode, width_scale, height_scale, contrast)
# 体型差只靠整体缩放，不贴几何补丁
BODY = {
    "magma": ("fire", 1.00, 1.00, 1.40),   # 焰鳞：基准厚重
    "frost": ("ice", 0.82, 1.08, 1.45),    # 霜棱：瘦高
    "storm": ("storm", 0.88, 1.04, 1.50),  # 雷冠：偏瘦
    "stone": ("stone", 1.16, 0.90, 1.35),  # 岩夯：矮阔
    "jade": ("jade", 0.78, 1.12, 1.42),    # 碧枝：更瘦更高
}


def _bbox(im: Image.Image) -> tuple[int, int, int, int]:
    return im.split()[-1].getbbox() or (0, 0, im.width, im.height)


def reshape(im: Image.Image, w_scale: float, h_scale: float) -> Image.Image:
    """按包围盒缩放主体，居中贴回原画布。不绘制任何额外几何。"""
    x0, y0, x1, y1 = _bbox(im)
    crop = im.crop((x0, y0, x1, y1))
    nw = max(8, int(crop.width * w_scale))
    nh = max(8, int(crop.height * h_scale))
    scaled = crop.resize((nw, nh), Image.NEAREST)
    canvas = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ox = max(0, min(im.width - nw, x0 + (crop.width - nw) // 2))
    oy = max(0, min(im.height - nh, y0 + (crop.height - nh) // 2))
    # 矮化时略下沉贴地；拔高时略上移留角空间
    if h_scale < 1.0:
        oy = min(im.height - nh, oy + int((crop.height - nh) * 0.35))
    elif h_scale > 1.0:
        oy = max(0, oy - int((nh - crop.height) * 0.25))
    canvas.paste(scaled, (ox, oy), scaled)
    return canvas


def morph(src: Image.Image, species: str) -> Image.Image:
    mode, ws, hs, contrast = BODY[species]
    out = recolor(src, mode, contrast=contrast)
    if ws != 1.0 or hs != 1.0:
        out = reshape(out, ws, hs)
    return out


def _write_species_seed(species: str, tag: str, game: Image.Image, raw: Image.Image) -> None:
    """同步写入 longren/{id}/candidates + picks（干净版覆盖 WIP）。"""
    base = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "longren", species)
    cand = os.path.join(base, "candidates")
    picks = os.path.join(base, "picks")
    os.makedirs(cand, exist_ok=True)
    os.makedirs(picks, exist_ok=True)
    # 新编号进 candidates
    with tempfile.TemporaryDirectory() as td:
        rp = os.path.join(td, "raw.png")
        gp = os.path.join(td, "game.png")
        raw.save(rp)
        game.save(gp)
        entry = archive_pair(
            f"dragon/longren/{species}/candidates",
            rp,
            gp,
            note=f"clean_recolor_reshape_{species}_no_overlay",
            source="morph_longren_5pack",
            prompt="no rectangle overlays; body scale + palette only",
        )
    # 刷新 picks 展示用（固定文件名）
    names = {
        "magma": "yanlin",
        "frost": "shuangling",
        "storm": "leiguan",
        "stone": "yanhang",
        "jade": "bizhi",
    }
    nm = names[species]
    game.save(os.path.join(picks, f"pick_{species}_{nm}_game.png"))
    raw.save(os.path.join(picks, f"pick_{species}_{nm}_raw.png"))
    game.resize((game.width * 4, game.height * 4), Image.NEAREST).save(
        os.path.join(picks, f"pick_{species}_{nm}_preview4x.png")
    )
    print(species, "->", entry["tag"], "picks refreshed")
    return entry


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--modes", default="magma,frost,storm,stone,jade")
    args = ap.parse_args()
    if not os.path.isfile(SRC_GAME):
        raise SystemExit(f"missing {SRC_GAME}")

    modes = [m.strip() for m in args.modes.split(",") if m.strip()]
    for m in modes:
        if m not in BODY:
            raise SystemExit(f"unknown {m}; {tuple(BODY)}")

    src_g = Image.open(SRC_GAME).convert("RGBA")
    src_r = Image.open(SRC_RAW).convert("RGBA") if os.path.isfile(SRC_RAW) else None
    results: list[tuple[str, Image.Image]] = []

    for species in modes:
        game = morph(src_g, species)
        raw = morph(src_r, species) if src_r is not None else game.resize(
            (game.width * 4, game.height * 4), Image.NEAREST
        )
        _write_species_seed(species, "", game, raw)
        results.append((species, game))
        # studio picks 对照（干净）
        picks_dir = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "picks")
        game.save(os.path.join(picks_dir, f"_clean_{species}_game.png"))
        raw.save(os.path.join(picks_dir, f"_clean_{species}_raw.png"))

    # contact sheet
    picks = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "picks")
    cells = [("004", Image.open(SRC_GAME).convert("RGBA"))]
    for sp, im in results:
        cells.append((sp, im))
    scale = 4
    cw = max(i.width for _, i in cells) * scale
    ch = max(i.height for _, i in cells) * scale
    pad, gap, lh = 14, 10, 26
    sheet = Image.new(
        "RGB",
        (pad * 2 + len(cells) * cw + (len(cells) - 1) * gap, pad * 2 + ch + lh),
        (12, 12, 16),
    )
    dr = ImageDraw.Draw(sheet)
    for i, (lab, im) in enumerate(cells):
        big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        x = pad + i * (cw + gap)
        sheet.paste(big, (x + (cw - big.width) // 2, pad + (ch - big.height) // 2), big)
        dr.text((x, pad + ch + 4), lab, fill=(220, 200, 160))
    out = os.path.join(picks, "_preview_longren_5_clean.png")
    sheet.save(out)
    print("preview", out)

    # deprecate note on dirty cand files
    note = os.path.join(picks, "_DIRTY_OVERLAY_FAIL.md")
    with open(note, "w", encoding="utf-8") as f:
        f.write(
            "# 脏块废图说明\n\n"
            "`_cand_096/097/098_*` 以及带 morph 矩形补丁的图 = **FAIL**。\n"
            "原因：`morph_longren_5pack` 旧版用 rectangle 硬画角/尾，留在角色上像不明色块。\n"
            "以 `_clean_{species}_*` 与各亚种 `picks/pick_*` 为准。\n"
        )
    if args.preview:
        os.startfile(out)  # type: ignore[attr-defined]


if __name__ == "__main__":
    main()
