# 全用量范围的调价审查

现有客户快照只能反映已经观测到的数量。迁移价格版本前，`analyze_prices(baseline, candidate, limit)` 检查整个 `0..limit` 整数域，给出精确差额的最小值、最大值及最早出现的数量。最大差额不大于零，表示在该有界域内候选方案的精确价格从不更高；这不代表任何舍入后、最低消费或其他收费的结论。

两个普通 Plan 必须同币种、指标和单位，可有不同 id/版本、档位边界及 Graduated/Volume 模式。limit 是不超过 30 位的规范非负整数。报告按两个计划所有档位转移切分，最多 2047 段，数量边界均包含。每个 `PriceSpan` 包含 `from_quantity,to_quantity,baseline_total,candidate_total,baseline_step,candidate_step`：

```text
exact_total(q) = total_at_from + step * (q - from_quantity)
delta(q) = candidate_exact_total(q) - baseline_exact_total(q)
```

段内差额为一次函数，最大/最小值必在端点；整量价降价产生的跳变位于段之间，不会被抹平。零用量明确包含；极值相同时选择最小数量。即使相邻档单价相同也保留规范边界切分，因此输出固定且可核验，避免依赖抽样或逐数量遍历。

`PriceAnalysis` 保留两个 `{id,version}` 计划引用、币种/指标/单位、limit、spans，以及 `minimum_delta,minimum_at,maximum_delta,maximum_at`。所有价格是精确十进制字符串，差额可为负。`verify_analysis` 接收可信的两个计划与 limit，检查完整无重叠覆盖、所有规范边界、每段金额和斜率，再检查全域端点极值；曲线检查使用独立的截断区间求和，不调用分析生成器或其前缀递推。

```text
moon run cmd/analyze --target wasm -- examples/stripe/plan.json examples/stripe-volume/plan.json 25
moon run cmd/analyze --target wasm -- examples/stripe/plan.json examples/stripe-volume/plan.json 25 --json
moon run cmd/analyze --target wasm -- examples/stripe/plan.json examples/stripe-volume/plan.json 25 --verify examples/analysis/report.json
```

公开 Stripe 教学规则产生 `[0,5]`、`[6,10]`、`[11,25]` 三段。候选整量价相对渐进价的最小差额是 -7.5，最早在 11 单位；最大差额是 0，最早在零用量。来源为既有价格示例；上限为合成审查参数。

`encode/decode_analysis` 使用 `jieheng.price-analysis.v1`，恰含 `schema,baseline,candidate,currency,metric,unit,limit,spans,minimum_delta,minimum_at,maximum_delta,maximum_at`。引用与分段字段如上，禁止未知字段、重复键、超 1 Mi UTF-16 单元文档；解码仅检查结构，接受归档前必须可信核验。不会据报告自动变更客户合同或推断限额以外的行为。

不支持整包计划、最低消费、舍入后极值、税费、折扣、汇率或时间分摊。价格生效时间表可通过 `select_plan` 选出两个可信版本后再调用此接口；它不自动决定迁移日期。
