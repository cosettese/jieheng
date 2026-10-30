///|
fn plan(
  tier_count : Int32,
  metric : String,
) -> @jieheng.Plan raise @jieheng.PricingError {
  @jieheng.compile_plan(
    id=metric,
    version="v1",
    metric~,
    unit="unit",
    currency="USD",
    tiers=Array::makei(tier_count, i => @jieheng.Tier::{
        up_to: if i + 1 == tier_count {
          None
        } else {
          Some((i + 1).to_string())
        },
        unit_price: "0.001",
      })[:],
  )
}

///|
fn usage(metric : String, quantity : Int32) -> @jieheng.Usage {
  {
    customer: "benchmark",
    period: "synthetic-period",
    metric,
    quantity: quantity.to_string(),
  }
}

///|
fn catalog() -> @jieheng.Catalog raise @jieheng.PricingError {
  let entries : Array[@jieheng.CatalogEntry] = []
  for m in 0..<4 {
    for v in 0..<128 {
      let metric = "metric-\{m}"
      let p = @jieheng.compile_plan(
        id=metric,
        version="v\{v}",
        metric~,
        unit="unit",
        currency="USD",
        tiers=[{ up_to: None, unit_price: "0.001", }],
      )
      entries.push({
        starts_on: "\{2020+v}-01-01",
        ends_before: if v == 127 {
          None
        } else {
          Some("\{2021+v}-01-01")
        },
        tariff: MeteredTariff(p, "0", Waive),
      })
    }
  }
  @jieheng.compile_catalog(entries[:])
}

///|
#cfg(target="js")
fn arguments() -> Array[String] {
  let raw = @env.args()
  if raw.is_empty() {
    []
  } else {
    raw[1:].to_owned()
  }
}

///|
#cfg(not(target="js"))
fn arguments() -> Array[String] {
  @env.args()
}

///|
fn main {
  run() catch {
    e => {
      println("benchmark error: \{e}")
      abort("benchmark failed")
    }
  }
}

