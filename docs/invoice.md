# 多指标用量账单

同一个产品往往同时收取多个指标的费用。`rate_invoice` 将一位客户、一个周期、一个币种的 1–64 项 `ChargeInput` 组合成可逐项解释和独立核验的价格账单。

每项包含已编译 `plan`、已汇总 `usage`、明确的 `minimum`（无需最低消费时传 `"0"`）与 `zero_usage`。不同指标可以有不同单位、阶梯模式和最低消费；每个指标只能出现一次。输入顺序就是账单顺序。相同指标重复、混客户、混周期、混币种和任意坏项都会使整个请求失败，不跳过或合并数据。

明确的结算规则是：**每个指标先补最低消费差额、再按同一个显式精度/舍入规则结算，最后精确相加 minor units**。不对账单再次舍入。两个指标各 0.004、两位 HalfEven 的账单金额是 0.00，精确应计为 0.008，差额为 -0.008。账单差额可能大于一个最小货币单位，这是多项舍入的合计，不可用单次舍入区间验证整个账单。

`Invoice` 保留 `charges` 以及客户/周期/币种、`usage_total`、`top_up`、`total`、`scale`、`rounding`、`minor_units`、固定精度 `amount`、有符号 `delta`。前三个金额分别为原始用量之和、最低消费补差之和、最终精确应计之和；`delta = amount - total`。每项都保留完整用量分档和最低消费依据。

调用 `verify_invoice(items, report, scale~, rounding~)` 时必须提供完整可信的输入清单，而非相信报告中的计划/用量/政策。核验独立检查每项分档、补差和结算，随后检查行数、顺序、身份和各总计，拒绝删行、换序、重复行以及伪造总计。它不会调用账单生成器。

## 可复现案例

```text
moon run cmd/invoice --target wasm -- examples/invoice/input.json 2 half-even
moon run cmd/invoice --target wasm -- examples/invoice/input.json 2 half-even --json
moon run cmd/invoice --target wasm -- examples/invoice/input.json 2 half-even --verify examples/invoice/invoice.json
moon run scripts/e2e.mbtx wasm
```

示例是设计工作室的合成预算：20 个字体单位按 Stripe 公开教学规则为 127.50，60000 GB-Mo 按既有 S3 公开价格快照为 1371.20，再应用假设的存储合同最低消费 1500（补差 128.80），合计 USD 1627.50。价格来源分别见 `SOURCES.md` 和 `examples/s3/README.md`；客户、月份、用量、组合关系和最低消费均为演示参数。不同来源的定价规则仅用于展示组合能力，不代表 Stripe 或 AWS 会共同出具该账单，也不是实际供应商完整报价。

## 交换格式与边界

`encode_invoice_input` / `decode_invoice_input`：`jieheng.invoice-input.v1` 恰含 `schema`、`items`。每项恰含完整 PlanV1 `plan`、完整 UsageV1 `usage`、字符串 `minimum`、枚举字符串 `zero_usage`。解码同时校验清单身份约束；嵌入计划只是格式便利，核验方仍需自行保管可信清单。

`encode_invoice` / `decode_invoice`：`jieheng.invoice.v1` 恰含 `schema` 和上述 `Invoice` 全部字段；`charges` 是完整 ChargeV1 数组。解码后仍需可信核验。所有嵌套未知字段、重复键、畸形数字/枚举或超过 1 Mi UTF-16 单元的文档会被拒绝；编码也检查大小。金额合计仍限制 60 位整数和 18 位小数，超限报错。大规模客户集合应使用批量调价接口；不能将一个客户的相同指标任意拆分，以免阶梯和最低消费被重复应用。

当前只支持逐指标结算；不支持整张账单统一舍入、账单级最低消费、税费、折扣、套餐、抵扣、账单号/法定发票字段、开票发送或收款。这是可嵌入下游应用的定价账单，不是完整财务系统。
