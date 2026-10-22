///|
/// A complete pricing rule without any ignored usage quantity.
pub(all) enum Tariff {
  MeteredTariff(Plan, String, ZeroUsageMinimum)
  PackageTariff(PackagePlan)
}

///|
pub(all) struct CatalogEntry {
  starts_on : String
  ends_before : String?
  tariff : Tariff
}

///|
priv struct TariffInfo {
  id : String
  version : String
  metric : String
  unit : String
  currency : String
}

///|
fn tariff_info(tariff : Tariff) -> TariffInfo raise PricingError {
  match tariff {
    MeteredTariff(p, minimum, _) => {
      ignore(decimal(minimum, "tariff.minimum"))
      {
        id: p.id,
        version: p.version,
        metric: p.metric,
        unit: p.unit,
        currency: p.currency,
      }
    }
    PackageTariff(p) =>
      {
        id: p.id,
        version: p.version,
        metric: p.metric,
        unit: p.unit,
        currency: p.currency,
      }
  }
}

///|
priv struct DatedTariff {
  start : Int32
  end : Int32?
  entry : CatalogEntry
}

///|
/// Detached timelines for all required metrics of one product, in one currency.
pub struct Catalog {
  priv entries : Array[DatedTariff]
  priv metrics : Array[String]
}

///|
pub(all) struct CatalogBill {
  on : String
  bill : Bill
} derive(Debug, Eq)

///|
pub extend CatalogBill with Debug::{to_repr}

///|
pub extend CatalogBill with Eq::{equal, not_equal}

///|
pub fn compile_catalog(
  entries : ArrayView[CatalogEntry],
) -> Catalog raise PricingError {
  if entries.length() == 0 || entries.length() > 512 {
    invalid("size", "catalog.entries", "provide 1 to 512 dated rules")
  }
  let metadata : Map[String, TariffInfo] = Map([])
  let versions : Map[String, Map[String, Unit]] = Map([])
  let previous : Map[String, DatedTariff] = Map([])
  let metrics : Array[String] = []
  let compiled : Array[DatedTariff] = []
  let currency = tariff_info(entries[0].tariff).currency
  for i, entry in entries {
    let path = "catalog.entries[\{i}]"
    let info = tariff_info(entry.tariff)
    let start = date_key(entry.starts_on, path + ".starts_on")
    let end = entry.ends_before.map(s => date_key(s, path + ".ends_before"))
    if end is Some(n) && n <= start {
      invalid("interval", path, "end must be strictly after start")
    }
    if info.currency != currency {
      invalid("currency", path, "every catalog metric must use one currency")
    }
    match metadata.get(info.metric) {
      None => {
        if metrics.length() == 64 {
          invalid("size", path, "maximum 64 catalog metrics")
        }
        metadata[info.metric] = info
        versions[info.metric] = Map([])
        metrics.push(info.metric)
      }
      Some(first) => {
        if info.id != first.id || info.unit != first.unit {
          invalid(
            "identity", path, "versions of each metric must preserve plan id and unit",
          )
        }
        let prev = previous[info.metric]
        if start <= prev.start ||
          prev.end is None ||
          (prev.end is Some(n) && start < n) {
          invalid(
            "overlap", path, "each metric timeline must be ordered and disjoint; only its final end may be null",
          )
        }
      }
    }
    let seen = versions[info.metric]
    if seen.contains(info.version) {
      invalid(
        "duplicate", path, "versions must be unique within each metric timeline",
      )
    }
    if seen.length() == 128 {
      invalid("size", path, "maximum 128 versions per metric")
    }
    seen[info.version] = ()
    let dated : DatedTariff = { start, end, entry, }
    previous[info.metric] = dated
    compiled.push(dated)
  }
  { entries: compiled, metrics, }
}

///|
fn bind_tariff(tariff : Tariff, usage : Usage) -> BillItem {
  match tariff {
    MeteredTariff(plan, minimum, zero_usage) =>
      Metered({ plan, usage, minimum, zero_usage, })
    PackageTariff(plan) => Packaged(plan, usage)
  }
}

///|
fn check_usage_bundle(usages : ArrayView[Usage]) -> Unit raise PricingError {
  if usages.length() == 0 || usages.length() > 64 {
    invalid("size", "usages", "provide 1 to 64 aggregated metric snapshots")
  }
  let seen : Map[String, Unit] = Map([])
  for i, u in usages {
    check_usage(u)
    if u.customer != usages[0].customer || u.period != usages[0].period {
      invalid(
        "identity",
        "usages[\{i}]",
        "bundle must share customer and period",
      )
    }
    if seen.contains(u.metric) {
      invalid(
        "duplicate",
        "usages[\{i}].metric",
        "provide exactly one aggregated snapshot per metric",
      )
    }
    seen[u.metric] = ()
  }
}

///|
fn catalog_items(
  catalog : Catalog,
  on : String,
  usages : ArrayView[Usage],
) -> Array[BillItem] raise PricingError {
  let day = date_key(on, "catalog.on")
  check_usage_bundle(usages)
  let by_metric : Map[String, Usage] = Map([])
  for u in usages {
    if !catalog.metrics.contains(u.metric) {
      invalid(
        "unknown",
        "usages.metric",
        "metric '\{u.metric}' is not in this catalog",
      )
    }
    by_metric[u.metric] = u
  }
  let items : Array[BillItem] = []
  for metric in catalog.metrics {
    guard by_metric.get(metric) is Some(usage) else {
      invalid(
        "missing",
        "usages",
        "missing required metric '\{metric}'; supply an explicit zero snapshot if unused",
      )
      return []
    }
    let mut selected : Tariff? = None
    for dated in catalog.entries {
      if tariff_info(dated.entry.tariff).metric == metric &&
        day >= dated.start &&
        (dated.end is None || (dated.end is Some(n) && day < n)) {
        selected = Some(dated.entry.tariff)
        break
      }
    }
    guard selected is Some(tariff) else {
      invalid(
        "uncovered",
        "catalog.on",
        "no version covers '\{on}' for metric '\{metric}'",
      )
      return []
    }
    items.push(bind_tariff(tariff, usage))
  }
  items
}

///|
/// Select all required metric rules on one explicit civil date, then produce a
/// mixed bill. Input usage order does not change the catalog's output order.
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
///   let r = @jieheng.rate_catalog(
///     c,
///     "2026-10-22",
///     [
///       {
///         customer: "acme",
///         metric: "messages",
///         period: "October",
///         quantity: "2501",
///       },
///     ],
///     scale=2,
///     rounding=HalfEven,
///   )
///   inspect(r.bill.totals.amount, content="2.55")
/// }
/// ```
pub fn rate_catalog(
  catalog : Catalog,
  on : String,
  usages : ArrayView[Usage],
  scale~ : Int32,
  rounding~ : Rounding,
) -> CatalogBill raise PricingError {
  {
    on,
    bill: rate_bill(catalog_items(catalog, on, usages)[:], scale~, rounding~),
  }
}

///|
pub fn verify_catalog(
  catalog : Catalog,
  on : String,
  usages : ArrayView[Usage],
  record : CatalogBill,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  if record.on != on {
    invalid(
      "identity", "catalog.on", "record date must match the trusted pricing date",
    )
  }
  verify_bill(
    catalog_items(catalog, on, usages)[:],
    record.bill,
    scale~,
    rounding~,
  )
}
