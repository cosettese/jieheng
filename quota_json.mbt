///|
pub fn encode_quota(quote : QuotaQuote) -> String raise PricingError {
  check_budget(quote.request)
  let witness = match quote.first_unaffordable {
    Some(e) => evidence_json(e)
    None => Json::null()
  }
  let json : Json = {
    "schema": "jieheng.quota-quote.v1",
    "request": budget_request_json(quote.request),
    "evidence": evidence_json(quote.evidence),
    "first_unaffordable": witness,
  }
  bounded_json(json)
}

///|
/// Structural decode; verify_quota requires a trusted plan, request and policy.
pub fn decode_quota(text : String) -> QuotaQuote raise PricingError {
  let r = fields(
    parse_document(text),
    ["schema", "request", "evidence", "first_unaffordable"],
    "quota",
  )
  expect_value(r, "schema", "jieheng.quota-quote.v1", "quota")
  {
    request: budget_request_from_json(r["request"]),
    evidence: evidence_from_json(r["evidence"]),
    first_unaffordable: match r["first_unaffordable"] {
      Null => None
      value => Some(evidence_from_json(value))
    },
  }
}
