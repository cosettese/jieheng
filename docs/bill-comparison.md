# 相同用量下的整单合同比较

`compare_bills(before,after,scale~,rounding~)` 比较两份完整 `BillItem` 清单，保留双方 `Bill`，按指标名匹配并生成 `BillChange`。双方必须具有相同客户、周期、币种、完整指标集合；每指标的 `Usage` 和计量单位必须完全相同。指标顺序、计划 id/版本、阶梯/整包模型、包容量和最低消费政策允许变化。不会对新增/删除指标、单位换算或用量变化作猜测。

`BillComparison` 含 `baseline,candidate,changes,exact_delta,settled_delta`。changes 依基线顺序保存每项 `metric,unit,baseline_index,candidate_index,usage_delta,top_up_delta,exact_delta,settled_delta`，索引明确映射到原账单。差额总是候选减基线；usage_delta 是用量计价金额差额而非数量变化，top_up_delta 是最低消费补差变化。exact_delta 包含补差；settled_delta 为双方分别结算后的金额之差，不能对差额再舍入。

`verify_bill_comparison` 接收双方可信清单与结算规则，独立核验两张完整账单，再检查指标映射、每项差额及合计。模型或明细篡改、重复/遗漏行、交换索引和伪造汇总均拒绝，不调用比较生成器或账单生成器。

```text
moon run cmd/compare-bills --target wasm -- examples/bill/input.json examples/bill-comparison/candidate.json 2 half-even
moon run cmd/compare-bills --target wasm -- examples/bill/input.json examples/bill-comparison/candidate.json 2 half-even --json
moon run cmd/compare-bills --target wasm -- examples/bill/input.json examples/bill-comparison/candidate.json 2 half-even --verify examples/bill-comparison/report.json
```

示例保留原 S3 真实单价快照，把假设的存储最低消费从 1500 改为 1400，同时把消息的合成整包价改为每条 0.0007，候选清单还交换指标顺序。两份用量完全相同。整单精确差额 -100.7993，结算差额 -100.8；这些合同修改与消息单价均为假设参数，不是供应商调价事实。原始价格/用量来源见 `SOURCES.md`。

`encode/decode_bill_comparison` 使用 `jieheng.bill-comparison.v1`，恰含 `schema` 和上述五个字段；两侧是完整 BillV1，changes 每行恰含上述八个字段。索引为 0–63 的 JSON 整数，其余金额是字符串。未知字段、重复键、超 1 Mi UTF-16 单元的文档拒绝；解码只检查结构，接收归档前必须可信核验。不执行合同变更、付款、税费、汇率或跨用量估算。旧 `compare_plans` 和所有旧格式不变。
