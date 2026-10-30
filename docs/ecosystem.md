# 生态边界与公开 API 对照

观察日：2026-10-30。这是对指定快照的审阅，不是持续监控或生态唯一性证明。阶衡的独立价值是：对已汇总的整数指标，提供精确的分档／整包合同计价、可信输入下的归档核验，以及完整日期窗口和客户账单的调价发布检查。

## 检索范围与不确定性

- Mooncakes：执行 moon update 后审阅[官方 Git 索引](https://mooncakes.io/git/index)，快照为 ab6d913b6a43ae30d76770d5c249a457d569a5ba，提交时间 2026-10-30T10:13:35Z。对所有模块索引检索 pricing、billing、tiered、tariff、invoice、money、freight、计价、账单、阶梯，并读取命中模块的最新条目。注册表命中是候选筛选，不能单凭描述判断 API 等价。
- GitHub 与网页：使用 MoonBit pricing billing tiered catalog migration，以及 site:mooncakes.io pricing billing money invoice tier catalog；进一步读取下列仓库默认分支快照的全部已提交 .mbti、许可证，以及相关源码和使用说明。
- 未发布项目、其他托管平台、不同语言描述、未被搜索引擎索引的仓库及审阅后的更新仍可能遗漏。公开接口缺少某个名字不证明内部没有相似算法。若出现覆盖相同核心工作流和 API 边界的成熟项目，应重新审查范围。

## 已深入审阅的相关项目

下表的活动时间来自 GitHub repository API 的 pushed_at（UTC），只说明观察到的最近推送，不代表发布频率或维护承诺。接口链接固定到审阅提交；根许可证与 API 一起核对。

| 项目／快照／最近推送 | 公开入口与功能范围 | 与阶衡的交集及独立边界 |
| --- | --- | --- |
| [moonmoney](https://github.com/haol-05/moonmoney/tree/b5e950cf5e9c3205a3af22225d31bf6c6ed1f2e1)；2026-10-26；[Apache-2.0](https://github.com/haol-05/moonmoney/blob/b5e950cf5e9c3205a3af22225d31bf6c6ed1f2e1/LICENSE)；注册表 0.1.4 | [根接口](https://github.com/haol-05/moonmoney/blob/b5e950cf5e9c3205a3af22225d31bf6c6ed1f2e1/pkg.generated.mbti)：Money::of_minor、Money::allocate、Rate::parse；货币最小单位、分摊、税、现金舍入、汇率及格式解析 | 交集是精确金额与舍入。阶衡的 Plan、Usage、Evidence 和 Catalog 绑定用量合同，保留小于货币最小单位的单价直至显式结算；不把通用 Money、税或 FX API 当作新增贡献 |
| [moongate](https://github.com/vectie/moongate/tree/ebf4e1a730233392c532a91d5488e24edae00f42)；2026-10-19；[Apache-2.0](https://github.com/vectie/moongate/blob/ebf4e1a730233392c532a91d5488e24edae00f42/LICENSE) | [根接口](https://github.com/vectie/moongate/blob/ebf4e1a730233392c532a91d5488e24edae00f42/pkg.generated.mbti)：calculate_cost_for_app；[usage_preview 接口](https://github.com/vectie/moongate/blob/ebf4e1a730233392c532a91d5488e24edae00f42/usage_preview/pkg.generated.mbti)：price_usage_file_json、compare_usage_files_json；模型 token 成本、离线重计价、路由和网关相关流程 | **确有重叠**：用量重计价与费用比较。[重计价价卡](https://github.com/vectie/moongate/blob/ebf4e1a730233392c532a91d5488e24edae00f42/usage_preview/rate_card.mbt)按 provider/model 指定 USD 输入／输出每百万 token 价格。阶衡接受调用方定义的整数指标、任意累计档位、整包和最低消费，并提供全窗口目录结构审查、完整客户账单门禁及可信合同核验；不提供 token 采集或路由 API |
| [ccusage-mbt](https://github.com/kazuph/ccusage-mbt/tree/a561e8fd2ff8e07f7ef67e6f282850a6e1b7aa2f)；2026-02-24；[Apache-2.0](https://github.com/kazuph/ccusage-mbt/blob/a561e8fd2ff8e07f7ef67e6f282850a6e1b7aa2f/LICENSE) | [使用说明](https://github.com/kazuph/ccusage-mbt/blob/a561e8fd2ff8e07f7ef67e6f282850a6e1b7aa2f/README.md)：daily／monthly／weekly／session 命令；Claude/Codex 本地日志汇总与模型成本计算。未发现该快照提交 .mbti，不能据此推断所有符号的可复用性 | 交集是成本统计。阶衡提供通用合同库及归档报告核验，输入不依赖会话日志目录、模型名或 C 日志解析器 |
| [moonbit-freight-calculator](https://github.com/xvkong834/moonbit-freight-calculator/tree/0e1914a15fa472d58169945dfa8d3755f1f5ddb2)；2026-08-24；[MIT](https://github.com/xvkong834/moonbit-freight-calculator/blob/0e1914a15fa472d58169945dfa8d3755f1f5ddb2/LICENSE)；注册表 xvkong834 0.3.0 | [接口](https://github.com/xvkong834/moonbit-freight-calculator/blob/0e1914a15fa472d58169945dfa8d3755f1f5ddb2/pkg.generated.mbti)：billing_rule、quote、quote_manifest、reconcile_lines；首重续重、区域、附加费及物流结算 | 交集是报价、最低费用及对账。阶衡的计量单位不绑定包裹和重量，合同按任意整数档位／整包表达，并审查跨日期的多指标目录迁移 |
| [moonbit-accounting](https://github.com/mhlagent/moonbit-accounting/tree/d3bda69ba28c8e897a95cf2c3b0e5472dbb61f39)；2026-08-24；[Apache-2.0](https://github.com/mhlagent/moonbit-accounting/blob/d3bda69ba28c8e897a95cf2c3b0e5472dbb61f39/LICENSE) | [接口](https://github.com/mhlagent/moonbit-accounting/blob/d3bda69ba28c8e897a95cf2c3b0e5472dbb61f39/pkg.generated.mbti)：build_report_pack、account_balance、compare_reports；财务分录、报表、账龄和合并 | 交集是金额报告与期间比较。阶衡从合同与聚合用量计算应计费用，不维护会计分录、科目映射或财务报表体系 |

这些仓库的 API 和许可证用于研究，未作为阶衡实现或测试的代码来源；本次没有运行它们的构建或验证其业务正确性。也不以其项目规模、下载量或星标推断需求强度。

## 新命中与后续复查

注册表另命中 [aurum](https://github.com/Lyllyl789/aurum) 0.1.1（最小单位金额、现金流与贷款）、[moonbit-fixedincome](https://github.com/lwmvr/moonbit-fixedincome) 0.2.1（固收现金流定价）、[wagekit](https://github.com/JQ-ai-nb/wagekit) 0.3.0（工资与预扣税核对），以及贸易文档和 OFD 文档库。这些条目目前只做元信息筛选，尚未逐个深入审阅 API。注册表中的 lyyjavastudy/moonbit-freight-calculator 也指向上述 xvkong834 仓库，不能重复计为两个独立实现。

## 已实现的独立贡献与验收入口

| 工作流 | 阶衡公开入口 | 当前可核验证据 |
| --- | --- | --- |
| 亚最小货币单位计价与显式结算 | compile_plan → rate → settle | quickstart.mbt.md、examples/stripe、精度与舍入测试 |
| 非单调整量价的可负担前缀 | quote_quota / verify_quota | examples/quota、首次失败凭证与穷举参考 |
| 完整日期窗口的结构迁移检查 | audit_catalog_migration / verify_catalog_migration | examples/migration、逐日生成式参考 |
| 完整客户账单调价及上线门禁 | replay_catalogs / verify_catalog_replay / check_replay_policy | examples/replay、独立逐单位与百分比参考 |

独立性来自上述输入契约和完整工作流的组合，而不是更名、展示界面或重写金额运算。此对照不证明所有相关仓库均缺少这些能力；判断范围限于已审阅接口和源码。[验收索引](acceptance.md)区分当前实现、验证证据与待完成的提交条件。
