///|
/// Encode an ordered cohort input; identities must be unique.
pub fn encode_cohort_usage(
  usages : ArrayView[Usage],
) -> String raise PricingError {
  check_cohort(usages)
  let json : Json = {
    "schema": "jieheng.cohort-usage.v1",
    "usages": usages.map(usage_json),
  }
  bounded_json(json)
}

///|
pub fn decode_cohort_usage(text : String) -> Array[Usage] raise PricingError {
  let root = fields(parse_document(text), ["schema", "usages"], "cohort")
  expect_value(root, "schema", "jieheng.cohort-usage.v1", "cohort")
  let items = bounded_items(root["usages"], 256, "cohort.usages")
  let usages = items.map(usage_from_json)
  check_cohort(usages[:])
  usages
}

///|
fn bounded_items(
  value : Json,
  max : Int32,
  path : String,
) -> Array[Json] raise PricingError {
  guard value is Array(items) else {
    invalid("type", path, "expected an array")
    return []
  }
  if items.length() == 0 || items.length() > max {
    invalid("size", path, "expected 1 to \{max} entries")
  }
  items
}

///|
fn bounded_json(value : Json) -> String raise PricingError {
  let text = value.stringify()
  if text.length() > 1048576 {
    invalid(
      "size", "$", "encoded document exceeds the 1048576 UTF-16 code unit exchange limit; split the request",
    )
  }
  text
}

///|
/// Structural encoding only; verify against trusted plans and usages on receipt.
pub fn encode_cohort(report : CohortComparison) -> String raise PricingError {
  if report.rows.length() == 0 || report.rows.length() > 256 {
    invalid("size", "cohort.rows", "expected 1 to 256 rows")
  }
  let json : Json = {
    "schema": "jieheng.cohort-comparison.v1",
    "rows": report.rows.map(comparison_json),
    "baseline_exact": report.baseline_exact,
    "candidate_exact": report.candidate_exact,
    "baseline_settled": report.baseline_settled,
    "candidate_settled": report.candidate_settled,
    "exact_delta": report.exact_delta,
    "settled_delta": report.settled_delta,
  }
  bounded_json(json)
}

///|
pub fn decode_cohort(text : String) -> CohortComparison raise PricingError {
  let root = fields(
    parse_document(text),
    [
      "schema", "rows", "baseline_exact", "candidate_exact", "baseline_settled",
      "candidate_settled", "exact_delta", "settled_delta",
    ],
    "cohort",
  )
  expect_value(root, "schema", "jieheng.cohort-comparison.v1", "cohort")
  {
    rows: bounded_items(root["rows"], 256, "cohort.rows").map(
      comparison_from_json,
    ),
    baseline_exact: text_value(root["baseline_exact"], "cohort.baseline_exact"),
    candidate_exact: text_value(
      root["candidate_exact"],
      "cohort.candidate_exact",
    ),
    baseline_settled: text_value(
      root["baseline_settled"],
      "cohort.baseline_settled",
    ),
    candidate_settled: text_value(
      root["candidate_settled"],
      "cohort.candidate_settled",
    ),
    exact_delta: text_value(root["exact_delta"], "cohort.exact_delta"),
    settled_delta: text_value(root["settled_delta"], "cohort.settled_delta"),
  }
}
