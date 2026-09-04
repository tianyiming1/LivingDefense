#!/usr/bin/env python3
"""
sprite2sheet.py — 通用"视频/图片序列 → Godot 序列帧图集"工具

用法示例:
  # 从视频生成 16 帧图集（自动检测背景色，自动去水印）
  python sprite2sheet.py dragon.mp4 --frames 16 --out-prefix dragon

  # 纯白背景素材、像素风缩放、拆成两段动画
  python sprite2sheet.py hero.mp4 --bg white --pixel-art --cell 96 --segments 0-7,8-15

  # 输入一个文件夹里的 png 序列（已抽好的帧）也行
  python sprite2sheet.py ./frames_dir/ --out-prefix boss

依赖: pip install pillow imageio imageio-ffmpeg numpy
"""
import argparse
import os
import sys
import glob

import numpy as np
from PIL import Image


def load_frames(path: str) -> np.ndarray:
    """输入 mp4 或图片文件夹，返回 (T,H,W,3) uint8 数组。"""
    if os.path.isdir(path):
        files = sorted(
            f for f in glob.glob(os.path.join(path, "*"))
            if f.lower().endswith((".png", ".jpg", ".jpeg", ".bmp", ".webp"))
        )
        if not files:
            sys.exit(f"[错误] {path} 里没有图片")
        return np.stack([np.array(Image.open(f).convert("RGB")) for f in files])
    if not os.path.isfile(path):
        sys.exit(f"[错误] 找不到 {path}")
    import imageio
    reader = imageio.get_reader(path)
    frames = np.stack([np.array(f)[..., :3] for f in reader])
    reader.close()
    return frames


def detect_bg(frames: np.ndarray, margin_ratio: float = 0.02) -> np.ndarray:
    """取四边边框像素的中位数估计背景色。"""
    h, w = frames.shape[1:3]
    my, mx = max(1, int(h * margin_ratio)), max(1, int(w * margin_ratio))
    border = np.concatenate([
        frames[:, :my].reshape(-1, 3),
        frames[:, -my:].reshape(-1, 3),
        frames[:, :, :mx].reshape(-1, 3),
        frames[:, :, -mx:].reshape(-1, 3),
    ])
    return np.median(border, axis=0)


def remove_watermark(arr: np.ndarray, bg: np.ndarray, frac: float) -> np.ndarray:
    """底部 frac 区域内的灰色文字像素（低饱和、中亮度）置为背景色。"""
    h = arr.shape[0]
    y0 = int(h * (1 - frac))
    region = arr[y0:]
    r, g, b = region[..., 0].astype(int), region[..., 1].astype(int), region[..., 2].astype(int)
    mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
    gray_text = (mx - mn < 28) & (mx > 60) & (mx < 215)
    region[gray_text] = bg.astype(np.uint8)
    arr[y0:] = region
    return arr


def union_bbox(frames: np.ndarray, bg: np.ndarray, tol: int,
               cut_bottom: float = 0.0, pad: int = 8):
    """所有帧中"非背景"内容的联合包围盒。cut_bottom 用于排除水印区。"""
    h, w = frames.shape[1:3]
    limit = int(h * (1 - cut_bottom))
    minx, miny, maxx, maxy = w, h, -1, -1
    bgf = bg.astype(np.float32)
    for f in frames:
        d = np.abs(f[:limit].astype(np.float32) - bgf).max(axis=2)
        ys, xs = np.where(d > tol)
        if len(xs) == 0:
            continue
        minx, miny = min(minx, int(xs.min())), min(miny, int(ys.min()))
        maxx, maxy = max(maxx, int(xs.max())), max(maxy, int(ys.max()))
    if maxx < 0:
        sys.exit("[错误] 没检测到内容，试试调大 --bg-tol")
    return (max(0, minx - pad), max(0, miny - pad),
            min(w - 1, maxx + pad), min(limit - 1, maxy + pad))


def parse_segments(spec: str, total: int):
    """'0-7,8-15' -> [(0,8),(8,16)]；缺省为整段。"""
    if not spec:
        return [(0, total)]
    segs = []
    for part in spec.split(","):
        a, _, b = part.partition("-")
        segs.append((int(a), (int(b) + 1) if b else int(a) + 1))
    return segs


