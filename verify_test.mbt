///|
fn evidence(
  p : @jieheng.Plan,
  u : @jieheng.Usage,
  scale~ : Int32 = 2,
  rounding~ : @jieheng.Rounding = HalfEven,
) -> @jieheng.Evidence raise {
  let calculation = @jieheng.rate(p, u)
  { calculation, settlement: @jieheng.settle(calculation, scale~, rounding~), }
}

///|
test "evidence round trips and independent settlement intervals" {
  for mills in 0..<=99 {
    let price = "0." +
      "0".repeat(3 - mills.to_string().length()) +
      mills.to_string()
    let p = plan([
      { up_to: Some("5"), unit_price: price, },
      { up_to: None, unit_price: "0.005", },
    ])
    for scale in [0, 1, 2, 3, 18] {
      for rounding in [@jieheng.HalfEven, HalfUp, Down, Up] {
        let u = usage("7")
        let record = evidence(p, u, scale~, rounding~)
        @jieheng.verify_evidence(p, u, record, scale~, rounding~)
        let text = @jieheng.encode_evidence(record)
        let decoded = @jieheng.decode_evidence(text)
        assert_eq(decoded, record)
        assert_eq(@jieheng.encode_evidence(decoded), text)
      }
    }
  }
  let p = plan([{ up_to: None, unit_price: "0.000000000000000001", }])
  for q in ["0", "1", "999999999999999999999999999999"] {
    let u = usage(q)
    @jieheng.verify_evidence(p, u, evidence(p, u), scale=2, rounding=HalfEven)
  }
  let huge = plan([
    {
      up_to: None,
      unit_price: "999999999999999999999999999999.999999999999999999",
    },
  ])
  let u = usage("999999999999999999999999999999")
  let record = evidence(huge, u, scale=18)
  @jieheng.verify_evidence(huge, u, record, scale=18, rounding=HalfEven)
  assert_eq(@jieheng.decode_evidence(@jieheng.encode_evidence(record)), record)
}

///|
test "identity omission overlap prices subtotals and totals cannot be forged" {
  let p = plan([
    { up_to: Some("5"), unit_price: "7", },
    { up_to: None, unit_price: "6.5", },
  ])
  let u = usage("6")
  let c = @jieheng.rate(p, u)
  let changed : Array[@jieheng.Calculation] = [
    { ..c, plan_id: "another", },
    { ..c, plan_version: "v2", },
    { ..c, currency: "EUR", },
    { ..c, unit: "byte", },
    { ..c, usage: { ..u, customer: "another", }, },
    { ..c, total: "41.50", },
    { ..c, total: "41.49", },
    { ..c, lines: [], },
    { ..c, lines: [c.lines[0]], },
    { ..c, lines: [c.lines[1], c.lines[0]], },
    { ..c, lines: [c.lines[0], c.lines[0], c.lines[1]], },
  ]
  for fake in changed {
    rejected(() => @jieheng.verify_calculation(p, u, fake))
  }
  let first = c.lines[0]
  let changed_lines : Array[@jieheng.Line] = [
    { ..first, tier: 1, },
    { ..first, from_exclusive: "1", },
    { ..first, to_inclusive: "4", },
    { ..first, quantity: "4", },
    { ..first, unit_price: "6.5", },
    { ..first, subtotal: "34.99", },
    { ..first, quantity: "-1", },
    { ..first, quantity: "05", },
  ]
  for fake in changed_lines {
    rejected(() => {
      @jieheng.verify_calculation(p, u, { ..c, lines: [fake, c.lines[1]], })
    })
  }
  @jieheng.verify_calculation(p, u, c)
  rejected(() => @jieheng.verify_calculation(p, usage("7"), c))
}

///|
test "equal prices cannot disguise a shifted tier boundary" {
  let p = plan([
    { up_to: Some("5"), unit_price: "1", },
    { up_to: None, unit_price: "1", },
  ])
  let u = usage("6")
  let c = @jieheng.rate(p, u)
  let fake = {
    ..c,
    lines: [
      { ..c.lines[0], to_inclusive: "4", quantity: "4", subtotal: "4", },
      { ..c.lines[1], from_exclusive: "4", quantity: "2", subtotal: "2", },
    ],
  }
  rejected(() => @jieheng.verify_calculation(p, u, fake))
}

///|
test "settlement policy tie parity delta and fixed formatting are verified" {
  let p = plan([{ up_to: None, unit_price: "0.025", }])
  let r = evidence(p, usage("1"))
  let s = r.settlement
  let changed : Array[@jieheng.Settlement] = [
    { ..s, currency: "EUR", },
    { ..s, scale: 3, },
    { ..s, rounding: HalfUp, },
    { ..s, minor_units: "3", amount: "0.03", delta: "0.005", },
    { ..s, minor_units: "1", amount: "0.01", delta: "-0.015", },
    { ..s, delta: "0", },
    { ..s, amount: "0.020", },
    { ..s, amount: "0.03", },
    { ..s, minor_units: "02", },
    { ..s, minor_units: "-1", },
    { ..s, minor_units: "9".repeat(79), },
  ]
  for fake in changed {
    rejected(() => {
      @jieheng.verify_settlement(
        r.calculation,
        fake,
        scale=2,
        rounding=HalfEven,
      )
    })
  }
  rejected(() => {
    @jieheng.verify_evidence(p, usage("1"), r, scale=2, rounding=HalfUp)
  })
  @jieheng.verify_evidence(p, usage("1"), r, scale=2, rounding=HalfEven)
}

///|
test "transport rejects unsupported fields duplicate names and malformed indices" {
  let p = plan([{ up_to: None, unit_price: "0.005", }])
  let text = @jieheng.encode_evidence(evidence(p, usage("1")))
  for
    invalid in [
      text.replace(
        old="\"schema\":\"jieheng.evidence.v1\"",
        new="\"schema\":\"jieheng.evidence.v2\"",
      ),
      text.replace(old="\"scale\":2", new="\"scale\":2,\"tax\":\"1\""),
      text.replace(old="\"scale\":2", new="\"scale\":2,\"scale\":3"),
      text.replace(old="\"scale\":2", new="\"scale\":2.5"),
      text.replace(old="\"scale\":2", new="\"scale\":19"),
      text.replace(old="\"tier\":0", new="\"tier\":-1"),
      text.replace(old="\"tier\":0", new="\"tier\":1e100"),
      text.replace(old="\"tier\":0", new="\"tier\":\"0\""),
      "{}",
      "[]",
      "null",
      "not json",
    ] {
    rejected(() => ignore(@jieheng.decode_evidence(invalid)))
  }
  let forged = text.replace(old="\"total\":\"0.005\"", new="\"total\":\"0\"")
  let decoded = @jieheng.decode_evidence(forged)
  rejected(() => {
    @jieheng.verify_evidence(p, usage("1"), decoded, scale=2, rounding=HalfEven)
  })
  @jieheng.verify_evidence(
    p,
    usage("1"),
    @jieheng.decode_evidence(text),
    scale=2,
    rounding=HalfEven,
  )
}
