///|
test "verified statement explains mixed contracts without dropping archival data" {
  let items = mixed_items()
  for scale in [0, 2, 18] {
    for rounding in [@jieheng.HalfEven, HalfUp, Down, Up] {
      let bill = @jieheng.rate_bill(items[:], scale~, rounding~)
      let report = @jieheng.render_bill_markdown(
        items[:],
        bill,
        scale~,
        rounding~,
      )
      assert_true(report.contains("Model: graduated"))
      assert_true(report.contains("Model: package"))
      assert_true(report.contains("Minimum: 0.005"))
      assert_true(report.contains("| 5 | 0.006 | 2 | 4 | 0.012 |"))
      assert_true(report.contains(@jieheng.encode_bill_input(items[:])))
      assert_true(report.contains(@jieheng.encode_bill(bill)))
      let blocks = report.split("```json\n").collect()
      assert_eq(blocks.length(), 3)
      let input_text = blocks[1].split("\n```").collect()[0].to_owned()
      let bill_text = blocks[2].split("\n```").collect()[0].to_owned()
      let restored_items = @jieheng.decode_bill_input(input_text)
      let restored_bill = @jieheng.decode_bill(bill_text)
      @jieheng.verify_bill(restored_items[:], restored_bill, scale~, rounding~)
      assert_eq(@jieheng.encode_bill_input(restored_items[:]), input_text)
      assert_eq(@jieheng.encode_bill(restored_bill), bill_text)
      assert_eq(
        @jieheng.render_bill_markdown(items[:], bill, scale~, rounding~),
        report,
      )
      rejected(() => {
        ignore(
          @jieheng.render_bill_markdown(
            items[:],
            { ..bill, totals: { ..bill.totals, amount: "999", }, },
            scale~,
            rounding~,
          ),
        )
      })
      assert_eq(
        @jieheng.render_bill_markdown(items[:], bill, scale~, rounding~),
        report,
      )
    }
  }
}

///|
test "statement escapes label markup and fences arbitrary canonical JSON safely" {
  let name = "中文😀 <script> & | [x](url) ** _ ! # \\ ``` ~~~"
  let p = @jieheng.compile_plan(
    id=name,
    version="````",
    metric=name,
    unit=name,
    currency="USD",
    tiers=[
      { up_to: Some("2"), unit_price: "0", },
      { up_to: None, unit_price: "0.1", },
    ],
  )
  let items : Array[@jieheng.BillItem] = [
    Metered({
      plan: p,
      usage: { customer: name, period: name, metric: name, quantity: "0", },
      minimum: "1",
      zero_usage: Waive,
    }),
  ]
  let bill = @jieheng.rate_bill(items[:], scale=2, rounding=HalfEven)
  let report = @jieheng.render_bill_markdown(
    items[:],
    bill,
    scale=2,
    rounding=HalfEven,
  )
  assert_true(
    report.contains(
      "中文😀 &#60;script&#62; &#38; &#124; &#91;x&#93;(url) &#42;&#42;",
    ),
  )
  assert_true(report.contains("&#96;&#96;&#96;&#96;"))
  assert_true(report.contains("`````json\n"))
  assert_true(report.contains("No occupied tiers at zero usage."))
  assert_true(report.contains("At zero usage: waive"))
  assert_true(report.contains(@jieheng.encode_bill_input(items[:])))
  assert_true(report.contains(@jieheng.encode_bill(bill)))
}

///|
test "statement preserves volume semantics and rejects wrong policy or identity" {
  let p = curve_plan(Volume)
  let items : Array[@jieheng.BillItem] = [
    Metered({ plan: p, usage: usage("4"), minimum: "0", zero_usage: Charge, }),
  ]
  let bill = @jieheng.rate_bill(items[:], scale=2, rounding=HalfEven)
  let report = @jieheng.render_bill_markdown(
    items[:],
    bill,
    scale=2,
    rounding=HalfEven,
  )
  assert_true(report.contains("Model: volume"))
  rejected(() => {
    ignore(
      @jieheng.render_bill_markdown(items[:], bill, scale=2, rounding=Down),
    )
  })
  rejected(() => {
    ignore(
      @jieheng.render_bill_markdown(
        items[:],
        { ..bill, customer: "other", },
        scale=2,
        rounding=HalfEven,
      ),
    )
  })
  rejected(() => {
    ignore(@jieheng.render_bill_markdown([], bill, scale=2, rounding=HalfEven))
  })
}

///|
test "statement refuses contracts too large to preserve instead of omitting unused tiers" {
  let tiers : Array[@jieheng.Tier] = []
  let price = "9".repeat(30) + "." + "9".repeat(18)
  for n in 1..<1024 {
    tiers.push({ up_to: Some(n.to_string()), unit_price: price, })
  }
  tiers.push({ up_to: None, unit_price: price, })
  let items : Array[@jieheng.BillItem] = []
  for n in 0..<16 {
    let metric = "metric-\{n}"
    let p = @jieheng.compile_plan(
      id="api",
      version="v1",
      metric~,
      unit="unit",
      currency="USD",
      tiers=tiers[:],
    )
    items.push(
      Metered({
        plan: p,
        usage: { ..usage("0"), metric, },
        minimum: "0",
        zero_usage: Waive,
      }),
    )
  }
  let bill = @jieheng.rate_bill(items[:], scale=2, rounding=HalfEven)
  try {
    ignore(
      @jieheng.render_bill_markdown(items[:], bill, scale=2, rounding=HalfEven),
    )
    fail("oversized contract must not become an incomplete statement")
  } catch {
    @jieheng.Invalid(code~, path~, message~) => {
      assert_eq(code, "size")
      assert_eq(path, "$")
      assert_true(message.contains("split"))
    }
    e => raise e
  }
}
