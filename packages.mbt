///|
/// A fixed nonzero package capacity and exact price per package.
pub struct PackagePlan {
  priv id : String
  priv version : String
  priv metric : String
  priv unit : String
  priv currency : String
  priv size : BigInt
  priv price : BigInt
}

///|
pub(all) struct PackageEvidence {
  plan_id : String
  plan_version : String
  currency : String
  unit : String
  usage : Usage
  package_size : String
  package_price : String
  packages : String
  unused_units : String
  total : String
  settlement : Settlement
} derive(Debug, Eq)

///|
pub extend PackageEvidence with Debug::{to_repr}

///|
pub extend PackageEvidence with Eq::{equal, not_equal}

///|
pub fn compile_package(
  id~ : String,
  version~ : String,
  metric~ : String,
  unit~ : String,
  currency~ : String,
  package_size~ : String,
  package_price~ : String,
) -> PackagePlan raise PricingError {
  label(id, "package.id")
  label(version, "package.version")
  label(metric, "package.metric")
  label(unit, "package.unit")
  check_currency(currency)
  let size = natural(package_size, "package.package_size")
  if size == 0N {
    invalid(
      "size", "package.package_size", "package size must be a positive integer",
    )
  }
  {
    id,
    version,
    metric,
    unit,
    currency,
    size,
    price: decimal(package_price, "package.package_price"),
  }
}

///|
fn package_quantity(
  plan : PackagePlan,
  usage : Usage,
) -> BigInt raise PricingError {
  check_usage(usage)
  if usage.metric != plan.metric {
    invalid("metric", "usage.metric", "expected metric '\{plan.metric}'")
  }
  natural(usage.quantity, "usage.quantity")
}

///|
/// Round capacity up to full packages, then settle the exact package total once.
///
/// ```mbt check
/// test {
///   let p = @jieheng.compile_package(
///     id="seats",
///     version="v1",
///     metric="users",
///     unit="user",
///     currency="USD",
///     package_size="5",
///     package_price="10",
///   )
///   let e = @jieheng.rate_packages(
///     p,
///     { customer: "acme", metric: "users", period: "2026-10", quantity: "6", },
///     scale=2,
///     rounding=HalfEven,
///   )
///   inspect(e.packages, content="2")
///   inspect(e.unused_units, content="4")
///   inspect(e.settlement.amount, content="20.00")
/// }
/// ```
pub fn rate_packages(
  plan : PackagePlan,
  usage : Usage,
  scale~ : Int32,
  rounding~ : Rounding,
) -> PackageEvidence raise PricingError {
  let quantity = package_quantity(plan, usage)
  let packages = (quantity + plan.size - 1N) / plan.size
  let total = format_atoms(packages * plan.price)
  let record = {
    plan_id: plan.id,
    plan_version: plan.version,
    currency: plan.currency,
    unit: plan.unit,
    usage,
    package_size: plan.size.to_string(),
    package_price: format_atoms(plan.price),
    packages: packages.to_string(),
    unused_units: (packages * plan.size - quantity).to_string(),
    total,
    settlement: settle_total(plan.currency, total, scale~, rounding~),
  }
  verify_packages(plan, usage, record, scale~, rounding~)
  record
}

///|
/// Independently check capacity conservation and minimality without repeating
/// the producer's ceiling division, then check exact price and rounding interval.
pub fn verify_packages(
  plan : PackagePlan,
  usage : Usage,
  record : PackageEvidence,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  let quantity = package_quantity(plan, usage)
  if record.plan_id != plan.id ||
    record.plan_version != plan.version ||
    record.currency != plan.currency ||
    record.unit != plan.unit ||
    record.usage != usage ||
    record.package_size != plan.size.to_string() ||
    record.package_price != format_atoms(plan.price) {
    invalid(
      "identity", "packages", "plan, usage, package capacity and price must match trusted inputs",
    )
  }
  let count = natural(record.packages, "packages.packages")
  let unused = natural(record.unused_units, "packages.unused_units")
  if count * plan.size != quantity + unused || unused >= plan.size {
    invalid(
      "capacity", "packages.unused_units", "purchased capacity must equal usage plus unused units, with unused capacity smaller than one package",
    )
  }
  if record.total != format_atoms(count * plan.price) {
    invalid(
      "total", "packages.total", "expected exact package count multiplied by price per package",
    )
  }
  verify_total_settlement(
    plan.currency,
    record.total,
    record.settlement,
    scale~,
    rounding~,
  )
}
