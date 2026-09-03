"""用剪影范本做低强度 img2img，锁体态后再上色。

  python tools/gen/gen_from_silhouette.py --class longren --count 4
  python tools/gen/gen_from_silhouette.py --all --count 2

只写入 _studio/dragon/{class}/，不碰 ship。strength 默认 0.40。
"""
from __future__ import annotations

import argparse
import os
import sys
import time

import torch
from diffusers import StableDiffusionImg2ImgPipeline, LCMScheduler
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from archive_candidates import archive_pair  # noqa: E402
from pixelize import pixelize  # noqa: E402

MODEL = r"D:\AI_models\lcm_dreamshaper_v7"
TMPL = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "templates")
TMP = os.path.join(ROOT, "assets", "pixels", "_studio", "incoming", "sil_tmp")

NEG = (
    "extra legs, extra arms, extra limbs, three legs, five legs, four arms, "
    "two heads, fused bodies, centaur, missing legs, missing arms, "
    "wing from hip, wing from wrist, melted limbs, cropped, spritesheet, "
    "multiple characters, blurry, photo, realistic, text, watermark"
)

PROMPTS = {
    "longren": (
        "orange bipedal dragon man pixel art, exactly two arms with clawed hands, "
        "exactly two legs with feet, exactly two bat wings on back, one head one tail, "
        "side view facing right, full body, solid dark purple background"
    ),
    "whelp": (
        "small orange baby dragon quadruped pixel art, exactly four short legs, "
        "small wings, one head one tail, side view full body, solid dark purple background"
    ),
    "drake": (
        "medium orange drake quadruped pixel art, exactly four legs no arms, "
        "exactly two wings on back, one head one tail, side view full body, "
        "solid dark purple background"
    ),
    "adult": (
        "large orange adult dragon quadruped pixel art, exactly four thick legs, "
        "large wings, one head one tail, side view full body, solid dark purple background"
    ),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--class", dest="cls", default="", choices=list(PROMPTS) + [""])
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--count", type=int, default=2)
    ap.add_argument("--strength", type=float, default=0.40)
    ap.add_argument("--seed", type=int, default=900)
    args = ap.parse_args()

    classes = list(PROMPTS) if args.all else ([args.cls] if args.cls else [])
    if not classes:
        ap.error("need --class NAME or --all")

    assert torch.cuda.is_available()
    os.makedirs(TMP, exist_ok=True)

    print("loading LCM...", flush=True)
    pipe = StableDiffusionImg2ImgPipeline.from_pretrained(
        MODEL,
        torch_dtype=torch.float16,
        safety_checker=None,
        requires_safety_checker=False,
    )
    pipe.scheduler = LCMScheduler.from_config(pipe.scheduler.config)
    pipe = pipe.to("cuda")
    pipe.enable_attention_slicing()

    for cls in classes:
        sil_path = os.path.join(TMPL, f"{cls}_sil.png")
        if not os.path.isfile(sil_path):
            print("MISSING template — run draw_dragon_anatomy.py first:", sil_path)
            continue
        ref = Image.open(sil_path).convert("RGB").resize((512, 512), Image.NEAREST)
        for i in range(args.count):
            seed = args.seed + i * 13 + hash(cls) % 1000
            g = torch.Generator(device="cuda").manual_seed(seed)
            prompt = PROMPTS[cls]
            print(f"\n=== {cls} #{i+1} seed={seed} str={args.strength} ===", flush=True)
            t0 = time.time()
            img = pipe(
                prompt=prompt,
                negative_prompt=NEG,
                image=ref,
                strength=args.strength,
                num_inference_steps=6,
                guidance_scale=1.2,
                generator=g,
            ).images[0]
            raw = os.path.join(TMP, f"{cls}_{i:03d}_raw.png")
            game = os.path.join(TMP, f"{cls}_{i:03d}_game.png")
            img.save(raw)
            pixelize(raw, game, "dragon", 64, True, preview=0, flip_x=False, out_h=72, do_quantize=False)
            archive_pair(
                f"dragon/{cls}",
                raw,
                game,
                note=f"sil_i2i_s{args.strength}",
                seed=seed,
                prompt=prompt,
                source="gen_from_silhouette",
            )
            print("ok %.1fs" % (time.time() - t0), flush=True)

    print("\nDONE — filter studio classes before promote")


if __name__ == "__main__":
    main()
