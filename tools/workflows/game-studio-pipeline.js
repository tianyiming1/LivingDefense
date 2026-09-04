// ============================================================
// game-studio-pipeline v2：完整工作室角色模型
// 对齐 game-studio 预设的 18 角色 × 5 条线 + 激活规则 + 门禁收口
//
// 设计要点：
//  - 角色注册表 = 预设的 18 角色（分 5 条线）
//  - 任务 → 激活相关角色（议题激活，不全员上）→ 按依赖 DAG 派 agent
//  - 契约不变：CO 变更单 = 唯一事实源；门禁不过不前进；blockers 交用户
//  - token 感知：默认"单议题激活"（几个角色）；fullStudio 模式才全线上
// ============================================================
const ROOT = args.root || 'D:\\GameWorkSpace\\TowerDefenseProto'
const FULL = args.fullStudio === true // 里程碑/大议题才 true

// ---------- 角色注册表（对齐 game-studio 预设 18 角色）----------
// 决策层: 制作人(排期/门禁/风险) · 创意总监(愿景)
// 设计线: 主设计师(机制) · 数值设计师 · 关卡设计师 · 叙事设计师
// 工程线: 技术总监(架构) · 玩法工程师 · 管线与工具工程师 · 技术美术
// 美术线: 美术总监(风格/验收) · 概念美术 · UI·UX 设计师 · 音频设计师
// 质量线: QA 主管(策略) · QA 测试员
// 数据线: 数据分析师(平衡/留存) · 发行线: 社区与商店经理(上架/本地化)
const ROLES = {
  decision: ['制作人 Producer', '创意总监 Creative Director'],
  design:   ['主设计师 Game Designer Lead', '数值设计师 Economy Designer', '关卡设计师 Level Designer', '叙事设计师 Narrative Designer'],
  eng:      ['技术总监 Tech Director', '玩法工程师 Gameplay Engineer', '管线与工具工程师 Pipeline Engineer', '技术美术 Technical Artist'],
  art:      ['美术总监 Art Director', '概念美术 Concept Artist', 'UI·UX 设计师', '音频设计师 Audio Designer'],
  qa:       ['QA 主管 QA Lead', 'QA 测试员 QA Tester'],
  data:     ['数据分析师 Data Analyst', '社区与商店经理 Community & Store Manager'],
}

// 任务 → 激活哪条线/角色（议题激活；可用 --lines 覆盖）
function pickLines(t) {
  const s = (t || '').toLowerCase()
  const lines = new Set(['design'])            // 任何任务都先过设计
  if (s.includes('数值')||s.includes('平衡')||s.includes('经济')) lines.add('data')
  if (s.includes('ui')||s.includes('界面')||s.includes('美术')||s.includes('精灵')||s.includes('图标')||s.includes('概念')) lines.add('art')
  if (s.includes('音')) lines.add('audio')
  if (s.includes('开发')||s.includes('实现')||s.includes('代码')||s.includes('技能')||s.includes('进化')) lines.add('eng')
  if (s.includes('上架')||s.includes('发行')||s.includes('商店')||s.includes('本地化')) lines.add('store')
  if (FULL) { ['decision','eng','art','qa','data'].forEach(l => lines.add(l)); lines.add('audio'); lines.add('store') }
  lines.add('qa') // QA 永远收口
  return lines
}

phase('0 立项：制作人开单')
log('任务：' + (args.task || '') + ' | fullStudio=' + FULL)
log('激活角色线：' + [...pickLines(args.task || '')].join(', '))

