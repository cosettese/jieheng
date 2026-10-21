///|
fn check_usage(usage : Usage) -> Unit raise PricingError {
  label(usage.customer, "usage.customer")
  label(usage.metric, "usage.metric")
  label(usage.period, "usage.period")
  ignore(natural(usage.quantity, "usage.quantity"))
}

///|
/// Decode one already aggregated usage snapshot, without implicit coercions.
pub fn decode_usage(text : String) -> Usage raise PricingError {
  usage_from_json(parse_document(text))
}

///|
fn usage_from_json(value : Json) -> Usage raise PricingError {
  let object = fields(
    value,
    ["schema", "customer", "metric", "period", "quantity"],
    "usage",
  )
  expect_value(object, "schema", "jieheng.usage.v1", "usage")
  let usage = {
    customer: text_value(object["customer"], "usage.customer"),
    metric: text_value(object["metric"], "usage.metric"),
    period: text_value(object["period"], "usage.period"),
    quantity: text_value(object["quantity"], "usage.quantity"),
  }
  check_usage(usage)
  usage
}

///|
/// Validate before encoding; no unknown data can be silently lost.
pub fn encode_usage(usage : Usage) -> String raise PricingError {
  check_usage(usage)
  usage_json(usage).stringify()
}

///|
fn usage_json(usage : Usage) -> Json {
  {
    "schema": "jieheng.usage.v1",
    "customer": usage.customer,
    "metric": usage.metric,
    "period": usage.period,
    "quantity": usage.quantity,
  }
}
