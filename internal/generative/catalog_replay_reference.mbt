///|
fn daily_charge(r : DailyRule, q : Int32) -> Int32 {
  if r.model == 2 {
    let mut capacity = 0
    let mut cost = 0
    while capacity < q {
      capacity += r.size
      cost += r.first
    }
    return cost
  }
  let mut total = 0
  for unit in 1..<=q {
    let selector = if r.model == 1 { q } else { unit }
    total += if selector <= r.bound { r.first } else { r.next }
  }
  if q == 0 && r.waive {
    0
  } else {
    total.max(r.minimum)
  }
}

///|
// Parse generated output into oracle units, without a library decimal helper.
fn observed_units(text : String, scale : Int32) -> BigInt raise {
  let negative = text.has_prefix("-")
  let positive = if negative { text[1:].to_owned() } else { text }
  let parts = positive.split(".").collect()
  let fraction = if parts.length() == 2 { parts[1].to_owned() } else { "" }
  if scale < 0 ||
    scale > 18 ||
    parts.length() > 2 ||
    parts[0].is_empty() ||
    !parts[0].iter().all(c => c >= '0' && c <= '9') ||
    (parts.length() == 2 && fraction.is_empty()) ||
    fraction.length() > scale ||
    !fraction.iter().all(c => c >= '0' && c <= '9') {
    fail("malformed or over-precision observed amount: \{text}")
  }
  let value = BigInt::from_string(parts[0].to_owned()) * pow10(scale) +
    (if fraction.is_empty() {
      0N
    } else {
      BigInt::from_string(fraction) * pow10(scale - fraction.length())
    })
  if negative {
    -value
  } else {
    value
  }
}

///|
fn check_daily_replay(
  input : DailyCase,
  report : @jieheng.CatalogReplay,
  ctx : Context,
) -> (Array[BigInt], Array[BigInt]) raise {
  let before : Array[BigInt] = []
  let after : Array[BigInt] = []
  let mut be = 0
  let mut ae = 0
  let mut bs = 0N
  let mut aset = 0N
  let mut inc = 0
  let mut dec = 0
  let mut same = 0
  let mut maximum = 0N
  let mut at : Int32? = None
  daily_assert(ctx, report.rows.length() == 4, "replay-row-count")
  for row, day in [0, 2, 4, 7] {
    let mut exact_b = 0
    let mut exact_a = 0
    let mut settled_b = 0N
    let mut settled_a = 0N
    for metric in 0..<2 {
      let q = input.quantities[row][metric]
      let b = daily_charge(
        input.replay_before[daily_select(input.replay_before, metric, day).unwrap()],
        q,
      )
      let a = daily_charge(
        input.replay_after[daily_select(input.replay_after, metric, day).unwrap()],
        q,
      )
      exact_b += b
      exact_a += a
      settled_b += minor_units(b, input.scale, input.round)
      settled_a += minor_units(a, input.scale, input.round)
    }
    let r = report.rows[row].comparison
    daily_assert(
      ctx,
      report.rows[row].on == input.dates[day],
      "replay-day-binding",
    )
    daily_assert(
      ctx,
      observed_units(r.baseline.totals.total, 3) == BigInt::from_int(exact_b) &&
      observed_units(r.candidate.totals.total, 3) == BigInt::from_int(exact_a),
      "replay-per-unit-exact",
    )
    daily_assert(
      ctx,
      observed_units(r.baseline.totals.amount, input.scale) == settled_b &&
      observed_units(r.candidate.totals.amount, input.scale) == settled_a,
      "replay-per-item-rounding",
    )
    daily_assert(
      ctx,
      observed_units(r.settled_delta, input.scale) == settled_a - settled_b &&
      observed_units(r.exact_delta, 3) == BigInt::from_int(exact_a - exact_b),
      "replay-row-deltas",
    )
    before.push(settled_b)
    after.push(settled_a)
    be += exact_b
    ae += exact_a
    bs += settled_b
    aset += settled_a
    let delta = settled_a - settled_b
    if delta > 0N {
      inc += 1
    } else if delta < 0N {
      dec += 1
    } else {
      same += 1
    }
    if delta > maximum {
      maximum = delta
      at = Some(row)
    }
  }
  daily_assert(
    ctx,
    observed_units(report.baseline_exact, 3) == BigInt::from_int(be) &&
    observed_units(report.candidate_exact, 3) == BigInt::from_int(ae),
    "replay-exact-aggregate",
  )
  daily_assert(
    ctx,
    observed_units(report.baseline_settled, input.scale) == bs &&
    observed_units(report.candidate_settled, input.scale) == aset &&
    observed_units(report.settled_delta, input.scale) == aset - bs &&
    observed_units(report.exact_delta, 3) == BigInt::from_int(ae - be),
    "replay-settled-aggregate",
  )
  daily_assert(
    ctx,
    report.increased == inc &&
    report.decreased == dec &&
    report.unchanged == same &&
    observed_units(report.max_increase, input.scale) == maximum &&
    report.max_increase_index == at,
    "replay-distribution-and-first-maximum",
  )
  (before, after)
}

///|
fn daily_cases(input : DailyCase) -> Array[@jieheng.CatalogReplayCase] {
  [0, 2, 4, 7].mapi((row, day) => {
    on: input.dates[day],
    usages: Array::makei(2, metric => @jieheng.Usage::{
      customer: "customer-\{row}",
      period: "generated",
      metric: "metric-\{metric}",
      quantity: input.quantities[row][metric].to_string(),
    }),
  })
}

///|
fn daily_policy_expected(
  before : Array[BigInt],
  after : Array[BigInt],
  cap : BigInt,
  percent_mills : BigInt?,
) -> Bool {
  for i, amount in before {
    let delta = after[i] - amount
    if delta > cap ||
      (
        delta > 0N &&
        percent_mills is Some(p) &&
        (amount == 0N || delta * 100000N > amount * p)
      ) {
      return false
    }
  }
  true
}

///|
fn daily_fixed(units : BigInt, scale : Int32) -> String {
  let digits = units.to_string()
  if scale == 0 {
    return digits
  }
  let padded = "0".repeat((scale + 1 - digits.length()).max(0)) + digits
  let cut = padded.length() - scale
  padded[:cut].to_owned() + "." + padded[cut:].to_owned()
}