///|
fn run() -> Unit raise {
  let args = arguments()
  if args.length() != 1 && (args.length() != 2 || args[1] != "--smoke") {
    fail("usage: moon run cmd/benchmark --release [-- --smoke]")
  }
  let count = if args.length() == 2 { 1U } else { 5U }
  let bench = @bench.Bench()
  let dimensions : Array[Json] = []
  for tiers in [1, 64, 1024] {
    let p = plan(tiers, "calls")
    let u = usage("calls", tiers)
    let rated = @jieheng.rate(p, u)
    let expected = if tiers == 64 { "0.064" } else { "1.024" }
    if tiers == 1 {
      assert_eq(rated.total, "0.001")
    } else {
      assert_eq(rated.total, expected)
    }
    @jieheng.verify_calculation(p, u, rated)
    bench.bench(
      name="rate-\{tiers}",
      () => bench.keep(try! @jieheng.rate(p, u)),
      count~,
    )
    dimensions.push({
      "id": "rate-\{tiers}",
      "tiers": tiers,
      "quantity": tiers,
      "occupied_lines": tiers,
      "operation": "rate",
    })
  }
  let large = plan(1024, "calls")
  let large_usage = usage("calls", 1024)
  let calculation = @jieheng.rate(large, large_usage)
  let evidence : @jieheng.Evidence = {
    calculation,
    settlement: @jieheng.settle(calculation, scale=2, rounding=HalfEven),
  }
  @jieheng.verify_evidence(
    large,
    large_usage,
    evidence,
    scale=2,
    rounding=HalfEven,
  )
  bench.bench(
    name="verify-1024",
    () => {
      try! @jieheng.verify_evidence(
        large,
        large_usage,
        evidence,
        scale=2,
        rounding=HalfEven,
      )
      bench.keep(evidence.settlement)
    },
    count~,
  )
  dimensions.push({
    "id": "verify-1024",
    "tiers": 1024,
    "occupied_lines": 1024,
    "operation": "verify_evidence",
  })
  let items : Array[@jieheng.BillItem] = []
  for i in 0..<64 {
    let metric = "metric-\{i}"
    let u = usage(metric, 6)
    if i % 2 == 0 {
      items.push(
        Metered({
          plan: plan(1, metric),
          usage: u,
          minimum: "0.005",
          zero_usage: Charge,
        }),
      )
    } else {
      items.push(
        Packaged(
          @jieheng.compile_package(
            id=metric,
            version="v1",
            metric~,
            unit="unit",
            currency="USD",
            package_size="5",
            package_price="0.006",
          ),
          u,
        ),
      )
    }
  }
  let bill = @jieheng.rate_bill(items[:], scale=2, rounding=HalfEven)
  assert_eq(bill.totals.total, "0.576")
  assert_eq(bill.totals.amount, "0.64")
  @jieheng.verify_bill(items[:], bill, scale=2, rounding=HalfEven)
  bench.bench(
    name="bill-64",
    () => {
      bench.keep(try! @jieheng.rate_bill(items[:], scale=2, rounding=HalfEven))
    },
    count~,
  )
  dimensions.push({
    "id": "bill-64",
    "items": 64,
    "metered": 32,
    "packaged": 32,
    "operation": "rate_bill",
  })
  bench.bench(
    name="verify-bill-64",
    () => {
      try! @jieheng.verify_bill(items[:], bill, scale=2, rounding=HalfEven)
      bench.keep(bill.totals)
    },
    count~,
  )
  dimensions.push({
    "id": "verify-bill-64",
    "items": 64,
    "operation": "verify_bill",
  })
  let c = catalog()
  let usages = Array::makei(4, i => usage("metric-\{i}", 1))
  let dated = @jieheng.rate_catalog(
    c,
    "2127-06-30",
    usages[:],
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(dated.bill.totals.usage_total, "0.004")
  @jieheng.verify_catalog(
    c,
    "2127-06-30",
    usages[:],
    dated,
    scale=2,
    rounding=HalfEven,
  )
  bench.bench(
    name="catalog-rate-512",
    () => {
      bench.keep(
        try! @jieheng.rate_catalog(
          c,
          "2127-06-30",
          usages[:],
          scale=2,
          rounding=HalfEven,
        ),
      )
    },
    count~,
  )
  dimensions.push({
    "id": "catalog-rate-512",
    "entries": 512,
    "metrics": 4,
    "versions_per_metric": 128,
    "operation": "rate_catalog",
  })
  let migration = @jieheng.audit_catalog_migration(
    c, c, "2020-01-01", "2148-01-01",
  )
  assert_eq(migration.spans.length(), 512)
  @jieheng.verify_catalog_migration(
    c,
    c,
    migration.starts_on,
    migration.ends_before,
    migration,
  )
  bench.bench(
    name="migration-512",
    () => {
      bench.keep(
        try! @jieheng.audit_catalog_migration(c, c, "2020-01-01", "2148-01-01"),
      )
    },
    count~,
  )
  dimensions.push({
    "id": "migration-512",
    "entries_per_catalog": 512,
    "spans": 512,
    "operation": "audit_catalog_migration",
  })
  bench.bench(
    name="verify-migration-512",
    () => {
      try! @jieheng.verify_catalog_migration(
        c,
        c,
        migration.starts_on,
        migration.ends_before,
        migration,
      )
      bench.keep(migration.spans.length())
    },
    count~,
  )
  dimensions.push({
    "id": "verify-migration-512",
    "entries_per_catalog": 512,
    "spans": 512,
    "operation": "verify_catalog_migration",
  })
  let result : Json = {
    "schema": "jieheng.benchmark-workload.v1",
    "time_unit": "microseconds_per_operation",
    "samples_per_workload": count.to_string(),
    "fixtures": "synthetic-v1",
    "dimensions": dimensions,
    "summaries": @json.parse(bench.dump_summaries()),
  }
  println(result.stringify())
}
