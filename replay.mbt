///|
pub(all) struct CatalogReplayCase {
  on : String
  usages : Array[Usage]
} derive(Debug, Eq)

///|
pub extend CatalogReplayCase with Debug::{to_repr}

///|
pub extend CatalogReplayCase with Eq::{equal, not_equal}

///|
pub(all) struct CatalogReplayRow {
  on : String
  comparison : BillComparison
} derive(Debug, Eq)

///|
pub extend CatalogReplayRow with Debug::{to_repr}

///|
pub extend CatalogReplayRow with Eq::{equal, not_equal}

///|
/// Counts describe customer-period snapshots; exact totals are never rounded
/// across customers. The maximum is the greatest positive settled increase,
/// with the first input index winning ties; no increase gives zero and None.
pub(all) struct CatalogReplay {
  currency : String
  rows : Array[CatalogReplayRow]
  baseline_exact : String
  candidate_exact : String
  baseline_settled : String
  candidate_settled : String
  exact_delta : String
  settled_delta : String
  increased : Int32
  decreased : Int32
  unchanged : Int32
  max_increase : String
  max_increase_index : Int32?
} derive(Debug, Eq)

///|
pub extend CatalogReplay with Debug::{to_repr}

///|
pub extend CatalogReplay with Eq::{equal, not_equal}

///|
/// Per-snapshot settled-price limits. A percentage limit rejects any positive
/// change from a zero baseline, since no finite relative increase exists.
pub(all) struct ReplayPolicy {
  currency : String
  max_increase : String
  max_increase_percent : String?
} derive(Debug, Eq)

///|
pub extend ReplayPolicy with Debug::{to_repr}

///|
pub extend ReplayPolicy with Eq::{equal, not_equal}

///|
fn check_replay_cases(
  cases : ArrayView[CatalogReplayCase],
) -> Unit raise PricingError {
  if cases.length() == 0 || cases.length() > 256 {
    invalid(
      "size", "replay.cases", "provide 1 to 256 complete customer-period snapshots",
    )
  }
  let seen : Map[String, Map[String, Unit]] = Map([])
  let mut metric_count = 0
  for i, c in cases {
    ignore(date_key(c.on, "replay.cases[\{i}].on"))
    check_usage_bundle(c.usages[:]) catch {
      Invalid(code~, path~, message~) =>
        raise Invalid(code~, path="replay.cases[\{i}]." + path, message~)
    }
    metric_count += c.usages.length()
    if metric_count > 1024 {
      invalid(
        "size", "replay.cases", "maximum 1024 metric snapshots per batch; split between complete customer-period cases",
      )
    }
    let u = c.usages[0]
    let periods = match seen.get(u.customer) {
      Some(p) => p
      None => {
        let p = Map([])
        seen[u.customer] = p
        p
      }
    }
    if periods.contains(u.period) {
      invalid(
        "duplicate",
        "replay.cases[\{i}]",
        "each customer-period must occur once, even if pricing dates differ",
      )
    }
    periods[u.period] = ()
  }
}

///|
fn replay_totals(
  rows : ArrayView[CatalogReplayRow],
) -> CatalogReplay raise PricingError {
  let mut be = 0N
  let mut ce = 0N
  let mut bs = 0N
  let mut cs = 0N
  let mut increased = 0
  let mut decreased = 0
  let mut unchanged = 0
  let mut maximum = 0N
  let mut maximum_index : Int32? = None
  for i, row in rows {
    let c = row.comparison
    if c.baseline.currency != rows[0].comparison.baseline.currency ||
      c.candidate.currency != c.baseline.currency {
      invalid(
        "currency", "replay.rows", "one currency is required throughout the batch",
      )
    }
    be += amount_atoms(c.baseline.totals.total, "replay.baseline_exact")
    ce += amount_atoms(c.candidate.totals.total, "replay.candidate_exact")
    let b = amount_atoms(c.baseline.totals.amount, "replay.baseline_settled")
    let a = amount_atoms(c.candidate.totals.amount, "replay.candidate_settled")
    bs += b
    cs += a
    let delta = a - b
    if delta > 0N {
      increased += 1
    } else if delta < 0N {
      decreased += 1
    } else {
      unchanged += 1
    }
    if delta > maximum {
      maximum = delta
      maximum_index = Some(i)
    }
  }
  for n in [be, ce, bs, cs] {
    ignore(amount_atoms(format_atoms(n), "replay.totals"))
  }
  {
    currency: rows[0].comparison.baseline.currency,
    rows: rows.to_owned(),
    baseline_exact: format_atoms(be),
    candidate_exact: format_atoms(ce),
    baseline_settled: format_atoms(bs),
    candidate_settled: format_atoms(cs),
    exact_delta: format_atoms(ce - be),
    settled_delta: format_atoms(cs - bs),
    increased,
    decreased,
    unchanged,
    max_increase: format_atoms(maximum),
    max_increase_index: maximum_index,
  }
}

