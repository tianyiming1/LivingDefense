#!/usr/bin/env python3
"""
《活体防线》平衡离线推演 — 对应 docs/BALANCE_CALCULATION_MODEL_v1.md
用法: python tools/balance_calc.py [--t-kill 3.5] [--plan]
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from math import floor

# --- config.gd 镜像（改 config 后同步此处）---
START_MONEY = 300
START_LIVES = 20
WAVE_CLEAR_BASE = 40
WAVE_CLEAR_PER = 6

ENEMIES = [
    {"id": 0, "name": "Grunt", "hp": 55.0, "speed": 75.0, "reward": 8, "attack": 14.0, "interval": 0.9},
    {"id": 1, "name": "Runner", "hp": 30.0, "speed": 150.0, "reward": 12, "attack": 6.0, "interval": 0.6},
    {"id": 2, "name": "Tank", "hp": 230.0, "speed": 42.0, "reward": 25, "attack": 38.0, "interval": 0.8},
]

HUMAN_UNITS = [
    {"id": 0, "name": "Infantry", "gold": 60, "food": 8, "dmg": 14.0, "rate": 1.0, "hp": 200.0},
    {"id": 1, "name": "Musketeer", "gold": 100, "food": 12, "dmg": 17.0, "rate": 1.1, "hp": 150.0},
    {"id": 2, "name": "Mortar", "gold": 150, "food": 18, "dmg": 13.0, "rate": 0.9, "hp": 170.0},
    {"id": 3, "name": "Arbalest", "gold": 110, "food": 10, "dmg": 22.0, "rate": 1.0, "hp": 140.0},
    {"id": 4, "name": "Cleric", "gold": 90, "food": 10, "dmg": 0.0, "rate": 0.0, "hp": 160.0},
]

# CO-011 草案
START_FOOD = 24
FARM_FOOD_PER_WAVE = 6
START_FARMERS = 2
CORPSE_FOOD = {0: 3, 1: 2, 2: 8}

# S1Autoplay PLAN（buy:unit_id 简化为 unit id 列表）
S1_PLAN_GOLD = {
    1: [(0, 60), (1, 100), (0, 60)],
    2: [(0, 60)],
    3: [(1, 100), (0, 60)],
    4: [(1, 100)],
    5: [(1, 100)],
    6: [(1, 100)],  # + evolve 50 on a2, omitted in gold-only pass
    7: [(0, 60)],
    8: [(0, 60), (1, 100)],
    9: [],  # evolve d2 50
    10: [(1, 100)],
    11: [(4, 90)],
    12: [(1, 100)],
}
S1_PLAN_FOOD = {
    1: [(0, 8), (1, 12), (0, 8)],
    2: [(0, 8)],
    3: [(1, 12), (0, 8)],
    4: [(1, 12)],
    5: [(1, 12)],
    6: [(1, 12)],
    7: [(0, 8)],
    8: [(0, 8), (1, 12)],
    9: [],
    10: [(1, 12)],
    11: [(4, 10)],
    12: [(1, 12)],
}
EVOLVE_GOLD = {6: 50, 7: 50, 9: 50}  # approximate PLAN evolutions


def enemy_hp(eid: int, wave: int) -> float:
    base = ENEMIES[eid]["hp"]
    return base * (1.0 + (wave - 1) * 0.16)


def wave_composition(wave: int) -> list[int]:
    out: list[int] = []
    tanks = int(floor((wave - 1) / 4.0))
    runners = int(max(0.0, (wave - 2) * 1.5))
    grunts = 3 + wave
    out.extend([2] * tanks)
    out.extend([0] * grunts)
    out.extend([1] * runners)
    return out


def spawn_interval(wave: int) -> float:
    return max(0.45, 0.9 - wave * 0.04)


def unit_dps(uid: int) -> float:
    u = HUMAN_UNITS[uid]
    return u["dmg"] * u["rate"]


PATH_LENGTH_PX = 2100.0  # Config.PATH_POINTS 折线近似长度
AVG_ENEMY_SPEED = 75.0


def estimate_wave_duration(wave: int) -> float:
    comp = wave_composition(wave)
    n = len(comp)
    travel = PATH_LENGTH_PX / AVG_ENEMY_SPEED
    spawn = n * spawn_interval(wave)
    return travel + spawn


def wave_dps_req(wave: int, t_kill: float) -> float:
    """整波 DPS 需求 = 总HP / 波次战斗时长（非单怪 T_kill）。"""
    duration = estimate_wave_duration(wave)
    return wave_total_hp(wave) / max(duration, 1.0)


def per_enemy_dps_req(wave: int, t_kill: float) -> float:
    """单怪暴露段 DPS 需求（骨架 T_kill 约束，用于校核单体）。"""
    comp = wave_composition(wave)
    if not comp:
        return 0.0
    avg_hp = wave_total_hp(wave) / len(comp)
    return avg_hp / t_kill


def wave_total_hp(wave: int) -> float:
    return sum(enemy_hp(eid, wave) for eid in wave_composition(wave))


def wave_kill_gold_if_clear(wave: int) -> int:
    comp = wave_composition(wave)
    return sum(ENEMIES[eid]["reward"] for eid in comp)


def wave_clear_bonus(wave: int) -> int:
    return WAVE_CLEAR_BASE + wave * WAVE_CLEAR_PER


@dataclass
class WaveReport:
    wave: int
    n_enemies: int
    total_hp: float
    dps_req: float
    dps_req_per_enemy: float
    wave_duration: float
    gold_in_clear: int
    food_in: int
    gold_spend: int
    food_spend: int
    gold_bal: int
    food_bal: int
    dps_panel_on_field: float


def simulate_human_plan(t_kill: float = 3.5, farms: int = 2) -> list[WaveReport]:
    gold = START_MONEY
    food = START_FOOD
    field_units: list[int] = []
    reports: list[WaveReport] = []

    for w in range(1, 13):
        # planning spend
        g_sp = sum(c for _, c in S1_PLAN_GOLD.get(w, []))
        g_sp += EVOLVE_GOLD.get(w, 0)
        f_sp = sum(c for _, c in S1_PLAN_FOOD.get(w, []))
        for uid, _ in S1_PLAN_GOLD.get(w, []):
            field_units.append(uid)

        gold -= g_sp
        food -= f_sp

        # wave income (assume full clear)
        g_in = wave_kill_gold_if_clear(w) + wave_clear_bonus(w)
        f_in = farms * FARM_FOOD_PER_WAVE
        gold += g_in
        food += f_in

        total_hp = wave_total_hp(w)
        duration = estimate_wave_duration(w)
        dps_req = wave_dps_req(w, t_kill)
        dps_pe = per_enemy_dps_req(w, t_kill)
        dps_field = sum(unit_dps(u) for u in field_units)

        reports.append(
            WaveReport(
                wave=w,
                n_enemies=len(wave_composition(w)),
                total_hp=total_hp,
                dps_req=dps_req,
                dps_req_per_enemy=dps_pe,
                wave_duration=duration,
                gold_in_clear=g_in,
                food_in=f_in,
                gold_spend=g_sp,
                food_spend=f_sp,
                gold_bal=gold,
                food_bal=food,
                dps_panel_on_field=dps_field,
            )
        )

    return reports


def print_report(reports: list[WaveReport], t_kill: float) -> None:
    print(f"=== 平衡推演 (单怪T_kill={t_kill}s, 人族 PLAN, 假设全清) ===")
    print(f"{'波':>3} {'怪':>3} {'时长s':>6} {'总HP':>7} {'波DPS需':>7} {'场上DPS':>7} {'缺口%':>6} "
          f"{'金余':>6} {'粮余':>5} {'单怪DPS需':>8}")
    print("-" * 78)
    fails = []
    for r in reports:
        gap = 0.0 if r.dps_req <= 0 else (1 - r.dps_panel_on_field / r.dps_req) * 100
        ok_dps = r.dps_panel_on_field >= r.dps_req * 0.85
        ok_g = r.gold_bal >= 0
        ok_f = r.food_bal >= 0
        flag = ""
        if not ok_dps:
            flag += " DPS"
        if not ok_g:
            flag += " GOLD"
        if not ok_f:
            flag += " FOOD"
        if flag:
            fails.append((r.wave, flag.strip()))
        print(
            f"{r.wave:3d} {r.n_enemies:3d} {r.wave_duration:6.1f} {r.total_hp:7.0f} {r.dps_req:7.1f} "
            f"{r.dps_panel_on_field:7.1f} {gap:5.1f}% {r.gold_bal:6d} {r.food_bal:5d} "
            f"{r.dps_req_per_enemy:8.1f}{' !'+flag if flag else ''}"
        )
    print("-" * 95)
    if fails:
        print(f"闭合失败波次: {fails}")
    else:
        print("纸上闭合: 金币/食物/DPS(85%) 全部通过")


def print_unit_table() -> None:
    print("\n=== 单位 DPS/100g ===")
    for u in HUMAN_UNITS:
        dps = u["dmg"] * u["rate"]
        per100 = dps / u["gold"] * 100 if u["gold"] else 0
        print(f"  {u['name']:12s}  DPS={dps:5.1f}  gold={u['gold']:3d}  food={u['food']:2d}  DPS/100g={per100:5.1f}")


def print_wave_matrix() -> None:
    print("\n=== 波次矩阵 + 总HP ===")
    for w in range(1, 13):
        comp = wave_composition(w)
        g = comp.count(0)
        r = comp.count(1)
        t = comp.count(2)
        thp = wave_total_hp(w)
        print(f"  w{w:2d}: G={g:2d} R={r:2d} T={t}  n={len(comp):2d}  TotalHP={thp:7.0f}  interval={spawn_interval(w):.2f}s")


def corpse_food_if_all_on_carpet(wave: int, carpet_prob: float = 0.6) -> float:
  comp = wave_composition(wave)
  total = sum(CORPSE_FOOD[eid] for eid in comp)
  return total * carpet_prob


def main() -> None:
    p = argparse.ArgumentParser(description="Living Rampart balance calculator")
    p.add_argument("--t-kill", type=float, default=3.5, help="目标击杀时间(秒)")
    p.add_argument("--farms", type=int, default=2, help="农田数(人族)")
    p.add_argument("--matrix", action="store_true", help="只打印波次矩阵")
    p.add_argument("--units", action="store_true", help="只打印单位表")
    args = p.parse_args()

    if args.matrix:
        print_wave_matrix()
        return
    if args.units:
        print_unit_table()
        return

    print_unit_table()
    print_wave_matrix()
    reports = simulate_human_plan(t_kill=args.t_kill, farms=args.farms)
    print_report(reports, args.t_kill)

    print("\n=== 菌族尸体食物期望 (毯上概率 60%) ===")
    for w in range(1, 13):
        ef = corpse_food_if_all_on_carpet(w, 0.6)
        print(f"  w{w:2d}: 全尸在毯 ≈ {ef:.1f} 食物")


if __name__ == "__main__":
    main()
