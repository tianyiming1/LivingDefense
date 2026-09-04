"""Dream anim FREE path: solid puppet (no hole-cut layers).

Every frame starts from the FULL approved ship sprite. Wings are an EXTRA overlay
scaled from wing-colored pixels — we never delete body pixels (that caused shredded FAIL).

Usage:
  python tools/gen/gen_dream_cutout_frames.py --units 14 --install
  python tools/gen/promote_dream_hand_anim.py --unit 14 --dry-run
"""
from __future__ import annotations

import argparse
import os
import shutil

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHIP = os.path.join(ROOT, "assets", "pixels", "dragon")
DREAM = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "dream")
HAND = os.path.join(DREAM, "hand_anim")
CW, CH = 96, 108
FOOT = int(CH * 0.92)
THR = 40


def opaque_bbox(im: Image.Image):
	px = im.load()
	xs, ys = [], []
	for y in range(im.size[1]):
		for x in range(im.size[0]):
			r, g, b, a = px[x, y]
			if a > THR and r + g + b > 40:
				xs.append(x)
				ys.append(y)
	if not xs:
		return None
	return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def extract(im: Image.Image) -> Image.Image:
	bb = opaque_bbox(im)
	if not bb:
		return Image.new("RGBA", (1, 1), (0, 0, 0, 0))
	return im.crop(bb)


def is_wing_pixel(r: int, g: int, b: int, a: int) -> bool:
	if a < THR or r + g + b < 40:
		return False
	if b >= r + 15 and b >= g and (r + g) < 280:
		return True
	if r < 90 and g < 90 and b > 70:
		return True
	return False


