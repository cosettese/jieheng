///|
pub fn encode_bill_comparison(
  report : BillComparison,
) -> String raise PricingError {
  if report.changes.length() == 0 || report.changes.length() > 64 {
    invalid(
      "size", "bill_comparison.changes", "expected 1 to 64 metric changes",
    )
  }
  let changes : Array[Json] = report.changes.map(c => {
    "metric": c.metric,
    "unit": c.unit,
    "baseline_index": c.baseline_index,
    "candidate_index": c.candidate_index,
    "usage_delta": c.usage_delta,
    "top_up_delta": c.top_up_delta,
    "exact_delta": c.exact_delta,
    "settled_delta": c.settled_delta,
  })
  let json : Json = {
    "schema": "jieheng.bill-comparison.v1",
    "baseline": bill_json(report.baseline),
    "candidate": bill_json(report.candidate),
    "changes": changes,
    "exact_delta": report.exact_delta,
    "settled_delta": report.settled_delta,
  }
  bounded_json(json)
}

///|
/// Strict structural decode; verify_bill_comparison requires both trusted manifests.
pub fn decode_bill_comparison(
  text : String,
) -> BillComparison raise PricingError {
  let r = fields(
    parse_document(text),
    [
      "schema", "baseline", "candidate", "changes", "exact_delta", "settled_delta",
    ],
    "bill_comparison",
  )
  expect_value(r, "schema", "jieheng.bill-comparison.v1", "bill_comparison")
  let changes : Array[BillChange] = []
  for i, v in bounded_items(r["changes"], 64, "bill_comparison.changes") {
    let path = "bill_comparison.changes[\{i}]"
    let c = fields(
      v,
      [
        "metric", "unit", "baseline_index", "candidate_index", "usage_delta", "top_up_delta",
        "exact_delta", "settled_delta",
      ],
      path,
    )
    changes.push({
      metric: text_value(c["metric"], path + ".metric"),
      unit: text_value(c["unit"], path + ".unit"),
      baseline_index: small_integer(
        c["baseline_index"],
        63,
        path + ".baseline_index",
      ),
      candidate_index: small_integer(
        c["candidate_index"],
        63,
        path + ".candidate_index",
      ),
      usage_delta: text_value(c["usage_delta"], path + ".usage_delta"),
      top_up_delta: text_value(c["top_up_delta"], path + ".top_up_delta"),
      exact_delta: text_value(c["exact_delta"], path + ".exact_delta"),
      settled_delta: text_value(c["settled_delta"], path + ".settled_delta"),
    })
  }
  {
    baseline: bill_from_json(r["baseline"]),
    candidate: bill_from_json(r["candidate"]),
    changes,
    exact_delta: text_value(r["exact_delta"], "bill_comparison.exact_delta"),
    settled_delta: text_value(
      r["settled_delta"],
      "bill_comparison.settled_delta",
    ),
  }
}
