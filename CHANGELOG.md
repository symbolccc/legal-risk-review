# Changelog

遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与语义化版本。

## v1.4.0 — 2026-10-16

消除评测偏斜：此前 `settlement-review.md` 与 `contract-seal.md` 两份细则**零用例覆盖**，
只有供应商与垫款文书被测。

### Added

- `validate-opinion.ps1` 改为 profile 感知，三类文书共用一个校验器，
  由文件首行 `<!-- profile: xxx -->` 选择：
  - `payment-term` 垫款/风控意见（五段 + 结论三要素 + 穿透算式）
  - `settlement` 返点/结算单审理（九项核对 ≥5 + 缺陷必须逐项点名）
  - `seal` 用印与归档（份数 + 去向闭环）
- `opinion-requirements.json` 改为 profiles 结构，新增 `vague_defect_patterns`、
  `enumerated_defect_pattern`，所有 CJK 词表集中在配置里。
- 结算单 golden 2 个（通过、退回并逐项点名四个缺陷）、用印 golden 1 个。
- 负例 2 个：结算单用「材料不全」笼统概括、用印记录缺原件去向。
- 用例数下限提升：legal 2→5，negative 5→8。
- `legal-risk-review` 的 description 增加英文摘要，便于跨语言检索命中。

### Fixed

- **`@($null).Count` 等于 1 导致的误判**：profile 缺少某字段时，
  `@($p.penetration_terms).Count -gt 0` 恒为真，产生一个只含 `$null` 的列表，
  而 `$null` 参与 `-like` 匹配会命中任意文本，于是所有非垫款类文书都被判为
  「只有 1 项、不足 5 项」。改为显式检查属性是否存在。
- **脚本内中文字面量再次违反纯 ASCII 约束**：`材料不全` 在 PowerShell 5.1 下被读成乱码，
  规则永不触发。移入配置文件。
- **笼统措辞检测扫描全文**：核对项段落里的合法分号会让校验器误认为「已逐项列举」，
  而真正的笼统结论在另一段。改为只在结论段判定。

## v1.3.0 — 2026-10-16

拆分为两个技能。此前把 OA 自动化项目的输出契约与工程约束，当成了通用法务审核口径。

### Changed

- **仓库现在包含两个独立技能**：`legal-risk-review`（文书类审核，输出中文文书）与
  `oa-supplier-review`（供应商入库，输出 JSON）。资金方向相反，结论口径不可互相套用。
- `schemas/review-output.schema.json` → `schemas/supplier-review-output.schema.json`，
  描述明确限定为供应商程序专用，不再自称「适用于所有审核」。
- 工程实现约束（API Key 位置、内存处理、超时重试、不自动提交、串单防护）从审核细则
  `supplier-rules.md` 移入 `oa-supplier-review` 的独立章节。
- `legal-risk-review` 主干移除供应商内容，改为指向另一技能。
- `build-dist.ps1` 改为自动发现每个技能的源文件，按技能各自出版本号，
  并检测陈旧构建产物。

### Added

- `scripts/validate-opinion.ps1` + `scripts/opinion-requirements.json`：
  中文文书的结构校验——必需段落、结论三要素、穿透算式是否写出、
  **有证据缺口却声称无异议**。段落词表放配置文件，脚本保持纯 ASCII。
- `evals/legal/` 2 个文书 golden：双线账期穿透、GMV 缺失但正确标注待补。
- `evals/invalid/opinion-gap-but-clean.md` 文书负例。
- `skills/oa-supplier-review/`：R1–R12、页面结构事实、七项未确认、工程约束、自检。
- CI 新增两项门禁：
  - **评测文件跟踪数断言**（防止 `.gitignore` 再次静默吞掉 golden）
  - **技能规范性检查**（目录名与 `name:` 一致、有 version、description 含触发条件）
- `run-evals.ps1` 新增**用例数量下限断言**：目录缺失或被忽略时报红，不再静默通过。
- `run-evals.ps1` 按扩展名分派校验器：`.json` 走契约校验，`.md` 走文书校验。

### Fixed

- **`.gitignore` 的裸 `cases/` 吞掉了 `evals/cases/`**：6 个 golden 从未进入版本库，
  CI 因此只跑负例却报告全绿。已锚定为 `/cases/`，并加断言防复发。
- **评测器跨文件泄漏期望值**：`.md` 用例没有 `_expect`，会沿用上一个 `.json` 的期望理由，
  导致校验器正确拦截却被判为 WRONG-REASON。改为每个文件独立重置。
- **等号检查作用域错误**：穿透算式位于账期段落而非结论段落，原实现误判合规文书。
- `Split-Path -Extension` 不存在，改用 `[System.IO.Path]::GetExtension`。
- `validate-opinion.ps1` 中的中文字面量违反纯 ASCII 约束，改由配置文件提供。

## v1.2.0 — 2026-10-16

把「有唯一正确答案的部分」从提示词下沉为可执行代码，并建立回归防线。

### Added

