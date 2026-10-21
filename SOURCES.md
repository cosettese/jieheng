# Sources and licensing

Checked on 2026-10-21. Project source is provided under Apache-2.0. No upstream pricing implementation or test suite was copied.

| Resource | Use | License / status |
| --- | --- | --- |
| [MoonBit core](https://github.com/moonbitlang/core) | Standard-library BigInt, strings, collections, tests | Apache-2.0; distributed with the toolchain |
| [MoonBit async v0.22.5](https://github.com/moonbitlang/async) | File CLI and `.mbtx` process automation only | Apache-2.0; pinned dependency, not vendored |
| [MoonBit x v0.5.5](https://github.com/moonbitlang/x) | CLI process exit status (`sys`) only | Apache-2.0; pinned dependency, not vendored |
| [AWS S3 public price list](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonS3/current/us-east-1/index.json) | Real Standard storage pricing snapshot | Numerical facts only; AWS material is not relicensed. Exact product and provenance in `examples/s3/README.md` |
| [Stripe tiered pricing documentation](https://docs.stripe.com/subscriptions/pricing-models/tiered-pricing) | Numerical graduated example: bounds 5, 10, infinity; prices 7, 6.5, 6; totals 41.50, 127.50, 157.50 | Public documentation; numerical facts transcribed, no documentation prose or implementation copied; not relicensed |
| [MoonBit official stable distribution](https://www.moonbitlang.com/download/) | Stable compiler v0.10.16+b1a0e846e and moon 0.1.20261020, observed from official `binaries/latest` on 2026-10-21 | Build tools, not vendored |
| [setup-moonbit](https://github.com/hustcer/setup-moonbit) | CI toolchain setup action | External action, not vendored; upstream license applies |
| [msvc-dev-cmd](https://github.com/ilammy/msvc-dev-cmd) | Windows CI C/C++ compiler environment | MIT; external action, not vendored |

The customer and period labels in tests and the demo are synthetic. The published price example is a reproducible teaching case, not a live price quotation or customer usage dataset.

## Ecosystem boundary

Package pricing (2026-10-22): demand/semantics reference is [Stripe's Plan API, transform_usage](https://docs.stripe.com/api/plans/object). Jieheng implements a fixed-capacity upward package count with independently checked minimality, not Stripe's subscription or usage protocols. The SMS fixture (1000 units at USD 0.85, quantity 2501) is entirely synthetic and not a supplier price. Implementation and repeated-addition reference tests were written here; no upstream code or tests were copied.

The effective-date schedule example (2026-10-22) uses the existing S3 snapshot and its observed `effectiveDate` of 2026-10-01. No additional historical prices are invented. Open-ended applicability and the selected date are explicit demonstration inputs, not a claim about future AWS prices. Gregorian validation and timeline tests were written for this project without copying a date-library implementation.

The multi-metric invoice example (2026-10-22) combines the existing Stripe teaching prices and S3 public price snapshot with synthetic usage, customer/period and a hypothetical storage floor. It is a constructed pricing statement, not an actual provider invoice. Multi-charge demand is also illustrated by [Lago's invoicing product](https://getlago.com/platform/billing-invoicing). No invoice implementation, test suite or documentation prose was copied. Jieheng remains a pure usage-pricing library without accounting entries, tax or payment processing.

The minimum-spend feature (2026-10-22) is a deliberately bounded contract rule defined in `docs/minimum.md`. Demand references include [Lago's public charge API](https://github.com/getlago/lago-java-client/blob/main/docs/PlanUpdateInputPlanChargesInner.md), whose `minAmountCents` describes a per-charge, per-period minimum. No Lago code or test cases were copied; Jieheng does not implement Lago proration, invoice lifecycle or tax semantics. The S3 demonstration's USD 1500 minimum is hypothetical, not an AWS policy.

The cohort fixture added on 2026-10-22 combines the same Stripe public numerical rules at quantities 6, 20 and 25 with synthetic customer labels. The sums and regression cases were calculated for this project; no external customer data or test suite was copied.

The volume example added on 2026-10-22 uses the same Stripe tutorial's numerical rules: quantities 6, 20 and 25 cost 39, 120 and 150 under volume pricing. Only these numerical facts and domain semantics were transcribed; no source code, test suite or prose was copied. The original S3 price snapshot remains the observation from 2026-10-21.

The research baseline is the Mooncakes registry and public sources checked on 2026-10-21. Searches included `pricing`, `billing`, `tier`, `rate`, `cost`, `money`, `freight`, `invoice`, and Chinese equivalents. This is evidence for a complementary scope, not proof that no competing project exists.

- [moonmoney](https://github.com/haol-05/moonmoney), Apache-2.0: currency/minor-unit money, allocation, rounding, rates and FX. Jieheng supplies cumulative tier allocation and keeps sub-minor-unit prices exact until settlement.
- [moonbit-freight-calculator](https://github.com/xvkong834/moonbit-freight-calculator), MIT: freight first-weight/additional-weight rules, zones, surcharges and reconciliation. Jieheng handles arbitrary graduated marginal tiers, without logistics rules.
- [moongate](https://github.com/vectie/moongate), Apache-2.0: model token usage costs, provider/model rate cards and offline repricing. Jieheng has no model/token/proxy workflow; its input is a generic aggregated metric and an arbitrary tier plan.
- [moonbit-accounting](https://github.com/mhlagent/moonbit-accounting), Apache-2.0: debit/credit accounting and reports. Jieheng stops at pricing and settlement.

Demand references: [Lago](https://github.com/getlago/lago), [OpenMeter](https://github.com/openmeterio/openmeter), and [Kill Bill](https://github.com/killbill/killbill). These are larger billing/metering systems, not dependencies or source-code donors.
