# 示例二：供应商入库审批输出

> 单据编号、企业名、代码、人名均为脱敏示意。

## 输入

```
申请部门：某业务部（业务部门）
供应商类型：费用类
是否跨境业务：否
法定代表人：张某某
统一社会信用代码：91330100MA2XXXXXX0
营业执照附件：法定代表人显示「李某某」；信用代码第 9 位起模糊不可辨
```

## 判定

| 规则 | 表单值 | 证据值 | 结果 | 说明 |
| :-- | :-- | :-- | :-- | :-- |
| R1 供应商类型 | 费用类 | 应为成本类 | **fail** | 业务部门应为成本类 |
| R3 跨境业务 | 否 | — | **uncertain** | 「境外公司」标准未配置，无法判定 |
| R5 法定代表人 | 张某某 | 李某某 | **fail** | 与营业执照不一致 |
| R5 统一社会信用代码 | 91330100MA2XXXXXX0 | 第 9 位起不可辨 | **uncertain** | 无法逐字符确认，不得判 pass |
| R6 注册地址 | 省略市级 | 完整 | **pass** | 省/市/区层级省略可接受 |

## 输出 JSON

```json
{
  "case_id": "OA-DEMO-0001",
  "overall_result": "建议打回",
  "confidence": "high",
  "checks": [
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
      "check_id": "unified_social_credit_code",
      "result": "uncertain",
      "field": "统一社会信用代码",
      "form_value": "91330100MA2XXXXXX0",
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
      "reason": "境外公司判定标准尚未确认",
      "requires_human_review": true
    }
  ],
  "issues": [
    "供应商类型与部门口径不符（R1）",
    "法定代表人与营业执照不一致（R5）"
  ],
  "approval_comment": "供应商类型应为成本类；法定代表人与营业执照不一致；统一社会信用代码与跨境业务需人工核验。",
  "model_notes": []
}
```

## 侧边栏呈现

```
AI 审查：建议打回

[红] 供应商类型
申请部门：某业务部
当前值：费用类
预期值：成本类

[红] 法定代表人
表单：张某某
营业执照：李某某

[黄] 统一社会信用代码
附件第 9 位起不可辨认，需人工核验原件

[黄] 跨境业务
境外公司判定标准未配置，需人工核验

[填入审批意见]  [重新审查]
```

## 关键点

1. 有 fail 即整体「建议打回」，不因存在 uncertain 而降级为需人工核验。
2. uncertain 一律 `requires_human_review: true`。
3. 模糊不等于「大概一致」，不可辨认就是 uncertain。
4. 只填入意见，**不触发提交**。
