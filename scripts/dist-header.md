# {{SKILL}} — 单文件分享版

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
