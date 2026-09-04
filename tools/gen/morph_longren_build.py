"""【已停用分区缩放】旧版 clear+paste 翼/角/肩会导致龙人「割裂」。

请改用：
  python tools/gen/morph_longren_5pack.py --preview
（整身换色 + 统一缩放，不拆部件）

真要翼更大/女体/角更大：用 Comfy 整图出，或手工改，禁止再分区挖贴。
"""
from __future__ import annotations

import sys

if __name__ == "__main__":
    print(
        "FAIL: morph_longren_build 已停用（会割裂躯干）。\n"
        "改跑: python tools/gen/morph_longren_5pack.py --preview",
        file=sys.stderr,
    )
    raise SystemExit(2)
