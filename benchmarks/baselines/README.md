# Recorded baselines

Reproduce with the commands and scope in [docs/benchmarks.md](../../docs/benchmarks.md). JSON files contain the complete official benchmark summaries and exact working-source hashes, rather than only selected best timings.

- windows-portable.json: recorded locally on 2026-10-30, release Wasm/Wasm-GC/JavaScript, five samples per workload. Windows runtime memory is explicitly uncollected. The benchmark additions were uncommitted when measured; git_head_context identifies their parent, and source_manifest identifies the measured files.

These synthetic measurements are an initial reference on the recorded machine. Do not compare operating systems or backends without accounting for hardware, runtime and load. CI runs all four backends, including actual Native execution; its retained BENCHMARK_RESULT log line includes Linux/macOS whole-process RSS.
