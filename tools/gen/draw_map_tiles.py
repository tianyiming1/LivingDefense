"""生成俯视地图像素图块（32×32）+ 图集，对齐 VISUAL_DESIGN §4。"""
import os
import random
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "pixels", "map")

TILE = 32

# VISUAL_DESIGN §4
C_GRASS = (56, 102, 64)       # #386640
C_GRASS_HI = (68, 118, 76)
C_GRASS_DK = (44, 82, 52)
C_PATH = (199, 179, 128)      # #C7B380
C_PATH_DK = (140, 120, 80)
C_PATH_HI = (220, 200, 150)
C_SPAWN = (64, 191, 77)
C_GOAL = (217, 64, 64)
C_OUTLINE = (30, 30, 40)


def _px(d, x, y, c, w=1, h=1):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def _noise_dots(d, base, hi, dk, seed=0):
    rng = random.Random(seed)
    _px(d, 0, 0, base, TILE, TILE)
    for _ in range(18):
        x, y = rng.randint(0, TILE - 2), rng.randint(0, TILE - 2)
        c = hi if rng.random() > 0.5 else dk
        _px(d, x, y, c, 2, 2)


def tile_grass(variant: int) -> Image.Image:
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bases = [C_GRASS, C_GRASS_HI, C_GRASS_DK]
    _noise_dots(d, bases[variant % 3], C_GRASS_HI, C_GRASS_DK, seed=variant * 17 + 3)
    return img


def tile_path() -> Image.Image:
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _px(d, 0, 0, C_PATH, TILE, TILE)
    for x in range(0, TILE, 4):
        _px(d, x, 8, C_PATH_HI, 2, 1)
        _px(d, x + 2, 20, C_PATH_DK, 2, 1)
    return img


def tile_path_edge(side: str) -> Image.Image:
    """side: n/s/e/w — 草地向路径过渡。"""
    img = tile_grass(0)
    d = ImageDraw.Draw(img)
    if side == "n":
        _px(d, 0, 0, C_PATH, TILE, TILE // 2 + 2)
    elif side == "s":
        _px(d, 0, TILE // 2 - 2, C_PATH, TILE, TILE // 2 + 2)
    elif side == "w":
        _px(d, 0, 0, C_PATH, TILE // 2 + 2, TILE)
    else:
        _px(d, TILE // 2 - 2, 0, C_PATH, TILE // 2 + 2, TILE)
    _px(d, 0, 0, C_PATH_DK, TILE, 1)
    return img


def tile_spawn() -> Image.Image:
    img = tile_grass(1)
    d = ImageDraw.Draw(img)
    cx, cy = TILE // 2, TILE // 2
    d.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(*C_SPAWN, 180), outline=C_OUTLINE)
    return img


def tile_goal() -> Image.Image:
    img = tile_grass(2)
    d = ImageDraw.Draw(img)
    cx, cy = TILE // 2, TILE // 2
    d.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=(*C_GOAL, 180), outline=C_OUTLINE)
    return img


def tile_wet_grass() -> Image.Image:
    """雨天变体：草地略深，供天气系统混色。"""
    img = tile_grass(0)
    d = ImageDraw.Draw(img)
    overlay = Image.new("RGBA", (TILE, TILE), (20, 40, 80, 35))
    return Image.alpha_composite(img, overlay)


def tile_snow_grass() -> Image.Image:
    img = tile_grass(1)
    d = ImageDraw.Draw(img)
    for x in range(0, TILE, 5):
        _px(d, x, (x * 3) % 28, (230, 235, 245), 2, 2)
    return img


TILES = [
    ("grass_a", tile_grass(0)),
    ("grass_b", tile_grass(1)),
    ("grass_c", tile_grass(2)),
    ("path", tile_path()),
    ("path_edge_n", tile_path_edge("n")),
    ("path_edge_s", tile_path_edge("s")),
    ("path_edge_e", tile_path_edge("e")),
    ("path_edge_w", tile_path_edge("w")),
    ("spawn", tile_spawn()),
    ("goal", tile_goal()),
    ("grass_wet", tile_wet_grass()),
    ("grass_snow", tile_snow_grass()),
]


def build_atlas() -> Image.Image:
    w = TILE * len(TILES)
    atlas = Image.new("RGBA", (w, TILE), (0, 0, 0, 0))
    for i, (_, img) in enumerate(TILES):
        atlas.paste(img, (i * TILE, 0))
    return atlas


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, img in TILES:
        p = os.path.join(OUT, "%s_32.png" % name)
        img.save(p, optimize=True)
        print("wrote", p)
    atlas_path = os.path.join(OUT, "tileset_32.png")
    build_atlas().save(atlas_path, optimize=True)
    print("wrote", atlas_path, "(%d tiles)" % len(TILES))


if __name__ == "__main__":
    main()