- `schemas/review-output.schema.json`：输出契约。枚举即规范，非法枚举值使整条结论作废并转人工，不自动纠正。
- `scripts/validate-uscc.ps1`：统一社会信用代码格式与 GB 32100-2015 校验位重算。可抓出「表单与附件填了同一个错码」这类比对无法发现的问题。
- `scripts/validate-output.ps1`：双层校验——Schema 合规 + 结论与 checks 自洽。专门拦「有 uncertain 却标 confidence: high」这类矛盾。
- `scripts/run-evals.ps1`：评测执行器。golden 必须通过，负例必须被拦且**理由正确**。
- `evals/cases/` 6 个 golden：成本/费用填反、地址层级省略与注册资本写法差异、模糊附件、注销主体、校验位失败、附件类型不符。
- `evals/invalid/` 5 个负例：枚举非法、分档矛盾、置信度矛盾、uncertain 未标记、有 fail 但 issues 为空。
- `tests/test-uscc.ps1`：校验位单测，含 540 个单字符变异全检（汉明距离 1 完整覆盖）。
- `.github/workflows/ci.yml`：ubuntu 与 windows 双平台门禁，含 dist 可重现性检查与 .ps1 纯 ASCII 检查。

### Fixed

- **校验器形同虚设的缺陷**：`Add-V` 写入 `$global:v` 而汇总读取脚本作用域的 `$v`，导致所有违规被静默丢弃、任何输入都判通过。由负例集当场暴露并修复——这正是负例存在的意义。
- **扫描器自指误报**：`scan-secrets.ps1` 命中自身模式表，已排除自身文件。
- **评测数据含 16 位连续数字**：会被识别为真实卡号，已改为占位形式。

### Changed

- 工作流程新增两步：信用代码必须过脚本判定；输出 JSON 必须过自洽校验。
- 单文件分享版纳入 Schema（附录 I），可独立查阅输出契约。
- 脚本层统一纯 ASCII：Windows PowerShell 5.1 将无 BOM 的 UTF-8 脚本按 ANSI 解析，中文注释会直接导致语法错误。

## v1.1.0 — 2026-10-15

对供应商入库审批模块做逆向检查后修补。修复 5 处可导致误判的问题，另补 10 处歧义与缺口。

### Fixed

- **示例自相矛盾**：示例中存在 `uncertain` 却标注 `confidence: high`，与 §4「存在任一 uncertain → low」冲突。已改为 `low`，并在 §4 增加禁止凭印象填结论字段的说明。
- **敏感信息规则与输出模板冲突**：铁律禁写「合同金额明细」，而垫款意见模板要求填金额。已拆成两个语境：审批文书必须写金额；记忆仓库、日志、公开文件与示例不得写。
- **多银行账户口径冲突**：§5 曾把「多银行账户」列为建议复核（出件但标注），而未确认项要求需人工核验。统一为必须人工。
- **注册资本误杀**：原要求逐字符确认，导致「32.86 亿元」与「328600 万元」被判不一致。改为数值等价比对。
- **地址容错方向不明**：未规定省略发生在表单侧还是附件侧。明确省略方向不限，只比对双方共有层级。

### Added

- **第 0 步前置硬校验**：统一社会信用代码格式与 GB 32100-2015 校验位本地重算、主体存续性。三项为确定性事实，失败即 `fail`，不降级为 uncertain。
- **R10 主体存续性**：经营状态须为存续/在业。此前字段存在但无任何规则引用，已注销主体可被建议通过。
- **R11 营业期限**：合作期间须落在营业期限内。
- **R12 建档一致性**：避免已建档主体重复入库。
- **附件第四态**：类型与用途不符（如拿身份证当营业执照）判 `fail`，且必须在字段比对之前判定。
- **已知限制章节**：重名无法区分身份、不查外部风险名单、不判商业合理性、依赖第三方数据新鲜度。
- Gotchas 由 12 条增至 17 条；自检清单由 9 项增至 13 项。
- 示例补充注销主体、校验位不符、期限过期、注册资本写法差异四种情形。

### Changed

- `confidence: high` 的前置条件收紧为「不存在任何 uncertain」。
- §5 升级路径三档均扩充新触发条件。

## v1.0.0 — 2026-10-15

### Added

- 通用铁律：禁止编造（含禁止推算数字）、「未查到 ≠ 不存在」、不确定即人工核验、归属三分。
- 垫款/风控意见固定结构与账期穿透算法、GMV 时效口径、额度核定规则。
- 供应商入库审批 R1–R9 全表、部门口径、六项刻意留空的未确认项。
- 返点与结算单 A/B/C/D/E 五类审理流程与九项全维度核对。
- 合同用印与原件归档八段流程。
- 分档判定（结论三值 + 字段级红黄绿 + 置信度条件）。
- 升级路径三档（立即上报 / 必须人工 / 建议复核）。
- Gotchas 易错清单 12 条。
- 证据来源契约（来源优先级、逐字符规则、容错范围、缺失来源三态区分）。
- 可填输出模板与标准审批话术对照表。
- 两个脱敏示例（账期穿透分档、供应商审批 JSON 与侧边栏呈现）。
- 边界声明：本技能不做什么。

### Changed

- 采用 `skills/<name>/SKILL.md` 目录布局，支持 `npx skills add` 与插件式安装。
- 细则移入 `references/`，主干精简为可一次读完的 L2 层（渐进式披露）。

### Not yet included

- 自动化脚本与 `tests/`（当前为纯 Markdown 技能，无代码可测）。
- 分档阈值与额度比例的公司级校准（标注为「待校准」）。
