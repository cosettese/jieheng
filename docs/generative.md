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
