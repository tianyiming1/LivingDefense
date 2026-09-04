# Sound Design: The Living Rampart（活体防线）

> 派生自 `VISUAL_DESIGN.md`（几何剪影 + 高对比色板）  
> 实现：`audio_controller.gd`（程序合成，零外部音频文件）  
> 总线：`Master ← Music / SFX / UI`

## 1. 声音概念

**清脆几何打击** — 方波/三角波短促音 + 轻微音高随机，匹配像素剪影风格；不用写实金属采样。

**BGM（CO-ART-PROD-001 W1）** — 同族程序合成琶音循环（菜单 / 规划 / 战斗三态）；零外部音频文件，许可=自有代码输出。日后若引入 CC0 采样须走 `docs/ASSET_POLICY.md`。

视觉标签映射：`geometry-primitive-modularity` → 方块感打击；`render-glow-outline` → 蓄能/技能用正弦上扬。

## 2. 事件族（全局固定语义）

| 事件族 | 音色身份 | 波形 | 时长 | 用途 |
|:---|:---|:---|:---|:---|
| `impact_light` | 轻击 | 方波 + 快衰减 | 40–80ms | 跑者咬、毒伤 tick |
| `impact_med` | 中击 | 方波 + 三角谐波 | 60–120ms | 步兵挥砍、Grunt 拳 |
| `impact_heavy` | 重击 | 低方波 + 噪声尾 | 100–180ms | Tank 砸、晶壁挡 |
| `ranged_shot` | 射击 | 三角下滑 | 50–100ms | 火枪、弩、晶刺 |
| `ranged_boom` | 爆炸 | 噪声 burst + 正弦尾 | 120–200ms | 迫击炮、爆孢、熔岩 |
| `charge_up` | 蓄能 | 正弦上扬 | 连续 | 硅基蓄能、龙息前摇 |
| `charge_release` | 释放 | 方波 + 泛音 | 80–150ms | 蓄能完毕、共振脉冲 |
| `fly_whoosh` | 掠空 | 滤波噪声 | 60ms | 龙族飞行、跑者冲刺 |
| `aura_tick` | 光环 | 柔正弦 | 30ms | 牧师、菌毯 debuff |
| `spawn` | 部署 | 上行两音 | 100ms | 单位放下 |
| `death` | 死亡 | 下滑方波 | 150ms | 单位/敌人死亡 |
| `ui` | 界面 | 短方波 | 30ms | 按钮、开波 |

## 3. 单位 × 音效矩阵

### 人族（Human）

| 单位 | kind | 移动 | 攻击 | 受击 | 死亡 | 特殊 |
|:---|:---|:---|:---|:---|:---|:---|
| 步兵 Infantry | melee | `foot_armor` ×4 变体 | `impact_med` + `sword_swish` | `impact_light` | `death` | 进化：`ui` 上行 |
| 火枪手 Musketeer | single | `foot_light` | `ranged_shot`（火枪） | `impact_light` | `death` | — |
| 迫击炮 Mortar | splash | `foot_heavy` | `ranged_boom`（低） | `impact_med` | `death` | 装填：200ms 静音间隔 |
| 弩塔 Arbalest | aa | `foot_light` | `ranged_shot`（高音） | `impact_light` | `death` | 对空：+15% pitch |
| 牧师 Cleric | aura | `foot_light` | `aura_tick`（每 0.5s） | `impact_light` | `death` | 光环 LOOP 极轻 |

### 菌族（Fungus）— 固定不动，无走路

| 单位 | kind | idle | 攻击 | 受击 | 死亡 | 特殊 |
|:---|:---|:---|:---|:---|:---|:---|
| 毒蘑菇 | melee | `spore_idle` 呼吸 | `impact_light` + `poison_squish` | `impact_light` | `spore_pop` | 毒：低频 tick |
| 爆孢蘑菇 | splash | `spore_idle` | `ranged_boom`（孢） | `impact_light` | `spore_pop` | 传染：额外 `spore_burst` |
| 菌毯蘑菇 | aura | `mycelium_hum` LOOP | — | `impact_light` | `spore_pop` | 铺毯：`mycelium_grow` |
| 麻痹蘑菇 | single | `spore_idle` | `ranged_shot`（电）+ `paralyze_zap` | `impact_light` | `spore_pop` | 麻痹 CD 长音 |

### 龙族（Dragon）

