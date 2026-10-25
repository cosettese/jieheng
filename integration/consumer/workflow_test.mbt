///|
fn consumer_items() -> Array[@jieheng.BillItem] raise @jieheng.PricingError {
  // Stripe public teaching prices, with synthetic client/period and message rule.
  let plan = @jieheng.compile_plan(
    id="api",
    version="v1",
    metric="requests",
    unit="request",
    currency="USD",
    tiers=[
      { up_to: Some("5"), unit_price: "7", },
      { up_to: Some("10"), unit_price: "6.5", },
      { up_to: None, unit_price: "6", },
    ],
  )
  let bundle = @jieheng.compile_package(
    id="messages",
    version="v1",
    metric="messages",
    unit="message",
    currency="USD",
    package_size="1000",
    package_price="0.85",
  )
  [
    Metered({
      plan,
      usage: {
        customer: "acme",
        period: "2026-10",
        metric: "requests",
        quantity: "20",
      },
      minimum: "130",
      zero_usage: Charge,
    }),
    Packaged(bundle, {
      customer: "acme",
      period: "2026-10",
      metric: "messages",
      quantity: "2501",
    }),
  ]
}

///|
test "an independent module can archive verify and explain a complete bill using public API" {
  let items = consumer_items()
  let manifest = @jieheng.encode_bill_input(items[:])
  let trusted = @jieheng.decode_bill_input(manifest)
  let bill = @jieheng.rate_bill(trusted[:], scale=2, rounding=HalfEven)
  assert_eq(bill.totals.usage_total, "130.05")
  assert_eq(bill.totals.top_up, "2.5")
  assert_eq(bill.totals.amount, "132.55")
  let archive = @jieheng.encode_bill(bill)
  let restored = @jieheng.decode_bill(archive)
  @jieheng.verify_bill(trusted[:], restored, scale=2, rounding=HalfEven)
  assert_eq(@jieheng.encode_bill(restored), archive)
  let explanation = @jieheng.render_bill_markdown(
    trusted[:],
    restored,
    scale=2,
    rounding=HalfEven,
  )
  assert_true(
    explanation.contains("| 130.05 | 2.5 | 132.55 | 132.55 | 0 | 13255 |"),
  )
  assert_true(explanation.contains("| 1000 | 0.85 | 3 | 499 | 2.55 |"))
  assert_true(explanation.contains(manifest))
  assert_true(explanation.contains(archive))
  let forged = { ..restored, totals: { ..restored.totals, amount: "0.00", }, }
  try {
    ignore(
      @jieheng.render_bill_markdown(
        trusted[:],
        forged,
        scale=2,
        rounding=HalfEven,
      ),
    )
    fail("unverified evidence must not be displayed")
  } catch {
    @jieheng.Invalid(code~, path~, ..) => {
      assert_eq(code, "total")
      assert_eq(path, "bill.totals")
    }
    e => raise e
  }
  assert_eq(
    @jieheng.render_bill_markdown(
      trusted[:],
      restored,
      scale=2,
      rounding=HalfEven,
    ),
    explanation,
  )
}

///|
test "consumer retains sub-minor amounts and handles typed diagnostics without losing a good snapshot" {
  let p = @jieheng.compile_plan(
    id="tiny",
    version="v1",
    metric="calls",
    unit="call",
    currency="USD",
    tiers=[{ up_to: None, unit_price: "0.000000000000000001", }],
  )
  let u : @jieheng.Usage = {
    customer: "acme",
    period: "period",
    metric: "calls",
    quantity: "1",
  }
  let c = @jieheng.rate(p, u)
  assert_eq(c.total, "0.000000000000000001")
  let s = @jieheng.settle(c, scale=2, rounding=Up)
  assert_eq(s.amount, "0.01")
  @jieheng.verify_evidence(
    p,
    u,
    { calculation: c, settlement: s, },
    scale=2,
    rounding=Up,
  )
  try {
    ignore(
      @jieheng.decode_usage(
        @jieheng.encode_usage(u).replace(
          old="\"quantity\":\"1\"",
          new="\"quantity\":1",
        ),
      ),
    )
    fail("must reject a JSON number instead of coercing it")
  } catch {
    @jieheng.Invalid(code~, path~, ..) => {
      assert_eq(code, "type")
      assert_eq(path, "usage.quantity")
    }
    e => raise e
  }
  assert_eq(@jieheng.rate(p, u), c)
}
