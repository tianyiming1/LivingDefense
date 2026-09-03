"""
外部 AI 出图导入游戏：把 raw PNG 放进 assets/pixels/_studio/incoming/，一键像素化并写入正式路径。

用法：
  1. 用任意 AI（见 prompts_external.json 里的 prompt）出图
  2. 保存为 assets/pixels/_studio/incoming/human/unit_0.png（或 .jpg / .webp）
  3. 运行：
       python tools/gen/import_ai_sprite.py
       python tools/gen/import_ai_sprite.py --id human/unit_0
       python tools/gen/import_ai_sprite.py --src D:/my_knight.png --id human/unit_0

游戏自动读取 assets/pixels/{race}/unit_{n}.png，无需改代码。
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelize import pixelize  # noqa: E402
from archive_candidates import archive_pair  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
INCOMING = os.path.join(ROOT, "assets", "pixels", "_studio", "incoming")
OUT_ROOT = os.path.join(ROOT, "assets", "pixels")
PROMPTS = os.path.join(os.path.dirname(__file__), "prompts_external.json")

EXTS = (".png", ".jpg", ".jpeg", ".webp")


def _load_manifest():
    with open(PROMPTS, encoding="utf-8") as f:
        return json.load(f)


def _palette_for(asset_id: str, manifest: dict) -> str:
    for group in ("units", "enemies"):
        for item in manifest.get(group, []):
            if item["id"] == asset_id:
                return item["palette"]
    return "human"


def _find_incoming(asset_id: str) -> str | None:
    base = os.path.join(INCOMING, asset_id.replace("/", os.sep))
    for ext in EXTS:
        p = base + ext
        if os.path.isfile(p):
            return p
    # 也支持 _studio/incoming/human/unit_0_raw.png
    for ext in EXTS:
        p = base + "_raw" + ext
        if os.path.isfile(p):
            return p
    return None


def _out_path(asset_id: str) -> str:
    return os.path.join(OUT_ROOT, asset_id.replace("/", os.sep) + ".png")


def import_one(src: str, asset_id: str, manifest: dict, w: int, h: int, outline: bool,
               flip_x: bool = False, do_quantize: bool = False, retro: bool = False,
               note: str = "", seed: int | None = None, prompt: str = "",
               source: str = "import", archive: bool = True):
    palette = _palette_for(asset_id, manifest)
    out = _out_path(asset_id)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    # 正式路径不写 preview，候选编号库里保留
    pixelize(src, out, palette, w, outline, preview=0,
             flip_x=flip_x, out_h=h, do_quantize=do_quantize or retro, retro=retro)
    print("OK", asset_id, "<-", src, "->", out)
    if archive:
        archive_pair(
            asset_id, src, out,
            note=note or "import",
            seed=seed,
            prompt=prompt,
            source=source,
            flip_x=flip_x,
        )
    return out


def list_pending(manifest: dict):
    all_ids = [u["id"] for u in manifest["units"]] + [e["id"] for e in manifest["enemies"]]
    print("=== prompts_external.json 资产清单 ===\n")
    for item in manifest["units"] + manifest["enemies"]:
        aid = item["id"]
        inc = _find_incoming(aid)
        status = "READY" if inc else "missing"
        print("[%s] %s — %s" % (status, aid, item["name"]))
        full = item["prompt"] + manifest.get("style_suffix", "")
        print("  prompt:", full[:120] + ("..." if len(full) > 120 else ""))
        if inc:
            print("  file:", inc)
        print()
    print("负向词:", manifest["meta"]["negative"][:100], "...")
    print("\n放入路径示例:", os.path.join(INCOMING, "human", "unit_0.png"))


def main():
    ap = argparse.ArgumentParser(description="Import external AI sprites into game")
    ap.add_argument("--list", action="store_true", help="Show all assets and prompt snippets")
    ap.add_argument("--id", default="", help="Asset id e.g. human/unit_0 or enemies/enemy_1")
    ap.add_argument("--src", default="", help="Override source image path")
    ap.add_argument("--width", type=int, default=96)
    ap.add_argument("--height", type=int, default=108)
    ap.add_argument("--no-outline", action="store_true")
    ap.add_argument("--flip-x", action="store_true", help="Mirror horizontally (AI often faces left)")
    ap.add_argument("--quantize", action="store_true", help="Force palette quantize (default: keep AI colors)")
    ap.add_argument("--retro", action="store_true", help="Crush HD fake-pixel art to true low-res pixels")
    args = ap.parse_args()
    manifest = _load_manifest()
    os.makedirs(INCOMING, exist_ok=True)

    if args.list:
        list_pending(manifest)
        return

    opts = {
        "flip_x": args.flip_x,
        "do_quantize": args.quantize,
        "retro": args.retro,
    }

    if args.id and args.src:
        import_one(args.src, args.id, manifest, args.width, args.height, not args.no_outline, **opts)
        return

    if args.id:
        src = _find_incoming(args.id)
        if not src:
            print("ERROR: no file in", INCOMING, "for", args.id)
            print("Expected:", os.path.join(INCOMING, args.id.replace("/", os.sep) + ".png"))
            sys.exit(1)
        import_one(src, args.id, manifest, args.width, args.height, not args.no_outline, **opts)
        return

    # 批量：导入 _studio/incoming 里所有能找到的
    done = 0
    for item in manifest["units"] + manifest["enemies"]:
        aid = item["id"]
        src = _find_incoming(aid)
        if src:
            import_one(src, aid, manifest, args.width, args.height, not args.no_outline, **opts)
            done += 1
    if done == 0:
        print("No files in", INCOMING)
        print("Run with --list to see prompts, then save AI images and re-run.")
    else:
        print("Imported", done, "sprites. F5 to preview in game.")


if __name__ == "__main__":
    main()
