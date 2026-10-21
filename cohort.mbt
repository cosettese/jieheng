///|
/// One comparison per trusted usage, in input order. Totals sum separately
/// settled customer-period amounts: never round a cohort-wide exact total.
pub(all) struct CohortComparison {
  rows : Array[Comparison]
  baseline_exact : String
  candidate_exact : String
  baseline_settled : String
  candidate_settled : String
  exact_delta : String
  settled_delta : String
} derive(Debug, Eq)

///|
pub extend CohortComparison with Debug::{to_repr}

///|
pub extend CohortComparison with Eq::{equal, not_equal}

///|
fn check_cohort(usages : ArrayView[Usage]) -> Unit raise PricingError {
  if usages.length() == 0 || usages.length() > 256 {
    invalid(
      "size", "cohort.usages", "provide 1 to 256 already aggregated snapshots",
    )
  }
  let seen : Map[String, Map[String, Unit]] = Map([])
  for i, usage in usages {
    check_usage(usage) catch {
      Invalid(code~, path~, message~) =>
        raise Invalid(code~, path="cohort.usages[\{i}]." + path, message~)
    }
    let periods = match seen.get(usage.customer) {
      Some(periods) => periods
      None => {
        let periods = Map([])
        seen[usage.customer] = periods
        periods
      }
    }
    if periods.contains(usage.period) {
      invalid(
        "duplicate",
        "cohort.usages[\{i}]",
        "aggregate each customer and period once; duplicate snapshots are not added or discarded",
      )
    }
    periods[usage.period] = ()
  }
}

///|
/// Compare a cohort under one compatible pair of plans and settlement policy.
/// All-or-nothing: malformed or duplicate snapshots reject the whole request.
///
/// ```mbt check
/// test {
///   let plan = @jieheng.compile_plan(
///     id="api",
///     version="v1",
///     metric="calls",
///     unit="call",
///     currency="USD",
///     tiers=[{ up_to: None, unit_price: "0.004", }],
///   )
///   let report = @jieheng.compare_cohort(
///     plan,
///     plan,
///     [{ customer: "acme", metric: "calls", period: "2026-10", quantity: "1", }],
///     scale=2,
///     rounding=HalfEven,
///   )
///   inspect(report.baseline_exact, content="0.004")
///   inspect(report.baseline_settled, content="0")
/// }
/// ```
pub fn compare_cohort(
  baseline : Plan,
  candidate : Plan,
  usages : ArrayView[Usage],
  scale~ : Int32,
  rounding~ : Rounding,
) -> CohortComparison raise PricingError {
  comparable(baseline, candidate)
  check_cohort(usages)
  let rows : Array[Comparison] = []
  for i, usage in usages {
    rows.push(
      compare_plans(baseline, candidate, usage, scale~, rounding~) catch {
        Invalid(code~, path~, message~) =>
          raise Invalid(code~, path="cohort.usages[\{i}]." + path, message~)
      },
    )
  }
  let report = cohort_totals(rows[:])
  verify_cohort(baseline, candidate, usages, report, scale~, rounding~)
  report
}

///|
fn cohort_totals(
  rows : ArrayView[Comparison],
) -> CohortComparison raise PricingError {
  let mut be = 0N
  let mut ce = 0N
  let mut bs = 0N
  let mut cs = 0N
  for row in rows {
    be += amount_atoms(row.baseline.calculation.total, "cohort.baseline_exact")
    ce += amount_atoms(
      row.candidate.calculation.total,
      "cohort.candidate_exact",
    )
    bs += amount_atoms(
      row.baseline.settlement.amount,
      "cohort.baseline_settled",
    )
    cs += amount_atoms(
      row.candidate.settlement.amount,
      "cohort.candidate_settled",
    )
  }
  // Accumulation must remain within the existing 60-digit amount envelope.
  for total in [be, ce, bs, cs] {
    ignore(amount_atoms(format_atoms(total), "cohort.totals"))
  }
  {
    rows: rows.to_owned(),
    baseline_exact: format_atoms(be),
    candidate_exact: format_atoms(ce),
    baseline_settled: format_atoms(bs),
    candidate_settled: format_atoms(cs),
    exact_delta: format_atoms(ce - be),
    settled_delta: format_atoms(cs - bs),
  }
}

///|
/// Independently verify every row and its binding to trusted input order,
/// then check exact conservation of all totals and both signed differences.
pub fn verify_cohort(
  baseline : Plan,
  candidate : Plan,
  usages : ArrayView[Usage],
  report : CohortComparison,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  comparable(baseline, candidate)
  check_cohort(usages)
  if report.rows.length() != usages.length() {
    invalid(
      "coverage", "cohort.rows", "exactly one ordered comparison is required for each trusted snapshot",
    )
  }
  for i, usage in usages {
    verify_comparison(
      baseline,
      candidate,
      usage,
      report.rows[i],
      scale~,
      rounding~,
    ) catch {
      Invalid(code~, path~, message~) =>
        raise Invalid(code~, path="cohort.rows[\{i}]." + path, message~)
    }
  }
  let expected = cohort_totals(report.rows[:])
  if report.baseline_exact != expected.baseline_exact ||
    report.candidate_exact != expected.candidate_exact ||
    report.baseline_settled != expected.baseline_settled ||
    report.candidate_settled != expected.candidate_settled ||
    report.exact_delta != expected.exact_delta ||
    report.settled_delta != expected.settled_delta {
    invalid(
      "total", "cohort.totals", "totals must conserve the verified row amounts; deltas are candidate minus baseline",
    )
  }
}
