"""Install COMPLETE WorkBuddy action (fly 8 + land 8 = 16 frames).

Source (WorkBuddy dragon_godot_spriteframes.tres):
  fly  = dragon_godot_1_frames (loop)
  land = dragon_godot_2_frames (one-shot complete)
User gate: 8-frame-only felt incomplete — need full action.

Installs fly/idle/walk_0..15 + fly_sheet (16×96) for AtlasTexture.
FPS target in engine: 8 → full cycle ≈ 2.0s.

Usage:
  python tools/gen/install_workbuddy_fly.py --units 14,15,16,17
"""
from __future__ import annotations

import argparse
import json
import os

from PIL import Image, ImageDraw, ImageSequence

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WB_DEFAULT = r"C:\Users\asus\WorkBuddy\2026-09-04-09-00-43"
SHIP = os.path.join(ROOT, "assets", "pixels", "dragon")
HAND = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "dream", "hand_anim")
STUDIO = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "dream", "workbuddy")
CW, CH = 96, 108
FOOT = int(CH * 0.92)
THR = 12
SCALES = {14: 0.55, 15: 0.70, 16: 0.85, 17: 1.0}
FRAME_MS = 125  # ~8 FPS, 16 frames → ~2.0s complete action


def rematte(im: Image.Image) -> Image.Image:
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


def union_bbox(bbs):
	bbs = [b for b in bbs if b]
	if not bbs:
		return None
	return (
		min(b[0] for b in bbs),
		min(b[1] for b in bbs),
		max(b[2] for b in bbs),
		max(b[3] for b in bbs),
	)


def load_complete_action(wb: str) -> list[Image.Image]:
	"""fly(g1)×8 + land(g2)×8 = 16-frame complete action."""
	frames: list[Image.Image] = []
	for folder in ("dragon_godot_1_frames", "dragon_godot_2_frames"):
		d = os.path.join(wb, folder)
		if not os.path.isdir(d):
			raise FileNotFoundError(d)
		for i in range(8):
			p = os.path.join(d, f"frame_{i:02d}.png")
			frames.append(rematte(Image.open(p).convert("RGBA")))
	# Fallback: frames/ 00..15 or landing gif
	if len(frames) < 16:
		fr = os.path.join(wb, "frames")
		if os.path.isdir(fr):
			frames = [
				rematte(Image.open(os.path.join(fr, f"frame_{i:02d}.png")).convert("RGBA"))
				for i in range(16)
			]
	if len(frames) < 16:
		raise RuntimeError(f"need 16 complete-action frames, got {len(frames)}")
	return frames[:16]


def fit_locked(srcs: list[Image.Image], scale: float) -> list[Image.Image]:
	ub = union_bbox([opaque_bbox(s) for s in srcs])
	if not ub:
		return [Image.new("RGBA", (CW, CH), (0, 0, 0, 0)) for _ in srcs]
	x0 = max(0, ub[0] - 1)
	y0 = max(0, ub[1] - 1)
	x1 = min(srcs[0].size[0], ub[2] + 1)
	y1 = min(srcs[0].size[1], ub[3] + 1)
	cw, ch = x1 - x0, y1 - y0
	sx = min(1.0, (CW - 4) / cw, (CH - 4) / ch) * scale
	nw = max(1, int(round(cw * sx)))
	nh = max(1, int(round(ch * sx)))
	paste_y = FOOT - nh
	if paste_y < 2:
		over = 2 - paste_y
		nh2 = max(1, nh - over)
		nw2 = max(1, int(round(nw * (nh2 / float(nh)))))
		nw, nh = nw2, nh2
		paste_y = FOOT - nh
	paste_x = (CW - nw) // 2
	out = []
	for s in srcs:
		crop = s.crop((x0, y0, x1, y1)).resize((nw, nh), Image.NEAREST)
		canvas = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
		canvas.alpha_composite(crop, (paste_x, max(2, paste_y)))
		out.append(canvas)
	return out


def write_sheet(frames: list[Image.Image], path: str) -> None:
	sheet = Image.new("RGBA", (CW * len(frames), CH), (0, 0, 0, 0))
	for i, fr in enumerate(frames):
		sheet.alpha_composite(fr, (i * CW, 0))
	sheet.save(path)


