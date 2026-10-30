# 全窗口目录迁移审查

给定两个可信目录和日期窗口，audit_catalog_migration 按指标对齐，在双方所有生效边界处分段。报告覆盖整个半开区间 [starts_on, ends_before)，包括没有变化的区间以及双方都没有价格的空窗，不猜测用量或金额影响。

报告按旧目录的指标顺序排列，新增指标追加到末尾；同指标内按日期排列。baseline_entry / candidate_entry 是相应可信目录 entries 数组的原始索引，null 表示该区间没有可选规则。目录快照必须与报告一起保留。

| 变化代码 | 分类与处置 |
| --- | --- |
| metric-added / metric-removed | 阻断；调用方必须明确迁移指标集合 |
| baseline-gap / candidate-gap | 阻断；补齐该日期的价格，不做回退猜测 |
| currency-changed / unit-changed | 阻断；需要显式换算，审查器不转换 |
| identity-changed / version-changed | 复核；追踪身份或版本变动 |
| model-changed / pricing-changed | 复核；模型、档位、单价或包容量变化 |
| minimum-changed / zero-policy-changed | 复核；最低消费或零用量政策变化 |

CatalogChange::is_blocking 区分上述两类。结构兼容不代表可以无条件上线：价格变化仍需业务审批和实际用量回放。同种模型按规范数值比较，十进制尾零不产生变化；模型切换由 model-changed 概括，不虚构不可比的单价差额。

~~~text
moon run cmd/migration --target wasm -- examples/catalog/catalog.json examples/migration/candidate.json 2026-10-01 2026-11-02
moon run cmd/migration --target wasm -- examples/catalog/catalog.json examples/migration/candidate.json 2026-10-01 2026-11-02 --verify examples/migration/report.json
~~~

默认输出完整 JSON，不因发现变化失败。--require-compatible 遇到任何阻断项时以退出码 2 失败；--require-unchanged 遇到任何变化即失败。失败只写 stderr，stdout 为空。原样目录且整个窗口有价格时可以通过两个门禁；即使比较同一目录，窗口内空窗仍会阻断。

verify_catalog_migration 不调用报告生成器：逐段检查连续覆盖、指标顺序、原始条目选择和下一个可能生效边界，拒绝删段、换序、伪造索引、篡改变化以及不必要拆段。语义分类复用同一规则定义，不能将它称作完全独立的第二套业务规则实现。

交换格式 jieheng.catalog-migration.v1 恰含 schema、starts_on、ends_before、spans。每段恰含 metric、starts_on、ends_before、baseline_entry、candidate_entry、changes。变化是上表字符串；未知字段、重复键和未知代码均拒绝。索引为 0..511 或 null；最多 4096 段、每段最多 12 个代码，文档上限仍为 1 Mi UTF-16 单元。解码只检查结构，接受归档前必须使用两个可信目录核验。日期沿用 0001..9999 年公历的现有范围。

样例复用原有 S3 公开单价；把最低消费从 1500 改为 1400，并假设消息包从 10 月 17 日起变为每千条 0.95。两项变动和生效日期均为假设合同，不是供应商事实。报告揭示消息指标在 10 月 1 日至 17 日的候选空窗；17 日后的窗口结构兼容，但仍有价格和版本变化需要复核。
