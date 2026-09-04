"""
ComfyUI → _studio（默认对齐 pick_004：img2img 锁熔岩晶体风）

用法：
  python tools/gen/comfy_pixel_gen.py --preset longren_mage --n 2
  python tools/gen/comfy_pixel_gen.py --preset fire_longren --n 2
  python tools/gen/comfy_pixel_gen.py --preset ice_longren --n 2 --denoise 0.6
  python tools/gen/comfy_pixel_gen.py --preset flame_drake --txt2img   # 强制纯文生
"""
from __future__ import annotations

import argparse
import json
import os
import random
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GEN_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, GEN_DIR)

from archive_candidates import archive_pair  # noqa: E402
from pixelize import pixelize  # noqa: E402

COMFY_ROOT = r"D:\softwares\ComfyUI"
COMFY_PY = os.path.join(COMFY_ROOT, "venv", "Scripts", "python.exe")
COMFY_MAIN = os.path.join(COMFY_ROOT, "main.py")
COMFY_OUT = os.path.join(COMFY_ROOT, "output")
COMFY_IN = os.path.join(COMFY_ROOT, "input")
COMFY_CN = os.path.join(COMFY_ROOT, "models", "controlnet")
COMFY_URL = "http://127.0.0.1:8188"
PROMPTS_PATH = os.path.join(GEN_DIR, "prompts_comfy.json")
# SDXL Canny ControlNet (place via tools/gen/setup_comfy_dream_anim.ps1)
DEFAULT_CN_CANNY = "controlnet-canny-sdxl-1.0.safetensors"
INCOMING = os.path.join(ROOT, "assets", "pixels", "_studio", "incoming")
DEFAULT_REF = os.path.join(
    ROOT, "assets", "pixels", "_studio", "dragon", "picks", "pick_004_flame_drake_raw.png"
)


def _load_cfg() -> dict:
    with open(PROMPTS_PATH, encoding="utf-8") as f:
        return json.load(f)


def _http_json(method: str, path: str, body: dict | None = None, timeout: float = 30) -> dict:
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        COMFY_URL + path,
        data=data,
        method=method,
        headers={"Content-Type": "application/json"} if body is not None else {},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def comfy_up() -> bool:
    try:
        urllib.request.urlopen(COMFY_URL + "/system_stats", timeout=2)
        return True
    except Exception:
        return False


def ensure_comfy(wait_s: int = 90) -> None:
    if comfy_up():
        print("ComfyUI already up")
        return
    if not os.path.isfile(COMFY_PY) or not os.path.isfile(COMFY_MAIN):
        raise SystemExit(f"ComfyUI not found at {COMFY_ROOT}")
    print("Starting ComfyUI...")
    subprocess.Popen(
        [COMFY_PY, COMFY_MAIN, "--port", "8188", "--listen", "127.0.0.1"],
        cwd=COMFY_ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    t0 = time.time()
    while time.time() - t0 < wait_s:
        if comfy_up():
            print("ComfyUI ready")
            return
        time.sleep(2)
    raise SystemExit("ComfyUI failed to start (timeout)")


def stage_file(src_path: str, dest_name: str) -> str:
	os.makedirs(COMFY_IN, exist_ok=True)
	dest = os.path.join(COMFY_IN, dest_name)
	shutil.copy2(src_path, dest)
	return dest_name


def stage_ref(ref_path: str) -> str:
	"""复制参考图到 ComfyUI/input，返回 LoadImage 用的文件名。"""
	return stage_file(ref_path, "pick004_style_ref.png")


def controlnet_canny_path() -> str | None:
	"""Return controlnet filename if installed."""
	if not os.path.isdir(COMFY_CN):
		return None
	for name in (DEFAULT_CN_CANNY, "OpenPoseXL2.safetensors", "diffusion_pytorch_model.safetensors"):
		if os.path.isfile(os.path.join(COMFY_CN, name)):
			return name
	for n in os.listdir(COMFY_CN):
		if n.endswith(".safetensors") and "put_" not in n.lower():
			return n
	return None


def build_img2img_controlnet(
	prompt: str,
	negative: str,
	seed: int,
	ckpt: str,
	lora: str | None,
	lora_strength: float,
	steps: int,
	cfg: float,
	sampler: str,
	scheduler: str,
	denoise: float,
	ref_filename: str,
	control_filename: str,
	controlnet_name: str,
	control_strength: float,
	prefix: str,
) -> dict:
	"""img2img + ControlNet (pose guide). One frame per queue."""
	nodes: dict = {
		"1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": ckpt}},
		"20": {"class_type": "LoadImage", "inputs": {"image": ref_filename}},
		"22": {"class_type": "LoadImage", "inputs": {"image": control_filename}},
		"23": {"class_type": "ControlNetLoader", "inputs": {"control_net_name": controlnet_name}},
	}
	model_src, clip_src = ["1", 0], ["1", 1]
	if lora and lora_strength > 0.01:
		nodes["10"] = {
			"class_type": "LoraLoader",
			"inputs": {
				"model": ["1", 0],
				"clip": ["1", 1],
				"lora_name": lora,
				"strength_model": lora_strength,
				"strength_clip": lora_strength,
			},
		}
		model_src, clip_src = ["10", 0], ["10", 1]
	nodes["6"] = {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": clip_src}}
	nodes["7"] = {"class_type": "CLIPTextEncode", "inputs": {"text": negative, "clip": clip_src}}
	nodes["24"] = {
		"class_type": "ControlNetApplyAdvanced",
		"inputs": {
			"positive": ["6", 0],
			"negative": ["7", 0],
			"control_net": ["23", 0],
			"image": ["22", 0],
			"strength": float(control_strength),
			"start_percent": 0.0,
			"end_percent": 1.0,
		},
	}
	nodes["21"] = {
		"class_type": "VAEEncode",
		"inputs": {"pixels": ["20", 0], "vae": ["1", 2]},
	}
	nodes["3"] = {
		"class_type": "KSampler",
		"inputs": {
			"seed": int(seed),
			"steps": int(steps),
			"cfg": float(cfg),
			"sampler_name": sampler,
			"scheduler": scheduler,
			"denoise": float(denoise),
			"model": model_src,
			"positive": ["24", 0],
			"negative": ["24", 1],
			"latent_image": ["21", 0],
		},
	}
	nodes["8"] = {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["1", 2]}}
	nodes["9"] = {
		"class_type": "SaveImage",
		"inputs": {"images": ["8", 0], "filename_prefix": prefix},
	}
	return nodes


