"""敌人 3/4 侧视精灵 — 委托 draw_sprites_34。"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from draw_sprites_34 import (  # noqa: E402
    draw_enemy_grunt_34, draw_enemy_runner_34, draw_enemy_tank_34, draw_enemy_boss_34,
    save_preview,
)

ENEMY_DRAWERS = {
    0: draw_enemy_grunt_34,
    1: draw_enemy_runner_34,
    2: draw_enemy_tank_34,
    3: draw_enemy_boss_34,
}


def draw_enemy(enemy_id: int, size=64):
    return ENEMY_DRAWERS.get(enemy_id, draw_enemy_grunt_34)()


def save_all(out_dir: str):
    os.makedirs(out_dir, exist_ok=True)
    for eid in sorted(ENEMY_DRAWERS.keys()):
        path = os.path.join(out_dir, "enemy_%d.png" % eid)
        save_preview(draw_enemy(eid), path)
        print("wrote", path)


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    save_all(os.path.join(root, "assets", "pixels", "enemies"))
