# 变更单 CO-015：龙族身份可读抛光

- **状态**：已实施
- **日期**：2026-09-03
- **派工**：WP-D1

## 变更

1. **HUD**：顶栏 `龙巢 x/4`；有蛋时显示 `孵蛋：n（最短 t）`。
2. **场上**：`dragon_egg_markers` 画蛋位 + 倒计时秒数。
3. **龙焰**：全屏橙红闪 + `dragon_breath` 音效 + 状态句。
4. **修复**：补齐被调用但缺失的 `_refresh_dragon_identity()`（放置/孵化/回巢/战损/周期刷新）。

## 可验证

- 龙族开局即见巢位占用。
- 龙死后出现蛋标记与 HUD 孵蛋行。
- 波中按 1 有闪屏与灼烧状态。

## 影响文件

`main.gd`、`hud.gd`、`dragon_egg_markers.gd`、`translations/strings.csv`
