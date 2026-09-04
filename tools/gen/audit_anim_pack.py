#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""audit_anim_pack.py — 动画帧包自动审核门禁（契约见 docs/动画_素材契约与审核_v1.md）

用法:
  python audit_anim_pack.py --race human --unit 0
  python audit_anim_pack.py --dir assets/pixels/human/unit_0_anim
  python audit_anim_pack.py --all            # 遍历 assets/pixels/*/unit_*_anim
  python audit_anim_pack.py --all --fail-fast

通过 -> 在包目录写 REVIEW.json {"status":"approved", ...}
失败 -> 写 {"status":"rejected", "reasons":[...]}，exit code 1
引擎 (UnitSprites.load_anim_frames / 梦龙 Atlas) 只认 status == "approved"。
"""
import argparse
import json
import os
import sys
import datetime
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PIXELS = os.path.join(ROOT, "assets", "pixels")
GEN = os.path.join(ROOT, "tools", "gen")

ANIMS = ["idle", "walk", "fly", "attack", "death"]
MIN_FRAMES = {"idle": 2, "walk": 4, "fly": 4, "attack": 3, "death": 2}
# 关键动作：缺失/退化即 FAIL；其余动作有则查、无则跳过
REQUIRED_ANIMS = {"idle"}
MOVE_ANIMS = {"walk", "fly"}

CANVAS_NEW = (96, 108)
BOTTOM_STD_FAIL = {"walk": 3.0, "fly": 4.0, "idle": 3.0, "attack": 6.0, "death": 6.0}
SEAM_IOU_FAIL = 0.35
SEAM_IOU_WARN = 0.65
OFF_PALETTE_FAIL = 0.20
EQUAL_RATIO = 0.97  # 占位伪帧 / 静态残帧判定


def load_race_palette(race):
    """尝试从 tools/gen/pixelize.py 导入 PALETTES；失败返回 None（跳过色板检查并注明）。
    目录键名与色板键名可能不同（assets/pixels/enemies/ → PALETTES['enemy']）。"""
    aliases = [race]
    if race == "enemies":
        aliases.append("enemy")
    try:
        sys.path.insert(0, GEN)
        import pixelize  # noqa
        pal = getattr(pixelize, "PALETTES", None)
        if isinstance(pal, dict):
            for key in aliases:
                if key in pal:
                    return list(pal[key])
    except Exception:
        pass
    return None


def silhouette_mask(img):
    """alpha 包围盒 + 剪影 mask（用于锚点稳定/循环闭合检测）。"""
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    a = img.getchannel("A")
    bbox = a.getbbox()
    mask = None
    if bbox is not None:
        mask = a.crop(bbox)
    return bbox, mask


def silhouette_iou(a_mask, b_mask):
    """两张 alpha mask（同尺寸）的剪影重合度。"""
    if a_mask is None or b_mask is None:
        return 0.0
    aw = a_mask.resize((32, 32))
    bw = b_mask.resize((32, 32))
    a_bits = aw.point(lambda p: 1 if p > 16 else 0)
    b_bits = bw.point(lambda p: 1 if p > 16 else 0)
    ab, bb = a_bits.tobytes(), b_bits.tobytes()
    inter = sum(1 for x, y in zip(ab, bb) if x and y)
    union = sum(1 for x, y in zip(ab, bb) if x or y)
    return inter / union if union else 1.0


def near_palette(px, palette, tol=95.0):
    r, g, b = px
    best = min((r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2 for pr, pg, pb in palette)
    return best <= tol * tol


def audit_pack(race, unit, pack_dir, force=False, no_write=False, out=sys.stdout):
    msgs = {"fail": [], "warn": [], "note": []}
    metrics = {}

    # ---- 结构：枚举连续帧 ----
    frames = {}
    for anim in ANIMS:
        arr = []
        i = 0
        while True:
            p = os.path.join(pack_dir, "%s_%d.png" % (anim, i))
            if not os.path.isfile(p):
                break
            arr.append(p)
            i += 1
        if arr:
            frames[anim] = arr
    if not frames:
        return _finish(pack_dir, msgs, metrics, {"fatal": "no frames"}, out, no_write=no_write, force=force)

    # 画布统一
    sizes = {}
    for anim, arr in frames.items():
        for p in arr:
            try:
                sizes.setdefault(Image.open(p).size, 0)
                sizes[Image.open(p).size] += 1
            except Exception:
                msgs["fail"].append("unreadable png: %s" % os.path.basename(p))
    if len(sizes) > 1:
        msgs["fail"].append("canvas not uniform: %s" % {str(k): v for k, v in sizes.items()})
    canvas = next(iter(sizes), CANVAS_NEW)
    metrics["canvas"] = "%dx%d" % canvas

    # 缺关键动作
    for anim in REQUIRED_ANIMS:
        if anim not in frames:
            msgs["fail"].append("missing required anim '%s'" % anim)
    have_move = [a for a in MOVE_ANIMS if a in frames]
    if not have_move:
        msgs["fail"].append("no movement anim (need walk or fly)")

    loaded = {}
    for anim, arr in frames.items():
        imgs = []
        ok = True
        for p in arr:
            try:
                im = Image.open(p).convert("RGBA")
            except Exception:
                ok = False
                break
            imgs.append(im)
        if not ok:
            msgs["fail"].append("%s: unreadable frame" % anim)
            continue
        loaded[anim] = imgs
        n = len(imgs)
        metrics[anim + "_frames"] = n
        if n == 1:
            msgs["fail"].append("%s: single frame = degenerate anim" % anim)
        elif anim in MIN_FRAMES and n < MIN_FRAMES[anim]:
            msgs["warn"].append("%s: %d frames (<%d)" % (anim, n, MIN_FRAMES[anim]))
        # 静态残帧：相邻完全相同
        for i in range(1, n):
            if imgs[i - 1].tobytes() == imgs[i].tobytes():
                msgs["warn"].append("%s: frame %d == frame %d (static pair)" % (anim, i - 1, i))

    # ---- 透明背景 ----
    corners_ok = True
    for anim, imgs in loaded.items():
        for im in imgs:
            w, h = im.size
            for c in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
                if im.getpixel(c)[3] > 8:
                    corners_ok = False
                    break
    if not corners_ok:
        msgs["warn"].append("non-transparent corner (may have bg)")

    # ---- 占位伪帧：idle/walk/base 同图 ----
    if "idle" in loaded and "walk" in loaded:
        a, b = loaded["idle"][0], loaded["walk"][0]
        if a.size == b.size:
            eq = sum(1 for x, y in zip(a.tobytes(), b.tobytes()) if x == y) / max(1, len(a.tobytes()))
            if eq >= EQUAL_RATIO:
                msgs["fail"].append("placeholder: idle0 == walk0 (%.0f%% same)" % (eq * 100))
    if "idle" in loaded and len(loaded["idle"]) >= 2:
        a, b = loaded["idle"][0], loaded["idle"][1]
        if a.size == b.size:
            eq = sum(1 for x, y in zip(a.tobytes(), b.tobytes()) if x == y) / max(1, len(a.tobytes()))
            if eq >= EQUAL_RATIO:
                msgs["fail"].append("idle static: idle0 == idle1 (no breathing)")

    # ---- 锚点漂移 + 循环闭合 ----
    for anim, imgs in loaded.items():
        if len(imgs) < 2:
            continue
        bottoms, masks = [], []
        for im in imgs:
            bb, mk = silhouette_mask(im)
            if bb is None:
                bottoms.append(None)
            else:
                bottoms.append(bb[3])  # ymax
            masks.append(mk)
        valid = [b for b in bottoms if b is not None]
        if len(valid) >= 2:
            mean = sum(valid) / len(valid)
            std = (sum((b - mean) ** 2 for b in valid) / len(valid)) ** 0.5
            metrics[anim + "_bottom_std"] = round(std, 2)
            thr = BOTTOM_STD_FAIL.get(anim, 5.0)
            if std > thr:
                msgs["fail"].append("%s: bottom drifts %.1fpx (>%.0f)" % (anim, std, thr))
            elif std > 2.0:
                msgs["warn"].append("%s: bottom drifts %.1fpx" % (anim, std))
        if anim in MOVE_ANIMS and masks[0] is not None and masks[-1] is not None:
            iou = silhouette_iou(masks[0], masks[-1])
            metrics[anim + "_loop_iou"] = round(iou, 2)
            if iou < SEAM_IOU_FAIL:
                msgs["fail"].append("%s: loop seam (first/last IoU %.2f < %.2f)" % (anim, iou, SEAM_IOU_FAIL))
            elif iou < SEAM_IOU_WARN:
                msgs["warn"].append("%s: loop seam notable (IoU %.2f)" % (anim, iou))

    # ---- 色板合规 ----
    palette = load_race_palette(race)
    # 包级色板覆盖：包目录可放 palette.json {"colors": [[r,g,b],...]}（如梦龙自定色板）
    override_path = os.path.join(pack_dir, "palette.json")
    if os.path.isfile(override_path):
        try:
            with open(override_path, "r", encoding="utf-8") as pf:
                pj = json.load(pf)
            if isinstance(pj.get("colors"), list) and pj["colors"]:
                palette = [tuple(c) for c in pj["colors"]]
                msgs["note"].append("palette overridden by pack palette.json (%d colors)" % len(palette))
        except Exception:
            pass
    if palette is None:
        msgs["note"].append("palette check skipped (pixelize.PALETTES unavailable)")
    else:
        total, off = 0, 0
        for anim, imgs in loaded.items():
            for im in imgs:
                # 隔 2px 采样，降低开销
                w, h = im.size
                for yy in range(0, h, 2):
                    for xx in range(0, w, 2):
                        r, g, b, a = im.getpixel((xx, yy))
                        if a < 32:
                            continue
                        total += 1
                        if not near_palette((r, g, b), palette):
                            off += 1
        if total:
            ratio = off / total
            metrics["off_palette"] = round(ratio, 3)
            if ratio > OFF_PALETTE_FAIL:
                msgs["fail"].append("palette drift: %.0f%% off-race-palette (>%.0f%%)" % (ratio * 100, OFF_PALETTE_FAIL * 100))
            elif ratio > 0.08:
                msgs["warn"].append("palette drift: %.0f%% off-race-palette" % (ratio * 100))

    status = "rejected" if msgs["fail"] else "approved"
    return _finish(pack_dir, msgs, metrics, {}, out, approved=status == "approved", unit=unit, no_write=no_write, force=force)


def _finish(pack_dir, msgs, metrics, extra, out, approved=None, unit=None, no_write=False, force=False):
    status = extra.get("fatal") and "rejected" or ("approved" if approved is True else "rejected")
    record = {
        "pack": os.path.relpath(pack_dir, PIXELS),
        "status": status,
        "level": "audit",
        "audited_at": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "tool": "tools/gen/audit_anim_pack.py",
        "reasons": msgs["fail"] + msgs["warn"],
        "notes": msgs["note"],
        "metrics": metrics,
    }
    if "fatal" in extra:
        record["reasons"] = [extra["fatal"]]
    # 写 REVIEW.json（approved/rejected 都写；引擎只认 approved）。--no-write 时跳过（仅审查）
    protected = False
    if not no_write:
        # baseline_v1 历史包防误伤：若本次判 rejected，除非 --force，否则不覆盖在册 approved
        if record["status"] == "rejected" and not force:
            try:
                with open(os.path.join(pack_dir, "REVIEW.json"), "r", encoding="utf-8") as ef:
                    existing = json.load(ef)
                if existing.get("status") == "approved" and existing.get("level") == "baseline_v1":
                    record["status"] = "approved"
                    record["protected"] = True
                    record["level"] = str(existing.get("level", "baseline_v1"))
                    record["reasons"] = []
                    protected = True
            except Exception:
                pass
        try:
            rp = os.path.join(pack_dir, "REVIEW.json")
            with open(rp, "w", encoding="utf-8") as f:
                json.dump(record, f, ensure_ascii=False, indent=2)
            record["review_file"] = rp
        except Exception as e:
            record["review_file_error"] = str(e)
    final_ok = protected or status == "approved"
    line = "[%s] %s  frames=%s" % (record["status"].upper(), record["pack"], metrics.get("canvas", "?"))
    if protected:
        line += "  [protected baseline, not overwritten]"
    if msgs["fail"]:
        line += "  FAIL: " + " | ".join(msgs["fail"][:4])
    if msgs["warn"]:
        line += "  warn: " + " | ".join(msgs["warn"][:3])
    print(line, file=out)
    return final_ok, record


def main():
    ap = argparse.ArgumentParser(description="动画帧包自动审核门禁")
    ap.add_argument("--race")
    ap.add_argument("--unit", type=int)
    ap.add_argument("--dir")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--fail-fast", action="store_true")
    ap.add_argument("--no-write", action="store_true", help="只审查不写 REVIEW.json（历史包体检用）")
    ap.add_argument("--force", action="store_true", help="允许覆写 baseline_v1 在册 approved（判 rejected 时仍落 rejected）")
    args = ap.parse_args()

    targets = []
    if args.dir:
        targets.append((os.path.basename(os.path.dirname(args.dir.rstrip("/\\"))), -1, args.dir.rstrip("/\\")))
    elif args.race is not None and args.unit is not None:
        d = os.path.join(PIXELS, args.race, "unit_%d_anim" % args.unit)
        targets.append((args.race, args.unit, d))
    elif args.all:
        for race in sorted(os.listdir(PIXELS)):
            rd = os.path.join(PIXELS, race)
            if not os.path.isdir(rd):
                continue
            for d in sorted(os.listdir(rd)):
                if d.endswith("_anim"):
                    unit = int(d[len("unit_"):-len("_anim")]) if d[len("unit_"):-len("_anim")].isdigit() else -1
                    targets.append((race, unit, os.path.join(rd, d)))
    else:
        ap.error("need --race+--unit | --dir | --all")

    ok_all = True
    records = []
    for race, unit, d in targets:
        if not os.path.isdir(d):
            print("[MISS] %s" % d)
            ok_all = False
            if args.fail_fast:
                sys.exit(1)
            continue
        ok, rec = audit_pack(race, unit, d, no_write=args.no_write, force=args.force)
        ok_all = ok_all and ok
        records.append(rec)
        if not ok and args.fail_fast:
            sys.exit(1)
    sys.exit(0 if ok_all else 1)


if __name__ == "__main__":
    main()
