# oa-supplier-review — 单文件分享版

> 本文件由 `scripts/build-dist.ps1` 从仓库内该技能的各源文件按顺序拼接生成，**内容与源文件逐字一致**。
> 用途：整段粘贴给任何 AI，或放进产品知识库，无需安装目录结构。
> 修改请改源文件后重新运行构建脚本，不要单独编辑本文件。
> 仓库：https://github.com/symbolccc/legal-risk-review

## 关于附录

附录为该技能目录下 `references/`、`assets/`、`examples/`（以及适用的输出契约）的完整原文，
由构建脚本自动发现并按字母顺序编号。主干中指向某个细则时，可在附录按路径找到同名文件。

## 可执行层（本文件之外，需 clone 仓库）

规则里凡是**确定性检查**，都不该交给模型。仓库提供零依赖 PowerShell 脚本，
Windows PowerShell 5.1 与 pwsh 7 通用：

| 脚本 | 作用 |
| :-- | :-- |
| `scripts/validate-uscc.ps1` | 统一社会信用代码格式与 GB 32100-2015 校验位重算 |
| `scripts/validate-output.ps1` | 校验 JSON 输出是否符合契约 **且**结论与 checks 自洽 |
| `scripts/validate-opinion.ps1` | 校验中文文书段落完整、结论三要素、是否「有缺口却称无异议」 |
| `scripts/run-evals.ps1` | 回归评测：golden 必须通过，负例必须被拦且理由正确，**并断言用例数量下限** |
| `tests/test-uscc.ps1` | 校验位单测，含 540 个单字符变异全检 |
| `scripts/scan-secrets.ps1` | 凭据与隐私数据扫描 |

CI（`.github/workflows/ci.yml`）在 ubuntu 与 windows 双平台跑上述全部检查，并强制
`dist/` 与源文件同步、`.ps1` 保持纯 ASCII、`.gitignore` 不得吞掉评测目录。

> 单文件版可独立阅读；要真正落地审核，建议 clone 仓库使用脚本层，
> 让「校验位对不对」「结论自不自洽」「文书缺不缺段」由代码判定而不是由模型自觉。

---

---
name: oa-supplier-review
description: 致远 OA 供应商入库审批的自动化审核规则层。用于判断供应商审批单能否通过：供应商类型与申请部门是否匹配、跨境业务判定、营业执照与银行信息核验、一般纳税人三方一致、主体存续性与营业期限、统一社会信用代码校验位，以及输出结构化 JSON 审核结论。当用户要求审供应商入库单、核营业执照或银行证明、判断供应商能否通过、生成审批意见 JSON 时使用。
version: 1.0.0
license: MIT
author: symbolccc
---

# OA 供应商入库审核

## 这个 skill 与 legal-risk-review 的区别

| | legal-risk-review | 本 skill |
| :-- | :-- | :-- |
| 审的是 | 我方要不要给客户账期、垫不垫钱 | 我方能不能让这家供应商入库打款 |
| 资金方向 | 客户 → 我方 | 我方 → 供应商 |
| 交付形态 | 中文文书（垫款意见、风控意见） | 结构化 JSON + 审批意见文本 |
| 消费方 | 法务与业务复核 | Edge 扩展侧边栏渲染 |

两者共用信用代码校验与证据契约，但**结论口径不可互相套用**。

## 免责声明

输出为**初审建议**，不构成法律意见。最终是否通过由人工在 OA 中提交决定。本技能不自动提交，也不实现任何等效逻辑。

## 0. 三条不可让步的约束

1. **不自动提交**：只允许「填入审批意见」，提交必须由人点击。
2. **不绕过安全机制**：不规避登录、验证码、权限与数据访问限制。
3. **不确定即人工**：证据不足、字符不可辨认、规则未配置，一律 `需人工核验`，不得默认通过。

## 1. 审核流程

1. 绑定单据：读取当前 `case_id`，**切换单据后必须重新绑定**，禁止沿用上一单结论。
2. 附件类型预检：先确认每个附件是不是它声称的那种证照（见 `references/source-contract.md` 第四态）。类型不符直接 `fail`，不进入字段比对。
3. 硬校验（确定性，必须用脚本）：
   - 统一社会信用代码格式与校验位 → `scripts/validate-uscc.ps1`
   - 主体存续性（经营状态）