///|
/// Replay complete metric snapshots against two trusted catalog versions on
/// each case's explicit date. Missing or incompatible metrics reject the batch.
///
/// ```mbt check
/// test {
///   let p = @jieheng.compile_package(
///     id="sms",
///     version="v1",
///     metric="messages",
///     unit="message",
///     currency="USD",
///     package_size="10",
///     package_price="1",
///   )
///   let c = @jieheng.compile_catalog([
///     { starts_on: "2026-01-01", ends_before: None, tariff: PackageTariff(p), },
///   ])
///   let cases : Array[@jieheng.CatalogReplayCase] = [
///     {
///       on: "2026-10-22",
///       usages: [
///         {
///           customer: "acme",
///           metric: "messages",
///           period: "October",
///           quantity: "11",
///         },
///       ],
///     },
///   ]
///   let r = @jieheng.replay_catalogs(c, c, cases[:], scale=2, rounding=HalfEven)
///   inspect(r.unchanged, content="1")
/// }
/// ```
pub fn replay_catalogs(
  before : Catalog,
  after : Catalog,
  cases : ArrayView[CatalogReplayCase],
  scale~ : Int32,
  rounding~ : Rounding,
) -> CatalogReplay raise PricingError {
  check_replay_cases(cases)
  let rows : Array[CatalogReplayRow] = []
  for i, c in cases {
    let comparison = compare_bills(
      catalog_items(before, c.on, c.usages[:])[:],
      catalog_items(after, c.on, c.usages[:])[:],
      scale~,
      rounding~,
    ) catch {
      Invalid(code~, path~, message~) =>
        raise Invalid(code~, path="replay.cases[\{i}]." + path, message~)
    }
    rows.push({ on: c.on, comparison, })
  }
  let report = replay_totals(rows[:])
  verify_catalog_replay(before, after, cases, report, scale~, rounding~)
  report
}

///|
/// Verify complete dated input binding and both bills of every row, without
/// invoking replay_catalogs or pricing producers, then conserve all aggregates.
pub fn verify_catalog_replay(
  before : Catalog,
  after : Catalog,
  cases : ArrayView[CatalogReplayCase],
  report : CatalogReplay,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  check_replay_cases(cases)
  if report.rows.length() != cases.length() {
    invalid(
      "coverage", "replay.rows", "exactly one ordered row is required per trusted case",
    )
  }
  for i, c in cases {
    if report.rows[i].on != c.on {
      invalid(
        "date",
        "replay.rows[\{i}].on",
        "row date must match the trusted pricing date",
      )
    }
    verify_bill_comparison(
      catalog_items(before, c.on, c.usages[:])[:],
      catalog_items(after, c.on, c.usages[:])[:],
      report.rows[i].comparison,
      scale~,
      rounding~,
    ) catch {
      Invalid(code~, path~, message~) =>
        raise Invalid(code~, path="replay.rows[\{i}]." + path, message~)
    }
  }
  if report != replay_totals(report.rows[:]) {
    invalid(
      "total", "replay.totals", "preserve all verified row totals, increase counts and first maximum index",
    )
  }
}

///|
fn validate_replay_policy(policy : ReplayPolicy) -> Unit raise PricingError {
  check_currency(policy.currency)
  ignore(amount_atoms(policy.max_increase, "replay.policy.max_increase"))
  if policy.max_increase_percent is Some(s) {
    ignore(decimal(s, "replay.policy.max_increase_percent"))
  }
}

///|
/// Verify first, then apply both optional relative and mandatory absolute limits
/// per complete customer-period bill. Uses integer cross-products, not division.
pub fn check_replay_policy(
  before : Catalog,
  after : Catalog,
  cases : ArrayView[CatalogReplayCase],
  report : CatalogReplay,
  policy : ReplayPolicy,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  validate_replay_policy(policy)
  verify_catalog_replay(before, after, cases, report, scale~, rounding~)
  if policy.currency != report.currency {
    invalid(
      "currency", "replay.policy.currency", "policy currency must match the verified batch; no FX conversion",
    )
  }
  let cap = amount_atoms(policy.max_increase, "replay.policy.max_increase")
  let percent = policy.max_increase_percent.map(s => {
    decimal(s, "replay.policy.max_increase_percent")
  })
  for i, row in report.rows {
    let c = row.comparison
    let b = amount_atoms(c.baseline.totals.amount, "replay.baseline")
    let a = amount_atoms(c.candidate.totals.amount, "replay.candidate")
    let delta = a - b
    if delta > cap ||
      (
        delta > 0N &&
        percent is Some(p) &&
        (b == 0N || delta * 100N * factor() > b * p)
      ) {
      invalid(
        "policy",
        "replay.rows[\{i}]",
        "customer '\{c.baseline.customer}', period '\{c.baseline.period}', date \{row.on}: settled \{b |> format_atoms} -> \{a |> format_atoms} \{report.currency} exceeds a per-snapshot increase limit",
      )
    }
  }
}
