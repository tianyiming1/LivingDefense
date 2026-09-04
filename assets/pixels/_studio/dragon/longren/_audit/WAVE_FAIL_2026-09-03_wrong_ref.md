# AUDIT WAVE COMPLETE — wrong-ref batch 2026-09-03

**Batch:** Comfy i2i × frost/jade/magma (5+5+5 then filled to 010)  
**Ref used:** `templates/longren_ref_1024.png` (block sil) — **NOT** pick_004  
**Terminal:** ALL_DONE 2026-09-03 ~17:00  
**Preview4x:** generated — does not change verdict

## Hard verdict (all species)

| Species | IDs | Color gate | Style vs pick_004 | Promote |
|---------|-----|------------|-------------------|---------|
| frost | 001–010 | FAIL cool=0% | FAIL flat block | **禁止** |
| jade | 001–010 | FAIL green=0% | FAIL flat block | **禁止** |
| magma | 001–010 | warm OK-ish | FAIL flat block (same family) | **禁止** |

Magma warm% alone is **not** enough. Visual read = same orange/purple geometric placeholder as frost/jade. STYLE_GATE fail.

## Catalog honesty FAIL
`frost/candidates/catalog.json`:
- `"status": "all_fail_deleted"` while `001_raw/game.png` … `010_*` **still on disk**
- `"source": "comfy_img2img_pick004"` while gen log used `longren_ref_1024.png`

→ Evidence gate FAIL; catalogs must be corrected or quarantined with this audit note.

## approved / picks
Empty — correct. Do not promote this wave.

## Required before next gen
1. `--ref` = `picks/pick_004_flame_drake_raw.png` only
2. Quarantine or delete this wave (or move to `_fail/wrong_ref_2026-09-03/`)
3. Fix catalog status to match disk
4. Read SPECIES.md + STYLE_GATE + ANATOMY before archive

## Skills compliance
Missing evidence of router → create-game-assets / asset-architecture / directing-game-visuals before dump.