4. 逐字段比对：按 `references/supplier-rules.md` 的 R1–R12 判定 `pass` / `fail` / `uncertain` / `not_applicable`。
5. 分档：任一 `fail` → 建议打回；无 `fail` 有 `uncertain` → 需人工核验；全 `pass` → 建议通过。
6. 置信度：存在任一 `uncertain` 即 `low`；`high` 要求零 `uncertain` 且关键字段均有可读原件支撑。
7. 输出 JSON 必须过 `scripts/validate-output.ps1`，它同时检查 Schema 与「结论是否由 checks 推出」。

## 2. 输出契约

见 `schemas/supplier-review-output.schema.json`。要点：

- 枚举值即规范，**非法枚举使整条结论作废并转人工，不得自动纠正**。
- 每个 `uncertain` 项的 `requires_human_review` 必须为 `true`。
- 有 `fail` 时 `issues` 不得为空——每个缺陷都要点名。
- `model_notes` 必须写明实际读了哪些来源、哪些没读到。

## 3. 细则与配置

| 内容 | 位置 |
| :-- | :-- |
| R1–R12 全表、部门口径、未确认项、已知限制 | `references/supplier-rules.md` |
| 证据来源优先级、附件类型校验、缺失四态 | `references/source-contract.md` |
| 完整输出示例（含 JSON 与侧边栏呈现） | `examples/example-supplier-review.md` |

## 4. 工程约束（做自动化系统时）

这些是**实现层面**的要求，与审核规则分开：

- API Key 只放后端环境变量，不进浏览器扩展。
- 附件只在内存处理，不落用户下载目录，不写入长期存储。
- 模型输出必须过 JSON Schema 校验后才可渲染。
- AI 调用超时返回「需人工核验」，不得卡住审批页面；最多重试一次。
- 日志不记录完整账号、附件原件与凭据。
- 扩展只在供应商审批表页面运行，不读取其他表单。
- 侧边栏结果与 `case_id` 绑定，防止串单。

## 5. 页面结构事实

供实现参考，来自真实单据的 DOM 探测，非推测：

- 表单本体在 **cap4 子 iframe** 内，主文档 frame 读不到字段。
- 表单 frame 特征：`section=97 attach=3 iframe=1 table=4`。
- 附件区块类：`cap4-attach`、`cap4-attach__items`、`cap4-attach__browse`。
- 打开单据时 OA 会另开一个浏览器窗口，该窗口默认无扩展入口。

## 6. 未确认项（默认输出需人工核验）

以下七项刻意留空，不得猜测或用行业惯例补全：

1. 全部业务部门的标准名称 / 部门编码完整名单
2. 「境外公司」的准确判定标准
3. 国际业务部门清单（当前仅知一个名字，改名或新增会静默失效）
4. 一般纳税人合格证明的文件类型
5. 银行名称简称是否允许
6. 多个银行账户如何判断
7. 企业名称括号、简称、英文名是否视为一致

## 7. 自检

1. `case_id` 是否绑定到当前单据？
2. 附件类型是否先于字段比对确认？
3. 信用代码是否过了脚本，而不是心算？
4. 经营状态与营业期限是否核过？
5. 每个 `uncertain` 是否都标了 `requires_human_review: true`？
6. 有 `fail` 时 `issues` 是否点名了每一个？
7. `confidence` 是否与 `uncertain` 数量自洽？
8. 输出是否过了 `validate-output.ps1`？



---

# Appendix A - references/source-contract.md

# 供应商审核证据契约

> 定义「什么算证据、冲突时信谁、取不到时怎么办」。

## 来源优先级

| 优先级 | 来源 | 用途 |
| :-- | :-- | :-- |
| 1 | 附件原件（营业执照、银行开户证明、纳税人证明） | 证照类字段的最终依据 |
| 2 | OA 自动带出的第三方工商数据 | 企业信息比对基准（R4） |
| 3 | OA 表单字段（业务方填写） | **被审对象，不是证据** |
| 4 | 业务方聊天补充说明 | 仅用于澄清，不得替代原件 |

表单与证据冲突时，判表单错。

## 先验类型，再看内容

附件进入字段比对前必须先回答：**这是不是该字段要求的证照？**

拿身份证、合同页、系统截图当营业执照时，后续比对全部发生在错误对象上。类型不符直接 `fail`，不进入字段环节。

## 逐字符字段

以下字段任一位无法确认即不得判 `pass`：

- 统一社会信用代码
- 银行账号

