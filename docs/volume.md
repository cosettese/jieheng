# Volume pricing

Volume pricing applies a single selected tier's price to **every unit**. This differs from graduated pricing, where each unit keeps the price of the tier it falls into. For example, with bounds 5 and 10 and prices 7, 6.5 and 6, quantity 6 costs 39 under volume pricing and 41.5 under graduated pricing. Quantity 20 costs 120 and 127.5 respectively.

These numbers reproduce the [Stripe public tiered pricing tutorial](https://docs.stripe.com/subscriptions/pricing-models/tiered-pricing), checked on 2026-10-22. The usage and customer labels are synthetic; no Stripe implementation or documentation prose was copied. The fixture is not an actual subscription or current commercial price offer.

## Run and verify

```text
moon update
moon run cmd/rate --target wasm -- examples/stripe-volume/plan.json examples/stripe-volume/usage.json 2 half-even
moon run cmd/verify --target wasm -- examples/stripe-volume/plan.json examples/stripe-volume/usage.json examples/stripe-volume/evidence.json 2 half-even
```

The rate command prints one line: `tier 2: 20 x 6 = 120`, exact total `120`, and settlement `USD 120.00`. The verifier prints `verified: USD 120.00`. The same workflow runs with `--target native` when the required native compiler is available. `scripts/e2e.mbtx` runs both workflows against the checked-in canonical evidence.

## API and intervals

Pass `mode=Volume` to `compile_plan`, or `"mode":"volume"` in `jieheng.plan.v1` JSON. `Plan::mode()` returns `Volume` or `Graduated`. The default constructor mode remains `Graduated`. Encoding preserves the explicit mode. All existing numeric, label, tier-count, ordering and unbounded-final-tier rules apply to both modes.

For positive quantity `q`, tier `i` is selected exactly when `previous_bound < q <= up_to[i]` (the final tier has no upper bound). Its single evidence line spans `(0, q]`, has quantity `q`, and records the **selected plan tier index**, which can be greater than zero. Its subtotal and total both equal `q × selected_price`, with no intermediate rounding. The same settlement policies apply to either mode.

Zero usage has no selected tier, no lines and total zero. Fixed tier fees are unsupported, so the library does not reproduce systems that charge a first-tier flat fee for zero usage. A decreasing price schedule can produce a lower total after crossing a tier boundary; the implementation does not impose monetary monotonicity on volume pricing.

The verifier does not call `rate`. It checks the claimed tier index against both neighboring trusted bounds, then checks full-quantity coverage, exact price and product. A plausible subtotal using a different tier is rejected. It also rejects graduated multi-line evidence under a volume plan.

## Compatibility

Plan/evidence schema names remain v1. Existing graduated JSON and evidence bytes remain unchanged, and old API calls still select graduated pricing. An older decoder rejects a new volume plan explicitly because it does not support that mode.

Evidence v1 derives its pricing semantics from the **trusted plan**, rather than adding a new field to public `Calculation` or rewriting existing records. Supply the complete trusted plan, including its mode, for verification. Change the plan version when changing semantics. Plan IDs and versions remain labels and provide no cryptographic authenticity. Calculations within the first tier, or with zero usage, can correctly have identical results under both modes.
