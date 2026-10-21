///|
pub fn encode_schedule(schedule : Schedule) -> String raise PricingError {
  let entries : Array[Json] = schedule.periods.map(period => {
    "starts_on": period.entry.starts_on,
    "ends_before": match period.entry.ends_before {
      Some(s) => Json::string(s)
      None => Json::null()
    },
    "plan": plan_json(period.entry.plan),
  })
  let json : Json = { "schema": "jieheng.schedule.v1", "entries": entries }
  bounded_json(json)
}

///|
pub fn decode_schedule(text : String) -> Schedule raise PricingError {
  let root = fields(parse_document(text), ["schema", "entries"], "schedule")
  expect_value(root, "schema", "jieheng.schedule.v1", "schedule")
  let values = bounded_items(root["entries"], 128, "schedule.entries")
  let entries : Array[EffectivePlan] = []
  for i, value in values {
    let path = "schedule.entries[\{i}]"
    let item = fields(value, ["starts_on", "ends_before", "plan"], path)
    entries.push({
      starts_on: text_value(item["starts_on"], path + ".starts_on"),
      ends_before: match item["ends_before"] {
        Null => None
        other => Some(text_value(other, path + ".ends_before"))
      },
      plan: plan_from_json(item["plan"]),
    })
  }
  compile_schedule(entries[:])
}

///|
pub fn encode_scheduled(
  record : ScheduledEvidence,
) -> String raise PricingError {
  ignore(date_key(record.on, "scheduled.on"))
  let json : Json = {
    "schema": "jieheng.scheduled-evidence.v1",
    "on": record.on,
    "evidence": evidence_json(record.evidence),
  }
  bounded_json(json)
}

///|
/// Strict structural decode; use verify_scheduled with trusted date and schedule.
pub fn decode_scheduled(text : String) -> ScheduledEvidence raise PricingError {
  let root = fields(
    parse_document(text),
    ["schema", "on", "evidence"],
    "scheduled",
  )
  expect_value(root, "schema", "jieheng.scheduled-evidence.v1", "scheduled")
  let on = text_value(root["on"], "scheduled.on")
  ignore(date_key(on, "scheduled.on"))
  { on, evidence: evidence_from_json(root["evidence"]), }
}
