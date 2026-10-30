///|
pub(all) enum CatalogChange {
  MetricAdded
  MetricRemoved
  BaselineGap
  CandidateGap
  CurrencyChanged
  UnitChanged
  IdentityChanged
  VersionChanged
  ModelChanged
  PricingChanged
  MinimumChanged
  ZeroPolicyChanged
} derive(Debug, Eq)

///|
pub extend CatalogChange with Debug::{to_repr}

///|
pub extend CatalogChange with Eq::{equal, not_equal}

///|
/// Identical usage cannot be bound without an explicit mapping. Nonblocking
/// changes still require business review; structural compatibility is not approval.
pub fn CatalogChange::is_blocking(self : CatalogChange) -> Bool {
  match self {
    MetricAdded
    | MetricRemoved
    | BaselineGap
    | CandidateGap
    | CurrencyChanged
    | UnitChanged => true
    _ => false
  }
}

///|
/// Half-open interval, referencing entries in the two trusted catalog snapshots.
pub(all) struct MigrationSpan {
  metric : String
  starts_on : String
  ends_before : String
  baseline_entry : Int32?
  candidate_entry : Int32?
  changes : Array[CatalogChange]
} derive(Debug, Eq)

///|
pub extend MigrationSpan with Debug::{to_repr}

///|
pub extend MigrationSpan with Eq::{equal, not_equal}

///|
/// Unchanged spans are retained to prove full metric and window coverage.
pub(all) struct CatalogMigration {
  starts_on : String
  ends_before : String
  spans : Array[MigrationSpan]
} derive(Debug, Eq)

///|
pub extend CatalogMigration with Debug::{to_repr}

///|
pub extend CatalogMigration with Eq::{equal, not_equal}

///|
fn migration_window(start : String, end : String) -> Unit raise PricingError {
  if date_key(end, "migration.ends_before") <=
    date_key(start, "migration.starts_on") {
    invalid("interval", "migration", "end must be strictly after start")
  }
}

///|
fn migration_metrics(before : Catalog, after : Catalog) -> Array[String] {
  let metrics = before.metrics.copy()
  for m in after.metrics {
    if !metrics.contains(m) {
      metrics.push(m)
    }
  }
  metrics
}

///|
fn selected_entry(
  c : Catalog,
  indices : ArrayView[Int32],
  day : String,
) -> Int32? {
  for i in indices {
    let d = c.entries[i]
    if d.entry.starts_on <= day &&
      (
        d.entry.ends_before is None ||
        (d.entry.ends_before is Some(end) && day < end)
      ) {
      return Some(i)
    }
  }
  None
}

///|
// Build once per operation. Keep original entry indices and catalog metric order;
// only the hash lookup is shared, not the producer/verifier boundary algorithms.
fn migration_timelines(
  c : Catalog,
) -> Map[String, Array[Int32]] raise PricingError {
  let timelines : Map[String, Array[Int32]] = Map([])
  for i, d in c.entries {
    let metric = tariff_info(d.entry.tariff).metric
    match timelines.get(metric) {
      Some(indices) => indices.push(i)
      None => timelines[metric] = [i]
    }
  }
  timelines
}

///|
fn same_tier_prices(a : Plan, b : Plan) -> Bool {
  if a.tiers.length() != b.tiers.length() {
    return false
  }
  for i, tier in a.tiers {
    if tier.up_to != b.tiers[i].up_to || tier.price != b.tiers[i].price {
      return false
    }
  }
  true
}

///|
fn migration_changes(
  before : Catalog,
  after : Catalog,
  metric : String,
  bi : Int32?,
  ai : Int32?,
) -> Array[CatalogChange] raise PricingError {
  let changes : Array[CatalogChange] = []
  if !before.metrics.contains(metric) {
    changes.push(MetricAdded)
  }
  if !after.metrics.contains(metric) {
    changes.push(MetricRemoved)
  }
  if before.metrics.contains(metric) && bi is None {
    changes.push(BaselineGap)
  }
  if after.metrics.contains(metric) && ai is None {
    changes.push(CandidateGap)
  }
  if bi is Some(i) && ai is Some(j) {
    let bt = before.entries[i].entry.tariff
    let at = after.entries[j].entry.tariff
    let b = tariff_info(bt)
    let a = tariff_info(at)
    if b.currency != a.currency {
      changes.push(CurrencyChanged)
    }
    if b.unit != a.unit {
      changes.push(UnitChanged)
    }
    if b.id != a.id {
      changes.push(IdentityChanged)
    }
    if b.version != a.version {
      changes.push(VersionChanged)
    }
    match (bt, at) {
      (MeteredTariff(bp, bm, bz), MeteredTariff(ap, am, az)) => {
        if bp.mode != ap.mode {
          changes.push(ModelChanged)
        }
        if !same_tier_prices(bp, ap) {
          changes.push(PricingChanged)
        }
        if decimal(bm, "migration.minimum") != decimal(am, "migration.minimum") {
          changes.push(MinimumChanged)
        }
        if bz != az {
          changes.push(ZeroPolicyChanged)
        }
      }
      (PackageTariff(bp), PackageTariff(ap)) =>
        if bp.size != ap.size || bp.price != ap.price {
          changes.push(PricingChanged)
        }
      _ => changes.push(ModelChanged)
    }
  }
  changes
}

