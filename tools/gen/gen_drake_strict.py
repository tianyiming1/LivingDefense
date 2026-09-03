"""重出龙族亚龙(drake)：强制单一体态，丢弃肢体错乱旧图。

体态二选一（每张只用一种，禁止人龙混血堆肢）：
  A) quadruped — 四足龙形 + 一对翅膀 + 一尾一头
  B) biped     — 双足直立 + 两臂两腿 + 一对翅膀（接近 pick_004）

用法：
  python tools/gen/gen_drake_strict.py              # 清坏图 + 出 8 张
  python tools/gen/gen_drake_strict.py --keep-old   # 保留旧编号，从 next 起追加
  python tools/gen/gen_drake_strict.py --count 12
"""
from __future__ import annotations

import argparse
import os
import shutil
import sys
import time

import torch
from diffusers import StableDiffusionImg2ImgPipeline, StableDiffusionPipeline, LCMScheduler
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from archive_candidates import archive_pair, _dir, _save_catalog  # noqa: E402
from pixelize import pixelize  # noqa: E402

MODEL = r"D:\AI_models\lcm_dreamshaper_v7"
ASSET_ID = "dragon/drake"
TMP = os.path.join(ROOT, "assets", "pixels", "_studio", "incoming", "drake_tmp")
PICK004 = os.path.join(
    ROOT, "assets", "pixels", "_studio", "dragon", "picks", "pick_004_flame_drake_raw.png"
)

NEG = (
    "extra legs, three legs, five legs, six legs, extra arms, four arms, three arms, "
    "extra limbs, fused limbs, missing limbs, missing legs, missing arms, "
    "two heads, double head, hydra, conjoined, fused bodies, Siamese, centaur, "
    "human torso on dragon body, multiple characters, overlapping dragons, "
    "extra wings, three wings, four wings, wing from hip, wing from leg, "
    "deformed hands, melted body, cropped, cut off, spritesheet, walk cycle, "
    "blurry, photo, realistic, 3d render, text, watermark"
)

# CLIP 短 prompt：体态词放最前
VARIANTS = [
    # quadruped classic
    {
        "mode": "txt",
        "prompt": (
            "one orange medium drake, classic four-legged dragon, exactly four legs, "
            "exactly two bat wings on back, one long tail, one horned head facing right, "
            "side view full body, solid dark purple background, pixel art game sprite"
        ),
    },
    {
        "mode": "txt",
        "prompt": (
            "one red scaled drake quadruped, four sturdy clawed legs only, "
            "pair of purple membrane wings, single head, single tail, "
            "side view full body standing, solid dark purple background, pixel art game sprite"
        ),
    },
    {
        "mode": "txt",
        "prompt": (
            "one amber wingless-body quadruped drake with two small back wings, "
            "exactly four legs planted on ground, clear hips and shoulders, one head one tail, "
            "side view full body, solid dark purple background, pixel art game sprite"
        ),
    },
    {
        "mode": "txt",
        "prompt": (
            "one compact fire drake on four legs, lizard dragon silhouette, "
            "two wings folded, no arms, four feet only, one head facing right, "
            "side view full body, solid dark purple background, pixel art game sprite"
        ),
    },
    # biped — prefer img2img from good pick to lock limbs
    {
        "mode": "i2i",
        "prompt": (
            "same bipedal orange flame drake, exactly two arms two legs, "
            "exactly two wings, one head one tail, clawed hands and feet, "
            "side view facing right, full body, solid dark purple background, pixel art"
        ),
        "strength": 0.38,
    },
    {
        "mode": "i2i",
        "prompt": (
            "bipedal red dragon warrior, exactly two arms two digitigrade legs, "
            "pair of bat wings on back only, clear hands separate from wings, "
            "side view full body, solid dark purple background, pixel art game sprite"
        ),
        "strength": 0.42,
    },
    {
        "mode": "txt",
        "prompt": (
            "one bipedal orange dragon, upright, exactly two arms with hands, "
            "exactly two legs with feet, exactly two wings on shoulders, one head one tail, "
            "no extra limbs, side view full body, solid dark purple background, pixel art sprite"
        ),
    },
    {
        "mode": "i2i",
        "prompt": (
            "orange biped drake idle pose, two arms two legs two wings only, "
            "clean silhouette, side view full body, solid dark purple background, pixel art"
        ),
        "strength": 0.35,
    },
]