def write_godot_tres(out_path: str, anims, cols: int, cell: int, fps: int):
    """生成 Godot 4 SpriteFrames .tres 资源。

    anims = [(名称, 帧数, 是否循环, 图集文件名)]，每段可来自不同图集。
    .tres 与各图集放同一目录即可直接加载。
    """
    sheets = sorted({a[3] for a in anims})
    total_subs = sum(a[1] for a in anims)
    load_steps = len(sheets) + total_subs + 1
    L = [f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]', ""]
    for k, s in enumerate(sheets, 1):
        L += [f'[ext_resource type="Texture2D" path="res://{s}" id="{k}_sheet"]', ""]
    sid = 0
    anim_dicts = []
    for name, count, loop, sheet_file in anims:
        ext_id = f'{sheets.index(sheet_file) + 1}_sheet'
        frame_refs = []
        for i in range(count):
            sid += 1
            x, y = (i % cols) * cell, (i // cols) * cell
            L += [f'[sub_resource type="AtlasTexture" id="Sprite2Sheet_at{sid}"]',
                  f'atlas = ExtResource("{ext_id}")',
                  f'region = Rect2({x}, {y}, {cell}, {cell})', ""]
            frame_refs.append(f'{{\n"duration": 1.0,\n"texture": SubResource("Sprite2Sheet_at{sid}")\n}}')
        anim_dicts.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %d.0\n}'
                          % (", ".join(frame_refs), "true" if loop else "false", name, fps))
    L += ["[resource]", "animations = [" + ", ".join(anim_dicts) + "]"]
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")


GD_ANIM_SCRIPT = """extends AnimatedSprite2D
## 通用动画状态机：animation_finished 后自动回到 fallback 动画(默认第一个)。
## 用法: start("land") 播放一次性动作, 播完自动回 fallback。

@export var fallback: StringName = &""

func _ready() -> void:
    if fallback == &"":
        fallback = sprite_frames.get_animation_names()[0]
    animation_finished.connect(_on_finished)
    play(fallback)

func start(anim: StringName) -> void:
    play(anim)

func _on_finished() -> void:
    if not sprite_frames.get_animation_loop(animation):
        play(fallback)
"""


