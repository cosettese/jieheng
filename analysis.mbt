///|
pub(all) struct PlanRef {
  id : String
  version : String
} derive(Debug, Eq)

///|
pub extend PlanRef with Debug::{to_repr}

///|
pub extend PlanRef with Eq::{equal, not_equal}

///|
/// Inclusive integer interval. For q in [from_quantity,to_quantity], each exact
/// total equals its value at from_quantity plus step * (q-from_quantity).
pub(all) struct PriceSpan {
  from_quantity : String
  to_quantity : String
  baseline_total : String
  candidate_total : String
  baseline_step : String
  candidate_step : String
} derive(Debug, Eq)

///|
pub extend PriceSpan with Debug::{to_repr}

///|
pub extend PriceSpan with Eq::{equal, not_equal}

///|
/// Candidate minus baseline over every integer quantity from zero to limit.
/// Extreme ties select the smallest quantity. This is exact, unsettled pricing.
pub(all) struct PriceAnalysis {
  baseline : PlanRef
  candidate : PlanRef
  currency : String
  metric : String
  unit : String
  limit : String
  spans : Array[PriceSpan]
  minimum_delta : String
  minimum_at : String
  maximum_delta : String
  maximum_at : String
} derive(Debug, Eq)

///|
pub extend PriceAnalysis with Debug::{to_repr}

///|
pub extend PriceAnalysis with Eq::{equal, not_equal}

///|
fn curve_piece(
  plan : Plan,
  q : BigInt,
  limit : BigInt,
) -> (BigInt, BigInt, BigInt) {
  let mut lower = 0N
  let mut prefix = 0N
  for tier in plan.tiers {
    let bound = match tier.up_to {
      Some(n) => n
      None => limit
    }
    if q <= bound {
      let end = if bound < limit { bound } else { limit }
      let total = match plan.mode {
        Graduated => prefix + (q - lower) * tier.price
        Volume => q * tier.price
      }
      return (end, total, tier.price)
    }
    prefix += (bound - lower) * tier.price
    lower = bound
  }
  abort("validated plan always ends in an unbounded tier")
}

///|
fn analysis_extremes(
  spans : ArrayView[PriceSpan],
) -> (String, String, String, String) raise PricingError {
  let mut minimum = 0N
  let mut maximum = 0N
  let mut min_at = 0N
  let mut max_at = 0N
  for span in spans {
    let from = natural(span.from_quantity, "analysis.span.from")
    let to = natural(span.to_quantity, "analysis.span.to")
    let start = amount_atoms(span.candidate_total, "analysis.candidate_total") -
      amount_atoms(span.baseline_total, "analysis.baseline_total")
    let slope = decimal(span.candidate_step, "analysis.candidate_step") -
      decimal(span.baseline_step, "analysis.baseline_step")
    for (q, delta) in [(from, start), (to, start + slope * (to - from))] {
      if delta < minimum {
        minimum = delta
        min_at = q
      }
      if delta > maximum {
        maximum = delta
        max_at = q
      }
    }
  }
  (
    format_atoms(minimum),
    min_at.to_string(),
    format_atoms(maximum),
    max_at.to_string(),
  )
}

///|
/// Partition the entire bounded integer domain at both plans' tier transitions.
/// Affine extrema occur at endpoints; volume cliffs remain separate spans.
///
/// ```mbt check
/// test {
///   let a = @jieheng.compile_plan(
///     id="api",
///     version="v1",
///     metric="calls",
///     unit="call",
///     currency="USD",
///     tiers=[{ up_to: None, unit_price: "1", }],
///   )
///   let r = @jieheng.analyze_prices(a, a, "999999999999999999999999999999")
///   inspect(r.spans.length(), content="1")
///   inspect(r.maximum_delta, content="0")
/// }
/// ```
pub fn analyze_prices(
  baseline : Plan,
  candidate : Plan,
  limit : String,
) -> PriceAnalysis raise PricingError {
  comparable(baseline, candidate)
  let cap = natural(limit, "analysis.limit")
  let spans : Array[PriceSpan] = []
  let mut from = 0N
  while from <= cap {
    let (be, bt, bs) = curve_piece(baseline, from, cap)
    let (ce, ct, cs) = curve_piece(candidate, from, cap)
    let to = if be < ce { be } else { ce }
    spans.push({
      from_quantity: from.to_string(),
      to_quantity: to.to_string(),
      baseline_total: format_atoms(bt),
      candidate_total: format_atoms(ct),
      baseline_step: format_atoms(bs),
      candidate_step: format_atoms(cs),
    })
    from = to + 1N
  }
  let (minimum_delta, minimum_at, maximum_delta, maximum_at) = analysis_extremes(
    spans[:],
  )
  let report = {
    baseline: { id: baseline.id, version: baseline.version, },
    candidate: { id: candidate.id, version: candidate.version, },
    currency: baseline.currency,
    metric: baseline.metric,
    unit: baseline.unit,
    limit,
    spans,
    minimum_delta,
    minimum_at,
    maximum_delta,
    maximum_at,
  }
  verify_analysis(baseline, candidate, limit, report)
  report
}

