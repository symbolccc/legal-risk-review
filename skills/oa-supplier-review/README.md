# oa-supplier-review

致远 OA 供应商入库审批的自动化审核规则层。

## 触发方式

审供应商入库单、核营业执照或银行证明、判断供应商能否通过、生成审批意见 JSON 时加载。

## 与 legal-risk-review 的分工

| | legal-risk-review | 本 skill |
| :-- | :-- | :-- |
| 审的是 | 要不要给客户账期、我方垫不垫钱 | 能不能让供应商入库、我方给它打款 |
| 输出 | 中文文书 | JSON + 审批意见文本 |

不要互相套用结论口径。

## 按任务取文件

| 任务 | 读什么 |
| :-- | :-- |
| 判断能否通过 | `SKILL.md` §1、§3 → `references/supplier-rules.md` |
| 证据怎么算数 | `references/source-contract.md` |
| 信用代码对不对 | `../../../scripts/validate-uscc.ps1`（必须跑脚本） |
| 输出格式与校验 | `../../../schemas/supplier-review-output.schema.json`、`../../../scripts/validate-output.ps1` |
| 看完整输出长什么样 | `examples/example-supplier-review.md` |

## 依赖

规则阅读零依赖。可执行层为纯 ASCII PowerShell，Windows PowerShell 5.1 与 pwsh 通用。

无法运行脚本时主干仍可用，但信用代码校验位与输出自洽检查会退回模型自查，**应在结论中声明该局限**。