| 单位 | kind | 移动 | 攻击 | 受击 | 死亡 | 特殊 |
|:---|:---|:---|:---|:---|:---|:---|
| 幼龙 Whelp | fly | `fly_whoosh` | `charge_release`（龙息）+ `burn_sizzle` | `impact_light` | `death` + `wing_flap` | 点燃 tick |
| 焰龙 Drake | burst | `foot_heavy` | `impact_med` + `burn_sizzle` | `impact_med` | `death` | 护盾：`charge_up` 短 |
| 熔岩泰坦 | explode | `foot_heavy` 慢 | `ranged_boom`（重） | `impact_heavy` | `ranged_boom`（大） | 自爆 |

### 硅基（Silicon）

| 单位 | kind | 移动 | 攻击 | 受击 | 死亡 | 特殊 |
|:---|:---|:---|:---|:---|:---|:---|
| 晶核 Core | charge | `crystal_clink` 慢 | `charge_up` LOOP → `charge_release` | `impact_med` | `crystal_shatter` | 蓄能环对应音量 |
| 晶刺 Spike | spike | `crystal_clink` | `charge_up` → `ranged_shot`（晶） | `impact_med` | `crystal_shatter` | 对跑者 +pitch |
| 晶壁 Wall | wall | `crystal_clink` 极慢 | `impact_heavy`（挡） | `impact_heavy` | `crystal_shatter` | 碎裂再凝：`charge_up` |

### 敌人（Enemy）

| 单位 | 移动 | 攻击 | 受击 | 死亡 | 漏怪 |
|:---|:---|:---|:---|:---|:---|
| Grunt 锈红方 | `foot_creature` 中速 | `impact_med` | `impact_light` | `death` 低 | `leak_grunt` |
| Runner 冰蓝三角 | `fly_whoosh` 快 | `impact_light` 快 | `impact_light` | `death` 高 | `leak_runner` |
| Tank 暗紫六边 | `foot_creature` 慢 | `impact_heavy` | `impact_med` | `death` 极低 | `leak_tank` |

## 4. 动作 × 音效同步点（必须对齐）

| 动作 | 动画帧触发点 | 音效触发点 | 代码钩子 |
|:---|:---|:---|:---|
| 步兵走路 | 脚落地帧 1、3 | 同帧 `foot_armor` | `unit.gd` 位移 > 2px/s |
| 步兵挥砍 | 帧 2（剑最大弧） | 同帧 `sword_swish` + `impact_med` | `_perform_attack` melee |
| 火枪射击 | 帧 1 枪口闪 | 同帧 `ranged_shot` | `_fire` / `play_muzzle` |
| 敌人咬击 | 帧 2 前冲 | 同帧 `impact_*` | `enemy._attack_nearest` |
| 蓄能完成 | 光环满圈 | `charge_release` | `_charge >= need` |

**纪律**：伤害数字在动画/音效触发帧应用，不在按键帧（避免「空刀有声无伤」）。

## 5. 实现架构

```
main.gd
  └── audio_controller.gd   # play_event(id, pos, pitch_scale?)
  └── unit.gd               # anim_state → Sprite 或 程序 tween
  └── enemy.gd
  └── attack_vfx.gd         # 已有视觉，补 audio_controller 调用
```

- `config.gd` 每单位增加：`anim_profile`, `sfx_profile`（字符串 key，单一数据源）
- Headless 测试：`audio_controller` no-op 模式保留 API，测状态机切换

## 6. 验收清单（M2 音效门禁）

- [x] W1：主菜单 / 规划 / 战斗有循环 BGM；建造、击杀、漏怪、升级、胜、负、UI 有独立事件音（程序合成）
- [ ] 闭眼可区分：近战砍 / 远程射 / 爆炸 / 蓄能释放
- [ ] 每个 kind 至少 1 种专属动作可见（挥砍/射击/蓄能/光环脉冲）
- [ ] 移动单位有走路反馈（音或步尘，至少一项）
- [ ] 同屏 10 单位无爆音（SFX 总线限幅 + 同类 50ms 冷却）
- [ ] 步兵挥砍：动画帧 2 与 `sword_swish` 偏差 < 1 帧（33ms@30fps）

## 7. 分期

| 阶段 | 范围 |
|:---|:---|
| **M2-A** | `audio_controller.gd` + 步兵 walk/swing + 3 敌人 walk/bite |
| **M2-B** | 人族 5 单位 + 菌族 4 单位全矩阵 |
| **M2-C** | 龙族 + 硅基 + 技能/波次/UI 音 |
| **M3** | 像素精灵帧替换程序动画，**音效 key 不变** |
