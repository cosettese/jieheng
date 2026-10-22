# 按整包容量收费

短信包、批量席位等合约按整包收取费用，最后不足一包的用量也购买完整容量。`compile_package` 创建独立的 `PackagePlan`，接收 id、版本、指标、单位、币种、正整数 `package_size` 和非负精确小数 `package_price`。数值上限与原价目表一致：容量/用量 30 位整数，包价 30 位整数和 18 位小数。

`rate_packages` 接收已经汇总的 `Usage` 与明确结算规则，精确计算：

```text
packages = ceil(quantity / package_size)
unused_units = packages * package_size - quantity
total = packages * package_price
```

零用量得到零包和零金额。单价是每包价格，不能当成每原始单位价格；不会以浮点数换算。输出 `PackageEvidence` 包含计划身份、原始用量、包容量、包价、包数、未使用容量、精确总计及一次最终结算。`verify_packages` 使用容量守恒和 `0 <= unused_units < package_size` 独立证明包数最小，再核对精确乘积和舍入区间，不调用计价器的向上整除。

```text
moon run cmd/packages --target wasm -- examples/packages/plan.json examples/packages/usage.json 2 half-even
moon run cmd/packages --target wasm -- examples/packages/plan.json examples/packages/usage.json 2 half-even --json
moon run cmd/packages --target wasm -- examples/packages/plan.json examples/packages/usage.json 2 half-even --verify examples/packages/evidence.json
```

此短信演示的全部数据为合成：每 1000 条 USD 0.85，用量 2501 条需 3 包，未使用 499 条，总计 USD 2.55。它不是实际短信供应商报价。真实需求参考 Stripe 的 `transform_usage.divide_by` / `round=up` 公开接口；本实现只定义向上取整的固定容量计价，不复现 Stripe 的计量、订阅或支付协议。项目的真实公开价格工作流仍见 S3/Stripe 既有示例。

`encode/decode_package_plan` 使用 `jieheng.package-plan.v1`，仅含 `schema,id,version,metric,unit,currency,package_size,package_price`。`encode/decode_packages` 使用 `jieheng.package-evidence.v1`，仅含 `schema,plan_id,plan_version,currency,unit,usage,package_size,package_price,packages,unused_units,total,settlement`。数字均用字符串，Usage/Settlement 与既有格式相同。拒绝未知字段、重复键、不兼容 schema 和超过 1 Mi UTF-16 单元的输入；凭证编码也检查大小。解码凭证后必须以可信计划、用量和政策核验。

包计划与旧 PlanV1 分离，旧解码器会拒绝包格式。可以通过独立的 [Bill 接口](bill.md) 与阶梯项组成账单；旧 `Invoice` / `Schedule` 不接受包计划。不支持包内阶梯、免费包数、向下取整、最低购买包数、未用容量结转、最低消费或折扣；这些字段不能被静默忽略。不同用量快照不得擅自分开购买包，否则可能重复向上取整。
