///|
fn invoice_input(
  metric : String,
  price : String,
  minimum~ : String = "0",
) -> @jieheng.ChargeInput raise @jieheng.PricingError {
  {
    plan: @jieheng.compile_plan(
      id="api-" + metric,
      version="v1",
      metric~,
      unit="unit",
      currency="USD",
      tiers=[{ up_to: None, unit_price: price, }],
    ),
    usage: { ..usage("1"), metric, },
    minimum,
    zero_usage: Waive,
  }
}

///|
test "invoice rounds each metric once and sums settled minor units" {
  let items = [invoice_input("api", "0.004"), invoice_input("storage", "0.004")]
  let bill = @jieheng.rate_invoice(items[:], scale=2, rounding=HalfEven)
  assert_eq(bill.usage_total, "0.008")
  assert_eq(bill.top_up, "0")
  assert_eq(bill.total, "0.008")
  assert_eq(bill.amount, "0.00")
  assert_eq(bill.minor_units, "0")
  assert_eq(bill.delta, "-0.008")
  // A global rounding operation would instead produce 0.01 and is rejected.
  let fakes = [
    { ..bill, amount: "0.01", minor_units: "1", delta: "0.002", },
    { ..bill, charges: [bill.charges[1], bill.charges[0]], },
    { ..bill, charges: [bill.charges[0]], },
    { ..bill, charges: [bill.charges[0], bill.charges[0]], },
    { ..bill, customer: "other", },
    { ..bill, period: "other", },
    { ..bill, currency: "EUR", },
    { ..bill, usage_total: "0", },
    { ..bill, top_up: "0.001", },
    { ..bill, total: "0", },
    { ..bill, scale: 3, },
    { ..bill, rounding: HalfUp, },
    { ..bill, delta: "0", },
    { ..bill, minor_units: "00", },
  ]
  for fake in fakes {
    rejected(() => {
      @jieheng.verify_invoice(items[:], fake, scale=2, rounding=HalfEven)
    })
  }
  let text = @jieheng.encode_invoice(bill)
  assert_eq(@jieheng.decode_invoice(text), bill)
  assert_eq(@jieheng.encode_invoice(@jieheng.decode_invoice(text)), text)
  @jieheng.verify_invoice(items[:], bill, scale=2, rounding=HalfEven)
}

///|
test "invoice independent integer reference all rounding policies and precision" {
  let items = [
    invoice_input("api", "0.004", minimum="0.005"),
    invoice_input("storage", "0.006"),
  ]
  for
    (rounding, amount, delta) in [
      (@jieheng.HalfEven, "0.01", "-0.001"),
      (HalfUp, "0.02", "0.009"),
      (Down, "0.00", "-0.011"),
      (Up, "0.02", "0.009"),
    ] {
    let bill = @jieheng.rate_invoice(items[:], scale=2, rounding~)
    assert_eq(bill.usage_total, "0.01")
    assert_eq(bill.top_up, "0.001")
    assert_eq(bill.total, "0.011")
    assert_eq(bill.amount, amount)
    assert_eq(bill.delta, delta)
    @jieheng.verify_invoice(items[:], bill, scale=2, rounding~)
  }
  let many : Array[@jieheng.ChargeInput] = []
  for i in 0..<64 {
    many.push(invoice_input("metric-\{i}", "0.006"))
  }
  for scale in [0, 2, 18] {
    let bill = @jieheng.rate_invoice(many[:], scale~, rounding=HalfEven)
    assert_eq(bill.total, "0.384")
    let expected = if scale == 0 {
      "0"
    } else if scale == 2 {
      "0.64"
    } else {
      "0.384000000000000000"
    }
    assert_eq(bill.amount, expected)
    @jieheng.verify_invoice(many[:], bill, scale~, rounding=HalfEven)
    assert_eq(@jieheng.decode_invoice(@jieheng.encode_invoice(bill)), bill)
  }
  rejected(() => {
    ignore(
      @jieheng.rate_invoice(
        (many + [invoice_input("overflow", "1")])[:],
        scale=2,
        rounding=HalfEven,
      ),
    )
  })
}

