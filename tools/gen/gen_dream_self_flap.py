"""Dream flap — pivot-rotate OUR 042 still (no WorkBuddy pixels).

Quality bar: clean silhouette, full up→down→up wing stroke, body bob,
NO shred / splat 拖影 / 双翅叠影.

Method:
  - Spatial wing mask (lateral upper only; protect white torso / legs / tail).
  - Erase masked membrane from body, rotate L/R wings about shoulders (NEAREST).
  - Drop orphan debris blobs; hard contact shadow only.
  - 16 frames @ 125ms; fly_sheet for AtlasTexture.

Usage:
  python tools/gen/gen_dream_self_flap.py --units 14,15,16,17
"""
from __future__ import annotations

import argparse
import json
import math
import os

from PIL import Image, ImageDraw, ImageSequence

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHIP = os.path.join(ROOT, "assets", "pixels", "dragon")
DREAM = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "dream")
APPROVED = os.path.join(DREAM, "approved", "042_game.png")
HAND = os.path.join(DREAM, "hand_anim")
STUDIO = os.path.join(DREAM, "self_flap")
GIF_REF = r"C:\Users\asus\WorkBuddy\2026-09-04-09-00-43\dragon_godot_1_preview.gif"
CW, CH = 96, 108
FOOT = int(CH * 0.92)
THR = 28
N_FLAP = 16
FRAME_MS = 125
SCALES = {14: 0.55, 15: 0.70, 16: 0.85, 17: 1.0}


def rematte(im: Image.Image, thr: int = 18) -> Image.Image:
	im = im.convert("RGBA")
	px = im.load()
	for y in range(im.size[1]):
		for x in range(im.size[0]):
			r, g, b, a = px[x, y]
			if a < 8 or r + g + b <= thr:
				px[x, y] = (0, 0, 0, 0)
	return im


def opaque_bbox(im: Image.Image):
	px = im.load()
	xs, ys = [], []
	for y in range(im.size[1]):
		for x in range(im.size[0]):
			r, g, b, a = px[x, y]
			if a > THR and r + g + b > 30:
				xs.append(x)
				ys.append(y)
	if not xs:
		return None
	return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def opaque_count(im: Image.Image) -> int:
	px = im.load()
	n = 0
	for y in range(im.size[1]):
		for x in range(im.size[0]):
			r, g, b, a = px[x, y]
			if a > THR and r + g + b > 30:
				n += 1
	return n


def fit_to_canvas(im: Image.Image, scale: float) -> Image.Image:
	im = rematte(im)
	bb = opaque_bbox(im)
	if not bb:
		return Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	crop = im.crop(bb)
	sx = min(1.0, (CW - 6) / crop.size[0], (CH - 10) / crop.size[1]) * scale
	nw = max(1, int(round(crop.size[0] * sx)))
	nh = max(1, int(round(crop.size[1] * sx)))
	crop = crop.resize((nw, nh), Image.NEAREST)
	out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	x = (CW - nw) // 2
	y = FOOT - nh
	if y < 2:
		over = 2 - y
		nh2 = max(1, nh - over)
		nw2 = max(1, int(round(nw * (nh2 / float(nh)))))
		crop = crop.resize((nw2, nh2), Image.NEAREST)
		nw, nh = nw2, nh2
		x = (CW - nw) // 2
		y = FOOT - nh
	out.alpha_composite(crop, (x, max(2, y)))
	return out


def _drop_orphan_blobs(im: Image.Image, min_keep: int = 18) -> Image.Image:
	"""Remove tiny disconnected opaque blobs (warp debris / 拖影)."""
	w, h = im.size
	px = im.load()
	seen = [[False] * w for _ in range(h)]
	comps: list[list[tuple[int, int]]] = []
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if seen[y][x] or a <= THR or r + g + b <= 30:
				continue
			stack = [(x, y)]
			seen[y][x] = True
			comp: list[tuple[int, int]] = []
			while stack:
				cx, cy = stack.pop()
				comp.append((cx, cy))
				for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					nx, ny = cx + dx, cy + dy
					if not (0 <= nx < w and 0 <= ny < h) or seen[ny][nx]:
						continue
					rr, gg, bb, aa = px[nx, ny]
					if aa <= THR or rr + gg + bb <= 30:
						continue
					seen[ny][nx] = True
					stack.append((nx, ny))
			comps.append(comp)
	if not comps:
		return im
	comps.sort(key=len, reverse=True)
	for c in comps[1:]:
		if len(c) < min_keep:
			for x, y in c:
				px[x, y] = (0, 0, 0, 0)
	return im


