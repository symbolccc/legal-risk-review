# legal-risk-review v1.0.0 — 单文件分享版

> 本文件由仓库内 `skills/legal-risk-review/` 下各文件按顺序拼接生成，**内容与源文件逐字一致**。
> 用途：整段粘贴给任何 AI，或放进产品知识库，无需安装目录结构。
> 修改请改源文件后运行 `pwsh scripts/build-dist.ps1` 重新生成，不要单独编辑本文件。
> 仓库：https://github.com/symbolccc/legal-risk-review

## 目录

| 章节 | 内容 | 源文件 |
| :-- | :-- | :-- |
| 主干 | 铁律、流程、分档、升级、Gotchas、自检、边界 | `SKILL.md` |
| 附录 A | 证据来源优先级与缺失处理 | `references/source-contract.md` |
| 附录 B | 供应商入库审批 R1–R9 全表 | `references/supplier-rules.md` |
| 附录 C | 返点与结算单五类审理 | `references/settlement-review.md` |
| 附录 D | 合同用印与归档八段流程 | `references/contract-seal.md` |
| 附录 E | 垫款/风控意见可填模板 | `assets/risk-opinion-template.md` |
| 附录 F | 标准审批话术对照表 | `assets/approval-replies.md` |
| 附录 G | 示例：账期穿透与分档 | `examples/example-payment-term.md` |
| 附录 H | 示例：供应商审批输出与 JSON | `examples/example-supplier-review.md` |
| 附录 I | 输出契约 JSON Schema | `schemas/review-output.schema.json` |

## 可执行层（本文件之外，需 clone 仓库）

规则里凡是**确定性计算**，都不该交给模型。仓库提供零依赖脚本，Windows PowerShell 5.1 与 pwsh 通用：

| 脚本 | 作用 |
| :-- | :-- |
| `scripts/validate-uscc.ps1` | 统一社会信用代码格式与 GB 32100-2015 校验位重算 |
| `scripts/validate-output.ps1` | 校验输出是否符合 Schema **且**结论与 checks 自洽 |
| `scripts/run-evals.ps1` | 跑评测：golden 必须通过，负例必须被拦且理由正确 |
| `tests/test-uscc.ps1` | 校验位单测，含 540 个单字符变异全检 |
| `scripts/scan-secrets.ps1` | 凭据与隐私数据扫描 |

CI（`.github/workflows/ci.yml`）在 ubuntu 与 windows 双平台跑上述全部检查，并强制
`dist/` 与源文件同步、`.ps1` 保持纯 ASCII。

> 单文件版可独立阅读；要真正落地审核，建议 clone 仓库使用脚本层，
> 让「校验位对不对」「结论自不自洽」由代码判定而不是由模型自觉。

---
