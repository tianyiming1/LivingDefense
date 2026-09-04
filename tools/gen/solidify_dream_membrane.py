"""梦龙翼膜实心化（create-game-assets raster normalize）。

纪律：
- 锁身份：基于 approved still，不改解剖/色板气质
- 先写 candidates + 绿底 QA，泄漏≈0 才 promote approved/ship
- 禁止扩张外轮廓；只填内部针孔与稀疏抖点透草
- walk 占位帧 dy=0（CO-046 梦步）
"""
from __future__ import annotations

import os
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STUDIO = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "dream")
SHIP = os.path.join(ROOT, "assets", "pixels", "dragon")
GRASS = (62, 120, 58, 255)
MEMBRANE_FALLBACK = (42, 24, 72, 255)  # ~#2A1848


def mark_exterior(px, w: int, h: int, athresh: int = 40):
	exterior = [[False] * w for _ in range(h)]
	q: deque[tuple[int, int]] = deque()
	for x in range(w):
		for y in (0, h - 1):
			if px[x, y][3] < athresh:
				exterior[y][x] = True
				q.append((x, y))
	for y in range(h):
		for x in (0, w - 1):
			if px[x, y][3] < athresh and not exterior[y][x]:
				exterior[y][x] = True
				q.append((x, y))
	while q:
		x, y = q.popleft()
		for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
			nx, ny = x + dx, y + dy
			if 0 <= nx < w and 0 <= ny < h and not exterior[ny][nx] and px[nx, ny][3] < athresh:
				exterior[ny][nx] = True
				q.append((nx, ny))
	return exterior


def avg(cols: list[tuple[int, int, int]]) -> tuple[int, int, int]:
	n = len(cols)
	return (
		sum(c[0] for c in cols) // n,
		sum(c[1] for c in cols) // n,
		sum(c[2] for c in cols) // n,
	)


def solidify(im: Image.Image, passes: int = 40) -> Image.Image:
	out = im.convert("RGBA").copy()
	w, h = out.size
	px = out.load()
	exterior = mark_exterior(px, w, h)
	for y in range(h):
		for x in range(w):
			if px[x, y][3] >= 40 or exterior[y][x]:
				continue
			cols: list[tuple[int, int, int]] = []
			for r in range(1, 5):
				for dx in range(-r, r + 1):
					for dy in range(-r, r + 1):
						nx, ny = x + dx, y + dy
						if 0 <= nx < w and 0 <= ny < h:
							rr, gg, bb, aa = px[nx, ny]
							if aa >= 160 and rr + gg + bb > 40:
								cols.append((rr, gg, bb))
				if cols:
					break
			if cols:
				c = avg(cols)
				px[x, y] = (c[0], c[1], c[2], 255)
			else:
				px[x, y] = MEMBRANE_FALLBACK

	for _ in range(passes):
		px = out.load()
		fills: list[tuple[int, int, tuple[int, int, int]]] = []
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				if px[x, y][3] >= 40:
					continue
				cols = []
				op = 0
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						if dx == 0 and dy == 0:
							continue
						nx, ny = x + dx, y + dy
						if not (0 <= nx < w and 0 <= ny < h):
							continue
						rr, gg, bb, aa = px[nx, ny]
						if aa >= 180:
							op += 1
							if rr + gg + bb > 40:
								cols.append((rr, gg, bb))
				if op >= 12 and len(cols) >= 8:
					fills.append((x, y, avg(cols)))
				elif op >= 8 and len(cols) >= 6:
					c4: list[tuple[int, int, int]] = []
					n4 = 0
					for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
						rr, gg, bb, aa = px[x + dx, y + dy]
						if aa >= 180 and rr + gg + bb > 40:
							n4 += 1
							c4.append((rr, gg, bb))
					if n4 >= 3:
						fills.append((x, y, avg(c4 if c4 else cols)))
		if not fills:
			break
		px = out.load()
		for x, y, c in fills:
			px[x, y] = (c[0], c[1], c[2], 255)

	px = out.load()
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a == 0:
				continue
			if a < 128:
				px[x, y] = (0, 0, 0, 0)
			elif a < 255:
				px[x, y] = (r, g, b, 255)
	return out