// ---------- 1 设计冻结（串行，必须先）----------
phase('1 设计冻结（主设计师/数值/关卡/叙事 按议题）')
const designSkill = (args.skill) || (() => { const s=(args.task||'').toLowerCase(); if(s.includes('种族')||s.includes('race'))return 'race-designer'; if(s.includes('怪')||s.includes('敌'))return 'monster-designer'; if(s.includes('技能'))return 'skill-designer'; if(s.includes('进化')||s.includes('科技'))return 'tech-tree-designer'; if(s.includes('剧情')||s.includes('世界')||s.includes('故事'))return 'narrative-designer'; return 'unit-designer' })()
const design = await agent(`
你是塔防工作室设计线 agent（本议题激活角色：按需扮演 主设计师/数值/关卡/叙事）。
工作目录：${ROOT}。任务：${args.task || '(未给任务：请主动补一个符合项目当前里程碑(M0-M5，见 docs/DESIGN.md)的可落地设计)'}
步骤：
1) 读 docs/RACES.md、DESIGN.md、BALANCE_MODEL.md、docs/变更单 最新 CO、scripts/config.gd 数值口径。
2) 加载 skill：${designSkill}（按其模板发散→收敛）；再加载 design-logic 过五关并当场修订。
3) 写定稿到 docs/变更单/CO-<最新编号+1>.md（若属某族/敌族，另在对应 RACE/资产文档加小节并注明）。
4) 只出设计文档；数值方向给粗档（进 config.gd 前由数值设计师/开发校准）。
输出 JSON：{ docPath, summary, logicGates:{定义关,自洽关,反例关,可验证关,确定度关}, blockers, needsDecisions:["需制作人/用户拍板项"] }
`, { schema: { type:'object', properties: {
  docPath:{type:'string'}, summary:{type:'string'},
  logicGates:{type:'object', properties:{定义关:{type:'boolean'},自洽关:{type:'boolean'},反例关:{type:'boolean'},可验证关:{type:'boolean'},确定度关:{type:'boolean'}}, additionalProperties:false},
  blockers:{type:'string'}, needsDecisions:{type:'array',items:{type:'string'}} },
  required:['docPath','summary','logicGates'], additionalProperties:false } })
if (!design) return { status:'design-agent-failed', phase:'design' }
log('设计冻结 → ' + design.docPath + (design.blockers && design.blockers!=='none' ? (' | 阻塞:'+design.blockers) : ''))

