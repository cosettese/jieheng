///|
/// A finite procurement request, without an ignored or guessed usage quantity.
pub(all) struct BudgetRequest {
  customer : String
  period : String
  budget : String
  limit : String
} derive(Debug, Eq)

///|
pub extend BudgetRequest with Debug::{to_repr}

///|
pub extend BudgetRequest with Eq::{equal, not_equal}

///|
/// Maximum affordable quantity within the explicit limit, with complete evidence.
/// For Volume, smaller quantities need not all be affordable.
pub(all) struct BudgetQuote {
  request : BudgetRequest
  evidence : Evidence
} derive(Debug, Eq)

///|
pub extend BudgetQuote with Debug::{to_repr}

///|
pub extend BudgetQuote with Eq::{equal, not_equal}

///|
fn check_budget(request : BudgetRequest) -> Unit raise PricingError {
  label(request.customer, "budget.customer")
  label(request.period, "budget.period")
  ignore(amount_atoms(request.budget, "budget.budget"))
  ignore(natural(request.limit, "budget.limit"))
}

///|
fn budget_usage(
  plan : Plan,
  request : BudgetRequest,
  quantity : BigInt,
) -> Usage {
  {
    customer: request.customer,
    metric: plan.metric,
    period: request.period,
    quantity: quantity.to_string(),
  }
}

///|
fn search_quantity(
  lower : BigInt,
  upper : BigInt,
  fits : (BigInt) -> Bool raise PricingError,
) -> BigInt? raise PricingError {
  if lower > upper || !fits(lower) {
    return None
  }
  let mut lo = lower
  let mut hi = upper
  while lo < hi {
    let mid = (lo + hi + 1N) / 2N
    if fits(mid) {
      lo = mid
    } else {
      hi = mid - 1N
    }
  }
  Some(lo)
}

