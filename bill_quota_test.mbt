///|
fn bill_quota_input(
  tariff : @jieheng.Tariff,
  budget : String,
) -> @jieheng.BillQuotaInput raise @jieheng.PricingError {
  let c = invoice_input("storage", "0.004")
  {
    fixed: [Metered({ ..c, usage: { ..c.usage, period: "2026-10", }, })],
    variable: tariff,
    request: budget_request(budget),
  }
}

///|
fn bill_forward(
  input : @jieheng.BillQuotaInput,
  q : Int32,
  scale~ : Int32,
  rounding~ : @jieheng.Rounding,
) -> @jieheng.Bill raise @jieheng.PricingError {
  let u : @jieheng.Usage = {
    customer: input.request.customer,
    period: input.request.period,
    metric: "calls",
    quantity: q.to_string(),
  }
  let item : @jieheng.BillItem = match input.variable {
    MeteredTariff(p, minimum, zero_usage) =>
      Metered({ plan: p, usage: u, minimum, zero_usage, })
    PackageTariff(p) => Packaged(p, u)
  }
  @jieheng.rate_bill((input.fixed + [item])[:], scale~, rounding~)
}

///|
test "bill quota agrees with exhaustive first-failure billing across contracts" {
  let tariffs : Array[@jieheng.Tariff] = [
    MeteredTariff(curve_plan(Graduated), "0.005", Charge),
    MeteredTariff(curve_plan(Graduated), "0.005", Waive),
    MeteredTariff(curve_plan(Volume, shifted=true), "0.005", Charge),
    MeteredTariff(curve_plan(Volume, shifted=true), "0.005", Waive),
    PackageTariff(pack("5")),
  ]
  for tariff in tariffs {
    for scale in [0, 2, 18] {
      for rounding in [@jieheng.HalfEven, HalfUp, Down, Up] {
        for budget in ["0", "0.005", "0.01", "0.019", "0.02", "0.04"] {
          let input = bill_quota_input(tariff, budget)
          if reference_atoms(
              bill_forward(input, 0, scale~, rounding~).totals.amount,
            ) >
            reference_atoms(budget) {
            rejected(() => {
              ignore(@jieheng.quote_bill_quota(input, scale~, rounding~))
            })
            continue
          }
          let mut expected = 0
          for q in 1..<=30 {
            if reference_atoms(
                bill_forward(input, q, scale~, rounding~).totals.amount,
              ) >
              reference_atoms(budget) {
              break
            }
            expected = q
          }
          let report = @jieheng.quote_bill_quota(input, scale~, rounding~)
          assert_eq(
            report.bill,
            bill_forward(input, expected, scale~, rounding~),
          )
          assert_eq(report.first_unaffordable is None, expected == 30)
          @jieheng.verify_bill_quota(input, report, scale~, rounding~)
          let text = @jieheng.encode_bill_quota(report)
          assert_eq(@jieheng.decode_bill_quota(text), report)
          assert_eq(
            @jieheng.encode_bill_quota(@jieheng.decode_bill_quota(text)),
            text,
          )
          let manifest = @jieheng.encode_bill_quota_input(input)
          let decoded = @jieheng.decode_bill_quota_input(manifest)
          assert_eq(@jieheng.encode_bill_quota_input(decoded), manifest)
        }
      }
    }
  }
}

///|
test "bill quota rejects earlier volume overspend and preserves fixed evidence" {
  let p = @jieheng.compile_plan(
    id="api",
    version="v1",
    metric="calls",
    unit="call",
    currency="USD",
    mode=Volume,
    tiers=[
      { up_to: Some("5"), unit_price: "10", },
      { up_to: Some("10"), unit_price: "1", },
      { up_to: None, unit_price: "20", },
    ],
  )
  let input = bill_quota_input(MeteredTariff(p, "2", Waive), "12")
  let report = @jieheng.quote_bill_quota(input, scale=2, rounding=HalfEven)
  assert_eq(report.bill, bill_forward(input, 1, scale=2, rounding=HalfEven))
  let unsafe_quote = {
    ..report,
    bill: bill_forward(input, 10, scale=2, rounding=HalfEven),
    first_unaffordable: Some(
      bill_forward(input, 11, scale=2, rounding=HalfEven),
    ),
  }
  rejected(() => {
    @jieheng.verify_bill_quota(input, unsafe_quote, scale=2, rounding=HalfEven)
  })
  for
    fake in [
      { ..report, first_unaffordable: None, },
      { ..report, first_unaffordable: Some(report.bill), },
      { ..report, variable_metric: "other", },
      { ..report, request: { ..report.request, budget: "100", }, },
      { ..report, bill: { ..report.bill, items: [report.bill.items[1]], }, },
    ] {
    rejected(() => {
      @jieheng.verify_bill_quota(input, fake, scale=2, rounding=HalfEven)
    })
  }
  @jieheng.verify_bill_quota(input, report, scale=2, rounding=HalfEven)
}

