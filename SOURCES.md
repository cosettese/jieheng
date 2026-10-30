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

The strict JSON ingress passes `max_nesting_depth=32` to the installed MoonBit core parser, mapping its depth error to the existing Jieheng diagnostic. No parser source or upstream tests were copied; depth/size boundary and recovery regressions were written here. This uses the verified core API shipped with the documented toolchain.

The independent consumer module uses only Jieheng public APIs. Its workflow tests reuse the existing Stripe teaching numbers, with explicitly synthetic clients, minimum and message-package rules. No external integration implementation or tests were copied; the module is Apache-2.0 like the rest of this repository.

The release verifier is project-authored `.mbtx` automation using MoonBit async process/filesystem APIs and external Git/tar tools; it copies no release-helper implementation. Source snapshots exclude local build outputs, while toolchain and dependency caches may be reused. Verification summaries describe executed checks, not a signature or a claim of fully offline builds.

## Ecosystem boundary

Distribution tooling uses moon package and standard archive tools, following official MoonBit .moonignore documentation. The consumer tests and executable quickstart are project-authored; no external release workflow or example implementation was copied. Archive testing is distinct from registry publication and installation.

Multi-customer catalog replay and release thresholds are project-authored composition and exact-integer policy logic. Tests use independent forward bills and percent cross-product references, without copying an upstream suite. The example reuses the existing S3 price snapshot and hypothetical migration contract with synthetic customers/usages; aggregate savings do not imply every customer saves. Existing single-bill comparison JSON bytes remain covered by the end-to-end golden fixtures.

Catalog migration auditing uses project-defined structural/review classifications over the two complete trusted timelines. Interval generation, an independent boundary/selection checker and adversarial tests were written here without copying upstream migration code. Its sample reuses the existing public S3 unit-price facts with hypothetical floor/message-price/date changes; these changes are not supplier facts.

The Markdown statement reuses the existing mixed-bill contract, public S3 unit prices and explicitly synthetic usage/minimum/message package. Rendering, escaping, fence selection and tests were written here; no external template, report implementation, customer data or fixture was copied. JSON appendices preserve the existing formats and source boundary. Project code and documentation remain Apache-2.0.

Catalog coverage checks reuse the existing catalog fixture and its documented public-price/synthetic-contract boundary. Interval-complement code and exhaustive small-window tests were written for this project, without copying a calendar library or external tests. Coverage is not a claim about supplier price validity.

The bill-quota example reuses the existing S3 price snapshot and synthetic message package, with a synthetic USD 1503 budget. Independent first-failure enumeration, fixed-item conservation and minimum/rounding tests were written here. It is bounded pricing analysis, not copied portfolio optimization, metering or payment code.

The bill-comparison candidate reuses the existing S3 unit prices. Its USD 1400 floor and USD 0.0007 per-message price are synthetic contract changes, not supplier facts. Both manifests preserve identical usage. Metric alignment and signed-difference tests were written for this project, without copying upstream comparison code or fixtures.

The versioned catalog example reuses the documented S3 snapshot and synthetic message package. The November message price, its effective date and minimum-spend policy are hypothetical demonstration contracts. Timeline grouping, complete metric matching and tests were written here; no external catalog implementation or fixture was copied.

Safe-prefix quotas reuse the existing S3 price facts and synthetic budget parameters. The three-tier volume-hole fixture (10 / 1 / 20 per unit, bounds 5 / 10 / infinity, budget 12) is constructed for this project, not a supplier quote. First-failure exhaustive tests and independent prefix/witness checks were written here without copying an external implementation or suite. This adds no event-metering, accounting or payment workflow.

Whole-domain price analysis reuses the documented Stripe graduated/volume numerical rules with a synthetic limit of 25. The piecewise-affine algorithm, independent truncated-sum checker and exhaustive forward-pricing regression tests were written here; no external optimizer, curve-analysis implementation or test suite was copied. No uniqueness or performance advantage is asserted.

The mixed bill example combines the already documented S3 price snapshot and synthetic message package, usage and minimum-spend parameters. No new supplier price is asserted. Tagged-model composition, duplicate-metric checks and regression tests were written for this project without copying upstream code or fixtures.

Budget inversion (2026-10-22) reuses the existing S3 price facts with a synthetic USD 1500 budget and 100000-unit search ceiling. No optimizer implementation or tests were copied. Exhaustive forward enumeration is the test oracle; maximality verification uses separately derived rounding thresholds. Stripe's existing public volume-pricing example also documents that crossing tiers can decrease totals, motivating the per-tier search rather than a globally monotone assumption.

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