///|
/// Independent truncated-range sum and selected-tier slope. Does not call the
/// producer's prefix recurrence, rate, or curve_piece.
fn check_curve_value(plan : Plan, q : BigInt) -> (BigInt, BigInt) {
  let mut sum = 0N
  let mut previous = 0N
  let mut slope = 0N
  let mut selected = false
  for tier in plan.tiers {
    let upper = match tier.up_to {
      Some(n) => if q < n { q } else { n }
      None => q
    }
    if upper > previous {
      sum += (upper - previous) * tier.price
    }
    if !selected && (tier.up_to is None || (tier.up_to is Some(n) && q <= n)) {
      slope = tier.price
      selected = true
    }
    match tier.up_to {
      Some(n) => previous = n
      None => ()
    }
  }
  (
    match plan.mode {
      Graduated => sum
      Volume => q * slope
    },
    slope,
  )
}

///|
/// Prove complete canonical coverage, both affine functions and endpoint extrema
/// against trusted plans. No sampled-quantity assumption or solver reexecution.
pub fn verify_analysis(
  baseline : Plan,
  candidate : Plan,
  limit : String,
  report : PriceAnalysis,
) -> Unit raise PricingError {
  comparable(baseline, candidate)
  let cap = natural(limit, "analysis.limit")
  if report.baseline != { id: baseline.id, version: baseline.version, } ||
    report.candidate != { id: candidate.id, version: candidate.version, } ||
    report.currency != baseline.currency ||
    report.metric != baseline.metric ||
    report.unit != baseline.unit ||
    report.limit != limit {
    invalid(
      "identity", "analysis", "plan references, currency, metric, unit and limit must match trusted inputs",
    )
  }
  if report.spans.length() == 0 || report.spans.length() > 2047 {
    invalid("size", "analysis.spans", "expected 1 to 2047 spans")
  }
  let mut expected_from = 0N
  for i, span in report.spans {
    let path = "analysis.spans[\{i}]"
    let from = natural(span.from_quantity, path + ".from_quantity")
    let to = natural(span.to_quantity, path + ".to_quantity")
    if from != expected_from || from > to || to > cap {
      invalid(
        "coverage", path, "spans must cover zero through the trusted limit exactly once, in order",
      )
    }
    let mut expected_to = cap
    for plan in [baseline, candidate] {
      for tier in plan.tiers {
        if tier.up_to is Some(n) && n >= from && n < expected_to {
          expected_to = n
        }
      }
    }
    if to != expected_to {
      invalid(
        "boundary", path, "split at exactly the next tier transition of either trusted plan",
      )
    }
    let (bt, bs) = check_curve_value(baseline, from)
    let (ct, cs) = check_curve_value(candidate, from)
    if span.baseline_total != format_atoms(bt) ||
      span.candidate_total != format_atoms(ct) ||
      span.baseline_step != format_atoms(bs) ||
      span.candidate_step != format_atoms(cs) {
      invalid(
        "curve", path, "exact values and per-unit slopes must match the trusted plans",
      )
    }
    expected_from = to + 1N
  }
  if expected_from != cap + 1N {
    invalid(
      "coverage", "analysis.spans", "missing the end of the trusted quantity domain",
    )
  }
  let (min_delta, min_at, max_delta, max_at) = analysis_extremes(
    report.spans[:],
  )
  if report.minimum_delta != min_delta ||
    report.minimum_at != min_at ||
    report.maximum_delta != max_delta ||
    report.maximum_at != max_at {
    invalid(
      "extrema", "analysis", "extrema must cover all span endpoints and choose the smallest quantity on ties",
    )
  }
}
