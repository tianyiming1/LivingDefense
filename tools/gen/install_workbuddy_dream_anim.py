"""Slice WorkBuddy multi-frame sheets → dream unit anim (96×108 foot-anchored).

Sheets live in dream/workbuddy/{s96,fly8,land8,...} as r_c.png cells
(already cut from the integrated sprite sheets).

Usage:
  python tools/gen/install_workbuddy_dream_anim.py --units 17
  python tools/gen/promote_dream_hand_anim.py --unit 17
"""
from __future__ import annotations

import argparse
import json
import os
import shutil

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WB = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "dream", "workbuddy")
HAND = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "dream", "hand_anim")
SHIP = os.path.join(ROOT, "assets", "pixels", "dragon")
CW, CH = 96, 108
FOOT = int(CH * 0.92)
THR = 28
SCALES = {14: 0.45, 15: 0.62, 16: 0.82, 17: 1.0}


def rematte(im: Image.Image) -> Image.Image:
	"""Black bg → alpha; keep dark body pixels (sum>THR)."""
	im = im.convert("RGBA")
	px = im.load()
	for y in range(im.size[1]):
		for x in range(im.size[0]):
			r, g, b, a = px[x, y]
			if r + g + b <= THR:
				px[x, y] = (0, 0, 0, 0)
	return im


def opaque_bbox(im: Image.Image):
	px = im.load()
	xs, ys = [], []
	for y in range(im.size[1]):
		for x in range(im.size[0]):
			r, g, b, a = px[x, y]
			if a > 40 and r + g + b > 40:
				xs.append(x)
				ys.append(y)
	if not xs:
		return None
	return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def fit_canvas(im: Image.Image, lift: int = 0, max_h: int | None = None) -> Image.Image:
	im = rematte(im)
	bb = opaque_bbox(im)
	if not bb:
		return Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	crop = im.crop(bb)
	mh = max_h if max_h else CH - 10 - lift
	mw = CW - 6
	sx = min(1.0, mw / crop.size[0], mh / max(1, crop.size[1]))
	if sx < 0.999:
		crop = crop.resize(
			(max(1, int(crop.size[0] * sx)), max(1, int(crop.size[1] * sx))),
			Image.NEAREST,
		)
	out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	x = (CW - crop.size[0]) // 2
	y = FOOT - lift - crop.size[1]
	y = max(2, min(CH - crop.size[1] - 2, y))
	out.alpha_composite(crop, (x, y))
	return out


def load_cell(sheet: str, r: int, c: int) -> Image.Image:
	p = os.path.join(WB, sheet, f"{r}_{c}.png")
	return Image.open(p).convert("RGBA")


