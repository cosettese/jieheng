# 范围内每个数量都安全的预算配额

`quote_budget` 回答最大的可负担数量。整量计价可能在降价档之后重新变得可负担，不能直接把那个最大解当成消费配额。`quote_quota(plan, request, scale~, rounding~)` 回答另一个问题：**寻找最大 q，使从零到 q 的每个整数数量的最终结算金额都不超过预算**，且 q 不超过显式 limit。

输入复用 `BudgetRequest { customer,period,budget,limit }`；币种取自可信 Plan，数量/预算上限、精度、四种舍入规则与预算工作流一致。返回 `QuotaQuote { request,evidence,first_unaffordable }`。evidence 保存安全配额端点的完整凭证；若 q < limit，first_unaffordable 必须保存 q+1 的完整超预算凭证；达到 limit 时必须为 null，不接受域外证据。

生成器按档位的连续单调段搜索，遇到首个超预算数量就停止，不跨过超支区间寻找后续折扣。独立 `verify_quota` 接收可信计划、完整请求和政策，检查端点凭证、整量价所有先前档位最坏端点、紧邻超预算证据和 limit 语义；不重新运行生成器、分段构造或二分。渐进价因边际单价非负，其可行端点已能证明整个前缀。

```text
moon run cmd/quota --target wasm -- examples/s3/plan.json examples/budget/request.json 2 half-even
moon run cmd/quota --target wasm -- examples/s3/plan.json examples/budget/request.json 2 half-even --verify examples/quota/s3-quote.json
moon run cmd/quota --target wasm -- examples/quota/hole-plan.json examples/quota/hole-request.json 2 half-even
moon run cmd/budget --target wasm -- examples/quota/hole-plan.json examples/quota/hole-request.json 2 half-even
```

真实 S3 价格快照配合假设 USD 1500 预算，q=65854、端点结算 1499.99，下一个数量 65855 结算 1500.01。价格来源见既有 S3 文档；预算和数量是合成规划参数。

合成反例中，前 5 单位每单位 10、6–10 单位每单位 1、之后每单位 20。预算 12 时最大可行数量是 10，但 2–5 单位超支，所以安全配额是 1，首个超预算见证是 2 单位、金额 20.00。此例验证了两种 API 的实际语义差异。

`encode/decode_quota` 使用独立 `jieheng.quota-quote.v1`，恰含 `schema,request,evidence,first_unaffordable`；request 为完整 BudgetRequestV1，其余是完整 EvidenceV1 或明确的 null。拒绝缺失字段、重复键、未知字段和超 1 Mi UTF-16 单元文档。解码只检查结构，收到 null 不能据此相信没有超支点，必须可信核验。

配额描述的是同一周期内**累计数量对应的一次最终报价**，不表示多次独立下单的金额相加也安全，不包含原始事件计量、并发扣减、实时限流或持续监控。当前不包含最低消费、整包计价、税费、折扣、多指标或时间版本切换。达到 limit 只证明给定范围内安全，不代表域外也安全。低于结算单位的预算仍按精确金额比较，零预算可能因舍入允许正数量。