///|
/// Audit every metric throughout the civil-date window. No usage is synthesized
/// and no monetary impact is inferred.
///
/// ```mbt check
/// test {
///   let p = @jieheng.compile_package(
///     id="sms",
///     version="v1",
///     metric="messages",
///     unit="message",
///     currency="USD",
///     package_size="1000",
///     package_price="0.85",
///   )
///   let c = @jieheng.compile_catalog([
///     { starts_on: "2026-10-01", ends_before: None, tariff: PackageTariff(p), },
///   ])
///   let r = @jieheng.audit_catalog_migration(c, c, "2026-10-01", "2026-11-01")
///   inspect(r.spans[0].changes.length(), content="0")
/// }
/// ```
pub fn audit_catalog_migration(
  before : Catalog,
  after : Catalog,
  starts_on : String,
  ends_before : String,
) -> CatalogMigration raise PricingError {
  migration_window(starts_on, ends_before)
  let spans : Array[MigrationSpan] = []
  let before_timelines = migration_timelines(before)
  let after_timelines = migration_timelines(after)
  for metric in migration_metrics(before, after) {
    let bi = before_timelines.get(metric).unwrap_or([])
    let ai = after_timelines.get(metric).unwrap_or([])
    let boundaries = [starts_on, ends_before]
    for (c, indices) in [(before, bi), (after, ai)] {
      for index in indices {
        let d = c.entries[index]
        for edge in [Some(d.entry.starts_on), d.entry.ends_before] {
          if edge is Some(s) &&
            starts_on < s &&
            s < ends_before &&
            !boundaries.contains(s) {
            boundaries.push(s)
          }
        }
      }
    }
    boundaries.sort()
    for i in 0..<(boundaries.length() - 1) {
      let start = boundaries[i]
      let bi = selected_entry(before, bi[:], start)
      let ai = selected_entry(after, ai[:], start)
      spans.push({
        metric,
        starts_on: start,
        ends_before: boundaries[i + 1],
        baseline_entry: bi,
        candidate_entry: ai,
        changes: migration_changes(before, after, metric, bi, ai),
      })
    }
  }
  { starts_on, ends_before, spans, }
}

///|
// Independent selection and next-boundary validation, without sorting or rating.
fn checked_migration_boundary(
  c : Catalog,
  indices : ArrayView[Int32],
  start : String,
  end : String,
  claimed : Int32?,
) -> String raise PricingError {
  let mut next = end
  let mut actual : Int32? = None
  for i in indices {
    let d = c.entries[i]
    if d.entry.starts_on <= start &&
      (
        d.entry.ends_before is None ||
        (d.entry.ends_before is Some(e) && start < e)
      ) {
      actual = Some(i)
    }
    for edge in [Some(d.entry.starts_on), d.entry.ends_before] {
      if edge is Some(e) && start < e && e < next {
        next = e
      }
    }
  }
  if claimed != actual {
    invalid(
      "selection", "migration.spans", "entry index must select the trusted rule covering this metric and date",
    )
  }
  next
}

///|
/// Independently check ordered coverage, maximal intervals and trusted selections.
/// Does not call audit_catalog_migration or its sorted-boundary algorithm.
pub fn verify_catalog_migration(
  before : Catalog,
  after : Catalog,
  starts_on : String,
  ends_before : String,
  report : CatalogMigration,
) -> Unit raise PricingError {
  migration_window(starts_on, ends_before)
  if report.starts_on != starts_on || report.ends_before != ends_before {
    invalid("identity", "migration", "report must use the trusted date window")
  }
  if report.spans.length() > 4096 {
    invalid("size", "migration.spans", "maximum 4096 spans")
  }
  let mut row = 0
  let before_timelines = migration_timelines(before)
  let after_timelines = migration_timelines(after)
  for metric in migration_metrics(before, after) {
    let bi = before_timelines.get(metric).unwrap_or([])
    let ai = after_timelines.get(metric).unwrap_or([])
    let mut cursor = starts_on
    while cursor < ends_before {
      if row >= report.spans.length() {
        invalid(
          "coverage", "migration.spans", "missing metric or date interval",
        )
      }
      let s = report.spans[row]
      if s.metric != metric || s.starts_on != cursor {
        invalid(
          "coverage",
          "migration.spans[\{row}]",
          "preserve metric order and contiguous date coverage",
        )
      }
      let bnext = checked_migration_boundary(
        before,
        bi[:],
        cursor,
        ends_before,
        s.baseline_entry,
      )
      let anext = checked_migration_boundary(
        after,
        ai[:],
        cursor,
        ends_before,
        s.candidate_entry,
      )
      let next = if bnext < anext { bnext } else { anext }
      if s.ends_before != next ||
        s.changes !=
        migration_changes(
          before,
          after,
          metric,
          s.baseline_entry,
          s.candidate_entry,
        ) {
        invalid(
          "changes",
          "migration.spans[\{row}]",
          "preserve the next trusted boundary and every ordered change",
        )
      }
      cursor = next
      row += 1
    }
  }
  if row != report.spans.length() {
    invalid("coverage", "migration.spans", "extra or duplicated intervals")
  }
}
