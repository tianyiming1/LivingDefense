# AUDIT — process / pipeline (2026-09-03 continuous)

**Verdict: FAIL — root cause of frost/jade/magma orange-block flood**

## Finding
Active gen (Comfy batch) used:

```
--ref assets/pixels/_studio/dragon/templates/longren_ref_1024.png
```

That file is a **6KB orange/purple block silhouette**, not the style lock.

Style lock requires:

```
assets/pixels/_studio/dragon/picks/pick_004_flame_drake_raw.png
```

## Consequence
img2img from the block template **cannot** produce pick_004 crystalline longren. Output collapses to the same orange block family across frost / jade / magma. Frost cool%=0 on all 001–010 is expected under this ref.

## Process violations
1. Wrong img2img anchor (template sil vs STYLE_GATE pick_004)
2. Species folders filled without SPECIES.md color gate (frost still warm)
3. Skills not evidenced: `create-game-assets`, `asset-architecture`, STYLE_GATE read before gen
4. Parallel species dump of identical fail family treated as progress

## Required fix before any further archive
1. Stop using `templates/longren_ref_1024.png` as style/img2img anchor
2. Restore `--ref` to `picks/pick_004_flame_drake_raw.png` (or approved pick only)
3. Quarantine frost 001–010 / jade 001–005 / magma 001+ from this batch
4. Do not promote any of this wave

## Magma 001
Same block family → **FAIL** style (even if warm color vaguely magma-adjacent). Not ship.
