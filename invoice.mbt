///|
/// Trusted charge input: one already aggregated metric, one plan and one floor.
/// Plans are validated snapshots; arrays are consumed without being retained.
pub(all) struct ChargeInput {
  plan : Plan
  usage : Usage
  minimum : String
  zero_usage : ZeroUsageMinimum
}

///|
/// Pricing statement, not a legal invoice or payment instruction.
/// Each charge is settled separately; amount sums those settlements exactly.
/// delta = amount - total can exceed one minor unit over multiple charges.
pub(all) struct Invoice {
  customer : String
  period : String
  currency : String
  charges : Array[Charge]
  usage_total : String
  top_up : String
  total : String
  scale : Int32
  rounding : Rounding
  minor_units : String
  amount : String
  delta : String
} derive(Debug, Eq)

///|
pub extend Invoice with Debug::{to_repr}

///|
pub extend Invoice with Eq::{equal, not_equal}

///|
fn check_invoice_inputs(
  items : ArrayView[ChargeInput],
) -> Unit raise PricingError {
  if items.length() == 0 || items.length() > 64 {
    invalid("size", "invoice.items", "provide 1 to 64 metric charges")
  }
  let first = items[0]
  let seen : Map[String, Unit] = Map([])
  for i, item in items {
    let path = "invoice.items[\{i}]"
    ignore(validate_usage(item.plan, item.usage)) catch {
      Invalid(code~, path=inner, message~) =>
        raise Invalid(code~, path=path + "." + inner, message~)
    }
    ignore(decimal(item.minimum, path + ".minimum"))
    if item.usage.customer != first.usage.customer ||
      item.usage.period != first.usage.period ||
      item.plan.currency != first.plan.currency {
      invalid(
        "identity", path, "all charges must share one customer, period and currency; no FX conversion is supported",
      )
    }
    if seen.contains(item.usage.metric) {
      invalid(
        "duplicate",
        path + ".usage.metric",
        "one charge per metric is supported; aggregate duplicate metrics before rating",
      )
    }
    seen[item.usage.metric] = ()
  }
}

///|
/// Rate multiple metrics for one customer-period, apply each explicit minimum,
/// settle each charge, then sum minor units without a second rounding operation.
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
///   let bill = @jieheng.rate_invoice(
///     [
///       {
///         plan: p,
///         usage: {
///           customer: "acme",
///           metric: "calls",
///           period: "2026-10",
///           quantity: "1",
///         },
///         minimum: "0",
///         zero_usage: Waive,
///       },
///     ],
///     scale=2,
///     rounding=HalfEven,
///   )
///   inspect(bill.total, content="0.006")
///   inspect(bill.amount, content="0.01")
/// }
/// ```
pub fn rate_invoice(
  items : ArrayView[ChargeInput],
  scale~ : Int32,
  rounding~ : Rounding,
) -> Invoice raise PricingError {
  check_invoice_inputs(items)
  let charges : Array[Charge] = []
  for i, item in items {
    charges.push(
      rate_charge(
        item.plan,
        item.usage,
        minimum=item.minimum,
        zero_usage=item.zero_usage,
        scale~,
        rounding~,
      ) catch {
        Invalid(code~, path~, message~) =>
          raise Invalid(code~, path="invoice.items[\{i}]." + path, message~)
      },
    )
  }
  let report = invoice_totals(charges[:], scale~, rounding~)
  verify_invoice(items, report, scale~, rounding~)
  report
}

///|
fn invoice_totals(
  charges : ArrayView[Charge],
  scale~ : Int32,
  rounding~ : Rounding,
) -> Invoice raise PricingError {
  let mut raw = 0N
  let mut top_up = 0N
  let mut total = 0N
  let mut units = 0N
  for charge in charges {
    raw += amount_atoms(charge.calculation.total, "invoice.usage_total")
    top_up += amount_atoms(charge.top_up, "invoice.top_up")
    total += amount_atoms(charge.total, "invoice.total")
    units += wide_natural(
      charge.settlement.minor_units,
      78,
      "invoice.minor_units",
    )
  }
  let amount = fixed_amount(units, scale)
  let paid = amount_atoms(amount, "invoice.amount")
  for n in [raw, top_up, total] {
    ignore(amount_atoms(format_atoms(n), "invoice.totals"))
  }
  let first = charges[0].calculation
  {
    customer: first.usage.customer,
    period: first.usage.period,
    currency: first.currency,
    charges: charges.to_owned(),
    usage_total: format_atoms(raw),
    top_up: format_atoms(top_up),
    total: format_atoms(total),
    scale,
    rounding,
    minor_units: units.to_string(),
    amount,
    delta: format_atoms(paid - total),
  }
}

///|
/// Verify against the complete trusted item list and settlement policy.
/// Missing/reordered/duplicated charges and all forged aggregates are rejected.
pub fn verify_invoice(
  items : ArrayView[ChargeInput],
  invoice : Invoice,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  check_invoice_inputs(items)
  if invoice.charges.length() != items.length() {
    invalid(
      "coverage", "invoice.charges", "exactly one charge is required per trusted input, in the original order",
    )
  }
  for i, item in items {
    verify_charge(
      item.plan,
      item.usage,
      invoice.charges[i],
      minimum=item.minimum,
      zero_usage=item.zero_usage,
      scale~,
      rounding~,
    ) catch {
      Invalid(code~, path~, message~) =>
        raise Invalid(code~, path="invoice.charges[\{i}]." + path, message~)
    }
  }
  let expected = invoice_totals(invoice.charges[:], scale~, rounding~)
  if invoice != expected {
    invalid(
      "total", "invoice.totals", "identity, policy and all totals must match the independently verified per-charge settlements; no invoice-wide re-rounding",
    )
  }
}
