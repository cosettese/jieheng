# Compare price plans at identical usage

Use a saved aggregated customer/period/metric quantity to assess a new price version or a switch between graduated and volume pricing. Both sides must use the same metric, unit and currency. No FX, rescaling, time proration, raw-event aggregation or percentage estimate is inferred.

The report preserves complete baseline and candidate evidence. Both use the **same supplied usage**, scale and rounding rule. Deltas always mean **candidate minus baseline**: a negative delta means the candidate is cheaper for this snapshot, not that it will be cheaper for every quantity.

## Reproduce the public numerical example

The checked-in Stripe tutorial fixtures use the same prices and 20 fonts but different pricing semantics:

```text
moon update
moon run cmd/compare --target wasm -- examples/stripe/plan.json examples/stripe-volume/plan.json examples/stripe/usage.json 2 half-even
```

Expected output:

```text
stripe-typographic-graduated@docs-2026-10-21 -> stripe-typographic-volume@docs-2026-10-22
typographic-example / documentation-example / 20 font
baseline: USD 127.50 (exact 127.5)
candidate: USD 120.00 (exact 120)
exact delta: -7.5
settled delta: -7.5
```

These are publicly documented teaching prices and synthetic usage, not a claim of actual customer savings. The original source and license status are recorded in [SOURCES.md](../SOURCES.md).

## Archive and verify

Add `--json` to emit deterministic `jieheng.comparison.v1` JSON. The output matches [the complete checked-in comparison](../examples/stripe-volume/comparison.json), apart from the trailing newline. Archive the plan and usage snapshots alongside it. Verify an archived comparison with trusted inputs:

```text
moon run cmd/compare --target wasm -- examples/stripe/plan.json examples/stripe-volume/plan.json examples/stripe/usage.json 2 half-even --verify examples/stripe-volume/comparison.json
```

Expected: `verified comparison: exact delta -7.5; settled delta -7.5`. Editing `settled_delta` to `0` fails at `comparison.settled_delta`, exits nonzero and emits no successful stdout. Incompatible currencies/units/metrics are rejected before comparison. The same CLI runs with `--target native` and its compiler prerequisites.

## Exact difference versus settled difference

For a single unit, baseline price `0.004` and candidate price `0.006` have an exact difference of `0.002`. With scale 2 and HalfEven, the independently settled amounts are `0.00` and `0.01`, so the **settled difference is `0.01`**. Rounding the exact difference would give `0.00` and would be wrong for a comparison of bills. Reversing the plans yields `-0.002` and `-0.01`.

Deltas use normalized signed decimal strings (`0`, `-7.5`, `0.002`), not fixed-width money formatting; the full settlement records retain explicit scale, policy and fixed-width amounts. Zero baseline amounts are valid, and no undefined percentage change is invented.

## Library contract and exchange format

- `compare_plans(baseline, candidate, usage, scale~, rounding~)` returns `Comparison` with `baseline`, `candidate`, `exact_delta`, `settled_delta`. It verifies both evidence records before returning.
- `verify_comparison(baseline, candidate, usage, report, scale~, rounding~)` checks the two records against the trusted inputs and policy and recomputes both signed differences. It does not call `compare_plans` or trust embedded identities alone.
- `encode_comparison` emits all typed fields in a stable order. `decode_comparison` checks the strict versioned shape and embedded evidence. Structural decoding alone is not semantic verification; use `verify_comparison` to accept external data.

The top-level object has exactly `schema`, `baseline`, `candidate`, `exact_delta`, `settled_delta`. Schema is `jieheng.comparison.v1`. Each side is a full `jieheng.evidence.v1` object. Deltas must be strings. Unknown fields, duplicate names (including nested ones), invalid versions, missing fields and unsupported numeric encodings are rejected. Existing JSON resource limits apply. Accepted valid reports round-trip deterministically; noncanonical or false delta claims are preserved during structural decoding and rejected during semantic verification.

This is a one-snapshot comparison, not cohort aggregation or a price recommendation engine. It inherits the evidence format's trust boundary: plan/version labels are not cryptographic hashes and reports are not signatures or authenticated invoices.
