"""Purge unapproved studio assets: candidates/, REJECT refs, banned FAIL pipelines."""
from __future__ import annotations

import os
import shutil
from pathlib import Path

ROOT = Path("assets/pixels/_studio")
SHIP = Path("assets/pixels")
GEN = Path("tools/gen")


def count_png(p: Path) -> int:
	return len(list(p.rglob("*.png"))) if p.exists() else 0


def main() -> None:
	print("BEFORE studio png", count_png(ROOT))
	kill: list[Path] = []

	# REJECT / WorkBuddy named
	for p in ROOT.rglob("*"):
		name = p.name
		if name.startswith("ref_REJECT") or "_REJECT" in name or "WORKBUDDY" in name.upper():
			kill.append(p)

	# Diagnostic dream PNGs
	for rel in (
		"dragon/dream/PUPPET_COMPOSE_17.png",
		"dragon/dream/PUPPET_FIX_VERIFY_17.png",
		"dragon/dream/DOUBLE_WING_DIAG.png",
	):
		p = ROOT / rel
		if p.exists():
			kill.append(p)

	# procedural / non-user-final picks noise
	for rel in (
		"dragon/picks/procedural_drake_game.png",
		"dragon/picks/procedural_drake_raw.png",
	):
		p = ROOT / rel
		if p.exists():
			kill.append(p)

	# ALL candidates/ under _studio (WIP not approved)
	for cand in ROOT.rglob("candidates"):
		if cand.is_dir():
			kill.append(cand)

	# Banned FAIL anim generators
	for name in (
		"install_workbuddy_dream_anim.py",
		"install_workbuddy_fly.py",
		"gen_dream_self_flap.py",
		"gen_dream_comfy_flap.py",
		"gen_unit_action_frames.FAIL.txt",
	):
		p = GEN / name
		if p.exists():
			kill.append(p)

	# Collapse nested: prefer deleting parent dirs
	dirs = sorted({p for p in kill if p.is_dir()}, key=lambda x: len(str(x)))
	kept_dirs: list[Path] = []
	for d in dirs:
		if any(d == kd or kd in d.parents for kd in kept_dirs):
			continue
		kept_dirs.append(d)

	files = [p for p in kill if p.is_file()]
	files = [f for f in files if not any(kd in f.parents or f.parent == kd for kd in kept_dirs)]

	deleted: list[str] = []
	for d in sorted(kept_dirs, key=lambda x: -len(str(x))):
		if d.exists():
			shutil.rmtree(d, ignore_errors=True)
			deleted.append(f"DIR {d.as_posix()}")

	for f in files:
		if not f.exists():
			continue
		f.unlink(missing_ok=True)
		ip = Path(str(f) + ".import")
		if ip.exists():
			ip.unlink(missing_ok=True)
		deleted.append(f"FILE {f.as_posix()}")

	# Dream ship anim must stay empty of unapproved frames
	for u in (14, 15, 16, 17):
		anim = SHIP / "dragon" / f"unit_{u}_anim"
		if anim.is_dir():
			for f in list(anim.iterdir()):
				if f.suffix.lower() in (".png", ".json"):
					f.unlink(missing_ok=True)
					deleted.append(f"SHIP {f.as_posix()}")

	# Empty hand_anim frame leftovers
	ha = ROOT / "dragon/dream/hand_anim"
	if ha.is_dir():
		for f in ha.rglob("*.png"):
			f.unlink(missing_ok=True)
			deleted.append(f"HAND {f.as_posix()}")

	print("deleted", len(deleted))
	for d in deleted[:80]:
		print(" ", d)
	if len(deleted) > 80:
		print(" ...", len(deleted) - 80, "more")

	# recreate empty candidates placeholders? NO — user wants gone. approved stays.
	print("AFTER studio png", count_png(ROOT))
	print("candidates left", [p.as_posix() for p in ROOT.rglob("candidates")])
	print("REJECT left", [p.as_posix() for p in ROOT.rglob("ref_REJECT*")])
	print("approved_game", len(list(ROOT.rglob("approved/*_game.png"))))
	picks = ROOT / "dragon/picks"
	print("dragon picks png", len(list(picks.rglob("*.png"))) if picks.exists() else 0)


if __name__ == "__main__":
	os.chdir(Path(__file__).resolve().parents[2] if False else Path.cwd())
	main()
