///|
fn plan(tiers : Array[@jieheng.Tier]) -> @jieheng.Plan raise {
  @jieheng.compile_plan(
    id="api",
    version="v1",
    metric="calls",
    unit="call",
    currency="USD",
    tiers~,
  )
}

///|
fn usage(quantity : String) -> @jieheng.Usage {
  { customer: "acme", metric: "calls", period: "2026-09", quantity, }
}

///|
fn rejected(f : () -> Unit raise @jieheng.PricingError) -> Unit raise {
  try f() catch {
    @jieheng.Invalid(code~, path~, message~) => {
      assert_true(code.length() > 0)
      assert_true(path.length() > 0)
      assert_true(message.length() > 0)
    }
  } noraise {
    _ => fail("expected diagnostic")
  }
}

///|
test "published graduated example and occupied tier explanation" {
  let p = plan([
    { up_to: Some("5"), unit_price: "7", },
    { up_to: Some("10"), unit_price: "6.5", },
    { up_to: None, unit_price: "6", },
  ])
  for
    (q, expected) in [
      ("0", "0"),
      ("4", "28"),
      ("5", "35"),
      ("6", "41.5"),
      ("9", "61"),
      ("10", "67.5"),
      ("11", "73.5"),
      ("20", "127.5"),
      ("25", "157.5"),
    ] {
    assert_eq(@jieheng.rate(p, usage(q)).total, expected)
  }
  let r = @jieheng.rate(p, usage("6"))
  assert_eq(r.lines.length(), 2)
  assert_eq(r.lines[1], {
    tier: 1,
    from_exclusive: "5",
    to_inclusive: "6",
    quantity: "1",
    unit_price: "6.5",
    subtotal: "6.5",
  })
  assert_eq(@jieheng.rate(p, usage("0")).lines.length(), 0)
}

///|
test "conservation and marginal pricing against a per-unit oracle" {
  let tiers : Array[@jieheng.Tier] = [
    { up_to: Some("3"), unit_price: "0", },
    { up_to: Some("9"), unit_price: "0.003", },
    { up_to: Some("17"), unit_price: "0.002", },
    { up_to: None, unit_price: "0.001", },
  ]
  let p = plan(tiers)
  let mut expected_mills = 0
  for q in 0..<=100 {
    if q > 0 {
      expected_mills += if q <= 3 {
        0
      } else if q <= 9 {
        3
      } else if q <= 17 {
        2
      } else {
        1
      }
    }
    let r = @jieheng.rate(p, usage(q.to_string()))
    let mut sum = 0N
    for line in r.lines {
      sum += BigInt::from_string(line.quantity)
      assert_eq(
        BigInt::from_string(line.to_inclusive) -
        BigInt::from_string(line.from_exclusive),
        BigInt::from_string(line.quantity),
      )
    }
    assert_eq(sum, BigInt::from_int(q))
    let mills = @jieheng.settle(r, scale=3, rounding=Down)
    assert_eq(mills.minor_units, expected_mills.to_string())
    assert_eq(@jieheng.rate(p, usage(q.to_string())), r)
  }
}

///|
test "round once retains subcent lines" {
  let p = plan([
    { up_to: Some("1"), unit_price: "0.004", },
    { up_to: None, unit_price: "0.004", },
  ])
  let r = @jieheng.rate(p, usage("2"))
  assert_eq(r.total, "0.008")
  let s = @jieheng.settle(r, scale=2, rounding=HalfEven)
  assert_eq(s.amount, "0.01")
  assert_eq(s.delta, "0.002")
  assert_eq(@jieheng.settle(r, scale=2, rounding=Down).delta, "-0.008")
}

///|
test "ties and directed rounding at scales zero two and eighteen" {
  for
    (price, even, half_up, down, up) in [
      ("0.005", "0.00", "0.01", "0.00", "0.01"),
      ("0.015", "0.02", "0.02", "0.01", "0.02"),
      ("0.025", "0.02", "0.03", "0.02", "0.03"),
      ("0", "0.00", "0.00", "0.00", "0.00"),
    ] {
    let r = @jieheng.rate(
      plan([{ up_to: None, unit_price: price, }]),
      usage("1"),
    )
    assert_eq(@jieheng.settle(r, scale=2, rounding=HalfEven).amount, even)
    assert_eq(@jieheng.settle(r, scale=2, rounding=HalfUp).amount, half_up)
    assert_eq(@jieheng.settle(r, scale=2, rounding=Down).amount, down)
    assert_eq(@jieheng.settle(r, scale=2, rounding=Up).amount, up)
  }
  let r = @jieheng.rate(plan([{ up_to: None, unit_price: "2.5", }]), usage("1"))
  assert_eq(@jieheng.settle(r, scale=0, rounding=HalfEven).amount, "2")
  assert_eq(
    @jieheng.settle(r, scale=18, rounding=HalfEven).amount,
    "2.500000000000000000",
  )
}

