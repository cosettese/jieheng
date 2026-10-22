///|
fn tariff_json(tariff : Tariff) -> Json {
  match tariff {
    MeteredTariff(p, minimum, zero) =>
      {
        "kind": "metered",
        "plan": plan_json(p),
        "minimum": minimum,
        "zero_usage": zero_usage_name(zero),
      }
    PackageTariff(p) => { "kind": "package", "plan": package_plan_json(p) }
  }
}

///|
fn tariff_from_json(value : Json, path : String) -> Tariff raise PricingError {
  match item_kind(value, path) {
    "metered" => {
      let r = fields(value, ["kind", "plan", "minimum", "zero_usage"], path)
      MeteredTariff(
        plan_from_json(r["plan"]),
        text_value(r["minimum"], path + ".minimum"),
        zero_usage_from_name(text_value(r["zero_usage"], path + ".zero_usage")),
      )
    }
    "package" => {
      let r = fields(value, ["kind", "plan"], path)
      PackageTariff(package_plan_from_json(r["plan"]))
    }
    _ => {
      invalid("kind", path, "only metered and package tariffs are supported")
      abort("unreachable")
    }
  }
}

///|
pub fn encode_catalog(catalog : Catalog) -> String raise PricingError {
  let entries : Array[Json] = catalog.entries.map(d => {
    "starts_on": d.entry.starts_on,
    "ends_before": match d.entry.ends_before {
      Some(s) => Json::string(s)
      None => Json::null()
    },
    "tariff": tariff_json(d.entry.tariff),
  })
  let json : Json = { "schema": "jieheng.catalog.v1", "entries": entries }
  bounded_json(json)
}

///|
pub fn decode_catalog(text : String) -> Catalog raise PricingError {
  let r = fields(parse_document(text), ["schema", "entries"], "catalog")
  expect_value(r, "schema", "jieheng.catalog.v1", "catalog")
  let entries : Array[CatalogEntry] = []
  for i, value in bounded_items(r["entries"], 512, "catalog.entries") {
    let path = "catalog.entries[\{i}]"
    let e = fields(value, ["starts_on", "ends_before", "tariff"], path)
    entries.push({
      starts_on: text_value(e["starts_on"], path + ".starts_on"),
      ends_before: match e["ends_before"] {
        Null => None
        v => Some(text_value(v, path + ".ends_before"))
      },
      tariff: tariff_from_json(e["tariff"], path + ".tariff"),
    })
  }
  compile_catalog(entries[:])
}

///|
pub fn encode_usage_bundle(
  usages : ArrayView[Usage],
) -> String raise PricingError {
  check_usage_bundle(usages)
  let json : Json = {
    "schema": "jieheng.usage-bundle.v1",
    "usages": usages.map(usage_json),
  }
  bounded_json(json)
}

///|
pub fn decode_usage_bundle(text : String) -> Array[Usage] raise PricingError {
  let r = fields(parse_document(text), ["schema", "usages"], "usages")
  expect_value(r, "schema", "jieheng.usage-bundle.v1", "usages")
  let usages = bounded_items(r["usages"], 64, "usages").map(usage_from_json)
  check_usage_bundle(usages[:])
  usages
}

///|
pub fn encode_catalog_bill(record : CatalogBill) -> String raise PricingError {
  ignore(date_key(record.on, "catalog.on"))
  let json : Json = {
    "schema": "jieheng.catalog-bill.v1",
    "on": record.on,
    "bill": bill_json(record.bill),
  }
  bounded_json(json)
}

///|
pub fn decode_catalog_bill(text : String) -> CatalogBill raise PricingError {
  let r = fields(parse_document(text), ["schema", "on", "bill"], "catalog")
  expect_value(r, "schema", "jieheng.catalog-bill.v1", "catalog")
  let on = text_value(r["on"], "catalog.on")
  ignore(date_key(on, "catalog.on"))
  { on, bill: bill_from_json(r["bill"]), }
}
