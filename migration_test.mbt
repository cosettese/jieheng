///|
test "migration partitions both timelines and exposes gaps without losing unchanged spans" {
  let entries = catalog_entries()
  let before = @jieheng.compile_catalog(entries[:])
  let after = @jieheng.compile_catalog([
    { ..entries[0], tariff: MeteredTariff(priced("0.004"), "0.006", Waive), },
    { ..entries[1], ends_before: Some("2026-10-15"), },
    { ..entries[2], starts_on: "2026-10-17", },
  ])
  let r = @jieheng.audit_catalog_migration(
    before, after, "2026-10-01", "2026-11-02",
  )
  assert_eq(r.spans.length(), 5)
  assert_eq(r.spans[0].changes, [@jieheng.MinimumChanged, ZeroPolicyChanged])
  assert_eq(r.spans[2].changes, [@jieheng.CandidateGap])
  assert_eq(r.spans[3].changes, [@jieheng.VersionChanged, PricingChanged])
  assert_eq(r.spans[4].changes, [])
  @jieheng.verify_catalog_migration(
    before,
    after,
    r.starts_on,
    r.ends_before,
    r,
  )
  let json = @jieheng.encode_catalog_migration(r)
  let restored = @jieheng.decode_catalog_migration(json)
  assert_eq(restored, r)
  assert_eq(@jieheng.encode_catalog_migration(restored), json)
  assert_eq(
    @jieheng.audit_catalog_migration(before, after, r.starts_on, r.ends_before),
    r,
  )
  for
    changed in [
      { ..r, spans: [], },
      { ..r, starts_on: "2026-10-02", },
      {
        ..r,
        spans: [{ ..r.spans[0], baseline_entry: Some(511), }, ..r.spans[1:]],
      },
      { ..r, spans: [{ ..r.spans[0], changes: [], }, ..r.spans[1:]], },
      {
        ..r,
        spans: [{ ..r.spans[0], ends_before: "2026-10-02", }, ..r.spans[1:]],
      },
      { ..r, spans: [r.spans[1], r.spans[0], ..r.spans[2:]], },
      { ..r, spans: [..r.spans, r.spans[0]], },
    ] {
    rejected(() => {
      @jieheng.verify_catalog_migration(
        before,
        after,
        r.starts_on,
        r.ends_before,
        changed,
      )
    })
  }
  for
    bad in [
      json.replace(old="candidate-gap", new="unrecognized"),
      json.replace(old="\"baseline_entry\":0", new="\"baseline_entry\":512"),
      json.replace(old="\"schema\":", new="\"extension\":true,\"schema\":"),
      json.replace(
        old="\"schema\":",
        new="\"schema\":\"duplicate\",\"schema\":",
      ),
    ] {
    rejected(() => ignore(@jieheng.decode_catalog_migration(bad)))
  }
  @jieheng.verify_catalog_migration(
    before,
    after,
    r.starts_on,
    r.ends_before,
    r,
  )
}

///|
test "migration treats semantic prices separately from labels and blocks mapping changes" {
  let p = priced("1")
  let one = (tariff : @jieheng.Tariff) => {
    @jieheng.compile_catalog([
      { starts_on: "0001-01-01", ends_before: None, tariff, },
    ])
  }
  let b = one(MeteredTariff(p, "0", Charge))
  let equivalent = one(MeteredTariff(priced("1.000"), "0.000", Charge))
  assert_eq(
    @jieheng.audit_catalog_migration(b, equivalent, "0001-01-01", "9999-12-31").spans[0].changes,
    [],
  )
  let altered = @jieheng.compile_plan(
    id="other",
    version="v2",
    metric="calls",
    unit="thousand-calls",
    currency="EUR",
    mode=Volume,
    tiers=[{ up_to: None, unit_price: "2", }],
  )
  let a = one(MeteredTariff(altered, "3", Waive))
  let r = @jieheng.audit_catalog_migration(b, a, "2026-10-01", "2026-11-01")
  assert_eq(r.spans[0].changes, [
    @jieheng.CurrencyChanged,
    UnitChanged,
    IdentityChanged,
    VersionChanged,
    ModelChanged,
    PricingChanged,
    MinimumChanged,
    ZeroPolicyChanged,
  ])
  assert_true(@jieheng.CurrencyChanged.is_blocking())
  assert_true(@jieheng.UnitChanged.is_blocking())
  assert_false(@jieheng.PricingChanged.is_blocking())
  assert_false(@jieheng.ModelChanged.is_blocking())
  @jieheng.verify_catalog_migration(b, a, r.starts_on, r.ends_before, r)
  let pkg = @jieheng.compile_package(
    id="sms",
    version="v1",
    metric="messages",
    unit="message",
    currency="USD",
    package_size="1000",
    package_price="1",
  )
  let added = one(PackageTariff(pkg))
  let changed = @jieheng.audit_catalog_migration(
    b, added, "2026-10-01", "2026-11-01",
  )
  assert_eq(changed.spans[0].changes, [@jieheng.MetricRemoved])
  assert_eq(changed.spans[1].changes, [@jieheng.MetricAdded])
  @jieheng.verify_catalog_migration(
    b,
    added,
    changed.starts_on,
    changed.ends_before,
    changed,
  )
}

