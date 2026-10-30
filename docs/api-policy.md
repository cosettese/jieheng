# Public API and compatibility policy

The public contract is the generated root pkg.generated.mbti plus each workflow's documented numeric/input limits. Start with the tested [quickstart](../quickstart.mbt.md); most applications need only one workflow, not every exported record.

| Need | Recommended path |
| --- | --- |
| One usage snapshot | compile_plan → rate → settle; retain trusted plan/usage |
| Archive external calculations | encode/decode_evidence → verify_evidence before accepting |
| Multiple pricing models | BillItem → rate_bill → verify_bill; use render_bill_markdown for explanations |
| Change a product's contract | audit_catalog_migration → verify_catalog_migration, then replay_catalogs → check_replay_policy |
| Bound spend | quote_quota or quote_bill_quota; retain first-unaffordable evidence |

Inputs are already aggregated integer quantities; currency is an explicit label. There is no implicit unit conversion, ISO currency lookup or money Float arithmetic. Typed output records are inspectable, not authenticated: their decoded structure alone is never sufficient for acceptance.

## Version rules

- Before 1.0, a minor source version can change public signatures or record fields, but any such change must be listed explicitly in CHANGELOG.md with a migration note. Patch changes preserve existing valid public calls; newly rejected malformed inputs and diagnostic changes are documented.
- The v1 JSON schema names are independent of the package version. Required field additions, field removals or changed numeric meaning require a new schema identifier and explicit migration. Accepted inputs never silently drop unknown data.
- Canonical output order and exact numeric strings are regression-checked. Preservation concerns accepted semantics and canonical output, not original input whitespace or insignificant decimal trailing zeroes.
- Diagnostic code/path categories are documented per workflow; error prose can improve. Applications should pattern-match PricingError::Invalid fields rather than scrape CLI prose.
- Generated interface files are reviewed, never hand-edited. CI checks formatting/interface drift and runs a separate consumer module.

The policy states maintenance intent, not a promise of perpetual compatibility or of capabilities outside the documented boundary. Tax, FX, payments, event aggregation and subscriptions remain outside this library.
