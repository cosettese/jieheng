///|
/// Encode all typed fields in deterministic order; verify before accepting data.
pub fn encode_comparison(report : Comparison) -> String {
  let json : Json = {
    "schema": "jieheng.comparison.v1",
    "baseline": evidence_json(report.baseline),
    "candidate": evidence_json(report.candidate),
    "exact_delta": report.exact_delta,
    "settled_delta": report.settled_delta,
  }
  json.stringify()
}

///|
/// Strict structural decoder; semantic acceptance requires verify_comparison.
pub fn decode_comparison(text : String) -> Comparison raise PricingError {
  let object = fields(
    parse_document(text),
    ["schema", "baseline", "candidate", "exact_delta", "settled_delta"],
    "comparison",
  )
  expect_value(object, "schema", "jieheng.comparison.v1", "comparison")
  {
    baseline: comparison_side(object["baseline"], "baseline"),
    candidate: comparison_side(object["candidate"], "candidate"),
    exact_delta: text_value(object["exact_delta"], "comparison.exact_delta"),
    settled_delta: text_value(
      object["settled_delta"],
      "comparison.settled_delta",
    ),
  }
}

///|
fn comparison_side(value : Json, side : String) -> Evidence raise PricingError {
  evidence_from_json(value) catch {
    Invalid(code~, path~, message~) =>
      raise Invalid(code~, path="comparison." + side + "." + path, message~)
  }
}
