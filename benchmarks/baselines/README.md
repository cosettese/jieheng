# Recorded baselines

Reproduce with the commands and scope in [docs/benchmarks.md](../../docs/benchmarks.md). JSON files contain the complete official benchmark summaries and exact working-source hashes, rather than only selected best timings.

- [windows-portable.json](windows-portable.json): recorded locally on 2026-10-30, release Wasm/Wasm-GC/JavaScript, five samples per workload. Windows runtime memory is explicitly uncollected. The benchmark additions were uncommitted when measured; git_head_context identifies their parent, and source_manifest identifies the measured files.
- [linux-ci.json](linux-ci.json): Intel Xeon Platinum 8370C, x86_64, release execution of all four backends, including Native and whole-process RSS.
- [macos-ci.json](macos-ci.json): Apple M1 virtual runner, arm64, release execution of all four backends, including Native and whole-process RSS.

Both CI records were extracted without changing their JSON payload from [run 41018763161](https://github.com/cosettese/jieheng/actions/runs/41018763161), on 2026-10-30. They identify clean source revision 4ded4682d810405377593afb7b9f79968b5be241 and retain five samples per workload. Runner load is uncontrolled; these are observations, not regression limits.

For orientation, the Linux Native record reports the following medians; the JSON retains all nine operations, raw summary statistics and other backends:

| Operation | Median milliseconds per operation |
| --- | ---: |
| 1024 occupied tiers: rate | 1.881 |
| 64 mixed items: rate_bill | 1.994 |
| 512 catalog entries: rate_catalog | 0.650 |
| 512 migration spans: audit | 111.360 |
| 512 migration spans: verify | 219.026 |

Linux Native peak RSS was 3,973,120 bytes for the entire nine-workload process, including setup and warmup. This cannot be attributed to any single operation and is not an allocation measurement.

These synthetic measurements are an initial reference on the recorded machine. Do not compare operating systems or backends without accounting for hardware, runtime and load. CI runs all four backends, including actual Native execution; its retained BENCHMARK_RESULT log line includes Linux/macOS whole-process RSS.
