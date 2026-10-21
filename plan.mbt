///|
/// Compile tiers and detach them from caller-owned arrays.
/// The default mode preserves graduated pricing for existing callers.
/// Bounds must increase strictly, and only the last bound must be None.
pub fn compile_plan(
  id~ : String,
  version~ : String,
  metric~ : String,
  unit~ : String,
  currency~ : String,
  tiers~ : ArrayView[Tier],
  mode~ : PricingMode = Graduated,
) -> Plan raise PricingError {
  label(id, "plan.id")
  label(version, "plan.version")
  label(metric, "plan.metric")
  label(unit, "plan.unit")
  if currency.length() != 3 {
    invalid(
      "currency", "plan.currency", "use an explicit three-letter uppercase currency label",
    )
  }
  for c in currency {
    if c < 'A' || c > 'Z' {
      invalid(
        "currency", "plan.currency", "use ASCII uppercase letters; no currency conversion is performed",
      )
    }
  }
  if tiers.length() == 0 || tiers.length() > 1024 {
    invalid(
      "tiers", "plan.tiers", "provide 1..1024 tiers, ending with an unbounded tier",
    )
  }
  let compiled = []
  let mut previous = 0N
  for i, tier in tiers {
    let path = "plan.tiers[\{i}]"
    let bound = match tier.up_to {
      Some(text) => {
        if i == tiers.length() - 1 {
          invalid(
            "unbounded",
            path + ".up_to",
            "the last tier must have an unbounded upper limit",
          )
        }
        let n = natural(text, path + ".up_to")
        if n <= previous {
          invalid(
            "order",
            path + ".up_to",
            "upper bounds must be strictly increasing and positive",
          )
        }
        previous = n
        Some(n)
      }
      None => {
        if i != tiers.length() - 1 {
          invalid(
            "unbounded",
            path + ".up_to",
            "only the last tier may be unbounded",
          )
        }
        None
      }
    }
    compiled.push({
      up_to: bound,
      price: decimal(tier.unit_price, path + ".unit_price"),
    })
  }
  { id, version, metric, unit, currency, mode, tiers: compiled, }
}

///|
/// Return the plan's explicit pricing semantics.
pub fn Plan::mode(self : Plan) -> PricingMode {
  self.mode
}

///|
fn validate_usage(plan : Plan, usage : Usage) -> BigInt raise PricingError {
  label(usage.customer, "usage.customer")
  label(usage.metric, "usage.metric")
  label(usage.period, "usage.period")
  if usage.metric != plan.metric {
    invalid("metric", "usage.metric", "expected metric '\{plan.metric}'")
  }
  natural(usage.quantity, "usage.quantity")
}
