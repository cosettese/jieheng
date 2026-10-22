///|
fn catalog_entries() -> Array[@jieheng.CatalogEntry] raise @jieheng.PricingError {
  let p = priced("0.004")
  let old = @jieheng.compile_package(
    id="messages",
    version="v1",
    metric="messages",
    unit="message",
    currency="USD",
    package_size="5",
    package_price="0.006",
  )
  let new = @jieheng.compile_package(
    id="messages",
    version="v2",
    metric="messages",
    unit="message",
    currency="USD",
    package_size="5",
    package_price="0.010",
  )
  [
    {
      starts_on: "2026-10-01",
      ends_before: None,
      tariff: MeteredTariff(p, "0.005", Charge),
    },
    {
      starts_on: "2026-10-01",
      ends_before: Some("2026-11-01"),
      tariff: PackageTariff(old),
    },
    { starts_on: "2026-11-01", ends_before: None, tariff: PackageTariff(new), },
  ]
}

///|
test "catalog selects package versions and retains minimum policy and exact usage" {
  let entries = catalog_entries()
  let c = @jieheng.compile_catalog(entries[:])
  let usages = [usage("1"), { ..usage("6"), metric: "messages", }]
  let old = @jieheng.rate_catalog(
    c,
    "2026-10-31",
    usages[:],
    scale=2,
    rounding=HalfEven,
  )
  let new = @jieheng.rate_catalog(
    c,
    "2026-11-01",
    usages[:],
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(old.bill.totals.amount, "0.01")
  assert_eq(new.bill.totals.amount, "0.02")
  assert_eq(old.bill.totals.top_up, "0.001")
  assert_eq(
    @jieheng.rate_catalog(
      c,
      "2026-10-31",
      [usages[1], usages[0]],
      scale=2,
      rounding=HalfEven,
    ),
    old,
  )
  @jieheng.verify_catalog(
    c,
    "2026-10-31",
    usages[:],
    old,
    scale=2,
    rounding=HalfEven,
  )
  rejected(() => {
    @jieheng.verify_catalog(
      c,
      "2026-11-01",
      usages[:],
      old,
      scale=2,
      rounding=HalfEven,
    )
  })
  rejected(() => {
    @jieheng.verify_catalog(
      c,
      "2026-11-01",
      usages[:],
      { ..old, on: "2026-11-01", },
      scale=2,
      rounding=HalfEven,
    )
  })
  let text = @jieheng.encode_catalog(c)
  entries[0] = entries[1]
  assert_eq(@jieheng.encode_catalog(c), text)
  assert_eq(@jieheng.encode_catalog(@jieheng.decode_catalog(text)), text)
  assert_eq(
    @jieheng.decode_catalog_bill(@jieheng.encode_catalog_bill(old)),
    old,
  )
  assert_eq(
    @jieheng.decode_usage_bundle(@jieheng.encode_usage_bundle(usages[:])),
    usages,
  )
}

///|
test "catalog refuses missing unknown duplicated or mixed-customer snapshots" {
  let c = @jieheng.compile_catalog(catalog_entries()[:])
  let usages = [usage("1"), { ..usage("6"), metric: "messages", }]
  for
    bad in [
      [],
      [usages[0]],
      [usages[0], usages[0]],
      [usages[0], { ..usages[1], metric: "unknown", }],
      [usages[0], { ..usages[1], customer: "other", }],
      [usages[0], { ..usages[1], period: "other", }],
    ] {
    rejected(() => {
      ignore(
        @jieheng.rate_catalog(
          c,
          "2026-10-22",
          bad[:],
          scale=2,
          rounding=HalfEven,
        ),
      )
    })
  }
  rejected(() => {
    ignore(
      @jieheng.rate_catalog(
        c,
        "2026-09-30",
        usages[:],
        scale=2,
        rounding=HalfEven,
      ),
    )
  })
  let zero = [usage("0"), { ..usage("0"), metric: "messages", }]
  let bill = @jieheng.rate_catalog(
    c,
    "2026-10-22",
    zero[:],
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(bill.bill.totals.total, "0.005")
}

///|
test "catalog validates per-metric intervals versions identities and resource bounds" {
  let e = catalog_entries()
  for
    bad in [
      [],
      [e[0], e[1], { ..e[2], starts_on: "2026-10-31", }],
      [e[0], e[2], e[1]],
      [e[0], { ..e[1], ends_before: None, }, e[2]],
      [{ ..e[0], starts_on: "2026-02-29", }],
      [e[0], { ..e[0], starts_on: "2027-01-01", }],
      [{ ..e[0], tariff: MeteredTariff(priced("1"), "-1", Charge), }],
    ] {
    rejected(() => ignore(@jieheng.compile_catalog(bad[:])))
  }
  let all : Array[@jieheng.CatalogEntry] = []
  for m in 0..<4 {
    for y in 1..<=128 {
      let year = y.to_string()
      let next = (y + 1).to_string()
      let p = @jieheng.compile_package(
        id="metric-\{m}",
        version=year,
        metric="metric-\{m}",
        unit="unit",
        currency="USD",
        package_size="1",
        package_price="0",
      )
      all.push({
        starts_on: "0".repeat(4 - year.length()) + year + "-01-01",
        ends_before: Some("0".repeat(4 - next.length()) + next + "-01-01"),
        tariff: PackageTariff(p),
      })
    }
  }
  ignore(@jieheng.compile_catalog(all[:]))
  rejected(() => ignore(@jieheng.compile_catalog((all + [e[0]])[:])))
  let one = all[:128].to_owned()
  let p = @jieheng.compile_package(
    id="metric-0",
    version="129",
    metric="metric-0",
    unit="unit",
    currency="USD",
    package_size="1",
    package_price="0",
  )
  one.push({
    starts_on: "0129-01-01",
    ends_before: None,
    tariff: PackageTariff(p),
  })
  rejected(() => ignore(@jieheng.compile_catalog(one[:])))
}

///|
test "catalog nested transport rejects unknown policies and recovers" {
  let c = @jieheng.compile_catalog(catalog_entries()[:])
  let text = @jieheng.encode_catalog(c)
  for
    bad in [
      "{}",
      "null",
      text.replace(old="jieheng.catalog.v1", new="jieheng.catalog.v2"),
      text.replace(
        old="\"kind\":\"package\"",
        new="\"kind\":\"package\",\"minimum\":\"1\"",
      ),
      text.replace(old="\"kind\":\"package\"", new="\"kind\":\"unknown\""),
      text.replace(
        old="\"starts_on\":\"2026-10-01\"",
        new="\"starts_on\":\"2026-10-01\",\"starts_on\":\"2026-10-02\"",
      ),
    ] {
    rejected(() => ignore(@jieheng.decode_catalog(bad)))
  }
  assert_eq(@jieheng.encode_catalog(@jieheng.decode_catalog(text)), text)
}
