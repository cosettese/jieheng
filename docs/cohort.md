# 批量调价影响

客户成功或定价团队可将同一指标的客户周期快照分别应用到两个计划，得到可逐项核验的调价报告。输入必须已汇总；库不会猜测哪些记录需要合并。

```text
moon run cmd/cohort --target wasm -- examples/stripe/plan.json examples/stripe-volume/plan.json examples/cohort/usages.json 2 half-even
moon run cmd/cohort --target wasm -- examples/stripe/plan.json examples/stripe-volume/plan.json examples/cohort/usages.json 2 half-even --json
moon run cmd/cohort --target wasm -- examples/stripe/plan.json examples/stripe-volume/plan.json examples/cohort/usages.json 2 half-even --verify examples/cohort/report.json
```

这三个合成客户使用 Stripe 公开教学案例的真实价格规则，数量为 6、20、25。渐进价合计 326.5，整量价合计 309，精确及结算差额均为 -17.5。这里没有真实客户数据。

API 为 `compare_cohort` / `verify_cohort`，接收两个可信 `Plan`、`ArrayView[Usage]` 和显式精度/舍入规则。`CohortComparison.rows` 按输入顺序保留完整 `Comparison`；其余六个金额字段为双方精确合计、双方结算合计、精确差额和结算差额。合计使用规范十进制字符串，差额始终为候选减基线。

每个客户周期分别舍入，然后相加；绝不将所有客户合并后舍入。输入限制 1–256 个快照。同一客户和周期只能出现一次，两个计划必须具有相同指标、单位和货币；不同周期允许共存。任何失败均拒绝整个请求，不跳过坏项。诊断带行索引。不要将一个客户周期拆成多个独立快照以绕过限制：阶梯和结算结果会改变。

交换 API：`encode_cohort_usage` / `decode_cohort_usage` 使用 `jieheng.cohort-usage.v1`，仅含 `schema`、`usages`（完整 UsageV1 数组）。`encode_cohort` / `decode_cohort` 使用 `jieheng.cohort-comparison.v1`，仅含 `schema`、`rows`（完整 ComparisonV1 数组）及上述六个字段。未知字段、重复键和超过 1 Mi UTF-16 单元的文档会被拒绝；编码也检查此上限。大批次应分组生成报告，不能静默截断。

解码只检查结构；接受归档前必须以可信计划、用量和规则调用 `verify_cohort`，防止删行、换序、重复行、篡改金额或总计。核验不会重新调用计价器。
