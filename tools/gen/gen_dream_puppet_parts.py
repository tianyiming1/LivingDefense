"""Dream Path A: puppet parts — body core + left/right wings.

body = ship sprite with wing membrane cleared (shoulder stub kept → no hole at rest)
wing_l / wing_r = membrane split by midline, rotate at shared shoulder

Usage:
  python tools/gen/gen_dream_puppet_parts.py --units 14,15,16,17
"""
from __future__ import annotations

import argparse
import json
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHIP = os.path.join(ROOT, "assets", "pixels", "dragon")
STUDIO = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "dream", "hand_anim")
THR = 40
STUB_R = 8


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


def is_dark_membrane(r: int, g: int, b: int, a: int) -> bool:
	"""深紫/靛翅膜（#2A1848 一带）；排除冰蓝白鳞与高光。"""
	if a < THR or r + g + b < 40:
		return False
	# 亮白/冰蓝鳞 → 非翅
	if r + g + b >= 420:
		return False
	if min(r, g, b) >= 140:
		return False
	# 暗紫靛：B 主导且不亮
	if b >= 70 and b >= r + 20 and b >= g and (r + g + b) < 340 and max(r, g, b) < 180:
		return True
	if r < 90 and g < 100 and 70 <= b <= 170 and (r + g) < b + 40:
		return True
	return False


def extract_wing_mask(base: Image.Image) -> Image.Image:
	"""空间优先：上半身中线两侧为翅；色板仅辅助抠暗膜。禁止把冰蓝躯干当翅。"""
	out = Image.new("RGBA", base.size, (0, 0, 0, 0))
	px, op = base.load(), out.load()
	bb0 = opaque_bbox(base)
	if not bb0:
		return out
	x0, y0, x1, y1 = bb0
	mid = (x0 + x1) / 2.0
	bw = max(8, x1 - x0)
	bh = max(8, y1 - y0)
	# 躯干柱：中线 ±18% 宽度保留给身体
	torso = max(5.0, bw * 0.18)
	y_wing_lo = y0
	y_wing_hi = y0 + int(bh * 0.58)
	for y in range(y_wing_lo, min(base.size[1], y_wing_hi + 1)):
		for x in range(x0, x1):
			r, g, b, a = px[x, y]
			if a < THR or r + g + b < 40:
				continue
			# 亮鳞/白高光不进翅
			if r + g + b >= 480 or (r >= 200 and g >= 200 and b >= 200):
				continue
			dx = abs(x - mid)
			lateral = dx >= torso
			membrane = is_dark_membrane(r, g, b, a)
			# 侧翼区：暗膜必取；偏青但非高亮的膜也可（半透明冰蓝翅）
			ice_membrane = (
				lateral
				and b >= g
				and b >= r + 8
				and 90 <= (r + g + b) <= 520
				and not (r >= 180 and g >= 180)
			)
			if membrane or (lateral and ice_membrane):
				op[x, y] = (r, g, b, a)
	# 若翅过少：强制上半侧翼带
	wb = opaque_bbox(out)
	need = max(80, int(bw * bh * 0.04))
	opaque_n = 0
	if wb:
		for y in range(wb[1], wb[3]):
			for x in range(wb[0], wb[2]):
				if op[x, y][3] > THR:
					opaque_n += 1
	if opaque_n < need:
		band = max(6, int(bw * 0.22))
		for y in range(y0, y0 + max(1, int(bh * 0.55))):
			for x in range(x0, x1):
				if abs(x - mid) < band:
					continue
				p = px[x, y]
				if p[3] > THR and sum(p[:3]) > 40 and sum(p[:3]) < 520:
					op[x, y] = p
	return out


def shoulder_pivot(body: Image.Image, wing: Image.Image) -> tuple[float, float]:
	bb = opaque_bbox(body)
	wb = opaque_bbox(wing)
	if not bb:
		return body.size[0] / 2.0, body.size[1] * 0.45
	cx = (bb[0] + bb[2]) / 2.0
	# fixed torso band — avoid hip-level pivot (looks like whole-body tilt)
	sy = bb[1] + (bb[3] - bb[1]) * 0.36
	if wb:
		cx = (wb[0] + wb[2]) / 2.0
		w_attach = wb[1] + (wb[3] - wb[1]) * 0.70
		# pull toward wing root but never below 42% of body
		hi = bb[1] + (bb[3] - bb[1]) * 0.42
		sy = min(max(w_attach, bb[1] + (bb[3] - bb[1]) * 0.28), hi)
	return float(cx), float(sy)


def split_lr(wing: Image.Image, mid_x: float) -> tuple[Image.Image, Image.Image]:
	wl = Image.new("RGBA", wing.size, (0, 0, 0, 0))
	wr = Image.new("RGBA", wing.size, (0, 0, 0, 0))
	px, pl, pr = wing.load(), wl.load(), wr.load()
	for y in range(wing.size[1]):
		for x in range(wing.size[0]):
			p = px[x, y]
			if p[3] < THR or sum(p[:3]) < 40:
				continue
			if x < mid_x:
				pl[x, y] = p
			else:
				pr[x, y] = p
	# ensure each side has something
	if opaque_bbox(wl) is None:
		wl = wing.copy()
	if opaque_bbox(wr) is None:
		wr = wing.copy()
	return wl, wr


