///|
fn mixed_items() -> Array[@jieheng.BillItem] raise @jieheng.PricingError {
  let input = invoice_input("calls", "0.004", minimum="0.005")
  let p = @jieheng.compile_package(
    id="messages",
    version="v1",
    metric="messages",
    unit="message",
    currency="USD",
    package_size="5",
    package_price="0.006",
  )
  [
    Metered(input),
    Packaged(p, { ..input.usage, metric: "messages", quantity: "6", }),
  ]
}

///|
test "mixed bill preserves both kinds and settles each item exactly once" {
  let items = mixed_items()
  let b = @jieheng.rate_bill(items[:], scale=2, rounding=HalfEven)
  assert_eq(b.totals.usage_total, "0.016")
  assert_eq(b.totals.top_up, "0.001")
  assert_eq(b.totals.total, "0.017")
  assert_eq(b.totals.amount, "0.01")
  assert_eq(b.totals.delta, "-0.007")
  guard b.items[1] is PackageCharge(p) else { fail("package evidence missing") }
  assert_eq(p.packages, "2")
  assert_eq(p.unused_units, "4")
  let input = @jieheng.encode_bill_input(items[:])
  let decoded = @jieheng.decode_bill_input(input)
  assert_eq(@jieheng.encode_bill_input(decoded[:]), input)
  assert_eq(@jieheng.rate_bill(decoded[:], scale=2, rounding=HalfEven), b)
  let text = @jieheng.encode_bill(b)
  assert_eq(@jieheng.decode_bill(text), b)
  assert_eq(@jieheng.encode_bill(@jieheng.decode_bill(text)), text)
  for
    fake in [
      { ..b, items: [b.items[1], b.items[0]], },
      { ..b, items: [b.items[0]], },
      { ..b, items: [b.items[0], b.items[0]], },
      { ..b, customer: "other", },
      { ..b, currency: "EUR", },
      { ..b, period: "other", },
      { ..b, totals: { ..b.totals, total: "0", }, },
      {
        ..b,
        totals: {
          ..b.totals,
          amount: "0.02",
          minor_units: "2",
          delta: "0.003",
        },
      },
      { ..b, totals: { ..b.totals, top_up: "0", }, },
      { ..b, totals: { ..b.totals, scale: 3, }, },
    ] {
    rejected(() => {
      @jieheng.verify_bill(items[:], fake, scale=2, rounding=HalfEven)
    })
  }
  @jieheng.verify_bill(items[:], b, scale=2, rounding=HalfEven)
}

///|
test "all metered bills agree with existing invoice without changing old formats" {
  let old = [
    invoice_input("calls", "0.004", minimum="0.005"),
    invoice_input("storage", "0.006"),
  ]
  let items : Array[@jieheng.BillItem] = old.map(c => Metered(c))
  for scale in [0, 2, 18] {
    for rounding in [@jieheng.HalfEven, HalfUp, Down, Up] {
      let invoice = @jieheng.rate_invoice(old[:], scale~, rounding~)
      let b = @jieheng.rate_bill(items[:], scale~, rounding~)
      assert_eq(b.totals.amount, invoice.amount)
      assert_eq(b.totals.total, invoice.total)
      assert_eq(b.totals.delta, invoice.delta)
      @jieheng.verify_bill(items[:], b, scale~, rounding~)
    }
  }
}

///|
test "mixed bill rejects duplicate metrics across models and mixed identities" {
  let metered = invoice_input("calls", "1")
  let p = pack("5")
  let duplicate : Array[@jieheng.BillItem] = [
    Metered(metered),
    Packaged(p, metered.usage),
  ]
  rejected(() => {
    ignore(@jieheng.rate_bill(duplicate[:], scale=2, rounding=HalfEven))
  })
  let mismatched : Array[@jieheng.BillItem] = [
    Metered(metered),
    Packaged(p, { ..metered.usage, customer: "other", }),
  ]
  rejected(() => {
    ignore(@jieheng.rate_bill(mismatched[:], scale=2, rounding=HalfEven))
  })
  rejected(() => ignore(@jieheng.rate_bill([], scale=2, rounding=HalfEven)))
  let many : Array[@jieheng.BillItem] = []
  for i in 0..<64 {
    many.push(Metered(invoice_input("metric-\{i}", "0.006")))
  }
  assert_eq(
    @jieheng.rate_bill(many[:], scale=2, rounding=HalfEven).totals.amount,
    "0.64",
  )
  many.push(Metered(invoice_input("overflow", "1")))
  rejected(() => ignore(@jieheng.rate_bill(many[:], scale=2, rounding=HalfEven)))
}

///|
test "mixed transport rejects unsupported model fields and recovers" {
  let items = mixed_items()
  let input = @jieheng.encode_bill_input(items[:])
  for
    bad in [
      "{}",
      "null",
      input.replace(
        old="\"kind\":\"package\"",
        new="\"kind\":\"package\",\"minimum\":\"10\"",
      ),
      input.replace(old="\"kind\":\"package\"", new="\"kind\":\"unknown\""),
      input.replace(
        old="\"kind\":\"package\"",
        new="\"kind\":\"package\",\"kind\":\"metered\"",
      ),
      input.replace(
        old="\"package_size\":\"5\"",
        new="\"package_size\":\"5\",\"allowance\":1",
      ),
    ] {
    rejected(() => ignore(@jieheng.decode_bill_input(bad)))
  }
  let b = @jieheng.rate_bill(items[:], scale=2, rounding=HalfEven)
  let text = @jieheng.encode_bill(b)
  for
    bad in [
      "{}",
      text.replace(old="jieheng.bill.v1", new="jieheng.bill.v2"),
      text.replace(old="\"kind\":\"package\"", new="\"kind\":\"metered\""),
      text.replace(old="\"totals\":{", new="\"tax\":0,\"totals\":{"),
      text.replace(old="\"scale\":2", new="\"scale\":2,\"scale\":3"),
    ] {
    rejected(() => ignore(@jieheng.decode_bill(bad)))
  }
  assert_eq(@jieheng.decode_bill(text), b)
  @jieheng.verify_bill(items[:], b, scale=2, rounding=HalfEven)
}
