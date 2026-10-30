# 阶衡 · Jieheng

精确的阶梯用量计价库。给定一个版本化价目表和已经汇总的用量，按渐进分档或整量选档规则生成明细、精确小计，以及按明确规则舍入一次的结算金额。适合 API、消息、存储等产品的报价、账单解释和价格变更复算。

## 当前能力

- 任意 1–1024 档渐进式计价（graduated）：每档只对落入该档的用量收费，支持免费档；最终档必须无上限。
- 整量选档计价（volume）：按总用量选中一个档位，再将该档单价应用于全部用量；零用量不收费，不包含档位固定费。
- 标准库 BigInt 精确运算，价格最多 30 位整数和 18 位小数，用量最多 30 位非负整数；不经过浮点数。
- 分档明细与合计；显式选择 0–18 位结算精度，支持 HalfEven、HalfUp、Down、Up，保留舍入差额。
- 严格版本化 JSON 价目表与用量交换，拒绝未知字段和重复键；文件计价工具与公开 Stripe/AWS 价格示例。
- 可归档的计算凭证；独立检查分档守恒、小计、合计和结算规则，提供凭证核验命令。
- 同一用量下比较两个价格方案，保留双方凭证，分别输出精确差额和结算差额，并可核验归档比较报告。
- [批量调价影响汇总](docs/cohort.md)：逐客户周期结算、拒绝重复快照、保留每项比较和可核验总计。
- [显式最低消费](docs/minimum.md)：保留原始用量，单列补差，明确零用量政策，在补差后结算一次。
- [多指标用量账单](docs/invoice.md)：同客户周期逐项补差、结算后汇总；拒绝重复指标和混币种，保留完整核验依据。
- [价格生效时间表](docs/schedule.md)：明确日期选择版本，拒绝重叠和无覆盖日期，支持历史凭证核验。
- [整包容量计价](docs/packages.md)：用量向上取整到完整包，保留未使用容量，独立核验最小包数与结算。
- [预算内最大用量](docs/budget.md)：支持渐进与非单调整量价，显式限制搜索范围，提供独立最大性核验。
- [阶梯与整包组合账单](docs/bill.md)：保留两类完整凭证，跨模型拒绝重复指标，逐项结算后汇总。
- [全范围调价审查](docs/analysis.md)：按完整整数域分析金额差异，保留整量价跳变，验证所有分段和极值。
- [安全预算配额](docs/quota.md)：保证零到配额的每个整数用量都可负担，保留第一个超预算数量的凭证。
- [版本化多指标目录](docs/catalog.md)：按日期选择阶梯、最低消费与整包规则，要求完整用量覆盖后生成账单。
- [整单合同比较](docs/bill-comparison.md)：按指标对齐相同用量，分列价格、补差和结算差异，允许计价模型迁移。
- [整单预算配额](docs/bill-quota.md)：保留固定用量项，为一个含最低消费或整包规则的可变指标求安全配额。
- [目录覆盖审查](docs/coverage.md)：发布前列出每个必需指标在日期窗口内的全部计价空窗，可作为失败退出的上线检查。
- [账单解释报告](docs/report.md)：核验后导出 Markdown，解释分档、最低消费、整包和舍入，并保留完整合同与凭证附录。
- [目录迁移审查](docs/migration.md)：覆盖整个日期窗口，区分指标／单位／币种／空窗阻断和价格／模型／最低消费等复核项，提供可核验报告与发布门禁。
- [完整账单批量回放](docs/replay.md)：按客户周期回放多指标目录变更，核验涨降分布和最大涨额，并用金额／百分比上限阻止异常调价发布。
- Wasm、Wasm-GC、JavaScript、Native 使用同一个纯计算库，仅依赖标准库；文件工具使用 `moonbitlang/async`，支持 Wasm 和 Native。

## 使用

