///|
test "daily oracle calendar windows include century leap and year boundaries" {
  assert_eq(calendar_window(0)[2], "2000-02-29")
  assert_eq(calendar_window(1)[2], "1900-03-01")
  assert_eq(calendar_window(2)[4], "2025-01-01")
  assert_eq(calendar_window(3)[2], "2024-02-29")
  let run = run_generated_catalogs(1U, 2).stringify()
  assert_true(run.contains("\"checks\":140"))
  assert_true(run.contains("\"fingerprint\":\"3155616578\""))
}

///|
test "daily migration reference independently detects corrupted coverage and recovers" {
  let input = generate_daily(Generator::{ state: 31U, })
  let b = daily_catalog(input.before, input.dates, "USD")
  let a = daily_catalog(
    input.after,
    input.dates,
    if input.currency_changed {
      "EUR"
    } else {
      "USD"
    },
  )
  let report = @jieheng.audit_catalog_migration(
    b,
    a,
    input.dates[0],
    input.dates[8],
  )
  let ctx = Context::{
    seed: 31U,
    index: 0,
    checks: 0,
    fingerprint: 2166136261U,
  }
  check_daily_report(input, report, ctx)
  let spans = report.spans.copy()
  spans[0] = { ..spans[0], ends_before: spans[0].starts_on, }
  let rejected = try {
    check_daily_report(input, { ..report, spans, }, ctx)
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  check_daily_report(input, report, ctx)
}

///|
test "per-unit replay reference detects forged totals without invoking the verifier" {
  let input = generate_daily(Generator::{ state: 42U, })
  let b = daily_catalog(input.replay_before, input.dates, "USD")
  let a = daily_catalog(input.replay_after, input.dates, "USD")
  let cases = daily_cases(input)
  let report = @jieheng.replay_catalogs(
    b,
    a,
    cases[:],
    scale=input.scale,
    rounding=rounding(input.round),
  )
  let ctx = Context::{
    seed: 42U,
    index: 0,
    checks: 0,
    fingerprint: 2166136261U,
  }
  ignore(check_daily_replay(input, report, ctx))
  let rejected = try {
    ignore(
      check_daily_replay(input, { ..report, baseline_exact: "999999", }, ctx),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  ignore(check_daily_replay(input, report, ctx))
}

///|
test "relative policy reference includes exact fractional thresholds and zero baseline" {
  assert_true(daily_policy_expected([200N], [225N], 25N, Some(12500N)))
  assert_false(daily_policy_expected([200N], [225N], 25N, Some(12499N)))
  assert_false(daily_policy_expected([200N], [225N], 24N, None))
  assert_true(daily_policy_expected([0N], [0N], 0N, Some(0N)))
  assert_false(daily_policy_expected([0N], [1N], 100N, Some(1000000N)))
  assert_true(daily_policy_expected([0N], [1N], 1N, None))
  assert_true(daily_policy_expected([10N], [0N], 0N, Some(0N)))
}

///|
test "observed amount oracle rejects malformed or truncated data" {
  assert_eq(observed_units("-0.125", 3), -125N)
  assert_eq(observed_units(daily_fixed(125N, 3), 3), 125N)
  assert_eq(daily_fixed(1N, 18), "0.000000000000000001")
  for bad in ["1.2.3", "1.", "x", "-", ".1", "1.2345", "1.2x"] {
    let rejected = try {
      ignore(observed_units(bad, 3))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  assert_eq(observed_units("0.001", 3), 1N)
}

///|
test "fractional relative boundary and zero baseline run through the public gate" {
  let input = generate_daily(Generator::{ state: 19U, })
  let base = {
    ..input.replay_before[0],
    metric: 0,
    start: 0,
    end: 8,
    open: false,
    model: 0,
    first: 1000,
    next: 1000,
    minimum: 0,
    waive: true,
  }
  let rules = [base, { ..base, metric: 1, }]
  let changed = rules.map(r => { ..r, first: 1125, next: 1125, })
  let c = {
    ..input,
    replay_before: rules,
    replay_after: changed,
    quantities: [[0, 0], [1, 0], [1, 0], [1, 0]],
    scale: 3,
    round: 0,
  }
  let b = daily_catalog(rules, c.dates, "USD")
  let a = daily_catalog(changed, c.dates, "USD")
  let cases = daily_cases(c)
  let report = @jieheng.replay_catalogs(
    b,
    a,
    cases[:],
    scale=3,
    rounding=HalfEven,
  )
  @jieheng.check_replay_policy(
    b,
    a,
    cases[:],
    report,
    {
      currency: "USD",
      max_increase: "0.125",
      max_increase_percent: Some("12.5"),
    },
    scale=3,
    rounding=HalfEven,
  )
  let ctx = Context::{
    seed: 19U,
    index: 0,
    checks: 0,
    fingerprint: 2166136261U,
  }
  daily_reject(
    ctx,
    () => {
      @jieheng.check_replay_policy(
        b,
        a,
        cases[:],
        report,
        {
          currency: "USD",
          max_increase: "0.125",
          max_increase_percent: Some("12.499"),
        },
        scale=3,
        rounding=HalfEven,
      )
    },
    "fractional-relative-boundary",
  )
  let zero = daily_catalog(
    rules.map(r => { ..r, first: 0, next: 0, }),
    c.dates,
    "USD",
  )
  let zero_report = @jieheng.replay_catalogs(
    zero,
    a,
    cases[:],
    scale=3,
    rounding=HalfEven,
  )
  daily_reject(
    ctx,
    () => {
      @jieheng.check_replay_policy(
        zero,
        a,
        cases[:],
        zero_report,
        {
          currency: "USD",
          max_increase: "10",
          max_increase_percent: Some("1000"),
        },
        scale=3,
        rounding=HalfEven,
      )
    },
    "zero-baseline-relative",
  )
  @jieheng.check_replay_policy(
    zero,
    a,
    cases[:],
    zero_report,
    { currency: "USD", max_increase: "10", max_increase_percent: None, },
    scale=3,
    rounding=HalfEven,
  )
}

///|
test "catalog one-case replay consumes input draws but skips earlier execution" {
  let rng = Generator::{ state: 7U, }
  for _ in 0..<7 {
    ignore(generate_daily(rng))
  }
  let last = generate_daily(rng)
  let ctx = Context::{
    seed: 7U,
    index: 7,
    checks: 0,
    fingerprint: 2166136261U,
  }
  exercise_daily(last, ctx)
  let selected = run_generated_catalogs(7U, 8, only_case=7).stringify()
  assert_true(selected.contains("\"executed_cases\":1"))
  assert_true(selected.contains("\"fingerprint\":\"\{ctx.fingerprint}\""))
  assert_true(selected.contains("\"checks\":\{ctx.checks}"))
  for (count, index) in [(0, None), (4097, None), (2, Some(-1)), (2, Some(2))] {
    let bad = try {
      ignore(run_generated_catalogs(1U, count, only_case?=index))
      false
    } catch {
      _ => true
    }
    assert_true(bad)
  }
  ignore(run_generated_catalogs(0U, 1))
}
