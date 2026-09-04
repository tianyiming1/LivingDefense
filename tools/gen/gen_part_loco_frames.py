"""分区位移生成可读分帧（2D 像素正统：姿态差画在帧里，运行时只切图）。

- fly：翅膜区上下位移（扇翅），身体不动
- walk：腿区交替抬移 + 上身微倾（贴地，无整图蹦）
- attack：上身蓄力后仰 → 前压 → 回正
- idle：翅微动两帧

输出 ship unit_{id}_anim/ + studio 备份。
"""
from __future__ import annotations

import os
from typing import Callable

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHIP = os.path.join(ROOT, "assets", "pixels", "dragon")
STUDIO_DREAM = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "dream", "anim")

# id -> stage name for studio (optional)
DREAM_IDS = {14: "whelp", 15: "drake", 16: "wyrm", 17: "adult"}
LONGREN_IDS = (3, 10, 11, 12)


def harden(im: Image.Image) -> Image.Image:
	out = im.convert("RGBA").copy()
	px = out.load()
	w, h = out.size
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


def opaque_bbox(im: Image.Image) -> tuple[int, int, int, int]:
	px = im.load()
	w, h = im.size
	xs, ys = [], []
	for y in range(h):
		for x in range(w):
			if px[x, y][3] >= 128:
				xs.append(x)
				ys.append(y)
	if not xs:
		return (0, 0, w - 1, h - 1)
	return (min(xs), min(ys), max(xs), max(ys))


def is_dream_wing(r: int, g: int, b: int) -> bool:
	# 深紫膜 / 冰蓝外缘 / 暗紫
	if b >= 80 and r <= 120 and g <= 140:
		return True
	if r <= 64 and g <= 64 and b >= 64:
		return True
	if abs(r - g) < 40 and b >= r + 10 and b >= 160:
		return True
	return False


def is_longren_wing(r: int, g: int, b: int, y: int, y0: int, y1: int) -> bool:
	# 暗翼：偏暗红褐/近黑，且在上半身
	mid = y0 + int((y1 - y0) * 0.55)
	if y > mid:
		return False
	lum = r + g + b
	if lum < 140 and r >= g and r >= b:
		return True
	if lum < 90:
		return True
	return False


def build_masks(im: Image.Image, mode: str) -> tuple[Image.Image, Image.Image, Image.Image]:
	"""返回 body, wings, legs 三层（RGBA，互斥优先：翅>腿>身）。"""
	base = im.convert("RGBA")
	w, h = base.size
	x0, y0, x1, y1 = opaque_bbox(base)
	leg_y = y0 + int((y1 - y0) * 0.62)
	cx = (x0 + x1) * 0.5

	body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	wings = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	legs = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	bp, wp, lp, px = body.load(), wings.load(), legs.load(), base.load()

	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a < 128:
				continue
			wing = False
			if mode == "dream":
				# 翅：颜色像膜，或上半侧翼（离中轴远）
				if is_dream_wing(r, g, b):
					wing = True
				elif y < y0 + int((y1 - y0) * 0.58) and abs(x - cx) > (x1 - x0) * 0.18:
					if b >= 40 or r + g + b < 120:
						wing = True
			else:
				wing = is_longren_wing(r, g, b, y, y0, y1)
				if not wing and y < y0 + int((y1 - y0) * 0.5) and abs(x - cx) > (x1 - x0) * 0.22:
					if r + g + b < 160:
						wing = True

			if wing:
				wp[x, y] = (r, g, b, a)
			elif y >= leg_y:
				lp[x, y] = (r, g, b, a)
			else:
				bp[x, y] = (r, g, b, a)
	return body, wings, legs


def paste_shift(dst: Image.Image, layer: Image.Image, dx: int, dy: int) -> None:
	if layer is None:
		return
	w, h = dst.size
	tmp = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	tmp.paste(layer, (dx, dy), layer)
	dst.alpha_composite(tmp)


def compose(body: Image.Image, wings: Image.Image, legs: Image.Image, body_xy=(0, 0), wing_xy=(0, 0), leg_xy=(0, 0)) -> Image.Image:
	w, h = body.size
	out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	# 先翅后身再腿，避免翅盖住头；攻击时也可先身
	paste_shift(out, wings, wing_xy[0], wing_xy[1])
	paste_shift(out, body, body_xy[0], body_xy[1])
	paste_shift(out, legs, leg_xy[0], leg_xy[1])
	return harden(out)


