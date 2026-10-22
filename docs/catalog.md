# 版本化多指标价目目录

`Catalog` 把一个产品必需的全部指标及完整收费规则放进按日期选择的目录，支持普通计划的最低消费和整包计划。`Tariff` 为 `MeteredTariff(Plan, minimum, zero_usage)` 或 `PackageTariff(PackagePlan)`，不含可被忽略的用量。`CatalogEntry` 包含 `starts_on,ends_before,tariff`；日期沿用严格公历规则，起日包含、止日不包含。

`compile_catalog` 接收 1–512 个规则，最多 64 个指标、每指标 128 版本。同一指标的版本必须按起日递增、不重叠、id/单位不变、版本唯一；可跨阶梯/整包模型迁移。不同指标可交错声明，全部使用一个币种。仅每指标最后版本可无结束日；空档允许声明，使用空档日期会明确报错。目录脱离输入数组。

`rate_catalog(catalog,on,usages,scale~,rounding~)` 要求 1–64 个同客户/周期的用量，恰好覆盖目录全部指标。缺失、额外或重复指标均拒绝；未使用也需显式零用量。输出 `CatalogBill {on,bill}`，账单按指标在目录首次出现的顺序排列，输入用量换序不会改变输出。它不解析 period 标签，不切分跨版本用量，也不按天分摊。`verify_catalog` 以可信目录、日期、完整用量和规则重新绑定所需版本，再独立核验混合账单。

```text
moon run cmd/catalog --target wasm -- examples/catalog/catalog.json 2026-10-22 examples/catalog/usages.json 2 half-even
moon run cmd/catalog --target wasm -- examples/catalog/catalog.json 2026-10-22 examples/catalog/usages.json 2 half-even --json
moon run cmd/catalog --target wasm -- examples/catalog/catalog.json 2026-10-22 examples/catalog/usages.json 2 half-even --verify examples/catalog/bill.json
```

案例沿用真实 S3 价格快照、假设存储最低消费及合成消息包：10 月总计 1502.55；消息包在假设的 11 月 1 日由 0.85 调为 1，其他输入保持相同，总计 1503.00。消息价格、版本日期、客户、用量及最低消费均非供应商实际合同。S3 价格来源和 effectiveDate 仍为既有快照，没有新编造历史价格。

格式 `jieheng.catalog.v1` 恰含 `schema,entries`，每项恰含 `starts_on,ends_before,tariff`。tariff 的 metered 对象恰含 `kind,plan,minimum,zero_usage`，package 对象恰含 `kind,plan`；计划为对应完整 V1 对象，不支持字段会拒绝。`jieheng.usage-bundle.v1` 恰含 `schema,usages`，数组为完整 UsageV1。`jieheng.catalog-bill.v1` 恰含 `schema,on,bill`，bill 为完整 BillV1。对应 `encode/decode_catalog`、`encode/decode_usage_bundle`、`encode/decode_catalog_bill`。重复键、未知字段和超 1 Mi UTF-16 单元文档均拒绝；归档账单解码后仍需可信核验。

旧 `Schedule` 与所有旧 JSON 不变。此目录没有按客户分组的订阅管理、自动迁移、发票发送、税费或收款；调用方保存可信目录快照并明确选择日期。