def build_txt2img(
    prompt: str,
    negative: str,
    seed: int,
    ckpt: str,
    lora: str | None,
    lora_strength: float,
    width: int,
    height: int,
    steps: int,
    cfg: float,
    sampler: str,
    scheduler: str,
    prefix: str,
) -> dict:
    nodes: dict = {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": ckpt}},
    }
    model_src, clip_src = ["1", 0], ["1", 1]
    if lora and lora_strength > 0.01:
        nodes["10"] = {
            "class_type": "LoraLoader",
            "inputs": {
                "model": ["1", 0],
                "clip": ["1", 1],
                "lora_name": lora,
                "strength_model": lora_strength,
                "strength_clip": lora_strength,
            },
        }
        model_src, clip_src = ["10", 0], ["10", 1]
    nodes["6"] = {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": clip_src}}
    nodes["7"] = {"class_type": "CLIPTextEncode", "inputs": {"text": negative, "clip": clip_src}}
    nodes["5"] = {
        "class_type": "EmptyLatentImage",
        "inputs": {"width": width, "height": height, "batch_size": 1},
    }
    nodes["3"] = {
        "class_type": "KSampler",
        "inputs": {
            "seed": int(seed),
            "steps": int(steps),
            "cfg": float(cfg),
            "sampler_name": sampler,
            "scheduler": scheduler,
            "denoise": 1.0,
            "model": model_src,
            "positive": ["6", 0],
            "negative": ["7", 0],
            "latent_image": ["5", 0],
        },
    }
    nodes["8"] = {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["1", 2]}}
    nodes["9"] = {
        "class_type": "SaveImage",
        "inputs": {"images": ["8", 0], "filename_prefix": prefix},
    }
    return nodes


