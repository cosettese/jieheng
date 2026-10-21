///|
fn zero_usage_name(value : ZeroUsageMinimum) -> String {
  match value {
    Charge => "charge"
    Waive => "waive"
  }
}

///|
fn zero_usage_from_name(value : String) -> ZeroUsageMinimum raise PricingError {
  match value {
    "charge" => Charge
    "waive" => Waive
    _ => {
      invalid(
        "policy", "charge.zero_usage", "choose charge or waive explicitly",
      )
      Waive
    }
  }
}

///|
fn charge_json(charge : Charge) -> Json {
  {
    "schema": "jieheng.charge.v1",
    "calculation": calculation_json(charge.calculation),
    "minimum": charge.minimum,
    "zero_usage": zero_usage_name(charge.zero_usage),
    "top_up": charge.top_up,
    "total": charge.total,
    "settlement": settlement_json(charge.settlement),
  }
}

///|
/// Structural encoding; semantic acceptance requires verify_charge.
pub fn encode_charge(charge : Charge) -> String raise PricingError {
  bounded_json(charge_json(charge))
}

///|
pub fn decode_charge(text : String) -> Charge raise PricingError {
  charge_from_json(parse_document(text))
}

///|
fn charge_from_json(value : Json) -> Charge raise PricingError {
  let root = fields(
    value,
    [
      "schema", "calculation", "minimum", "zero_usage", "top_up", "total", "settlement",
    ],
    "charge",
  )
  expect_value(root, "schema", "jieheng.charge.v1", "charge")
  {
    calculation: calculation_from_json(root["calculation"]),
    minimum: text_value(root["minimum"], "charge.minimum"),
    zero_usage: zero_usage_from_name(
      text_value(root["zero_usage"], "charge.zero_usage"),
    ),
    top_up: text_value(root["top_up"], "charge.top_up"),
    total: text_value(root["total"], "charge.total"),
    settlement: settlement_from_json(root["settlement"]),
  }
}