///|
test "bill quota distinguishes infeasible zero usage from zero or capped quotas" {
  let p = priced("0.006")
  let charged : @jieheng.BillQuotaInput = {
    fixed: [],
    variable: MeteredTariff(p, "1", Charge),
    request: budget_request("0", limit="10"),
  }
  rejected(() => {
    ignore(@jieheng.quote_bill_quota(charged, scale=2, rounding=HalfEven))
  })
  let waived = { ..charged, variable: MeteredTariff(p, "1", Waive), }
  let zero = @jieheng.quote_bill_quota(waived, scale=2, rounding=HalfEven)
  assert_eq(zero.bill.totals.amount, "0.00")
  assert_true(zero.first_unaffordable is Some(_))
  let capped = @jieheng.quote_bill_quota(
    { ..waived, request: { ..waived.request, limit: "0", }, },
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(capped.first_unaffordable, None)
  let free : @jieheng.BillQuotaInput = {
    fixed: [],
    variable: PackageTariff(pack("999999999999999999999999999999", price="0")),
    request: budget_request("0", limit="999999999999999999999999999999"),
  }
  let huge = @jieheng.quote_bill_quota(free, scale=18, rounding=Up)
  assert_eq(huge.first_unaffordable, None)
  guard huge.bill.items[0] is PackageCharge(c) else {
    fail("expected package evidence")
  }
  assert_eq(c.usage.quantity, free.request.limit)
  assert_eq(
    @jieheng.encode_bill_quota_input(
      @jieheng.decode_bill_quota_input(@jieheng.encode_bill_quota_input(free)),
    ),
    @jieheng.encode_bill_quota_input(free),
  )
}

///|
test "bill quota rejects conflicting manifests size bounds and unrepresentable witnesses" {
  let input = bill_quota_input(MeteredTariff(priced("1"), "0", Waive), "1")
  let c = invoice_input("calls", "0")
  rejected(() => {
    ignore(
      @jieheng.quote_bill_quota(
        {
          ..input,
          fixed: [Metered({ ..c, usage: { ..c.usage, period: "2026-10", }, })],
        },
        scale=2,
        rounding=HalfEven,
      ),
    )
  })
  rejected(() => {
    ignore(
      @jieheng.quote_bill_quota(
        { ..input, request: { ..input.request, customer: "other", }, },
        scale=2,
        rounding=HalfEven,
      ),
    )
  })
  rejected(() => {
    ignore(@jieheng.quote_bill_quota(input, scale=19, rounding=HalfEven))
  })
  let fixed : Array[@jieheng.BillItem] = []
  for i in 0..<63 {
    let c = invoice_input("metric-\{i}", "0")
    fixed.push(Metered({ ..c, usage: { ..c.usage, period: "2026-10", }, }))
  }
  let bounded = { ..input, fixed, request: { ..input.request, limit: "0", }, }
  assert_eq(
    @jieheng.quote_bill_quota(bounded, scale=2, rounding=HalfEven).bill.items.length(),
    64,
  )
  fixed.push(Metered(invoice_input("overflow", "0")))
  rejected(() => {
    ignore(@jieheng.quote_bill_quota(bounded, scale=2, rounding=HalfEven))
  })
  let huge = "999999999999999999999999999999"
  let c = invoice_input("storage", huge)
  let overflow : @jieheng.BillQuotaInput = {
    fixed: [
      Metered({ ..c, usage: { ..c.usage, period: "2026-10", quantity: huge, }, }),
    ],
    variable: MeteredTariff(priced(huge), "0", Waive),
    request: budget_request("9".repeat(60), limit="10"),
  }
  let diagnostic_path = try {
    ignore(@jieheng.quote_bill_quota(overflow, scale=0, rounding=HalfEven))
    ""
  } catch {
    @jieheng.Invalid(code~, path~, message~) => {
      ignore(code)
      ignore(message)
      path
    }
  }
  assert_true(diagnostic_path.has_prefix("bill_quota.first_unaffordable."))
}

///|
test "bill quota strict nested exchange and recovery" {
  let input = bill_quota_input(PackageTariff(pack("5")), "0.02")
  let text = @jieheng.encode_bill_quota_input(input)
  for
    bad in [
      "{}",
      "null",
      text.replace(
        old="jieheng.bill-quota-input.v1",
        new="jieheng.bill-quota-input.v2",
      ),
      text.replace(old="\"variable\":{", new="\"tax\":0,\"variable\":{"),
      text.replace(
        old="\"kind\":\"package\"",
        new="\"kind\":\"package\",\"minimum\":\"1\"",
      ),
      text.replace(
        old="\"limit\":\"30\"",
        new="\"limit\":\"30\",\"limit\":\"31\"",
      ),
    ] {
    rejected(() => ignore(@jieheng.decode_bill_quota_input(bad)))
  }
  let r = @jieheng.quote_bill_quota(input, scale=2, rounding=HalfEven)
  let encoded = @jieheng.encode_bill_quota(r)
  for
    bad in [
      "{}",
      encoded.replace(old="\"first_unaffordable\":{", new="\"missing\":{"),
      encoded.replace(
        old="\"first_unaffordable\":{",
        new="\"first_unaffordable\":null,\"first_unaffordable\":{",
      ),
    ] {
    rejected(() => ignore(@jieheng.decode_bill_quota(bad)))
  }
  assert_eq(@jieheng.decode_bill_quota(encoded), r)
  @jieheng.verify_bill_quota(input, r, scale=2, rounding=HalfEven)
}