def build_img2img(
    prompt: str,
    negative: str,
    seed: int,
    ckpt: str,
    lora: str | None,
    lora_strength: float,
    steps: int,
    cfg: float,
    sampler: str,
    scheduler: str,
    denoise: float,
    ref_filename: str,
    prefix: str,
) -> dict:
    nodes: dict = {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": ckpt}},
        "20": {"class_type": "LoadImage", "inputs": {"image": ref_filename}},
    }
    model_src, clip_src = ["1", 0], ["1", 1]
    if lora and lora_strength > 0.01:
        nodes["10"] = {
            "class_type": "LoraLoader",
            "inputs": {
                "model": ["1", 0],
                "clip": ["1", 1],
                "lora_name": lora,
                "strength_model": lora_strength,
                "strength_clip": lora_strength,
            },
        }
        model_src, clip_src = ["10", 0], ["10", 1]
    nodes["6"] = {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": clip_src}}
    nodes["7"] = {"class_type": "CLIPTextEncode", "inputs": {"text": negative, "clip": clip_src}}
    nodes["21"] = {
        "class_type": "VAEEncode",
        "inputs": {"pixels": ["20", 0], "vae": ["1", 2]},
    }
    nodes["3"] = {
        "class_type": "KSampler",
        "inputs": {
            "seed": int(seed),
            "steps": int(steps),
            "cfg": float(cfg),
            "sampler_name": sampler,
            "scheduler": scheduler,
            "denoise": float(denoise),
            "model": model_src,
            "positive": ["6", 0],
            "negative": ["7", 0],
            "latent_image": ["21", 0],
        },
    }
    nodes["8"] = {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["1", 2]}}
    nodes["9"] = {
        "class_type": "SaveImage",
        "inputs": {"images": ["8", 0], "filename_prefix": prefix},
    }
    return nodes


def queue_and_wait(workflow: dict, timeout_s: int = 240) -> str:
    r = _http_json("POST", "/prompt", {"prompt": workflow})
    pid = r["prompt_id"]
    print("queued", pid)
    t0 = time.time()
    while time.time() - t0 < timeout_s:
        time.sleep(2)
        try:
            hist = _http_json("GET", f"/history/{pid}", timeout=15)
        except Exception:
            continue
        item = hist.get(pid)
        if not item:
            continue
        status = item.get("status") or {}
        if status.get("status_str") == "error":
            raise SystemExit(f"Comfy error: {status.get('messages')}")
        outs = item.get("outputs") or {}
        if "9" in outs and outs["9"].get("images"):
            img = outs["9"]["images"][0]
            sub = img.get("subfolder") or ""
            path = (
                os.path.join(COMFY_OUT, sub, img["filename"])
                if sub
                else os.path.join(COMFY_OUT, img["filename"])
            )
            if os.path.isfile(path):
                return path
            if status.get("completed"):
                raise SystemExit(f"output missing: {path}")
    raise SystemExit("Comfy generate timeout")


def soft_game_sprite(raw_path: str, out_path: str, palette: str, w: int, h: int) -> None:
    pixelize(
        raw_path,
        out_path,
        palette_name=palette,
        size=w,
        outline=True,
        preview=0,
        out_h=h,
        do_quantize=False,
        retro=False,
    )


def archive_raw_game(
    archive_id: str,
    raw_path: str,
    palette: str,
    game_w: int,
    game_h: int,
    note: str,
    seed: int | None,
    prompt: str,
) -> tuple[str, str]:
    with tempfile.TemporaryDirectory() as td:
        game_tmp = os.path.join(td, "game.png")
        soft_game_sprite(raw_path, game_tmp, palette, game_w, game_h)
        entry = archive_pair(
            archive_id,
            raw_path,
            game_tmp,
            note=note,
            seed=seed,
            prompt=prompt,
            source="comfy_img2img_pick004",
        )
    studio = os.path.join(ROOT, "assets", "pixels", "_studio", archive_id.replace("/", os.sep))
    tag = entry["tag"]
    return os.path.join(studio, f"{tag}_raw.png"), os.path.join(studio, f"{tag}_game.png")


def drop_incoming(raw_path: str, archive_id: str, tag: str) -> str:
    dest_dir = os.path.join(INCOMING, archive_id.replace("/", os.sep))
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, f"{tag}.png")
    shutil.copy2(raw_path, dest)
    return dest