def clear_anim_pngs(folder: str) -> None:
	if not os.path.isdir(folder):
		return
	for n in list(os.listdir(folder)):
		if not n.endswith(".png"):
			continue
		if n.startswith(("fly_", "idle_", "walk_", "attack_", "death_")) or n.endswith("_sheet.png"):
			os.remove(os.path.join(folder, n))


def install_unit(uid: int, srcs: list[Image.Image]) -> list[Image.Image]:
	scale = SCALES.get(uid, 1.0)
	fitted = fit_locked(srcs, scale)
	assert len(fitted) == 16
	fly = fitted  # complete: flap then land
	# attack = land half; death = last 4 of land held
	attack = fitted[8:11] + [fitted[11]]  # 4 poses from land
	death = [fitted[12], fitted[13], fitted[14], fitted[15]]

	hand = os.path.join(HAND, f"unit_{uid}")
	ship = os.path.join(SHIP, f"unit_{uid}_anim")
	os.makedirs(hand, exist_ok=True)
	os.makedirs(ship, exist_ok=True)
	clear_anim_pngs(hand)
	clear_anim_pngs(ship)

	for i, fr in enumerate(fly):
		for name in (f"fly_{i}.png", f"idle_{i}.png", f"walk_{i}.png"):
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
	write_sheet(fly, os.path.join(hand, "idle_sheet.png"))
	write_sheet(fly, os.path.join(ship, "idle_sheet.png"))
	fly[0].save(os.path.join(SHIP, f"unit_{uid}.png"))
	print(f"unit_{uid}: COMPLETE action fly/idle/walk×16 attack×{len(attack)} death×{len(death)}")

	meta_p = os.path.join(SHIP, f"unit_{uid}_puppet", "meta.json")
	if os.path.isfile(meta_p):
		with open(meta_p, encoding="utf-8") as f:
			meta = json.load(f)
		meta["prefer_frames"] = True
		meta["fly_source"] = "godot_1_frames+godot_2_frames"
		meta["fly_frames"] = 16
		meta["fly_sheet"] = True
		meta["complete_action"] = True
		meta.pop("reject", None)
		with open(meta_p, "w", encoding="utf-8") as f:
			json.dump(meta, f, indent=2)
	return fly


def write_preview(unit17: list[Image.Image]) -> None:
	os.makedirs(STUDIO, exist_ok=True)
	frames = []
	for fr in unit17:
		bg = Image.new("RGBA", (CW, CH), (0, 0, 0, 255))
		bg.alpha_composite(fr)
		frames.append(bg.resize((CW * 3, CH * 3), Image.NEAREST).convert("P", palette=Image.ADAPTIVE))
	path = os.path.join(STUDIO, "GIF_QUALITY_GATE_17.gif")
	frames[0].save(path, save_all=True, append_images=frames[1:], duration=FRAME_MS, loop=0)
	# strip labeled fly|land
	cell = 64
	sheet = Image.new("RGB", (cell * 16, cell + 28), (16, 16, 22))
	dr = ImageDraw.Draw(sheet)
	dr.text((4, 2), "0-7 fly (g1) | 8-15 land (g2) = COMPLETE", fill=(120, 255, 140))
	for i, fr in enumerate(unit17):
		bg = Image.new("RGBA", (cell, cell), (0, 0, 0, 255))
		s = fr.resize((cell, int(cell * CH / CW)), Image.NEAREST)
		y = (cell - s.size[1]) // 2
		bg.alpha_composite(s, (0, max(0, y)))
		sheet.paste(bg.convert("RGB"), (i * cell, 20))
	sheet.save(os.path.join(STUDIO, "COMPLETE16_STRIP.png"))
	print("preview", path, f"{len(unit17)}f @{FRAME_MS}ms")


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--wb", default=WB_DEFAULT)
	ap.add_argument("--units", default="14,15,16,17")
	args = ap.parse_args()
	srcs = load_complete_action(args.wb)
	arch = os.path.join(STUDIO, "complete16_frames")
	os.makedirs(arch, exist_ok=True)
	for i, im in enumerate(srcs):
		im.save(os.path.join(arch, f"act_{i:02d}.png"))
	unit17 = None
	for uid in [int(x) for x in args.units.split(",") if x.strip()]:
		fly = install_unit(uid, srcs)
		if uid == 17:
			unit17 = fly
	if unit17 is None:
		unit17 = fit_locked(srcs, 1.0)
	write_preview(unit17)
	print("DONE — 16-frame COMPLETE fly+land action installed")


if __name__ == "__main__":
	main()
