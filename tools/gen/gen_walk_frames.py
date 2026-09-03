"""行走帧生成：warrior 4 帧步态循环（AI 出图 + 转制 128px）"""
import os, sys, time
import torch
from diffusers import StableDiffusionPipeline, LCMScheduler
from PIL import Image, ImageEnhance, ImageFilter

MODEL = r"D:\AI_models\lcm_dreamshaper_v7"
BASE_EXP = r"D:\GameWorkSpace\TowerDefenseProto\docs\repurpose_demo\walk_frames"
NEG = "blurry, low quality, watermark, text, logo, noise, oversaturated, extra limbs, extra arms, deformed"
STYLE = ", digital concept art, dark background, cinematic lighting, high detail"

BASE = "glowing silicon crystal warrior, faceted hexagonal armor, cyan energy core in chest, radiant white highlights"
GAITS = [
    ("w1", "walking forward, left leg striding forward, arms swinging"),
    ("w2", "walking forward, right leg striding forward, arms swinging"),
    ("w3", "walking forward, legs crossing mid-step, torso slightly leaning forward"),
    ("w4", "walking forward, legs passing each other, next stride beginning"),
]

TARGET_BG = (111, 211, 231)
TARGET_HI = (245, 249, 255)

def clamp(v):
    return max(0, min(255, int(v)))

def calibrate(img, amount=0.35):
    px = img.load(); w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y][:3]
            lum = 0.299*r + 0.587*g + 0.114*b
            r2 = clamp(r + (TARGET_BG[0]-r)*amount)
            g2 = clamp(g + (TARGET_BG[1]-g)*amount)
            b2 = clamp(b + (TARGET_BG[2]-b)*amount)
            if lum > 200:
                r2 = clamp(r2 + (TARGET_HI[0]-r2)*0.4)
                g2 = clamp(g2 + (TARGET_HI[1]-g2)*0.4)
                b2 = clamp(b2 + (TARGET_HI[2]-b2)*0.4)
            px[x, y] = (r2, g2, b2)
    return img

def unit_crop(src, size=128):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    side = int(min(w, h) * 0.55)
    left = (w - side)//2
    top = int(h*0.18)
    im = im.crop((left, top, left+side, top+side))
    im = calibrate(im, 0.35)
    return im.resize((size, size), Image.LANCZOS)

def main():
    assert torch.cuda.is_available()
    os.makedirs(BASE_EXP, exist_ok=True)
    os.makedirs(os.path.join(BASE_EXP, "raw"), exist_ok=True)
    print("loading pipe...", flush=True)
    pipe = StableDiffusionPipeline.from_pretrained(MODEL, torch_dtype=torch.float16,
        safety_checker=None, requires_safety_checker=False)
    pipe.scheduler = LCMScheduler.from_config(pipe.scheduler.config)
    pipe = pipe.to("cuda")
    pipe.enable_attention_slicing()
    seeds = [101, 202, 303, 404]
    for i, (fid, gait) in enumerate(GAITS):
        prompt = BASE + ", " + gait + STYLE
        g = torch.Generator(device="cuda").manual_seed(seeds[i])
        t0 = time.time()
        img = pipe(prompt=prompt, negative_prompt=NEG, num_inference_steps=4,
                   guidance_scale=1.5, generator=g, width=768, height=768).images[0]
        raw = os.path.join(BASE_EXP, "raw", fid + ".png")
        img.save(raw)
        u = unit_crop(raw)
        out = os.path.join(BASE_EXP, fid + "_128.png")
        u.save(out)
        print("[%s] %.1fs -> %s" % (fid, time.time() - t0, out), flush=True)
    print("ALL DONE")

if __name__ == "__main__":
    main()