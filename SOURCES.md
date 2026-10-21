# Sources and licensing

Checked on 2026-10-21. Project source is provided under Apache-2.0. No upstream pricing implementation or test suite was copied.

| Resource | Use | License / status |
| --- | --- | --- |
| [MoonBit core](https://github.com/moonbitlang/core) | Standard-library BigInt, strings, collections, tests | Apache-2.0; distributed with the toolchain |
| [Stripe tiered pricing documentation](https://docs.stripe.com/subscriptions/pricing-models/tiered-pricing) | Numerical graduated example: bounds 5, 10, infinity; prices 7, 6.5, 6; totals 41.50, 127.50, 157.50 | Public documentation; numerical facts transcribed, no documentation prose or implementation copied; not relicensed |
| [MoonBit release notes](https://www.moonbitlang.com/updates/) | 2026-09-21 release; installed compiler v0.10.14 | Documentation reference only |
| [setup-moonbit](https://github.com/hustcer/setup-moonbit) | CI toolchain setup action | External action, not vendored; upstream license applies |

The customer and period labels in tests and the demo are synthetic. The published price example is a reproducible teaching case, not a live price quotation or customer usage dataset.

## Ecosystem boundary

The research baseline is the Mooncakes registry and public sources checked on 2026-10-21. Searches included `pricing`, `billing`, `tier`, `rate`, `cost`, `money`, `freight`, `invoice`, and Chinese equivalents. This is evidence for a complementary scope, not proof that no competing project exists.

- [moonmoney](https://github.com/haol-05/moonmoney), Apache-2.0: currency/minor-unit money, allocation, rounding, rates and FX. Jieheng supplies cumulative tier allocation and keeps sub-minor-unit prices exact until settlement.
- [moonbit-freight-calculator](https://github.com/xvkong834/moonbit-freight-calculator), MIT: freight first-weight/additional-weight rules, zones, surcharges and reconciliation. Jieheng handles arbitrary graduated marginal tiers, without logistics rules.
- [moongate](https://github.com/vectie/moongate), Apache-2.0: model token usage costs, provider/model rate cards and offline repricing. Jieheng has no model/token/proxy workflow; its input is a generic aggregated metric and an arbitrary tier plan.
- [moonbit-accounting](https://github.com/mhlagent/moonbit-accounting), Apache-2.0: debit/credit accounting and reports. Jieheng stops at pricing and settlement.

Demand references: [Lago](https://github.com/getlago/lago), [OpenMeter](https://github.com/openmeterio/openmeter), and [Kill Bill](https://github.com/killbill/killbill). These are larger billing/metering systems, not dependencies or source-code donors.
