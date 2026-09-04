"""Dream flap via Comfy img2img+Canny (local stand-in for WorkBuddy I2V).

True img2video (即梦/SVD) is not installed. This approximates the redraw half:
  042_raw (identity) + mesh-warp pose canny (wing path) → AI redraw frames
  → soft pixelize 96×108 → ship unit_14–17.

Usage:
  python tools/gen/gen_dream_comfy_flap.py --frames 8 --units 14,15,16,17
  python tools/gen/gen_dream_comfy_flap.py --skip-gen   # reuse raws already in studio
"""
from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageOps, ImageSequence

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GEN = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, GEN)

import comfy_pixel_gen as comfy  # noqa: E402
from gen_dream_self_flap import (  # noqa: E402
	CW,
	CH,
	FOOT,
	FRAME_MS,
	GIF_REF,
	N_FLAP,
	SCALES,
	build_clip,
	clear_anim,
	fit_to_canvas,
	gate_frames,
	opaque_count,
	px_changed,
	rematte,
	write_sheet,
)
from pixelize import pixelize  # noqa: E402

DREAM = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "dream")
APPROVED_RAW = os.path.join(DREAM, "approved", "042_raw.png")
APPROVED_GAME = os.path.join(DREAM, "approved", "042_game.png")
STUDIO = os.path.join(DREAM, "comfy_flap")
RAW_DIR = os.path.join(STUDIO, "raws")
POSE_DIR = os.path.join(STUDIO, "poses")
HAND = os.path.join(DREAM, "hand_anim")
SHIP = os.path.join(ROOT, "assets", "pixels", "dragon")

BASE_PROMPT = (
	"SAME dream dragon as reference, ice-cyan white jagged crystalline voxel scales, "
	"deep purple wing bones, translucent ice-blue wing membranes, EXACTLY ONE pair bat wings "
	"from UPPER BACK only, EXACTLY ONE curved spiked tail, bipedal beast dragon NOT humanoid, "
	"three-quarter facing left, full body, solid black background, locked camera, "
	"same character identity, redraw wings clearly"
)
NEG = (
	"hip wings, secondary wings, four wings, two pairs of wings, winglets, weapon, text, watermark, "
	"multiple characters, spritesheet, cropped, realistic photo, 3d render, two tails, "
	"extra arms, extra legs, severed limbs, messy silhouette, morphing body, face change"
)

# Wing pose tags for flap cycle (up → down → up). Index maps onto N_FLAP phases.
POSE_TAGS = [
	"wings RAISED high above back, membranes taut upward",
	"wings high-mid, tips angled up-back",
	"wings mid-open horizontal, membranes spread wide",
	"wings mid-down, pushing air, membranes bowed",
	"wings LOW beside body, tips down, membranes folded slightly",
	"wings mid-down recovering, membranes flexing",
	"wings mid-open horizontal again",
	"wings high-mid rising for next stroke",
]


def ensure_dirs() -> None:
	for d in (STUDIO, RAW_DIR, POSE_DIR):
		os.makedirs(d, exist_ok=True)


def prepare_ref_1024() -> str:
	"""Stage 042_raw (already 1024) or pad game upscale onto black."""
	if os.path.isfile(APPROVED_RAW):
		src = APPROVED_RAW
	else:
		g = rematte(Image.open(APPROVED_GAME).convert("RGBA"))
		canvas = Image.new("RGB", (1024, 1024), (0, 0, 0))
		up = g.resize((96 * 8, 108 * 8), Image.NEAREST)
		x = (1024 - up.size[0]) // 2
		y = 1024 - up.size[1] - 40
		canvas.paste(up.convert("RGB"), (x, max(0, y)), up.split()[-1])
		src = os.path.join(STUDIO, "ref_from_game.png")
		canvas.save(src)
	return comfy.stage_file(src, "dream042_flap_ref.png")