///|
test "invoice rejects mixed identities duplicate metrics and aggregate overflow" {
  let first = invoice_input("api", "1")
  let second = invoice_input("storage", "1")
  let eur = @jieheng.compile_plan(
    id="eur",
    version="v1",
    metric="storage",
    unit="unit",
    currency="EUR",
    tiers=[{ up_to: None, unit_price: "1", }],
  )
  for
    bad in [
      [],
      [first, first],
      [first, { ..second, usage: { ..second.usage, customer: "other", }, }],
      [first, { ..second, usage: { ..second.usage, period: "other", }, }],
      [first, { ..second, plan: eur, }],
      [first, { ..second, usage: { ..second.usage, metric: "wrong", }, }],
      [first, { ..second, minimum: "-1", }],
    ] {
    rejected(() => {
      ignore(@jieheng.rate_invoice(bad[:], scale=2, rounding=HalfEven))
    })
    rejected(() => ignore(@jieheng.encode_invoice_input(bad[:])))
  }
  let huge : Array[@jieheng.ChargeInput] = []
  for i in 0..<64 {
    let item = invoice_input("metric-\{i}", "999999999999999999999999999999")
    huge.push({
      ..item,
      usage: { ..item.usage, quantity: "999999999999999999999999999999", },
    })
  }
  rejected(() => {
    ignore(@jieheng.rate_invoice(huge[:], scale=2, rounding=HalfEven))
  })
  let good = @jieheng.rate_invoice([first, second], scale=2, rounding=HalfEven)
  assert_eq(good.amount, "2.00")
}

///|
test "invoice strict nested transport roundtrips recovery and input detachment" {
  let items = [
    invoice_input("api", "0.004", minimum="0.005"),
    invoice_input("storage", "0.006"),
  ]
  let encoded = @jieheng.encode_invoice_input(items[:])
  let decoded = @jieheng.decode_invoice_input(encoded)
  assert_eq(@jieheng.encode_invoice_input(decoded[:]), encoded)
  let bill = @jieheng.rate_invoice(items[:], scale=2, rounding=HalfEven)
  assert_eq(@jieheng.rate_invoice(decoded[:], scale=2, rounding=HalfEven), bill)
  for
    bad in [
      "{}",
      "null",
      "[",
      encoded.replace(
        old="jieheng.invoice-input.v1",
        new="jieheng.invoice-input.v2",
      ),
      encoded.replace(old="\"items\":[", new="\"tax\":0,\"items\":["),
      encoded.replace(
        old="\"minimum\":\"0.005\"",
        new="\"minimum\":\"0.005\",\"minimum\":\"0\"",
      ),
      encoded.replace(
        old="\"unit_price\":\"0.006\"",
        new="\"unit_price\":\"0.006\",\"fixed_fee\":\"1\"",
      ),
    ] {
    rejected(() => ignore(@jieheng.decode_invoice_input(bad)))
  }
  let text = @jieheng.encode_invoice(bill)
  for
    bad in [
      "{}",
      "null",
      text.replace(old="jieheng.invoice.v1", new="jieheng.invoice.v2"),
      text.replace(old="\"charges\":[", new="\"tax\":0,\"charges\":["),
      text.replace(old="\"scale\":2", new="\"scale\":2,\"scale\":3"),
      text.replace(old="\"scale\":2", new="\"scale\":2.5"),
      text.replace(old="\"zero_usage\":\"waive\"", new="\"zero_usage\":null"),
    ] {
    rejected(() => ignore(@jieheng.decode_invoice(bad)))
  }
  assert_eq(@jieheng.decode_invoice(text), bill)
  items[0] = items[1]
  assert_eq(@jieheng.encode_invoice(bill), text)
  @jieheng.verify_invoice(decoded[:], bill, scale=2, rounding=HalfEven)
}
