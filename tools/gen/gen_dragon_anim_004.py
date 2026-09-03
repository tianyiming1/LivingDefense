"""从 picks/004 生成 DNF 风格分帧：保解剖的程序变形帧 + 低强度 img2img 攻击帧。
输出：assets/pixels/dragon/unit_1_anim/{idle,walk,attack}_N.png
实验帧归档到 _studio/dragon/anim_wip/
"""
from __future__ import annotations

import os
import sys

import torch
from PIL import Image, ImageEnhance
from diffusers import StableDiffusionImg2ImgPipeline, LCMScheduler

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from archive_candidates import archive_pair  # noqa: E402
from pixelize import pixelize  # noqa: E402

MODEL = r"D:\AI_models\lcm_dreamshaper_v7"
REF_RAW = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "picks", "pick_004_flame_drake_raw.png")
REF_GAME = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "picks", "pick_004_flame_drake_game.png")
OUT_DIR = os.path.join(ROOT, "assets", "pixels", "dragon", "unit_1_anim")
TMP = os.path.join(ROOT, "assets", "pixels", "_studio", "incoming")

NEG = (
    "extra legs, three legs, four arms, missing hands, missing arms, deformed hands, "
    "extra limbs, fused limbs, cropped, spritesheet, multiple characters, blurry, photo"
)
BASE_CHAR = (
    "same orange red bipedal dragon man as reference, exactly two arms two legs, "
    "clawed hands, bat wings, side view facing right, full body, solid dark purple background, "
    "pixel art game sprite"
)


def _save_game(src: str, name: str) -> str:
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, name)
    pixelize(src, out, "dragon", 64, True, preview=0, flip_x=False, out_h=72, do_quantize=False)
    archive_pair("dragon/anim_wip", src, out, note=name, source="anim_gen")
    return out


def _pose_transform(im: Image.Image, rotate_deg: float, dx: int, dy: int, sx: float = 1.0, sy: float = 1.0) -> Image.Image:
    w, h = im.size
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    work = im.copy()
    if abs(sx - 1.0) > 0.001 or abs(sy - 1.0) > 0.001:
        nw, nh = max(1, int(w * sx)), max(1, int(h * sy))
        work = work.resize((nw, nh), Image.NEAREST)
    if abs(rotate_deg) > 0.01:
        work = work.rotate(rotate_deg, resample=Image.NEAREST, expand=False)
    ox = (w - work.size[0]) // 2 + dx
    oy = (h - work.size[1]) // 2 + dy
    canvas.alpha_composite(work, (ox, oy))
    return canvas


def make_transform_frames(game_png: str) -> None:
    im = Image.open(game_png).convert("RGBA")
    # idle: 呼吸两帧
    frames = {
        "idle_0.png": im,
        "idle_1.png": _pose_transform(im, 0, 0, -1, 1.0, 1.03),
        "walk_0.png": _pose_transform(im, -4, 1, 0, 1.02, 0.97),
        "walk_1.png": _pose_transform(im, 2, 0, -2, 0.98, 1.04),
        "walk_2.png": _pose_transform(im, -3, 1, 0, 1.02, 0.97),
        "walk_3.png": _pose_transform(im, 3, 0, -2, 0.98, 1.04),
        "attack_0.png": _pose_transform(im, 8, -3, -1, 0.96, 1.04),  # 蓄力后仰
        "attack_1.png": _pose_transform(im, -6, 4, -2, 1.08, 0.94),  # 突进
        "attack_2.png": _pose_transform(im, -2, 1, 0, 1.0, 1.0),  # 收招
    }
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, frame in frames.items():
        path = os.path.join(OUT_DIR, name)
        frame.save(path)
        archive_pair("dragon/anim_wip", None, path, note="xform_" + name, source="procedural_pose")
        print("xform", name)


def make_img2img_extras(pipe) -> None:
    if not os.path.isfile(REF_RAW):
        print("no REF_RAW, skip img2img")
        return
    init = Image.open(REF_RAW).convert("RGB").resize((512, 512), Image.NEAREST)
    os.makedirs(TMP, exist_ok=True)
    jobs = [
        ("attack_ai_0.png", 0.32, 72001, "windup pose, body leans back, claws raised, ready to strike, " + BASE_CHAR),
        ("attack_ai_1.png", 0.36, 72002, "attacking slash pose, body lunging forward, claws swinging, motion, " + BASE_CHAR),
        ("walk_ai_0.png", 0.30, 72003, "running pose, one leg forward, leaning forward, " + BASE_CHAR),
    ]
    for name, strength, seed, prompt in jobs:
        g = torch.Generator(device="cuda").manual_seed(seed)
        print("img2img", name, flush=True)
        img = pipe(
            prompt=prompt,
            negative_prompt=NEG,
            image=init,
            strength=strength,
            num_inference_steps=8,
            guidance_scale=2.0,
            generator=g,
        ).images[0]
        raw = os.path.join(TMP, name)
        img.save(raw)
        # 不覆盖程序帧；另存 ai 候选
        out = os.path.join(OUT_DIR, name.replace(".png", "_cand.png"))
        pixelize(raw, out, "dragon", 64, True, preview=0, flip_x=True, out_h=72, do_quantize=False)
        archive_pair("dragon/anim_wip", raw, out, note=name, seed=seed, prompt=prompt, source="img2img_004")


def main():
    assert os.path.isfile(REF_GAME), "missing 004_game"
    # 确保正式 unit_1 仍是 004
    unit1 = os.path.join(ROOT, "assets", "pixels", "dragon", "unit_1.png")
    if os.path.isfile(REF_GAME):
        Image.open(REF_GAME).save(unit1)
        print("synced unit_1.png from 004_game")

    make_transform_frames(REF_GAME)

    print("loading img2img...", flush=True)
    pipe = StableDiffusionImg2ImgPipeline.from_pretrained(
        MODEL, torch_dtype=torch.float16, safety_checker=None, requires_safety_checker=False
    )
    pipe.scheduler = LCMScheduler.from_config(pipe.scheduler.config)
    pipe = pipe.to("cuda")
    pipe.enable_attention_slicing()
    make_img2img_extras(pipe)
    print("DONE ->", OUT_DIR)


if __name__ == "__main__":
    main()
