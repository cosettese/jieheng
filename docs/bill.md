# 阶梯与整包组合账单

`rate_bill(items, scale~, rounding~)` 接收 1–64 个显式模型输入，返回 `Bill`。`BillItem::Metered(ChargeInput)` 保留渐进/整量计划及最低消费；`BillItem::Packaged(PackagePlan, Usage)` 保留整包容量语义。一个指标跨所有模型只能出现一次，所有项必须同客户、同周期、同币种。每项独立计价、补差（仅 metered）、结算，再精确相加 minor units，不进行整单第二次舍入。

`Bill.items` 按输入顺序保留 `MeteredCharge(Charge)` 或 `PackageCharge(PackageEvidence)`，整包未用容量不会被压成普通单位明细。`Bill.totals` 包含 `usage_total,top_up,total,scale,rounding,minor_units,amount,delta`；包费计入 usage_total，补差仅来自 metered 项，`delta = amount - total`。`verify_bill` 必须接收可信完整输入清单，独立核验每项模型及凭证、身份、顺序、完整性和所有合计。模型替换、重复/丢失项或伪造总计均拒绝。

```text
moon run cmd/bill --target wasm -- examples/bill/input.json 2 half-even
moon run cmd/bill --target wasm -- examples/bill/input.json 2 half-even --json
moon run cmd/bill --target wasm -- examples/bill/input.json 2 half-even --verify examples/bill/bill.json
```

案例组合既有 S3 真实价格快照和合成消息包：存储原始金额 1371.20、假设最低消费补差 128.80，消息 2501 条需三包共 2.55，合计 USD 1502.55。客户、用量、存储最低消费和消息包价均是演示参数；不是云供应商或短信供应商的完整实际账单。来源见 `SOURCES.md`、`examples/s3/README.md`。

`encode/decode_bill_input` 使用 `jieheng.bill-input.v1`，恰含 `schema,items`。metered 项恰含 `kind:"metered",plan,usage,minimum,zero_usage`；package 项恰含 `kind:"package",plan,usage`。计划和用量均为各自完整 V1 对象。向 package 项添加最低消费等不支持字段会拒绝，不能被忽略。

`encode/decode_bill` 使用 `jieheng.bill.v1`，恰含 `schema,customer,period,currency,items,totals`；每项恰含 `kind,evidence`，凭证对应完整 ChargeV1 或 PackageEvidenceV1。totals 恰含上述八个字段。数字字符串、重复键/未知字段拒绝、1 Mi UTF-16 单元文档上限和 60 位金额合计上限与现有工作流一致。解码不代替可信核验。

原 `Invoice`、`ChargeInput` 及其 JSON 不变，纯 metered 用户无需迁移。新 Bill 不支持税费、折扣、整单舍入、包最低消费或包额度结转；包计划尚不能直接放入旧 `Schedule`、预算接口。
