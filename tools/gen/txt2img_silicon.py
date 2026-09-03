"""LCM 文生图：硅基流动概念图（4 步快速）"""
import argparse, sys, random
import torch
from diffusers import StableDiffusionPipeline, LCMScheduler

NEG = 'blurry, low quality, watermark, text, noise, oversaturated'

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--prompt', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--seed', type=int, default=42)
    ap.add_argument('--steps', type=int, default=4)
    ap.add_argument('--cfg', type=float, default=1.5)
    ap.add_argument('--model', default=r'D:\AI_models\lcm_dreamshaper_v7')
    args = ap.parse_args()

    assert torch.cuda.is_available(), 'CUDA not available'
    print('loading model...', flush=True)
    pipe = StableDiffusionPipeline.from_pretrained(
        args.model, torch_dtype=torch.float16, safety_checker=None, requires_safety_checker=False)
    pipe.scheduler = LCMScheduler.from_config(pipe.scheduler.config)
    pipe = pipe.to('cuda')
    pipe.enable_attention_slicing()
    print('generating...', flush=True)
    g = torch.Generator(device='cuda').manual_seed(args.seed)
    img = pipe(prompt=args.prompt, negative_prompt=NEG, num_inference_steps=args.steps,
               guidance_scale=args.cfg, generator=g, width=768, height=768).images[0]
    img.save(args.out)
    print('saved:', args.out)

if __name__ == '__main__':
    main()
