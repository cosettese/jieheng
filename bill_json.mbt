///|
fn item_kind(value : Json, path : String) -> String raise PricingError {
  guard value is Object(o) && o.contains("kind") else {
    invalid(
      "kind", path, "expected an object with explicit kind metered or package",
    )
    return ""
  }
  text_value(o["kind"], path + ".kind")
}

///|
pub fn encode_bill_input(
  items : ArrayView[BillItem],
) -> String raise PricingError {
  bounded_json(bill_input_json(items))
}

///|
fn bill_input_json(items : ArrayView[BillItem]) -> Json raise PricingError {
  ignore(check_bill(items))
  let values : Array[Json] = items.map(item => {
    match item {
      Metered(c) =>
        {
          "kind": "metered",
          "plan": plan_json(c.plan),
          "usage": usage_json(c.usage),
          "minimum": c.minimum,
          "zero_usage": zero_usage_name(c.zero_usage),
        }
      Packaged(p, u) =>
        {
          "kind": "package",
          "plan": package_plan_json(p),
          "usage": usage_json(u),
        }
    }
  })
  let json : Json = { "schema": "jieheng.bill-input.v1", "items": values }
  json
}

///|
pub fn decode_bill_input(text : String) -> Array[BillItem] raise PricingError {
  bill_input_from_json(parse_document(text))
}

///|
fn bill_input_from_json(value : Json) -> Array[BillItem] raise PricingError {
  let root = fields(value, ["schema", "items"], "bill")
  expect_value(root, "schema", "jieheng.bill-input.v1", "bill")
  let values = bounded_items(root["items"], 64, "bill.items")
  let items : Array[BillItem] = []
  for i, value in values {
    let path = "bill.items[\{i}]"
    match item_kind(value, path) {
      "metered" => {
        let r = fields(
          value,
          ["kind", "plan", "usage", "minimum", "zero_usage"],
          path,
        )
        items.push(
          Metered({
            plan: plan_from_json(r["plan"]),
            usage: usage_from_json(r["usage"]),
            minimum: text_value(r["minimum"], path + ".minimum"),
            zero_usage: zero_usage_from_name(
              text_value(r["zero_usage"], path + ".zero_usage"),
            ),
          }),
        )
      }
      "package" => {
        let r = fields(value, ["kind", "plan", "usage"], path)
        items.push(
          Packaged(
            package_plan_from_json(r["plan"]),
            usage_from_json(r["usage"]),
          ),
        )
      }
      _ =>
        invalid(
          "kind",
          path + ".kind",
          "only metered and package items are supported",
        )
    }
  }
  ignore(check_bill(items[:]))
  items
}

///|
pub fn encode_bill(bill : Bill) -> String raise PricingError {
  bounded_json(bill_json(bill))
}

///|
fn bill_json(bill : Bill) -> Json raise PricingError {
  if bill.items.length() == 0 || bill.items.length() > 64 {
    invalid("size", "bill.items", "expected 1 to 64 items")
  }
  let items : Array[Json] = bill.items.map(item => {
    match item {
      MeteredCharge(c) => { "kind": "metered", "evidence": charge_json(c) }
      PackageCharge(c) => { "kind": "package", "evidence": packages_json(c) }
    }
  })
  let t = bill.totals
  let json : Json = {
    "schema": "jieheng.bill.v1",
    "customer": bill.customer,
    "period": bill.period,
    "currency": bill.currency,
    "items": items,
    "totals": {
      "usage_total": t.usage_total,
      "top_up": t.top_up,
      "total": t.total,
      "scale": t.scale,
      "rounding": rounding_name(t.rounding),
      "minor_units": t.minor_units,
      "amount": t.amount,
      "delta": t.delta,
    },
  }
  json
}

///|
/// Strict structural decode; verify_bill requires the complete trusted manifest.
pub fn decode_bill(text : String) -> Bill raise PricingError {
  bill_from_json(parse_document(text))
}

///|
fn bill_from_json(value : Json) -> Bill raise PricingError {
  let r = fields(
    value,
    ["schema", "customer", "period", "currency", "items", "totals"],
    "bill",
  )
  expect_value(r, "schema", "jieheng.bill.v1", "bill")
  let values = bounded_items(r["items"], 64, "bill.items")
  let items : Array[BillEvidence] = []
  for i, value in values {
    let path = "bill.items[\{i}]"
    let v = fields(value, ["kind", "evidence"], path)
    match item_kind(value, path) {
      "metered" => items.push(MeteredCharge(charge_from_json(v["evidence"])))
      "package" => items.push(PackageCharge(packages_from_json(v["evidence"])))
      _ =>
        invalid(
          "kind",
          path + ".kind",
          "only metered and package evidence is supported",
        )
    }
  }
  let t = fields(
    r["totals"],
    [
      "usage_total", "top_up", "total", "scale", "rounding", "minor_units", "amount",
      "delta",
    ],
    "bill.totals",
  )
  {
    customer: text_value(r["customer"], "bill.customer"),
    period: text_value(r["period"], "bill.period"),
    currency: text_value(r["currency"], "bill.currency"),
    items,
    totals: {
      usage_total: text_value(t["usage_total"], "bill.usage_total"),
      top_up: text_value(t["top_up"], "bill.top_up"),
      total: text_value(t["total"], "bill.total"),
      scale: small_integer(t["scale"], 18, "bill.scale"),
      rounding: rounding_from_name(text_value(t["rounding"], "bill.rounding")),
      minor_units: text_value(t["minor_units"], "bill.minor_units"),
      amount: text_value(t["amount"], "bill.amount"),
      delta: text_value(t["delta"], "bill.delta"),
    },
  }
}
