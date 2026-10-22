///|
pub fn encode_analysis(report : PriceAnalysis) -> String raise PricingError {
  if report.spans.length() == 0 || report.spans.length() > 2047 {
    invalid("size", "analysis.spans", "expected 1 to 2047 spans")
  }
  let spans : Array[Json] = report.spans.map(s => {
    "from_quantity": s.from_quantity,
    "to_quantity": s.to_quantity,
    "baseline_total": s.baseline_total,
    "candidate_total": s.candidate_total,
    "baseline_step": s.baseline_step,
    "candidate_step": s.candidate_step,
  })
  let json : Json = {
    "schema": "jieheng.price-analysis.v1",
    "baseline": { "id": report.baseline.id, "version": report.baseline.version },
    "candidate": {
      "id": report.candidate.id,
      "version": report.candidate.version,
    },
    "currency": report.currency,
    "metric": report.metric,
    "unit": report.unit,
    "limit": report.limit,
    "spans": spans,
    "minimum_delta": report.minimum_delta,
    "minimum_at": report.minimum_at,
    "maximum_delta": report.maximum_delta,
    "maximum_at": report.maximum_at,
  }
  bounded_json(json)
}

///|
fn plan_ref_from_json(
  value : Json,
  path : String,
) -> PlanRef raise PricingError {
  let r = fields(value, ["id", "version"], path)
  {
    id: text_value(r["id"], path + ".id"),
    version: text_value(r["version"], path + ".version"),
  }
}

///|
/// Structural decode only; verify_analysis proves semantic coverage and values.
pub fn decode_analysis(text : String) -> PriceAnalysis raise PricingError {
  let r = fields(
    parse_document(text),
    [
      "schema", "baseline", "candidate", "currency", "metric", "unit", "limit", "spans",
      "minimum_delta", "minimum_at", "maximum_delta", "maximum_at",
    ],
    "analysis",
  )
  expect_value(r, "schema", "jieheng.price-analysis.v1", "analysis")
  let entries = bounded_items(r["spans"], 2047, "analysis.spans")
  let spans : Array[PriceSpan] = []
  for i, value in entries {
    let path = "analysis.spans[\{i}]"
    let s = fields(
      value,
      [
        "from_quantity", "to_quantity", "baseline_total", "candidate_total", "baseline_step",
        "candidate_step",
      ],
      path,
    )
    spans.push({
      from_quantity: text_value(s["from_quantity"], path + ".from_quantity"),
      to_quantity: text_value(s["to_quantity"], path + ".to_quantity"),
      baseline_total: text_value(s["baseline_total"], path + ".baseline_total"),
      candidate_total: text_value(
        s["candidate_total"],
        path + ".candidate_total",
      ),
      baseline_step: text_value(s["baseline_step"], path + ".baseline_step"),
      candidate_step: text_value(s["candidate_step"], path + ".candidate_step"),
    })
  }
  {
    baseline: plan_ref_from_json(r["baseline"], "analysis.baseline"),
    candidate: plan_ref_from_json(r["candidate"], "analysis.candidate"),
    currency: text_value(r["currency"], "analysis.currency"),
    metric: text_value(r["metric"], "analysis.metric"),
    unit: text_value(r["unit"], "analysis.unit"),
    limit: text_value(r["limit"], "analysis.limit"),
    spans,
    minimum_delta: text_value(r["minimum_delta"], "analysis.minimum_delta"),
    minimum_at: text_value(r["minimum_at"], "analysis.minimum_at"),
    maximum_delta: text_value(r["maximum_delta"], "analysis.maximum_delta"),
    maximum_at: text_value(r["maximum_at"], "analysis.maximum_at"),
  }
}
