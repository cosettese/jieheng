///|
test "minimum applies before rounding and preserves usage evidence" {
  let p = priced("0.004")
  let u = usage("1")
  let c = @jieheng.rate_charge(
    p,
    u,
    minimum="0.0050",
    zero_usage=Charge,
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(c.calculation, @jieheng.rate(p, u))
  assert_eq(c.minimum, "0.005")
  assert_eq(c.top_up, "0.001")
  assert_eq(c.total, "0.005")
  assert_eq(c.settlement.amount, "0.00")
  assert_eq(c.settlement.delta, "-0.005")
  let text = @jieheng.encode_charge(c)
  assert_eq(@jieheng.decode_charge(text), c)
  assert_eq(@jieheng.encode_charge(@jieheng.decode_charge(text)), text)
  let fakes = [
    { ..c, minimum: "0.006", },
    { ..c, zero_usage: Waive, },
    { ..c, top_up: "0", },
    { ..c, top_up: "0.0010", },
    { ..c, total: "0.004", top_up: "0", },
    { ..c, total: "0.006", top_up: "0.002", },
    { ..c, total: "0.0050", },
    { ..c, calculation: { ..c.calculation, total: "0", }, },
    {
      ..c,
      settlement: {
        ..c.settlement,
        amount: "0.01",
        minor_units: "1",
        delta: "0.005",
      },
    },
  ]
  for fake in fakes {
    rejected(() => {
      @jieheng.verify_charge(
        p,
        u,
        fake,
        minimum="0.005",
        zero_usage=Charge,
        scale=2,
        rounding=HalfEven,
      )
    })
  }
  rejected(() => {
    @jieheng.verify_charge(
      p,
      u,
      c,
      minimum="0.006",
      zero_usage=Charge,
      scale=2,
      rounding=HalfEven,
    )
  })
  rejected(() => {
    @jieheng.verify_charge(
      p,
      u,
      c,
      minimum="0.005",
      zero_usage=Charge,
      scale=2,
      rounding=HalfUp,
    )
  })
  @jieheng.verify_charge(
    p,
    u,
    c,
    minimum="0.005",
    zero_usage=Charge,
    scale=2,
    rounding=HalfEven,
  )
}

///|
test "minimum boundary lattice zero policy and integer reference" {
  let p = priced("0.001")
  for q in 0..<=20 {
    for floor in 0..<=20 {
      let minimum = "0." +
        "0".repeat(3 - floor.to_string().length()) +
        floor.to_string()
      for zero_usage in [@jieheng.Charge, Waive] {
        let effective_floor = if q == 0 && zero_usage == Waive {
          0
        } else {
          floor
        }
        let expected = if q > effective_floor { q } else { effective_floor }
        let expected_decimal = "0." +
          "0".repeat(3 - expected.to_string().length()) +
          expected.to_string()
        let canonical_expected = @jieheng.rate(
            priced(expected_decimal),
            usage("1"),
          ).total
        for rounding in [@jieheng.HalfEven, HalfUp, Down, Up] {
          let c = @jieheng.rate_charge(
            p,
            usage(q.to_string()),
            minimum~,
            zero_usage~,
            scale=2,
            rounding~,
          )
          assert_eq(c.total, canonical_expected)
          @jieheng.verify_charge(
            p,
            usage(q.to_string()),
            c,
            minimum~,
            zero_usage~,
            scale=2,
            rounding~,
          )
        }
      }
    }
  }
  for scale in [0, 18] {
    let c = @jieheng.rate_charge(
      p,
      usage("0"),
      minimum="999999999999999999999999999999.000000000000000001",
      zero_usage=Charge,
      scale~,
      rounding=Up,
    )
    @jieheng.verify_charge(
      p,
      usage("0"),
      c,
      minimum=c.minimum,
      zero_usage=Charge,
      scale~,
      rounding=Up,
    )
  }
}

///|
test "minimum invalid input strict exchange and recovery" {
  let p = priced("1")
  for
    minimum in [
      "-1",
      "01",
      "1e2",
      "0.",
      " 1",
      "1.0000000000000000001",
      "9".repeat(31),
    ] {
    rejected(() => {
      ignore(
        @jieheng.rate_charge(
          p,
          usage("1"),
          minimum~,
          zero_usage=Charge,
          scale=2,
          rounding=HalfEven,
        ),
      )
    })
  }
  let c = @jieheng.rate_charge(
    p,
    usage("0"),
    minimum="10",
    zero_usage=Waive,
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(c.total, "0")
  assert_eq(c.top_up, "0")
  let text = @jieheng.encode_charge(c)
  for
    bad in [
      "{}",
      "null",
      "[",
      text.replace(old="jieheng.charge.v1", new="jieheng.charge.v2"),
      text.replace(
        old="\"zero_usage\":\"waive\"",
        new="\"zero_usage\":\"auto\"",
      ),
      text.replace(old="\"minimum\":\"10\"", new="\"minimum\":10"),
      text.replace(old="\"minimum\":\"10\"", new="\"minimum\":\"10\",\"tax\":0"),
      text.replace(
        old="\"minimum\":\"10\"",
        new="\"minimum\":\"0\",\"minimum\":\"10\"",
      ),
    ] {
    rejected(() => ignore(@jieheng.decode_charge(bad)))
  }
  assert_eq(@jieheng.decode_charge(text), c)
  @jieheng.verify_charge(
    p,
    usage("0"),
    c,
    minimum="10",
    zero_usage=Waive,
    scale=2,
    rounding=HalfEven,
  )
}
