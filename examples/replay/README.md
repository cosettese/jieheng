# 完整客户账单回放

输入是三个假设客户在同一周期的完整存储与消息用量。旧目录为 examples/catalog/catalog.json，新目录为 examples/migration/candidate.json；均使用 2026-10-22 这一明确计价日期。S3 单价来源沿用已记录的公开快照，最低消费、消息价、生效日期、客户和用量是示例假设，不能当作供应商账单。

~~~text
moon run cmd/replay --target wasm -- examples/catalog/catalog.json examples/migration/candidate.json examples/replay/cases.json 2 half-even
moon run cmd/replay --target wasm -- examples/catalog/catalog.json examples/migration/candidate.json examples/replay/cases.json 2 half-even --verify examples/replay/report.json --policy examples/replay/policy.json
~~~

| 客户 | 旧结算 USD | 新结算 USD | 差额 |
| --- | --- | --- | --- |
| small | 1502.55 | 1402.85 | -99.70 |
| bulk | 2350.00 | 2350.00 | 0 |
| large | 1813.75 | 1814.05 | +0.30 |
| 合计 | 5666.30 | 5566.90 | -99.40 |

总额下降并不表示每个客户都没有涨价。policy.json 允许每个客户周期增加最多 0.30 USD 且不超过旧金额的 1%，因此通过。换为 strict-policy.json 后，large 的 0.30 超过 0.25 上限，命令失败且 stdout 为空；诊断指出客户、周期和日期。完整报告为 report.json。
