# legal-risk-review

广告 / 营销公司法务风控审核口径的 Agent Skill。

## 触发方式

描述命中以下任一场景即加载：出风控意见、垫款意见、审结算单、核供应商材料、写审批话术、判断单据能否通过、推算账期与垫款敞口。

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
| 审供应商入库 | §1、§4 | `references/supplier-rules.md`、`references/source-contract.md` |
| 审返点/结算单 | §1 | `references/settlement-review.md`、`assets/approval-replies.md` |
| 合同用印归档 | §1 | `references/contract-seal.md` |
| 判断是否升级 | §5 | `references/source-contract.md` |

## 依赖

无。纯 Markdown，不调用脚本、不需要 API Key，任何能读文件的 Agent 均可使用。
