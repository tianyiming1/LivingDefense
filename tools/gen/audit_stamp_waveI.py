import json
from pathlib import Path
batches = {"frost": ["043", "044"], "jade": ["044", "045"]}
for sp, tags in batches.items():
    p = Path(f"assets/pixels/_studio/dragon/longren/{sp}/candidates/catalog.json")
    if not p.exists():
        print(sp, "no catalog"); continue
    d = json.loads(p.read_text(encoding="utf-8"))
    d.setdefault("audit", {})
    d["audit"]["wave_I_beast_leak"] = {
        "verdict": "FAIL",
        "tags": tags,
        "doc": "assets/pixels/_studio/dragon/longren/_audit/AUDIT_2026-09-03_waveI_dream_and_043.md",
        "promote": "blocked",
    }
    for it in d.get("items", []):
        tag = str(it.get("tag") or f"{int(it.get('index', 0)):03d}")
        if tag in tags:
            it["audit_note"] = "FAIL waveI beast/spirit not female longren"
        if tag == "042" and sp == "frost":
            it["audit_note"] = "MIGRATED to dream/pick_dream_menglong — removed from frost candidates"
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(sp, "stamped", tags)
# dream audit note
dream_audit = Path("assets/pixels/_studio/dragon/dream/_AUDIT_CONTINUOUS.md")
dream_audit.write_text("""# Continuous auditor — dream pick

- Object: `picks/pick_dream_menglong_*` (= frost draft 042)
- Verdict: **CONDITIONAL PASS** as Dream Dragon (beast path per SPECIES.md)
- Not frost female longren
- frost/candidates/042 purged after migration
- Date: 2026-09-03
""", encoding="utf-8")
print("dream audit written; frost 042 present?", Path("assets/pixels/_studio/dragon/longren/frost/candidates/042_game.png").exists())
