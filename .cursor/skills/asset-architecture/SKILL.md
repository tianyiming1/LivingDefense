---
name: asset-architecture
description: >
  Architects and enforces the TowerDefenseProto pixel asset layout: ship vs _studio,
  numbered candidate archives, dedupe, promote-to-ship, and provenance. Use when
  reorganizing assets/pixels, cleaning duplicate images, designing folder taxonomy,
  moving AI generations, promoting candidates, or the user mentions 架构/整理资源/
  去重/目录混乱/studio/candidates/incoming.
---

# Asset Architecture — 《活体防线》像素资源架构

Enforce a **two-lane** layout: engine **ship** paths stay stable; all WIP lives under
`_studio/`. Never dump raws, previews, or duplicates into ship folders.

## When to use

- Reorganize / clean `assets/pixels/`
- AI gen → archive → filter → promote
- Duplicate images / mixed `_candidates` / `_incoming` leftovers
- New race/category taxonomy (e.g. 龙人/幼龙/亚龙/成龙)

**When not:** pure prompt/style art direction → `directing-game-visuals`; single sprite
import without layout change → `tools/gen/import_ai_sprite.py` only.

## Canonical layout

```
assets/pixels/
  README.md
  PROVENANCE.json                 # ship only
  {human|fungus|dragon|silicon}/unit_N.png
  dragon/unit_N_anim/{idle|walk|attack}_K.png
  enemies/enemy_N.png
  map/*.png
  _studio/                        # NEVER referenced by Godot load paths
    incoming/                     # drop zone; clear after import
    dragon/
      longren/                    # 龙人族 — 见 longren/INDEX.md
        magma/ frost/ storm/ stone/ jade/
          candidates/ picks/ pose/
          anim/{idle|walk|attack}/ ui/
        （根 NNN_* = legacy 未分类池，只读）
      whelp/ drake/ adult/
      picks/                      # 全族共享锚点（e.g. pick_004_*）
      refs/                       # sheets / moodboards
      anim_wip/                   # 跨种实验帧（优先改用亚种 anim/）
      ANATOMY.md
    enemies/ref/
```

| Lane | Path rule | Godot |
|------|-----------|-------|
| **Ship** | Final game sizes only; no `*_raw`, no `*_cand`, no duplicates | Loaded |
| **Studio** | Numbered `NNN_raw.png` / `NNN_game.png` + `catalog.json` | Ignored |

Legacy names `_candidates` and `_incoming` are **retired**. Scripts use `_studio` and
`_studio/incoming`.

## Hard rules

1. **Ship paths are contracts.** Do not rename `assets/pixels/dragon/unit_1.png` or
   `unit_1_anim/` without updating `scripts/unit_sprites.gd` and callers.
2. **Generate into studio, never overwrite.** Use `archive_candidates.archive_pair` so
   indices only increase.
3. **One content hash → one file.** Before keeping a copy, MD5-dedupe against the
   target folder (see `tools/gen/reorganize_pixels.py`).
4. **Promote is explicit.** User picks an index →
   `python tools/gen/archive_candidates.py --promote dragon/longren 4` (or copy pick
   into ship + `record_provenance.py`). Do not silently overwrite ship.
5. **Provenance on every ship write.** `commercial_ok: false` must not ship.
6. **Anatomy gates before promote.** Read `_studio/dragon/ANATOMY.md` for 龙族:
   longren = 2 hands + 2 feet; discard limb errors.
7. **No second tree.** Do not recreate `_candidates`, parallel `batch/`, `classified/`,
   or mirror ship anim into studio as loose copies of the same ship frames.

## Pipeline (tools)

| Step | Command / module |
|------|------------------|
| **ComfyUI SDXL（推荐）** | `python tools/gen/comfy_pixel_gen.py --preset flame_drake --archive dragon/longren/magma` |
| Drop raw | `_studio/incoming/dragon/longren/{id}/…` |
| Local gen (pixel_sprite) | `python tools/gen/gen_unit_local.py --id …` → archives under `_studio/` |
| Import | `python tools/gen/import_ai_sprite.py --id …` |
| List | `python tools/gen/archive_candidates.py --list` |
| Promote | `python tools/gen/archive_candidates.py --promote dragon/longren/magma N`（再拷 ship `dragon/unit_1`） |
| Provenance | `python tools/gen/record_provenance.py --id … --source local_sd --commercial-ok` |
| Full rebuild (rare) | `python tools/gen/reorganize_pixels.py` — **destructive** to old trees |

ComfyUI 安装与权重在仓库外：`D:\softwares\ComfyUI`（Juggernaut-XL + pixel-art-lora-sdxl）。Diffusers 权重仍在 `D:\AI_models\`。

Dragon classification IDs for archive folders:

- `dragon/longren/{magma|frost|storm|stone|jade}` — 龙人五亚种（焰鳞/霜棱/雷冠/岩夯/碧枝）
- Legacy flat `dragon/longren` — 未分类历史池，**勿再写入**
- `dragon/whelp` · `dragon/drake` · `dragon/adult`
- Approved look: `_studio/dragon/picks/pick_004_flame_drake_*` → 焰鳞 `longren/magma/picks/` → ship `dragon/unit_1.png`

Models live under `D:\AI_models\` (not inside the repo).

## Agent checklist when “整理资源”

1. Map current tree vs canonical layout above.
2. Keep ship untouched unless promoting.
3. Move WIP → `_studio/...` with taxonomy; MD5-dedupe.
4. Rebuild `catalog.json` per folder.
5. Delete empty/legacy dirs; remove orphan `.import` only when the PNG is gone.
6. Point scripts/docs at `_studio`; update this skill if taxonomy changes.
7. Summarize for user: what stayed in ship, what was deduped, where to filter next.

## Anti-patterns

- Putting `001_raw.png` next to `unit_1.png` in ship
- Copying the same gen into `batch/` + `classified/` + `longren/`
- Leaving `_incoming` temps after import
- Promoting limb-broken sprites “先用着”
- Storing models under `project/models/`
