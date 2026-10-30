# Reproducible runtime baseline

When run through the unified acceptance entry, CI retains the benchmark JSON, resource logs and BENCHMARK_RESULT line inside the downloadable evidence artifact, rather than echoing every nested log to the Actions console. See [acceptance artifacts](acceptance.md).

This harness measures existing public operations. It is not a claim of a speed advantage, an SLA, a production capacity estimate or a comparison with another library.

~~~text
moon run scripts/benchmark.mbtx portable baseline
moon run scripts/benchmark.mbtx all baseline
moon run scripts/benchmark.mbtx portable smoke
~~~

Portable executes Wasm, Wasm-GC and JavaScript. All additionally builds and actually runs Native; a missing compiler or runtime fails the command. Smoke uses one sample to validate the workflow; baseline uses five samples per workload. CI executes the all baseline on Linux, Windows and macOS. The script prints the retained result.json path and a BENCHMARK_RESULT JSON line for CI log extraction. Build logs, runtime JSON and resource logs are retained alongside it; any failed build, run or resource parse aborts the command.

## Workloads and fixture checks

All fixtures are synthetic and versioned as synthetic-v1. Setup and precondition assertions are outside each timed closure. Public API validation performed inside the called operation remains included.

| Workload | Input and measured operation |
| --- | --- |
| rate-1 / rate-64 / rate-1024 | Graduated plan with 1/64/1024 occupied tiers, price 0.001 per unit, quantity equal to tier count; rate |
| verify-1024 | Same 1024-line calculation, scale 2/HalfEven settlement; verify_evidence |
| bill-64 | 32 metered and 32 packaged items with distinct metrics; rate_bill |
| verify-bill-64 | Same mixed bill; verify_bill |
| catalog-rate-512 | Four metrics with 128 consecutive yearly versions each, date 2127-06-30; rate_catalog |
| migration-512 | Compare that catalog with itself over 2020-01-01 through 2148-01-01; audit_catalog_migration, 512 spans |
| verify-migration-512 | Verify that full-window report; verify_catalog_migration |

The script checks known totals and trusted verification before timing: tier totals 0.001/0.064/1.024, mixed exact total 0.576 and settled amount 0.64, catalog usage total 0.004, and migration span count 512. A precondition failure prevents a result from being reported. These cases exercise resource limits and representative composition; they are not all possible worst cases or a replay of real customer traffic.

## Timing and memory scope

The workload uses the official moonbitlang/core/bench API, adaptive batch calibration/warmup and Bench::keep. Each of five samples is an average per operation within its batch. Raw summaries retain batch size, run count, minimum, maximum, mean, median and dispersion; units are microseconds per operation. Five samples do not support strong tail-latency claims. The runtime, JIT, allocator, host load and toolchain affect results; compare like-for-like repeated runs before drawing conclusions. See the [official benchmark guide](https://docs.moonbitlang.com/en/stable/language/benchmarks.html).

Build completes before measurement. The wrapper invokes the compiled artifact directly through moonrun, Node or the Native executable. On Linux, GNU /usr/bin/time -v reports peak RSS in KiB, converted to bytes. On macOS, /usr/bin/time -l reports bytes. This is the peak of the entire runtime process across all nine workloads, including fixtures, calibration, runtime overhead and JSON serialization; it excludes compilation and is not per-operation allocation. Parsing failures are errors, never zero measurements. Windows currently reports peak_rss_bytes=null and memory_status=not-collected.

## Recorded evidence

Checked-in results are under [benchmarks/baselines](../benchmarks/baselines/README.md). Each records OS, architecture, CPU identifier, Node and MoonBit versions, backend, build mode, workload dimensions, statistics and memory availability. git_head_context is the checkout's base commit, not an assertion that a dirty checkout equals that commit. source_manifest records raw Git blob hashes of the actual source, configuration, interfaces and automation files; working_tree_clean reports whether local changes existed. Raw hashes can differ with line endings. They permit source identification, not binary reproducibility or a performance guarantee.

The harness adds no performance regression threshold: stable dedicated hardware and a variability study are needed before enforcing one. No core API behavior or numeric limits are changed by benchmarking.
