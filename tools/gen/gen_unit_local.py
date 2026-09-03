"""
本地像素模型：下载权重 → 读 prompts_external.json → 出图 → 导入 assets/pixels/

默认模型：Onodofthenorth/SD_PixelArt_SpriteSheet_Generator（侧视触发词 PixelartRSS）

用法：
  python tools/gen/gen_unit_local.py --download
  python tools/gen/gen_unit_local.py --id dragon/unit_1 --seed 100
  python tools/gen/gen_unit_local.py --id human/unit_0 --seed 42 --dry-run
  python tools/gen/gen_unit_local.py --all --seed 100
  python tools/gen/gen_unit_local.py --list
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GEN_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, GEN_DIR)

from import_ai_sprite import INCOMING, PROMPTS, import_one, list_pending  # noqa: E402
from archive_candidates import archive_pair, next_index, CANDIDATES  # noqa: E402

DEFAULT_REPO = "Onodofthenorth/SD_PixelArt_SpriteSheet_Generator"
# 权重统一放 D:\AI_models，不占用项目目录
DEFAULT_MODEL = r"D:\AI_models\pixel_sprite"
SIDE_TRIGGER = "PixelartRSS"
# CLIP 只吃前 77 token：角色描述必须放最前，风格放后
LOCAL_STYLE = (
    "single character only, one pose, NOT spritesheet, NOT walk cycle, NOT animation strip, "
    "side view facing right, full body, solid dark purple background, "
    "true pixel art game sprite, hard edges, limited colors"
)
DEFAULT_NEG_EXTRA = (
    "spritesheet, walk cycle, animation frames, multiple poses, multiple characters, "
    "top-down, bird eye, overhead, isometric, front view, back view, "
    "watermark, text, blurry, smooth, realistic, 3d render, "
    "anti-aliasing, soft edges, gradient, illustration, 4k, human girl, redhead girl"
)


def _load_manifest() -> dict:
    with open(PROMPTS, encoding="utf-8") as f:
        return json.load(f)


def _find_asset(manifest: dict, asset_id: str) -> dict | None:
    for group in ("units", "enemies"):
        for item in manifest.get(group, []):
            if item["id"] == asset_id:
                return item
    return None


def _all_asset_ids(manifest: dict) -> list[str]:
    return [u["id"] for u in manifest.get("units", [])] + [e["id"] for e in manifest.get("enemies", [])]


def _has_weights(subdir: str) -> bool:
    for name in (
        "diffusion_pytorch_model.safetensors",
        "diffusion_pytorch_model.bin",
        "model.safetensors",
        "model.bin",
    ):
        if os.path.isfile(os.path.join(subdir, name)):
            return True
    return False


def _model_ready(model_dir: str) -> bool:
    if not os.path.isfile(os.path.join(model_dir, "model_index.json")):
        return False
    return _has_weights(os.path.join(model_dir, "unet")) and _has_weights(os.path.join(model_dir, "vae"))


def ensure_model(model_dir: str, repo: str, force_download: bool = False) -> str:
    if _model_ready(model_dir) and not force_download:
        print("model ready:", model_dir)
        return model_dir
    os.makedirs(model_dir, exist_ok=True)
    print("downloading", repo, "->", model_dir, flush=True)
    from huggingface_hub import snapshot_download

    snapshot_download(repo_id=repo, local_dir=model_dir)
    if not _model_ready(model_dir):
        raise RuntimeError("model incomplete after download — check network / HF access: " + model_dir)
    print("download OK:", model_dir)
    return model_dir


def build_prompt(item: dict, manifest: dict) -> str:
    # CLIP 77 token：只用英文短描述，中文 style_note 会被浪费
    body = item.get("prompt", "")
    # 去掉颜色码与过长尾句，保留前两句核心外形
    sentences = [s.strip() for s in body.replace("#", " ").split(".") if s.strip()]
    core = ". ".join(sentences[:2]) + "."
    parts = [
        SIDE_TRIGGER,
        core,
        "single character one pose only",
        "NOT spritesheet NOT walk cycle",
        "solid dark purple background",
        "pixel art game sprite",
    ]
    return ", ".join(parts)


def build_negative(manifest: dict) -> str:
    meta_neg = manifest.get("meta", {}).get("negative", "")
    return f"{DEFAULT_NEG_EXTRA}, {meta_neg}" if meta_neg else DEFAULT_NEG_EXTRA


def _incoming_raw(asset_id: str) -> str:
    # 临时落盘，随后 archive_pair 会编号永久保存
    rel = asset_id.replace("/", os.sep) + "_gen_raw.png"
    return os.path.join(INCOMING, rel)


def _out_game_path(asset_id: str) -> str:
    return os.path.join(ROOT, "assets", "pixels", asset_id.replace("/", os.sep) + ".png")


def load_pipe(model_dir: str):
    import torch
    from diffusers import StableDiffusionPipeline

    assert torch.cuda.is_available(), "CUDA not available — 需要 NVIDIA 显卡"
    print("loading model...", model_dir, flush=True)
    t0 = time.time()
    pipe = StableDiffusionPipeline.from_pretrained(
        model_dir,
        torch_dtype=torch.float16,
        safety_checker=None,
        requires_safety_checker=False,
    )
    pipe = pipe.to("cuda")
    pipe.enable_attention_slicing()
    print("model loaded in %.1fs" % (time.time() - t0), flush=True)
    return pipe


def generate_image(pipe, prompt: str, negative: str, out_path: str, seed: int,
                   steps: int, cfg: float, size: int):
    import torch

    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    print("generating seed=%d steps=%d ..." % (seed, steps), flush=True)
    t0 = time.time()
    g = torch.Generator(device="cuda").manual_seed(seed)
    img = pipe(
        prompt=prompt,
        negative_prompt=negative,
        num_inference_steps=steps,
        guidance_scale=cfg,
        generator=g,
        width=size,
        height=size,
    ).images[0]
    img.save(out_path)
    print("saved in %.1fs -> %s" % (time.time() - t0, out_path))
    return out_path


def process_one(
    asset_id: str,
    manifest: dict,
    pipe,
    *,
    seed: int,
    steps: int,
    cfg: float,
    size: int,
    dry_run: bool,
    skip_import: bool,
    force: bool,
    flip_x: bool,
    retro: bool,
    quantize: bool,
    no_outline: bool,
    width: int,
    height: int,
) -> bool:
    item = _find_asset(manifest, asset_id)
    if not item:
        print("ERROR: unknown id:", asset_id)
        return False

    out_game = _out_game_path(asset_id)
    if os.path.isfile(out_game) and not force and not dry_run and not skip_import:
        print("SKIP (exists):", asset_id, "->", out_game, "(use --force)")
        return False

    prompt = build_prompt(item, manifest)
    negative = build_negative(manifest)
    raw_path = _incoming_raw(asset_id)

    print("\n=== %s — %s ===" % (asset_id, item.get("name", "")))
    print("prompt:", prompt[:200] + ("..." if len(prompt) > 200 else ""))

    if dry_run:
        return True

    generate_image(pipe, prompt, negative, raw_path, seed, steps, cfg, size)

    if skip_import:
        archive_pair(
            asset_id, raw_path, None,
            note="raw_only",
            seed=seed,
            prompt=prompt,
            source="local_sd",
            flip_x=flip_x,
        )
        print("raw archived (skip import):", raw_path)
        return True

    import_one(
        raw_path,
        asset_id,
        manifest,
        width,
        height,
        not no_outline,
        flip_x=flip_x,
        do_quantize=quantize,
        retro=retro,
        note="local_sd",
        seed=seed,
        prompt=prompt,
        source="local_sd",
        archive=True,
    )
    return True


def main():
    ap = argparse.ArgumentParser(description="Local pixel SD: generate + import game sprites")
    ap.add_argument("--id", default="", help="Asset id e.g. dragon/unit_1 or enemies/enemy_0")
    ap.add_argument("--all", action="store_true", help="Generate all assets in manifest")
    ap.add_argument("--list", action="store_true", help="List manifest + incoming status")
    ap.add_argument("--download", action="store_true", help="Download pixel model only")
    ap.add_argument("--redownload", action="store_true", help="Force re-download model weights")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--repo", default=DEFAULT_REPO)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--steps", type=int, default=28)
    ap.add_argument("--cfg", type=float, default=7.5)
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--width", type=int, default=96, help="Game import width")
    ap.add_argument("--height", type=int, default=108, help="Game import height")
    ap.add_argument("--dry-run", action="store_true", help="Print prompt only, no GPU")
    ap.add_argument("--skip-import", action="store_true", help="Save raw to _studio/incoming only")
    ap.add_argument("--force", action="store_true", help="Overwrite existing game sprites")
    ap.add_argument("--flip-x", action="store_true", help="Mirror on import (if faces left)")
    ap.add_argument("--retro", action="store_true", help="Crush to true low-res pixels on import")
    ap.add_argument("--quantize", action="store_true", help="Force palette quantize on import")
    ap.add_argument("--no-outline", action="store_true")
    args = ap.parse_args()

    manifest = _load_manifest()
    os.makedirs(INCOMING, exist_ok=True)

    if args.list:
        list_pending(manifest)
        print("\n本地出图: python tools/gen/gen_unit_local.py --id <id> --seed 42")
        print("模型路径:", args.model)
        return

    if args.download or args.redownload:
        ensure_model(args.model, args.repo, force_download=args.redownload)
        return

    if not args.id and not args.all:
        ap.print_help()
        print("\n示例: python tools/gen/gen_unit_local.py --id dragon/unit_1 --seed 100")
        sys.exit(1)

    ids = _all_asset_ids(manifest) if args.all else [args.id]
    for aid in ids:
        if not _find_asset(manifest, aid):
            print("ERROR: unknown id:", aid)
            sys.exit(1)

    if args.dry_run:
        for i, aid in enumerate(ids):
            process_one(
                aid, manifest, None,
                seed=args.seed + i, steps=args.steps, cfg=args.cfg, size=args.size,
                dry_run=True, skip_import=args.skip_import, force=args.force,
                flip_x=args.flip_x, retro=args.retro, quantize=args.quantize,
                no_outline=args.no_outline, width=args.width, height=args.height,
            )
        return

    ensure_model(args.model, args.repo)
    pipe = load_pipe(args.model)

    done = 0
    for i, aid in enumerate(ids):
        ok = process_one(
            aid, manifest, pipe,
            seed=args.seed + i, steps=args.steps, cfg=args.cfg, size=args.size,
            dry_run=False, skip_import=args.skip_import, force=args.force,
            flip_x=args.flip_x, retro=args.retro, quantize=args.quantize,
            no_outline=args.no_outline, width=args.width, height=args.height,
        )
        if ok:
            done += 1

    print("\nFinished:", done, "/", len(ids))
    if done and not args.skip_import:
        print("F5 in Godot to preview.")


if __name__ == "__main__":
    main()
