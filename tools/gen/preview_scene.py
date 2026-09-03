"""游戏内画面预览 v0.1 —— 把转制资产拼成模拟游戏画面（1280x720）"""
import argparse, os
from PIL import Image, ImageDraw, ImageFont

def try_font(size):
    for name in ["arial.ttf", "segoeui.ttf", "msyh.ttc"]:
        try:
            return ImageFont.truetype("C:\\Windows\\Fonts\\" + name, size)
        except Exception:
            pass
    return ImageFont.load_default()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--bg', required=True)
    ap.add_argument('--unit', required=True)
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    os.makedirs(os.path.dirname(a.out), exist_ok=True)

    W, H = 1280, 720
    bg = Image.open(a.bg).convert("RGB")
    # 背景等比裁剪到画面
    w, h = bg.size
    scale = max(W / w, H / h)
    bg = bg.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
    bx, by = (bg.width - W) // 2, (bg.height - H) // 2
    bg = bg.crop((bx, by, bx + W, by + H))
    scene = bg.convert("RGBA")

    # 战场整体压暗一层，让单位/路径可读
    dark = Image.new("RGBA", (W, H), (8, 10, 14, 118))
    scene = Image.alpha_composite(scene, dark)
    d = ImageDraw.Draw(scene)

    # 主路径（折线，深灰半透明）—— 从左侧进入绕到右下基地
    path_pts = [(-30, 210), (260, 220), (430, 150), (610, 160), (760, 300),
                (720, 470), (900, 560), (1110, 540), (1260, 600)]
    d.line(path_pts, fill=(30, 34, 40, 165), width=56)
    d.line(path_pts, fill=(16, 18, 22, 120), width=34)  # 路径内深线

    # 硅基单位站位：沿路径摆 5 个战士贴图
    unit = Image.open(a.unit).convert("RGBA")
    spots = [(420, 140), (600, 150), (705, 290), (880, 545), (1000, 530)]
    for (ux, uy) in spots:
        scene.alpha_composite(unit, (ux - unit.width // 2, uy - unit.height // 2))
        d.ellipse([ux - 52, uy + 46, ux + 52, uy + 92], outline=(111, 211, 231, 120), width=2)  # 站位圈

    # 基地 / 晶核（右下）：六边形描边
    cx, cy, r = 1130, 600, 64
    hex_pts = [(cx + r * math.cos(math.radians(a2)), cy + r * math.sin(math.radians(a2)))
               for a2 in range(30, 390, 60)]
    d.polygon(hex_pts, outline=(111, 211, 231, 220), width=3, fill=(20, 40, 55, 120))
    d.text((cx - 22, cy - 8), "核", fill=(245, 249, 255, 230), font=try_font(26))

    # HUD 顶栏（半透明条）
    d.rectangle([0, 0, W, 52], fill=(10, 14, 20, 170))
    # 晶能条
    d.text((20, 10), "晶能", fill=(200, 230, 245, 255), font=try_font(20))
    d.rectangle([78, 14, 318, 38], outline=(111, 211, 231, 255), width=2)
    d.rectangle([80, 16, 80 + int(238 * 0.62), 36], fill=(111, 211, 231, 230))
    d.text((250, 10), "128/200", fill=(245, 249, 255, 255), font=try_font(18))
    # 波次信息
    d.text((980, 10), "波次 3 / 12", fill=(245, 249, 255, 255), font=try_font(20))
    d.text((1140, 10), "矿石 240", fill=(255, 208, 112, 255), font=try_font(18))

    # 底部说明
    d.rectangle([0, H - 34, W, H], fill=(8, 10, 14, 200))
    d.text((W // 2 - 300, H - 30), "AI 转制画面预览（示意，非最终画面） 单位=unit_warrior_128 背景=bg_veins_dark",
           fill=(160, 175, 190, 255), font=try_font(16))

    scene.convert("RGB").save(a.out, optimize=True)
    print("DONE ->", a.out)

if __name__ == "__main__":
    import math
    main()