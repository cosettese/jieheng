///|
/// Every integer usage from zero through evidence.quantity is affordable.
/// Unless limited by request.limit, the next quantity has a verified over-budget
/// witness. This differs from maximum feasible quantity under Volume pricing.
pub(all) struct QuotaQuote {
  request : BudgetRequest
  evidence : Evidence
  first_unaffordable : Evidence?
} derive(Debug, Eq)

///|
pub extend QuotaQuote with Debug::{to_repr}

///|
pub extend QuotaQuote with Eq::{equal, not_equal}

///|
fn quota_evidence(
  plan : Plan,
  request : BudgetRequest,
  q : BigInt,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Evidence raise PricingError {
  let calculation = rate(plan, budget_usage(plan, request, q))
  { calculation, settlement: settle(calculation, scale~, rounding~), }
}

///|
/// Find the largest safe prefix of integer quantities, stopping at the first
/// unaffordable point even if later volume discounts make larger points feasible.
///
/// ```mbt check
/// test {
///   let p = @jieheng.compile_plan(
///     id="api",
///     version="v1",
///     metric="calls",
///     unit="call",
///     currency="USD",
///     mode=Volume,
///     tiers=[
///       { up_to: Some("5"), unit_price: "10", },
///       { up_to: Some("10"), unit_price: "1", },
///       { up_to: None, unit_price: "20", },
///     ],
///   )
///   let r = @jieheng.quote_quota(
///     p,
///     { customer: "acme", period: "2026-10", budget: "12", limit: "20", },
///     scale=2,
///     rounding=HalfEven,
///   )
///   inspect(r.evidence.calculation.usage.quantity, content="1")
///   inspect(r.first_unaffordable.unwrap().calculation.usage.quantity, content="2")
/// }
/// ```
pub fn quote_quota(
  plan : Plan,
  request : BudgetRequest,
  scale~ : Int32,
  rounding~ : Rounding,
) -> QuotaQuote raise PricingError {
  check_budget(request)
  ignore(settle_total(plan.currency, "0", scale~, rounding~))
  let budget = amount_atoms(request.budget, "quota.budget")
  let limit = natural(request.limit, "quota.limit")
  let mut quota = limit
  let mut from = 0N
  while from <= limit {
    let (to, total, step) = curve_piece(plan, from, limit)
    if !rounded_fits(plan.currency, total, budget, scale~, rounding~) {
      quota = from - 1N
      break
    }
    if !rounded_fits(
        plan.currency,
        total + step * (to - from),
        budget,
        scale~,
        rounding~,
      ) {
      let best = search_quantity(from, to, q => {
        rounded_fits(
          plan.currency,
          total + step * (q - from),
          budget,
          scale~,
          rounding~,
        )
      })
      // The lower endpoint was checked above, so a feasible point exists.
      if best is Some(q) {
        quota = q
      }
      break
    }
    from = to + 1N
  }
  let first_unaffordable = if quota < limit {
    Some(quota_evidence(plan, request, quota + 1N, scale~, rounding~))
  } else {
    None
  }
  let quote = {
    request,
    evidence: quota_evidence(plan, request, quota, scale~, rounding~),
    first_unaffordable,
  }
  verify_quota(plan, request, quote, scale~, rounding~)
  quote
}

///|
/// Independently verify the whole feasible prefix and the first unsafe neighbor.
/// Does not invoke quote_quota, curve_piece, binary search or settlement producers.
pub fn verify_quota(
  plan : Plan,
  request : BudgetRequest,
  quote : QuotaQuote,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  check_budget(request)
  if quote.request != request {
    invalid(
      "identity", "quota.request", "all request fields must match trusted inputs",
    )
  }
  let q = natural(quote.evidence.calculation.usage.quantity, "quota.quantity")
  let limit = natural(request.limit, "quota.limit")
  if q > limit {
    invalid("limit", "quota.quantity", "quota exceeds the trusted search limit")
  }
  verify_evidence(
    plan,
    budget_usage(plan, request, q),
    quote.evidence,
    scale~,
    rounding~,
  )
  let budget = amount_atoms(request.budget, "quota.budget")
  if amount_atoms(quote.evidence.settlement.amount, "settlement.amount") >
    budget {
    invalid(
      "budget", "quota.quantity", "quota endpoint exceeds the trusted budget",
    )
  }
  if plan.mode == Volume {
    // Each occupied volume tier is nondecreasing internally. Its rightmost
    // point is a worst-case prefix point, including tiers before later discounts.
    let mut previous = 0N
    for tier in plan.tiers {
      let upper = match tier.up_to {
        Some(n) => if n < q { n } else { q }
        None => q
      }
      if upper > previous &&
        !threshold_fits(upper * tier.price, budget, scale, rounding) {
        invalid(
          "prefix", "quota.quantity", "an earlier quantity inside the proposed quota exceeds budget; later discounts do not make the prefix safe",
        )
      }
      match tier.up_to {
        Some(n) => previous = n
        None => ()
      }
      if upper == q {
        break
      }
    }
  }
  // Graduated prices have nonnegative marginal charges; the verified feasible
  // endpoint proves the entire prefix. Both modes still require the next witness.
  if q == limit {
    if quote.first_unaffordable is Some(_) {
      invalid(
        "witness", "quota.first_unaffordable", "no out-of-domain witness is accepted when quota equals the trusted limit",
      )
    }
  } else {
    guard quote.first_unaffordable is Some(witness) else {
      invalid(
        "witness", "quota.first_unaffordable", "provide evidence for exactly quota plus one",
      )
      return
    }
    verify_evidence(
      plan,
      budget_usage(plan, request, q + 1N),
      witness,
      scale~,
      rounding~,
    ) catch {
      Invalid(code~, path~, message~) =>
        raise Invalid(code~, path="quota.first_unaffordable." + path, message~)
    }
    if amount_atoms(witness.settlement.amount, "settlement.amount") <= budget {
      invalid(
        "witness", "quota.first_unaffordable", "next quantity is still affordable; this quota is not the largest safe prefix",
      )
    }
  }
}
