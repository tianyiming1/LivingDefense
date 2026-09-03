# Visual Design: The Living Rampart（活体防线）

**Concept-Derived Visual Tags**: `#geometry-primitive-modularity`, `#render-glow-outline`, `#composition-centered-stage`

## 1. Visual Concept

**几何剪影军团** — 俯视战场上，种族靠「形状签名 + 固定色板」两秒内可读；细节服从玩法语义，不靠写实人体。

## 2. Color Palette

| Role | Color | Hex | Usage |
|:---|:---|:---|:---|
| 人族主体 | 蓝灰钢 | `#6B82B8` | 步兵/火枪身体主色 |
| 人族辅色 | 钢蓝深 | `#4D6AA8` | 描边、阴影、远程单位 |
| 段级标记 | 黄星 | `#FFDC50` | 进化段 1–3 颗星，肉眼可见 |
| 威胁（敌） | 锈红/冰蓝/暗紫灰 | `#BF4A2F` / `#3A8FC6` / `#6E5A73` | 与四族主色全部错开 |
| 战场底 | 暗绿草地 | `#386640` | 路径外可建造区 |

## 3. Object Rendering Specifications

### 人族步兵（Infantry）— 首枚像素资产

| 属性 | 规格 | 验收 |
|:---|:---|:---|
| 视角 | **俯视**（bird-eye），面朝 +X（右） | 同屏 5 单位可辨朝向 |
| 剪影 | **纵矩形**躯干 + 小方头，非人形写实 | 与 `art_samples_v1` 人族框一致 |
| 近战标记 | 右手 **剑**（十字护手 + 剑身朝 +X）+ 左手 **圆盾** | 无 HUD 可识别「剑盾步兵」 |
| 头部 | **钢盔**圆顶 + 面甲观察缝（朝面向） | 与无盔单位可区分 |
| 段标记 | 胸甲 **1 颗黄星**（segment=1） | 进化后星数增加 |
| 尺寸 | 64×64 画布，主体高约 32px | 与 `radius=11` 游戏缩放匹配 |
| 色板 | 仅人族 8 色量化 | 禁止渐变抗锯齿 |

**禁止**：正面立绘、水晶铠甲、场景背景入镜、与硅基/敌色混淆。

## 4. Background & Environment

- 路径区：土黄 `#C7B380`；可建造区：暗绿 `#386640`
- 单位站位居中可读；菌毯/粒子等噪声放 peripheral（`composition-centered-stage`）

## 5. Feedback Effects

| Event | Visual Response | Intensity |
|:---|:---|:---|
| 受击 | 轮廓闪白 0.15s | Med |
| 近战攻击 | 朝向目标亮线 + 枪口闪 | Med |
| 进化 | 黄星数量 +1 | Low |
| 死亡 | 即刻消失（S3 起粒子） | High |

## 6. AI-Generated Look Suppression Rules

### 6.1 Visual Hierarchy Rules

- Protagonist（己方单位）：几何剪影 + 种族色板
- Threat（敌人）：圆/方/三角敌色板，与四族零重叠
- Reward：击杀金币飘字（HUD）；无单位级奖励色
- 2-second recognition check：俯视矩形蓝兵 + 右向剑 = 人族步兵

### 6.2 Limits on Familiar Template Symbols

- Adopted familiar elements (max 2)：星标段级、剑方向表近战
- Replaced unique element：不用写实盔甲/人脸，用矩形+武器线

### 6.3 UI-Independent Feedback

| Event | Non-UI visual response | Intensity |
|:---|:---|:---|
| 受击 | 白闪轮廓 | Med |
| 近战 | 剑方向亮线 | Med |
| 减速 | 冰蓝底圈 13px | Low |

### 6.4 Composition and Gaze Guidance

- Initial focal point：路径走廊中央战斗区
- Visual flow：左出生 → 右终点；单位沿路径布防
- Anti-center-clutter：菌毯/特效降低中心区饱和度

## 7. Asset Handoff（像素管线）

| 元素 | M2 现状 | M3 目标 |
|:---|:---|:---|
| 单位身体 | `unit.gd` draw_* | `Sprite2D` 64×64，程序模板或 AI 后量化 |
| 段星/光环 | 代码叠加 | 仍代码叠加（不烘焙进贴图） |
| 地图 | `map.gd` 色块 | 平铺像素图块 |
| UI 图标 | 色块按钮 | 128×128 NEAREST 放大 idle 帧 |