///|
test "migration covers every day over independently enumerated interval pairs" {
  let e = catalog_entries()[0]
  let day = (n : Int32) => "2026-02-0\{n}"
  for left in 1..<6 {
    for right in (left + 1)..<8 {
      let b = @jieheng.compile_catalog([
        { ..e, starts_on: day(left), ends_before: Some(day(right)), },
      ])
      let a = @jieheng.compile_catalog([
        { ..e, starts_on: day(3), ends_before: Some(day(6)), },
      ])
      let r = @jieheng.audit_catalog_migration(b, a, day(1), day(8))
      @jieheng.verify_catalog_migration(b, a, day(1), day(8), r)
      for d in 1..<8 {
        let rows = r.spans.filter(s => {
          s.starts_on <= day(d) && day(d) < s.ends_before
        })
        assert_eq(rows.length(), 1)
        assert_eq(rows[0].baseline_entry is Some(_), left <= d && d < right)
        assert_eq(rows[0].candidate_entry is Some(_), 3 <= d && d < 6)
        assert_eq(
          rows[0].changes.contains(@jieheng.BaselineGap),
          !(left <= d && d < right),
        )
        assert_eq(
          rows[0].changes.contains(@jieheng.CandidateGap),
          !(3 <= d && d < 6),
        )
      }
    }
  }
  let c = @jieheng.compile_catalog([e])
  for
    (s, t) in [
      ("1900-02-29", "2000-03-01"),
      ("2026-10-01", "2026-10-01"),
      ("2026-10-02", "2026-10-01"),
    ] {
    rejected(() => ignore(@jieheng.audit_catalog_migration(c, c, s, t)))
  }
}

///|
test "migration handles maximum catalog timelines and rejects oversized archives without truncation" {
  let before : Array[@jieheng.CatalogEntry] = []
  let after : Array[@jieheng.CatalogEntry] = []
  for metric_index in 0..<4 {
    let metric = "metric-\{metric_index}"
    for version in 0..<128 {
      let year = (2020 + version).to_string()
      let next = (2021 + version).to_string()
      let p = @jieheng.compile_plan(
        id=metric,
        version="v\{version}",
        metric~,
        unit="unit",
        currency="USD",
        tiers=[{ up_to: None, unit_price: "1", }],
      )
      before.push({
        starts_on: year + "-01-01",
        ends_before: if version == 127 {
          None
        } else {
          Some(next + "-01-01")
        },
        tariff: MeteredTariff(p, "0", Charge),
      })
      after.push({
        starts_on: year + "-07-01",
        ends_before: if version == 127 {
          None
        } else {
          Some(next + "-07-01")
        },
        tariff: MeteredTariff(p, "0", Charge),
      })
    }
  }
  let b = @jieheng.compile_catalog(before[:])
  let a = @jieheng.compile_catalog(after[:])
  let r = @jieheng.audit_catalog_migration(b, a, "2020-01-01", "2148-01-01")
  assert_eq(r.spans.length(), 1024)
  @jieheng.verify_catalog_migration(b, a, r.starts_on, r.ends_before, r)
  assert_eq(
    @jieheng.decode_catalog_migration(@jieheng.encode_catalog_migration(r)),
    r,
  )
  let oversized = {
    ..r,
    spans: [{ ..r.spans[0], metric: "x".repeat(1048576), }],
  }
  rejected(() => ignore(@jieheng.encode_catalog_migration(oversized)))
  let p = priced("1")
  let pkg = @jieheng.compile_package(
    id="api",
    version="v1",
    metric="calls",
    unit="call",
    currency="USD",
    package_size="2",
    package_price="1",
  )
  let left = @jieheng.compile_catalog([
    {
      starts_on: "2026-01-01",
      ends_before: None,
      tariff: MeteredTariff(p, "5", Charge),
    },
  ])
  let right = @jieheng.compile_catalog([
    { starts_on: "2026-01-01", ends_before: None, tariff: PackageTariff(pkg), },
  ])
  let switched = @jieheng.audit_catalog_migration(
    left, right, "2026-01-01", "2027-01-01",
  )
  assert_eq(switched.spans[0].changes, [@jieheng.ModelChanged])
}