> 信用代码还须过格式与校验位硬校验（`scripts/validate-uscc.ps1`）。表单与附件填同一个错码时比对一致，只有校验位能抓出这种「一致地错」。

## 数值等价字段

| 字段 | 比对方式 |
| :-- | :-- |
| 注册资本 | 换算到同一单位后相等即 `pass`；位数读不全才 `uncertain` |
| 成立日期 / 期限 | 日期解析后比较，格式差异不算不一致 |

## 层级容错（仅地址）

只比对**双方都写出来的层级**；一方多写出的层级不作为不一致依据；任一共有层级实质冲突即 `fail`。省略方向不限。

## 来源缺失四态

| 情况 | 措辞 | 结论 |
| :-- | :-- | :-- |
| 未提供 / 未上传 | 「未提供 X 附件」 | 退回补件 |
| 已读取但不可辨认 | 「X 已读取，字段不可辨认」 | 需人工核验 |
| 不在本系统内 | 「未查询 X（数据在 Y 系统）」 | ⚠️ 待补，不得推断不存在 |
| 已上传但不是该类文件 | 「附件内容与用途不符，未识别为 X」 | **fail 退回** |

## 输出必须声明

1. 实际读取了哪些来源
2. 哪些未能读取及原因
3. 每个判定字段对应哪个来源
4. 无法确认字段是否已全部标为需人工核验

## 禁止

- 用行业常识、历史单据、外部公开信息补全当前单据缺少的字段。
- 把业务方填报值当作已验证事实。
- 来源不足时给「建议通过」。
- 类型校验之前先做字段比对。



---

# Appendix B - references/supplier-rules.md

# 供应商入库审批细则（R0–R12）

> 按需加载。SKILL.md 主干只保留判定流程，本文件是完整规则表。

## 第 0 步：前置硬校验（先做，不通过就不用往下走）

这三项是**确定性事实**，不依赖比对，失败即 `fail`，不得降级为 uncertain：

| 校验 | 规则 | 失败结论 |
| :-- | :-- | :-- |
| 统一社会信用代码格式 | 长度必须 18 位；字符集仅 `0-9` 与大写字母，不含 `I O Z S V` | fail：代码格式非法，退回 |
| 统一社会信用代码校验位 | 按 GB 32100-2015（MOD 31-2）重算第 18 位，与填写值比对 | fail：校验位不符，说明存在录入错误或伪造 |
| 主体存续性（R10） | 经营状态须为「存续 / 在业」 | 注销、吊销、清算、停业、其他异常 → fail 打回 |

> 校验位算法是本地可算的公开国标，不需要外部接口。**两边表单与附件填了同一个错码时，比对会 pass，但校验位一定报错**——这是唯一能抓出「一致地错」的手段。

## 规则表

| 编号 | 规则 | 判定依据 |
| :-- | :-- | :-- |
| R1 | 申请部门为业务部门 → 供应商类型应为「成本类」 | 部门口径见下 |
| R2 | 非业务部门 → 供应商类型应为「费用类」 | 部门口径见下 |
| R3 | 供应商为境外公司，或申请部门命中「国际业务部门清单」→ 跨境业务应为「是」 | 清单为配置项；清单缺失或境外标准未配置时 → uncertain |
| R4 | 企业信息以 OA 自动带出的第三方工商数据为当前比对基准 | 基准优先级见 source-contract.md |
| R5 | 营业执照核验：主体名称、统一社会信用代码、注册资本、注册地址、法定代表人 | 附件证据 |
| R6 | 地址比对方向不限：只要**双方已出现的层级**字符串一致即可；任一共有层级实质冲突即 fail | 仅地址有层级容错 |
| R7 | 银行核验：户名、开户行、账号、统一社会信用代码 | 附件证据 |
| R8 | 一般纳税人：OA 选择、第三方工商信息、上传证明三者一致 | 三方交叉 |
| R9 | 无法从证据确认时，结论必须为「需人工核验」 | 兜底规则 |
| R10 | 主体存续性：经营状态须为存续/在业 | 见第 0 步 |
| R11 | 营业期限：合同或合作期间落在营业期限内；已过期或到期日早于合作结束 → fail；期限字段读不到 → uncertain | 附件 + 表单期限字段 |
| R12 | 建档一致性：表单「供应商是否已建档」为是却走新建流程，或反之 → uncertain 需人工 | 避免重复建档 |