**步兵生成策略（当前）**：程序模板按 §3 规格绘制 → 作为 AI 量化参考基准；AI 出图仅用于地图氛围，单位以几何模板为主。

---

## 8. 单位动作规格（ANIMATION_DESIGN）

> 配套音效见 `SOUND_DESIGN.md` §3–§4。动画与音效在同一帧触发。

### 8.1 动作状态机（所有可动单位）

```
idle → walk → attack → (hit) → death
         ↑       ↓
         └── cooldown ──┘
```

固定单位（菌族）：`idle ↔ attack`，无 walk。

### 8.2 按 kind 的标准动作

| kind | 走路 | 攻击动作 | 帧数 | 朝向 |
|:---|:---|:---|:---|:---|
| `melee` | 4 帧循环，脚交替 | **挥砍**：身体前倾 + 剑弧 90°→0° | walk 4 / atk 3 | 面朝目标 |
| `single` | 4 帧 | **射击**：停步 + 枪口闪 + 弹道 | walk 4 / atk 2 | 面朝目标 |
| `splash` | 4 帧 | **开火**：后坐力 squash + 炮弹 | walk 4 / atk 3 | 面朝目标 |
| `aa` | 4 帧 | 同 single，弹道更快 | walk 4 / atk 2 | 面朝目标 |
| `aura` | 2 帧呼吸 | **脉冲**：光环缩放 1.0→1.08→1.0 | idle 2 | 无朝向 |
| `fly` | 2 帧上下浮动 | **龙息**：头前伸 + 火线 | hover 2 / atk 3 | 面朝目标 |
| `charge` | 4 帧慢走 | **蓄能**：发光环充填 → 爆发 | walk 4 / charge LOOP / atk 2 | 面朝目标 |
| `spike` | 4 帧 | 同 charge，释放为晶刺弹 | 同上 | 面朝目标 |
| `wall` | 4 帧极慢 | **格挡**：盾前顶 + 震退 | walk 4 / block 2 | 面朝路径 |
| `burst` | 4 帧 | **撕咬**：前扑 | walk 4 / atk 3 | 面朝目标 |
| `explode` | 4 帧慢 | **重击** / 死亡爆炸 | walk 4 / atk 3 / death 4 | — |

### 8.3 人族步兵（Infantry）— 参考实现

| 动画 | 帧 | 像素变化 | 音效 |
|:---|:---|:---|:---|
| `idle` | 1 | 站立，剑收在身侧 | — |
| `walk_1` | 1 | 左脚前，身体 ±1px 上下 | `foot_armor` |
| `walk_2` | 1 | 右脚前 | `foot_armor` |
| `walk_3` | 1 | 左脚前（镜像 w1） | `foot_armor` |
| `walk_4` | 1 | 右脚前（镜像 w2） | `foot_armor` |
| `attack_1` | 1 | 举剑后摆 | — |
| `attack_2` | 1 | **剑水平挥出**（关键帧） | `sword_swish` + `impact_med` |
| `attack_3` | 1 | 收剑回位 | — |

M2 可用 **Tween 旋转剑弧 + 身体前倾** 代替完整精灵表；M3 换 `AnimatedSprite2D` 同名动画。

### 8.4 敌人动作

| 敌人 | 走路 | 攻击 | 特征 |
|:---|:---|:---|:---|
| Grunt 方 | 4 帧沉重 | 身体前撞 2 帧 | 锈红，步频中 |
| Runner 三角 | 4 帧快 | 快速啄击 1 帧 | 冰蓝，步频 ×1.8 |
| Tank 六边 | 2 帧极慢 | 重压下沉 + 震地 3 帧 | 暗紫，体型大 |

### 8.5 M2 实现路径（不写死资产）

1. `unit.gd` 增加 `anim_state` / `anim_frame` / `facing_angle`
2. 移动时：`anim_state=walk`，按 `speed` 切换帧率
3. `_perform_attack` 时：`anim_state=attack`，帧 2 触发伤害+音效
4. `enemy.gd` 同理；Runner 走路用快帧率
5. 菌族：`stationary` 跳过 walk，攻击用 cap 弹跳 tween

### 8.6 验收（动作门禁）

- [ ] 步兵：走路可见脚交替；挥砍可见剑弧；攻击帧与伤害同时
- [ ] 火枪：停步射击，非走路中开火
- [ ] 菌菇：不动但有 idle 呼吸；Runner 明显比 Tank 快
- [ ] 同屏 8 单位动作不同步（帧偏移 `instance_id % 4`）
