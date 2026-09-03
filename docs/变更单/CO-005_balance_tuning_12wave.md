# CO-005 数值调整：12 波赛跑 FAIL 修复（A+B）

- 日期：2026-09-01
- 批准人：用户（制作人拍板，见评审文档 docs/wave12_balance_review.md）
- 生效版本：赛跑 config v7.1
- 为什么变：12 波自动赛跑 FAIL 于波 3（GAME OVER，lives 20→6→0）。根因链（数据评审证据）：初始 200→3 兵→波 1 漏怪→清波 bonus 永不发放→经济锁死→波 3 崩。数学闭合：波 2 末 money=6 = 20+击杀46-补兵60 ✓。
- 影响范围：config.gd 仅两处常量/公式；不改任何脚本逻辑。
  1. START_MONEY: 200 → 300（开局 5 兵，波 1 可全清）
  2. wave_composition grunts: 4+wave*2 → 3+wave（波 1 阵容 6→4 Grunt）
- 不改：敌人属性、单位属性、波次成长、奖励公式（后续按 C/D 微调时另开单）
- 验证方法：改后复跑 tools/wave12_test.gd（12 波赛跑）→ 预期 PASS（WIN，lives>0）
- 回滚：一行还原常量即可