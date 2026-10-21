///|
/// Encode a complete trusted input manifest with embedded validated plans.
pub fn encode_invoice_input(
  items : ArrayView[ChargeInput],
) -> String raise PricingError {
  check_invoice_inputs(items)
  let entries : Array[Json] = items.map(item => {
    "plan": plan_json(item.plan),
    "usage": usage_json(item.usage),
    "minimum": item.minimum,
    "zero_usage": zero_usage_name(item.zero_usage),
  })
  let json : Json = { "schema": "jieheng.invoice-input.v1", "items": entries }
  bounded_json(json)
}

///|
pub fn decode_invoice_input(
  text : String,
) -> Array[ChargeInput] raise PricingError {
  let root = fields(parse_document(text), ["schema", "items"], "invoice")
  expect_value(root, "schema", "jieheng.invoice-input.v1", "invoice")
  let entries = bounded_items(root["items"], 64, "invoice.items")
  let items : Array[ChargeInput] = []
  for i, entry in entries {
    let path = "invoice.items[\{i}]"
    let item = fields(entry, ["plan", "usage", "minimum", "zero_usage"], path)
    items.push({
      plan: plan_from_json(item["plan"]),
      usage: usage_from_json(item["usage"]),
      minimum: text_value(item["minimum"], path + ".minimum"),
      zero_usage: zero_usage_from_name(
        text_value(item["zero_usage"], path + ".zero_usage"),
      ),
    })
  }
  check_invoice_inputs(items[:])
  items
}

///|
/// Structural encoding; verify_invoice is required for semantic acceptance.
pub fn encode_invoice(invoice : Invoice) -> String raise PricingError {
  if invoice.charges.length() == 0 || invoice.charges.length() > 64 {
    invalid("size", "invoice.charges", "expected 1 to 64 charges")
  }
  let json : Json = {
    "schema": "jieheng.invoice.v1",
    "customer": invoice.customer,
    "period": invoice.period,
    "currency": invoice.currency,
    "charges": invoice.charges.map(charge_json),
    "usage_total": invoice.usage_total,
    "top_up": invoice.top_up,
    "total": invoice.total,
    "scale": invoice.scale,
    "rounding": rounding_name(invoice.rounding),
    "minor_units": invoice.minor_units,
    "amount": invoice.amount,
    "delta": invoice.delta,
  }
  bounded_json(json)
}

///|
pub fn decode_invoice(text : String) -> Invoice raise PricingError {
  let root = fields(
    parse_document(text),
    [
      "schema", "customer", "period", "currency", "charges", "usage_total", "top_up",
      "total", "scale", "rounding", "minor_units", "amount", "delta",
    ],
    "invoice",
  )
  expect_value(root, "schema", "jieheng.invoice.v1", "invoice")
  {
    customer: text_value(root["customer"], "invoice.customer"),
    period: text_value(root["period"], "invoice.period"),
    currency: text_value(root["currency"], "invoice.currency"),
    charges: bounded_items(root["charges"], 64, "invoice.charges").map(
      charge_from_json,
    ),
    usage_total: text_value(root["usage_total"], "invoice.usage_total"),
    top_up: text_value(root["top_up"], "invoice.top_up"),
    total: text_value(root["total"], "invoice.total"),
    scale: small_integer(root["scale"], 18, "invoice.scale"),
    rounding: rounding_from_name(
      text_value(root["rounding"], "invoice.rounding"),
    ),
    minor_units: text_value(root["minor_units"], "invoice.minor_units"),
    amount: text_value(root["amount"], "invoice.amount"),
    delta: text_value(root["delta"], "invoice.delta"),
  }
}
