# 显式最低消费

合同有最低消费时，仅有分档小计不足以解释账单。`rate_charge` 在原始用量计算之外列出补差，并对最终应计金额结算一次：

```text
effective_minimum = 0  if quantity == 0 and zero_usage == Waive
                    minimum  otherwise
top_up = max(0, effective_minimum - calculation.total)
total = calculation.total + top_up
settlement = round(total, scale, rounding)
```

`minimum` 与单价相同，最多 30 位整数和 18 位小数，必须是非负十进制字符串，不能用已舍入的用量金额计算补差。调用方必须指定 `zero_usage=Charge` 或 `Waive`：前者零用量也收最低消费，后者只对零用量豁免；非零用量但免费档金额为零时仍适用最低消费。最低消费是舍入前的合同下限，结算后可能略低于该值，例如 0.005 按两位 HalfEven 结算为 0.00。需要保证结算后的下限时应选取可由结算精度表示的合同金额。

`Charge` 保留原始 `Calculation`，增加规范化的 `minimum`、`zero_usage`、`top_up`、`total` 和最终 `settlement`。`verify_charge` 接受同样的可信计划、用量、最低消费、零用量策略和结算规则，独立检查分档、补差守恒、下限约束和舍入区间；不调用 `rate_charge`。旧 `rate` / `EvidenceV1` 行为及规范 JSON 字节不变。

以下以真实 S3 价格快照和合成 60000 GB-Mo 用量展示每周期 USD 1500 的假设合同最低消费。该最低消费是本项目设计的演示参数，并非 AWS 实际政策。原始金额 1371.2，补差 128.8，最终 1500.00。

```text
moon run cmd/charge --target wasm -- examples/s3/plan.json examples/s3/usage.json 1500 charge 2 half-even
moon run cmd/charge --target wasm -- examples/s3/plan.json examples/s3/usage.json 1500 charge 2 half-even --json
moon run cmd/charge --target wasm -- examples/s3/plan.json examples/s3/usage.json 1500 charge 2 half-even --verify examples/minimum/charge.json
```

`encode_charge` / `decode_charge` 使用 `jieheng.charge.v1`，字段恰为 `schema`、`calculation`（同 EvidenceV1 的完整计算记录）、`minimum`、`zero_usage`（`charge` / `waive`）、`top_up`、`total`、`settlement`。结构解码不代替可信核验；未知字段、重复键、错误枚举或超过 1 Mi UTF-16 单元的 JSON 会被拒绝。

不支持按天比例分摊、最低消费跨周期结转、预付款抵扣、税费、折扣、阶梯固定费或支付平台的最低扣款阈值。周期仍是标签，由调用方决定合同如何应用。
