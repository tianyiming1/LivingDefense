# 变更单 CO-044：龙族隐藏种族 + 彩蛋单位

- **状态**：**搁置**（等剧情系统接入后再定解锁通道）
- **日期**：2026-09-03
- **用户裁定**：隐藏解锁「后面再说，等接入剧情再说」——禁止再以菜单连点/临时随机事件冒充终局方案

## 已保留（供剧情接线）

- `scripts/player_secrets.gd`：`unlock_dragon` / `unlock_easter_units` 持久化 API
- `Config.RACES.dragon.hidden` 字段（当前 **false**，菜单四族公开）
- 单位 `easter_egg` 标记（id 12/13/14）；商店闸门**暂关**
- `event_bus` 内 `_accept_dragon_shadow_omen` / `_accept_scale_vault` 处理函数保留，**POOL 未挂行**

## 当前运行态（搁置期）

| 项 | 行为 |
| --- | --- |
| 菜单 | 人 / 菌 / **龙** / 硅 均可选 |
| 解锁事件 | 不进池，不触发 |
| 彩蛋单位 | 龙族商店可见可买（仍标 `easter_egg`） |

## 剧情接入时待办

1. 将 `hidden` 改回 `true`  
2. 剧情节点或正式事件调用 `PlayerSecrets.unlock_*`  
3. 恢复 `shop_units` 对 `easter_egg` 的闸门  
4. 禁用一切菜单连点类解锁（纪律：世界内发现）

## 逻辑备注

「隐藏种族」定义 = 世界/剧情内发现；菜单连点 = 偷换论题（已废止，不再复活）。
