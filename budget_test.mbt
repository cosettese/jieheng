///|
fn budget_request(
  budget : String,
  limit~ : String = "30",
) -> @jieheng.BudgetRequest {
  { customer: "acme", period: "2026-10", budget, limit, }
}

///|
fn quote_at(
  p : @jieheng.Plan,
  request : @jieheng.BudgetRequest,
  q : String,
  scale~ : Int32 = 2,
  rounding~ : @jieheng.Rounding = HalfEven,
) -> @jieheng.BudgetQuote raise @jieheng.PricingError {
  let calculation = @jieheng.rate(p, {
    customer: request.customer,
    metric: "calls",
    period: request.period,
    quantity: q,
  })
  {
    request,
    evidence: {
      calculation,
      settlement: @jieheng.settle(calculation, scale~, rounding~),
    },
  }
}

///|
test "budget maximum matches exhaustive enumeration across modes and policies" {
  for mode in [@jieheng.Graduated, Volume] {
    for
      prices in [
        ["0.007", "0.003", "0.009"],
        ["0.01", "0.001", "0"],
        ["0", "0.015", "0.005"],
      ] {
      let p = @jieheng.compile_plan(
        id="api",
        version="v1",
        metric="calls",
        unit="call",
        currency="USD",
        mode~,
        tiers=[
          { up_to: Some("5"), unit_price: prices[0], },
          { up_to: Some("10"), unit_price: prices[1], },
          { up_to: None, unit_price: prices[2], },
        ],
      )
      for rounding in [@jieheng.HalfEven, HalfUp, Down, Up] {
        for scale in [0, 2, 3] {
          // Budgets are thousandths; sum comparisons use small integer minor
          // units from independently enumerated forward calculations.
          for mills in [0, 1, 5, 10, 15, 19, 20, 49, 100, 200] {
            let request = budget_request(
              "0." +
              "0".repeat(3 - mills.to_string().length()) +
              mills.to_string(),
            )
            let allowed = if scale == 0 {
              0
            } else if scale == 2 {
              mills / 10
            } else {
              mills
            }
            let mut expected = 0
            for q in 0..<=30 {
              let forward = quote_at(
                p,
                request,
                q.to_string(),
                scale~,
                rounding~,
              )
              let minor = BigInt::from_string(
                forward.evidence.settlement.minor_units,
              )
              if minor <= BigInt::from_int(allowed) {
                expected = q
              }
            }
            let quote = @jieheng.quote_budget(p, request, scale~, rounding~)
            assert_eq(
              quote.evidence.calculation.usage.quantity,
              expected.to_string(),
            )
            @jieheng.verify_budget(p, request, quote, scale~, rounding~)
            let text = @jieheng.encode_budget(quote)
            assert_eq(@jieheng.decode_budget(text), quote)
            assert_eq(
              @jieheng.encode_budget(@jieheng.decode_budget(text)),
              text,
            )
          }
        }
      }
    }
  }
}

///|
test "budget volume holes do not hide affordable larger quantities" {
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
  let r = budget_request("12", limit="20")
  let quote = @jieheng.quote_budget(p, r, scale=2, rounding=HalfEven)
  assert_eq(quote.evidence.calculation.usage.quantity, "10")
  assert_eq(quote.evidence.settlement.amount, "10.00")
  // q=1 is affordable, q=2..5 are not, then q=6..10 are affordable again.
  let locally_plausible = quote_at(p, r, "1")
  rejected(() => {
    @jieheng.verify_budget(p, r, locally_plausible, scale=2, rounding=HalfEven)
  })
  rejected(() => {
    @jieheng.verify_budget(
      p,
      r,
      quote_at(p, r, "11"),
      scale=2,
      rounding=HalfEven,
    )
  })
  @jieheng.verify_budget(p, r, quote, scale=2, rounding=HalfEven)
}

///|
test "budget ties sub-minor budgets free tails and huge finite limits" {
  let p = priced("0.005")
  for
    (budget, rounding, expected) in [
      ("0", @jieheng.HalfEven, "1"),
      ("0", HalfUp, "0"),
      ("0", Down, "1"),
      ("0", Up, "0"),
      ("0.01", HalfEven, "2"),
      ("0.02", HalfEven, "5"),
      ("0.02", HalfUp, "4"),
      ("0.019", HalfEven, "2"),
    ] {
    let r = budget_request(budget)
    assert_eq(
      @jieheng.quote_budget(p, r, scale=2, rounding~).evidence.calculation.usage.quantity,
      expected,
    )
  }
  let huge = "999999999999999999999999999999"
  let atom = priced("0.000000000000000001")
  let r = budget_request("0.000000000000000005", limit=huge)
  let quote = @jieheng.quote_budget(atom, r, scale=18, rounding=HalfEven)
  assert_eq(quote.evidence.calculation.usage.quantity, "5")
  let free = priced("0")
  for
    (rounding, expected) in [
      (@jieheng.Down, "999999999999999999"),
      (HalfEven, "500000000000000000"),
      (HalfUp, "499999999999999999"),
      (Up, "0"),
    ] {
    assert_eq(
      @jieheng.quote_budget(
        atom,
        budget_request("0", limit=huge),
        scale=0,
        rounding~,
      ).evidence.calculation.usage.quantity,
      expected,
    )
  }
  assert_eq(
    @jieheng.quote_budget(
      free,
      budget_request("0", limit=huge),
      scale=18,
      rounding=Up,
    ).evidence.calculation.usage.quantity,
    huge,
  )
  let zero_limit = @jieheng.quote_budget(
    p,
    budget_request("10", limit="0"),
    scale=0,
    rounding=Up,
  )
  assert_eq(zero_limit.evidence.calculation.usage.quantity, "0")
  let expensive = priced("999999999999999999999999999999.999999999999999999")
  let r = budget_request("0", limit=huge)
  assert_eq(
    @jieheng.quote_budget(expensive, r, scale=0, rounding=Up).evidence.calculation.usage.quantity,
    "0",
  )
}

