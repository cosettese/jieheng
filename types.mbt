///|
/// Diagnostics contain a stable code, an input path, and an actionable message.
pub(all) suberror PricingError {
  Invalid(code~ : String, path~ : String, message~ : String)
} derive(Debug, Eq)

///|
/// A cumulative inclusive upper bound, or None for the final unbounded tier.
/// Decimal prices are in currency units per one integer usage unit.
pub(all) struct Tier {
  up_to : String?
  unit_price : String
} derive(Debug, Eq)

///|
priv struct CompiledTier {
  up_to : BigInt?
  price : BigInt
}

///|
/// Validated, detached snapshot of a graduated price plan.
pub struct Plan {
  priv id : String
  priv version : String
  priv metric : String
  priv unit : String
  priv currency : String
  priv tiers : Array[CompiledTier]
}

///|
/// Already aggregated usage for one customer, metric, and opaque period label.
pub(all) struct Usage {
  customer : String
  metric : String
  period : String
  quantity : String
} derive(Debug, Eq)

///|
/// Exact allocation for one occupied tier. No line-level monetary rounding.
pub(all) struct Line {
  tier : Int32
  from_exclusive : String
  to_inclusive : String
  quantity : String
  unit_price : String
  subtotal : String
} derive(Debug, Eq)

///|
/// Exact, unsettled calculation. Public records may be inspected and serialized.
pub(all) struct Calculation {
  plan_id : String
  plan_version : String
  currency : String
  unit : String
  usage : Usage
  lines : Array[Line]
  total : String
} derive(Debug, Eq)

///|
/// All amounts are nonnegative; Down/Up mean toward/away from zero.
pub(all) enum Rounding {
  HalfEven
  HalfUp
  Down
  Up
} derive(Debug, Eq)

///|
/// Exactly one rounding operation on the complete total.
/// delta = amount - exact total, and can be negative.
pub(all) struct Settlement {
  currency : String
  scale : Int32
  rounding : Rounding
  minor_units : String
  amount : String
  delta : String
} derive(Debug, Eq)

///|
fn invalid(
  code : String,
  path : String,
  message : String,
) -> Unit raise PricingError {
  raise Invalid(code~, path~, message~)
}
