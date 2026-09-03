# 《活体防线》素材合规策略（ASSET POLICY）

> 非律师意见。上架 Steam / 商业发行前，重要合同与授权请自行核对或咨询律师。  
> 目标：**游戏内全部可见素材可溯源、可商用、不侵犯第三方权利。**

---

## 1. 允许进入正式包体的素材

| 类型 | 是否可商用 | 条件 |
|------|------------|------|
| 本仓库程序生成（`tools/gen/draw_*.py`） | ✅ | 自有代码输出，默认安全 |
| 自绘 / 委托外包（合同含商用+独家或转让） | ✅ | 保留合同与交接记录 |
| CC0 / 公有领域 | ✅ | 保留来源链接与许可证副本 |
| 明确商用授权的付费素材包 | ✅ | 许可证允许「游戏发行」；注明署名要求 |
| 本地开源模型出图（如 Apache-2.0 / 允许商用的 OpenRAIL 系） | ⚠️ 条件允许 | 见 §3；禁止抄袭现有 IP |
| 在线 AI（Leonardo 等）**付费档且 ToS 赋予所有权/商用权** | ⚠️ 条件允许 | 保存账单与当时 ToS 截图 |
| 在线 AI **免费档** | ❌ 默认不进正式包 | 多数平台 IP 归平台或非独占，他人可同图商用 |
| 未知来源图 / 网图 / 其他游戏拆包 | ❌ | 一律禁止 |
| 「某某游戏风格 / 某某角色」提示词 | ❌ | 商标与外形近似风险高 |

---

## 2. 绝对禁止

1. 使用任天堂、暴雪、米哈游、Valve 等现有角色、标志、关卡图。  
2. 把其他商业游戏的 sprite / 音效 / 字体直接放进工程。  
3. 用「原作角色名 / 精确皮肤复刻」出图再当原创。  
4. 未经授权的真人肖像、受保护建筑/品牌标识。  
5. 来源说不清的「网上找的像素龙 / 狼人」。

---

## 3. 本项目已用模型（权重不进游戏包，只作出图工具）

| 模型 | 路径 | 许可证（权重） | 说明 |
|------|------|----------------|------|
| LCM Dreamshaper v7 | `D:\AI_models\lcm_dreamshaper_v7` | 以 HF 页面为准（常为 OpenRAIL 系） | 出图需遵守模型卡 Restrictive 条款 |
| Pixel SpriteSheet | `D:\AI_models\pixel_sprite` | **Apache-2.0** | 权重可商用；**输出**仍须原创、不抄现有 IP |

**注意：** 模型许可证 ≠ 输出版权自动归你。仍须：原创设定、不模仿知名作品、保留生成记录。

---

## 4. 在线平台（简要）

| 平台 | 免费档商用/所有权 | 建议 |
|------|-------------------|------|
| Leonardo.ai | 免费档：**平台主张 Output IP 归属平台**；仅给非独占许可；图常公开 | **上架素材勿用免费档出图**；付费档再核对当时 ToS |
| 即梦 / 通义等 | 以各平台最新用户协议为准 | 商用前必须读「知识产权 / 商用」条款并截图存档 |

---

## 5. 入库流程（强制）

目录架构（ship / `_studio`）见 `assets/pixels/README.md` 与 `.cursor/skills/asset-architecture/SKILL.md`。
候选与临时图只进 `_studio/`，不得堆进正式种族目录。

每张进入 `assets/pixels/` **正式（ship）**路径的图，必须在 `assets/pixels/PROVENANCE.json` 登记：

- `id`：如 `dragon/unit_0`
- `source`：`procedural` / `local_sd` / `leonardo_paid` / `commission` / `cc0` …
- `tool`：模型或软件名 + 版本/日期
- `license`：CC0 / Apache输出 / 合同编号 / 自有
- `commercial_ok`：`true` / `false`
- `notes`：提示词是否含第三方 IP、是否需署名

**`commercial_ok: false` 的文件不得用于 Steam 构建。**

导入命令：

```powershell
python tools/gen/import_ai_sprite.py --id dragon/unit_0 --src ...
# 随后编辑 PROVENANCE.json，或使用：
python tools/gen/record_provenance.py --id dragon/unit_0 --source local_sd --commercial-ok
```

---

## 6. 当前工程风险分级（摘要）

见 `assets/pixels/PROVENANCE.json`。原则：

- **程序像素（draw_*）**：可作占位与兜底，法律风险最低。  
- **Leonardo 免费档导入的龙**：上架前应 **替换**（付费档重出 / 本地合规模型重出 / 外包）。  
- **本地 SD img2img 龙**：可用作原型；发行前确认提示词无第三方 IP，并完成 provenance。  
- **用户聊天中贴的未知来源狼人等**：在确认来源前 **禁止入库**。

---

## 7. 发行前检查清单

- [ ] 所有 `assets/` 下 PNG/音频/字体均有 provenance 或 LICENSE  
- [ ] 无免费档在线 AI「平台所有权」素材进入正式包  
- [ ] 无第三方商标、角色名、抄袭剪影  
- [ ] 字体为 OFL/自有/已购商用授权  
- [ ] 音效来自自研程序音 / CC0 / 已购授权（见 DESIGN 中 freesound 等，需逐条核对许可）  
- [ ] Steam 商店图同样遵守本策略  

---

## 8. 推荐的「零纠纷」美术路线（本项目）

1. **默认**：`draw_sprites_34.py` / `draw_map_tiles.py` 程序像素（已自有）。  
2. **提升品质**：本地开源模型 + **原创提示词** + 人工修图（Aseprite），并写 provenance。  
3. **最终品质**：外包或自绘，合同写明「商用、可改、可上架、权利转让/独家」。  
4. 避免依赖「免费在线 AI 抽卡图」作为终稿。
