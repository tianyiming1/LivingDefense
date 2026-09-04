import json
from pathlib import Path
batches = {"frost": ["039", "040", "041", "042"], "jade": ["040", "041", "042", "043"]}
for sp, tags in batches.items():
    p = Path(f"assets/pixels/_studio/dragon/longren/{sp}/candidates/catalog.json")
    d = json.loads(p.read_text(encoding="utf-8"))
    d.setdefault("audit", {})
    d["audit"]["wave_F_drake_leak"] = {
        "verdict": "FAIL",
        "tags": tags,
        "reason": "wyvern/spirit/beast — not female longren light-armor",
        "doc": "assets/pixels/_studio/dragon/longren/_audit/AUDIT_2026-09-03_waveF_drake_leak.md",
        "promote": "blocked",
    }
    for it in d.get("items", []):
        tag = str(it.get("tag") or f"{int(it.get('index', 0)):03d}")
        if tag in tags:
            it["audit_note"] = "FAIL waveF not_female_longren — block promote"
            if it.get("source") == "comfy_img2img_pick004" and "t2i" in str(it.get("note", "")):
                it["source"] = "comfy_txt2img"
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(sp, "stamped", tags)
