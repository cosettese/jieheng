///|
/// Strict versioned JSON plan decoder. Unknown fields and duplicate keys fail.
pub fn decode_plan(text : String) -> Plan raise PricingError {
  let object = fields(
    parse_document(text),
    ["schema", "id", "version", "metric", "unit", "currency", "mode", "tiers"],
    "plan",
  )
  expect_value(object, "schema", "jieheng.plan.v1", "plan")
  let mode = match text_value(object["mode"], "plan.mode") {
    "graduated" => Graduated
    "volume" => Volume
    _ =>
      raise Invalid(
        code="unsupported",
        path="plan.mode",
        message="choose graduated or volume",
      )
  }
  guard object["tiers"] is Array(items) else {
    raise Invalid(code="type", path="plan.tiers", message="expected an array")
  }
  if items.length() > 1024 {
    invalid("tiers", "plan.tiers", "maximum 1024 tiers")
  }
  let tiers = []
  for i, item in items {
    let path = "plan.tiers[\{i}]"
    let tier = fields(item, ["up_to", "unit_price"], path)
    let up_to = match tier["up_to"] {
      Null => None
      value => Some(text_value(value, path + ".up_to"))
    }
    tiers.push({
      up_to,
      unit_price: text_value(tier["unit_price"], path + ".unit_price"),
    })
  }
  compile_plan(
    id=text_value(object["id"], "plan.id"),
    version=text_value(object["version"], "plan.version"),
    metric=text_value(object["metric"], "plan.metric"),
    unit=text_value(object["unit"], "plan.unit"),
    currency=text_value(object["currency"], "plan.currency"),
    tiers~,
    mode~,
  )
}

///|
/// Deterministic schema-order JSON; decimal trailing zeroes are normalized.
pub fn encode_plan(plan : Plan) -> String {
  plan_json(plan).stringify()
}

///|
fn plan_json(plan : Plan) -> Json {
  let tiers : Array[Json] = []
  for tier in plan.tiers {
    let bound : Json = match tier.up_to {
      Some(n) => Json::string(n.to_string())
      None => Json::null()
    }
    tiers.push({ "up_to": bound, "unit_price": format_atoms(tier.price) })
  }
  {
    "schema": "jieheng.plan.v1",
    "id": plan.id,
    "version": plan.version,
    "metric": plan.metric,
    "unit": plan.unit,
    "currency": plan.currency,
    "mode": pricing_mode_name(plan.mode),
    "tiers": tiers,
  }
}

///|
fn pricing_mode_name(mode : PricingMode) -> String {
  match mode {
    Graduated => "graduated"
    Volume => "volume"
  }
}
