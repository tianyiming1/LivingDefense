"""单张像素风单位样张：SD 出图 -> 像素化 -> 预览"""
import os
import sys
import time

import torch
from diffusers import StableDiffusionPipeline, LCMScheduler
from PIL import Image, ImageDraw, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelize import pixelize

MODEL = r"D:\AI_models\lcm_dreamshaper_v7"
OUT_DIR = os.path.join(ROOT, "assets", "pixels", "human")

NEG = (
    "blurry, smooth, realistic, 3d render, photograph, anti-aliasing, "
    "gradient, soft edges, watermark, text, logo, extra limbs, deformed, "
    "multiple characters, isometric, low quality, noise"
)

SAMPLES = {
    "human_infantry_idle": {
        "prompt": (
            "cute chibi knight character icon, simple flat colors, front view, "
            "blue steel armor, yellow star on chest, holding sword, "
            "centered on plain dark green background, game character portrait, "
            "clean silhouette, minimal detail"
        ),
        "palette": "human",
        "seed": 42706,
    },
}


def main():
    assert torch.cuda.is_available(), "CUDA not available"
    os.makedirs(OUT_DIR, exist_ok=True)
    raw_dir = os.path.join(OUT_DIR, "raw")
    os.makedirs(raw_dir, exist_ok=True)

    spec = SAMPLES["human_infantry_idle"]
    raw_path = os.path.join(raw_dir, "human_infantry_idle_raw.png")
    out_path = os.path.join(OUT_DIR, "human_infantry_idle_64.png")
    alt_path = os.path.join(OUT_DIR, "human_infantry_idle_sd_64.png")

    print("loading model...", flush=True)
    t0 = time.time()
    pipe = StableDiffusionPipeline.from_pretrained(
        MODEL,
        torch_dtype=torch.float16,
        safety_checker=None,
        requires_safety_checker=False,
    )
    pipe.scheduler = LCMScheduler.from_config(pipe.scheduler.config)
    pipe = pipe.to("cuda")
    pipe.enable_attention_slicing()
    print("model loaded in %.1fs" % (time.time() - t0), flush=True)

    print("generating...", flush=True)
    t1 = time.time()
    g = torch.Generator(device="cuda").manual_seed(spec["seed"])
    img = pipe(
        prompt=spec["prompt"],
        negative_prompt=NEG,
        num_inference_steps=4,
        guidance_scale=1.5,
        generator=g,
        width=768,
        height=768,
    ).images[0]
    img.save(raw_path)
    print("raw saved in %.1fs -> %s" % (time.time() - t1, raw_path), flush=True)

    pixelize(raw_path, alt_path, spec["palette"], 64, True, 8)
    print("ALL DONE")
    print("  raw :", raw_path)
    print("  pixel (sd):", alt_path)
    print("  preview:", alt_path.replace(".png", "_preview4x.png"))


if __name__ == "__main__":
    main()
