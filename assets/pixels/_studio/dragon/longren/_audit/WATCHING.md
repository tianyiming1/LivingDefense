# continuous audit — ARMED（Wave K）

## Steady
- frost/jade candidates：**空**
- magma approved：011,022,**023**（禁 picks）
- storm/stone approved：002 各一（CONDITIONAL）
- male candidates 留 CONDITIONAL；FAIL 已清
- dream whelp/drake 001–004：CONDITIONAL（禁自动升）
- ship unit_14–17_anim：占位 CONDITIONAL（CO-046）
- Loop：every **120s** `AGENT_LOOP_TICK_dragon_audit`

## On each tick
Scan frost/jade/magma/storm/stone candidates + dream/**/candidates；FAIL 删；PASS 只记不自动 approved/picks。

## Latest
- Wave K：男 FAIL 清库；magma 023 → approved；梦龙幼亚 CONDITIONAL；033 驳回升档（偏瘦）
- Stop: user says stop

Doc: `AUDIT_2026-09-03_waveK_male_dream.md`