**R9 与前置校验的优先级**：第 0 步三项属于「可确定的错」，判 `fail`；R9 管的是「确定不了的」，判 `uncertain`。两者不冲突。

## 字段比对方式（区分三种，别一律逐字符）

| 字段 | 比对方式 | 说明 |
| :-- | :-- | :-- |
| 主体名称 | 逐字 | 括号/简称/英文名是否等价属未确认项，遇差异走 uncertain |
| 统一社会信用代码 | 逐字符 + 校验位 | 任一位不可辨认即 uncertain；格式或校验位错即 fail |
| 银行账号 | 逐字符 | 任一位不可辨认即 uncertain |
| 注册资本 | **数值等价** | 换算到同一单位后相等即 pass（如 32.86 亿元 = 328600 万元）；数字位数读不全时仍 uncertain |
| 注册地址 | 层级比对 | 见 R6 |
| 法定代表人 | 逐字 | 重名无法区分为已知限制，见下 |

## 部门口径

- 业务部门：常规业务部门，如华北、华南。
- 非业务部门：法务、行政、数智中心。
- 拿不准的**必须问本人**，不得自行归类；未归类前 R1/R2 输出 uncertain，不得默认任一类型。

## 尚未确认，默认输出「需人工核验」

以下七项刻意留空。遇到时不得猜测、不得用行业惯例补全：

1. 全部业务部门的标准名称 / 部门编码完整名单
2. 「境外公司」的准确判定标准
3. R3 的国际业务部门清单（当前仅知「引力国际」一个名字，改名或新增会静默失效）
4. 一般纳税人合格证明的文件类型
5. 银行名称简称是否允许
6. 多个银行账户如何判断（**统一按需人工核验处理，不存在「出件但标注」的宽松档**）
7. 企业名称括号、简称、英文名是否视为一致

## 已知限制（不要假装能解决）

- **重名无法区分**：法定代表人与股东同名同姓时，本技能只能比对字符串一致，不能确认是否同一自然人。字符串一致即 pass，但需在 `model_notes` 里留一句「同名未做身份核验」。
- **不查外部风险名单**：失信、被执行、股权冻结等不在本技能范围内，需另行核查。
- **不判断商业合理性**：注册资本过低、成立过短等只提示事实，是否放行由人决定。

## 字段清单（OA 可稳定读到的）

表单编号 / 申请人 / 申请人部门 / 申请人电话 / 供应商类型 / 是否国内外企业 / 是否社交运营供应商 / 供应商联系人 / 供应商联系人电话 / 供应商联系人邮箱 / 是否跨境业务 / 备注说明 / 供应商是否已建档 / 供应商名称 / 供应商编码 / 统一社会信用代码 / 公司类型 / 成立时间 / 注册地址 / 注册资本 / 法定代表人 / 实缴资本 / 经营状态 / 是否涉及开票信息 / 营业开始时间 / 营业结束时间 / 营业期限 / 是否一般纳税人 / 一般纳税人网址 / 营业范围 / 实际经营地址 / 户名 / 开户行名称 / 收款账号 / 法务审批 / 财务审批

## 相关但不在本文件的内容

工程实现约束（API Key 位置、内存处理、超时重试、串单防护、不自动提交）见 `../SKILL.md` 第 4 节。
本文件只写**审核判定规则**，不写系统怎么搭。



---

# Appendix C - examples/example-supplier-review.md

# 示例二：供应商入库审批输出

> 单据编号、企业名、代码、人名均为脱敏示意。示例只演示**格式**，`confidence` 等结论字段必须按 SKILL.md §4 现推，不得照抄。

## 输入

```
申请部门：某业务部（业务部门）
供应商类型：费用类
是否跨境业务：否
供应商是否已建档：否
法定代表人：张某某
统一社会信用代码：91330100MA2XXXXXX9
经营状态：有限责任公司分公司注销
营业期限：2015-06-01 至 2025-12-31
合作期间：2026-11 起
注册资本（表单）：32.86 亿元
注册资本（执照）：328600 万元
营业执照附件：法定代表人显示「李某某」；信用代码第 9 位起模糊不可辨
```

## 第 0 步：前置硬校验

| 校验 | 结果 | 说明 |
| :-- | :-- | :-- |
| 信用代码长度与字符集 | **fail** | 含非法字符或长度不符时直接退回 |
| 信用代码校验位（GB 32100-2015） | **fail** | 重算第 18 位与填写值不符，说明存在录入错误或伪造 |
| 主体存续性 R10 | **fail** | 经营状态为注销，不得入库 |

