///|
fn volume_plan() -> @jieheng.Plan raise {
  @jieheng.compile_plan(
    id="api",
    version="v1",
    metric="calls",
    unit="call",
    currency="USD",
    mode=Volume,
    tiers=[
      { up_to: Some("5"), unit_price: "7", },
      { up_to: Some("10"), unit_price: "6.5", },
      { up_to: None, unit_price: "6", },
    ],
  )
}

///|
test "published volume example and exact boundary selection" {
  let p = volume_plan()
  assert_eq(p.mode(), @jieheng.Volume)
  for
    (q, total, index) in [
      ("0", "0", -1),
      ("1", "7", 0),
      ("4", "28", 0),
      ("5", "35", 0),
      ("6", "39", 1),
      ("9", "58.5", 1),
      ("10", "65", 1),
      ("11", "66", 2),
      ("20", "120", 2),
      ("25", "150", 2),
    ] {
    let u = usage(q)
    let e = evidence(p, u)
    assert_eq(e.calculation.total, total)
    assert_eq(e.calculation.lines.length(), if index == -1 { 0 } else { 1 })
    if index >= 0 {
      let line = e.calculation.lines[0]
      assert_eq(line.tier, index)
      assert_eq(line.quantity, q)
      assert_eq(line.from_exclusive, "0")
      assert_eq(line.to_inclusive, q)
    }
    @jieheng.verify_evidence(p, u, e, scale=2, rounding=HalfEven)
    assert_eq(@jieheng.decode_evidence(@jieheng.encode_evidence(e)), e)
  }
}

///|
test "volume oracle free tiers subcent totals and price cliffs" {
  let p = volume_plan()
  for q in 1..<=100 {
    let r = @jieheng.rate(p, usage(q.to_string()))
    let expected_half_units = q *
      (if q <= 5 { 14 } else if q <= 10 { 13 } else { 12 })
    assert_eq(
      @jieheng.settle(r, scale=1, rounding=Down).minor_units,
      (expected_half_units * 5).to_string(),
    )
    @jieheng.verify_calculation(p, usage(q.to_string()), r)
  }
  let p = @jieheng.compile_plan(
    id="cliff",
    version="v1",
    metric="calls",
    unit="call",
    currency="USD",
    mode=Volume,
    tiers=[
      { up_to: Some("100"), unit_price: "1", },
      { up_to: None, unit_price: "0.1", },
    ],
  )
  assert_eq(@jieheng.rate(p, usage("100")).total, "100")
  assert_eq(@jieheng.rate(p, usage("101")).total, "10.1")
  let free = @jieheng.compile_plan(
    id="free",
    version="v1",
    metric="calls",
    unit="call",
    currency="USD",
    mode=Volume,
    tiers=[
      { up_to: Some("5"), unit_price: "0", },
      { up_to: None, unit_price: "0.004", },
    ],
  )
  assert_eq(@jieheng.rate(free, usage("5")).total, "0")
  let e = evidence(free, usage("6"))
  assert_eq(e.calculation.total, "0.024")
  assert_eq(e.settlement.amount, "0.02")
  @jieheng.verify_evidence(free, usage("6"), e, scale=2, rounding=HalfEven)
}

///|
test "volume and graduated remain distinct under trusted plan verification" {
  let p = volume_plan()
  let u = usage("6")
  let e = evidence(p, u)
  let c = e.calculation
  let wrong : Array[@jieheng.Calculation] = [
    { ..c, total: "41.5", },
    { ..c, lines: [], },
    { ..c, lines: [c.lines[0], c.lines[0]], },
    { ..c, lines: [{ ..c.lines[0], tier: -1, }], },
    { ..c, lines: [{ ..c.lines[0], tier: 3, }], },
    {
      ..c,
      lines: [{ ..c.lines[0], tier: 0, unit_price: "7", subtotal: "42", }],
      total: "42",
    },
    {
      ..c,
      lines: [{ ..c.lines[0], tier: 2, unit_price: "6", subtotal: "36", }],
      total: "36",
    },
    {
      ..c,
      lines: [
        { ..c.lines[0], from_exclusive: "5", quantity: "1", subtotal: "6.5", },
      ],
      total: "6.5",
    },
    { ..c, lines: [{ ..c.lines[0], quantity: "06", }], },
    { ..c, lines: [{ ..c.lines[0], to_inclusive: "7", }], },
  ]
  for bad in wrong {
    rejected(() => @jieheng.verify_calculation(p, u, bad))
  }
  let graduated = @jieheng.decode_plan(
    @jieheng.encode_plan(p).replace(
      old="\"mode\":\"volume\"",
      new="\"mode\":\"graduated\"",
    ),
  )
  assert_eq(graduated.mode(), @jieheng.Graduated)
  rejected(() => @jieheng.verify_calculation(graduated, u, c))
  rejected(() => @jieheng.verify_calculation(p, u, @jieheng.rate(graduated, u)))
  let zero = @jieheng.rate(p, usage("0"))
  rejected(() => {
    @jieheng.verify_calculation(p, usage("0"), { ..zero, total: "1", })
  })
  @jieheng.verify_calculation(p, u, c)
}

///|
test "volume plan round trips preserve mode huge precision and tier limits" {
  let original = volume_plan()
  let encoded = @jieheng.encode_plan(original)
  let decoded = @jieheng.decode_plan(encoded)
  assert_eq(decoded.mode(), @jieheng.Volume)
  assert_eq(@jieheng.encode_plan(decoded), encoded)
  assert_eq(
    @jieheng.rate(original, usage("20")),
    @jieheng.rate(decoded, usage("20")),
  )
  let tiers : Array[@jieheng.Tier] = []
  for i in 1..<=1023 {
    tiers.push({ up_to: Some(i.to_string()), unit_price: "0.001", })
  }
  tiers.push({ up_to: None, unit_price: "0.000000000000000001", })
  let p = @jieheng.compile_plan(
    id="large",
    version="v1",
    metric="calls",
    unit="call",
    currency="USD",
    mode=Volume,
    tiers~,
  )
  let q = "999999999999999999999999999999"
  let e = evidence(p, usage(q), scale=18)
  assert_eq(e.calculation.lines[0].tier, 1023)
  assert_eq(e.calculation.total, "999999999999.999999999999999999")
  @jieheng.verify_evidence(p, usage(q), e, scale=18, rounding=HalfEven)
  let default_plan = plan([{ up_to: None, unit_price: "1", }])
  assert_eq(default_plan.mode(), @jieheng.Graduated)
}
