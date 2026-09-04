"""Guard: female longren presets must never point at banned multitail hero.

Does NOT overwrite prompts_comfy.json by default.
Run with --apply-beauty-i2i only if you intentionally switch ice/jade to beauty-board img2img.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(r"d:\GameWorkSpace\TowerDefenseProto")
PROMPTS = ROOT / "tools" / "gen" / "prompts_comfy.json"
BANNED = (
    "ref_frost_002_hero.png",
    "ref_REJECT_frost_002_multitail.png",
    "ref_REJECT_",
)
BEAUTY = "assets/pixels/_studio/dragon/longren/_refs/ref_female_beauty_board_B.png"


def main() -> int:
    cfg = json.loads(PROMPTS.read_text(encoding="utf-8"))
    bad: list[str] = []
    for name in ("ice_longren", "jade_longren"):
        preset = cfg.get("presets", {}).get(name, {})
        ref = str(preset.get("ref") or cfg.get("defaults", {}).get("ref") or "")
        for b in BANNED:
            if b in ref.replace("\\", "/"):
                bad.append(f"{name}.ref -> {ref}")
    if bad:
        print("AUDIT_FAIL banned female ref:")
        for line in bad:
            print(" ", line)
        print("Use beauty board or txt2img; never multitail hero/REJECT as i2i anchor.")
        return 2
    print("ok: ice/jade presets have no banned hero/REJECT ref")

    if "--apply-beauty-i2i" in sys.argv:
        # only when explicitly requested
        outfit_pos = (
            "elegant light armored bra covering breasts and short battle skirt, "
            "sexy warrior light armor, EMPTY hands, pretty woman face, hourglass, "
            "EXACTLY ONE tail only"
        )
        outfit_neg = (
            "nude, topless, bottomless, no skirt, multiple tails, twin tails, "
            "heavy spiked pauldrons, ugly face, sword, weapon, dragon snout, "
            "hip wings, floating icons, text, watermark"
        )
        cfg["presets"]["ice_longren"].update(
            {
                "img2img": True,
                "denoise": 0.52,
                "lora_strength": 0.0,
                "ref": BEAUTY,
                "negative": outfit_neg,
                "prompt": (
                    f"FEMALE frost dragonkin, {outfit_pos}, ice-blue white crystalline scales navy membranes, "
                    "EXACTLY ONE pair back wings, EXACTLY ONE tail, full body three-quarter, solid black background"
                ),
            }
        )
        cfg["presets"]["jade_longren"].update(
            {
                "img2img": True,
                "denoise": 0.55,
                "lora_strength": 0.0,
                "ref": BEAUTY,
                "negative": outfit_neg + ", orange lava, ice-white body",
                "prompt": (
                    f"FEMALE jade dragonkin, {outfit_pos}, deep jade green crystalline scales, "
                    "EXACTLY ONE pair LARGE back wings, EXACTLY ONE tail, outfit different from frost, "
                    "full body three-quarter, solid black background"
                ),
            }
        )
        PROMPTS.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("applied beauty-board i2i for ice/jade")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
