# legal-risk-review

广告 / 营销公司法务风控审核口径的 Agent Skill。把一套实际在用的审核规则变成 AI 可执行的指令：

- 撰写客户垫款意见、风控意见
- 审理返点与客户/媒体结算单
- 供应商入库审批（营业执照、银行信息、一般纳税人、跨境口径）
- 合同用印与原件归档流程

**不构成法律意见。** 输出为初审口径与风险提示，须经有资质人员复核。

## 结构

```
legal-risk-review/
├── SKILL 主体  skills/legal-risk-review/SKILL.md
├── references/   按需加载的细则（R0–R12、五类审理、用印、证据契约）
├── assets/       可填模板与标准话术
├── examples/     脱敏示例（含 JSON 输出）
├── schemas/      输出契约 JSON Schema（枚举即规范）
├── scripts/      可执行层：校验位、输出自洽校验、评测、扫描、构建
├── tests/        校验位单测（含 540 个单字符变异全检）
├── evals/cases/  golden 用例：必须通过
├── evals/invalid/ 负例：必须被拦且理由正确
├── dist/         单文件分享版（构建产物，整段粘贴用）
├── .github/workflows/ci.yml   ubuntu + windows 双平台门禁
├── CHANGELOG.md
└── LICENSE       MIT
```

改完源文件后重建分享版：

```bash
pwsh scripts/build-dist.ps1
```

脚本会从 `SKILL.md` 的 `version:` 读取版本号决定输出文件名，并逐个校验源文件是否被逐字复现，任一不一致即退出非零。

采用渐进式披露：`SKILL.md` 是主干，细则放 `references/`，避免一次性撑爆上下文。

## 安装

### Claude Code / 支持 skills 目录的 Agent

```bash
git clone https://github.com/symbolccc/legal-risk-review.git /tmp/lrr
cp -r /tmp/lrr/skills/legal-risk-review ~/.claude/skills/
```

装好后直接说「按 legal-risk-review 的口径给这家客户写垫款意见」。

### Skills CLI

```bash
npx skills add symbolccc/legal-risk-review@legal-risk-review
```

> 仓库刚发布，skills.sh 索引可能尚未收录。若报找不到，请用上面的 clone 方式。

### Codex / 其他读 AGENTS.md 的 Agent

在 `AGENTS.md` 加一行：

```markdown
涉及法务风控、垫款意见、结算单审理、供应商入库审批时，先读 skills/legal-risk-review/SKILL.md 并按其口径执行。
```

### 纯网页聊天产品

把 `SKILL.md` 全文粘进对话开头或产品知识库即可，它不依赖任何工具调用。

## 换公司必须重新校准的 8 处

这套口径的规则骨架通用，**数值与归类不可照搬**。fork 后逐项检查：

| # | 位置 | 要改什么 |
| :-- | :-- | :-- |
| 1 | `SKILL.md` §2.4 | 额度下浮比例（20% / 30%） |
| 2 | `SKILL.md` §2.3 | GMV 时效规则（哪一年看哪一段） |
| 3 | `SKILL.md` §2.2 | 电商固定档天数、穿透各段口径 |
| 4 | `SKILL.md` §4 §5 | 分档阈值与升级触发的组织层级 |
| 5 | `references/supplier-rules.md` | 部门归类名单、R0–R12 规则本身 |
| 6 | `references/supplier-rules.md` | 七项「未确认」是否已在贵司确认 |
| 7 | `references/source-contract.md` | 第三方工商信息用哪家、优先级是否调整 |
| 8 | `assets/approval-replies.md` | 审批话术与退回流程习惯 |

改完后建议用 `examples/` 里的两个示例回归验证一遍输出结构。

## 核心设计：四条反直觉约束

1. **禁止推算** —— AI 自己算出来的数字同样不可信，必须有出处或直接标待补。
2. **未查到 ≠ 不存在** —— 要求显式区分「未提供」「不可辨认」「数据在别的系统」三态。
3. **不确定即人工核验** —— 关键标识符无法逐字符确认时，不允许判通过。
4. **确定性计算交给代码** —— 校验位、枚举合规、结论自洽一律由脚本判定，不靠模型自觉；并用负例集证明校验器真的在工作。

第 3 条会让 AI 显得「不敢下结论」，这是刻意的：法务初审的漏判代价远高于多问一句。

## 适用前提

面向**甲方/代理公司投放业务的垫款与供应商准入**场景。以下情况请谨慎：

- 非广告行业（账期结构、GMV 概念不适用）。
- 需要出具正式法律意见的场合（本技能明确不做）。
- 单人无复核层级的团队（§5 升级路径依赖组织内有上级）。

## 验证与回归

脚本零外部依赖，Windows PowerShell 5.1 与 pwsh 7 通用：

```powershell
./tests/test-uscc.ps1          # 校验位单测
./scripts/run-evals.ps1        # golden 必须通过，负例必须被拦且理由正确
./scripts/scan-secrets.ps1     # 凭据与隐私扫描
./scripts/build-dist.ps1       # 重建 dist/ 并校验源文件逐字复现
```

关键设计是**负例集**：`evals/invalid/` 存放故意做坏的审核结果，校验器必须逐条拦下。
它首次运行就暴露了校验器把违规静默丢弃的缺陷——没有这一半，校验器是不是摆设无人知晓。

## 未包含

- 公司级阈值校准：文中比例与天数标注「待校准」处需你自行确认。
- 端到端系统集成测试：与具体审批系统（OA 等）的对接需在目标环境自行验证。

## License

MIT
