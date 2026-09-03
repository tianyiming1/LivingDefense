"""Fix pick_004 game sprite: face + second hand + readable wing pair."""
from __future__ import annotations

import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "picks", "pick_004_flame_drake_game.png")
BAK = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "picks", "pick_004_flame_drake_game_before_fix.png")
OUT = SRC


def setp(px, w, h, x, y, c):
    if 0 <= x < w and 0 <= y < h:
        px[x, y] = c


def stamp(px, w, h, ox, oy, cells, default_c):
    """cells: list of (dx,dy) or (dx,dy,color)."""
    for item in cells:
        if len(item) == 2:
            dx, dy = item
            c = default_c
        else:
            dx, dy, c = item
        setp(px, w, h, ox + dx, oy + dy, c)


def main():
    im = Image.open(SRC).convert("RGBA")
    if not os.path.isfile(BAK):
        im.save(BAK)
        print("backup", BAK)
    px = im.load()
    w, h = im.size

    OL = (0, 0, 0, 255)
    EYE = (255, 230, 90, 255)
    EYE_DK = (200, 120, 30, 255)
    SNOUT = (40, 20, 25, 255)
    HORN = (230, 90, 35, 255)
    OR = (210, 80, 35, 255)
    OR2 = (180, 55, 25, 255)
    P1 = (119, 73, 103, 255)
    P2 = (80, 24, 55, 255)
    P3 = (102, 39, 75, 255)
    P4 = (70, 30, 60, 255)
    WING = (95, 45, 85, 255)
    WING_DK = (55, 25, 50, 255)

    # --- FACE (head cluster is roughly x=22-40, y=4-20 facing left-ish) ---
    # Clear muddy head core then paint readable features
    for y in range(6, 18):
        for x in range(24, 42):
            r, g, b, a = px[x, y]
            if a < 20:
                continue
            # lightly darken clutter in face zone for redraw
            if r > 140 and y <= 14 and x >= 28:
                pass

    # eye (bright) — left-facing head: eye near left of face blob
    stamp(
        px, w, h, 30, 10,
        [
            (0, 0, EYE), (1, 0, EYE), (0, 1, EYE_DK), (1, 1, OL),
            (-1, 0, OL), (2, 0, OL), (0, -1, OL),
        ],
        EYE,
    )
    # snout / mouth facing left
    stamp(
        px, w, h, 24, 12,
        [
            (0, 0, SNOUT), (1, 0, SNOUT), (2, 0, OR2),
            (0, 1, OL), (1, 1, SNOUT), (2, 1, OR),
            (-1, 0, OL),
        ],
        SNOUT,
    )
    # second horn tip for readable crown
    stamp(
        px, w, h, 34, 4,
        [(0, 0, HORN), (0, 1, HORN), (1, 0, OL), (-1, 1, OL), (0, 2, OR)],
        HORN,
    )
    stamp(
        px, w, h, 28, 3,
        [(0, 0, HORN), (0, 1, OR), (1, 0, OL)],
        HORN,
    )

    # --- SECOND HAND (viewer's right / character left arm) ---
    # Remove a bit of lower-right wing noise so hand reads, then paint arm+claw
    bx, by = 44, 33
    for dy in range(0, 16):
        for dx in range(0, 14):
            x, y = bx + dx, by + dy
            if not (0 <= x < w and 0 <= y < h):
                continue
            r, g, b, a = px[x, y]
            # only clear mid-wing fringe in hand pocket
            if a > 20 and dx >= 2 and dy >= 2 and dx <= 10 and dy <= 12:
                if r < 130 and b > 40:  # purple wing mush
                    if dy >= 4:
                        px[x, y] = (0, 0, 0, 0)

    # upper arm orange from torso
    stamp(
        px, w, h, bx, by,
        [
            (0, 0, OR), (1, 0, OR), (2, 0, OR2),
            (0, 1, OR), (1, 1, OR), (2, 1, OR2), (3, 1, OR2),
            (1, 2, OR2), (2, 2, OR2), (3, 2, OR2),
            (-1, 0, OL), (0, -1, OL), (3, 0, OL),
        ],
        OR,
    )
    # purple forearm
    stamp(
        px, w, h, bx, by,
        [
            (3, 3, P1), (4, 3, P1), (5, 3, P3),
            (3, 4, P1), (4, 4, P1), (5, 4, P3), (6, 4, P3),
            (4, 5, P3), (5, 5, P2), (6, 5, P2),
            (5, 6, P2), (6, 6, P2), (7, 6, P4),
            (5, 7, P2), (6, 7, P4), (7, 7, P4),
            (2, 3, OL), (6, 3, OL), (8, 6, OL), (8, 7, OL),
        ],
        P1,
    )
    # 3-finger claw
    stamp(
        px, w, h, bx, by,
        [
            (6, 8, P3), (7, 8, P2), (8, 8, P2),
            (6, 9, P2), (7, 9, P2), (8, 9, P4), (9, 9, P4),
            (5, 10, P4), (6, 10, P2), (7, 10, P4), (8, 10, P4), (9, 10, OL),
            (6, 11, OL), (8, 11, P4), (9, 11, OL),
            (5, 9, OL), (10, 10, OL),
        ],
        P2,
    )

    # --- WINGS: simplify to ONE clear pair (far + near) ---
    # Far wing (left/back): clean triangle membrane behind left shoulder
    # Clear noisy low hip-wing pixels (anatomy rule: no hip wings)
    for y in range(40, 58):
        for x in range(4, 22):
            r, g, b, a = px[x, y]
            if a < 20:
                continue
            # purple blobs low-left that look like extra wing — erase if not leg/tail orange
            if r < 120 and b > 35 and g < 90 and y >= 44 and x <= 16:
                px[x, y] = (0, 0, 0, 0)

    # Paint a cleaner near-wing tip on upper right (readable membrane)
    stamp(
        px, w, h, 48, 8,
        [
            (0, 2, WING), (1, 1, WING), (2, 0, WING_DK), (3, 0, WING), (4, 1, WING),
            (1, 2, WING), (2, 1, WING), (3, 1, WING_DK), (4, 2, WING_DK),
            (2, 2, WING), (3, 2, WING), (4, 3, WING_DK),
            (3, 3, WING_DK), (2, 3, WING),
            (0, 1, OL), (5, 1, OL), (5, 2, OL), (1, 0, OL),
        ],
        WING,
    )
    # Far wing upper left clean tip
    stamp(
        px, w, h, 8, 6,
        [
            (2, 0, WING_DK), (1, 1, WING), (0, 2, WING), (1, 2, WING_DK), (2, 1, WING),
            (2, 2, WING), (3, 2, WING_DK), (1, 3, WING), (2, 3, WING),
            (0, 1, OL), (3, 0, OL), (0, 3, OL),
        ],
        WING,
    )

    im.save(OUT)
    print("saved", OUT)
    # also 4x preview for quick check
    prev = im.resize((w * 4, h * 4), Image.NEAREST)
    prev_path = OUT.replace(".png", "_fix_preview4x.png")
    prev.save(prev_path)
    print("preview", prev_path)


if __name__ == "__main__":
    main()
