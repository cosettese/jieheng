# 可归档的账单解释

`render_bill_markdown(items, bill, scale~, rounding~)` 接受可信的完整合同、待展示账单和明确的结算规则。它先执行 `verify_bill`，然后返回确定性的 Markdown：整单汇总、每个指标的计价模型、分档金额或包容量、最低消费补差、零用量政策和舍入差额。

两个 JSON 附录分别保留完整合同输入和账单凭证，包括正文中未占用的档位。它们与 `encode_bill_input` / `encode_bill` 的规范字节一致，可提取后交给现有解码和核验 API。Markdown 本身不是新的交换格式，没有 Markdown 导入器，也没有签名。

```text
moon run cmd/explain --target wasm -- examples/bill/input.json examples/bill/bill.json 2 half-even
```

可把 stdout 保存为 `.md` 文件。预先生成的完整结果见 [示例报告](../examples/report/statement.md)。S3 单价为既有公开快照；USD 1500 最低消费、消息包和用量为假设合同，来源及限制见 [组合账单](bill.md)。不是供应商开具的发票。

正文标签对 HTML 和 Markdown 标点进行实体转义，避免客户、指标和版本标签改变表格或插入 HTML；JSON 附录使用长度大于内容中最长反引号串的围栏。保留 Unicode 标签。报告不内嵌 HTML，也不依赖网络图片、字体或外部服务。输出统一使用 LF 换行；仓库为规范报告样例指定 LF，确保不同系统检出的文件可以逐字比较。

输入和凭证各自仍受现有 JSON 的 1 Mi UTF-16 单位限制，最终 Markdown 上限为 4 Mi UTF-16 单位。无法完整编码时拒绝输入，不截断档位或附录。CLI 在全部核验和格式化成功后才写 stdout；失败返回非零并在 stderr 提供诊断，不输出半份报告。报告限于现有用量计价语义，不增加税费、付款状态或法律发票字段。
