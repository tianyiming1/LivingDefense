"""Promote hand-drawn dream anim frames to ship after basic gates.

Usage:
  python tools/gen/promote_dream_hand_anim.py --unit 14 --dry-run
  python tools/gen/promote_dream_hand_anim.py --unit 14
"""
from __future__ import annotations

import argparse
import os
import shutil
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DREAM = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "dream")
HAND = os.path.join(DREAM, "hand_anim")
SHIP = os.path.join(ROOT, "assets", "pixels", "dragon")
CW, CH = 96, 108
THR = 40

# MVP minimum; full set preferred
MVP = {
	"idle": [0, 1],
	"walk": [0, 2],
	"fly": [0, 2],
	"attack": [0, 1, 2],
	"death": [0, 2],
}
FULL = {
	"idle": [0, 1],
	"walk": [0, 1, 2, 3],
	"fly": [0, 1, 2, 3],
	"attack": [0, 1, 2],
	"death": [0, 1, 2],
}


def mask(im: Image.Image):
	px = im.load()
	return {(x, y) for y in range(im.size[1]) for x in range(im.size[0])
			if px[x, y][3] > THR and sum(px[x, y][:3]) > 40}


def bbox(m: set):
	if not m:
		return None
	xs = [p[0] for p in m]
	ys = [p[1] for p in m]
	return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def iou(a: set, b: set) -> float:
	u = len(a | b)
	return len(a & b) / u if u else 1.0


def check_frame(path: str) -> list[str]:
	fails = []
	im = Image.open(path).convert("RGBA")
	if im.size != (CW, CH):
		fails.append(f"size {im.size} != {CW}x{CH}")
	m = mask(im)
	if len(m) < 180:
		fails.append("too empty")
	# top clip
	px = im.load()
	top = sum(1 for x in range(CW) for y in range(2) if px[x, y][3] > THR and sum(px[x, y][:3]) > 40)
	if top > 8:
		fails.append(f"top_clip={top}")
	# hard rectangular hole heuristic: large empty rect inside bbox
	return fails


def gate(uid: int, src: str, require_full: bool) -> list[str]:
	fails: list[str] = []
	need = FULL if require_full else MVP
	loaded: dict[str, Image.Image] = {}
	for anim, idxs in need.items():
		for i in idxs:
			name = f"{anim}_{i}.png"
			path = os.path.join(src, name)
			if not os.path.isfile(path):
				fails.append(f"missing {name}")
				continue
			ff = check_frame(path)
			fails.extend(f"{name}: {f}" for f in ff)
			loaded[f"{anim}_{i}"] = Image.open(path).convert("RGBA")

	if "idle_0" in loaded and "fly_0" in loaded:
		bi, bf = bbox(mask(loaded["idle_0"])), bbox(mask(loaded["fly_0"]))
		if bi and bf and bf[1] >= bi[1] - 4:
			fails.append("fly_0 not higher than idle_0")
		if "fly_2" in loaded:
			f0, f2 = mask(loaded["fly_0"]), mask(loaded["fly_2"])
			fy0 = max(p[1] for p in f0) if f0 else 0
			fy2 = max(p[1] for p in f2) if f2 else 0
			if abs(fy0 - fy2) > 6:
				fails.append(f"fly foot Y bounce {fy0} vs {fy2}")

	if "idle_0" in loaded and "death_2" in loaded:
		bi, bd = bbox(mask(loaded["idle_0"])), bbox(mask(loaded["death_2"]))
		if bi and bd:
			ia = (bi[2] - bi[0]) / max(1, bi[3] - bi[1])
			da = (bd[2] - bd[0]) / max(1, bd[3] - bd[1])
			if da < ia * 1.15:
				fails.append(f"death_2 not flat enough ({da:.2f} vs idle {ia:.2f})")

	if "idle_0" in loaded:
		mi = mask(loaded["idle_0"])
		for other in ("walk_0", "fly_0", "attack_1", "death_2"):
			if other in loaded and iou(mi, mask(loaded[other])) > 0.70:
				fails.append(f"too similar idle↔{other}")

	return fails


def write_compare(uid: int, src: str) -> None:
	names = ["idle_0", "walk_0", "walk_2", "fly_0", "fly_2", "attack_0", "attack_1", "death_2"]
	cell = 192
	sheet = Image.new("RGBA", (cell * len(names) + 8, cell + 24), (0, 0, 0, 255))
	d = ImageDraw.Draw(sheet)
	for i, n in enumerate(names):
		p = os.path.join(src, n + ".png")
		if not os.path.isfile(p):
			continue
		im = Image.open(p).convert("RGBA").resize((cell, cell), Image.NEAREST)
		sheet.alpha_composite(im, (4 + i * cell, 20))
		d.text((4 + i * cell, 2), n, fill=(255, 230, 80, 255))
	out = os.path.join(HAND, f"compare_u{uid}.png")
	sheet.save(out)
	print("compare", out)


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--unit", type=int, required=True)
	ap.add_argument("--full", action="store_true", help="require full 16 frames")
	ap.add_argument("--dry-run", action="store_true")
	args = ap.parse_args()
	uid = args.unit
	src = os.path.join(HAND, f"unit_{uid}")
	if not os.path.isdir(src):
		raise SystemExit(f"missing {src}")

	fails = gate(uid, src, require_full=args.full)
	write_compare(uid, src)
	if fails:
		print("GATE FAIL:")
		for f in fails:
			print(" ", f)
		sys.exit(1)
	print("GATE PASS")
	if args.dry_run:
		print("dry-run — not shipping")
		return

	dst = os.path.join(SHIP, f"unit_{uid}_anim")
	os.makedirs(dst, exist_ok=True)
	for n in list(os.listdir(dst)):
		if n.endswith(".png"):
			os.remove(os.path.join(dst, n))
	# copy all available anim pngs (not templates)
	for n in sorted(os.listdir(src)):
		if not n.endswith(".png") or n.startswith("_"):
			continue
		shutil.copy2(os.path.join(src, n), os.path.join(dst, n))
		print("shipped", n)
	# idle_0 → unit base if present
	idle = os.path.join(dst, "idle_0.png")
	if os.path.isfile(idle):
		shutil.copy2(idle, os.path.join(SHIP, f"unit_{uid}.png"))
		print("updated unit_%d.png from idle_0" % uid)
	print("DONE", dst)


if __name__ == "__main__":
	main()
