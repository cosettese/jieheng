# Change log

## 0.8.0 — current source version

This is a source release candidate; this file does not assert registry publication.

- Complete-window catalog migration audits: stable date partitions, explicit structural blockers and review changes, archived report verification and CLI gates.
- Complete customer-period mixed-bill replay across catalog versions, preserving per-item settlement and all source evidence.
- Exact absolute and relative per-snapshot increase policies, including explicit zero-baseline behavior.
- Existing v1 single-plan, evidence, bill and comparison exchanges retain their checked-in canonical output.
- Packaging excludes development workspaces and nested consumer modules; package-archive consumption is checked independently.

## Earlier source milestones

0.7.0 added catalog date-coverage checks, verified Markdown statements, strict JSON depth guarding, an independent consumer module and reproducible Git-snapshot verification. Earlier commits introduced graduated/volume pricing, explicit settlement, minimums, packages, dated catalogs, comparisons, bounded price analysis and budget quotas.

Historical source versions are not evidence of published Mooncakes releases. See Git history and CI for implementation and validation records.
