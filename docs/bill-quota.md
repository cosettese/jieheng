# 保留固定用量项的整单预算配额

`quote_bill_quota(input,scale~,rounding~)` 在 0–63 个固定用量项之外，为一个可变指标求安全配额。`BillQuotaInput { fixed,variable,request }` 中 fixed 是完整 BillItem 数组，其数量不会被改写；variable 是不带用量的完整 Tariff，可为含最低消费政策的普通计划或整包计划。request 复用 BudgetRequest，明确客户、周期、总预算和可变数量上限。固定项与可变项必须同客户、周期、币种且指标互不重复。

先逐项结算固定项，用总预算扣除它们实际的结算金额，再搜索可变项。每个可变数量都应用其完整最低消费/整包规则及舍入政策。目标是最大 q，使 0..q 的每个整数数量对应的**完整账单**均不超总预算；整量价不能跳过中间的超支区间。零用量豁免只作用于可变项自身，固定项不会因此取消。

若固定项已经超支，或零可变用量时其最低消费仍让整单超支，返回 `infeasible`，不伪造可行的零配额。limit 为零时只检验零点。达到 limit 不代表域外安全。

输出 `BillQuota { request,variable_metric,bill,first_unaffordable }`，bill 按固定项原顺序加末尾可变项保留全部凭证。未达到 limit 时必须提供 q+1 的完整超预算账单；达到时必须为 null。`verify_bill_quota` 接收完整可信 input，独立核验所有固定和可变凭证、指标及请求绑定、区间安全和下一单位超支；使用已验证固定金额和独立舍入阈值，不调用求解或账单生成器。对整量价逐档检查正数量最坏端点并应用最低消费；渐进价含最低消费及整包价的前缀安全由单调性和验证后的端点保证。

```text
moon run cmd/bill-quota --target wasm -- examples/bill-quota/input.json 2 half-even
moon run cmd/bill-quota --target wasm -- examples/bill-quota/input.json 2 half-even --json
moon run cmd/bill-quota --target wasm -- examples/bill-quota/input.json 2 half-even --verify examples/bill-quota/report.json
```

示例固定 60000 GB-Mo，使用既有 S3 真实价格快照及假设最低消费 1500；可变消息每 1000 条 0.85，总预算 1503，上限 10000。安全消息配额为 3000，整单 1502.55；3001 条须第四包，整单 1503.40 超预算。预算、客户、用量、最低消费和消息价格均为演示参数，并非供应商真实合同。

`encode/decode_bill_quota_input` 使用 `jieheng.bill-quota-input.v1`，恰含 `schema,fixed,variable,request`。fixed 为完整 BillInputV1，或明确 null 表示无固定项；variable 使用目录的 Tariff 对象格式（metered: kind/plan/minimum/zero_usage；package: kind/plan）；request 为完整 BudgetRequestV1。不存在被忽略的“变量初始数量”。`encode/decode_bill_quota` 使用 `jieheng.bill-quota.v1`，恰含 `schema,request,variable_metric,bill,first_unaffordable`；后两者为完整 BillV1 或 null。未知字段、重复键、模型不支持的政策以及超 1 Mi UTF-16 单元文档拒绝。解码报告只检查结构，接受前须可信核验。

数值上限沿用现有规则。整单及必要的超预算凭证必须能由现有 60 位金额格式表示；若见证金额超限则清晰拒绝该输入，不丢弃见证。输入编解码可保存没有可行配额的合同，求解时再返回 infeasible。固定项总数加变量最多 64。

这不是多变量资源分配优化：其他指标数量保持不变；不支持税费、折扣、整单二次舍入、跨期额度、自动限流或支付。旧 quote_budget / quote_quota 的语义与格式不变。
