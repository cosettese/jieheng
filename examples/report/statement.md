# Usage pricing statement

Customer: notification-service

Period: 2026-10

Currency: USD. Scale: 2. Rounding: half-even.

| Usage charges | Minimum top-ups | Exact total | Settled total | Rounding delta | Minor units |
| --- | --- | --- | --- | --- | --- |
| 1373.75 | 128.8 | 1502.55 | 1502.55 | 0 | 150255 |

Each item is settled once after its minimum, if any; settled items are summed without rounding again. This statement covers usage pricing only.

## Metric: storage-gb-month

Quantity: 60000 GB-Mo.

Plan: s3-standard-us-east-1-storage @ aws-20261015173540. Model: graduated.

Minimum: 1500. At zero usage: charge. Usage charge: 1371.2. Top-up: 128.8. Exact total: 1500.

| Tier | From (exclusive) | To (inclusive) | Quantity | Unit price | Subtotal |
| --- | --- | --- | --- | --- | --- |
| 0 | 0 | 51200 | 51200 | 0.023 | 1177.6 |
| 1 | 51200 | 60000 | 8800 | 0.022 | 193.6 |

Settled: USD 1500.00. Rounding delta: 0. Minor units: 150000.

## Metric: messages

Quantity: 2501 message.

Plan: message-bundle @ example-v1. Model: package.

| Capacity per package | Price per package | Packages | Unused units | Exact total |
| --- | --- | --- | --- | --- |
| 1000 | 0.85 | 3 | 499 | 2.55 |

Settled: USD 2.55. Rounding delta: 0. Minor units: 255.

## Complete contract input

The trusted input includes every tier, including unoccupied tiers.

```json
{"schema":"jieheng.bill-input.v1","items":[{"kind":"metered","plan":{"schema":"jieheng.plan.v1","id":"s3-standard-us-east-1-storage","version":"aws-20261015173540","metric":"storage-gb-month","unit":"GB-Mo","currency":"USD","mode":"graduated","tiers":[{"up_to":"51200","unit_price":"0.023"},{"up_to":"512000","unit_price":"0.022"},{"up_to":null,"unit_price":"0.021"}]},"usage":{"schema":"jieheng.usage.v1","customer":"notification-service","metric":"storage-gb-month","period":"2026-10","quantity":"60000"},"minimum":"1500","zero_usage":"charge"},{"kind":"package","plan":{"schema":"jieheng.package-plan.v1","id":"message-bundle","version":"example-v1","metric":"messages","unit":"message","currency":"USD","package_size":"1000","package_price":"0.85"},"usage":{"schema":"jieheng.usage.v1","customer":"notification-service","metric":"messages","period":"2026-10","quantity":"2501"}}]}
```

## Complete bill evidence

Verification requires the trusted contract and settlement policy; this is not a signature.

```json
{"schema":"jieheng.bill.v1","customer":"notification-service","period":"2026-10","currency":"USD","items":[{"kind":"metered","evidence":{"schema":"jieheng.charge.v1","calculation":{"plan_id":"s3-standard-us-east-1-storage","plan_version":"aws-20261015173540","currency":"USD","unit":"GB-Mo","usage":{"schema":"jieheng.usage.v1","customer":"notification-service","metric":"storage-gb-month","period":"2026-10","quantity":"60000"},"lines":[{"tier":0,"from_exclusive":"0","to_inclusive":"51200","quantity":"51200","unit_price":"0.023","subtotal":"1177.6"},{"tier":1,"from_exclusive":"51200","to_inclusive":"60000","quantity":"8800","unit_price":"0.022","subtotal":"193.6"}],"total":"1371.2"},"minimum":"1500","zero_usage":"charge","top_up":"128.8","total":"1500","settlement":{"currency":"USD","scale":2,"rounding":"half-even","minor_units":"150000","amount":"1500.00","delta":"0"}}},{"kind":"package","evidence":{"schema":"jieheng.package-evidence.v1","plan_id":"message-bundle","plan_version":"example-v1","currency":"USD","unit":"message","usage":{"schema":"jieheng.usage.v1","customer":"notification-service","metric":"messages","period":"2026-10","quantity":"2501"},"package_size":"1000","package_price":"0.85","packages":"3","unused_units":"499","total":"2.55","settlement":{"currency":"USD","scale":2,"rounding":"half-even","minor_units":"255","amount":"2.55","delta":"0"}}}],"totals":{"usage_total":"1373.75","top_up":"128.8","total":"1502.55","scale":2,"rounding":"half-even","minor_units":"150255","amount":"1502.55","delta":"0"}}
```
