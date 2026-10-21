///|
fn budget_request_json(request : BudgetRequest) -> Json {
  {
    "schema": "jieheng.budget-request.v1",
    "customer": request.customer,
    "period": request.period,
    "budget": request.budget,
    "limit": request.limit,
  }
}

///|
pub fn encode_budget_request(
  request : BudgetRequest,
) -> String raise PricingError {
  check_budget(request)
  bounded_json(budget_request_json(request))
}

///|
fn budget_request_from_json(value : Json) -> BudgetRequest raise PricingError {
  let r = fields(
    value,
    ["schema", "customer", "period", "budget", "limit"],
    "budget",
  )
  expect_value(r, "schema", "jieheng.budget-request.v1", "budget")
  let request = {
    customer: text_value(r["customer"], "budget.customer"),
    period: text_value(r["period"], "budget.period"),
    budget: text_value(r["budget"], "budget.budget"),
    limit: text_value(r["limit"], "budget.limit"),
  }
  check_budget(request)
  request
}

///|
pub fn decode_budget_request(text : String) -> BudgetRequest raise PricingError {
  budget_request_from_json(parse_document(text))
}

///|
pub fn encode_budget(quote : BudgetQuote) -> String raise PricingError {
  check_budget(quote.request)
  let json : Json = {
    "schema": "jieheng.budget-quote.v1",
    "request": budget_request_json(quote.request),
    "evidence": evidence_json(quote.evidence),
  }
  bounded_json(json)
}

///|
/// Structural decode only; use verify_budget with a trusted plan and request.
pub fn decode_budget(text : String) -> BudgetQuote raise PricingError {
  let r = fields(
    parse_document(text),
    ["schema", "request", "evidence"],
    "budget",
  )
  expect_value(r, "schema", "jieheng.budget-quote.v1", "budget")
  {
    request: budget_request_from_json(r["request"]),
    evidence: evidence_from_json(r["evidence"]),
  }
}