def flat_death(im: Image.Image, scale: float = 1.0) -> Image.Image:
	"""Side-squash for death_2 gate (wide flat)."""
	src = rematte(im)
	bb = opaque_bbox(src)
	if not bb:
		return fit_canvas(im)
	crop = src.crop(bb)
	nw = min(CW - 8, max(56, int(crop.size[0] * 1.15 * max(scale, 0.55))))
	nh = max(14, min(24, int(crop.size[1] * 0.40 * max(scale, 0.7))))
	crop = crop.resize((nw, nh), Image.NEAREST)
	out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	out.alpha_composite(crop, ((CW - nw) // 2, FOOT - nh + 2))
	return out


def tip_death(im: Image.Image, ang: float) -> Image.Image:
	src = rematte(im)
	bb = opaque_bbox(src)
	if not bb:
		return fit_canvas(im)
	crop = src.crop(bb).rotate(ang, resample=Image.NEAREST, expand=True)
	s = min((CW - 8) / crop.size[0], (CH - 16) / crop.size[1], 1.0)
	crop = crop.resize((max(1, int(crop.size[0] * s)), max(1, int(crop.size[1] * s))), Image.NEAREST)
	out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	out.alpha_composite(crop, ((CW - crop.size[0]) // 2, max(2, FOOT - crop.size[1])))
	return out


def build_clips(scale: float = 1.0) -> dict[str, Image.Image]:
	"""Map sheet cells → CO-046 clips. s96 is 4×4@96 (best)."""
	idle0 = fit_canvas(load_cell("s96", 3, 0), lift=0)
	idle1 = fit_canvas(load_cell("s96", 3, 1), lift=0)
	walk0 = fit_canvas(load_cell("s96", 3, 2), lift=0)
	walk1 = fit_canvas(load_cell("s96", 3, 3), lift=0)
	walk2 = fit_canvas(load_cell("s96", 2, 2), lift=0)
	walk3 = fit_canvas(load_cell("s96", 2, 3), lift=0)
	fly0 = fit_canvas(load_cell("s96", 0, 0), lift=16, max_h=78)
	fly1 = fit_canvas(load_cell("s96", 0, 1), lift=16, max_h=78)
	fly2 = fit_canvas(load_cell("s96", 0, 2), lift=16, max_h=78)
	fly3 = fit_canvas(load_cell("s96", 1, 0), lift=16, max_h=78)
	atk0 = fit_canvas(load_cell("s96", 2, 0), lift=2)
	atk1 = fit_canvas(load_cell("land8", 0, 0), lift=2)
	atk2 = fit_canvas(load_cell("s96", 2, 1), lift=2)
	d0 = tip_death(load_cell("land8", 0, 1) if os.path.isfile(os.path.join(WB, "land8", "0_1.png")) else load_cell("s96", 2, 0), 28)
	d1 = tip_death(load_cell("s96", 2, 0), 55)
	d2 = flat_death(load_cell("s96", 3, 0), scale=scale)
	raw = {
		"idle_0": idle0,
		"idle_1": idle1,
		"walk_0": walk0,
		"walk_1": walk1,
		"walk_2": walk2,
		"walk_3": walk3,
		"fly_0": fly0,
		"fly_1": fly1,
		"fly_2": fly2,
		"fly_3": fly3,
		"attack_0": atk0,
		"attack_1": atk1,
		"attack_2": atk2,
		"death_0": d0,
		"death_1": d1,
		"death_2": d2,
	}
	if abs(scale - 1.0) < 0.01:
		return raw
	# scale non-death_2; death_2 already sized
	out = {}
	for k, im in raw.items():
		if k == "death_2":
			out[k] = im
			continue
		bb = opaque_bbox(im)
		if not bb:
			out[k] = im
			continue
		crop = im.crop(bb)
		nw = max(1, int(crop.size[0] * scale))
		nh = max(1, int(crop.size[1] * scale))
		crop = crop.resize((nw, nh), Image.NEAREST)
		canvas = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
		lift = 16 if k.startswith("fly") else 0
		x = (CW - nw) // 2
		y = FOOT - lift - nh
		y = max(2, min(CH - nh - 2, y))
		canvas.alpha_composite(crop, (x, y))
		out[k] = canvas
	return out


def install_unit(uid: int) -> None:
	scaled = build_clips(SCALES.get(uid, 1.0))
	hand = os.path.join(HAND, f"unit_{uid}")
	os.makedirs(hand, exist_ok=True)
	for name, fr in scaled.items():
		fr.save(os.path.join(hand, f"{name}.png"))
	cand = os.path.join(hand, "candidates")
	os.makedirs(cand, exist_ok=True)
	for name, fr in scaled.items():
		fr.save(os.path.join(cand, f"{name}.png"))
	print(f"hand unit_{uid}: {len(scaled)} frames")


def set_prefer_frames(uid: int) -> None:
	meta_p = os.path.join(SHIP, f"unit_{uid}_puppet", "meta.json")
	if not os.path.isfile(meta_p):
		return
	with open(meta_p, encoding="utf-8") as f:
		meta = json.load(f)
	meta["prefer_frames"] = True
	with open(meta_p, "w", encoding="utf-8") as f:
		json.dump(meta, f, indent=2)
	print("prefer_frames", uid)


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--units", default="14,15,16,17")
	args = ap.parse_args()
	assert os.path.isdir(os.path.join(WB, "s96")), "run sheet slice first → workbuddy/s96"
	for uid in [int(x) for x in args.units.split(",") if x.strip()]:
		install_unit(uid)
		set_prefer_frames(uid)
	print("DONE — promote next")


if __name__ == "__main__":
	main()
