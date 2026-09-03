"""登记素材来源到 assets/pixels/PROVENANCE.json（合规台账）。"""
from __future__ import annotations

import argparse
import json
import os
from datetime import date

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROV = os.path.join(ROOT, "assets", "pixels", "PROVENANCE.json")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True, help="e.g. dragon/unit_0")
    ap.add_argument("--source", required=True, help="procedural|local_sd|leonardo_paid|commission|cc0|...")
    ap.add_argument("--tool", default="")
    ap.add_argument("--license", default="owned_by_project")
    ap.add_argument("--commercial-ok", action="store_true")
    ap.add_argument("--notes", default="")
    ap.add_argument("--path", default="", help="relative under assets/pixels/")
    args = ap.parse_args()

    data = {"policy": "docs/ASSET_POLICY.md", "updated": str(date.today()), "assets": []}
    if os.path.isfile(PROV):
        with open(PROV, encoding="utf-8") as f:
            data = json.load(f)

    entry = {
        "id": args.id,
        "paths": [args.path] if args.path else [args.id + ".png"],
        "source": args.source,
        "tool": args.tool,
        "license": args.license,
        "commercial_ok": bool(args.commercial_ok),
        "notes": args.notes,
    }
    assets = [a for a in data.get("assets", []) if a.get("id") != args.id]
    assets.append(entry)
    data["assets"] = assets
    data["updated"] = str(date.today())
    os.makedirs(os.path.dirname(PROV), exist_ok=True)
    with open(PROV, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("recorded:", args.id, "commercial_ok=", entry["commercial_ok"])


if __name__ == "__main__":
    main()
