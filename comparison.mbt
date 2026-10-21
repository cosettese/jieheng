///|
/// Candidate minus baseline, for one identical aggregated usage snapshot.
/// Deltas are signed exact decimal strings. Both sides retain complete evidence.
pub(all) struct Comparison {
  baseline : Evidence
  candidate : Evidence
  exact_delta : String
  settled_delta : String
} derive(Debug, Eq)

///|
pub extend Comparison with Debug::{to_repr}

///|
pub extend Comparison with Eq::{equal, not_equal}

///|
/// Compare compatible plans at the same usage and settlement policy.
/// Settled delta is the difference of two settled amounts, not a rounded delta.
///
/// ```mbt check
/// test {
///   let before = @jieheng.compile_plan(
///     id="api",
///     version="v1",
///     metric="calls",
///     unit="call",
///     currency="USD",
///     tiers=[{ up_to: None, unit_price: "0.004", }],
///   )
///   let after = @jieheng.compile_plan(
///     id="api",
///     version="v2",
///     metric="calls",
///     unit="call",
///     currency="USD",
///     tiers=[{ up_to: None, unit_price: "0.006", }],
///   )
///   let report = @jieheng.compare_plans(
///     before,
///     after,
///     { customer: "acme", metric: "calls", period: "2026-10", quantity: "1", },
///     scale=2,
///     rounding=HalfEven,
///   )
///   inspect(report.exact_delta, content="0.002")
///   inspect(report.settled_delta, content="0.01")
/// }
/// ```
pub fn compare_plans(
  baseline : Plan,
  candidate : Plan,
  usage : Usage,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Comparison raise PricingError {
  comparable(baseline, candidate)
  let before = rate(baseline, usage)
  let after = rate(candidate, usage)
  let before_settled = settle(before, scale~, rounding~)
  let after_settled = settle(after, scale~, rounding~)
  let report = {
    baseline: { calculation: before, settlement: before_settled, },
    candidate: { calculation: after, settlement: after_settled, },
    exact_delta: format_atoms(
      amount_atoms(after.total, "candidate.total") -
      amount_atoms(before.total, "baseline.total"),
    ),
    settled_delta: format_atoms(
      amount_atoms(after_settled.amount, "candidate.amount") -
      amount_atoms(before_settled.amount, "baseline.amount"),
    ),
  }
  verify_comparison(baseline, candidate, usage, report, scale~, rounding~)
  report
}

///|
fn comparable(baseline : Plan, candidate : Plan) -> Unit raise PricingError {
  if baseline.currency != candidate.currency {
    invalid(
      "currency", "comparison", "both plans must use the same currency; no FX conversion is performed",
    )
  }
  if baseline.metric != candidate.metric || baseline.unit != candidate.unit {
    invalid(
      "unit", "comparison", "both plans must use the same metric and unit; no unit conversion is performed",
    )
  }
}

///|
/// Validate both sides against trusted inputs and recompute signed differences.
pub fn verify_comparison(
  baseline : Plan,
  candidate : Plan,
  usage : Usage,
  report : Comparison,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  comparable(baseline, candidate)
  verify_evidence(baseline, usage, report.baseline, scale~, rounding~) catch {
    Invalid(code~, path~, message~) =>
      raise Invalid(code~, path="comparison.baseline." + path, message~)
  }
  verify_evidence(candidate, usage, report.candidate, scale~, rounding~) catch {
    Invalid(code~, path~, message~) =>
      raise Invalid(code~, path="comparison.candidate." + path, message~)
  }
  let expected = amount_atoms(
      report.candidate.calculation.total,
      "candidate.total",
    ) -
    amount_atoms(report.baseline.calculation.total, "baseline.total")
  if report.exact_delta != format_atoms(expected) {
    invalid(
      "delta", "comparison.exact_delta", "expected candidate exact total minus baseline exact total",
    )
  }
  let expected_settled = amount_atoms(
      report.candidate.settlement.amount,
      "candidate.amount",
    ) -
    amount_atoms(report.baseline.settlement.amount, "baseline.amount")
  if report.settled_delta != format_atoms(expected_settled) {
    invalid(
      "delta", "comparison.settled_delta", "expected candidate settled amount minus baseline settled amount",
    )
  }
}