模块名为 `cosettese/jieheng`。目前从源码使用；尚未发布到 Mooncakes。先阅读[可执行快速上手](quickstart.mbt.md)和 [API 兼容政策](docs/api-policy.md)。[独立消费模块](https://github.com/cosettese/jieheng/tree/main/integration/consumer) 展示源码工作区接入；[发行包验证](docs/distribution.md) 另行检查打包后的真实消费流程。开发仓库的 `moon.work` 同时测试主库和消费模块，发布包不携带此工作区。

```text
moon update
moon test --target all --deny-warn
moon run cmd/demo --target wasm
```

示例重现公开的分档定价案例：前 5 单位每单位 7，接下来的 5 单位每单位 6.5，之后每单位 6。6 单位为 USD 41.50，20 单位为 USD 127.50，25 单位为 USD 157.50。输入来自公开教学规则，不是实际客户账单。

```moonbit
let plan = @jieheng.compile_plan(
  id="api", version="2026-09", metric="requests",
  unit="request", currency="USD",
  tiers=[
    { up_to: Some("1000"), unit_price: "0" },
    { up_to: None, unit_price: "0.001" },
  ],
)
let calculation = @jieheng.rate(plan, {
  customer: "acme", metric: "requests", period: "2026-09", quantity: "1501",
})
let settlement = @jieheng.settle(calculation, scale=2, rounding=HalfEven)
// calculation.total == "0.501"; settlement.amount == "0.50"
// settlement.delta == "-0.001"
```

公开接口见 [pkg.generated.mbti](pkg.generated.mbti)。调用方需传播或处理 `PricingError`；诊断提供 `code`、`path`、`message`。`Plan` 是已校验且脱离输入数组的快照。`Calculation` 是可检查的公开记录；`settle` 只校验金额和精度。接受外部明细时，使用 `verify_evidence` 对可信计划、用量和结算规则进行独立核验。

## 精确定义与边界

渐进分档将数量 `q` 分配到各档 `(previous, up_to]`；整量选档根据 `q` 所处区间选中一档，对全部 `q` 收费。两种模式的零用量均得到空明细和零金额，不包含固定费。明细完全精确，合计后才结算舍入。整量选档跨越降价档位时，总价可能下降。

`compile_plan` 的可选参数 `mode=Volume` 启用整量选档，默认 `Graduated` 保持旧行为；JSON 中用 `"mode":"volume"` 或 `"graduated"`。现有渐进价目表与凭证的规范输出不变。完整规则与示例见 [docs/volume.md](docs/volume.md)。

数字使用 ASCII 十进制字符串；拒绝负数、指数、前导零、空白、空小数部分、超出精度或资源上限的输入。货币是三个 ASCII 大写字母的标签，不自动验证 ISO 币种或选择小数位。客户、周期、指标、计划版本都是调用方提供的标签；周期不参与时间计算。`usage.metric` 必须与计划一致。

**不支持**原始事件计量/去重、分数用量、阶梯固定费、税费、折扣、预付额度/结转套餐、汇率、按时间比例分摊、收款、完整云厂商账单。存储的 GB-month 等时间汇总必须由调用方先完成并约定整数计量单位。

## 三个实际工作流

1. SaaS 月结：上游按客户和月份汇总请求次数；本库应用免费档和收费档，客服可以逐档解释账单。
2. 容量报价：调用方先把存储使用汇总为约定的整数单位；按公开价格快照计算分档估价，不把估价当作供应商的完整发票。
3. 调价回归：保留相同用量快照，分别应用旧版本和新版本计划，检查边界客户和结算差额。

## 后续路线

已形成“目录全窗口迁移审查 → 完整客户账单回放 → 涨额门禁”的工作流，并完成发行包与独立消费验证。可运行[固定种子生成式验证](docs/generative.md)检查组合边界、保存失败上下文并跨后端重放，以及[九项性能基线](docs/benchmarks.md)记录运行耗时、输入规模和可采集的平台内存。后续重点是实际接入反馈与相同环境下的性能跟踪；注册表发布暂缓。回放、生成测试和性能基线均只覆盖提供或生成的样本。

## 开发与验证

[可复现交付验证](docs/release.md) 提供统一入口：`moon run scripts/verify.mbtx portable HEAD` 在只含 Git 已提交文件的新目录中运行格式、接口、严格检查、三个后端及端到端验证；`all HEAD` 增加 Native 实际运行，CI 在三个系统执行完整模式。

使用 `moon.mod` / `moon.pkg`。当前验证工具链：稳定版 MoonBit v0.10.16+b1a0e846e，moon 0.1.20261020。CI 在 Linux、Windows、macOS 执行四种后端测试和示例。CI 配置代表预期覆盖，具体运行结果以 Actions 为准。

```text
moon update
moon fmt
moon info
moon check --target all --deny-warn
moon test --target all --deny-warn
```

测试包含边界前后值、零用量、免费档、分配守恒、逐单位独立参考计算、18 位小数、超大整数、四种舍入规则、畸形输入、失败后恢复、输入数组隔离和确定性。

Apache-2.0；依赖和示例来源见 [SOURCES.md](SOURCES.md)。

完整文件工作流、JSON 格式与预期输出见 [docs/formats.md](docs/formats.md)。真实 S3 价格快照的区域、SKU、发布时间、单位和估价限制见 [examples/s3/README.md](examples/s3/README.md)。运行 `moon run scripts/e2e.mbtx wasm` 可核对公开案例、错误退出和失败后恢复。

计算凭证的生成、核验、篡改示例与独立核验算法见 [docs/verification.md](docs/verification.md)。凭证没有密码学签名，核验方必须保留可信的计划、用量和结算规则。

新旧方案或两种计价模式的比较、差额定义及归档核验见 [docs/comparison.md](docs/comparison.md)。比较不进行币种或计量单位转换。
