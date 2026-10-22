///|
fn quota_at(
  p : @jieheng.Plan,
  r : @jieheng.BudgetRequest,
  q : Int32,
) -> @jieheng.QuotaQuote raise @jieheng.PricingError {
  {
    request: r,
    evidence: quote_at(p, r, q.to_string()).evidence,
    first_unaffordable: Some(quote_at(p, r, (q + 1).to_string()).evidence),
  }
}

///|
test "safe quota matches exhaustive first-failure enumeration" {
  for mode in [@jieheng.Graduated, Volume] {
    for shifted in [false, true] {
      let p = curve_plan(mode, shifted~)
      for scale in [0, 2, 3] {
        for rounding in [@jieheng.HalfEven, HalfUp, Down, Up] {
          for mills in [0, 1, 5, 10, 19, 30, 100, 200] {
            let r = budget_request(
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
              let forward = quote_at(p, r, q.to_string(), scale~, rounding~)
              if BigInt::from_string(forward.evidence.settlement.minor_units) >
                BigInt::from_int(allowed) {
                break
              }
              expected = q
            }
            let quote = @jieheng.quote_quota(p, r, scale~, rounding~)
            assert_eq(
              quote.evidence.calculation.usage.quantity,
              expected.to_string(),
            )
            assert_eq(quote.first_unaffordable is None, expected == 30)
            @jieheng.verify_quota(p, r, quote, scale~, rounding~)
            if mode == Graduated {
              assert_eq(
                quote.evidence,
                @jieheng.quote_budget(p, r, scale~, rounding~).evidence,
              )
            }
            let text = @jieheng.encode_quota(quote)
            assert_eq(@jieheng.decode_quota(text), quote)
            assert_eq(@jieheng.encode_quota(@jieheng.decode_quota(text)), text)
          }
        }
      }
    }
  }
}

///|
test "safe quota refuses affordable endpoints that hide earlier volume overspend" {
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
  let quota = @jieheng.quote_quota(p, r, scale=2, rounding=HalfEven)
  assert_eq(quota.evidence.calculation.usage.quantity, "1")
  assert_eq(quota.first_unaffordable.unwrap().calculation.usage.quantity, "2")
  assert_eq(
    @jieheng.quote_budget(p, r, scale=2, rounding=HalfEven).evidence.calculation.usage.quantity,
    "10",
  )
  let unsafe_endpoint = quota_at(p, r, 10)
  // Both endpoint q=10 and witness q=11 have valid amounts; q=2..5 still fail.
  rejected(() => {
    @jieheng.verify_quota(p, r, unsafe_endpoint, scale=2, rounding=HalfEven)
  })
  rejected(() => {
    @jieheng.verify_quota(
      p,
      r,
      { ..quota, first_unaffordable: None, },
      scale=2,
      rounding=HalfEven,
    )
  })
  rejected(() => {
    @jieheng.verify_quota(p, r, quota_at(p, r, 0), scale=2, rounding=HalfEven)
  })
  @jieheng.verify_quota(p, r, quota, scale=2, rounding=HalfEven)
}

///|
test "quota handles rounding ties zero limits huge capacities and last-tier failures" {
  let atom = priced("0.000000000000000001")
  let huge = "999999999999999999999999999999"
  for
    (rounding, expected) in [
      (@jieheng.Down, "999999999999999999"),
      (HalfEven, "500000000000000000"),
      (HalfUp, "499999999999999999"),
      (Up, "0"),
    ] {
    let quote = @jieheng.quote_quota(
      atom,
      budget_request("0", limit=huge),
      scale=0,
      rounding~,
    )
    assert_eq(quote.evidence.calculation.usage.quantity, expected)
    assert_true(quote.first_unaffordable is Some(_))
  }
  let free = priced("0")
  for limit in ["0", huge] {
    let r = budget_request("0", limit~)
    let quote = @jieheng.quote_quota(free, r, scale=18, rounding=Up)
    assert_eq(quote.evidence.calculation.usage.quantity, limit)
    assert_eq(quote.first_unaffordable, None)
    let text = @jieheng.encode_quota(quote)
    assert_eq(@jieheng.decode_quota(text), quote)
    rejected(() => {
      @jieheng.verify_quota(
        free,
        r,
        { ..quote, first_unaffordable: Some(quote.evidence), },
        scale=18,
        rounding=Up,
      )
    })
  }
  let tiers : Array[@jieheng.Tier] = []
  for i in 1..<=1023 {
    tiers.push({ up_to: Some(i.to_string()), unit_price: "0", })
  }
  tiers.push({ up_to: None, unit_price: "1", })
  let p = @jieheng.compile_plan(
    id="api",
    version="v1",
    metric="calls",
    unit="call",
    currency="USD",
    mode=Volume,
    tiers~,
  )
  let r = budget_request("0", limit=huge)
  let quote = @jieheng.quote_quota(p, r, scale=18, rounding=Up)
  assert_eq(quote.evidence.calculation.usage.quantity, "1023")
  assert_eq(
    quote.first_unaffordable.unwrap().calculation.usage.quantity,
    "1024",
  )
}

///|
test "quota verifies trusted identity witness policy and recovery" {
  let p = priced("0.006")
  let r = budget_request("0.01", limit="100")
  let quote = @jieheng.quote_quota(p, r, scale=2, rounding=HalfEven)
  assert_eq(quote.evidence.calculation.usage.quantity, "2")
  for
    fake in [
      { ..quote, first_unaffordable: None, },
      { ..quote, first_unaffordable: Some(quote.evidence), },
      { ..quote, request: { ..r, budget: "0.02", }, },
      quota_at(p, r, 0),
      quota_at(p, r, 1),
      quota_at(p, r, 3),
      quota_at(p, r, 101),
      {
        ..quote,
        evidence: {
          ..quote.evidence,
          calculation: { ..quote.evidence.calculation, total: "0", },
        },
      },
    ] {
    rejected(() => @jieheng.verify_quota(p, r, fake, scale=2, rounding=HalfEven))
  }
  for
    bad in [
      { ..r, budget: "-1", },
      { ..r, limit: "01", },
      { ..r, customer: "", },
    ] {
    rejected(() => {
      ignore(@jieheng.quote_quota(p, bad, scale=2, rounding=HalfEven))
    })
  }
  rejected(() => ignore(@jieheng.quote_quota(p, r, scale=19, rounding=HalfEven)))
  rejected(() => ignore(@jieheng.quote_quota(p, r, scale=-1, rounding=HalfEven)))
  @jieheng.verify_quota(p, r, quote, scale=2, rounding=HalfEven)
}

///|
test "quota strict transport rejects loss of witness and unknown data" {
  let p = priced("0.006")
  let r = budget_request("0.01")
  let quote = @jieheng.quote_quota(p, r, scale=2, rounding=HalfEven)
  let text = @jieheng.encode_quota(quote)
  for
    bad in [
      "{}",
      "null",
      "[",
      text.replace(old="jieheng.quota-quote.v1", new="jieheng.budget-quote.v1"),
      text.replace(old="\"first_unaffordable\":{", new="\"missing\":{"),
      text.replace(
        old="\"first_unaffordable\":{",
        new="\"first_unaffordable\":null,\"first_unaffordable\":{",
      ),
      text.replace(old="\"request\":{", new="\"tax\":0,\"request\":{"),
      text.replace(old="\"scale\":2", new="\"scale\":2,\"unknown\":0"),
    ] {
    rejected(() => ignore(@jieheng.decode_quota(bad)))
  }
  assert_eq(@jieheng.decode_quota(text), quote)
}