///|
fn rounded_fits(
  currency : String,
  total : BigInt,
  budget : BigInt,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Bool raise PricingError {
  let settled = settle_total(currency, format_atoms(total), scale~, rounding~)
  let step = BigInt::from_string("1" + "0".repeat(18 - scale))
  // Compare integer minor units directly, including unaffordable probes.
  BigInt::from_string(settled.minor_units) * step <= budget
}

///|
/// Maximize integer quantity subject to settled charge <= budget and q <= limit.
/// Does not apply minimum spend, package rules, taxes or cross-metric budgets.
///
/// ```mbt check
/// test {
///   let p = @jieheng.compile_plan(
///     id="api",
///     version="v1",
///     metric="calls",
///     unit="call",
///     currency="USD",
///     tiers=[{ up_to: None, unit_price: "0.006", }],
///   )
///   let q = @jieheng.quote_budget(
///     p,
///     { customer: "acme", period: "2026-10", budget: "0.01", limit: "100", },
///     scale=2,
///     rounding=HalfEven,
///   )
///   inspect(q.evidence.calculation.usage.quantity, content="2")
///   inspect(q.evidence.settlement.amount, content="0.01")
/// }
/// ```
pub fn quote_budget(
  plan : Plan,
  request : BudgetRequest,
  scale~ : Int32,
  rounding~ : Rounding,
) -> BudgetQuote raise PricingError {
  check_budget(request)
  // Validate scale before any power or division; zero is always affordable.
  ignore(settle_total(plan.currency, "0", scale~, rounding~))
  let budget = amount_atoms(request.budget, "budget.budget")
  let limit = natural(request.limit, "budget.limit")
  let mut best = 0N
  match plan.mode {
    Graduated => {
      let found = search_quantity(0N, limit, q => {
        let calculation = rate(plan, budget_usage(plan, request, q))
        rounded_fits(
          plan.currency,
          amount_atoms(calculation.total, "calculation.total"),
          budget,
          scale~,
          rounding~,
        )
      })
      if found is Some(q) {
        best = q
      }
    }
    Volume => {
      let mut previous = 0N
      for tier in plan.tiers {
        let upper = match tier.up_to {
          Some(n) => if n < limit { n } else { limit }
          None => limit
        }
        let found = search_quantity(previous + 1N, upper, q => {
          rounded_fits(plan.currency, q * tier.price, budget, scale~, rounding~)
        })
        if found is Some(q) {
          best = q
        }
        match tier.up_to {
          Some(n) => previous = n
          None => ()
        }
        if upper == limit {
          break
        }
      }
    }
  }
  let calculation = rate(plan, budget_usage(plan, request, best))
  let quote = {
    request,
    evidence: {
      calculation,
      settlement: settle(calculation, scale~, rounding~),
    },
  }
  verify_budget(plan, request, quote, scale~, rounding~)
  quote
}

///|
/// Exact affordability threshold derived from the rounding intervals. The
/// verifier never calls settle_total, search_quantity or quote_budget.
fn threshold_fits(
  total : BigInt,
  budget : BigInt,
  scale : Int32,
  rounding : Rounding,
) -> Bool {
  let step = BigInt::from_string("1" + "0".repeat(18 - scale))
  let units = budget / step
  match rounding {
    Down => total < (units + 1N) * step
    Up => total <= units * step
    HalfUp => total * 2N < (units * 2N + 1N) * step
    HalfEven => {
      let twice = total * 2N
      let boundary = (units * 2N + 1N) * step
      twice < boundary || (twice == boundary && units % 2N == 0N)
    }
  }
}

///|
/// Check trusted request, allocation, settlement, feasibility and global
/// maximality. For Volume, examine the cheapest larger point of every tier.
pub fn verify_budget(
  plan : Plan,
  request : BudgetRequest,
  quote : BudgetQuote,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  check_budget(request)
  if quote.request != request {
    invalid(
      "identity", "budget.request", "quote request must match all trusted request fields",
    )
  }
  let q = natural(quote.evidence.calculation.usage.quantity, "budget.quantity")
  let limit = natural(request.limit, "budget.limit")
  if q > limit {
    invalid(
      "limit", "budget.quantity", "quantity exceeds the trusted finite search limit",
    )
  }
  verify_evidence(
    plan,
    budget_usage(plan, request, q),
    quote.evidence,
    scale~,
    rounding~,
  )
  let budget = amount_atoms(request.budget, "budget.budget")
  if amount_atoms(quote.evidence.settlement.amount, "settlement.amount") >
    budget {
    invalid(
      "budget", "budget.quantity", "settled amount exceeds the trusted budget",
    )
  }
  if q == limit {
    return
  }
  match plan.mode {
    Graduated => {
      // Nonnegative marginal prices imply a monotone total. Verify the next
      // exact amount by adding its one trusted marginal price to verified total.
      let next = q + 1N
      let raw = amount_atoms(
        quote.evidence.calculation.total,
        "calculation.total",
      )
      for tier in plan.tiers {
        if tier.up_to is None || (tier.up_to is Some(n) && next <= n) {
          if threshold_fits(raw + tier.price, budget, scale, rounding) {
            invalid(
              "maximum", "budget.quantity", "a larger quantity remains affordable",
            )
          }
          break
        }
      }
    }
    Volume => {
      let mut previous = 0N
      for tier in plan.tiers {
        let upper = match tier.up_to {
          Some(n) => if n < limit { n } else { limit }
          None => limit
        }
        let lower = if previous > q { previous + 1N } else { q + 1N }
        if lower <= upper &&
          threshold_fits(lower * tier.price, budget, scale, rounding) {
          invalid(
            "maximum", "budget.quantity", "a larger quantity is affordable in this or a later volume tier; lower quantities need not form a feasible prefix",
          )
        }
        match tier.up_to {
          Some(n) => previous = n
          None => ()
        }
        if upper == limit {
          break
        }
      }
    }
  }
}
