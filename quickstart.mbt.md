# Choose one complete workflow

These examples are compiled and executed as black-box tests. Prices, customers and limits here are synthetic.

## One aggregated metric, explicit settlement and archived verification

~~~mbt check
///|
test "quickstart: price and verify one metric" {
  let plan = @jieheng.compile_plan(
    id="api",
    version="v1",
    metric="requests",
    unit="request",
    currency="USD",
    tiers=[
      { up_to: Some("1000"), unit_price: "0", },
      { up_to: None, unit_price: "0.001", },
    ],
  )
  let usage : @jieheng.Usage = {
    customer: "acme",
    metric: "requests",
    period: "October",
    quantity: "1501",
  }
  let calculation = @jieheng.rate(plan, usage)
  let settlement = @jieheng.settle(calculation, scale=2, rounding=HalfEven)
  let archived = @jieheng.encode_evidence({ calculation, settlement, })
  let restored = @jieheng.decode_evidence(archived)
  @jieheng.verify_evidence(plan, usage, restored, scale=2, rounding=HalfEven)
  assert_eq(restored.calculation.total, "0.501")
  assert_eq(restored.settlement.amount, "0.50")
}
~~~

## Safe contract change and per-customer release policy

~~~mbt check
///|
test "quickstart: audit then replay a catalog change" {
  let old = @jieheng.compile_package(
    id="sms",
    version="v1",
    metric="messages",
    unit="message",
    currency="USD",
    package_size="1000",
    package_price="0.85",
  )
  let next = @jieheng.compile_package(
    id="sms",
    version="v2",
    metric="messages",
    unit="message",
    currency="USD",
    package_size="1000",
    package_price="0.90",
  )
  let before = @jieheng.compile_catalog([
    { starts_on: "2026-10-01", ends_before: None, tariff: PackageTariff(old), },
  ])
  let after = @jieheng.compile_catalog([
    { starts_on: "2026-10-01", ends_before: None, tariff: PackageTariff(next), },
  ])
  let migration = @jieheng.audit_catalog_migration(
    before, after, "2026-10-01", "2026-11-01",
  )
  @jieheng.verify_catalog_migration(
    before, after, "2026-10-01", "2026-11-01", migration,
  )
  assert_true(migration.spans[0].changes.contains(@jieheng.PricingChanged))
  let cases : Array[@jieheng.CatalogReplayCase] = [
    {
      on: "2026-10-22",
      usages: [
        {
          customer: "acme",
          metric: "messages",
          period: "October",
          quantity: "2501",
        },
      ],
    },
  ]
  let report = @jieheng.replay_catalogs(
    before,
    after,
    cases[:],
    scale=2,
    rounding=HalfEven,
  )
  @jieheng.check_replay_policy(
    before,
    after,
    cases[:],
    report,
    { currency: "USD", max_increase: "0.15", max_increase_percent: Some("6"), },
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(report.settled_delta, "0.15")
}
~~~

Structural compatibility only enables replay; it does not approve changed prices. Retain both trusted catalogs, the complete dated usages and settlement policy when verifying a report.

Source-workspace setup is described in the [consumer example](https://github.com/cosettese/jieheng/tree/main/integration/consumer). Registry installation is only available after the exact version is actually published; see [distribution verification](docs/distribution.md).
