# 从另一个模块采用 Jieheng

这里是模块 `cosettese/jieheng-consumer`，不是主库中的另一个包。它通过 `moon.mod` 声明依赖 `cosettese/jieheng@0.7.0`，只使用公开 API。仓库根目录的 `moon.work` 将该依赖解析到当前源码，避免假设尚未发生的 Mooncakes 发布。

从仓库根目录运行：

```text
moon check --target all --deny-warn
moon test --target all --deny-warn
```

工作区同时验证主库与消费模块。也可 `cd integration/consumer` 后执行相同命令；工作区发现仍使用上级 `moon.work`。四个稳定后端均执行消费测试，Native 需要对应系统的 C 工具链。

完整接入路径：编译合同 → 归档并恢复可信输入 → 出账 → 保存并恢复账单 → 用可信输入独立核验 → 导出 Markdown。测试还演示按 `PricingError::Invalid` 的诊断字段处理失败，并确认畸形输入和伪造账单不会影响随后正常计算。

例子沿用 Stripe 文档的公开教学单价（5 / 10 / 无上限，7 / 6.5 / 6），20 单位原价 127.5。最低消费 130、客户、周期及消息包（1000 条 / 0.85）全部为假设参数；合计 132.55。来源和许可见根目录 `SOURCES.md`。

接入自己的源码工作区时，保留消费模块的依赖声明，并在自己的 `moon.work` 中列出 Jieheng 检出目录和业务模块目录。不要复制本库的内部实现，也不要把示例版本号当作已经发布的 Mooncakes 包。
