///|
pub fn encode_bill_quota_input(
  input : BillQuotaInput,
) -> String raise PricingError {
  ignore(bill_quota_items(input, 0N))
  let fixed = if input.fixed.length() == 0 {
    Json::null()
  } else {
    bill_input_json(input.fixed[:])
  }
  let json : Json = {
    "schema": "jieheng.bill-quota-input.v1",
    "fixed": fixed,
    "variable": tariff_json(input.variable),
    "request": budget_request_json(input.request),
  }
  bounded_json(json)
}

///|
pub fn decode_bill_quota_input(
  text : String,
) -> BillQuotaInput raise PricingError {
  let r = fields(
    parse_document(text),
    ["schema", "fixed", "variable", "request"],
    "bill_quota",
  )
  expect_value(r, "schema", "jieheng.bill-quota-input.v1", "bill_quota")
  let fixed = match r["fixed"] {
    Null => []
    value => bill_input_from_json(value)
  }
  let input = {
    fixed,
    variable: tariff_from_json(r["variable"], "bill_quota.variable"),
    request: budget_request_from_json(r["request"]),
  }
  ignore(bill_quota_items(input, 0N))
  input
}

///|
pub fn encode_bill_quota(report : BillQuota) -> String raise PricingError {
  check_budget(report.request)
  let json : Json = {
    "schema": "jieheng.bill-quota.v1",
    "request": budget_request_json(report.request),
    "variable_metric": report.variable_metric,
    "bill": bill_json(report.bill),
    "first_unaffordable": match report.first_unaffordable {
      Some(b) => bill_json(b)
      None => Json::null()
    },
  }
  bounded_json(json)
}

///|
/// Structural decode only; accept after verify_bill_quota with complete trusted input.
pub fn decode_bill_quota(text : String) -> BillQuota raise PricingError {
  let r = fields(
    parse_document(text),
    ["schema", "request", "variable_metric", "bill", "first_unaffordable"],
    "bill_quota",
  )
  expect_value(r, "schema", "jieheng.bill-quota.v1", "bill_quota")
  {
    request: budget_request_from_json(r["request"]),
    variable_metric: text_value(
      r["variable_metric"],
      "bill_quota.variable_metric",
    ),
    bill: bill_from_json(r["bill"]),
    first_unaffordable: match r["first_unaffordable"] {
      Null => None
      value => Some(bill_from_json(value))
    },
  }
}
