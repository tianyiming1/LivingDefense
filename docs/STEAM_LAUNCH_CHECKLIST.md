# Steam 上架执行清单（M6-M7）

> 状态：存档规划（2026-09-02 生成）· 触发时机：游戏完成度到 M5（内容冻结、无 P0/P1）后启用
> 配套技能：`steam-publish`（~/.agents/skills，含 steampipe-build-scripts 参考）
> 本清单所有"只能本人完成"项标注 👤（AI 不可代办）

## 一、总时间线

| 阶段 | 内容 | 耗时 | 备注 |
| --- | --- | --- | --- |
| 0 前置 | 完成度到 M5 | 3-5 个月业余 | 见 DESIGN.md 里程碑 |
| 1 申请 | Steam Direct $100 + App ID | 即时 | 👤 注册 |
| 2 合规 | 身份验证 + W-8BEN + 银行 | 3-7 天 | 👤 全部本人 |
| 3 商店页 | capsule/截图/文案/标签/预告 | 3-5 工作日审核 | 素材可提前做 |
| 4 Coming Soon | 商店页上线等待期 | **≥2 周硬等待** | 建议提前 2-3 周挂出 |
| 5 传包 | steamcmd + VDF 上传 | 数小时 | steam-publish 技能 |
| 6 构建审核 | build 提交 | 几天 | 须商店页先过审 |
| 7 发售 | Release App（手动） | 即时 | 不会自动发售 |

## 二、Steam Direct 注册（👤 本人）

- [ ] 用本人 Steam 账号注册 Steamworks（partner.steamgames.com）
- [ ] 支付 $100/款（销售额累计 $1000 可退）
- [ ] 拿到 App ID（后续一切以它为主键）
- [ ] 创建独立构建账号（最小权限：Edit App Metadata + Publish App Changes；正式发售另需 Manage pricing）

> ⚠️ 安全：构建账号密码与 config.vdf 登录令牌**禁止提交进 git**

## 三、身份与税务（👤 本人）

- [ ] 身份验证：真实姓名 / 地址 / 手机
- [ ] 非美国个人填 W-8BEN（见下）
- [ ] 绑定收款银行账户

### W-8BEN 是什么（备忘）

- 美国 IRS 表格，向 Steam 声明"我不是美国纳税人"
- 不填：Steam 按最高 30% 预扣你的分成收入
- 填后：按中美税收协定通常降为 0-10%（游戏版税口径常见 0%，以申报选择为准）
- 准备材料：姓名（护照拼音）/ 国籍（中国）/ 中国英文地址 / 美国税号选"无" / 护照号
- 提交：Steamworks 后台税务向导（有中文），非纸质
- 不是额外收钱，是"少被扣钱"的必需声明

> ⚠️ 税务判定（版税 0% vs 10%、中国境内是否再申报）建议咨询专业财税或强模型复核，
> 本清单只含流程信息，不含税务结论。

## 四、商店素材规划（AI 可提前产出文档，图片需美术/工具）

- [ ] 名称：活体防线 The Living Rampart（已定）
- [ ] 副标题：塔会走，会流血，会进化（已入 strings.csv）
- [ ] 一句话描述（商店首行）：「不是普通塔防——你的塔会走、会死、会进化，四族活塔守一条防线」
- [ ] capsule 图：616x353（主图）+ 各尺寸衍生（616x353 / 460x215 / 231x87 等）
- [ ] 截图 5+ 张：选族 / 布防 / 波次战斗 / 进化 / Boss（等美术就绪后截）
- [ ] 标签建议：Tower Defense、Strategy、Indie、RTS、Multiplayer?（若后续加）
- [ ] 预告片：30-60s 实机（可选，M6 后期）
- [ ] 本地化：中/英已内置（CO-002），后续按需加语言

## 五、构建与上传（可用 steam-publish 技能执行）

- [ ] Godot 导出 Windows exe（Export → Windows Desktop，gl_compatibility 已默认）
- [ ] 下载 Steamworks SDK → tools/ContentBuilder/
- [ ] 编写 app_build_<AppID>.vdf（FileMapping 模板见 steam-publish 技能）
- [ ] steamcmd 登录（构建账号）+ run_app_build
- [ ] 先用 Preview=1 校验文件映射，再正式上传
- [ ] Beta 分支先测（SetLive beta-qa），确认后手动 set live default
- [ ] 提交 build 审核（须商店页已过审）

## 六、发售

- [ ] 商店页 + 构建双审核通过
- [ ] Coming Soon 满 2 周
- [ ] Release App → Publish Now → Release Now（手动，无人代按）

## 七、售后（M7）

- [ ] 定价策略（参考同类 TD：$9.99-$14.99 区间，发行时再定）
- [ ] 首周补丁预案（严重 bug 响应窗口）
- [ ] 社区：Steam 社区讨论 + 更新日志
- [ ] 首月销量复盘（数据进 kb）

## 关联

- 里程碑定义见 DESIGN.md §三；kb/01 §三 路线图含 M6-M7
- 平台替代：itch.io 可先挂免费/付费页练手（itch-publish 技能，5 分钟）