///|
test "budget rejects nonmaximal feasible quotes and trusted input substitution" {
  let p = priced("0.006")
  let r = budget_request("0.01", limit="100")
  let good = @jieheng.quote_budget(p, r, scale=2, rounding=HalfEven)
  assert_eq(good.evidence.calculation.usage.quantity, "2")
  for
    fake in [
      quote_at(p, r, "0"),
      quote_at(p, r, "1"),
      quote_at(p, r, "3"),
      quote_at(p, r, "101"),
      { ..good, request: { ..r, limit: "101", }, },
      {
        ..good,
        evidence: {
          ..good.evidence,
          calculation: { ..good.evidence.calculation, total: "0", },
        },
      },
    ] {
    rejected(() => {
      @jieheng.verify_budget(p, r, fake, scale=2, rounding=HalfEven)
    })
  }
  for
    bad in [
      { ..r, budget: "-1", },
      { ..r, budget: "1e2", },
      { ..r, budget: "0.", },
      { ..r, budget: "9".repeat(61), },
      { ..r, limit: "01", },
      { ..r, limit: "9".repeat(31), },
      { ..r, customer: "", },
    ] {
    rejected(() => {
      ignore(@jieheng.quote_budget(p, bad, scale=2, rounding=HalfEven))
    })
  }
  rejected(() => {
    ignore(@jieheng.quote_budget(p, r, scale=19, rounding=HalfEven))
  })
  rejected(() => {
    ignore(@jieheng.quote_budget(p, r, scale=-1, rounding=HalfEven))
  })
  @jieheng.verify_budget(p, r, good, scale=2, rounding=HalfEven)
}

///|
test "budget strict formats preserve all request fields and recover" {
  let r = budget_request("0.010")
  let text = @jieheng.encode_budget_request(r)
  assert_eq(@jieheng.decode_budget_request(text), r)
  for
    bad in [
      "{}",
      "null",
      text.replace(old="\"limit\":\"30\"", new="\"limit\":30"),
      text.replace(
        old="\"limit\":\"30\"",
        new="\"limit\":\"30\",\"quantity\":\"1\"",
      ),
      text.replace(
        old="\"limit\":\"30\"",
        new="\"limit\":\"30\",\"limit\":\"31\"",
      ),
    ] {
    rejected(() => ignore(@jieheng.decode_budget_request(bad)))
  }
  let p = priced("0.006")
  let q = @jieheng.quote_budget(p, r, scale=2, rounding=HalfEven)
  let record = @jieheng.encode_budget(q)
  for
    bad in [
      "{}",
      "[",
      record.replace(
        old="jieheng.budget-quote.v1",
        new="jieheng.budget-quote.v2",
      ),
      record.replace(old="\"request\":{", new="\"tax\":0,\"request\":{"),
      record.replace(old="\"scale\":2", new="\"scale\":2,\"scale\":3"),
    ] {
    rejected(() => ignore(@jieheng.decode_budget(bad)))
  }
  assert_eq(@jieheng.decode_budget(record), q)
}

///|
test "budget traverses all supported volume tiers including a free final tier" {
  let tiers : Array[@jieheng.Tier] = []
  for i in 1..<=1023 {
    tiers.push({ up_to: Some(i.to_string()), unit_price: "1", })
  }
  tiers.push({ up_to: None, unit_price: "0", })
  let p = @jieheng.compile_plan(
    id="api",
    version="v1",
    metric="calls",
    unit="call",
    currency="USD",
    mode=Volume,
    tiers~,
  )
  let r = budget_request("0", limit="999999999999999999999999999999")
  let quote = @jieheng.quote_budget(p, r, scale=18, rounding=Up)
  assert_eq(quote.evidence.calculation.usage.quantity, r.limit)
  assert_eq(quote.evidence.calculation.lines[0].tier, 1023)
  rejected(() => {
    @jieheng.verify_budget(
      p,
      r,
      quote_at(p, r, "0", scale=18, rounding=Up),
      scale=18,
      rounding=Up,
    )
  })
}