def count_grass_leaks(im: Image.Image) -> int:
	w, h = im.size
	px = im.load()
	leaks = 0
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if px[x, y][3] >= 40:
				continue
			cols = 0
			for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
				rr, gg, bb, aa = px[x + dx, y + dy]
				if aa > 160 and rr + gg + bb > 40:
					cols += 1
			if cols >= 2:
				leaks += 1
	return leaks


def pose(im: Image.Image, rot: float, dx: int, sx: float = 1.0, sy: float = 1.0) -> Image.Image:
	w, h = im.size
	canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	work = im.copy()
	if abs(sx - 1.0) > 0.001 or abs(sy - 1.0) > 0.001:
		work = work.resize((max(1, int(w * sx)), max(1, int(h * sy))), Image.NEAREST)
	if abs(rot) > 0.01:
		work = work.rotate(rot, resample=Image.NEAREST, expand=False)
	ox = (w - work.size[0]) // 2 + dx
	oy = (h - work.size[1]) // 2
	canvas.alpha_composite(work, (ox, oy))
	return solidify(canvas, passes=8)


def main() -> None:
	jobs = [
		("wyrm", os.path.join(STUDIO, "approved", "042_game.png"), 16, os.path.join(STUDIO, "wyrm", "candidates"), "090"),
		("drake", os.path.join(STUDIO, "drake", "approved", "003_game.png"), 15, os.path.join(STUDIO, "drake", "candidates"), "090"),
		("whelp", os.path.join(STUDIO, "whelp", "approved", "006_game.png"), 14, os.path.join(STUDIO, "whelp", "candidates"), "090"),
	]
	promoted = []
	for stage, src, uid, cand_dir, nid in jobs:
		os.makedirs(cand_dir, exist_ok=True)
		base = Image.open(src).convert("RGBA")
		before = count_grass_leaks(base)
		solid = solidify(base)
		after = count_grass_leaks(solid)
		gpath = os.path.join(cand_dir, f"{nid}_game.png")
		solid.save(gpath, optimize=True)
		qa = Image.new("RGBA", base.size, GRASS)
		qa.alpha_composite(solid)
		qa.save(os.path.join(cand_dir, f"{nid}_qa_grass.png"), optimize=True)
		print(f"{stage} leaks {before}->{after} candidate={gpath}")
		if after > 8:
			print(f"HOLD {stage}: leaks still {after}")
			continue

		if stage == "wyrm":
			solid.save(os.path.join(STUDIO, "approved", "042_game.png"), optimize=True)
			solid.save(os.path.join(STUDIO, "picks", "pick_dream_menglong_game.png"), optimize=True)
			p4 = solid.resize((solid.size[0] * 4, solid.size[1] * 4), Image.NEAREST)
			p4.save(os.path.join(STUDIO, "picks", "pick_dream_menglong_preview4x.png"), optimize=True)
		elif stage == "drake":
			solid.save(os.path.join(STUDIO, "drake", "approved", "003_game.png"), optimize=True)
		elif stage == "whelp":
			solid.save(os.path.join(STUDIO, "whelp", "approved", "006_game.png"), optimize=True)

		solid.save(os.path.join(SHIP, f"unit_{uid}.png"), optimize=True)
		frames = {
			"idle_0.png": solid,
			"idle_1.png": pose(solid, 0, 0, 1.0, 1.015),
			"walk_0.png": pose(solid, -2.0, 1, 1.01, 0.995),
			"walk_1.png": pose(solid, 1.2, 0, 0.995, 1.01),
			"walk_2.png": pose(solid, -1.6, 1, 1.01, 0.995),
			"walk_3.png": pose(solid, 1.6, 0, 0.995, 1.01),
			"attack_0.png": pose(solid, 3.5, -2, 0.985, 1.015),
			"attack_1.png": pose(solid, -2.5, 2, 1.03, 0.98),
			"attack_2.png": pose(solid, -1.0, 1, 1.0, 1.0),
		}
		anim_ship = os.path.join(SHIP, f"unit_{uid}_anim")
		for name, fr in frames.items():
			fr.save(os.path.join(anim_ship, name), optimize=True)
			clip = name.split("_")[0]
			fr.save(os.path.join(STUDIO, "anim", stage, clip, name), optimize=True)
		print(f"PROMOTED {stage} unit_{uid}")
		promoted.append(stage)

	print("DONE promoted=", promoted)


if __name__ == "__main__":
	main()
