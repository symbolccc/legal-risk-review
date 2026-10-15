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