def body_core(base: Image.Image, wing: Image.Image, sx: float, sy: float) -> Image.Image:
	"""Remove far wing pixels; keep stub near shoulder so rest pose seals."""
	out = base.copy()
	px, wp, op = base.load(), wing.load(), out.load()
	for y in range(base.size[1]):
		for x in range(base.size[0]):
			w = wp[x, y]
			if w[3] < THR or sum(w[:3]) < 40:
				continue
			if math.hypot(x - sx, y - sy) <= STUB_R:
				continue
			op[x, y] = (0, 0, 0, 0)
	return out


def write_preview(uid: int, body: Image.Image, wl: Image.Image, wr: Image.Image, sx: float, sy: float) -> None:
	os.makedirs(STUDIO, exist_ok=True)
	sheet = Image.new("RGBA", (96 * 4 + 40, 108 + 36), (28, 28, 36, 255))
	dr = ImageDraw.Draw(sheet)
	for i, ang in enumerate([0, -28, 28, 42]):
		canvas = Image.new("RGBA", (96, 108), (0, 0, 0, 0))
		canvas.alpha_composite(body)
		canvas.alpha_composite(wl.rotate(-ang, resample=Image.NEAREST, center=(sx, sy)))
		canvas.alpha_composite(wr.rotate(ang, resample=Image.NEAREST, center=(sx, sy)))
		bg = Image.new("RGBA", (96, 108), (190, 195, 205, 255))
		bg.alpha_composite(canvas)
		sheet.alpha_composite(bg, (10 + i * 100, 22))
		dr.ellipse((10 + i * 100 + int(sx) - 2, 22 + int(sy) - 2, 10 + i * 100 + int(sx) + 2, 22 + int(sy) + 2), fill=(255, 60, 60, 255))
		dr.text((10 + i * 100, 4), f"±{abs(ang)}", fill=(255, 220, 80, 255))
	path = os.path.join(STUDIO, f"PUPPET_PREVIEW_{uid}.png")
	sheet.save(path)
	print("preview", path)


def build_unit(uid: int) -> None:
	src = os.path.join(SHIP, f"unit_{uid}.png")
	base = Image.open(src).convert("RGBA")
	wing = extract_wing_mask(base)
	sx, sy = shoulder_pivot(base, wing)
	core = body_core(base, wing, sx, sy)
	base_n = sum(1 for p in base.getdata() if p[3] > THR and sum(p[:3]) > 40)
	core_n = sum(1 for p in core.getdata() if p[3] > THR and sum(p[:3]) > 40)
	# 安全阀：抠翅后身体过空 → 退回整图作 body（休息姿可读；扇翅略叠影）
	full_body = False
	if base_n > 0 and core_n / float(base_n) < 0.55:
		print(f"  WARN unit_{uid}: body too hollow ({core_n}/{base_n}); use full sprite as body")
		core = base.copy()
		full_body = True
	wl, wr = split_lr(wing, sx)
	bb = opaque_bbox(base)
	foot_y = float(bb[3] - 1) if bb else base.size[1] * 0.92
	out_dir = os.path.join(SHIP, f"unit_{uid}_puppet")
	os.makedirs(out_dir, exist_ok=True)
	core.save(os.path.join(out_dir, "body.png"))
	# 整图 body：禁止落盘翅部件，避免运行时叠出「两对翅膀」
	for old in ("wing.png", "wing_l.png", "wing_r.png"):
		op = os.path.join(out_dir, old)
		if os.path.isfile(op):
			os.remove(op)
	if not full_body:
		wing.save(os.path.join(out_dir, "wing.png"))
		wl.save(os.path.join(out_dir, "wing_l.png"))
		wr.save(os.path.join(out_dir, "wing_r.png"))
	meta = {
		"unit_id": uid,
		"canvas": [base.size[0], base.size[1]],
		"shoulder": [round(sx, 2), round(sy, 2)],
		"foot_y": round(foot_y, 2),
		"mode": "path_a_full_body_bob" if full_body else "path_a_dual_wing",
		"full_body": full_body,
		"stub_r": STUB_R,
		"parts": ["body"] if full_body else ["body", "wing_l", "wing_r", "wing"],
	}
	with open(os.path.join(out_dir, "meta.json"), "w", encoding="utf-8") as f:
		json.dump(meta, f, indent=2)
	write_preview(uid, core, wl, wr, sx, sy)
	wb = opaque_bbox(wing)
	print(f"unit_{uid}: shoulder=({sx:.1f},{sy:.1f}) wing={wb} -> {out_dir}")


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--units", default="14,15,16,17")
	args = ap.parse_args()
	for uid in [int(x) for x in args.units.split(",") if x.strip()]:
		build_unit(uid)
	print("DONE")


if __name__ == "__main__":
	main()
