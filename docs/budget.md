# 预算内最大用量

容量规划或采购时，需要反求一个明确预算能负担多少整数用量。`quote_budget(plan, request, scale~, rounding~)` 接收普通渐进/整量 `Plan` 和 `BudgetRequest { customer, period, budget, limit }`，返回 `BudgetQuote { request, evidence }`。用量在完整凭证 `evidence.calculation.usage.quantity` 中，目标是 **结算金额 <= budget 且 quantity <= limit 的最大整数用量**。

预算是同币种非负精确字符串，最多 60 位整数和 18 位小数；上限是不超过 30 位的规范非负整数，允许零。上限必须显式提供；免费档或免费尾档可能让任何用量可行，不能猜测无穷解。预算可以比结算精度更细，比较仍精确，例如两位结算时 0.019 的预算只足以支付到 0.01。预算针对最终结算金额，所以某些精确小计大于预算的用量仍可能因舍入而可行。

渐进价各边际单价非负，采用单调二分。整量价跨降价档可能下降，算法逐档求最大解，再选全局最大。**整量模式下，并非所有小于返回值的用量都可负担**，因此结果不能直接充当“从零开始任何用量都安全”的消费配额。例如前 5 单位每单位 10、6–10 单位每单位 1，预算 12 时，1 单位和 6–10 单位可行，2–5 单位不可行。

`verify_budget` 必须接收可信计划、请求和结算规则。它独立核验明细与舍入，再用舍入阈值证明最大性：渐进价检查多买一个单位，整量价检查每个更大区间的最便宜起点；不调用求解器或结算生成函数。金额正确但用量并非最大的归档报价同样会被拒绝。固定输入输出确定，不依赖时钟、网络或私有服务。

```text
moon run cmd/budget --target wasm -- examples/s3/plan.json examples/budget/request.json 2 half-even
moon run cmd/budget --target wasm -- examples/s3/plan.json examples/budget/request.json 2 half-even --json
moon run cmd/budget --target wasm -- examples/s3/plan.json examples/budget/request.json 2 half-even --verify examples/budget/quote.json
```

例子使用既有真实 S3 价格快照、假设 USD 1500 预算和 100000 GB-Mo 的搜索上限。最大为 65854 GB-Mo，精确小计 1499.988，结算 1499.99；65855 的精确小计 1500.01，超预算。价格来源与单位见 `examples/s3/README.md`，预算、客户、月份和上限为合成规划参数，不是实际账单或云端限额设置。

`encode/decode_budget_request`：`jieheng.budget-request.v1` 恰含 `schema,customer,period,budget,limit`。`encode/decode_budget`：`jieheng.budget-quote.v1` 恰含 `schema,request,evidence`，后两者是完整请求与 EvidenceV1。原请求字段保留，包括预算末尾小数零；未知字段、重复键、超限数值或超过 1 Mi UTF-16 单元的文档拒绝。报价解码只校验结构，接受前必须可信核验。

当前不支持整包计划、最低消费、多指标组合、税费、折扣、汇率、跨期额度或自动限流。计划中隐含之外的收费不能加入预算请求后被忽略；需要完整支持后才能估算。`limit` 表示搜索范围，结果等于它时不意味着提高上限后仍无可行用量。

需要“范围内每个用量都不超预算”的安全配额时，使用独立的 [quote_quota 工作流](quota.md)，不要将整量价最大可行解当作前缀安全保证。