// ---------- 2 并行各线（开发/美术/音频/数据 —— 只依赖设计契约）----------
phase('2 并行执行线（开发∥美术∥音频∥数据）')
const jobSpecs = []
const lines = pickLines(args.task || '')
if (lines.has('eng')) jobSpecs.push(() => agent(`
你是工程线 agent（本议题：技术总监牵头 + 玩法/管线工程师执行）。
契约（唯一事实源）：${design.docPath}（先读它及引用文档）。工作目录：${ROOT}。
按规格实现到 scripts/config.gd 与相关 .gd（数值单一来源、可回滚、跑 headless 冒烟："D:\\softwares\\Godot_v4.5.1-stable_win64.exe" --headless --path "${ROOT}" --quit"）。
不越权改设计；含糊项记 blockers。
输出 JSON：{ changedFiles:[], smoke, blockers }
`, { schema:{type:'object',properties:{changedFiles:{type:'array',items:{type:'string'}},smoke:{type:'string'},blockers:{type:'string'}},required:['changedFiles','smoke'],additionalProperties:false}}))
if (lines.has('art')) jobSpecs.push(() => agent(`
你是美术线 agent（美术总监把关；概念/UI/音频按需）。契约：${design.docPath}。
先读 docs/ART_GUIDE.md + ART_PIPELINE.md + tools/gen/pixelize.py 色板 + docs/briefs/ 模板。
产出：docs/briefs/ARTB-<编号>.md（风格5项/特征/色板/prompt 片段/负向词）+ visual-art-qa 审图清单；
真实出图（ComfyUI/Cursor）在 summary 注明"待出图/已给 prompt"。不写代码。
输出 JSON：{ briefPath, prompts:[], qaReady, blockers }
`, { schema:{type:'object',properties:{briefPath:{type:'string'},prompts:{type:'array',items:{type:'string'}},qaReady:{type:'boolean'},blockers:{type:'string'}},required:['briefPath','prompts','qaReady'],additionalProperties:false}}))
if (lines.has('audio')) jobSpecs.push(() => agent(`
你是音频设计师。契约：${design.docPath}。
产出一份音效/BGM 需求单（docs/audio/<设计名>-sfx.md）：需要哪些事件音/音乐段落/情绪关键词，供 later 程序化或资产实现；不写引擎代码。
输出 JSON：{ docPath, summary, blockers }
`, { schema:{type:'object',properties:{docPath:{type:'string'},summary:{type:'string'},blockers:{type:'string'}},required:['docPath','summary'],additionalProperties:false}}))
if (lines.has('data')) jobSpecs.push(() => agent(`
你是数据分析师。契约：${design.docPath}（含数值方向）。
给"验收该设计需要追踪的数据指标"清单（docs/ 下加一节或独立 .md）：哪些数值要测、目标区间、用什么口径（对照 BALANCE_MODEL）。
输出 JSON：{ docPath, summary, blockers }
`, { schema:{type:'object',properties:{docPath:{type:'string'},summary:{type:'string'},blockers:{type:'string'}},required:['docPath','summary'],additionalProperties:false}}))
if (lines.has('store')) jobSpecs.push(() => agent(`
你是社区与商店经理。契约：${design.docPath}。
给该设计的"展示/传播点"建议（截图/商店文案钩子/更新日志一句话）。不写代码。
输出 JSON：{ docPath, summary }
`, { schema:{type:'object',properties:{docPath:{type:'string'},summary:{type:'string'}},required:['docPath','summary'],additionalProperties:false}}))
const jobs = await parallel(jobSpecs)
const idx = { eng:0, art:0, audio:0, data:0, store:0 }
function take(l){ const i=idx[l]; idx[l]++; return i < jobs.length ? jobs[i] : null }
const eng = take('eng'), art = take('art'), aud = take('audio'), dat = take('data'), sto = take('store')

// ---------- 3 QA + 数据复核（串行收口，制作人门禁）----------
phase('3 QA/门禁收口（QA主管+制作人门禁）')
const qa = await agent(`
你是质量线+决策层 agent（QA 主管复核 + 制作人门禁主持）。工作目录：${ROOT}。
本轮：设计 ${design.docPath}；开发 ${eng?JSON.stringify(eng.changedFiles):'未激活'}; 美术 ${art?art.briefPath:'未激活'}。
1) 契约闭合：开发/美术是否都依设计规格；设计五关是否过。
2) Godot headless 冒烟："D:\\softwares\\Godot_v4.5.1-stable_win64.exe" --headless --path "${ROOT}" --quit"，读 stderr。
3) 对照当前里程碑 exit criteria（读 docs/DESIGN.md 的 M 定义 + 项目 QA 清单），给门禁结论。
输出 JSON：{ status:"pass|needs-user|fail", smoke, issues:[], milestoneGate:"M0-M5 哪档", nextStep }
`, { schema:{type:'object',properties:{status:{type:'string'},smoke:{type:'string'},issues:{type:'array',items:{type:'string'}},milestoneGate:{type:'string'},nextStep:{type:'string'}},required:['status','smoke','issues'],additionalProperties:false}})

return {
  status: qa ? qa.status : 'qa-agent-failed',
  roles: { design: design.docPath, dev: eng?eng.changedFiles:null, art: art?art.briefPath:null, audio: aud?aud.docPath:null, data: dat?dat.docPath:null, store: sto?sto.docPath:null },
  gate: qa ? qa.milestoneGate : null,
  blockers: [design.blockers, eng&&eng.blockers, art&&art.blockers, aud&&aud.blockers, dat&&dat.blockers].filter(Boolean),
  issues: qa ? qa.issues : [],
  note: '角色按议题激活；fullStudio=true 全线上（省 token 默认只激活相关线）。阻塞项交用户拍板再续跑。',
}
