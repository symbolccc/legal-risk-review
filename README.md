# 法务风控审核技能集

两个可独立安装的 Agent Skill，共用一套可执行校验层与回归评测。

| 技能 | 审什么 | 资金方向 | 输出形态 |
| :-- | :-- | :-- | :-- |
| [`legal-risk-review`](skills/legal-risk-review/SKILL.md) | 要不要给客户账期、我方垫不垫钱 | 客户 → 我方 | 中文文书 |
| [`oa-supplier-review`](skills/oa-supplier-review/SKILL.md) | 能不能让供应商入库打款 | 我方 → 供应商 | JSON + 审批意见 |

两者方向相反、结论口径不同，**不要互相套用**。需要哪装哪个，也可以都装。

**不构成法律意见。** 输出为初审口径与风险提示，须经有资质人员复核。

## 为什么拆成两个

早期版本把供应商入库规则、OA 程序的 JSON 输出契约、工程实现约束（API Key 位置、内存处理、不自动提交）全都塞进一个「法务审核」技能里。后果是：

- 一个只写垫款意见的人，被要求遵守 Edge 扩展的约束
- 输出契约写着「适用于所有审核」，但文书类输出根本不是那个 JSON 形状
- 评测集 6 个用例全是供应商场景，真正的日常业务零覆盖

拆开之后，各自的契约、评测和约束都只对相应场景生效。

## 结构

```
legal-risk-review/                  (仓库名沿用历史)
├── skills/
│   ├── legal-risk-review/          技能一：文书类审核
│   └── oa-supplier-review/         技能二：供应商入库自动化
├── schemas/            供应商 JSON 输出契约（枚举即规范）
├── scripts/            可执行层，两个技能共用
├── tests/              校验位单测
├── evals/
│   ├── supplier/       6 个 golden
│   ├── legal/          2 个 golden
│   └── invalid/        6 个负例（JSON + 文书）
├── dist/               每个技能各自的单文件分享版
└── .github/workflows/ci.yml
```

## 安装

### 只装文书审核技能

```bash
git clone https://github.com/symbolccc/legal-risk-review.git /tmp/lrr
cp -r /tmp/lrr/skills/legal-risk-review ~/.claude/skills/
```

### 只装供应商入库技能

```bash
cp -r /tmp/lrr/skills/oa-supplier-review ~/.claude/skills/
```

### 其他 Agent

在 `AGENTS.md` 指向对应 `SKILL.md`；纯网页产品可直接粘贴 `dist/` 里的单文件版。

## 可执行层

规则里凡是**有唯一正确答案**的部分，都不该交给模型：

| 脚本 | 拦什么 |
| :-- | :-- |
| `validate-uscc.ps1` | 信用代码格式与 GB 32100-2015 校验位——能抓出「表单与附件填了同一个错码」 |
| `validate-output.ps1` | JSON 契约合规 + 结论与 checks 自洽（如有 uncertain 却标 high） |
| `validate-opinion.ps1` | 文书段落完整、结论三要素、**有证据缺口却声称无异议** |
| `run-evals.ps1` | 回归评测，含**用例数量下限断言** |
| `scan-secrets.ps1` | 凭据与隐私扫描 |

零外部依赖，Windows PowerShell 5.1 与 pwsh 7 通用。

```powershell
./tests/test-uscc.ps1
./scripts/run-evals.ps1
./scripts/scan-secrets.ps1
./scripts/build-dist.ps1
```

## 两个真实教训

**一、校验器需要被测试。** `evals/invalid/` 存放故意做坏的结果，要求校验器必须拦下且理由正确。它首次运行就暴露了校验器把违规静默丢弃的缺陷——只有正例的话，一个什么都不检查的「校验器」会永远显示绿色。

**二、评测文件必须确认真的进了仓库。** 一条裸 `cases/` 的 `.gitignore` 规则吞掉了整个 golden 目录，CI 照常全绿，实际只跑了负例。现在有三重防护：`.gitignore` 锚定为 `/cases/`、`run-evals.ps1` 断言每个目录的用例数量下限、CI 检查 `git ls-files` 的跟踪数量。

## 换组织要校准什么

规则骨架通用，**数值与归类不可照搬**。

| 技能 | 位置 | 要改什么 |
| :-- | :-- | :-- |
| 两者 | `SKILL.md` §0 | 部门归类名单、组织架构层级 |
| legal | §2.2 §2.3 §2.4 | 账期固定档、GMV 时效、额度下浮比例 |
| legal | `assets/approval-replies.md` | 话术与退回流程习惯 |
| supplier | `references/supplier-rules.md` | R1–R12 本身、七项未确认是否已确认 |
| supplier | `references/source-contract.md` | 第三方工商数据用哪家 |
| supplier | `SKILL.md` §5 | 你方审批系统的实际页面结构 |

改完跑 `./scripts/run-evals.ps1`，golden 与负例必须全绿。

## License

MIT