def main():
    ap = argparse.ArgumentParser(description="视频/图片序列 → Godot 序列帧图集")
    ap.add_argument("input", help="mp4 视频 或 图片文件夹")
    ap.add_argument("--frames", type=int, default=16, help="每个动作抽几帧 (默认 16)")
    ap.add_argument("--cols", type=int, default=4, help="图集列数 (默认 4)")
    ap.add_argument("--cell", type=int, default=0, help="输出格子边长，0=自动取内容最大边")
    ap.add_argument("--pixel-art", action="store_true", help="最近邻缩放（像素风），默认 LANCZOS")
    ap.add_argument("--bg", default="auto", help="背景色: auto/black/white 或 R,G,B (默认 auto)")
    ap.add_argument("--bg-tol", type=int, default=30, help="背景判定阈值 (默认 30)")
    ap.add_argument("--wm", action="store_true", help="启用底部水印清理")
    ap.add_argument("--wm-strip", type=float, default=0.06, help="水印区高度比例 (默认 0.06)")
    ap.add_argument("--segments", default="", help="按帧拆多段动画，如 0-7,8-15")
    ap.add_argument("--no-crop", action="store_true",
                    help="不裁剪内容包围盒，保留整帧（地形/天气等需要格对位的素材必用）")
    ap.add_argument("--anim-names", default="", help="各段动画名，逗号分隔，如 fly,land (默认 anim_1/anim_2...)")
    ap.add_argument("--fps", type=int, default=12, help="GIF 预览帧率 / Godot 动画帧率 (默认 12)")
    ap.add_argument("--no-godot", action="store_true", help="不生成 Godot .tres 资源")
    ap.add_argument("--out-prefix", default="sprite", help="输出文件名前缀")
    args = ap.parse_args()

    frames = load_frames(args.input)
    T, H, W = frames.shape[0], frames.shape[1], frames.shape[2]
    print(f"[输入] {args.input}: {T} 帧, {W}x{H}")

    bg = (np.array([0, 0, 0]) if args.bg == "black"
          else np.array([255, 255, 255]) if args.bg == "white"
          else np.array([int(v) for v in args.bg.split(",")]) if "," in args.bg
          else detect_bg(frames))
    print(f"[背景] RGB={tuple(int(v) for v in bg)}")

    cut = args.wm_strip if args.wm else 0.0
    work = frames
    if args.wm:
        work = np.stack([remove_watermark(f.copy(), bg, 0.10) for f in frames])

    if args.no_crop:
        minx, miny, maxx, maxy = 0, 0, W - 1, H - 1
    else:
        minx, miny, maxx, maxy = union_bbox(work, bg, args.bg_tol, cut_bottom=cut)
    cw, ch = maxx - minx + 1, maxy - miny + 1
    side = max(cw, ch)
    print(f"[包围盒] ({minx},{miny})-({maxx},{maxy})  内容 {cw}x{ch}")

    cell = args.cell or side
    resample = Image.NEAREST if args.pixel_art else Image.LANCZOS
    segs = parse_segments(args.segments, min(args.frames, T))
    n = args.frames
    names = [s.strip() for s in args.anim_names.split(",") if s.strip()]
    godot_anims = []

    for si, (a, b) in enumerate(segs):
        cnt = min(n, b - a)
        idxs = [round(a + i * (b - 1 - a) / max(1, cnt - 1)) for i in range(cnt)]
        idxs = sorted(set(min(i, T - 1) for i in idxs))
        imgs = []
        for fi in idxs:
            arr = work[fi]
            if args.wm:
                arr = remove_watermark(arr.copy(), bg, 0.10)
            im = Image.fromarray(arr).crop((minx, miny, maxx + 1, maxy + 1))
            canvas = Image.new("RGB", (side, side), tuple(int(v) for v in bg))
            canvas.paste(im, ((side - cw) // 2, (side - ch) // 2))
            if cell != side:
                canvas = canvas.resize((cell, cell), resample)
            imgs.append(canvas)

        tag = f"_{si+1}" if len(segs) > 1 else ""
        out_sheet = f"{args.out_prefix}{tag}_sheet.png"
        cols = min(args.cols, len(imgs))
        rows = (len(imgs) + cols - 1) // cols
        rgba = [im.convert("RGBA") for im in imgs]

        # 透明底图集
        sheet = Image.new("RGBA", (cell * cols, cell * rows), (0, 0, 0, 0))
        arrs = np.stack([np.array(im) for im in rgba]).astype(np.float32)
        dist = np.abs(arrs[..., :3] - bg.astype(np.float32)).max(axis=3)
        alpha = np.where(dist > args.bg_tol, 255, 0).astype(np.uint8)
        arrs[..., 3] = alpha
        for i, a4 in enumerate(arrs):
            sheet.paste(Image.fromarray(a4.astype(np.uint8)), ((i % cols) * cell, (i // cols) * cell))
        sheet.save(out_sheet)

        # 单帧 + GIF 预览
        fdir = f"{args.out_prefix}{tag}_frames"
        os.makedirs(fdir, exist_ok=True)
        pframes = []
        for i, a4 in enumerate(arrs):
            Image.fromarray(a4.astype(np.uint8)).save(os.path.join(fdir, f"frame_{i:02d}.png"))
            pf = Image.new("RGBA", (cell, cell), tuple(int(v) for v in bg) + (255,))
            pf.alpha_composite(Image.fromarray(a4.astype(np.uint8)))
            pframes.append(pf.convert("P", palette=Image.ADAPTIVE))
        pframes[0].save(f"{args.out_prefix}{tag}_preview.gif", save_all=True,
                        append_images=pframes[1:], duration=int(1000 / args.fps), loop=0)

        anim_name = names[si] if si < len(names) else f"anim_{si+1}"
        loop = si < len(segs) - 1  # 最后一段默认不循环（适合落地/攻击收尾）
        godot_anims.append((anim_name, len(imgs), loop, os.path.basename(out_sheet)))

        print(f"[输出] {out_sheet} ({cell*cols}x{cell*rows}, {cols}列x{rows}行) "
              f"+ {fdir}/ + {args.out_prefix}{tag}_preview.gif")

    if not args.no_godot and godot_anims:
        tres_path = f"{args.out_prefix}_spriteframes.tres"
        write_godot_tres(tres_path, godot_anims, min(args.cols, n), cell, args.fps)
        with open(f"{args.out_prefix}_sprite_anim.gd", "w", encoding="utf-8") as f:
            f.write(GD_ANIM_SCRIPT)
        print(f"[输出] {tres_path} + {args.out_prefix}_sprite_anim.gd  "
              f"(Godot: 与图集放同一目录, AnimatedSprite2D 的 SpriteFrames 属性选这个 .tres)")

    print("\nGodot: AnimatedSprite2D -> SpriteFrames -> 逐帧拖入或导入面板切格"
          f"\n建议帧率: 待机/飞行循环 {args.fps}~16 FPS, 落地/攻击 {max(8, args.fps-2)}~{args.fps} FPS")


if __name__ == "__main__":
    main()
