# 组合账单解释报告

从已有的 `examples/bill/input.json` 和 `examples/bill/bill.json` 生成，合同与凭证均经过核验。`statement.md` 是完整规范输出；CI 在 Wasm 和 Native 上逐字比对。

```text
moon run cmd/explain --target wasm -- examples/bill/input.json examples/bill/bill.json 2 half-even
```

报告包含 S3 公开单价、假设的最低消费和消息包。价格来源和示例参数的边界与 [组合账单说明](../../docs/bill.md) 一致。没有实际客户数据，也不代表完整云账单。
