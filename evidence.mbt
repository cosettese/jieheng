///|
/// A transport record, not a signature or an authenticated invoice.
pub(all) struct Evidence {
  calculation : Calculation
  settlement : Settlement
} derive(Debug, Eq)

///|
pub extend Evidence with Debug::{to_repr}

///|
pub extend Evidence with Eq::{equal, not_equal}

///|
/// Verify against trusted inputs and policy, never against embedded claims alone.
pub fn verify_evidence(
  plan : Plan,
  usage : Usage,
  evidence : Evidence,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  verify_calculation(plan, usage, evidence.calculation)
  verify_settlement(
    evidence.calculation,
    evidence.settlement,
    scale~,
    rounding~,
  )
}

///|
fn rounding_name(rounding : Rounding) -> String {
  match rounding {
    HalfEven => "half-even"
    HalfUp => "half-up"
    Down => "down"
    Up => "up"
  }
}

///|
fn rounding_from_name(text : String) -> Rounding raise PricingError {
  match text {
    "half-even" => HalfEven
    "half-up" => HalfUp
    "down" => Down
    "up" => Up
    _ =>
      raise Invalid(
        code="rounding",
        path="settlement.rounding",
        message="choose half-even, half-up, down, or up",
      )
  }
}

///|
/// Encode every typed field in deterministic schema order.
/// Does not validate authenticity: use verify_evidence before accepting a record.
pub fn encode_evidence(evidence : Evidence) -> String {
  evidence_json(evidence).stringify()
}

///|
fn evidence_json(evidence : Evidence) -> Json {
  {
    "schema": "jieheng.evidence.v1",
    "calculation": calculation_json(evidence.calculation),
    "settlement": settlement_json(evidence.settlement),
  }
}

///|
fn calculation_json(c : Calculation) -> Json {
  let lines : Array[Json] = []
  for line in c.lines {
    lines.push({
      "tier": line.tier,
      "from_exclusive": line.from_exclusive,
      "to_inclusive": line.to_inclusive,
      "quantity": line.quantity,
      "unit_price": line.unit_price,
      "subtotal": line.subtotal,
    })
  }
  {
    "plan_id": c.plan_id,
    "plan_version": c.plan_version,
    "currency": c.currency,
    "unit": c.unit,
    "usage": usage_json(c.usage),
    "lines": lines,
    "total": c.total,
  }
}

///|
fn settlement_json(s : Settlement) -> Json {
  {
    "currency": s.currency,
    "scale": s.scale,
    "rounding": rounding_name(s.rounding),
    "minor_units": s.minor_units,
    "amount": s.amount,
    "delta": s.delta,
  }
}

///|
/// Strict structural decoder; semantic acceptance requires verify_evidence.
pub fn decode_evidence(text : String) -> Evidence raise PricingError {
  evidence_from_json(parse_document(text))
}

///|
fn evidence_from_json(value : Json) -> Evidence raise PricingError {
  let root = fields(value, ["schema", "calculation", "settlement"], "evidence")
  expect_value(root, "schema", "jieheng.evidence.v1", "evidence")
  {
    calculation: calculation_from_json(root["calculation"]),
    settlement: settlement_from_json(root["settlement"]),
  }
}

///|
fn calculation_from_json(value : Json) -> Calculation raise PricingError {
  let c = fields(
    value,
    ["plan_id", "plan_version", "currency", "unit", "usage", "lines", "total"],
    "calculation",
  )
  guard c["lines"] is Array(items) else {
    raise Invalid(
      code="type",
      path="calculation.lines",
      message="expected an array",
    )
  }
  if items.length() > 1024 {
    invalid("size", "calculation.lines", "maximum 1024 lines")
  }
  let lines : Array[Line] = []
  for i, item in items {
    let path = "calculation.lines[\{i}]"
    let line = fields(
      item,
      [
        "tier", "from_exclusive", "to_inclusive", "quantity", "unit_price", "subtotal",
      ],
      path,
    )
    lines.push({
      tier: small_integer(line["tier"], 1023, path + ".tier"),
      from_exclusive: text_value(
        line["from_exclusive"],
        path + ".from_exclusive",
      ),
      to_inclusive: text_value(line["to_inclusive"], path + ".to_inclusive"),
      quantity: text_value(line["quantity"], path + ".quantity"),
      unit_price: text_value(line["unit_price"], path + ".unit_price"),
      subtotal: text_value(line["subtotal"], path + ".subtotal"),
    })
  }
  {
    plan_id: text_value(c["plan_id"], "calculation.plan_id"),
    plan_version: text_value(c["plan_version"], "calculation.plan_version"),
    currency: text_value(c["currency"], "calculation.currency"),
    unit: text_value(c["unit"], "calculation.unit"),
    usage: usage_from_json(c["usage"]),
    lines,
    total: text_value(c["total"], "calculation.total"),
  }
}

///|
fn settlement_from_json(value : Json) -> Settlement raise PricingError {
  let s = fields(
    value,
    ["currency", "scale", "rounding", "minor_units", "amount", "delta"],
    "settlement",
  )
  {
    currency: text_value(s["currency"], "settlement.currency"),
    scale: small_integer(s["scale"], 18, "settlement.scale"),
    rounding: rounding_from_name(
      text_value(s["rounding"], "settlement.rounding"),
    ),
    minor_units: text_value(s["minor_units"], "settlement.minor_units"),
    amount: text_value(s["amount"], "settlement.amount"),
    delta: text_value(s["delta"], "settlement.delta"),
  }
}

///|
fn small_integer(
  value : Json,
  max : Int32,
  path : String,
) -> Int32 raise PricingError {
  guard value is Number(number, ..) &&
    number >= 0.0 &&
    number <= max.to_double() &&
    number == number.to_int().to_double() else {
    raise Invalid(
      code="integer",
      path~,
      message="expected an integer JSON index or scale within range",
    )
  }
  number.to_int()
}