def main():
    cfg = _load_cfg()
    d = cfg["defaults"]
    ap = argparse.ArgumentParser(description="ComfyUI → _studio (pick_004 img2img)")
    ap.add_argument("--preset", default="flame_drake")
    ap.add_argument("--prompt", default="")
    ap.add_argument("--archive", default="")
    ap.add_argument("--palette", default="")
    ap.add_argument("--n", type=int, default=1)
    ap.add_argument("--seed", type=int, default=-1)
    ap.add_argument("--ckpt", default=d["ckpt"])
    ap.add_argument("--lora", default=d["lora"])
    ap.add_argument("--lora-strength", type=float, default=float(d["lora_strength"]))
    ap.add_argument("--no-lora", action="store_true")
    ap.add_argument("--denoise", type=float, default=None, help="override preset/default denoise")
    ap.add_argument("--ref", default="", help="img2img reference (default pick_004 raw)")
    ap.add_argument("--txt2img", action="store_true", help="force text-to-image")
    ap.add_argument("--no-start", action="store_true")
    ap.add_argument("--incoming-only", action="store_true")
    ap.add_argument("--list-presets", action="store_true")
    ap.add_argument("--open", action="store_true")
    args = ap.parse_args()

    if args.list_presets:
        for k, v in cfg["presets"].items():
            print(f"{k}  img2img={v.get('img2img', False)}\n  {v['prompt'][:90]}...")
        return

    presets = cfg["presets"]
    if args.preset not in presets and not args.prompt:
        raise SystemExit(f"unknown preset {args.preset}")

    preset = presets.get(args.preset, presets["generic_pixel"])
    archive_id = args.archive or preset["archive_id"]
    palette = args.palette or preset.get("palette", "dragon")
    style_lock = cfg.get("style_lock", "")
    if preset.get("style_lock") is False:
        style_lock = ""
    prompt = (args.prompt.strip() or preset["prompt"])
    if style_lock:
        prompt = prompt + ", " + style_lock
    negative = cfg.get("negative_ui", cfg["negative"]) if palette == "ui" else cfg["negative"]
    if "negative" in preset:
        negative = preset["negative"]
    game_w = int(preset.get("game_w", d["game_w"]))
    game_h = int(preset.get("game_h", d["game_h"]))
    use_i2i = (not args.txt2img) and bool(preset.get("img2img", True))
    lora = None if args.no_lora else args.lora
    lora_strength = 0.0 if args.no_lora else float(preset.get("lora_strength", args.lora_strength))
    denoise = (
        float(args.denoise)
        if args.denoise is not None
        else float(preset.get("denoise", d.get("denoise", 0.48)))
    )

    if not args.no_start:
        ensure_comfy()
    elif not comfy_up():
        raise SystemExit("ComfyUI not running")

    ref_file = None
    if use_i2i:
        ref_path = args.ref or preset.get("ref") or d.get("ref") or DEFAULT_REF
        if not os.path.isabs(ref_path):
            ref_path = os.path.join(ROOT, ref_path.replace("/", os.sep))
        if not os.path.isfile(ref_path):
            raise SystemExit(f"ref missing: {ref_path}")
        ref_file = stage_ref(ref_path)
        print("img2img ref", ref_path, "denoise", denoise, "lora", lora_strength)

    last_game = ""
    for i in range(args.n):
        seed = args.seed + i if args.seed >= 0 else random.randint(0, 2**31 - 1)
        prefix = f"td_p004_{args.preset}"
        if use_i2i:
            wf = build_img2img(
                prompt=prompt,
                negative=negative,
                seed=seed,
                ckpt=args.ckpt,
                lora=lora,
                lora_strength=lora_strength,
                steps=int(d["steps"]),
                cfg=float(d["cfg"]),
                sampler=d["sampler"],
                scheduler=d["scheduler"],
                denoise=denoise,
                ref_filename=ref_file,
                prefix=prefix,
            )
        else:
            wf = build_txt2img(
                prompt=prompt,
                negative=negative,
                seed=seed,
                ckpt=args.ckpt,
                lora=lora,
                lora_strength=lora_strength,
                width=int(d["width"]),
                height=int(d["height"]),
                steps=int(d["steps"]),
                cfg=float(d["cfg"]),
                sampler=d["sampler"],
                scheduler=d["scheduler"],
                prefix=prefix,
            )
        print(f"[{i+1}/{args.n}] seed={seed} mode={'i2i' if use_i2i else 't2i'}")
        raw_comfy = queue_and_wait(wf)
        print("comfy out", raw_comfy)
        tag = f"{args.preset}_{seed}"
        if args.incoming_only:
            last_game = drop_incoming(raw_comfy, archive_id, tag)
            continue
        raw_arc, game_arc = archive_raw_game(
            archive_id,
            raw_comfy,
            palette,
            game_w,
            game_h,
            note=f"comfy_{'i2i' if use_i2i else 't2i'}_{args.preset}",
            seed=seed,
            prompt=prompt,
        )
        drop_incoming(raw_comfy, archive_id, tag)
        print("archived", raw_arc)
        print("game    ", game_arc)
        last_game = game_arc

    if args.open and last_game and os.path.isfile(last_game):
        os.startfile(last_game)  # type: ignore[attr-defined]
    print("DONE")


if __name__ == "__main__":
    main()
