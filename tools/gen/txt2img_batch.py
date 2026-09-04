"""批量出图：硅基流动概念图（单进程加载一次 pipe，多场景×seed）"""
import argparse, json, os, sys, time
import torch
from diffusers import StableDiffusionPipeline, LCMScheduler

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--json', default=r'D:\GameWorkSpace\TowerDefenseProto\tools\gen\prompts_silicon.json')
    ap.add_argument('--outdir', default=r'D:\GameWorkSpace\TowerDefenseProto\docs\ai_concepts')
    ap.add_argument('--model', default=r'D:\AI_models\lcm_dreamshaper_v7')
    ap.add_argument('--seeds', type=int, default=2)
    ap.add_argument('--steps', type=int, default=4)
    ap.add_argument('--cfg', type=float, default=1.5)
    ap.add_argument('--size', type=int, default=768)
    args = ap.parse_args()

    assert torch.cuda.is_available(), 'CUDA not available'
    data = json.load(open(args.json, encoding='utf-8-sig'))
    os.makedirs(args.outdir, exist_ok=True)

    print('loading model once ...', flush=True)
    t0 = time.time()
    pipe = StableDiffusionPipeline.from_pretrained(
        args.model, torch_dtype=torch.float16, safety_checker=None, requires_safety_checker=False)
    pipe.scheduler = LCMScheduler.from_config(pipe.scheduler.config)
    pipe = pipe.to('cuda')
    pipe.enable_attention_slicing()
    print('model loaded in %.1fs' % (time.time() - t0), flush=True)

    neg = data['negative']
    suffix = data['style_suffix']
    base_seed = int(time.time()) % 100000
    for scene in data['scenes']:
        for s in range(args.seeds):
            seed = base_seed + (hash(scene['id']) % 10000) + s * 977
            g = torch.Generator(device='cuda').manual_seed(seed)
            prompt = scene['prompt'] + suffix
            t1 = time.time()
            img = pipe(prompt=prompt, negative_prompt=neg, num_inference_steps=args.steps,
                       guidance_scale=args.cfg, generator=g,
                       width=args.size, height=args.size).images[0]
            out = os.path.join(args.outdir, scene['id'] + '_s' + str(s + 1) + '_seed' + str(seed) + '.png')
            img.save(out)
            print('[%s s%d] %.1fs -> %s' % (scene['id'], s + 1, time.time() - t1, out), flush=True)
    print('ALL DONE')

if __name__ == '__main__':
    main()

