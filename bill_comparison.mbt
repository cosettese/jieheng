///|
/// Candidate minus baseline for one identical metric snapshot. Indices preserve
/// both original bill orders; the change list follows the baseline order.
pub(all) struct BillChange {
  metric : String
  unit : String
  baseline_index : Int32
  candidate_index : Int32
  usage_delta : String
  top_up_delta : String
  exact_delta : String
  settled_delta : String
} derive(Debug, Eq)

///|
pub extend BillChange with Debug::{to_repr}

///|
pub extend BillChange with Eq::{equal, not_equal}

///|
pub(all) struct BillComparison {
  baseline : Bill
  candidate : Bill
  changes : Array[BillChange]
  exact_delta : String
  settled_delta : String
} derive(Debug, Eq)

///|
pub extend BillComparison with Debug::{to_repr}

///|
pub extend BillComparison with Eq::{equal, not_equal}

///|
fn bill_item_unit(item : BillItem) -> String {
  match item {
    Metered(c) => c.plan.unit
    Packaged(p, _) => p.unit
  }
}

///|
fn align_bills(
  before : ArrayView[BillItem],
  after : ArrayView[BillItem],
) -> Array[Int32] raise PricingError {
  let (bu, bc) = check_bill(before)
  let (au, ac) = check_bill(after)
  if bu.customer != au.customer ||
    bu.period != au.period ||
    bc != ac ||
    before.length() != after.length() {
    invalid(
      "identity", "bill_comparison", "both manifests must share customer, period, currency and the complete metric set",
    )
  }
  let indices : Map[String, Int32] = Map([])
  for i, item in after {
    indices[bill_identity(item).0.metric] = i
  }
  let aligned : Array[Int32] = []
  for i, item in before {
    let (usage, _) = bill_identity(item)
    guard indices.get(usage.metric) is Some(j) else {
      invalid(
        "coverage",
        "bill_comparison",
        "candidate is missing metric '\{usage.metric}'",
      )
      return []
    }
    if usage != bill_identity(after[j]).0 ||
      bill_item_unit(item) != bill_item_unit(after[j]) {
      invalid(
        "usage",
        "bill_comparison.items[\{i}]",
        "each metric must retain exactly the same usage and unit; no implicit conversion",
      )
    }
    aligned.push(j)
  }
  aligned
}

///|
fn bill_item_amounts(e : BillEvidence) -> (String, String, String, String) {
  match e {
    MeteredCharge(c) =>
      (c.calculation.total, c.top_up, c.total, c.settlement.amount)
    PackageCharge(c) => (c.total, "0", c.total, c.settlement.amount)
  }
}

///|
fn amount_difference(
  before : String,
  after : String,
) -> String raise PricingError {
  format_atoms(
    amount_atoms(after, "candidate.amount") -
    amount_atoms(before, "baseline.amount"),
  )
}

///|
fn bill_changes(
  before : ArrayView[BillItem],
  alignment : ArrayView[Int32],
  baseline : Bill,
  candidate : Bill,
) -> Array[BillChange] raise PricingError {
  let rows : Array[BillChange] = []
  for i, item in before {
    let j = alignment[i]
    let (br, bf, bt, bs) = bill_item_amounts(baseline.items[i])
    let (ar, af, at, ass) = bill_item_amounts(candidate.items[j])
    rows.push({
      metric: bill_identity(item).0.metric,
      unit: bill_item_unit(item),
      baseline_index: i,
      candidate_index: j,
      usage_delta: amount_difference(br, ar),
      top_up_delta: amount_difference(bf, af),
      exact_delta: amount_difference(bt, at),
      settled_delta: amount_difference(bs, ass),
    })
  }
  rows
}

///|
/// Compare identical metric usages across full mixed contracts, aligning by
/// metric rather than position. Pricing models and minimum policies may change.
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
///   let items : Array[@jieheng.BillItem] = [
///     Packaged(p, {
///       customer: "acme",
///       metric: "messages",
///       period: "October",
///       quantity: "2501",
///     }),
///   ]
///   let c = @jieheng.compare_bills(items[:], items[:], scale=2, rounding=HalfEven)
///   inspect(c.exact_delta, content="0")
/// }
/// ```
pub fn compare_bills(
  before : ArrayView[BillItem],
  after : ArrayView[BillItem],
  scale~ : Int32,
  rounding~ : Rounding,
) -> BillComparison raise PricingError {
  let alignment = align_bills(before, after)
  let baseline = rate_bill(before, scale~, rounding~)
  let candidate = rate_bill(after, scale~, rounding~)
  let report = {
    baseline,
    candidate,
    changes: bill_changes(before, alignment[:], baseline, candidate),
    exact_delta: amount_difference(
      baseline.totals.total,
      candidate.totals.total,
    ),
    settled_delta: amount_difference(
      baseline.totals.amount,
      candidate.totals.amount,
    ),
  }
  verify_bill_comparison(before, after, report, scale~, rounding~)
  report
}

///|
/// Verify both complete bills against trusted manifests, then check alignment
/// and every signed difference. Does not invoke compare_bills or rate_bill.
pub fn verify_bill_comparison(
  before : ArrayView[BillItem],
  after : ArrayView[BillItem],
  report : BillComparison,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  let alignment = align_bills(before, after)
  verify_bill(before, report.baseline, scale~, rounding~) catch {
    Invalid(code~, path~, message~) =>
      raise Invalid(code~, path="bill_comparison.baseline." + path, message~)
  }
  verify_bill(after, report.candidate, scale~, rounding~) catch {
    Invalid(code~, path~, message~) =>
      raise Invalid(code~, path="bill_comparison.candidate." + path, message~)
  }
  if report.changes !=
    bill_changes(before, alignment[:], report.baseline, report.candidate) ||
    report.exact_delta !=
    amount_difference(
      report.baseline.totals.total,
      report.candidate.totals.total,
    ) ||
    report.settled_delta !=
    amount_difference(
      report.baseline.totals.amount,
      report.candidate.totals.amount,
    ) {
    invalid(
      "delta", "bill_comparison.changes", "preserve every aligned metric and its usage/top-up/exact/settled differences; totals must conserve verified item amounts",
    )
  }
}