def _spatial_wing_mask(full: Image.Image) -> list[list[bool]]:
	"""Lateral upper wing only — never white torso / legs / tail (anti-叠影 erase)."""
	px = full.load()
	bb = opaque_bbox(full) or (10, 10, CW - 10, CH - 10)
	x0, y0, x1, y1 = bb
	mid = (x0 + x1) // 2
	cut_y = y0 + int((y1 - y0) * 0.64)
	band = max(5, (x1 - x0) // 6)
	mask = [[False] * CW for _ in range(CH)]
	for y in range(y0, min(cut_y + 1, CH)):
		for x in range(x0, x1):
			if abs(x - mid) < band:
				continue
			r, g, b, a = px[x, y]
			if a < THR or r + g + b < 30:
				continue
			lum = r + g + b
			if lum > 500:  # white body core
				continue
			wingish = (
				(b >= r + 6 and b >= g - 14)
				or (r < 130 and g < 140 and b > 60)
				or (b > r and b > g and lum < 460)
			)
			if wingish:
				mask[y][x] = True
	# Dilate 2 into non-torso (clear residual membrane that causes 叠影拖影)
	out = [row[:] for row in mask]
	for y in range(CH):
		for x in range(CW):
			if not mask[y][x]:
				continue
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					nx, ny = x + dx, y + dy
					if not (0 <= nx < CW and 0 <= ny < CH):
						continue
					if abs(nx - mid) < max(3, band - 2):
						rr, gg, bb, aa = px[nx, ny]
						if aa > THR and rr + gg + bb > 480:
							continue  # protect white torso
					if ny > cut_y + 3:
						continue
					out[ny][nx] = True
	return out


def prepare_wing_rig(base: Image.Image) -> dict:
	"""Split body / L wing / R wing once; shoulders for pivot rotate."""
	px = base.load()
	mask = _spatial_wing_mask(base)
	body = base.copy()
	bp = body.load()
	left = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	right = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	lp, rp = left.load(), right.load()
	bb = opaque_bbox(base) or (20, 20, 76, 100)
	mid = (bb[0] + bb[2]) // 2
	l_pts: list[tuple[int, int]] = []
	r_pts: list[tuple[int, int]] = []
	for y in range(CH):
		for x in range(CW):
			if not mask[y][x]:
				continue
			col = px[x, y]
			bp[x, y] = (0, 0, 0, 0)
			if x < mid:
				lp[x, y] = col
				l_pts.append((x, y))
			else:
				rp[x, y] = col
				r_pts.append((x, y))

	def shoulder(pts: list[tuple[int, int]]) -> tuple[float, float]:
		if not pts:
			return float(mid), float(CH * 0.42)
		cx, cy = CW * 0.5, CH * 0.42
		upper = [p for p in pts if p[1] < cy + 12] or pts
		s = min(upper, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)
		return float(s[0]), float(s[1])

	return {
		"body": body,
		"left": left,
		"right": right,
		"l_s": shoulder(l_pts),
		"r_s": shoulder(r_pts),
		"n_l": len(l_pts),
		"n_r": len(r_pts),
	}


def _rotate_around(layer: Image.Image, pivot: tuple[float, float], deg: float) -> Image.Image:
	big = Image.new("RGBA", (CW * 3, CH * 3), (0, 0, 0, 0))
	big.alpha_composite(layer, (CW, CH))
	rot = big.rotate(deg, resample=Image.NEAREST, center=(pivot[0] + CW, pivot[1] + CH))
	return rot.crop((CW, CH, CW * 2, CH * 2))


def make_flap_frame(rig: dict, phase: float, lift: int) -> Image.Image:
	"""phase 0..1: pivot-rotate L/R wings (hard nearest, no mesh splat 拖影)."""
	ang_deg = math.sin(phase * math.tau) * 26.0  # ~±26°
	bob = -math.sin(phase * math.tau) * 1.5
	lw = _rotate_around(rig["left"], rig["l_s"], -ang_deg)
	rw = _rotate_around(rig["right"], rig["r_s"], ang_deg)
	warped = rig["body"].copy()
	warped.alpha_composite(lw)
	warped.alpha_composite(rw)
	warped = _drop_orphan_blobs(warped, min_keep=20)

	bb2 = opaque_bbox(warped)
	out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	# No soft under-body smear — tiny hard contact shadow only
	d = ImageDraw.Draw(out)
	sw = 14 if lift < 12 else 8
	d.ellipse((CW // 2 - sw // 2, FOOT + 2, CW // 2 + sw // 2, FOOT + 4), fill=(16, 16, 22, 180))
	if not bb2:
		return out
	dy = (FOOT - lift) - (bb2[3] - 1) + int(round(bob))
	tmp = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	tmp.alpha_composite(warped, (0, dy))
	out.alpha_composite(tmp)
	return _drop_orphan_blobs(out, min_keep=12)


def build_clip(base: Image.Image, lift: int) -> list[Image.Image]:
	rig = prepare_wing_rig(base)
	if rig["n_l"] < 30 or rig["n_r"] < 30:
		raise RuntimeError(f"wing mask too small L={rig['n_l']} R={rig['n_r']}")
	return [make_flap_frame(rig, i / float(N_FLAP), lift) for i in range(N_FLAP)]


def px_changed(a: Image.Image, b: Image.Image) -> int:
	pa, pb = a.load(), b.load()
	n = 0
	for y in range(a.size[1]):
		for x in range(a.size[0]):
			if pa[x, y] != pb[x, y]:
				n += 1
	return n


def write_sheet(frames: list[Image.Image], path: str) -> None:
	sheet = Image.new("RGBA", (CW * len(frames), CH), (0, 0, 0, 0))
	for i, fr in enumerate(frames):
		sheet.alpha_composite(fr, (i * CW, 0))
	sheet.save(path)


def clear_anim(folder: str) -> None:
	if not os.path.isdir(folder):
		return
	for n in list(os.listdir(folder)):
		if n.endswith(".png") and (
			n.startswith(("fly_", "idle_", "walk_", "attack_", "death_")) or n.endswith("_sheet.png")
		):
			os.remove(os.path.join(folder, n))


def gate_frames(frames: list[Image.Image]) -> tuple[bool, str]:
	n0 = opaque_count(frames[0])
	if n0 < 200:
		return False, "too empty"
	deltas = [px_changed(frames[i], frames[i + 1]) for i in range(len(frames) - 1)]
	avg = sum(deltas) / max(1, len(deltas))
	# anti-shred: forbid big *loss*; mild gain OK (wing unfold). Big gain = smear/拖影.
	for i, fr in enumerate(frames):
		ni = opaque_count(fr)
		if ni < n0 * 0.72:
			return False, f"shred/opaque loss frame{i}: {ni} vs {n0}"
		if ni > n0 * 1.38:
			return False, f"smear/opaque inflate frame{i}: {ni} vs {n0}"
	if avg < 220:
		return False, f"motion too weak avg_delta={avg:.0f}"
	return True, f"ok avg_delta={avg:.0f} opaque0={n0}"


def install_unit(uid: int) -> list[Image.Image]:
	src = Image.open(APPROVED).convert("RGBA")
	full = fit_to_canvas(src, SCALES.get(uid, 1.0))
	fly = build_clip(full, lift=12)
	idle = build_clip(full, lift=4)
	ok, msg = gate_frames(fly)
	print(f"unit_{uid}: GATE {'PASS' if ok else 'FAIL'} — {msg}")
	if not ok:
		raise RuntimeError(f"unit_{uid} flap gate fail: {msg}")

	attack = [fly[0], fly[4], fly[8], fly[12]]
	death = [fly[12], fly[13], fly[14], fly[15]]

	hand = os.path.join(HAND, f"unit_{uid}")
	ship = os.path.join(SHIP, f"unit_{uid}_anim")
	os.makedirs(hand, exist_ok=True)
	os.makedirs(ship, exist_ok=True)
	clear_anim(hand)
	clear_anim(ship)
	for i in range(N_FLAP):
		for name, fr in ((f"fly_{i}.png", fly[i]), (f"idle_{i}.png", idle[i]), (f"walk_{i}.png", fly[i])):
			fr.save(os.path.join(hand, name))
			fr.save(os.path.join(ship, name))
	for i, fr in enumerate(attack):
		fr.save(os.path.join(hand, f"attack_{i}.png"))
		fr.save(os.path.join(ship, f"attack_{i}.png"))
	for i, fr in enumerate(death):
		fr.save(os.path.join(hand, f"death_{i}.png"))
		fr.save(os.path.join(ship, f"death_{i}.png"))
	write_sheet(fly, os.path.join(hand, "fly_sheet.png"))
	write_sheet(fly, os.path.join(ship, "fly_sheet.png"))
	write_sheet(idle, os.path.join(ship, "idle_sheet.png"))
	idle[0].save(os.path.join(SHIP, f"unit_{uid}.png"))

	meta_p = os.path.join(SHIP, f"unit_{uid}_puppet", "meta.json")
	if os.path.isfile(meta_p):
		with open(meta_p, encoding="utf-8") as f:
			meta = json.load(f)
		meta["prefer_frames"] = True
		meta["fly_source"] = "self_pivot_rotate_042"
		meta["fly_frames"] = N_FLAP
		meta["fly_sheet"] = True
		meta["complete_action"] = True
		meta.pop("reject", None)
		with open(meta_p, "w", encoding="utf-8") as f:
			json.dump(meta, f, indent=2)
	print(f"unit_{uid}: installed pivot-rotate COMPLETE {N_FLAP}f")
	return fly


def write_preview_and_compare(unit17: list[Image.Image]) -> None:
	os.makedirs(STUDIO, exist_ok=True)
	gif = []
	for fr in unit17:
		bg = Image.new("RGBA", (CW, CH), (0, 0, 0, 255))
		bg.alpha_composite(fr)
		gif.append(bg.resize((CW * 3, CH * 3), Image.NEAREST).convert("P", palette=Image.ADAPTIVE))
	path = os.path.join(STUDIO, "SELF_FLAP_GATE_17.gif")
	gif[0].save(path, save_all=True, append_images=gif[1:], duration=FRAME_MS, loop=0)

	cell = 60
	strip = Image.new("RGB", (cell * N_FLAP, cell + 24), (16, 16, 22))
	dr = ImageDraw.Draw(strip)
	dr.text((4, 2), f"SELF pivot-rotate {N_FLAP}f (no splat trail)", fill=(120, 255, 140))
	for i, fr in enumerate(unit17):
		bg = Image.new("RGBA", (cell, cell), (0, 0, 0, 255))
		s = fr.resize((cell, int(cell * CH / CW)), Image.NEAREST)
		bg.alpha_composite(s, (0, (cell - s.size[1]) // 2))
		strip.paste(bg.convert("RGB"), (i * cell, 18))
	strip.save(os.path.join(STUDIO, "SELF_FLAP_STRIP.png"))

	# COMPARE vs GIF ref (eye bar) — GIF used only as reference, not ship
	if os.path.isfile(GIF_REF):
		g = Image.open(GIF_REF)
		gfr = []
		for fr in ImageSequence.Iterator(g):
			gfr.append(fit_to_canvas(fr.convert("RGBA"), 1.0))
		gfr = gfr[:8]
		cmp = Image.new("RGB", (96 * 8, 96 * 2 + 36), (12, 12, 18))
		dr = ImageDraw.Draw(cmp)
		dr.text((4, 2), "GIF ref (quality bar — not shipped)", fill=(120, 255, 140))
		dr.text((4, 110), "SELF pivot-rotate (ship)", fill=(255, 200, 80))
		for i in range(8):
			gg = Image.new("RGBA", (96, 96), (0, 0, 0, 255))
			gg.alpha_composite(gfr[i], (0, -6))
			cmp.paste(gg.convert("RGB"), (i * 96, 16))
			si = unit17[i * 2]
			ss = Image.new("RGBA", (96, 96), (0, 0, 0, 255))
			ss.alpha_composite(si, (0, -6))
			cmp.paste(ss.convert("RGB"), (i * 96, 116))
		cmp.save(os.path.join(STUDIO, "COMPARE_GIF_VS_SELF.png"))
		print("compare", os.path.join(STUDIO, "COMPARE_GIF_VS_SELF.png"))
	print("preview", path)


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--units", default="14,15,16,17")
	args = ap.parse_args()
	if not os.path.isfile(APPROVED):
		raise SystemExit(f"missing {APPROVED}")
	unit17 = None
	for uid in [int(x) for x in args.units.split(",") if x.strip()]:
		fly = install_unit(uid)
		if uid == 17:
			unit17 = fly
	if unit17:
		write_preview_and_compare(unit17)
	print("DONE — mesh-warp self flap (GIF bar compare written)")


if __name__ == "__main__":
	main()
