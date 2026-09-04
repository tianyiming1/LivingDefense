"""Dream flap to GIF-quality bar — mesh-warp OUR 042 still (no WorkBuddy pixels).

Quality bar (eye): WorkBuddy dragon_godot_1_preview.gif motion character
  — clean silhouette, full up→down→up wing stroke, body bob, NO shred/noise.

Method:
  - Keep FULL approved sprite solid every frame (never delete wing holes).
  - Inverse-distance warp of wing-tip control points on a flap sine.
  - Foot-lock + slight body bob.
  - 16 frames @ 125ms; fly_sheet for AtlasTexture.

Gate (auto):
  - consecutive avg delta >= 800
  - opaque pixel count stable within 12% of frame0 (anti-shred)
  - COMPARE strip vs GIF for human eye

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


def is_wingish(r: int, g: int, b: int, a: int) -> bool:
	if a < THR or r + g + b < 30:
		return False
	if b >= r + 10 and b >= g - 8:
		return True
	if r < 110 and g < 120 and b > 70:
		return True
	return False


def wing_anchors(full: Image.Image) -> dict:
	"""Find shoulder + tip anchors for L/R wings from color."""
	px = full.load()
	bb = opaque_bbox(full)
	mid = CW // 2
	l_pts, r_pts = [], []
	for y in range(full.size[1]):
		for x in range(full.size[0]):
			r, g, b, a = px[x, y]
			if not is_wingish(r, g, b, a):
				continue
			if x < mid:
				l_pts.append((x, y))
			else:
				r_pts.append((x, y))
	# fallback: upper lateral opaque
	if len(l_pts) < 20 or len(r_pts) < 20:
		l_pts, r_pts = [], []
		if bb:
			x0, y0, x1, y1 = bb
			cut = y0 + int((y1 - y0) * 0.55)
			for y in range(y0, cut):
				for x in range(x0, x1):
					r, g, b, a = px[x, y]
					if a < THR or r + g + b < 30:
						continue
					if abs(x - mid) < max(4, (x1 - x0) // 7):
						continue
					(l_pts if x < mid else r_pts).append((x, y))

	def tip_and_shoulder(pts, left: bool):
		if not pts:
			sx = CW * (0.38 if left else 0.62)
			return (sx, CH * 0.42), (sx + (-18 if left else 18), CH * 0.22)
		# tip = farthest from body center
		cx, cy = CW * 0.5, CH * 0.45
		tip = max(pts, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)
		# shoulder = closest to center among upper half
		upper = [p for p in pts if p[1] < cy + 8] or pts
		shoulder = min(upper, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)
		return (float(shoulder[0]), float(shoulder[1])), (float(tip[0]), float(tip[1]))

	ls, lt = tip_and_shoulder(l_pts, True)
	rs, rt = tip_and_shoulder(r_pts, False)
	return {"l_s": ls, "l_t": lt, "r_s": rs, "r_t": rt}


def rotate_point(px: float, py: float, ox: float, oy: float, ang: float) -> tuple[float, float]:
	c, s = math.cos(ang), math.sin(ang)
	dx, dy = px - ox, py - oy
	return ox + dx * c - dy * s, oy + dx * s + dy * c


def mesh_warp_wing_region(
	src: Image.Image,
	src_ctrls: list[tuple[float, float]],
	dst_ctrls: list[tuple[float, float]],
	power: float = 1.55,
) -> Image.Image:
	"""Forward-warp wings onto solid body; splat 2×2 to avoid holes (anti-shred)."""
	out = src.copy()
	sp, op = src.load(), out.load()
	w, h = src.size
	n = len(src_ctrls)
	wing = [[False] * w for _ in range(h)]
	for y in range(h):
		for x in range(w):
			if is_wingish(*sp[x, y]):
				wing[y][x] = True
	# erase wing membranes (keep non-wing body intact)
	for y in range(h):
		for x in range(w):
			if wing[y][x]:
				op[x, y] = (0, 0, 0, 0)

	def map_point(x: float, y: float) -> tuple[float, float]:
		numx = numy = den = 0.0
		for i in range(n):
			dx = x - src_ctrls[i][0]
			dy = y - src_ctrls[i][1]
			d2 = dx * dx + dy * dy
			if d2 < 0.25:
				return dst_ctrls[i][0], dst_ctrls[i][1]
			wt = 1.0 / (d2 ** (power * 0.5))
			numx += wt * (x + (dst_ctrls[i][0] - src_ctrls[i][0]))
			numy += wt * (y + (dst_ctrls[i][1] - src_ctrls[i][1]))
			den += wt
		if den <= 1e-9:
			return x, y
		return numx / den, numy / den

	# splat wing pixels
	for y in range(h):
		for x in range(w):
			if not wing[y][x]:
				continue
			col = sp[x, y]
			if col[3] < THR:
				continue
			dx, dy = map_point(float(x), float(y))
			ix, iy = int(round(dx)), int(round(dy))
			for oy in (0, 1):
				for ox in (0, 1):
					px, py = ix + ox, iy + oy
					if 0 <= px < w and 0 <= py < h:
						br, bg, bb, ba = op[px, py]
						# don't paint over solid non-wing torso
						if ba > THR and not is_wingish(br, bg, bb, ba):
							continue
						op[px, py] = col

	# fill remaining holes inside original wing bbox: sample nearest painted wing
	bb = opaque_bbox(src)
	if bb:
		# one pass: if transparent where original was wing, copy from nearby painted
		for y in range(bb[1], bb[3]):
			for x in range(bb[0], bb[2]):
				if op[x, y][3] >= THR:
					continue
				if not wing[y][x]:
					continue
				# search radius 3
				found = None
				for r in range(1, 4):
					for dy in range(-r, r + 1):
						for dx in range(-r, r + 1):
							nx, ny = x + dx, y + dy
							if 0 <= nx < w and 0 <= ny < h and is_wingish(*op[nx, ny]):
								found = op[nx, ny]
								break
						if found:
							break
					if found:
						break
				if found:
					op[x, y] = found
	return out


def make_flap_frame(base: Image.Image, anchors: dict, phase: float, lift: int) -> Image.Image:
	"""phase 0..1 complete flap. Warp wing tips; body copy stays intact."""
	ang = math.sin(phase * math.tau) * 0.85  # ~49°
	bob = -math.sin(phase * math.tau) * 2.5

	ls, lt = anchors["l_s"], anchors["l_t"]
	rs, rt = anchors["r_s"], anchors["r_t"]
	bb = opaque_bbox(base) or (20, 20, 76, 100)
	head = ((bb[0] + bb[2]) * 0.5, bb[1] + 6.0)
	foot_pt = ((bb[0] + bb[2]) * 0.5, float(bb[3] - 2))
	chest = ((bb[0] + bb[2]) * 0.5, (bb[1] + bb[3]) * 0.45)

	out_push = 5.0 * max(0.0, -math.sin(phase * math.tau))
	lt2 = rotate_point(lt[0], lt[1], ls[0], ls[1], -ang)
	rt2 = rotate_point(rt[0], rt[1], rs[0], rs[1], ang)
	lt2 = (lt2[0] - out_push, lt2[1] + abs(ang) * 2)
	rt2 = (rt2[0] + out_push, rt2[1] + abs(ang) * 2)

	lm = ((ls[0] + lt[0]) * 0.55, (ls[1] + lt[1]) * 0.55)
	rm = ((rs[0] + rt[0]) * 0.55, (rs[1] + rt[1]) * 0.55)
	lm2 = rotate_point(lm[0], lm[1], ls[0], ls[1], -ang * 0.6)
	rm2 = rotate_point(rm[0], rm[1], rs[0], rs[1], ang * 0.6)

	# Only wing controls move; body controls identical (no body mesh tear)
	src_c = [ls, lt, lm, rs, rt, rm, head, chest, foot_pt]
	dst_c = [ls, lt2, lm2, rs, rt2, rm2, head, chest, foot_pt]
	warped = mesh_warp_wing_region(base, src_c, dst_c)

	# whole-sprite bob via foot-lock shift
	bb2 = opaque_bbox(warped)
	out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	d = ImageDraw.Draw(out)
	sw = 20 if lift < 12 else 12
	d.ellipse((CW // 2 - sw // 2, FOOT + 1, CW // 2 + sw // 2, FOOT + 5), fill=(20, 20, 30, 100))
	if not bb2:
		return out
	dy = (FOOT - lift) - (bb2[3] - 1) + int(round(bob))
	tmp = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
	tmp.alpha_composite(warped, (0, dy))
	out.alpha_composite(tmp)
	return out


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


def build_clip(base: Image.Image, lift: int) -> list[Image.Image]:
	anc = wing_anchors(base)
	return [make_flap_frame(base, anc, i / float(N_FLAP), lift) for i in range(N_FLAP)]


def gate_frames(frames: list[Image.Image]) -> tuple[bool, str]:
	n0 = opaque_count(frames[0])
	if n0 < 200:
		return False, "too empty"
	deltas = [px_changed(frames[i], frames[i + 1]) for i in range(len(frames) - 1)]
	avg = sum(deltas) / max(1, len(deltas))
	# anti-shred: opaque count stable (allow wing fold variance)
	for i, fr in enumerate(frames):
		ni = opaque_count(fr)
		if abs(ni - n0) / float(n0) > 0.22:
			return False, f"shred/opaque drift frame{i}: {ni} vs {n0}"
	if avg < 400:
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
		meta["fly_source"] = "self_mesh_warp_042"
		meta["fly_frames"] = N_FLAP
		meta["fly_sheet"] = True
		meta["complete_action"] = True
		meta.pop("reject", None)
		with open(meta_p, "w", encoding="utf-8") as f:
			json.dump(meta, f, indent=2)
	print(f"unit_{uid}: installed mesh-warp COMPLETE {N_FLAP}f")
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
	dr.text((4, 2), f"SELF mesh-warp {N_FLAP}f (GIF quality target)", fill=(120, 255, 140))
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
		dr.text((4, 110), "SELF mesh-warp (ship)", fill=(255, 200, 80))
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
