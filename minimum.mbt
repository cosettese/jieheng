///|
/// Whether a contractual minimum applies when the trusted quantity is zero.
pub(all) enum ZeroUsageMinimum {
  Charge
  Waive
} derive(Debug, Eq)

///|
pub extend ZeroUsageMinimum with Debug::{to_repr}

///|
pub extend ZeroUsageMinimum with Eq::{equal, not_equal}

///|
/// Usage-only calculation remains untouched. total = calculation.total + top_up.
/// Only total is settled; no intermediate rounded amount is fed into the floor.
pub(all) struct Charge {
  calculation : Calculation
  minimum : String
  zero_usage : ZeroUsageMinimum
  top_up : String
  total : String
  settlement : Settlement
} derive(Debug, Eq)

///|
pub extend Charge with Debug::{to_repr}

///|
pub extend Charge with Eq::{equal, not_equal}

///|
/// Apply an explicit single-metric minimum before one settlement operation.
///
/// ```mbt check
/// test {
///   let p = @jieheng.compile_plan(
///     id="api",
///     version="v1",
///     metric="calls",
///     unit="call",
///     currency="USD",
///     tiers=[{ up_to: None, unit_price: "0.004", }],
///   )
///   let c = @jieheng.rate_charge(
///     p,
///     { customer: "acme", metric: "calls", period: "2026-10", quantity: "1", },
///     minimum="0.005",
///     zero_usage=Charge,
///     scale=2,
///     rounding=HalfEven,
///   )
///   inspect(c.top_up, content="0.001")
///   inspect(c.total, content="0.005")
///   inspect(c.settlement.amount, content="0.00")
/// }
/// ```
pub fn rate_charge(
  plan : Plan,
  usage : Usage,
  minimum~ : String,
  zero_usage~ : ZeroUsageMinimum,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Charge raise PricingError {
  let floor = decimal(minimum, "charge.minimum")
  let calculation = rate(plan, usage)
  let raw = amount_atoms(calculation.total, "calculation.total")
  let applicable = if usage.quantity == "0" && zero_usage == Waive {
    0N
  } else {
    floor
  }
  let top_up = if applicable > raw { applicable - raw } else { 0N }
  let total = format_atoms(raw + top_up)
  let charge = {
    calculation,
    minimum: format_atoms(floor),
    zero_usage,
    top_up: format_atoms(top_up),
    total,
    settlement: settle_total(plan.currency, total, scale~, rounding~),
  }
  verify_charge(plan, usage, charge, minimum~, zero_usage~, scale~, rounding~)
  charge
}

///|
/// Verify usage allocation, explicit policy binding, floor conservation and the
/// independently checked rounding interval. Does not invoke rate_charge.
pub fn verify_charge(
  plan : Plan,
  usage : Usage,
  charge : Charge,
  minimum~ : String,
  zero_usage~ : ZeroUsageMinimum,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  let floor = decimal(minimum, "charge.minimum")
  verify_calculation(plan, usage, charge.calculation)
  if charge.minimum != format_atoms(floor) || charge.zero_usage != zero_usage {
    invalid(
      "policy", "charge.minimum", "minimum and zero-usage behavior must match the trusted contract",
    )
  }
  let raw = amount_atoms(charge.calculation.total, "calculation.total")
  let extra = amount_atoms(charge.top_up, "charge.top_up")
  let total = amount_atoms(charge.total, "charge.total")
  let active = usage.quantity != "0" || zero_usage == Charge
  // Verify inequalities and conservation rather than invoking the producer.
  if total != raw + extra ||
    total < raw ||
    (active && (total < floor || (total != raw && total != floor))) ||
    (!active && extra != 0N) ||
    charge.top_up != format_atoms(extra) ||
    charge.total != format_atoms(total) {
    invalid(
      "minimum", "charge.total", "total must equal usage plus the exact necessary minimum top-up; no other fee is supported",
    )
  }
  verify_total_settlement(
    plan.currency,
    charge.total,
    charge.settlement,
    scale~,
    rounding~,
  )
}
