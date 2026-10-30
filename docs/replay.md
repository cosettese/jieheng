# 多客户、多指标调价回放与发布门禁

replay_catalogs 接受两个可信 Catalog、完整的 CatalogReplayCase 数组和显式精度／舍入规则。每个案例包含一个公历计价日期 on 和同客户、同周期的完整 Usage 数组。两侧按同一日期选择规则，按指标对齐整单合同，保留双方所有账单凭证。指标增删、单位／币种不匹配或任一日期无价格均拒绝整个批次，不补零、不跳过失败项。

先用 [迁移审查](migration.md) 检查整个上线窗口，再使用真实或可公开复现的完整用量回放具体影响。两项检查互补：回放只证明提供的样本，不能保证未提供用量的影响。

案例按输入顺序保留。每个客户周期只能出现一次，即使 on 不同也视为重复；不同周期可以共存。指标用量必须先汇总，不能拆分一个客户周期以绕过限制。上限为 256 个案例、每例 64 个指标、全批共 1024 条指标快照。大批次只能在完整客户周期之间分组。

CatalogReplay 提供：

- 双方精确总额、已结算总额及两类差额；
- 每个日期的完整 BillComparison，保持逐项最低消费和结算，合计后不再舍入；
- increased / decreased / unchanged：结算金额涨、降、平的客户周期快照数量，不是去重客户人数；
- max_increase 和 max_increase_index：最大正结算涨额及最早输入索引；没有涨价时为零与 null。

verify_catalog_replay 使用可信目录、日期、用量和结算规则核验每个完整整单比较，再验证汇总、分类数量和最大值；不调用回放或计价生成器。汇总辅助逻辑与生成端共享，单项计价及舍入由既有独立核验器检查。解码成功不等于可接受报告。

ReplayPolicy 指定 currency、非负绝对涨额上限 max_increase 和可选非负百分比上限 max_increase_percent。check_replay_policy 先完整核验报告，再对每个客户周期的结算涨额检查两项上限。等于上限允许，下降或不变不触发涨价门禁；不同币种拒绝，不做汇率换算。

百分比通过 BigInt 交叉乘法比较，绝不先除法或舍入百分比。若设置百分比上限，旧金额为零、新金额大于零时拒绝，因为有限百分比不存在；null 表示不检查相对涨幅，但绝对上限仍必需。0 → 0 通过。负阈值、指数形式、超精度值等按既有十进制规则拒绝。

~~~text
moon run cmd/replay --target wasm -- examples/catalog/catalog.json examples/migration/candidate.json examples/replay/cases.json 2 half-even --policy examples/replay/policy.json
moon run cmd/replay --target wasm -- examples/catalog/catalog.json examples/migration/candidate.json examples/replay/cases.json 2 half-even --verify examples/replay/report.json --policy examples/replay/policy.json
~~~

默认导出完整 JSON；--verify 后可叠加 --policy。门禁失败返回退出码 2，stderr 给出第一个超限客户周期、日期和金额，stdout 为空。正常导出模式可查看全部账单。报告内任何行失败会拒绝全批，不导出半份结果。

格式：

- jieheng.replay-cases.v1：schema、cases；每例 on、usages（完整 UsageV1 对象数组）。
- jieheng.replay-policy.v1：schema、currency、max_increase、max_increase_percent（字符串或 null）。
- jieheng.catalog-replay.v1：schema、currency、rows、上述六个总额／差额字段、三个分类数量、max_increase、max_increase_index。每行仅 on、comparison（完整 BillComparisonV1）。

所有格式拒绝未知字段与重复键，输入及导出均受既有 1 Mi UTF-16 单位限制，无法完整表示时拒绝而不截断。汇总超过 60 位整数金额上限也拒绝。内存 API 的案例数量上限不保证每份完整证据都能放入单个交换文档，必要时按完整客户周期分组。规范示例、金额及来源见 [回放示例](../examples/replay/README.md)。
