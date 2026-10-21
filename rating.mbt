///|
/// Rate a cumulative quantity using marginal tiers; never rounds individual lines.
///
/// ```mbt check
/// test {
///   let plan = @jieheng.compile_plan(
///     id="api",
///     version="v1",
///     metric="requests",
///     unit="request",
///     currency="USD",
///     tiers=[
///       { up_to: Some("1000"), unit_price: "0", },
///       { up_to: None, unit_price: "0.001", },
///     ],
///   )
///   let result = @jieheng.rate(plan, {
///     customer: "acme",
///     metric: "requests",
///     period: "2026-09",
///     quantity: "1001",
///   })
///   inspect(result.total, content="0.001")
/// }
/// ```
pub fn rate(plan : Plan, usage : Usage) -> Calculation raise PricingError {
  let quantity = validate_usage(plan, usage)
  let lines = []
  let mut lower = 0N
  let mut total = 0N
  for index, tier in plan.tiers {
    if lower >= quantity {
      break
    }
    let upper = match tier.up_to {
      Some(bound) => if bound < quantity { bound } else { quantity }
      None => quantity
    }
    let count = upper - lower
    let subtotal = count * tier.price
    lines.push({
      tier: index,
      from_exclusive: lower.to_string(),
      to_inclusive: upper.to_string(),
      quantity: count.to_string(),
      unit_price: format_atoms(tier.price),
      subtotal: format_atoms(subtotal),
    })
    total += subtotal
    lower = upper
  }
  {
    plan_id: plan.id,
    plan_version: plan.version,
    currency: plan.currency,
    unit: plan.unit,
    usage,
    lines,
    total: format_atoms(total),
  }
}
