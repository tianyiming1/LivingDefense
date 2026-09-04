#!/usr/bin/env python3
"""Continuous audit ticker for longren species folders.
Echoes AGENT_LOOP_TICK when new/changed PNGs appear under candidates/approved/picks.
"""
from __future__ import annotations

import hashlib
import json
import os
import time

# tools/gen/this.py -> repo root
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LONGREN = os.path.join(ROOT, "assets", "pixels", "_studio", "dragon", "longren")
STATE = os.path.join(LONGREN, "_audit", "watch_state.json")
SPECIES = ("magma", "frost", "storm", "stone", "jade")
INTERVAL = 45


def fingerprint() -> dict[str, str]:
    out: dict[str, str] = {}
    for sp in SPECIES:
        for sub in ("candidates", "approved", "picks"):
            d = os.path.join(LONGREN, sp, sub)
            if not os.path.isdir(d):
                continue
            for name in os.listdir(d):
                if not name.lower().endswith((".png", ".json")):
                    continue
                path = os.path.join(d, name)
                try:
                    st = os.stat(path)
                except OSError:
                    continue
                key = f"{sp}/{sub}/{name}"
                out[key] = f"{st.st_mtime_ns}:{st.st_size}"
    return out


def load_state() -> dict[str, str]:
    if not os.path.isfile(STATE):
        return {}
    try:
        with open(STATE, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def save_state(fp: dict[str, str]) -> None:
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w", encoding="utf-8") as f:
        json.dump(fp, f, indent=2, sort_keys=True)


def main() -> None:
    print("AUDIT_WATCHER_START interval=%ss root=%s" % (INTERVAL, LONGREN), flush=True)
    prev = load_state()
    if not prev:
        prev = fingerprint()
        save_state(prev)
        print("AUDIT_BASELINE keys=%d" % len(prev), flush=True)
    while True:
        time.sleep(INTERVAL)
        cur = fingerprint()
        added = sorted(set(cur) - set(prev))
        removed = sorted(set(prev) - set(cur))
        changed = sorted(k for k in set(cur) & set(prev) if cur[k] != prev[k])
        if added or removed or changed:
            payload = {
                "prompt": "continuous-audit: review new/changed longren artifacts; emit 审核裁定; FAIL block promote",
                "added": added[:40],
                "removed": removed[:40],
                "changed": changed[:40],
            }
            print("AGENT_LOOP_TICK_audit " + json.dumps(payload, ensure_ascii=False), flush=True)
            save_state(cur)
            prev = cur
        else:
            print("AUDIT_HEARTBEAT ok keys=%d" % len(cur), flush=True)


if __name__ == "__main__":
    main()
