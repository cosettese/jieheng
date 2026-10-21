///|
fn timeline() -> @jieheng.Schedule raise @jieheng.PricingError {
  @jieheng.compile_schedule([
    {
      starts_on: "2024-02-01",
      ends_before: Some("2024-03-01"),
      plan: priced("1"),
    },
    {
      starts_on: "2024-03-01",
      ends_before: Some("2024-04-01"),
      plan: priced("2", version="v2"),
    },
    {
      starts_on: "2024-05-01",
      ends_before: None,
      plan: priced("3", version="v3"),
    },
  ])
}

///|
test "schedule selects exact boundaries gaps leap days and historical evidence" {
  let s = timeline()
  for
    (on, amount) in [
      ("2024-02-01", "1.00"),
      ("2024-02-29", "1.00"),
      ("2024-03-01", "2.00"),
      ("2024-03-31", "2.00"),
      ("2024-05-01", "3.00"),
      ("9999-12-31", "3.00"),
    ] {
    let record = @jieheng.rate_scheduled(
      s,
      on,
      usage("1"),
      scale=2,
      rounding=HalfEven,
    )
    assert_eq(record.evidence.settlement.amount, amount)
    @jieheng.verify_scheduled(
      s,
      on,
      usage("1"),
      record,
      scale=2,
      rounding=HalfEven,
    )
    let text = @jieheng.encode_scheduled(record)
    assert_eq(@jieheng.decode_scheduled(text), record)
    assert_eq(@jieheng.encode_scheduled(@jieheng.decode_scheduled(text)), text)
  }
  for on in ["2024-01-31", "2024-04-01", "2024-04-30"] {
    rejected(() => ignore(@jieheng.select_plan(s, on)))
  }
  let record = @jieheng.rate_scheduled(
    s,
    "2024-02-29",
    usage("1"),
    scale=2,
    rounding=HalfEven,
  )
  rejected(() => {
    @jieheng.verify_scheduled(
      s,
      "2024-03-01",
      usage("1"),
      record,
      scale=2,
      rounding=HalfEven,
    )
  })
  let changed = { ..record, on: "2024-03-01", }
  rejected(() => {
    @jieheng.verify_scheduled(
      s,
      "2024-03-01",
      usage("1"),
      changed,
      scale=2,
      rounding=HalfEven,
    )
  })
  @jieheng.verify_scheduled(
    s,
    "2024-02-29",
    usage("1"),
    record,
    scale=2,
    rounding=HalfEven,
  )
}

///|
test "schedule validates Gregorian dates without locale coercion" {
  let s = timeline()
  for
    bad in [
      "", "0000-01-01", "2023-02-29", "1900-02-29", "2100-02-29", "2024-04-31", "2024-00-01",
      "2024-13-01", "2024-01-00", "2024-01-32", "2024-1-01", "24-01-01", "2024/01/01",
      "2024-０1-01", "2024-01-01Z", "2024-01-01T00:00:00Z",
    ] {
    rejected(() => ignore(@jieheng.select_plan(s, bad)))
    rejected(() => {
      ignore(
        @jieheng.compile_schedule([
          { starts_on: bad, ends_before: None, plan: priced("1"), },
        ]),
      )
    })
  }
  for good in ["0001-01-01", "2000-02-29", "2400-02-29", "9999-12-31"] {
    let timeline = @jieheng.compile_schedule([
      { starts_on: good, ends_before: None, plan: priced("1"), },
    ])
    assert_eq(
      @jieheng.encode_plan(@jieheng.select_plan(timeline, good)),
      @jieheng.encode_plan(priced("1")),
    )
  }
}

///|
test "schedule rejects ambiguity identity changes and retains detached inputs" {
  let first : @jieheng.EffectivePlan = {
    starts_on: "2024-01-01",
    ends_before: Some("2024-02-01"),
    plan: priced("1"),
  }
  let second : @jieheng.EffectivePlan = {
    starts_on: "2024-02-01",
    ends_before: None,
    plan: priced("2", version="v2"),
  }
  let other = @jieheng.compile_plan(
    id="other",
    version="v2",
    metric="calls",
    unit="call",
    currency="USD",
    tiers=[{ up_to: None, unit_price: "1", }],
  )
  for
    bad in [
      [],
      [second, first],
      [first, { ..second, starts_on: "2024-01-31", }],
      [{ ..first, ends_before: None, }, second],
      [{ ..first, ends_before: Some("2024-01-01"), }],
      [first, { ..second, plan: priced("2"), }],
      [first, { ..second, plan: other, }],
    ] {
    rejected(() => ignore(@jieheng.compile_schedule(bad[:])))
  }
  let entries = [first, second]
  let schedule = @jieheng.compile_schedule(entries[:])
  let text = @jieheng.encode_schedule(schedule)
  entries[0] = second
  assert_eq(@jieheng.encode_schedule(schedule), text)
  assert_eq(@jieheng.encode_schedule(@jieheng.decode_schedule(text)), text)
  let many : Array[@jieheng.EffectivePlan] = []
  for i in 1..<=129 {
    let year = "0".repeat(4 - i.to_string().length()) + i.to_string()
    let next = (i + 1).to_string()
    many.push({
      starts_on: year + "-01-01",
      ends_before: Some("0".repeat(4 - next.length()) + next + "-01-01"),
      plan: priced("1", version=i.to_string()),
    })
  }
  ignore(@jieheng.compile_schedule(many[:128]))
  rejected(() => ignore(@jieheng.compile_schedule(many[:])))
}

///|
test "schedule strict nested transport and recovery" {
  let s = timeline()
  let text = @jieheng.encode_schedule(s)
  for
    bad in [
      "{}",
      "null",
      "[",
      text.replace(old="jieheng.schedule.v1", new="jieheng.schedule.v2"),
      text.replace(
        old="\"entries\":[",
        new="\"timezone\":\"UTC\",\"entries\":[",
      ),
      text.replace(
        old="\"starts_on\":\"2024-02-01\"",
        new="\"starts_on\":\"2024-02-01\",\"starts_on\":\"2024-02-02\"",
      ),
      text.replace(old="\"ends_before\":null", new="\"ends_before\":123"),
      text.replace(
        old="\"unit_price\":\"1\"",
        new="\"unit_price\":\"1\",\"tax\":0",
      ),
    ] {
    rejected(() => ignore(@jieheng.decode_schedule(bad)))
  }
  let r = @jieheng.rate_scheduled(
    s,
    "2024-02-29",
    usage("1"),
    scale=2,
    rounding=HalfEven,
  )
  let record = @jieheng.encode_scheduled(r)
  for
    bad in [
      "{}",
      record.replace(old="\"on\":\"2024-02-29\"", new="\"on\":\"2023-02-29\""),
      record.replace(
        old="\"on\":\"2024-02-29\"",
        new="\"on\":\"2024-02-29\",\"prorate\":true",
      ),
    ] {
    rejected(() => ignore(@jieheng.decode_scheduled(bad)))
  }
  assert_eq(@jieheng.encode_schedule(@jieheng.decode_schedule(text)), text)
}
