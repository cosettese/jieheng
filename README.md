# 阶衡 · Jieheng

精确的阶梯用量计价库。给定一个版本化价目表和已经汇总的用量，得到每档用量、精确小计，以及按明确规则舍入一次的结算金额。适合 API、消息、存储等产品的报价、账单解释和价格变更复算。

## 当前能力

- 任意 1–1024 档渐进式计价（graduated）：每档只对落入该档的用量收费，支持免费档；最终档必须无上限。
- 标准库 BigInt 精确运算，价格最多 30 位整数和 18 位小数，用量最多 30 位非负整数；不经过浮点数。
- 分档明细与合计；显式选择 0–18 位结算精度，支持 HalfEven、HalfUp、Down、Up，保留舍入差额。
- 严格版本化 JSON 价目表与用量交换，拒绝未知字段和重复键；文件计价工具与公开 Stripe/AWS 价格示例。
- Wasm、Wasm-GC、JavaScript、Native 使用同一个纯计算库，仅依赖标准库；文件工具使用 `moonbitlang/async`，支持 Wasm 和 Native。

## 使用

模块名为 `cosettese/jieheng`。目前从源码使用；尚未发布到 Mooncakes。

```text
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

公开接口见 [pkg.generated.mbti](pkg.generated.mbti)。调用方需传播或处理 `PricingError`；诊断提供 `code`、`path`、`message`。`Plan` 是已校验且脱离输入数组的快照。`Calculation` 是可检查的公开记录；`settle` 只校验金额和精度，不负责认证外部提供的计算明细。

## 精确定义与边界

数量 `q` 在档位 `(previous, up_to]` 中分配；零用量得到空明细和零金额。只输出实际使用的档位。每档小计完全精确，所有小计相加后才结算舍入，禁止逐行舍入后相加。

数字使用 ASCII 十进制字符串；拒绝负数、指数、前导零、空白、空小数部分、超出精度或资源上限的输入。货币是三个 ASCII 大写字母的标签，不自动验证 ISO 币种或选择小数位。客户、周期、指标、计划版本都是调用方提供的标签；周期不参与时间计算。`usage.metric` 必须与计划一致。

**不支持**原始事件计量/去重、分数用量、volume（整量选档）、阶梯固定费、税费、折扣、最低消费、套餐、汇率、按时间比例分摊、收款、完整云厂商账单。存储的 GB-month 等时间汇总必须由调用方先完成并约定整数计量单位。

## 三个实际工作流

1. SaaS 月结：上游按客户和月份汇总请求次数；本库应用免费档和收费档，客服可以逐档解释账单。
2. 容量报价：调用方先把存储使用汇总为约定的整数单位；按公开价格快照计算分档估价，不把估价当作供应商的完整发票。
3. 调价回归：保留相同用量快照，分别应用旧版本和新版本计划，检查边界客户和结算差额。

## 后续路线

下一步提供计算凭证和独立核验。之后才考虑独立的 volume 定价模式与价格变更比较。这里列出的后续能力均未实现。

## 开发与验证

使用 `moon.mod` / `moon.pkg`。当前验证工具链：稳定版 MoonBit v0.10.16+b1a0e846e，moon 0.1.20261020。CI 在 Linux、Windows、macOS 执行四种后端测试和示例。CI 配置代表预期覆盖，具体运行结果以 Actions 为准。

```text
moon fmt
moon info
moon check --target all --deny-warn
moon test --target all --deny-warn
```

测试包含边界前后值、零用量、免费档、分配守恒、逐单位独立参考计算、18 位小数、超大整数、四种舍入规则、畸形输入、失败后恢复、输入数组隔离和确定性。

Apache-2.0；依赖和示例来源见 [SOURCES.md](SOURCES.md)。

完整文件工作流、JSON 格式与预期输出见 [docs/formats.md](docs/formats.md)。真实 S3 价格快照的区域、SKU、发布时间、单位和估价限制见 [examples/s3/README.md](examples/s3/README.md)。运行 `moon run scripts/e2e.mbtx wasm` 可核对两个公开案例、错误退出和失败后恢复。
