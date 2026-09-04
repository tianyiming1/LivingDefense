"""Generate onion-skin templates for hand-drawn dream anim frames.

Copies approved ship base as dim underlay on 96x108 black canvas.
Output: dream/hand_anim/unit_{id}/_templates/{clip}_template.png
"""
from __future__ import annotations

import argparse
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DREAM = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "dream")
SHIP = os.path.join(ROOT, "assets", "pixels", "dragon")
HAND = os.path.join(DREAM, "hand_anim")
CW, CH = 96, 108

CLIPS = [
	"idle_0", "idle_1",
	"walk_0", "walk_1", "walk_2", "walk_3",
	"fly_0", "fly_1", "fly_2", "fly_3",
	"attack_0", "attack_1", "attack_2",
	"death_0", "death_1", "death_2",
]

HINTS = {
	"idle_0": "wings folded",
	"idle_1": "wings open",
	"walk_0": "L fore + R hind up",
	"walk_1": "contact",
	"walk_2": "R fore + L hind up",
	"walk_3": "contact",
	"fly_0": "wings UP feet tucked",
	"fly_1": "wings mid",
	"fly_2": "wings DOWN",
	"fly_3": "wings rising",
	"attack_0": "lean BACK cast",
	"attack_1": "LUNGE release",
	"attack_2": "recover",
	"death_0": "tilt side",
	"death_1": "falling",
	"death_2": "FLAT on side",
}


def dim_base(base: Image.Image, alpha: int = 70) -> Image.Image:
	out = Image.new("RGBA", (CW, CH), (0, 0, 0, 255))
	ghost = base.convert("RGBA").copy()
	px = ghost.load()
	for y in range(CH):
		for x in range(CW):
			r, g, b, a = px[x, y]
			if a > 40:
				px[x, y] = (r, g, b, alpha)
			else:
				px[x, y] = (0, 0, 0, 0)
	out.alpha_composite(ghost)
	return out


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--units", default="14")
	args = ap.parse_args()
	for uid in [int(x) for x in args.units.split(",") if x.strip()]:
		base_path = os.path.join(SHIP, f"unit_{uid}.png")
		if not os.path.isfile(base_path):
			raise SystemExit(f"missing {base_path}")
		base = Image.open(base_path).convert("RGBA")
		out_dir = os.path.join(HAND, f"unit_{uid}", "_templates")
		os.makedirs(out_dir, exist_ok=True)
		os.makedirs(os.path.join(HAND, f"unit_{uid}"), exist_ok=True)
		for clip in CLIPS:
			im = dim_base(base)
			d = ImageDraw.Draw(im)
			d.text((2, 2), clip, fill=(255, 220, 80, 255))
			hint = HINTS.get(clip, "")
			if hint:
				d.text((2, 12), hint[:22], fill=(180, 200, 255, 200))
			# foot guide line
			foot = int(CH * 0.92)
			d.line((0, foot, CW - 1, foot), fill=(60, 60, 80, 180))
			path = os.path.join(out_dir, f"{clip}_template.png")
			im.save(path)
			print("wrote", path)
	print("DONE — draw over templates, export to unit_{id}/ without _templates/")


if __name__ == "__main__":
	main()
