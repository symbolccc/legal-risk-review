# legal-risk-review

广告 / 营销公司法务风控审核口径的 Agent Skill，**输出中文文书**。

审的是「要不要给客户账期、我方垫不垫钱」，资金方向：客户 → 我方。

> 供应商入库审批（我方 → 供应商）请用 `oa-supplier-review`。两者方向相反、
> 输出形态不同，结论口径不可互相套用。

## 触发方式

出风控意见、垫款意见、审返点与结算单、写审批话术、推算账期与垫款敞口、整理用印归档流程。

## 加载顺序（渐进式披露）

| 层级 | 内容 | 何时进上下文 |
| :-- | :-- | :-- |
| L1 | frontmatter 的 name + description | 始终在场 |
| L2 | `SKILL.md` 主干：铁律、流程、分档、Gotchas、自检 | 任务匹配时 |
| L3 | `references/`、`assets/`、`examples/` | 具体任务需要时按需读 |

## 按任务取文件

| 任务 | 主干章节 | 需加载 |
| :-- | :-- | :-- |
| 写垫款/风控意见 | §2 | `assets/risk-opinion-template.md` |
| 审返点/结算单 | §1 | `references/settlement-review.md`、`assets/approval-replies.md` |
| 合同用印归档 | §1 | `references/contract-seal.md` |
| 判断证据算不算数 | §1 | `references/source-contract.md` |
| 判断是否升级 | §5 | `references/source-contract.md` |
| 交付前自查文书 | §10 | `../../../scripts/validate-opinion.ps1` |

## 依赖

**规则阅读零依赖**：纯 Markdown，不需要 API Key，任何能读文件的 Agent 均可直接使用。

**可执行层可选但强烈建议**：`scripts/validate-opinion.ps1` 会检查段落完整性、结论三要素、
穿透算式是否写出，以及「有证据缺口却声称无异议」这类矛盾。无法运行脚本时主干仍可用，
但这些结构缺陷只能靠模型自查，可靠性下降，应在结论中声明该局限。
