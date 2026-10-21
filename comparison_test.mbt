///|
fn priced(price : String, version~ : String = "v1") -> @jieheng.Plan raise {
  @jieheng.compile_plan(
    id="api",
    version~,
    metric="calls",
    unit="call",
    currency="USD",
    tiers=[{ up_to: None, unit_price: price, }],
  )
}

///|
test "comparison distinguishes exact change from separately settled change" {
  let before = priced("0.004")
  let after = priced("0.006", version="v2")
  let u = usage("1")
  let report = @jieheng.compare_plans(
    before,
    after,
    u,
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(report.exact_delta, "0.002")
  assert_eq(report.settled_delta, "0.01")
  assert_eq(report.baseline.settlement.amount, "0.00")
  assert_eq(report.candidate.settlement.amount, "0.01")
  @jieheng.verify_comparison(
    before,
    after,
    u,
    report,
    scale=2,
    rounding=HalfEven,
  )
  let reverse = @jieheng.compare_plans(
    after,
    before,
    u,
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(reverse.exact_delta, "-0.002")
  assert_eq(reverse.settled_delta, "-0.01")
}

///|
test "comparison is reflexive antisymmetric deterministic and serializable" {
  let before = priced("0.005")
  let after = priced("0.004")
  for q in 0..<=40 {
    let u = usage(q.to_string())
    for rounding in [@jieheng.HalfEven, HalfUp, Down, Up] {
      let r = @jieheng.compare_plans(before, after, u, scale=2, rounding~)
      let same = @jieheng.compare_plans(before, before, u, scale=2, rounding~)
      assert_eq(same.exact_delta, "0")
      assert_eq(same.settled_delta, "0")
      let reverse = @jieheng.compare_plans(after, before, u, scale=2, rounding~)
      assert_eq(
        reverse.exact_delta,
        if r.exact_delta == "0" {
          "0"
        } else {
          r.exact_delta[1:].to_owned()
        },
      )
      assert_eq(
        reverse.settled_delta,
        if r.settled_delta == "0" {
          "0"
        } else {
          r.settled_delta[1:].to_owned()
        },
      )
      assert_eq(@jieheng.compare_plans(before, after, u, scale=2, rounding~), r)
      let encoded = @jieheng.encode_comparison(r)
      let decoded = @jieheng.decode_comparison(encoded)
      assert_eq(decoded, r)
      assert_eq(@jieheng.encode_comparison(decoded), encoded)
      @jieheng.verify_comparison(before, after, u, decoded, scale=2, rounding~)
    }
  }
}

///|
test "graduated versus volume and large exact negative differences" {
  let volume = volume_plan()
  let graduated = @jieheng.decode_plan(
    @jieheng.encode_plan(volume).replace(
      old="\"mode\":\"volume\"",
      new="\"mode\":\"graduated\"",
    ),
  )
  let r = @jieheng.compare_plans(
    graduated,
    volume,
    usage("20"),
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(r.baseline.calculation.total, "127.5")
  assert_eq(r.candidate.calculation.total, "120")
  assert_eq(r.exact_delta, "-7.5")
  assert_eq(r.settled_delta, "-7.5")
  let max = "999999999999999999999999999999"
  let r = @jieheng.compare_plans(
    priced(max),
    priced("0"),
    usage(max),
    scale=18,
    rounding=HalfEven,
  )
  assert_eq(
    r.exact_delta,
    "-999999999999999999999999999998000000000000000000000000000001",
  )
  assert_eq(r.settled_delta, r.exact_delta)
}

///|
test "comparison refuses incompatible dimensions policies and tampered claims" {
  let before = priced("0.004")
  let after = priced("0.006")
  let u = usage("1")
  let report = @jieheng.compare_plans(
    before,
    after,
    u,
    scale=2,
    rounding=HalfEven,
  )
  let bad : Array[@jieheng.Comparison] = [
    { ..report, exact_delta: "0", },
    { ..report, exact_delta: "0.0020", },
    { ..report, settled_delta: "0.002", },
    { ..report, settled_delta: "-0.01", },
    { ..report, baseline: report.candidate, },
    { ..report, candidate: report.baseline, },
    {
      ..report,
      candidate: {
        ..report.candidate,
        calculation: { ..report.candidate.calculation, total: "0", },
      },
    },
  ]
  for invalid in bad {
    rejected(() => {
      @jieheng.verify_comparison(
        before,
        after,
        u,
        invalid,
        scale=2,
        rounding=HalfEven,
      )
    })
  }
  rejected(() => {
    @jieheng.verify_comparison(
      before,
      after,
      usage("2"),
      report,
      scale=2,
      rounding=HalfEven,
    )
  })
  rejected(() => {
    @jieheng.verify_comparison(
      before,
      after,
      u,
      report,
      scale=3,
      rounding=HalfEven,
    )
  })
  rejected(() => {
    @jieheng.verify_comparison(
      before,
      after,
      u,
      report,
      scale=2,
      rounding=HalfUp,
    )
  })
  for
    (metric, unit, currency) in [
      ("calls", "call", "EUR"),
      ("calls", "byte", "USD"),
      ("other", "call", "USD"),
    ] {
    let candidate = @jieheng.compile_plan(
      id="p",
      version="v2",
      metric~,
      unit~,
      currency~,
      tiers=[{ up_to: None, unit_price: "1", }],
    )
    rejected(() => {
      ignore(
        @jieheng.compare_plans(before, candidate, u, scale=2, rounding=HalfEven),
      )
    })
    rejected(() => {
      @jieheng.verify_comparison(
        before,
        candidate,
        u,
        report,
        scale=2,
        rounding=HalfEven,
      )
    })
  }
  rejected(() => {
    ignore(
      @jieheng.compare_plans(before, after, u, scale=19, rounding=HalfEven),
    )
  })
  @jieheng.verify_comparison(
    before,
    after,
    u,
    report,
    scale=2,
    rounding=HalfEven,
  )
}

///|
test "comparison exchange rejects unknown duplicate malformed and missing data" {
  let before = priced("0.004")
  let after = priced("0.006")
  let u = usage("1")
  let encoded = @jieheng.encode_comparison(
    @jieheng.compare_plans(before, after, u, scale=2, rounding=HalfEven),
  )
  for
    invalid in [
      encoded.replace(
        old="\"schema\":\"jieheng.comparison.v1\"",
        new="\"schema\":\"jieheng.comparison.v2\"",
      ),
      encoded.replace(
        old="\"exact_delta\":\"0.002\"",
        new="\"exact_delta\":\"0.002\",\"tax\":\"1\"",
      ),
      encoded.replace(
        old="\"exact_delta\":\"0.002\"",
        new="\"exact_delta\":\"0\",\"exact_delta\":\"0.002\"",
      ),
      encoded.replace(
        old="\"exact_delta\":\"0.002\"",
        new="\"exact_delta\":0.002",
      ),
      encoded.replace(
        old="\"minor_units\":\"0\"",
        new="\"minor_units\":\"0\",\"unknown\":true",
      ),
      encoded.replace(old="\"candidate\":{", new="\"other\":{"),
      "{}",
      "null",
      "[",
      "not json",
    ] {
    rejected(() => ignore(@jieheng.decode_comparison(invalid)))
  }
  let forged = @jieheng.decode_comparison(
    encoded.replace(
      old="\"settled_delta\":\"0.01\"",
      new="\"settled_delta\":\"0\"",
    ),
  )
  rejected(() => {
    @jieheng.verify_comparison(
      before,
      after,
      u,
      forged,
      scale=2,
      rounding=HalfEven,
    )
  })
}