def make_pose_guides(n: int) -> list[str]:
	"""Mesh-warp 042_game → upscaled RGB pose images for Canny ControlNet."""
	base = fit_to_canvas(Image.open(APPROVED_GAME).convert("RGBA"), 1.0)
	# build_clip uses N_FLAP; subsample evenly to n
	full = build_clip(base, lift=10)
	step = max(1, len(full) // n)
	picked = [full[(i * step) % len(full)] for i in range(n)]
	names: list[str] = []
	for i, fr in enumerate(picked):
		# white silhouette on black = strong canny edges for wing outline
		sil = Image.new("RGB", (CW, CH), (0, 0, 0))
		px = fr.load()
		sp = sil.load()
		for y in range(CH):
			for x in range(CW):
				r, g, b, a = px[x, y]
				if a > 40 and r + g + b > 30:
					sp[x, y] = (240, 240, 240)
		up = sil.resize((1024, 1024), Image.NEAREST)
		# slight blur so canny isn't pure pixel stair
		up = up.filter(ImageFilter.GaussianBlur(radius=1.2))
		path = os.path.join(POSE_DIR, f"pose_{i:02d}.png")
		up.save(path)
		names.append(comfy.stage_file(path, f"dream042_pose_{i:02d}.png"))
	return names


def gen_one(
	ref_name: str,
	pose_name: str,
	pose_i: int,
	seed: int,
	denoise: float,
	cn_strength: float,
	steps: int,
	use_cn: bool,
) -> str:
	cfg = comfy._load_cfg()
	d = cfg["defaults"]
	tag = POSE_TAGS[pose_i % len(POSE_TAGS)]
	prompt = f"{BASE_PROMPT}, {tag}, subtle hover bob"
	ckpt = d["ckpt"]
	lora = d["lora"]
	lora_str = 0.15
	cn = comfy.controlnet_canny_path() if use_cn else None
	prefix = f"dream_flap_{pose_i:02d}"
	if cn:
		wf = comfy.build_img2img_controlnet(
			prompt=prompt,
			negative=NEG,
			seed=seed + pose_i * 17,
			ckpt=ckpt,
			lora=lora,
			lora_strength=lora_str,
			steps=steps,
			cfg=float(d["cfg"]),
			sampler=d["sampler"],
			scheduler=d["scheduler"],
			denoise=denoise,
			ref_filename=ref_name,
			control_filename=pose_name,
			controlnet_name=cn,
			control_strength=cn_strength,
			prefix=prefix,
		)
	else:
		wf = comfy.build_img2img(
			prompt=prompt,
			negative=NEG,
			seed=seed + pose_i * 17,
			ckpt=ckpt,
			lora=lora,
			lora_strength=lora_str,
			steps=steps,
			cfg=float(d["cfg"]),
			sampler=d["sampler"],
			scheduler=d["scheduler"],
			denoise=denoise,
			ref_filename=ref_name,
			prefix=prefix,
		)
	print(f"gen frame {pose_i}: denoise={denoise} cn={cn_strength if cn else 0} — {tag[:40]}")
	return comfy.queue_and_wait(wf, timeout_s=300)


def soft_to_game(raw_path: str, out_path: str) -> None:
	pixelize(
		raw_path,
		out_path,
		palette_name="dragon",
		size=CW,
		outline=True,
		preview=0,
		out_h=CH,
		do_quantize=False,
		retro=False,
	)


def process_raws(n: int) -> list[Image.Image]:
	frames: list[Image.Image] = []
	for i in range(n):
		raw = os.path.join(RAW_DIR, f"raw_{i:02d}.png")
		if not os.path.isfile(raw):
			raise SystemExit(f"missing {raw}")
		game_tmp = os.path.join(STUDIO, f"game_{i:02d}.png")
		soft_to_game(raw, game_tmp)
		fr = fit_to_canvas(Image.open(game_tmp).convert("RGBA"), 1.0)
		# foot lock shared
		frames.append(fr)
		fr.save(os.path.join(STUDIO, f"cell_{i:02d}.png"))
	# unify foot Y to FOOT
	locked: list[Image.Image] = []
	for fr in frames:
		from gen_dream_self_flap import opaque_bbox

		bb = opaque_bbox(fr)
		out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
		if not bb:
			locked.append(out)
			continue
		dy = FOOT - (bb[3] - 1)
		tmp = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
		tmp.alpha_composite(fr, (0, dy))
		locked.append(tmp)
	return locked


def expand_to_16(frames8: list[Image.Image]) -> list[Image.Image]:
	"""Duplicate/lerp-ish by holding neighbors to fill 16 slots for runtime."""
	if len(frames8) >= 16:
		return frames8[:16]
	out: list[Image.Image] = []
	for i in range(16):
		t = i / 16.0 * len(frames8)
		j = min(len(frames8) - 1, int(t))
		out.append(frames8[j].copy())
	return out


def install_unit(uid: int, fly: list[Image.Image]) -> None:
	idle = []
	for fr in fly:
		# slight lower hover for idle
		bb = None
		from gen_dream_self_flap import opaque_bbox

		bb = opaque_bbox(fr)
		out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
		if bb:
			dy = 6
			tmp = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
			tmp.alpha_composite(fr, (0, dy))
			out = tmp
		idle.append(out)
	attack = [fly[0], fly[len(fly) // 4], fly[len(fly) // 2], fly[3 * len(fly) // 4]]
	death = fly[-4:] if len(fly) >= 4 else fly

	hand = os.path.join(HAND, f"unit_{uid}")
	ship = os.path.join(SHIP, f"unit_{uid}_anim")
	os.makedirs(hand, exist_ok=True)
	os.makedirs(ship, exist_ok=True)
	clear_anim(hand)
	clear_anim(ship)
	# rescale per unit
	def scaled(src: Image.Image) -> Image.Image:
		# re-fit from approved scale via compositing onto transparent then scale bbox
		sc = SCALES.get(uid, 1.0)
		if abs(sc - 1.0) < 0.01:
			return src
		bb = opaque_bbox(src)
		if not bb:
			return src
		crop = src.crop(bb)
		nw = max(1, int(round(crop.size[0] * sc)))
		nh = max(1, int(round(crop.size[1] * sc)))
		crop = crop.resize((nw, nh), Image.NEAREST)
		out = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
		x = (CW - nw) // 2
		y = FOOT - nh
		out.alpha_composite(crop, (x, max(2, y)))
		return out

	from gen_dream_self_flap import opaque_bbox

	fly_s = [scaled(f) for f in fly]
	idle_s = [scaled(f) for f in idle]
	for i in range(len(fly_s)):
		for name, fr in (
			(f"fly_{i}.png", fly_s[i]),
			(f"idle_{i}.png", idle_s[i]),
			(f"walk_{i}.png", fly_s[i]),
		):
			fr.save(os.path.join(hand, name))
			fr.save(os.path.join(ship, name))
	for i, fr in enumerate([scaled(a) for a in attack]):
		fr.save(os.path.join(hand, f"attack_{i}.png"))
		fr.save(os.path.join(ship, f"attack_{i}.png"))
	for i, fr in enumerate([scaled(a) for a in death]):
		fr.save(os.path.join(hand, f"death_{i}.png"))
		fr.save(os.path.join(ship, f"death_{i}.png"))
	write_sheet(fly_s, os.path.join(hand, "fly_sheet.png"))
	write_sheet(fly_s, os.path.join(ship, "fly_sheet.png"))
	write_sheet(idle_s, os.path.join(ship, "idle_sheet.png"))
	idle_s[0].save(os.path.join(SHIP, f"unit_{uid}.png"))

	meta_p = os.path.join(SHIP, f"unit_{uid}_puppet", "meta.json")
	if os.path.isfile(meta_p):
		with open(meta_p, encoding="utf-8") as f:
			meta = json.load(f)
		meta["prefer_frames"] = True
		meta["fly_source"] = "comfy_img2img_canny_042"
		meta["fly_frames"] = len(fly_s)
		meta["fly_sheet"] = True
		meta["complete_action"] = True
		meta.pop("reject", None)
		with open(meta_p, "w", encoding="utf-8") as f:
			json.dump(meta, f, indent=2)
	print(f"unit_{uid}: installed comfy flap {len(fly_s)}f")


def write_evidence(fly: list[Image.Image]) -> None:
	gif = []
	for fr in fly:
		bg = Image.new("RGBA", (CW, CH), (0, 0, 0, 255))
		bg.alpha_composite(fr)
		gif.append(bg.resize((CW * 3, CH * 3), Image.NEAREST).convert("P", palette=Image.ADAPTIVE))
	path = os.path.join(STUDIO, "COMFY_FLAP_GATE_17.gif")
	gif[0].save(path, save_all=True, append_images=gif[1:], duration=FRAME_MS, loop=0)

	cell = 60
	n = len(fly)
	strip = Image.new("RGB", (cell * n, cell + 24), (16, 16, 22))
	dr = ImageDraw.Draw(strip)
	dr.text((4, 2), f"Comfy i2i+canny flap {n}f (I2V stand-in)", fill=(120, 200, 255))
	for i, fr in enumerate(fly):
		bg = Image.new("RGBA", (cell, cell), (0, 0, 0, 255))
		s = fr.resize((cell, int(cell * CH / CW)), Image.NEAREST)
		bg.alpha_composite(s, (0, (cell - s.size[1]) // 2))
		strip.paste(bg.convert("RGB"), (i * cell, 18))
	strip.save(os.path.join(STUDIO, "COMFY_FLAP_STRIP.png"))

	if os.path.isfile(GIF_REF):
		g = Image.open(GIF_REF)
		gfr = [fit_to_canvas(fr.convert("RGBA"), 1.0) for fr in ImageSequence.Iterator(g)][:8]
		cmp = Image.new("RGB", (96 * 8, 96 * 2 + 36), (12, 12, 18))
		dr = ImageDraw.Draw(cmp)
		dr.text((4, 2), "GIF ref (quality bar — not shipped)", fill=(120, 255, 140))
		dr.text((4, 110), "Comfy i2i+canny (ship candidate)", fill=(255, 200, 80))
		for i in range(8):
			gg = Image.new("RGBA", (96, 96), (0, 0, 0, 255))
			gg.alpha_composite(gfr[i % len(gfr)], (0, -6))
			cmp.paste(gg.convert("RGB"), (i * 96, 16))
			si = fly[min(len(fly) - 1, i * len(fly) // 8)]
			ss = Image.new("RGBA", (96, 96), (0, 0, 0, 255))
			ss.alpha_composite(si, (0, -6))
			cmp.paste(ss.convert("RGB"), (i * 96, 116))
		cmp.save(os.path.join(STUDIO, "COMPARE_GIF_VS_COMFY.png"))
		print("compare", os.path.join(STUDIO, "COMPARE_GIF_VS_COMFY.png"))
	print("preview", path)


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--frames", type=int, default=8)
	ap.add_argument("--units", default="14,15,16,17")
	ap.add_argument("--denoise", type=float, default=0.42)
	ap.add_argument("--cn-strength", type=float, default=0.55)
	ap.add_argument("--steps", type=int, default=24)
	ap.add_argument("--seed", type=int, default=42042)
	ap.add_argument("--skip-gen", action="store_true")
	ap.add_argument("--no-cn", action="store_true")
	ap.add_argument("--no-ship", action="store_true")
	args = ap.parse_args()
	n = max(4, min(16, args.frames))
	ensure_dirs()

	if not args.skip_gen:
		if not os.path.isfile(APPROVED_GAME):
			raise SystemExit(f"missing {APPROVED_GAME}")
		comfy.ensure_comfy()
		ref_name = prepare_ref_1024()
		poses = make_pose_guides(n)
		for i in range(n):
			out = gen_one(
				ref_name,
				poses[i],
				i,
				args.seed,
				args.denoise,
				args.cn_strength,
				args.steps,
				use_cn=not args.no_cn,
			)
			dest = os.path.join(RAW_DIR, f"raw_{i:02d}.png")
			shutil.copy2(out, dest)
			print("saved", dest)

	cells = process_raws(n)
	ok, msg = gate_frames(cells if len(cells) >= 4 else cells * 2)
	# gate expects consecutive; for short clips relax via expand check
	print(f"GATE {'PASS' if ok else 'FAIL'} — {msg}")
	fly16 = expand_to_16(cells)
	ok16, msg16 = gate_frames(fly16)
	print(f"GATE16 {'PASS' if ok16 else 'FAIL'} — {msg16}")

	write_evidence(fly16 if len(fly16) >= 8 else cells)

	note = {
		"method": "comfy_img2img_canny_pose",
		"note": "Local stand-in for WorkBuddy img2video; no SVD/I2V model installed",
		"frames_gen": n,
		"frames_ship": len(fly16),
		"denoise": args.denoise,
		"cn_strength": args.cn_strength,
		"gate8": msg,
		"gate16": msg16,
		"workbuddy_banned": True,
	}
	with open(os.path.join(STUDIO, "NOTE.json"), "w", encoding="utf-8") as f:
		json.dump(note, f, indent=2)

	if args.no_ship:
		print("skip ship")
		return
	if not ok and not ok16:
		print("GATE FAIL — not shipping. Inspect studio/comfy_flap/")
		raise SystemExit(2)

	for uid in [int(x) for x in args.units.split(",") if x.strip()]:
		install_unit(uid, fly16)
	print("done")


if __name__ == "__main__":
	main()