硬校验已产生 `fail`，后续字段仍需逐项判定以便一次性退回，但不影响整体结论。

## 逐字段判定

| 规则 | 表单值 | 证据值 | 结果 | 说明 |
| :-- | :-- | :-- | :-- | :-- |
| R1 供应商类型 | 费用类 | 应为成本类 | **fail** | 业务部门应为成本类 |
| R3 跨境业务 | 否 | — | **uncertain** | 境外标准与国际业务部门清单未配置 |
| R5 主体名称 | 一致 | 一致 | **pass** | 逐字一致 |
| R5 法定代表人 | 张某某 | 李某某 | **fail** | 与营业执照不一致 |
| R5 统一社会信用代码 | …XX9 | 第 9 位起不可辨 | **uncertain** | 无法逐字符确认，不得判 pass（校验位已单独 fail） |
| R5 注册资本 | 32.86 亿元 | 328600 万元 | **pass** | 换算后数值等价，写法差异不算不一致 |
| R6 注册地址 | 省略市级 | 完整 | **pass** | 省略方向不限，共有层级一致 |
| R11 营业期限 | 至 2025-12-31 | 合作期 2026-11 起 | **fail** | 期限早于合作开始 |
| R12 建档一致性 | 未建档 | 走新建流程 | **pass** | 一致 |

## 输出 JSON

```json
{
  "case_id": "OA-DEMO-0001",
  "overall_result": "建议打回",
  "confidence": "low",
  "checks": [
    {
      "check_id": "uscc_checksum",
      "result": "fail",
      "field": "统一社会信用代码",
      "form_value": "91330100MA2XXXXXX9",
      "evidence_value": "校验位重算结果不符",
      "evidence_source": "GB 32100-2015 本地校验",
      "reason": "校验位不匹配，存在录入错误或伪造",
      "requires_human_review": false
    },
    {
      "check_id": "entity_status",
      "result": "fail",
      "field": "经营状态",
      "form_value": "注销",
      "evidence_value": "注销",
      "evidence_source": "第三方工商数据",
      "reason": "主体已注销，不得入库（R10）",
      "requires_human_review": false
    },
    {
      "check_id": "business_license_validity",
      "result": "fail",
      "field": "营业期限",
      "form_value": "2015-06-01 至 2025-12-31",
      "evidence_value": "合作期自 2026-11 起",
      "evidence_source": "表单期限字段",
      "reason": "营业期限早于合作开始时间（R11）",
      "requires_human_review": false
    },
    {
      "check_id": "supplier_type_by_department",
      "result": "fail",
      "field": "供应商类型",
      "form_value": "费用类",
      "evidence_value": "成本类",
      "evidence_source": "部门口径 R1",
      "reason": "申请部门为业务部门，供应商类型应为成本类",
      "requires_human_review": false
    },
    {
      "check_id": "business_license_legal_representative",
      "result": "fail",
      "field": "法定代表人",
      "form_value": "张某某",
      "evidence_value": "李某某",
      "evidence_source": "营业执照",
      "reason": "表单与营业执照法定代表人不一致",
      "requires_human_review": false
    },
    {
      "check_id": "registered_capital",
      "result": "pass",
      "field": "注册资本",
      "form_value": "32.86 亿元",
      "evidence_value": "328600 万元",
      "evidence_source": "营业执照",
      "reason": "换算后数值等价，写法差异不构成不一致",
      "requires_human_review": false
    },
    {
      "check_id": "unified_social_credit_code",
      "result": "uncertain",
      "field": "统一社会信用代码（逐字符）",
      "form_value": "91330100MA2XXXXXX9",
      "evidence_value": "附件第 9 位起不可辨认",
      "evidence_source": "营业执照",
      "reason": "无法逐字符确认，按规则不得判 pass",
      "requires_human_review": true
    },
    {
      "check_id": "cross_border_business",
      "result": "uncertain",
      "field": "是否跨境业务",
      "form_value": "否",
      "evidence_value": "未提供",
      "evidence_source": "规则未配置",
      "reason": "境外公司判定标准与国际业务部门清单尚未确认",
      "requires_human_review": true
    }
  ],
  "issues": [
    "统一社会信用代码校验位不符",
    "经营状态为注销，不得入库（R10）",
    "营业期限早于合作开始时间（R11）",
    "供应商类型与部门口径不符（R1）",
    "法定代表人与营业执照不一致（R5）"
  ],
  "approval_comment": "主体经营状态为注销且营业期限早于合作开始时间，不予入库；统一社会信用代码校验位不符、法定代表人与营业执照不一致、供应商类型应为成本类。信用代码逐字符与跨境业务需人工核验。",
  "model_notes": [
    "已读取来源：营业执照附件、第三方工商数据、OA 表单字段",
    "未能确认：营业执照附件第 9 位起字符不可辨认",
    "未查询：失信与被执行名单（超出本技能范围）"
  ]
}
```

