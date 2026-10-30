///|
pub fn encode_replay_cases(
  cases : ArrayView[CatalogReplayCase],
) -> String raise PricingError {
  check_replay_cases(cases)
  let values : Array[Json] = cases.map(c => {
    "on": c.on,
    "usages": c.usages.map(usage_json),
  })
  bounded_json({ "schema": "jieheng.replay-cases.v1", "cases": values })
}

///|
pub fn decode_replay_cases(
  text : String,
) -> Array[CatalogReplayCase] raise PricingError {
  let r = fields(parse_document(text), ["schema", "cases"], "replay")
  expect_value(r, "schema", "jieheng.replay-cases.v1", "replay")
  let cases = bounded_items(r["cases"], 256, "replay.cases").mapi((i, v) => {
    let path = "replay.cases[\{i}]"
    let c = fields(v, ["on", "usages"], path)
    {
      on: text_value(c["on"], path + ".on"),
      usages: bounded_items(c["usages"], 64, path + ".usages").map(
        usage_from_json,
      ),
    }
  })
  check_replay_cases(cases[:])
  cases
}

///|
pub fn encode_replay_policy(policy : ReplayPolicy) -> String raise PricingError {
  validate_replay_policy(policy)
  let percent = match policy.max_increase_percent {
    Some(s) => Json::string(s)
    None => Json::null()
  }
  bounded_json({
    "schema": "jieheng.replay-policy.v1",
    "currency": policy.currency,
    "max_increase": policy.max_increase,
    "max_increase_percent": percent,
  })
}

///|
pub fn decode_replay_policy(text : String) -> ReplayPolicy raise PricingError {
  let r = fields(
    parse_document(text),
    ["schema", "currency", "max_increase", "max_increase_percent"],
    "replay.policy",
  )
  expect_value(r, "schema", "jieheng.replay-policy.v1", "replay.policy")
  let policy = {
    currency: text_value(r["currency"], "replay.policy.currency"),
    max_increase: text_value(r["max_increase"], "replay.policy.max_increase"),
    max_increase_percent: match r["max_increase_percent"] {
      Null => None
      v => Some(text_value(v, "replay.policy.max_increase_percent"))
    },
  }
  validate_replay_policy(policy)
  policy
}

///|
pub fn encode_catalog_replay(
  report : CatalogReplay,
) -> String raise PricingError {
  if report.rows.length() == 0 || report.rows.length() > 256 {
    invalid("size", "replay.rows", "expected 1 to 256 rows")
  }
  for n in [report.increased, report.decreased, report.unchanged] {
    if n < 0 || n > 256 {
      invalid("count", "replay.counts", "counts must be 0..256")
    }
  }
  if report.max_increase_index is Some(i) && (i < 0 || i > 255) {
    invalid(
      "index", "replay.max_increase_index", "index must be 0..255 or null",
    )
  }
  let rows : Array[Json] = report.rows.map(r => {
    "on": r.on,
    "comparison": bill_comparison_json(r.comparison),
  })
  let index = match report.max_increase_index {
    Some(i) => Json(i)
    None => Json::null()
  }
  bounded_json({
    "schema": "jieheng.catalog-replay.v1",
    "currency": report.currency,
    "rows": rows,
    "baseline_exact": report.baseline_exact,
    "candidate_exact": report.candidate_exact,
    "baseline_settled": report.baseline_settled,
    "candidate_settled": report.candidate_settled,
    "exact_delta": report.exact_delta,
    "settled_delta": report.settled_delta,
    "increased": report.increased,
    "decreased": report.decreased,
    "unchanged": report.unchanged,
    "max_increase": report.max_increase,
    "max_increase_index": index,
  })
}

///|
/// Strict structural decoding; verify_catalog_replay still needs both catalogs,
/// complete dated cases and the settlement policy from a trusted source.
pub fn decode_catalog_replay(text : String) -> CatalogReplay raise PricingError {
  let r = fields(
    parse_document(text),
    [
      "schema", "currency", "rows", "baseline_exact", "candidate_exact", "baseline_settled",
      "candidate_settled", "exact_delta", "settled_delta", "increased", "decreased",
      "unchanged", "max_increase", "max_increase_index",
    ],
    "replay",
  )
  expect_value(r, "schema", "jieheng.catalog-replay.v1", "replay")
  let rows : Array[CatalogReplayRow] = bounded_items(
    r["rows"],
    256,
    "replay.rows",
  ).mapi((i, v) => {
    let path = "replay.rows[\{i}]"
    let row = fields(v, ["on", "comparison"], path)
    {
      on: text_value(row["on"], path + ".on"),
      comparison: bill_comparison_from_json(row["comparison"]),
    }
  })
  {
    currency: text_value(r["currency"], "replay.currency"),
    rows,
    baseline_exact: text_value(r["baseline_exact"], "replay.baseline_exact"),
    candidate_exact: text_value(r["candidate_exact"], "replay.candidate_exact"),
    baseline_settled: text_value(
      r["baseline_settled"],
      "replay.baseline_settled",
    ),
    candidate_settled: text_value(
      r["candidate_settled"],
      "replay.candidate_settled",
    ),
    exact_delta: text_value(r["exact_delta"], "replay.exact_delta"),
    settled_delta: text_value(r["settled_delta"], "replay.settled_delta"),
    increased: small_integer(r["increased"], 256, "replay.increased"),
    decreased: small_integer(r["decreased"], 256, "replay.decreased"),
    unchanged: small_integer(r["unchanged"], 256, "replay.unchanged"),
    max_increase: text_value(r["max_increase"], "replay.max_increase"),
    max_increase_index: match r["max_increase_index"] {
      Null => None
      v => Some(small_integer(v, 255, "replay.max_increase_index"))
    },
  }
}
