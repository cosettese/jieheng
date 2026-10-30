# 验收索引与统一验证

从仓库根目录运行：

~~~text
moon update
moon run scripts/acceptance.mbtx portable HEAD
moon run scripts/acceptance.mbtx all HEAD
~~~

portable 执行 Wasm、Wasm-GC、JavaScript；all 增加 Native 实际运行，需要系统 C 工具链。入口串联格式与接口无漂移检查、严格编译、全部测试、演示与文件端到端流程、发行包独立消费、固定种子矩阵和九项 release 性能基线。需要 Git、tar、Node、MoonBit；Linux/macOS 另需 unzip，内存采集使用 /usr/bin/time。首次执行需要下载依赖；允许复用工具链与依赖缓存。

每次先解析一个明确的 Git commit，再克隆本机仓库并 detached checkout 到该提交，所有阶段都在同一源码快照中运行。不会带入原工作区未提交文件，也不会创建提交或向远端写入。源码快照和日志分别保留在打印的临时目录中；需自行按保留策略管理磁盘。可以指定其他本地可解析提交，不能把未提交修改误认为已经验收；提交前仍可使用 scripts/verify.mbtx 的 Git 树模式。

acceptance.json 记录提交、Git 树、模式、各阶段命令和退出码。任一阶段失败立即停止，保存失败阶段和诊断；只在全部成功且源码未改变时报告 passed。每个阶段的 stdout/stderr 合并保存在同名日志内，包含现有工具的详细证据路径。这是工程验证结果，不表示赛事组已验收。

## CI 证据产物

统一入口会把各阶段的详细日志与摘要集中放在 acceptance/stages 下。可设置 JIEHENG_EVIDENCE_DIR 到一个专用的全新目录；不设置时使用新的临时目录。每个工具拒绝复用已经存在的同名阶段目录，防止新旧结果混淆。独立运行四个阶段工具时也支持该变量。

三系统 CI 均使用统一入口，并通过 always 条件上传 JSON、日志及漂移文本，保留 14 天；产物名称含操作系统、源码 SHA 和运行尝试次数。排除源码快照、消费测试工作区、编译产物和依赖缓存。打开 Actions 运行页面的 Artifacts 下载对应系统产物，先查看 acceptance.json，再查看失败阶段日志；生成式失败时还包含 failure.json、种子、参数、原始输出和对应源码身份。Windows 未采集的内存仍标为 null。

若工具链安装或入口自身编译在创建证据目录前失败，可能没有产物；此时应查看 Actions 原始日志，上传步骤会明确报缺失，不把缺失证据当成功。运行被强制取消或 runner 故障时也不能保证上传完成。后续需要长期保留的基线应经审查归档到 benchmarks/baselines。

## 已实现能力 → 可核验证据

本表描述当前代码范围，不代替已提交的申报书。正式提交时应再把申报承诺逐项映射到本表；没有核对过的承诺不标为完成。

| 能力 | 主要公开入口 | 规则与样例 | 自动检查 |
| --- | --- | --- | --- |
| 精确阶梯与整量价、一次结算 | compile_plan / rate / settle | [格式](formats.md)、[整量价](volume.md)、examples/stripe* | 单元测试、demo、文件金样、生成式参考计算 |
| 可信输入下核验归档凭证 | encode/decode_evidence / verify_evidence | [核验](verification.md)、examples/s3 | 往返、篡改、重复键、未知字段、失败恢复 |
| 最低消费、整包、多指标组合 | rate_bill / verify_bill | [组合账单](bill.md)、examples/bill | 精度与零政策、逐项结算守恒、独立消费模块 |
| 报价比较及客户批次汇总 | compare_plans / compare_bills / compare_cohort | [比较](comparison.md)、[批次](cohort.md)、[整单](bill-comparison.md) | 旧格式金样、指标对齐、独立差额检查 |
| 预算最大值、安全前缀配额 | quote_budget / quote_quota / quote_bill_quota | [预算](budget.md)、[配额](quota.md)、[整单配额](bill-quota.md) | 穷举小域、非单调整量价、首次失败凭证 |
| 全整数域价格变化分析 | analyze_prices / verify_analysis | [分析](analysis.md)、examples/analysis | 分段与极值、边界前后值、独立参考 |
| 生效日期目录与覆盖检查 | compile_catalog / rate_catalog / catalog_gaps | [目录](catalog.md)、[覆盖](coverage.md) | 日历边界、重叠/空窗、完整用量约束 |
| 目录迁移与完整客户回放门禁 | audit_catalog_migration / replay_catalogs / check_replay_policy | [迁移](migration.md)、[回放](replay.md)、examples/replay | 逐日生成式参考、逐单位金额参考、结构阻断、绝对/相对阈值与零基线、CLI 失败退出 |
| 可解释账单导出 | render_bill_markdown | [报告](report.md)、examples/report | 先核验后渲染、转义、附录、确定输出 |
| 下游采用与交付 | root pkg.generated.mbti | [入门](../quickstart.mbt.md)、[API 策略](api-policy.md)、[发行包](distribution.md) | 独立模块消费、打包泄漏检查、文档测试 |
| 组合正确性与性能边界 | cmd/generative / cmd/benchmark | [生成式](generative.md)、[基线](benchmarks.md) | 固定种子、跨后端摘要、九项工作负载和输入规模 |

全部公开签名以编译器生成的 [pkg.generated.mbti](../pkg.generated.mbti) 为准。基线是合成负载的测量，不是生产容量承诺。来源、依赖和许可证见 [SOURCES.md](../SOURCES.md)。

## 尚未完成的提交条件

- Mooncakes 注册表发布按项目所有者要求暂缓；archive 消费成功不等于注册表安装成功。
- Gitlink 公开仓库及默认分支同步未核实。
- 实际申报材料与当前实现的完整对应关系、当前赛事批次规则仍需确认。

这些事项不会被技术脚本自动认定为通过，也不会由脚本触发发布、推送或创建账号。
