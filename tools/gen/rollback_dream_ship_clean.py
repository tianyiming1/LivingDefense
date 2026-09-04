"""EMERGENCY: reject WorkBuddy AI fly/land sheets for ship.

Restore size_ladder clean bases → readable static anim (idle nudge only).
prefer_frames=true so Path A puppet does not double-wing.
NOT art-pass for motion — only stops the unreadable in-game mess.
"""
from __future__ import annotations

import json
import os
import shutil

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHIP = os.path.join(ROOT, "assets", "pixels", "dragon")
LADDER = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "dream", "size_ladder")
CW, CH = 96, 108

SOURCES = {
	14: "unit_14_s0.42_h42.png",
	15: "unit_15_s0.58_h57.png",
	16: "unit_16_s0.78_h78.png",
	17: "unit_17_s1.00_h93.png",
}


def opaque_n(im: Image.Image) -> int:
	return sum(1 for p in im.getdata() if p[3] > 40 and sum(p[:3]) > 40)


def nudge(im: Image.Image, dx: int, dy: int) -> Image.Image:
	c = Image.new("RGBA", im.size, (0, 0, 0, 0))
	c.alpha_composite(im, (dx, dy))
	return c


def write_static_anim(uid: int, base: Image.Image) -> None:
	out = os.path.join(SHIP, f"unit_{uid}_anim")
	os.makedirs(out, exist_ok=True)
	for n in list(os.listdir(out)):
		if n.endswith(".png"):
			os.remove(os.path.join(out, n))
	# Identical copies only — no ±1px nudge (engine jelly). Motion = real frames later.
	clips = {
		"idle": [base, base],
		"walk": [base, base, base, base],
		"fly": [base, base, base, base],
		"attack": [base, base, base],
		"death": [base, base, base],
	}
	for anim, frames in clips.items():
		for i, fr in enumerate(frames):
			fr.save(os.path.join(out, f"{anim}_{i}.png"))


def main() -> None:
	for uid, name in SOURCES.items():
		src = os.path.join(LADDER, name)
		if not os.path.isfile(src):
			raise SystemExit(f"missing {src}")
		base = Image.open(src).convert("RGBA")
		n = opaque_n(base)
		if n < 400:
			raise SystemExit(f"unit_{uid} too empty opaque={n}")
		dst = os.path.join(SHIP, f"unit_{uid}.png")
		# quarantine bad workbuddy fly if present
		bak = os.path.join(SHIP, f"unit_{uid}_anim_WORKBUDDY_REJECT")
		anim = os.path.join(SHIP, f"unit_{uid}_anim")
		if os.path.isdir(anim) and not os.path.isdir(bak):
			# keep one fly sample for audit
			os.makedirs(bak, exist_ok=True)
			for sample in ("fly_0.png", "idle_0.png"):
				p = os.path.join(anim, sample)
				if os.path.isfile(p):
					shutil.copy2(p, os.path.join(bak, sample))
		base.save(dst)
		write_static_anim(uid, base)
		meta_p = os.path.join(SHIP, f"unit_{uid}_puppet", "meta.json")
		if os.path.isfile(meta_p):
			with open(meta_p, encoding="utf-8") as f:
				meta = json.load(f)
			meta["prefer_frames"] = True
			meta["full_body"] = True
			meta["mode"] = "clean_static_rollback"
			meta["reject"] = "workbuddy_ai_sheets_unreadable_in_game"
			# ensure no wing overlays
			meta["parts"] = ["body"]
			with open(meta_p, "w", encoding="utf-8") as f:
				json.dump(meta, f, indent=2)
			for wing in ("wing.png", "wing_l.png", "wing_r.png"):
				wp = os.path.join(SHIP, f"unit_{uid}_puppet", wing)
				if os.path.isfile(wp):
					os.remove(wp)
		print(f"unit_{uid}: clean opaque={n} static anim + prefer_frames")
	print("DONE — WorkBuddy fly REJECTED from ship; clean ladder restored")


if __name__ == "__main__":
	main()
