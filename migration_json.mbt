///|
fn catalog_change_name(change : CatalogChange) -> String {
  match change {
    MetricAdded => "metric-added"
    MetricRemoved => "metric-removed"
    BaselineGap => "baseline-gap"
    CandidateGap => "candidate-gap"
    CurrencyChanged => "currency-changed"
    UnitChanged => "unit-changed"
    IdentityChanged => "identity-changed"
    VersionChanged => "version-changed"
    ModelChanged => "model-changed"
    PricingChanged => "pricing-changed"
    MinimumChanged => "minimum-changed"
    ZeroPolicyChanged => "zero-policy-changed"
  }
}

///|
fn catalog_change_from_name(name : String) -> CatalogChange raise PricingError {
  match name {
    "metric-added" => MetricAdded
    "metric-removed" => MetricRemoved
    "baseline-gap" => BaselineGap
    "candidate-gap" => CandidateGap
    "currency-changed" => CurrencyChanged
    "unit-changed" => UnitChanged
    "identity-changed" => IdentityChanged
    "version-changed" => VersionChanged
    "model-changed" => ModelChanged
    "pricing-changed" => PricingChanged
    "minimum-changed" => MinimumChanged
    "zero-policy-changed" => ZeroPolicyChanged
    _ => {
      invalid(
        "unsupported", "migration.changes", "unknown migration change code",
      )
      abort("unreachable")
    }
  }
}

///|
fn migration_index_json(index : Int32?) -> Json {
  match index {
    Some(i) => Json(i)
    None => Json::null()
  }
}

///|
pub fn encode_catalog_migration(
  report : CatalogMigration,
) -> String raise PricingError {
  migration_window(report.starts_on, report.ends_before)
  if report.spans.length() == 0 || report.spans.length() > 4096 {
    invalid("size", "migration.spans", "expected 1 to 4096 spans")
  }
  let spans : Array[Json] = []
  for s in report.spans {
    for index in [s.baseline_entry, s.candidate_entry] {
      if index is Some(i) && (i < 0 || i > 511) {
        invalid(
          "index", "migration.spans", "entry indices must be 0..511 or null",
        )
      }
    }
    let changes : Array[Json] = s.changes.map(c => {
      Json::string(catalog_change_name(c))
    })
    if changes.length() > 12 {
      invalid("size", "migration.changes", "maximum 12 change codes")
    }
    spans.push({
      "metric": s.metric,
      "starts_on": s.starts_on,
      "ends_before": s.ends_before,
      "baseline_entry": migration_index_json(s.baseline_entry),
      "candidate_entry": migration_index_json(s.candidate_entry),
      "changes": changes,
    })
  }
  bounded_json({
    "schema": "jieheng.catalog-migration.v1",
    "starts_on": report.starts_on,
    "ends_before": report.ends_before,
    "spans": spans,
  })
}

///|
/// Structural decoding only; trusted catalogs are required for verification.
pub fn decode_catalog_migration(
  text : String,
) -> CatalogMigration raise PricingError {
  let r = fields(
    parse_document(text),
    ["schema", "starts_on", "ends_before", "spans"],
    "migration",
  )
  expect_value(r, "schema", "jieheng.catalog-migration.v1", "migration")
  let start = text_value(r["starts_on"], "migration.starts_on")
  let end = text_value(r["ends_before"], "migration.ends_before")
  migration_window(start, end)
  let spans : Array[MigrationSpan] = []
  for i, v in bounded_items(r["spans"], 4096, "migration.spans") {
    let path = "migration.spans[\{i}]"
    let s = fields(
      v,
      [
        "metric", "starts_on", "ends_before", "baseline_entry", "candidate_entry",
        "changes",
      ],
      path,
    )
    let index = (v : Json) => {
      match v {
        Null => None
        _ => Some(small_integer(v, 511, path + ".entry"))
      }
    }
    guard s["changes"] is Array(changes) else {
      invalid("type", path + ".changes", "expected an array")
      abort("unreachable")
    }
    if changes.length() > 12 {
      invalid("size", path + ".changes", "maximum 12 change codes")
    }
    spans.push({
      metric: text_value(s["metric"], path + ".metric"),
      starts_on: text_value(s["starts_on"], path + ".starts_on"),
      ends_before: text_value(s["ends_before"], path + ".ends_before"),
      baseline_entry: index(s["baseline_entry"]),
      candidate_entry: index(s["candidate_entry"]),
      changes: changes.map(c => {
        catalog_change_from_name(text_value(c, path + ".changes"))
      }),
    })
  }
  { starts_on: start, ends_before: end, spans, }
}
