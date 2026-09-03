
# 技能系统设计文档 (SKILL SYSTEM v1.0)

> 状态：基于 S1-S3 四族实施；CD 表来源 RACES.md + BALANCE_MODEL §4
> 主动技能仅在 SKILL_WAVES = [1, 3, 5, 7, 9, 11] 可释放
> 被动属性（飞行/燃烧/护盾/爆炸/中毒等）全局常驱，不计入技能 CD

## 1. 主动技能 CD 表

| 技能名称 | 种族 | CD 波次 | 持续时间 | 效果 | 备注 |
|------|------|------|------|------|------|
| Rally Fire | 人族 | 2 波 | 8s | 全军攻速 +50% | 关键波释放：高密度/BOSS 波 |
| carpet_fever | 菌族 | 3 波 | 3s | 菌毯伤害 ×3 | 与菌毯蔓延叠加 |
| spore_burst | 菌族 | 2 波 | 即时 | 爆 2 孢子（传染链发起） | 每次击杀额外爆 2 孢子 |
| dragon_fire | 龙族 | 自带/被动 | 持续 3s | 直线穿透燃烧 | 非 CD 主动技能，计入龙息线形射击 |
| dragon_wyre | 龙族 | 3 波 | 10s | 全场敌人攻速 -20% | 光环型大招 |
| resonance_pulse | 硅基 | 2 波 | 6s | 消耗 3 晶能：整条晶脉波及范围持续伤害 | 晶脉链激活 |
| crystal_immobilize | 硅基 | 2 波 | 3s | 消耗 2 晶能：1 敌人冰冻 3s | 单体控制 |

## 2. CD 机制设计理念

- **CD ≥ 2 波**：主动技能是"策略点"不是"无敌按钮"；确保技能窗口波与非窗口波的手感差异可感知
- **大招 CD = 3 波**：龙威 / 菌毯沸腾 / 共振脉冲，周期更长，策略规划更深远
- **SKILL_WAVES = [1, 3, 5, 7, 9, 11]**：每隔 2 波一次，确保技能释放分布均匀，不与经济高峰重叠过多

## 3. 技能释放判定逻辑（伪代码）

`gdscript
func _unhandled_input(event) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_1:
            _on_skill()
            return

func _on_skill() -> void:
    var current_wave = main.wave_index + 1  # 1-based
    if current_wave in SKILL_WAVES:
        if player.cooldown <= 0:
            _activate_skill()
            player.cooldown = skill_cd_waves[current_wave] * Config.TIME_SCALE
    else:
        print("[INFO] 当前波次 " + str(current_wave) + " 技能不可释放，CD 还在")

func _skill_cooldown_process(_delta: float) -> void:
    if player.cooldown > 0:
        player.cooldown -= _delta
        hud.set_skill_ready(player.cooldown <= 0)
