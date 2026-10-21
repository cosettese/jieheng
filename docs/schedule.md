# 按生效日重现历史价格

`compile_schedule` 接受 1–128 个 `EffectivePlan { starts_on, ends_before, plan }`，返回脱离输入数组的 `Schedule`。计划必须具有相同 id、指标、单位和币种；版本标签唯一，价格和计价模式可以变化。区间须按起日严格递增、不重叠；仅最终区间可以无结束日。允许空档，但不会以最近版本填补空档。

日期严格采用公历 `YYYY-MM-DD`，年份 0001–9999，含世纪闰年校验；起日包含，止日不包含。日期没有时区、时刻、节假日或系统时钟含义。`select_plan(schedule, on)` 必须找到唯一覆盖日期的计划，否则报 `uncovered`。原有 `usage.period` 仍是标签，调用方明确选择适用日期。本库不跨版本切分用量，不按天分摊，也不判断合同应采用账期首日还是事件日期。

`rate_scheduled` 生成带 `on` 和完整 `Evidence` 的 `ScheduledEvidence`。`verify_scheduled` 必须接收可信时间表、日期、用量与结算规则，检查日期、版本、分档和舍入，不能只相信归档中的日期。后续修改时间表会改变核验依据，因此调用方应归档原时间表。

```text
moon run cmd/schedule --target wasm -- examples/schedule/schedule.json 2026-10-22 examples/s3/usage.json 2 half-even
moon run cmd/schedule --target wasm -- examples/schedule/schedule.json 2026-10-22 examples/s3/usage.json 2 half-even --json
moon run cmd/schedule --target wasm -- examples/schedule/schedule.json 2026-10-22 examples/s3/usage.json 2 half-even --verify examples/schedule/evidence.json
```

示例使用既有 AWS S3 公开价格快照的 `effectiveDate=2026-10-01`（来源见 `examples/s3/README.md`），合成用量计算为 USD 1371.20。示例仅保存这一版本，不能推断更早价格或未来实际价格；对 2026-09-30 会报无覆盖版本。无结束日是输入的演示约定，不保证供应商以后不调价。

交换格式 `jieheng.schedule.v1` 恰含 `schema`、`entries`；每项恰含 `starts_on`、字符串或 null 的 `ends_before`、完整 PlanV1 `plan`。`jieheng.scheduled-evidence.v1` 恰含 `schema`、`on`、完整 EvidenceV1 `evidence`。对应 `encode/decode_schedule` 和 `encode/decode_scheduled`；未知字段、重复键、无效日期与超出 1 Mi UTF-16 单元的文档拒绝。证据解码只校验结构，接受前需可信核验。旧 PlanV1、EvidenceV1 不变。
