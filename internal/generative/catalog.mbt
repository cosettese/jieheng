///|
fn exercise_daily(input : DailyCase, ctx : Context) -> Unit raise {
  let before = daily_catalog(input.before, input.dates, "USD")
  let after = daily_catalog(
    input.after,
    input.dates,
    if input.currency_changed {
      "EUR"
    } else {
      "USD"
    },
  )
  let report = @jieheng.audit_catalog_migration(
    before,
    after,
    input.dates[0],
    input.dates[8],
  )
  check_daily_report(input, report, ctx)
  @jieheng.verify_catalog_migration(
    before,
    after,
    input.dates[0],
    input.dates[8],
    report,
  )
  let encoded = @jieheng.encode_catalog_migration(report)
  daily_assert(
    ctx,
    @jieheng.decode_catalog_migration(encoded) == report,
    "migration-roundtrip",
  )
  daily_assert(
    ctx,
    @jieheng.audit_catalog_migration(
      before,
      after,
      input.dates[0],
      input.dates[8],
    ) ==
    report,
    "migration-determinism",
  )
  let damaged = report.spans.copy()
  damaged[0] = { ..damaged[0], ends_before: input.dates[0], }
  daily_reject(
    ctx,
    () => {
      @jieheng.verify_catalog_migration(
        before,
        after,
        input.dates[0],
        input.dates[8],
        { ..report, spans: damaged, },
      )
    },
    "migration-malformed-span",
  )
  let b = daily_catalog(input.replay_before, input.dates, "USD")
  let a = daily_catalog(input.replay_after, input.dates, "USD")
  for c in [before, after, b, a] {
    let text = @jieheng.encode_catalog(c)
    daily_assert(
      ctx,
      @jieheng.encode_catalog(@jieheng.decode_catalog(text)) == text,
      "catalog-roundtrip",
    )
  }
  let cases = daily_cases(input)
  let replay = @jieheng.replay_catalogs(
    b,
    a,
    cases[:],
    scale=input.scale,
    rounding=rounding(input.round),
  )
  let (old, candidate) = check_daily_replay(input, replay, ctx)
  @jieheng.verify_catalog_replay(
    b,
    a,
    cases[:],
    replay,
    scale=input.scale,
    rounding=rounding(input.round),
  )
  let saved = @jieheng.encode_catalog_replay(replay)
  daily_assert(
    ctx,
    @jieheng.decode_catalog_replay(saved) == replay,
    "replay-roundtrip",
  )
  for percent in ["0", "0.1", "1", "12.5", "50", "100", "1000"] {
    for cap in ["0", "100"] {
      let expected = daily_policy_expected(
        old,
        candidate,
        observed_units(cap, input.scale),
        Some(observed_units(percent, 3)),
      )
      let passed = try {
        @jieheng.check_replay_policy(
          b,
          a,
          cases[:],
          replay,
          {
            currency: "USD",
            max_increase: cap,
            max_increase_percent: Some(percent),
          },
          scale=input.scale,
          rounding=rounding(input.round),
        )
        true
      } catch {
        @jieheng.Invalid(code~, ..) => {
          if code != "policy" {
            fail("unexpected policy error: \{code}")
          }
          false
        }
      }
      daily_assert(ctx, passed == expected, "absolute-relative-policy-oracle")
    }
  }
  @jieheng.check_replay_policy(
    b,
    a,
    cases[:],
    replay,
    {
      currency: "USD",
      max_increase: replay.max_increase,
      max_increase_percent: None,
    },
    scale=input.scale,
    rounding=rounding(input.round),
  )
  daily_assert(ctx, true, "absolute-cap-equality")
  let maximum = observed_units(replay.max_increase, input.scale)
  if maximum > 0N {
    daily_reject(
      ctx,
      () => {
        @jieheng.check_replay_policy(
          b,
          a,
          cases[:],
          replay,
          {
            currency: "USD",
            max_increase: daily_fixed(maximum - 1N, input.scale),
            max_increase_percent: None,
          },
          scale=input.scale,
          rounding=rounding(input.round),
        )
      },
      "one-minor-unit-below-maximum",
    )
  }
  daily_reject(
    ctx,
    () => {
      @jieheng.verify_catalog_replay(
        b,
        a,
        cases[:],
        { ..replay, increased: replay.increased + 1, },
        scale=input.scale,
        rounding=rounding(input.round),
      )
    },
    "forged-replay-aggregate",
  )
  let missing = cases.copy()
  missing[0] = { ..missing[0], usages: [cases[0].usages[0]], }
  daily_reject(
    ctx,
    () => {
      ignore(
        @jieheng.replay_catalogs(
          b,
          a,
          missing[:],
          scale=input.scale,
          rounding=rounding(input.round),
        ),
      )
    },
    "incomplete-customer-bill",
  )
  daily_reject(
    ctx,
    () => {
      ignore(
        @jieheng.replay_catalogs(
          b,
          a,
          [cases[0], cases[0]],
          scale=input.scale,
          rounding=rounding(input.round),
        ),
      )
    },
    "duplicate-customer-period",
  )
  daily_assert(
    ctx,
    @jieheng.replay_catalogs(
      b,
      a,
      cases[:],
      scale=input.scale,
      rounding=rounding(input.round),
    ) ==
    replay,
    "replay-recovery-and-determinism",
  )
  let overlap = input.replay_before.copy()
  overlap.push(input.replay_before[0])
  daily_reject(
    ctx,
    () => ignore(daily_catalog(overlap, input.dates, "USD")),
    "overlapping-or-duplicate-timeline",
  )
  let invalid_dates = input.dates.copy()
  invalid_dates[0] = "1900-02-29"
  daily_reject(
    ctx,
    () => ignore(daily_catalog(input.replay_before, invalid_dates, "USD")),
    "nonleap-century-date",
  )
  daily_reject(
    ctx,
    () => {
      ignore(
        @jieheng.decode_catalog_replay(
          saved.replace(old="\"schema\":", new="\"unknown\":0,\"schema\":"),
        ),
      )
    },
    "unknown-replay-data",
  )
  daily_reject(
    ctx,
    () => {
      ignore(
        @jieheng.decode_catalog_migration(
          encoded.replace(
            old="\"schema\":",
            new="\"schema\":\"duplicate\",\"schema\":",
          ),
        ),
      )
    },
    "duplicate-migration-key",
  )
  for
    text in [
      @jieheng.encode_catalog(before),
      @jieheng.encode_catalog(after),
      encoded,
      saved,
    ] {
    for char in text.iter() {
      ctx.fingerprint = (ctx.fingerprint ^ char.to_int().reinterpret_as_uint()) *
        16777619U
    }
  }
}

