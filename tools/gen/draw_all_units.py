"""批量生成四族单位 + 敌人 3/4 侧视像素精灵（64×72）。"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from draw_sprites_34 import (  # noqa: E402
    draw_human_infantry_34, draw_human_musketeer_34, draw_human_mortar_34,
    draw_human_arbalest_34, draw_human_cleric_34, draw_mushroom_34,
    draw_dragon_34, draw_silicon_34,
    draw_enemy_grunt_34, draw_enemy_runner_34, draw_enemy_tank_34, draw_enemy_boss_34,
    save_preview,
)
from draw_unit_sprite import draw_human_infantry  # noqa: E402 — legacy top-down unused

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "pixels")

F_CAP = (138, 92, 191)
F_GRN = (111, 191, 74)
F_STEM = (64, 89, 38)
D_RED = (216, 87, 42)
D_GOLD = (232, 161, 60)
S_CYAN = (111, 211, 231)
S_WHITE = (245, 249, 255)
S_DARK = (40, 100, 120)

SPECS = [
    ("human", 0, lambda: draw_human_infantry_34(1)),
    # CO-042 / W4：unit_1 = 弓手（勿再画火枪）
    ("human", 1, draw_human_musketeer_34),  # legacy name; draw_human_roster_w4 overrides ship
    ("human", 2, draw_human_mortar_34),
    ("human", 3, draw_human_arbalest_34),
    ("human", 4, draw_human_cleric_34),
    ("fungus", 0, lambda: draw_mushroom_34(F_CAP, F_GRN, F_STEM)),
    ("fungus", 1, lambda: draw_mushroom_34((111, 140, 40), (180, 220, 80), F_STEM, spore=True)),
    ("fungus", 2, lambda: draw_mushroom_34((60, 100, 40), F_GRN, F_STEM, wide=True)),
    ("fungus", 3, lambda: draw_mushroom_34((115, 64, 38), (255, 200, 80), (80, 50, 30))),
    ("dragon", 0, lambda: draw_dragon_34(D_RED, D_GOLD, "small")),
    ("dragon", 1, lambda: draw_dragon_34((230, 100, 30), D_GOLD, "medium")),
    ("dragon", 2, lambda: draw_dragon_34((179, 26, 13), (255, 120, 40), "large")),
    ("silicon", 0, lambda: draw_silicon_34(S_CYAN, core=True)),
    ("silicon", 1, lambda: draw_silicon_34(S_WHITE, core=False)),
    ("silicon", 2, lambda: draw_silicon_34(S_DARK, core=False, bulky=True)),
]

ENEMIES = [
    draw_enemy_grunt_34,
    draw_enemy_runner_34,
    draw_enemy_tank_34,
    draw_enemy_boss_34,
]


def main():
    for race, uid, fn in SPECS:
        folder = os.path.join(OUT, race)
        os.makedirs(folder, exist_ok=True)
        path = os.path.join(folder, "unit_%d.png" % uid)
        img = fn()
        save_preview(img, path)
        print("wrote", path)
    ed = os.path.join(OUT, "enemies")
    os.makedirs(ed, exist_ok=True)
    for eid, fn in enumerate(ENEMIES):
        path = os.path.join(ed, "enemy_%d.png" % eid)
        save_preview(fn(), path)
        print("wrote", path)
    legacy = os.path.join(OUT, "human", "human_infantry_idle_64.png")
    draw_human_infantry_34(1).resize((64, 64), Image.NEAREST).save(legacy, optimize=True)
    print("ALL DONE", len(SPECS) + len(ENEMIES), "sprites (3/4 view 64x72)")


if __name__ == "__main__":
    main()
