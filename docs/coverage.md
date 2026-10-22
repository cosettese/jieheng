# 目录上线前的日期覆盖审查

一个日期能出账，不代表整个结算窗口都有价格。`catalog_gaps(catalog, starts_on, ends_before)` 检查目录的每个必需指标，返回窗口 `[starts_on, ends_before)` 内全部最大连续空窗；不需要客户用量，也不逐日展开。

返回顺序为目录中指标首次出现的顺序，再按日期排列。相接版本没有空窗，缺口裁剪到查询窗口，开放结束的规则覆盖后续日期。两个边界都必须是有效的 `0001..9999` 年公历日期，结束必须晚于开始。当前不能表示 `9999-12-31` 之后的排他边界，因此无法审查包含该最后一天的窗口。周期标签仍不参与日期计算。

```text
moon run cmd/coverage --target wasm -- examples/catalog/catalog.json 2026-09-30 2026-11-02
moon run cmd/coverage --target wasm -- examples/catalog/catalog.json 2026-10-01 2026-11-02 --require-complete
```

第一个命令列出 storage-gb-month 和 messages 在 `[2026-09-30, 2026-10-01)` 的空窗。第二个命令通过，输出空 `gaps`。可将第二个命令放在价目目录的发布检查中。原目录和公开价格来源见 [目录示例](../examples/catalog/README.md)；这里审查的是示例约定的生效时间，不保证供应商未来价格。

输出是确定性的 `jieheng.coverage.v1` JSON（`schema`、`starts_on`、`ends_before`、`gaps`；每个空窗含 `metric`、`starts_on`、`ends_before`）。普通模式即使发现缺口也成功退出，便于导出全部问题；`--require-complete` 在有缺口时返回退出码 2，stderr 包含数量与首个缺口，stdout 为空。去掉此标志即可查看全部缺口。

这项审查只证明目录内既定指标的日期覆盖，不证明价格正确、迁移前后指标相同或客户用量齐全。新增/删除指标、汇率、时区和按日分摊仍须由调用方显式处理。
