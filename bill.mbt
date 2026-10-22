///|
/// Explicitly tagged inputs preserve each pricing model's complete contract.
pub(all) enum BillItem {
  Metered(ChargeInput)
  Packaged(PackagePlan, Usage)
}

///|
pub(all) enum BillEvidence {
  MeteredCharge(Charge)
  PackageCharge(PackageEvidence)
} derive(Debug, Eq)

///|
pub extend BillEvidence with Debug::{to_repr}

///|
pub extend BillEvidence with Eq::{equal, not_equal}

///|
/// Item settlements are summed without a second rounding operation.
pub(all) struct BillTotals {
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
pub extend BillTotals with Debug::{to_repr}

///|
pub extend BillTotals with Eq::{equal, not_equal}

///|
pub(all) struct Bill {
  customer : String
  period : String
  currency : String
  items : Array[BillEvidence]
  totals : BillTotals
} derive(Debug, Eq)

///|
pub extend Bill with Debug::{to_repr}

///|
pub extend Bill with Eq::{equal, not_equal}

///|
fn bill_identity(item : BillItem) -> (Usage, String) raise PricingError {
  match item {
    Metered(input) => {
      ignore(validate_usage(input.plan, input.usage))
      ignore(decimal(input.minimum, "minimum"))
      (input.usage, input.plan.currency)
    }
    Packaged(plan, usage) => {
      ignore(package_quantity(plan, usage))
      (usage, plan.currency)
    }
  }
}

///|
fn check_bill(
  items : ArrayView[BillItem],
) -> (Usage, String) raise PricingError {
  if items.length() == 0 || items.length() > 64 {
    invalid(
      "size", "bill.items", "provide 1 to 64 explicitly tagged metric items",
    )
  }
  let (first, currency) = bill_identity(items[0])
  let seen : Map[String, Unit] = Map([])
  for i, item in items {
    let (usage, c) = bill_identity(item) catch {
      Invalid(code~, path~, message~) =>
        raise Invalid(code~, path="bill.items[\{i}]." + path, message~)
    }
    if usage.customer != first.customer ||
      usage.period != first.period ||
      c != currency {
      invalid(
        "identity",
        "bill.items[\{i}]",
        "all items must share customer, period and currency",
      )
    }
    if seen.contains(usage.metric) {
      invalid(
        "duplicate",
        "bill.items[\{i}].metric",
        "a metric can be billed only once across all pricing models",
      )
    }
    seen[usage.metric] = ()
  }
  (first, currency)
}

///|
/// Combine metered and package items with their original evidence intact.
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
///   let b = @jieheng.rate_bill(
///     [
///       Packaged(p, {
///         customer: "acme",
///         metric: "messages",
///         period: "2026-10",
///         quantity: "2501",
///       }),
///     ],
///     scale=2,
///     rounding=HalfEven,
///   )
///   inspect(b.totals.amount, content="2.55")
/// }
/// ```
pub fn rate_bill(
  items : ArrayView[BillItem],
  scale~ : Int32,
  rounding~ : Rounding,
) -> Bill raise PricingError {
  let (usage, currency) = check_bill(items)
  let records : Array[BillEvidence] = []
  for i, item in items {
    let record = try {
      match item {
        Metered(c) =>
          MeteredCharge(
            rate_charge(
              c.plan,
              c.usage,
              minimum=c.minimum,
              zero_usage=c.zero_usage,
              scale~,
              rounding~,
            ),
          )
        Packaged(p, u) => PackageCharge(rate_packages(p, u, scale~, rounding~))
      }
    } catch {
      Invalid(code~, path~, message~) =>
        raise Invalid(code~, path="bill.items[\{i}]." + path, message~)
    }
    records.push(record)
  }
  let bill = {
    customer: usage.customer,
    period: usage.period,
    currency,
    items: records,
    totals: bill_totals(records[:], scale~, rounding~),
  }
  verify_bill(items, bill, scale~, rounding~)
  bill
}

///|
fn bill_totals(
  items : ArrayView[BillEvidence],
  scale~ : Int32,
  rounding~ : Rounding,
) -> BillTotals raise PricingError {
  let mut raw = 0N
  let mut top_up = 0N
  let mut exact = 0N
  let mut units = 0N
  for item in items {
    let (r, t, total, s) = match item {
      MeteredCharge(c) => (c.calculation.total, c.top_up, c.total, c.settlement)
      PackageCharge(c) => (c.total, "0", c.total, c.settlement)
    }
    raw += amount_atoms(r, "bill.usage_total")
    top_up += amount_atoms(t, "bill.top_up")
    exact += amount_atoms(total, "bill.total")
    units += wide_natural(s.minor_units, 78, "bill.minor_units")
  }
  for n in [raw, top_up, exact] {
    ignore(amount_atoms(format_atoms(n), "bill.totals"))
  }
  let amount = fixed_amount(units, scale)
  let paid = amount_atoms(amount, "bill.amount")
  {
    usage_total: format_atoms(raw),
    top_up: format_atoms(top_up),
    total: format_atoms(exact),
    scale,
    rounding,
    minor_units: units.to_string(),
    amount,
    delta: format_atoms(paid - exact),
  }
}

///|
/// Reject model substitution, omission, reordering and forged totals. Each item
/// is checked by its independent pricing verifier, against the trusted manifest.
pub fn verify_bill(
  items : ArrayView[BillItem],
  bill : Bill,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  let (usage, currency) = check_bill(items)
  if bill.customer != usage.customer ||
    bill.period != usage.period ||
    bill.currency != currency ||
    bill.items.length() != items.length() {
    invalid(
      "identity", "bill", "bill identity and ordered item coverage must match trusted inputs",
    )
  }
  for i, item in items {
    try {
      match (item, bill.items[i]) {
        (Metered(c), MeteredCharge(e)) =>
          verify_charge(
            c.plan,
            c.usage,
            e,
            minimum=c.minimum,
            zero_usage=c.zero_usage,
            scale~,
            rounding~,
          )
        (Packaged(p, u), PackageCharge(e)) =>
          verify_packages(p, u, e, scale~, rounding~)
        _ =>
          invalid(
            "model", "kind", "evidence kind must match the trusted pricing model",
          )
      }
    } catch {
      Invalid(code~, path~, message~) =>
        raise Invalid(code~, path="bill.items[\{i}]." + path, message~)
    }
  }
  if bill.totals != bill_totals(bill.items[:], scale~, rounding~) {
    invalid(
      "total", "bill.totals", "expected exact item totals and the sum of independently verified item minor units",
    )
  }
}