## 侧边栏呈现

```
AI 审查：建议打回

[红] 经营状态
表单/工商：注销
要求：存续或在业

[红] 营业期限
执照：至 2025-12-31
合作期：2026-11 起

[红] 统一社会信用代码
校验位不符（GB 32100-2015）

[红] 供应商类型
申请部门：某业务部
当前值：费用类
预期值：成本类

[红] 法定代表人
表单：张某某
营业执照：李某某

[绿] 注册资本
32.86 亿元 = 328600 万元，数值等价

[黄] 统一社会信用代码（逐字符）
附件第 9 位起不可辨认，需人工核验原件

[黄] 跨境业务
境外公司判定标准未配置，需人工核验

[填入审批意见]  [重新审查]
```

## 关键点

1. 有 `fail` 即整体「建议打回」，不因存在 `uncertain` 而降级。
2. 存在任一 `uncertain` 时 `confidence` **必须是 low**——本例有 2 个 uncertain，所以是 low 而不是 high。
3. 校验位失败是确定性事实，判 `fail`；字符不可辨认是不确定性，判 `uncertain`。两者不同层。
4. 注册资本写法不同但数值等价，判 `pass`，不要误杀。
5. 注销主体即使材料齐全也不能通过——这是 R10 存在的理由。
6. `model_notes` 里必须写清读了哪些来源、哪些没读到。
7. 只填入意见，**不触发提交**。



---

# Appendix D - schemas/supplier-review-output.schema.json

Normative output contract, enforced by `scripts/validate-output.ps1`.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://github.com/symbolccc/legal-risk-review/schemas/review-output.schema.json",
  "title": "OA supplier onboarding review output",
  "description": "Output contract for the oa-supplier-review skill only, consumed by the Edge extension sidebar. It is NOT a universal contract: the legal-risk-review skill produces Chinese prose documents (payment-term and risk opinions), which have their own structure checker. Enumerations are normative: an out-of-enum value invalidates the whole result and must be escalated to a human, never auto-corrected.",
  "type": "object",
  "additionalProperties": false,
  "required": ["case_id", "overall_result", "confidence", "checks", "issues", "approval_comment"],
  "properties": {
    "case_id": {
      "type": "string",
      "minLength": 1,
      "description": "OA case number. Must be re-bound per document; never reuse the previous case."
    },
    "overall_result": {
      "enum": ["建议通过", "建议打回", "需人工核验"],
      "description": "Derived from checks by the tiering rules in SKILL.md section 4."
    },
    "confidence": {
      "enum": ["high", "medium", "low"],
      "description": "low whenever any check is uncertain; high requires zero uncertain checks."
    },
    "checks": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["check_id", "result", "field", "reason", "requires_human_review"],
        "properties": {
          "check_id": { "type": "string", "minLength": 1 },
          "result": { "enum": ["pass", "fail", "uncertain", "not_applicable"] },
          "field": { "type": "string", "minLength": 1 },
          "form_value": { "type": ["string", "null"] },
          "evidence_value": { "type": ["string", "null"] },
          "evidence_source": {
            "enum": [
              "营业执照", "银行开户证明", "纳税人证明", "附件",
              "第三方工商数据", "OA表单", "部门口径 R1", "部门口径 R2",
              "规则未配置", "未提供", "GB 32100-2015 本地校验", "其他"
            ]
          },
          "reason": { "type": "string", "minLength": 1 },
          "requires_human_review": { "type": "boolean" }
        }
      }
    },
    "issues": {
      "type": "array",
      "items": { "type": "string", "minLength": 1 }
    },
    "approval_comment": { "type": "string", "minLength": 1 },
    "model_notes": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Must state which sources were read and which could not be read."
    }
  }
}
```