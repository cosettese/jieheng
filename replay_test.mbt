///|
fn replay_case(
  customer : String,
  quantity : String,
) -> @jieheng.CatalogReplayCase {
  {
    on: "2026-10-22",
    usages: [
      { ..usage(if quantity == "0" { "0" } else { "1" }), customer, },
      { ..usage(quantity), customer, metric: "messages", },
    ],
  }
}

///|
fn replay_catalog_pair() -> (@jieheng.Catalog, @jieheng.Catalog) raise @jieheng.PricingError {
  let entries = catalog_entries()
  let p = @jieheng.compile_package(
    id="messages",
    version="new",
    metric="messages",
    unit="message",
    currency="USD",
    package_size="5",
    package_price="0.010",
  )
  (
    @jieheng.compile_catalog(entries[:]),
    @jieheng.compile_catalog([
      { ..entries[0], tariff: MeteredTariff(priced("0.004"), "0", Waive), },
      { starts_on: "2026-10-01", ends_before: None, tariff: PackageTariff(p), },
    ]),
  )
}

///|
test "replay preserves complete mixed bills, dated binding and per-item settlements" {
  let (b, a) = replay_catalog_pair()
  let cases = [
    replay_case("a", "6"),
    replay_case("b", "0"),
    replay_case("c", "1"),
  ]
  let r = @jieheng.replay_catalogs(b, a, cases[:], scale=2, rounding=HalfEven)
  assert_eq(r.baseline_exact, "0.033")
  assert_eq(r.candidate_exact, "0.038")
  assert_eq(r.baseline_settled, "0.02")
  assert_eq(r.candidate_settled, "0.03")
  assert_eq(r.settled_delta, "0.01")
  assert_eq((r.increased, r.decreased, r.unchanged), (1, 0, 2))
  assert_eq(r.max_increase_index, Some(0))
  assert_eq(r.max_increase, "0.01")
  let ties = [replay_case("first", "6"), replay_case("second", "6")]
  let tied = @jieheng.replay_catalogs(b, a, ties[:], scale=2, rounding=HalfEven)
  assert_eq(tied.max_increase_index, Some(0))
  @jieheng.verify_catalog_replay(b, a, cases[:], r, scale=2, rounding=HalfEven)
  assert_eq(
    @jieheng.decode_replay_cases(@jieheng.encode_replay_cases(cases[:])),
    cases,
  )
  let json = @jieheng.encode_catalog_replay(r)
  assert_eq(@jieheng.decode_catalog_replay(json), r)
  assert_eq(
    @jieheng.encode_catalog_replay(@jieheng.decode_catalog_replay(json)),
    json,
  )
  for
    forged in [
      { ..r, rows: [], },
      { ..r, currency: "EUR", },
      { ..r, increased: 0, },
      { ..r, max_increase_index: Some(1), },
      { ..r, settled_delta: "0", },
      { ..r, rows: [{ ..r.rows[0], on: "2026-10-23", }, ..r.rows[1:]], },
      { ..r, rows: [r.rows[1], r.rows[0], r.rows[2]], },
    ] {
    rejected(() => {
      @jieheng.verify_catalog_replay(
        b,
        a,
        cases[:],
        forged,
        scale=2,
        rounding=HalfEven,
      )
    })
  }
  for
    bad in [
      json.replace(old="\"currency\":", new="\"extension\":true,\"currency\":"),
      json.replace(old="\"schema\":", new="\"schema\":\"wrong\",\"schema\":"),
      json.replace(old="\"increased\":1", new="\"increased\":257"),
    ] {
    rejected(() => ignore(@jieheng.decode_catalog_replay(bad)))
  }
  let reverse = @jieheng.replay_catalogs(
    a,
    b,
    cases[:],
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(
    (reverse.increased, reverse.decreased, reverse.unchanged),
    (0, 1, 2),
  )
  assert_eq(reverse.max_increase_index, None)
  assert_eq(reverse.max_increase, "0")
  assert_eq(
    @jieheng.replay_catalogs(b, a, cases[:], scale=2, rounding=HalfEven),
    r,
  )
}

///|
fn flat_catalog(price : String) -> @jieheng.Catalog raise @jieheng.PricingError {
  @jieheng.compile_catalog([
    {
      starts_on: "2026-01-01",
      ends_before: None,
      tariff: MeteredTariff(priced(price), "0", Waive),
    },
  ])
}

///|
fn single_replay_case(
  customer : String,
  q : String,
) -> @jieheng.CatalogReplayCase {
  { on: "2026-10-22", usages: [{ ..usage(q), customer, }], }
}

///|
fn replay_policy_passes(
  b : @jieheng.Catalog,
  a : @jieheng.Catalog,
  cases : ArrayView[@jieheng.CatalogReplayCase],
  r : @jieheng.CatalogReplay,
  p : @jieheng.ReplayPolicy,
  scale : Int32,
  rounding : @jieheng.Rounding,
) -> Bool raise {
  try {
    @jieheng.check_replay_policy(b, a, cases, r, p, scale~, rounding~)
    true
  } catch {
    @jieheng.Invalid(code~, ..) => {
      assert_eq(code, "policy")
      false
    }
  }
}

///|
test "release policy checks exact percent boundaries and explicit zero-baseline semantics" {
  let b = flat_catalog("0.01")
  let a = flat_catalog("0.011")
  let cases = [single_replay_case("a", "100")]
  let r = @jieheng.replay_catalogs(b, a, cases[:], scale=2, rounding=HalfEven)
  let p : @jieheng.ReplayPolicy = {
    currency: "USD",
    max_increase: "0.1",
    max_increase_percent: Some("10"),
  }
  @jieheng.check_replay_policy(b, a, cases[:], r, p, scale=2, rounding=HalfEven)
  assert_eq(@jieheng.decode_replay_policy(@jieheng.encode_replay_policy(p)), p)
  rejected(() => {
    ignore(@jieheng.encode_replay_policy({ ..p, max_increase: "-1", }))
  })
  rejected(() => {
    ignore(
      @jieheng.encode_replay_policy({ ..p, max_increase_percent: Some("1e2"), }),
    )
  })
  rejected(() => {
    ignore(
      @jieheng.decode_replay_policy(
        @jieheng.encode_replay_policy(p).replace(
          old="\"schema\":",
          new="\"extension\":true,\"schema\":",
        ),
      ),
    )
  })
  rejected(() => {
    @jieheng.check_replay_policy(
      b,
      a,
      cases[:],
      { ..r, max_increase: "0", },
      p,
      scale=2,
      rounding=HalfEven,
    )
  })
  assert_false(
    replay_policy_passes(
      b,
      a,
      cases[:],
      r,
      { ..p, max_increase: "0.099999999999999999", },
      2,
      HalfEven,
    ),
  )
  assert_false(
    replay_policy_passes(
      b,
      a,
      cases[:],
      r,
      { ..p, max_increase_percent: Some("9.999999999999999999"), },
      2,
      HalfEven,
    ),
  )
  rejected(() => {
    @jieheng.check_replay_policy(
      b,
      a,
      cases[:],
      r,
      { ..p, currency: "EUR", },
      scale=2,
      rounding=HalfEven,
    )
  })
  let free = flat_catalog("0")
  let free_r = @jieheng.replay_catalogs(
    free,
    a,
    cases[:],
    scale=2,
    rounding=HalfEven,
  )
  let free_policy = {
    ..p,
    max_increase: "100",
    max_increase_percent: Some("999999"),
  }
  assert_false(
    replay_policy_passes(free, a, cases[:], free_r, free_policy, 2, HalfEven),
  )
  assert_true(
    replay_policy_passes(
      free,
      a,
      cases[:],
      free_r,
      { ..free_policy, max_increase_percent: None, },
      2,
      HalfEven,
    ),
  )
  let zeros = [single_replay_case("zero", "0")]
  let zr = @jieheng.replay_catalogs(
    free,
    a,
    zeros[:],
    scale=2,
    rounding=HalfEven,
  )
  assert_true(replay_policy_passes(free, a, zeros[:], zr, p, 2, HalfEven))
  let huge = [single_replay_case("huge", "9".repeat(30))]
  let hb = flat_catalog("1")
  let ha = flat_catalog("1.000000000000000001")
  let hr = @jieheng.replay_catalogs(
    hb,
    ha,
    huge[:],
    scale=18,
    rounding=HalfEven,
  )
  assert_true(
    replay_policy_passes(
      hb,
      ha,
      huge[:],
      hr,
      {
        currency: "USD",
        max_increase: "9".repeat(60),
        max_increase_percent: Some("0.0000000000000001"),
      },
      18,
      HalfEven,
    ),
  )
}

///|
test "batch totals and policy decisions agree with forward bills across rounding modes" {
  let b = flat_catalog("0.007")
  let a = flat_catalog("0.011")
  let cases = Array::makei(13, i => single_replay_case("c\{i}", i.to_string()))
  for scale in [0, 2, 18] {
    for rounding in [@jieheng.HalfEven, HalfUp, Down, Up] {
      let r = @jieheng.replay_catalogs(b, a, cases[:], scale~, rounding~)
      let mut sum_b = 0N
      let mut sum_a = 0N
      let mut rises = 0
      for c in cases {
        let br = @jieheng.rate_catalog(b, c.on, c.usages[:], scale~, rounding~)
        let ar = @jieheng.rate_catalog(a, c.on, c.usages[:], scale~, rounding~)
        sum_b += reference_atoms(br.bill.totals.amount)
        sum_a += reference_atoms(ar.bill.totals.amount)
        if reference_atoms(ar.bill.totals.amount) >
          reference_atoms(br.bill.totals.amount) {
          rises += 1
        }
      }
      assert_eq(reference_atoms(r.baseline_settled), sum_b)
      assert_eq(reference_atoms(r.candidate_settled), sum_a)
      assert_eq(r.increased, rises)
      for cap in ["0", "0.01", "1"] {
        for percent in [None, Some("0"), Some("50")] {
          let p : @jieheng.ReplayPolicy = {
            currency: "USD",
            max_increase: cap,
            max_increase_percent: percent,
          }
          let mut expected = true
          for row in r.rows {
            let before = reference_atoms(row.comparison.baseline.totals.amount)
            let delta = reference_atoms(row.comparison.candidate.totals.amount) -
              before
            if delta > reference_atoms(cap) {
              expected = false
            }
            if delta > 0N &&
              percent is Some(n) &&
              (before == 0N || delta * 100N > before * BigInt::from_string(n)) {
              expected = false
            }
          }
          assert_eq(
            replay_policy_passes(b, a, cases[:], r, p, scale, rounding),
            expected,
          )
        }
      }
    }
  }
}

///|
test "replay rejects incomplete, duplicate, oversized and overflowing batches without partial reports" {
  let (b, a) = replay_catalog_pair()
  let c = replay_case("a", "1")
  for
    cases in [
      [],
      [c, { ..c, on: "2026-10-23", }],
      [{ ..c, usages: [c.usages[0]], }],
      [{ ..c, on: "1900-02-29", }],
      Array::make(257, c),
    ] {
    rejected(() => {
      ignore(
        @jieheng.replay_catalogs(b, a, cases[:], scale=2, rounding=HalfEven),
      )
    })
  }
  let many : Array[@jieheng.CatalogReplayCase] = Array::makei(17, i => {
    on: "2026-10-22",
    usages: Array::makei(64, j => {
      ..usage("0"),
      customer: "c\{i}",
      metric: "m\{j}",
    }),
  })
  rejected(() => ignore(@jieheng.encode_replay_cases(many[:])))
  let large = flat_catalog("9".repeat(30))
  let overflow = [
    single_replay_case("a", "9".repeat(30)),
    single_replay_case("b", "9".repeat(30)),
  ]
  rejected(() => {
    ignore(
      @jieheng.replay_catalogs(
        large,
        large,
        overflow[:],
        scale=0,
        rounding=Down,
      ),
    )
  })
  let minimal = flat_catalog("0")
  let max_cases = Array::makei(256, i => single_replay_case("c\{i}", "0"))
  let r = @jieheng.replay_catalogs(
    minimal,
    minimal,
    max_cases[:],
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(r.unchanged, 256)
  assert_eq(
    @jieheng.decode_catalog_replay(@jieheng.encode_catalog_replay(r)),
    r,
  )
  let giant = { ..r, max_increase: "x".repeat(1048576), }
  rejected(() => ignore(@jieheng.encode_catalog_replay(giant)))
}