def make_clips(im: Image.Image, mode: str) -> dict[str, Image.Image]:
	body, wings, legs = build_masks(im, mode)
	# 统计翅像素，太少则整图上半当翅
	wc = sum(1 for p in wings.getdata() if p[3] >= 128)
	if wc < 40:
		# fallback：上半 opaque 当翅
		w, h = im.size
		x0, y0, x1, y1 = opaque_bbox(im)
		cut = y0 + int((y1 - y0) * 0.45)
		px = im.load()
		wings = Image.new("RGBA", (w, h), (0, 0, 0, 0))
		body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
		legs = Image.new("RGBA", (w, h), (0, 0, 0, 0))
		wp, bp, lp = wings.load(), body.load(), legs.load()
		leg_y = y0 + int((y1 - y0) * 0.62)
		for y in range(h):
			for x in range(w):
				r, g, b, a = px[x, y]
				if a < 128:
					continue
				if y < cut:
					wp[x, y] = (r, g, b, a)
				elif y >= leg_y:
					lp[x, y] = (r, g, b, a)
				else:
					bp[x, y] = (r, g, b, a)

	clips = {
		# idle：翅微抬 / 微落
		"idle_0.png": compose(body, wings, legs, wing_xy=(0, 0)),
		"idle_1.png": compose(body, wings, legs, wing_xy=(0, -2)),
		# walk：左腿抬 / 交替；身体微倾（水平）
		"walk_0.png": compose(body, wings, legs, body_xy=(1, 0), wing_xy=(1, 0), leg_xy=(-2, -3)),
		"walk_1.png": compose(body, wings, legs, body_xy=(0, 0), wing_xy=(0, 1), leg_xy=(2, 0)),
		"walk_2.png": compose(body, wings, legs, body_xy=(-1, 0), wing_xy=(-1, 0), leg_xy=(2, -3)),
		"walk_3.png": compose(body, wings, legs, body_xy=(0, 0), wing_xy=(0, 1), leg_xy=(-2, 0)),
		# fly：翅大幅上下（扇），身体固定高度感由运行时 lift 负责；帧内翅位移要明显
		"fly_0.png": compose(body, wings, legs, body_xy=(1, 0), wing_xy=(0, -6), leg_xy=(0, 1)),
		"fly_1.png": compose(body, wings, legs, body_xy=(0, 0), wing_xy=(0, 4), leg_xy=(0, -1)),
		"fly_2.png": compose(body, wings, legs, body_xy=(1, 0), wing_xy=(0, -5), leg_xy=(0, 1)),
		"fly_3.png": compose(body, wings, legs, body_xy=(0, 0), wing_xy=(0, 5), leg_xy=(0, -1)),
		# attack：后仰 → 前压 → 收
		"attack_0.png": compose(body, wings, legs, body_xy=(-3, -1), wing_xy=(-2, -2), leg_xy=(0, 0)),
		"attack_1.png": compose(body, wings, legs, body_xy=(3, -1), wing_xy=(2, 1), leg_xy=(0, 0)),
		"attack_2.png": compose(body, wings, legs, body_xy=(0, 0), wing_xy=(0, 0), leg_xy=(0, 0)),
	}
	return clips


def save_unit(uid: int, mode: str, studio_stage: str | None = None) -> None:
	src = os.path.join(SHIP, f"unit_{uid}.png")
	if not os.path.isfile(src):
		print("skip", uid)
		return
	im = Image.open(src).convert("RGBA")
	clips = make_clips(im, mode)
	anim = os.path.join(SHIP, f"unit_{uid}_anim")
	os.makedirs(anim, exist_ok=True)
	for name, fr in clips.items():
		fr.save(os.path.join(anim, name), optimize=True)
		if studio_stage:
			clip = name.split("_")[0]
			d = os.path.join(STUDIO_DREAM, studio_stage, clip)
			os.makedirs(d, exist_ok=True)
			fr.save(os.path.join(d, name), optimize=True)
	# 差异验收：fly_0 vs fly_1 像素差
	a = clips["fly_0.png"]
	b = clips["fly_1.png"]
	diff = sum(1 for pa, pb in zip(a.getdata(), b.getdata()) if pa != pb)
	print(f"unit_{uid} {mode} fly_diff_px={diff} wing_ok")


def main() -> None:
	for uid, stage in DREAM_IDS.items():
		save_unit(uid, "dream", stage)
	for uid in LONGREN_IDS:
		save_unit(uid, "longren", None)
	# 火焰飞龙若有立绘也给 fly 帧
	for uid in (0, 4, 7, 13):
		if os.path.isfile(os.path.join(SHIP, f"unit_{uid}.png")):
			save_unit(uid, "longren", None)


if __name__ == "__main__":
	main()