///|
test "exact huge quantities and eighteen digit fractional price" {
  let max = "999999999999999999999999999999"
  let p = plan([{ up_to: None, unit_price: max, }])
  assert_eq(
    @jieheng.rate(p, usage(max)).total,
    "999999999999999999999999999998000000000000000000000000000001",
  )
  let r = @jieheng.rate(
    plan([{ up_to: None, unit_price: "0.000000000000000001", }]),
    usage(max),
  )
  assert_eq(r.total, "999999999999.999999999999999999")
  assert_eq(
    @jieheng.settle(r, scale=2, rounding=HalfEven).amount,
    "1000000000000.00",
  )
}

///|
test "compiled plan detaches caller owned tiers" {
  let tiers : Array[@jieheng.Tier] = [{ up_to: None, unit_price: "1.00", }]
  let p = plan(tiers)
  tiers[0] = { up_to: None, unit_price: "100", }
  assert_eq(@jieheng.rate(p, usage("2")).total, "2")
}

///|
test "invalid bounds decimals quantities metrics and recovery" {
  let invalid_tiers : Array[Array[@jieheng.Tier]] = [
    [],
    [{ up_to: Some("1"), unit_price: "1", }],
    [{ up_to: None, unit_price: "1", }, { up_to: None, unit_price: "1", }],
    [{ up_to: Some("0"), unit_price: "1", }, { up_to: None, unit_price: "1", }],
    [
      { up_to: Some("2"), unit_price: "1", },
      { up_to: Some("2"), unit_price: "1", },
      { up_to: None, unit_price: "1", },
    ],
  ]
  for tiers in invalid_tiers {
    rejected(() => {
      ignore(
        @jieheng.compile_plan(
          id="p",
          version="v",
          metric="calls",
          unit="call",
          currency="USD",
          tiers~,
        ),
      )
    })
  }
  for
    price in [
      "", "-1", "+1", "NaN", "1e2", " 1", "01", ".1", "1.", "1.2.3", "0.0000000000000000001",
      "1000000000000000000000000000000",
    ] {
    rejected(() => {
      ignore(
        @jieheng.compile_plan(
          id="p",
          version="v",
          metric="calls",
          unit="call",
          currency="USD",
          tiers=[{ up_to: None, unit_price: price, }],
        ),
      )
    })
  }
  let p = plan([{ up_to: None, unit_price: "1", }])
  for
    quantity in [
      "", "-1", "1.0", "1e3", "01", "1000000000000000000000000000000",
    ] {
    rejected(() => ignore(@jieheng.rate(p, usage(quantity))))
  }
  rejected(() => ignore(@jieheng.rate(p, { ..usage("1"), metric: "other", })))
  let r = @jieheng.rate(p, usage("1"))
  rejected(() => ignore(@jieheng.settle(r, scale=19, rounding=HalfEven)))
  rejected(() => ignore(@jieheng.settle(r, scale=-1, rounding=HalfEven)))
  assert_eq(@jieheng.rate(p, usage("2")).total, "2")
}

///|
test "1024 tiers permitted 1025 rejected" {
  let tiers : Array[@jieheng.Tier] = []
  for i in 1..<=1023 {
    tiers.push({ up_to: Some(i.to_string()), unit_price: "0.001", })
  }
  tiers.push({ up_to: None, unit_price: "0.001", })
  assert_eq(@jieheng.rate(plan(tiers), usage("1024")).total, "1.024")
  tiers.insert(0, { up_to: Some("1"), unit_price: "0", })
  rejected(() => {
    ignore(
      @jieheng.compile_plan(
        id="p",
        version="v",
        metric="calls",
        unit="call",
        currency="USD",
        tiers~,
      ),
    )
  })
}
