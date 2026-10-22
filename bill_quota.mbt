///|
/// Fixed snapshots retain every quantity. The variable rule has no quantity;
/// its customer/period/limit come explicitly from request.
pub(all) struct BillQuotaInput {
  fixed : Array[BillItem]
  variable : Tariff
  request : BudgetRequest
}

///|
pub(all) struct BillQuota {
  request : BudgetRequest
  variable_metric : String
  bill : Bill
  first_unaffordable : Bill?
} derive(Debug, Eq)

///|
pub extend BillQuota with Debug::{to_repr}

///|
pub extend BillQuota with Eq::{equal, not_equal}

///|
fn bill_quota_items(
  input : BillQuotaInput,
  q : BigInt,
) -> Array[BillItem] raise PricingError {
  check_budget(input.request)
  let info = tariff_info(input.variable)
  let usage : Usage = {
    customer: input.request.customer,
    period: input.request.period,
    metric: info.metric,
    quantity: q.to_string(),
  }
  let items = input.fixed + [bind_tariff(input.variable, usage)]
  ignore(check_bill(items[:]))
  items
}

///|
fn variable_fits(
  input : BillQuotaInput,
  q : BigInt,
  available : BigInt,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Bool raise PricingError {
  let info = tariff_info(input.variable)
  let u : Usage = {
    customer: input.request.customer,
    period: input.request.period,
    metric: info.metric,
    quantity: q.to_string(),
  }
  let settlement = match input.variable {
    MeteredTariff(p, minimum, zero_usage) =>
      rate_charge(p, u, minimum~, zero_usage~, scale~, rounding~).settlement
    PackageTariff(p) => rate_packages(p, u, scale~, rounding~).settlement
  }
  let step = BigInt::from_string("1" + "0".repeat(18 - scale))
  BigInt::from_string(settlement.minor_units) * step <= available
}

///|
/// Keep 0..63 fixed metric snapshots and maximize a safe prefix for one variable
/// metric under the total settled bill budget, including explicit minimum rules.
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
///   let input : @jieheng.BillQuotaInput = {
///     fixed: [],
///     variable: PackageTariff(p),
///     request: {
///       customer: "acme",
///       period: "October",
///       budget: "3",
///       limit: "10000",
///     },
///   }
///   let q = @jieheng.quote_bill_quota(input, scale=2, rounding=HalfEven)
///   inspect(q.bill.totals.amount, content="2.55")
/// }
/// ```
pub fn quote_bill_quota(
  input : BillQuotaInput,
  scale~ : Int32,
  rounding~ : Rounding,
) -> BillQuota raise PricingError {
  ignore(bill_quota_items(input, 0N))
  let info = tariff_info(input.variable)
  ignore(settle_total(info.currency, "0", scale~, rounding~))
  let budget = amount_atoms(input.request.budget, "bill_quota.budget")
  let fixed_paid = if input.fixed.length() == 0 {
    0N
  } else {
    amount_atoms(
      rate_bill(input.fixed[:], scale~, rounding~).totals.amount,
      "bill_quota.fixed",
    )
  }
  if fixed_paid > budget {
    invalid(
      "infeasible", "bill_quota.budget", "fixed item settlements already exceed the budget",
    )
  }
  let available = budget - fixed_paid
  if !variable_fits(input, 0N, available, scale~, rounding~) {
    invalid(
      "infeasible", "bill_quota.budget", "zero variable usage already exceeds the remaining budget, including its minimum-spend policy",
    )
  }
  let limit = natural(input.request.limit, "bill_quota.limit")
  let mut quota = limit
  match input.variable {
    PackageTariff(_) =>
      if search_quantity(0N, limit, q => {
          variable_fits(input, q, available, scale~, rounding~)
        })
        is Some(q) {
        quota = q
      }
    MeteredTariff(p, _, _) => {
      // Zero-usage waiver is a distinct point. Every positive tier is monotone
      // internally even after taking max(raw, contractual minimum).
      let mut from = 1N
      while from <= limit {
        let (to, _, _) = curve_piece(p, from, limit)
        if !variable_fits(input, from, available, scale~, rounding~) {
          quota = from - 1N
          break
        }
        if !variable_fits(input, to, available, scale~, rounding~) {
          if search_quantity(from, to, q => {
              variable_fits(input, q, available, scale~, rounding~)
            })
            is Some(q) {
            quota = q
          }
          break
        }
        from = to + 1N
      }
    }
  }
  let bill = rate_bill(bill_quota_items(input, quota)[:], scale~, rounding~)
  let first_unaffordable = if quota < limit {
    Some(
      rate_bill(bill_quota_items(input, quota + 1N)[:], scale~, rounding~) catch {
        Invalid(code~, path~, message~) =>
          raise Invalid(
            code~,
            path="bill_quota.first_unaffordable." + path,
            message~,
          )
      },
    )
  } else {
    None
  }
  let report = {
    request: input.request,
    variable_metric: info.metric,
    bill,
    first_unaffordable,
  }
  verify_bill_quota(input, report, scale~, rounding~)
  report
}

///|
fn bill_evidence_usage(evidence : BillEvidence) -> Usage {
  match evidence {
    MeteredCharge(c) => c.calculation.usage
    PackageCharge(c) => c.usage
  }
}

///|
/// Verify fixed settlements, every model-specific witness and prefix safety.
/// Uses verified fixed amounts and rounding thresholds, never quota/rate producers.
pub fn verify_bill_quota(
  input : BillQuotaInput,
  report : BillQuota,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  check_budget(input.request)
  let info = tariff_info(input.variable)
  if report.request != input.request ||
    report.variable_metric != info.metric ||
    report.bill.items.length() != input.fixed.length() + 1 {
    invalid(
      "identity", "bill_quota", "request, variable metric and complete fixed/variable item coverage must match trusted input",
    )
  }
  let q = natural(
    bill_evidence_usage(report.bill.items[input.fixed.length()]).quantity,
    "bill_quota.quantity",
  )
  let limit = natural(input.request.limit, "bill_quota.limit")
  if q > limit {
    invalid(
      "limit", "bill_quota.quantity", "quota exceeds trusted search limit",
    )
  }
  verify_bill(bill_quota_items(input, q)[:], report.bill, scale~, rounding~)
  let budget = amount_atoms(input.request.budget, "bill_quota.budget")
  if amount_atoms(report.bill.totals.amount, "bill.amount") > budget {
    invalid(
      "budget", "bill_quota.quantity", "settled bill exceeds total budget",
    )
  }
  let mut fixed_paid = 0N
  for item in report.bill.items[:input.fixed.length()] {
    fixed_paid += amount_atoms(bill_item_amounts(item).3, "bill_quota.fixed")
  }
  let available = budget - fixed_paid
  match input.variable {
    MeteredTariff(p, minimum, _) if p.mode == Volume => {
      let floor = decimal(minimum, "bill_quota.minimum")
      let mut previous = 0N
      for tier in p.tiers {
        let upper = match tier.up_to {
          Some(n) => if n < q { n } else { q }
          None => q
        }
        if upper > previous {
          let raw = upper * tier.price
          let charge = if raw > floor { raw } else { floor }
          if !threshold_fits(charge, available, scale, rounding) {
            invalid(
              "prefix", "bill_quota.quantity", "an earlier positive volume quantity exceeds the whole-bill budget after its minimum is applied",
            )
          }
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
    _ => () // Graduated+floor and package charges are nondecreasing.
  }
  if q == limit {
    if report.first_unaffordable is Some(_) {
      invalid(
        "witness", "bill_quota.first_unaffordable", "no out-of-domain witness is accepted at the trusted limit",
      )
    }
  } else {
    guard report.first_unaffordable is Some(witness) else {
      invalid(
        "witness", "bill_quota.first_unaffordable", "a complete bill for exactly quota plus one is required",
      )
      return
    }
    verify_bill(bill_quota_items(input, q + 1N)[:], witness, scale~, rounding~) catch {
      Invalid(code~, path~, message~) =>
        raise Invalid(
          code~,
          path="bill_quota.first_unaffordable." + path,
          message~,
        )
    }
    if amount_atoms(witness.totals.amount, "bill.amount") <= budget {
      invalid(
        "witness", "bill_quota.first_unaffordable", "next complete bill is still affordable",
      )
    }
  }
}
