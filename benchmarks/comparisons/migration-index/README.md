# Migration timeline indexing observations

Recorded on 2026-10-30 on one Windows AMD64 host, Intel64 Family 6 Model 183 Stepping 1, with moon 0.1.20261020, moonc v0.10.16+b1a0e846e and Node v24.20.0. These are shared-host synthetic observations, not a general speedup guarantee or a regression threshold.

## Change and hypothesis

Previously, each migration span selected entries or checked the next boundary by scanning every catalog entry and calling tariff_info to filter metrics. That helper also validates/parses metered minimums. The verifier scanned both 512-entry catalogs for each of 512 spans: up to 524,288 metadata calls just for those two boundary scans, plus separate classification work. The code now groups original entry indices by metric once per operation, then visits only that metric's timeline. Filtering metadata work becomes proportional to input entries; classification still inspects selected rules per span. Date searches remain scans and boundary deduplication remains a separate cost; this is not a claim of a fully linear algorithm.

The index is local to the operation and adds bounded O(N) temporary storage. Public API, report order, global entry indices and classifications are preserved. The generator still sorts boundaries and the verifier independently searches for the next trusted boundary; they share the metadata index and existing classification rules, not a second complete business-rule implementation.

## Measurement protocol and complete data

The chronological order was A1 → B1 → A2 → B2, with five adaptive batch samples per workload in each complete release run. A is original source d52656a015c5c68046b3d4c61300198e617d2348; A2 was run from a detached local clone of that commit. B is the indexed implementation, measured before committing; its actual source blobs and dirty-checkout status are retained. git_head_context for B identifies its parent context, not the optimized source commit. No benchmark workload or driver implementation was changed between A and B.

- [before-first.json](before-first.json): A1, original checkout.
- [before-control.json](before-control.json): A2, original source in an isolated clone.
- [after-first.json](after-first.json): B1, first indexed measurement.
- [after-repeat.json](after-repeat.json): B2, repeated indexed measurement.
- [summary.json](summary.json): all nine workloads for all three backends, medians converted from microseconds to milliseconds. File order is A1/A2/B1/B2; chronological order is separately recorded.

OS, architecture, CPU identifier, toolchain, Node, fixture dimensions, run counts and workload identities were checked equal across the four records. Raw results retain every workload's minimum, maximum, median, mean, dispersion and batch size; no unfavorable control workload was discarded. Raw Git blob hashes can differ with line endings. Windows RSS is uncollected in all four records. Native timing and memory improvements were not compared here; CI separately runs Native and collects platform-available whole-process RSS.

## Observed migration medians

Milliseconds per operation, rounded to three decimals. Each cell is one run's five-sample median, not a single request latency or a confidence interval.

| Backend / operation | A1 | A2 | B1 | B2 |
| --- | ---: | ---: | ---: | ---: |
| Wasm / migration-512 | 200.232 | 310.000 | 6.867 | 9.438 |
| Wasm / verify-migration-512 | 359.040 | 542.697 | 18.038 | 22.494 |
| Wasm-GC / migration-512 | 39.319 | 68.719 | 2.828 | 2.554 |
| Wasm-GC / verify-migration-512 | 67.286 | 137.631 | 7.680 | 6.314 |
| JavaScript / migration-512 | 23.218 | 46.671 | 4.696 | 8.090 |
| JavaScript / verify-migration-512 | 47.937 | 141.794 | 11.918 | 17.605 |

Both original and optimized runs vary substantially on this machine. The observations support avoiding repeated metadata parsing for this workload; they do not establish tail latency, production throughput, performance on other inputs, or a cross-platform ranking. See summary.json for the seven unchanged control workloads and the raw records before interpreting ratios.

## Reproduce and verify behavior

Run moon run scripts/benchmark.mbtx portable baseline from a clean checkout of the original commit and from the revision containing this record; repeat alternately on the same host without concurrent builds/tests. Use a fresh JIEHENG_EVIDENCE_DIR for each run, or retain each printed temporary directory. The original driver is available in that commit. Use all instead of portable only with a working C toolchain; do not infer Native runtime success from compilation.

Run moon run scripts/acceptance.mbtx portable HEAD for current correctness and packaging evidence, or all HEAD for Native too. The interleaved-timeline regression checks first-seen metric order, original global indices and the existing selection diagnostic. Existing canonical JSON examples, hand-written migration cases and both generated domains must continue to pass with unchanged fingerprints. No persistent catalog cache, schema change or numeric-limit change is introduced.
