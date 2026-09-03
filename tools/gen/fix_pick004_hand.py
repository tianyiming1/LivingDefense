"""补全 pick_004 缺失的那只手（game 64x72）。"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "assets/pixels/_studio/dragon/picks/pick_004_flame_drake_game.png"


def main() -> None:
    im = Image.open(PATH).convert("RGBA")
    px = im.load()
    w, h = im.size

    OL = (0, 0, 0, 255)
    P1 = (119, 73, 103, 255)
    P2 = (80, 24, 55, 255)
    P3 = (102, 39, 75, 255)
    OR = (200, 70, 30, 255)

    def setp(x: int, y: int, c: tuple) -> None:
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = c

    # 右侧缺手前臂：从躯干右缘伸出，压在翼膜前，可识别为第二只爪
    bx, by = 44, 34

    for dx, dy in [
        (0, 0), (1, 0), (2, 0),
        (0, 1), (1, 1), (2, 1),
        (1, 2), (2, 2), (3, 2),
    ]:
        setp(bx + dx, by + dy, OR)
    for dx, dy in [(-1, 0), (0, -1), (3, 0), (3, 1)]:
        setp(bx + dx, by + dy, OL)

    for dx, dy in [
        (3, 3), (4, 3), (5, 3),
        (3, 4), (4, 4), (5, 4), (6, 4),
        (4, 5), (5, 5), (6, 5),
        (5, 6), (6, 6), (7, 6),
        (5, 7), (6, 7), (7, 7),
    ]:
        setp(bx + dx, by + dy, P1 if dy < 5 else P3)
    for dx, dy in [(2, 3), (3, 2), (6, 3), (7, 4), (8, 6), (8, 7), (4, 8), (7, 8)]:
        setp(bx + dx, by + dy, OL)

    for dx, dy in [
        (6, 8), (7, 8), (8, 8),
        (6, 9), (7, 9), (8, 9), (9, 9),
        (5, 10), (6, 10), (7, 10), (8, 10), (9, 10),
        (6, 11), (8, 11), (9, 11),
    ]:
        setp(bx + dx, by + dy, P2 if dy >= 10 else P3)
    for dx, dy in [(5, 9), (5, 11), (10, 10), (10, 11), (7, 12), (9, 12)]:
        setp(bx + dx, by + dy, OL)

    im.save(PATH)
    backup = PATH.with_name("pick_004_flame_drake_game_2hands.png")
    im.save(backup)
    print("updated", PATH)
    print("copy", backup)


if __name__ == "__main__":
    main()
