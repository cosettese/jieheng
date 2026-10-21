///|
pub fn encode_package_plan(plan : PackagePlan) -> String {
  let json : Json = {
    "schema": "jieheng.package-plan.v1",
    "id": plan.id,
    "version": plan.version,
    "metric": plan.metric,
    "unit": plan.unit,
    "currency": plan.currency,
    "package_size": plan.size.to_string(),
    "package_price": format_atoms(plan.price),
  }
  json.stringify()
}

///|
pub fn decode_package_plan(text : String) -> PackagePlan raise PricingError {
  let r = fields(
    parse_document(text),
    [
      "schema", "id", "version", "metric", "unit", "currency", "package_size", "package_price",
    ],
    "package",
  )
  expect_value(r, "schema", "jieheng.package-plan.v1", "package")
  compile_package(
    id=text_value(r["id"], "package.id"),
    version=text_value(r["version"], "package.version"),
    metric=text_value(r["metric"], "package.metric"),
    unit=text_value(r["unit"], "package.unit"),
    currency=text_value(r["currency"], "package.currency"),
    package_size=text_value(r["package_size"], "package.package_size"),
    package_price=text_value(r["package_price"], "package.package_price"),
  )
}

///|
pub fn encode_packages(record : PackageEvidence) -> String raise PricingError {
  let json : Json = {
    "schema": "jieheng.package-evidence.v1",
    "plan_id": record.plan_id,
    "plan_version": record.plan_version,
    "currency": record.currency,
    "unit": record.unit,
    "usage": usage_json(record.usage),
    "package_size": record.package_size,
    "package_price": record.package_price,
    "packages": record.packages,
    "unused_units": record.unused_units,
    "total": record.total,
    "settlement": settlement_json(record.settlement),
  }
  bounded_json(json)
}

///|
/// Strict structural decoder; accept only after verify_packages with trusted inputs.
pub fn decode_packages(text : String) -> PackageEvidence raise PricingError {
  let r = fields(
    parse_document(text),
    [
      "schema", "plan_id", "plan_version", "currency", "unit", "usage", "package_size",
      "package_price", "packages", "unused_units", "total", "settlement",
    ],
    "packages",
  )
  expect_value(r, "schema", "jieheng.package-evidence.v1", "packages")
  {
    plan_id: text_value(r["plan_id"], "packages.plan_id"),
    plan_version: text_value(r["plan_version"], "packages.plan_version"),
    currency: text_value(r["currency"], "packages.currency"),
    unit: text_value(r["unit"], "packages.unit"),
    usage: usage_from_json(r["usage"]),
    package_size: text_value(r["package_size"], "packages.package_size"),
    package_price: text_value(r["package_price"], "packages.package_price"),
    packages: text_value(r["packages"], "packages.packages"),
    unused_units: text_value(r["unused_units"], "packages.unused_units"),
    total: text_value(r["total"], "packages.total"),
    settlement: settlement_from_json(r["settlement"]),
  }
}
