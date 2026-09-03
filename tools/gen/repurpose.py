"""AI 资产转制工具 v0.1 —— 演示转制流程：概念图 -> 游戏资产形态"""
import argparse, os, math
from PIL import Image, ImageFilter, ImageEnhance, ImageDraw

TARGET_BG  = (111, 211, 231)   # ART_GUIDE 硅基青 #6FD3E7
TARGET_HI  = (245, 249, 255)   # #F5F9FF

def clamp(v): return max(0, min(255, int(v)))

def calibrate(img, amount):
    """校色闸：像素向硅基色板拉拢 amount(0-1)，保持亮度结构"""
    px = img.load(); w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y][:3]
            lum = 0.299*r + 0.587*g + 0.114*b
            r2 = clamp(r + (TARGET_BG[0]-r)*amount)
            g2 = clamp(g + (TARGET_BG[1]-g)*amount)
            b2 = clamp(b + (TARGET_BG[2]-b)*amount)
            # 高光区向白
            if lum > 200:
                r2 = clamp(r2 + (TARGET_HI[0]-r2)*0.4)
                g2 = clamp(g2 + (TARGET_HI[1]-g2)*0.4)
                b2 = clamp(b2 + (TARGET_HI[2]-b2)*0.4)
            a = px[x, y][3] if len(px[x, y]) == 4 else 255
            px[x, y] = (r2, g2, b2, a)
    return img

def bg_mode(src, out, cal=0.15):
    im = Image.open(src).convert("RGB")
    # 压暗 + 降饱和 + 轻微模糊：远景板，不干扰 HUD/路径可读性
    im = ImageEnhance.Brightness(im).enhance(0.55)
    im = ImageEnhance.Color(im).enhance(0.8)
    im = im.filter(ImageFilter.GaussianBlur(1.2))
    im = calibrate(im, cal)
    # 等比到 1920 宽
    w, h = im.size
    nw = 1920; nh = int(h * nw / w)
    im = im.resize((nw, nh), Image.LANCZOS)
    im.save(out, optimize=True)

def unit_mode(src, out, size=128, cal=0.35, show=4):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    # 主体区：中心 55% 正方形裁剪（单位特写）
    side = int(min(w, h) * 0.55)
    left = (w - side)//2; top = int(h*0.18)  # 略偏上取主体
    im = im.crop((left, top, left+side, top+side))
    im = calibrate(im, cal)
    im = im.resize((size, size), Image.LANCZOS)
    # 4x 放大预览 + 参数标注
    big = im.resize((size*show, size*show), Image.NEAREST)
    d = ImageDraw.Draw(big)
    d.text((8, 8), "SIZE=%dpx CAL=%.2f TARGET=%s" % (size, cal, "#6FD3E7"), fill=(255,255,255))
    im.save(out, optimize=True)
    big.save(out.replace(".png", "_preview4x.png"), optimize=True)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--mode', choices=['bg', 'unit'], required=True)
    ap.add_argument('--cal', type=float, default=0.15)
    a = ap.parse_args()
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    if a.mode == 'bg': bg_mode(a.src, a.out, a.cal)
    else: unit_mode(a.src, a.out, cal=a.cal)
    print('DONE ->', a.out)

if __name__ == '__main__':
    main()