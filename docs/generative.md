# Reproducible generated correctness checks

The internal generator uses a specified xorshift32 stream and independent integer-thousandth oracles. It is bounded testing, not a proof or an exhaustive search. A zero seed explicitly maps to 2463534242; all reported seeds remain the original input.

~~~text
moon run cmd/generative --target wasm -- 1 32
moon run cmd/generative --target wasm -- 1 32 --case 31
moon run scripts/generative.mbtx portable
~~~

The all profile additionally executes Native. The matrix runs seeds 0, 1 and 4294967295 with 32 cases each on every requested backend, plus a standalone replay of seed 1/case 31. Entire summaries, check counts and noncryptographic fingerprints must match between backends. The generator format is jieheng.generated.v1; retain the source revision with a failure because changing generation rules changes the meaning of a seed.

Each generated contract has 1–6 tiers with increasing integer boundaries no greater than 35; prices are 0..99 thousandths and quantities cover every integer 0..40, including both sides of every finite boundary. Modes, minimums, zero policies, package sizes, budgets, four rounding modes and precisions 0/1/2/3/18 vary deterministically.

Checks include:

- a per-unit reference calculation for graduated/volume prices, without using the producer's partition formula;
- independently derived integer rounding and minimum-spend amounts;
- exhaustive bounded forward search for the global affordable maximum and first unaffordable prefix, including volume discount cliffs;
- package minimality by repeated capacity addition, and mixed bills by summing separately settled items;
- plan/evidence/bill round trips, trusted verification, unknown fields, duplicate keys, forged totals and successful recovery after rejected input.

Existing handwritten tests remain responsible for maximum tier counts, 30/60-digit integers, full 18-digit prices, calendar edge cases, catalog replay and resource envelopes. The generator deliberately does not claim that its small numeric domain covers those dimensions.

The CLI accepts a UInt32 decimal seed, count 1..4096, and optional zero-based case index. Failure prints seed, case and phase plus a one-case replay command. All randomness is consumed while creating each case, so skipping earlier case execution preserves the selected input.

The matrix saves raw logs and failure.json (seed, backend, argv, stdout/stderr, reference output, toolchain and Git head) before stopping. Success saves result.json and marks whether the working tree was clean. Temporary evidence is retained for diagnosis. Fingerprints identify generated traces; they are not signatures or performance scores.

## Catalog migration and complete-bill replay

~~~text
moon run cmd/generative --target wasm -- catalog 1 32
moon run cmd/generative --target wasm -- catalog 1 32 --case 31
~~~

The matrix command runs both pricing and catalog domains, each with three seeds and a standalone selected-case replay. Existing pricing output and golden fingerprints remain unchanged. Catalog output has schema jieheng.generated-catalog.v1 and its own generator stream; failure.json and log names identify the domain. The [acceptance artifacts](acceptance.md) retain the seed/revision, command, raw output and reference summary on CI.

Each catalog case uses eight consecutive civil days from one of four explicit calendars: the 2000 leap-century boundary, the non-leap 1900 century, the 2024 leap day, or the 2024/2025 year boundary. Integer day-slot enumeration is the oracle; it does not call the producer's calendar-selection or sorted-boundary helpers. The migration pair contains one or two metrics, 1–3 day versions, optional gaps/open tails, metric addition/removal, currency/unit/identity/version changes, graduated/volume/package models, minimums and zero policies. Expected maximal spans and every ordered change class are built from daily selections, then compared with the whole report and checked for exactly one span per metric/day.

A separate complete pair has two metrics and four customer-period snapshots at day slots 0/2/4/7. Quantities include zero and generated values 0..20; tier bounds and package sizes are 1..5, prices and minimums 0..99 thousandths, with five settlement precisions and all four rounding modes. The reference enumerates individual units or repeatedly adds package capacity, applies minimums and independently settles each item. It checks every row, exact/settled aggregates, signed deltas, increase/decrease counts and the first largest increase. It does not use rate, rate_bill or the replay producer as its expected-value calculator.

Policy checks use independently derived settled units and integer cross-products for percentages 0/0.1/1/12.5/50/100/1000 and absolute caps 0/100. The exact observed maximum is accepted as an absolute limit; one minor unit below it is rejected when positive. Dedicated tests exercise exact 12.5% equality, a 12.499% failure and a positive change from a zero baseline. Other tests deliberately corrupt reports to establish that the references detect errors without invoking the library verifier.

Generated cases also check catalog/migration/replay round trips, deterministic recovery, invalid-century dates, overlapping/duplicate timelines, incomplete bills, duplicate customers, malformed spans, forged summaries, duplicate JSON keys and unknown data. These bounded checks complement the full numeric/calendar/resource-limit tests; they do not exhaust all dates, metric counts or contracts. All random draws occur before execution, preserving single-case replay independently of earlier successful cases.
