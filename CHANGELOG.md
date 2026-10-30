# Change log

## 0.8.0 — current source version

This is a source release candidate; this file does not assert registry publication.

- Unified technical acceptance runs all verification stages against one isolated commit and records stage failures and source identity; the evidence index maps implemented workflows to APIs, tests and examples.

- Complete-window catalog migration audits: stable date partitions, explicit structural blockers and review changes, archived report verification and CLI gates.
- Complete customer-period mixed-bill replay across catalog versions, preserving per-item settlement and all source evidence.
- Exact absolute and relative per-snapshot increase policies, including explicit zero-baseline behavior.
- Existing v1 single-plan, evidence, bill and comparison exchanges retain their checked-in canonical output.
- Packaging excludes development workspaces and nested consumer modules; package-archive consumption is checked independently.
- Seeded generated correctness checks add independent bounded pricing/rounding/quota oracles, mutation rejection, one-case replay and backend fingerprint comparison.
- Release-runtime benchmarks cover nine pricing, verification and catalog workloads, with source manifests and explicit whole-process RSS availability.

## Earlier source milestones

0.7.0 added catalog date-coverage checks, verified Markdown statements, strict JSON depth guarding, an independent consumer module and reproducible Git-snapshot verification. Earlier commits introduced graduated/volume pricing, explicit settlement, minimums, packages, dated catalogs, comparisons, bounded price analysis and budget quotas.

Historical source versions are not evidence of published Mooncakes releases. See Git history and CI for implementation and validation records.
