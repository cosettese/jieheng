# JSON exchange and file workflow

The library accepts only versioned, explicitly supported fields. JSON inputs are limited to 1,048,576 UTF-16 code units and 32 nesting levels. Every object is checked for duplicate keys after escape decoding. Unknown fields fail with `unknown`; they are never dropped. Whitespace and object field order do not affect semantics.

## Plan v1

`schema`, `id`, `version`, `metric`, `unit`, `currency`, `mode`, `tiers` are all required. `schema` must be `jieheng.plan.v1`, and `mode` must be `graduated`.

Each tier has exactly `up_to` and `unit_price`. A bound is a canonical integer string; `null` means unbounded. Every price is a plain nonnegative decimal string. The last tier must be unbounded; earlier bounds must increase strictly from zero. There are 1–1024 tiers. See [the complete example](../examples/stripe/plan.json).

`encode_plan(decode_plan(input))` emits deterministic schema-order JSON with normalized decimals. It preserves all accepted pricing semantics, not original whitespace or decimal trailing zeroes. Applying the same operation a second time produces identical bytes. No arbitrary metadata extension is supported in v1; keep provenance in an accompanying file.

## Usage v1

Exactly `schema`, `customer`, `metric`, `period`, `quantity` are required. `schema` must be `jieheng.usage.v1`. All other fields are strings. Quantity is already aggregated and must be an integer in `[0, 10^30 - 1]`. Labels are nonempty, contain no ASCII controls, and have at most 256 UTF-16 code units. This format does not ingest or deduplicate raw events or validate dates. See [the usage snapshot](../examples/stripe/usage.json).

## Command line

Run from the repository root with MoonBit v0.10.16 or a compatible stable toolchain:

```text
moon run cmd/rate --target wasm -- examples/stripe/plan.json examples/stripe/usage.json 2 half-even
```

Expected output:

```text
stripe-typographic-graduated@docs-2026-10-21
typographic-example / documentation-example / 20 font
tier 0: 5 x 7 = 35
tier 1: 5 x 6.5 = 32.5
tier 2: 10 x 6 = 60
exact: USD 127.5
settled: USD 127.50 (delta 0)
```

The four arguments are plan path, usage path, decimal settlement scale, and rounding rule (`half-even`, `half-up`, `down`, `up`). Quoted paths with spaces work normally. Files must be UTF-8; invalid encodings fail. The CLI reads bounded chunks and refuses inputs above 4 MiB, including files that grow during reading. The decoder independently enforces its text limit. File handles close on both success and failure; this is not a filesystem sandbox or a process-wide memory quota.

Only successful calculations are written to stdout. Invalid arguments, file failures, and pricing diagnostics propagate as errors with a nonzero process exit. Fix the indicated path and run again; the library retains no mutable session state after a failed input.

The pure library and demo support Wasm, Wasm-GC, JavaScript, and Native. The file CLI uses `moonbitlang/async` and supports **Wasm and Native**. It is not a browser program. Native execution needs the toolchain's supported compiler; v0.10.16 on Windows requires MSVC C++ Build Tools and Windows SDK. The core library does not perform I/O.