def wing_overlay(base: Image.Image) -> Image.Image:
	"""Wing-colored pixels only (for flap overlay). Full base stays solid underneath."""
	out = Image.new("RGBA", base.size, (0, 0, 0, 0))
	px, op = base.load(), out.load()
	for y in range(base.size[1]):
		for x in range(base.size[0]):
			r, g, b, a = px[x, y]
			if is_wing_pixel(r, g, b, a):
				op[x, y] = (r, g, b, a)
	# fallback: upper third lateral bands
	if opaque_bbox(out) is None:
		bb = opaque_bbox(base)
		if not bb:
			return out
		x0, y0, x1, y1 = bb
		mid = (x0 + x1) // 2
		band = max(4, (x1 - x0) // 5)
		for y in range(y0, y0 + max(1, (y1 - y0) // 2)):
			for x in range(x0, x1):
				if abs(x - mid) < band:
					continue
				p = px[x, y]
				if p[3] > THR and sum(p[:3]) > 40:
					op[x, y] = p
	return out


def shadow(cy: int, w: int = 24, h: int = 6) -> Image.Image:
	out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	d = ImageDraw.Draw(out)
	d.ellipse((CW // 2 - w // 2, cy - h // 2, CW // 2 + w // 2, cy + h // 2), fill=(35, 35, 50, 130))
	return out


def paste_foot(canvas: Image.Image, part: Image.Image, foot_y: int, dx: int = 0) -> tuple[int, int]:
	"""Paste extracted part so its bottom sits at foot_y. Returns top-left."""
	ext = extract(part)
	if ext.size[0] < 2:
		return 0, 0
	x = CW // 2 - ext.size[0] // 2 + dx
	y = foot_y - ext.size[1]
	y = max(2, min(CH - ext.size[1] - 2, y))
	x = max(1, min(CW - ext.size[0] - 1, x))
	canvas.alpha_composite(ext, (x, y))
	return x, y


def scale_ext(part: Image.Image, sx: float, sy: float) -> Image.Image:
	ext = extract(part)
	nw = max(1, int(ext.size[0] * sx))
	nh = max(1, int(ext.size[1] * sy))
	return ext.resize((nw, nh), Image.NEAREST)


def shear_bottom(im: Image.Image, left_dy: int, right_dy: int) -> Image.Image:
	"""Walk hint: shift left/right halves of bottom third vertically (no delete)."""
	bb = opaque_bbox(im)
	if not bb:
		return im
	x0, y0, x1, y1 = bb
	out = im.copy()
	mid = (x0 + x1) // 2
	cut = y0 + int((y1 - y0) * 0.55)
	px = im.load()
	op = out.load()
	# clear bottom band then redraw shifted
	for y in range(cut, im.size[1]):
		for x in range(im.size[0]):
			op[x, y] = (0, 0, 0, 0)
	for y in range(cut, y1):
		for x in range(x0, x1):
			r, g, b, a = px[x, y]
			if a < THR:
				continue
			dy = left_dy if x < mid else right_dy
			ny = y + dy
			if 0 <= ny < CH and 0 <= x < CW:
				op[x, ny] = (r, g, b, a)
	return out


def put_wing(canvas: Image.Image, wing: Image.Image, sx: float, sy: float, anchor_y: int, dx: int = 0) -> None:
	w = scale_ext(wing, sx, sy)
	if w.size[1] > 56:
		s = 56 / w.size[1]
		w = w.resize((max(1, int(w.size[0] * s)), 56), Image.NEAREST)
	wx = CW // 2 - w.size[0] // 2 + dx
	wy = max(2, anchor_y - w.size[1] + 8)
	wx = max(1, min(CW - w.size[0] - 1, wx))
	canvas.alpha_composite(w, (wx, wy))


def frame_solid(
	full: Image.Image,
	wing: Image.Image,
	*,
	lift: int = 0,
	dx: int = 0,
	body: Image.Image | None = None,
	wsx: float = 1.0,
	wsy: float = 1.0,
	sh_w: int = 24,
	wing_on: bool = True,
) -> Image.Image:
	out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	out.alpha_composite(shadow(FOOT + 2, sh_w, 4 if lift > 10 else 6))
	foot = FOOT - lift
	src = body if body is not None else full
	_, top_y = paste_foot(out, src, foot, dx=dx)
	if wing_on and wsx > 0.05 and wsy > 0.05:
		put_wing(out, wing, wsx, wsy, top_y + 12, dx=dx)
	return out


def fit_safe(base: Image.Image, top_margin: int = 22, bottom_margin: int = 8) -> Image.Image:
	"""Shrink tall ship sprites so idle has headroom; fly can then rise past idle top."""
	ext = extract(base)
	max_h = CH - top_margin - bottom_margin
	max_w = CW - 10
	sx = min(1.0, max_w / max(1, ext.size[0]), max_h / max(1, ext.size[1]))
	if sx < 0.999:
		ext = ext.resize(
			(max(1, int(ext.size[0] * sx)), max(1, int(ext.size[1] * sx))),
			Image.NEAREST,
		)
	out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	x = (CW - ext.size[0]) // 2
	y = FOOT - bottom_margin - ext.size[1]
	y = max(top_margin, min(y, FOOT - bottom_margin - ext.size[1]))
	y = max(top_margin, y)
	out.alpha_composite(ext, (x, y))
	return out


def build_clips(base: Image.Image) -> dict[str, Image.Image]:
	full = fit_safe(base.convert("RGBA"))
	wing = wing_overlay(full)
	clips: dict[str, Image.Image] = {}

	# idle: solid base only for fold; open = extra membrane (base already has wings)
	clips["idle_0"] = frame_solid(full, wing, wsx=0.0, wsy=0.0, wing_on=False)
	clips["idle_1"] = frame_solid(full, wing, lift=2, wsx=1.35, wsy=1.75, wing_on=True)

	for i in range(4):
		phases = [(-9, 7), (-2, 2), (9, -7), (2, -2)]
		ldy, rdy = phases[i]
		walk_body = shear_bottom(full, ldy, rdy)
		bob = 3 if i % 2 else 0
		wsy = 1.15 if i % 2 == 0 else 0.8
		dx = [-5, 0, 5, 0][i]
		clips[f"walk_{i}"] = frame_solid(
			full, wing, body=walk_body, lift=bob, dx=dx, wsx=1.0, wsy=wsy, wing_on=True
		)

	FLY = 22
	fly_wsy = [1.75, 1.15, 0.6, 1.25]
	fly_wsx = [1.0, 1.15, 1.3, 1.05]
	for i in range(4):
		clips[f"fly_{i}"] = frame_solid(
			full, wing, lift=FLY, wsx=fly_wsx[i], wsy=fly_wsy[i], sh_w=14, wing_on=True
		)

	# attack: wind-up back / lunge forward (spell cast)
	atk = [(10, 1.1, 1.4), (-14, 1.25, 0.9), (-3, 1.0, 1.1)]
	for i, (dx, wsx, wsy) in enumerate(atk):
		lean = full.rotate([-8, 6, 0][i], resample=Image.NEAREST, expand=False)
		clips[f"attack_{i}"] = frame_solid(
			full, wing, body=lean, dx=dx, wsx=wsx, wsy=wsy, wing_on=True
		)

	def death(i: int) -> Image.Image:
		src = extract(full)
		out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
		out.alpha_composite(shadow(FOOT + 4, 36, 7))
		ang = [25, 55, 90][i]
		rot = src.rotate(ang, resample=Image.NEAREST, expand=True)
		if i < 2:
			s = min((CW - 8) / rot.size[0], (CH - 18) / rot.size[1], 1.0)
			rot = rot.resize((max(1, int(rot.size[0] * s)), max(1, int(rot.size[1] * s))), Image.NEAREST)
			x = (CW - rot.size[0]) // 2 + (4 if i else 2)
			y = FOOT - rot.size[1] + (4 if i == 1 else 0)
			out.alpha_composite(rot, (max(1, x), max(2, y)))
		else:
			nw = min(CW - 8, max(52, int(rot.size[0] * 1.05)))
			nh = max(12, min(20, int(rot.size[1] * 0.4)))
			rot = rot.resize((nw, nh), Image.NEAREST)
			x = (CW - nw) // 2
			y = FOOT - nh + 4
			out.alpha_composite(rot, (x, max(2, y)))
		return out

	for i in range(3):
		clips[f"death_{i}"] = death(i)
	return clips


def write_compare(uid: int, folder: str) -> None:
	names = ["idle_0", "walk_0", "walk_2", "fly_0", "fly_2", "attack_0", "attack_1", "death_2"]
	cell = 192
	sheet = Image.new("RGBA", (cell * len(names) + 8, cell + 24), (0, 0, 0, 255))
	d = ImageDraw.Draw(sheet)
	for i, n in enumerate(names):
		p = os.path.join(folder, f"{n}.png")
		if not os.path.isfile(p):
			continue
		im = Image.open(p).convert("RGBA").resize((cell, cell), Image.NEAREST)
		sheet.alpha_composite(im, (4 + i * cell, 20))
		d.text((4 + i * cell, 2), n, fill=(255, 230, 80, 255))
	out = os.path.join(HAND, f"CUTOUT_COMPARE_{uid}.png")
	sheet.save(out)
	print("compare", out)


def write_eye(uid: int, folder: str) -> None:
	names = [
		"idle_0", "idle_1", "walk_0", "walk_1", "walk_2", "walk_3",
		"fly_0", "fly_1", "fly_2", "fly_3",
		"attack_0", "attack_1", "attack_2",
		"death_0", "death_1", "death_2",
	]
	cols = 8
	cw, ch = CW, CH
	cellx, celly = cw + 10, ch + 22
	rows = (len(names) + cols - 1) // cols
	out = Image.new("RGB", (cols * cellx + 8, rows * celly + 8), (210, 215, 225))
	dr = ImageDraw.Draw(out)
	for i, n in enumerate(names):
		p = os.path.join(folder, f"{n}.png")
		if not os.path.isfile(p):
			continue
		im = Image.open(p).convert("RGBA")
		bg = Image.new("RGBA", (cw, ch), (190, 200, 210, 255))
		bg.alpha_composite(im)
		x = 4 + (i % cols) * cellx
		y = 4 + (i // cols) * celly + 16
		out.paste(bg.convert("RGB"), (x, y))
		dr.text((x, y - 14), n, fill=(10, 10, 30))
	path = os.path.join(HAND, f"CUTOUT_EYE_{uid}.png")
	out.save(path)
	out.resize((out.width * 2, out.height * 2), Image.NEAREST).save(path.replace(".png", "_x2.png"))
	print("eye", path)


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--units", default="14")
	ap.add_argument("--install", action="store_true", help="copy candidates → unit folder for promote")
	args = ap.parse_args()
	for uid in [int(x) for x in args.units.split(",") if x.strip()]:
		base_path = os.path.join(SHIP, f"unit_{uid}.png")
		base = Image.open(base_path).convert("RGBA")
		clips = build_clips(base)
		cand = os.path.join(HAND, f"unit_{uid}", "candidates")
		os.makedirs(cand, exist_ok=True)
		for name, fr in clips.items():
			fr.save(os.path.join(cand, f"{name}.png"))
			print("cand", uid, name)
		write_compare(uid, cand)
		write_eye(uid, cand)
		if args.install:
			dest = os.path.join(HAND, f"unit_{uid}")
			for name in clips:
				shutil.copy2(os.path.join(cand, f"{name}.png"), os.path.join(dest, f"{name}.png"))
			print("installed to", dest)
	print("DONE — review CUTOUT_EYE_*_x2.png ; promote only after eye PASS")


if __name__ == "__main__":
	main()
