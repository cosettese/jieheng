# Reproducible pricing evidence

Pricing evidence binds a tier breakdown and one settlement to a plan ID/version and an aggregated usage snapshot. It lets an application archive a quote, explain a bill, or verify a previously produced result without trusting that result's arithmetic.

It is **not a signature, payment instruction or authenticated invoice**. Plan IDs are labels, not hashes. Keep trusted plan and usage snapshots separately. A verifier who accepts arbitrary replacement plans or usage can be shown a perfectly consistent calculation for the wrong inputs. Trusted scale and rounding are also explicit arguments; do not accept a report's policy merely because its final amount looks plausible.

## End-to-end example

No account, network, database or private service is needed after installing dependencies. From the repository root:

```text
moon update
moon run cmd/rate --target wasm -- examples/s3/plan.json examples/s3/usage.json 2 half-even --json
moon run cmd/verify --target wasm -- examples/s3/plan.json examples/s3/usage.json examples/s3/evidence.json 2 half-even
```

The first command emits canonical `jieheng.evidence.v1` JSON. Its output matches the checked-in evidence file (apart from the trailing newline). The second prints `verified: USD 1371.20`. Redirect the first command's stdout to a UTF-8 file to archive a new calculation. The file CLI also runs with `--target native` when its compiler prerequisites are installed.

Change the report's exact total from `1371.2` to `0`: verification fails with `total: calculation.total: expected the exact sum of all tier subtotals`. Change only the requested rounding policy to `half-up`: verification fails with `policy`, even though both policies give the same amount for this exact-cent example. Failed validation emits no successful output and exits nonzero.

`moon run scripts/e2e.mbtx wasm` checks both Stripe and S3 file workflows, canonical output against checked-in evidence, successful verification, a mismatched metric, a tampered total, an untrusted policy, and recovery. CI runs the same harness for Native. Comparing both targets to the same checked-in output detects serialization or arithmetic divergence.

## Library API

- `verify_calculation(plan, usage, calculation)` independently checks identity and the trusted plan's mode. Graduated pricing requires a positive contiguous partition from zero to the trusted quantity, correct tier boundaries, per-line multiplication, and the exact sum. Volume pricing requires exactly one positive-usage line, a selected tier whose interval contains the whole quantity, and that tier's price applied to all units. Zero usage requires an empty breakdown and zero total. It does not call `rate`.
- `verify_settlement(calculation, settlement, scale~, rounding~)` checks the supplied trusted policy and the rounding error interval, fixed decimal formatting, minor units and delta. It does not call `settle`. Used alone, it verifies settlement arithmetic only; it does not authenticate the calculation.
- `verify_evidence(plan, usage, evidence, scale~, rounding~)` performs both checks. Use this before accepting external evidence.
- `encode_evidence` serializes all typed record fields in a stable order. `decode_evidence` validates the versioned shape, field types, resource limits, duplicate keys and unsupported fields. Decoding alone does not mean that a report is semantically valid. The decoder intentionally preserves forged claims so the verifier can identify the inconsistency.

The evidence schema has exactly `schema`, `calculation`, `settlement`. Calculation contains `plan_id`, `plan_version`, `currency`, `unit`, `usage`, `lines`, `total`; usage uses the complete `jieheng.usage.v1` object. Lines contain `tier`, `from_exclusive`, `to_inclusive`, `quantity`, `unit_price`, `subtotal`. Settlement contains `currency`, `scale`, `rounding`, `minor_units`, `amount`, `delta`. Only bounded indices/scales are JSON numbers; quantities and monetary values remain strings. See the complete [S3 record](../examples/s3/evidence.json).

## Correctness details

Let `u = 10^-scale`, `a` be the settled amount and `t` the exact nonnegative total. The verifier checks these rounding intervals using integer arithmetic in units of `10^-18`:

| Rule | Required interval |
| --- | --- |
| Down | `-u < a - t <= 0` |
| Up | `0 <= a - t < u` |
| HalfUp | `-u < 2(a - t) <= u` |
| HalfEven | `-u <= 2(a - t) <= u`; a tie requires an even minor-unit integer |

The rating implementation instead divides the exact total by the settlement unit and selects the integer quotient or its successor. Tests cross-check both formulations across 100 fractional prices, five scales and all four policies (2,000 combinations), including ties. Further tests tamper with identities, boundaries, missing/duplicated lines, equal-price boundaries, quantities, prices, subtotals, totals, policy, amount formatting and delta.

Encoding normalizes accepted price decimals and whitespace, not their numeric meaning. Evidence produced by the library uses canonical decimals and is stable under encode/decode/encode. No cryptographic integrity, performance bound, global currency compliance or equivalence to a complete vendor invoice is claimed.