def wipe_old() -> None:
    d = _dir(ASSET_ID)
    rejected = os.path.join(os.path.dirname(d), "drake_rejected")
    os.makedirs(rejected, exist_ok=True)
    for name in list(os.listdir(d)):
        src = os.path.join(d, name)
        if name.endswith(".png"):
            shutil.move(src, os.path.join(rejected, name))
            print("rejected ->", name)
        elif name == "catalog.json":
            os.remove(src)
    _save_catalog(ASSET_ID, {"asset_id": ASSET_ID, "items": []})
    print("catalog reset:", ASSET_ID)


def load_pipes():
    print("loading LCM...", flush=True)
    t0 = time.time()
    txt = StableDiffusionPipeline.from_pretrained(
        MODEL,
        torch_dtype=torch.float16,
        safety_checker=None,
        requires_safety_checker=False,
    )
    txt.scheduler = LCMScheduler.from_config(txt.scheduler.config)
    txt = txt.to("cuda")
    txt.enable_attention_slicing()

    i2i = StableDiffusionImg2ImgPipeline.from_pretrained(
        MODEL,
        torch_dtype=torch.float16,
        safety_checker=None,
        requires_safety_checker=False,
    )
    i2i.scheduler = LCMScheduler.from_config(i2i.scheduler.config)
    i2i = i2i.to("cuda")
    i2i.enable_attention_slicing()
    print("loaded in %.1fs" % (time.time() - t0), flush=True)
    return txt, i2i


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--keep-old", action="store_true")
    ap.add_argument("--count", type=int, default=8)
    ap.add_argument("--seed", type=int, default=700)
    args = ap.parse_args()

    assert torch.cuda.is_available(), "need CUDA"
    if not args.keep_old:
        wipe_old()

    os.makedirs(TMP, exist_ok=True)
    txt, i2i = load_pipes()
    ref = None
    if os.path.isfile(PICK004):
        ref = Image.open(PICK004).convert("RGB").resize((512, 512), Image.LANCZOS)

    specs = (VARIANTS * ((args.count + len(VARIANTS) - 1) // len(VARIANTS)))[: args.count]
    for i, spec in enumerate(specs):
        seed = args.seed + i * 17
        prompt = spec["prompt"]
        raw = os.path.join(TMP, "drake_%03d_raw.png" % (i + 1))
        game = os.path.join(TMP, "drake_%03d_game.png" % (i + 1))
        g = torch.Generator(device="cuda").manual_seed(seed)
        print("\n=== #%d seed=%d mode=%s ===" % (i + 1, seed, spec["mode"]), flush=True)
        print(prompt[:120], flush=True)
        t0 = time.time()
        if spec["mode"] == "i2i" and ref is not None:
            img = i2i(
                prompt=prompt,
                negative_prompt=NEG,
                image=ref,
                strength=float(spec.get("strength", 0.4)),
                num_inference_steps=6,
                guidance_scale=1.2,
                generator=g,
            ).images[0]
        else:
            img = txt(
                prompt=prompt,
                negative_prompt=NEG,
                num_inference_steps=6,
                guidance_scale=1.5,
                generator=g,
                width=512,
                height=512,
            ).images[0]
        img.save(raw)
        pixelize(raw, game, "dragon", 64, True, preview=0, flip_x=False, out_h=72, do_quantize=False)
        archive_pair(
            ASSET_ID,
            raw,
            game,
            note=spec["mode"],
            seed=seed,
            prompt=prompt,
            source="drake_strict",
        )
        print("ok in %.1fs" % (time.time() - t0), flush=True)

    print("\nDONE — filter:", os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "drake"))
    print("rejected old (if wiped):", os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "drake_rejected"))


if __name__ == "__main__":
    main()