///|
/// Bounded eight-day catalog and complete-bill replay checks with a daily oracle.
pub fn run_generated_catalogs(
  seed : UInt32,
  count : Int32,
  only_case? : Int32,
) -> Json raise {
  if count < 1 ||
    count > 4096 ||
    (only_case is Some(i) && (i < 0 || i >= count)) {
    fail("count must be 1..4096; selected case must be within count")
  }
  let rng = Generator::{ state: if seed == 0U { 2463534242U } else { seed }, }
  let ctx = Context::{ seed, index: 0, checks: 0, fingerprint: 2166136261U, }
  let mut executed = 0
  for i in 0..<count {
    let input = generate_daily(rng)
    if only_case is Some(selected) && i != selected {
      continue
    }
    ctx.index = i
    exercise_daily(input, ctx) catch {
      e =>
        fail(
          "catalog seed=\{seed} case=\{i}: \{e}; replay: moon run cmd/generative -- catalog \{seed} \{i+1} --case \{i}",
        )
    }
    executed += 1
  }
  {
    "schema": "jieheng.generated-catalog.v1",
    "seed": seed.to_string(),
    "requested_cases": count,
    "executed_cases": executed,
    "selected_case": match only_case {
      Some(i) => Json(i)
      None => Json::null()
    },
    "checks": ctx.checks,
    "fingerprint": ctx.fingerprint.to_string(),
    "result": "passed",
  }
}
