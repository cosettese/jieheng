///|
/// Gregorian dates: inclusive start, exclusive optional end.
pub(all) struct EffectivePlan {
  starts_on : String
  ends_before : String?
  plan : Plan
}

///|
priv struct CompiledPeriod {
  start : Int32
  end : Int32?
  entry : EffectivePlan
}

///|
/// Validated, detached timeline for one plan identity, metric, unit and currency.
pub struct Schedule {
  priv periods : Array[CompiledPeriod]
}

///|
pub(all) struct ScheduledEvidence {
  on : String
  evidence : Evidence
} derive(Debug, Eq)

///|
pub extend ScheduledEvidence with Debug::{to_repr}

///|
pub extend ScheduledEvidence with Eq::{equal, not_equal}

///|
fn date_key(text : String, path : String) -> Int32 raise PricingError {
  if text.length() != 10 || text[4] != '-' || text[7] != '-' {
    invalid(
      "date", path, "expected a Gregorian date YYYY-MM-DD, years 0001..9999; timestamps and time zones are unsupported",
    )
  }
  let mut y = 0
  let mut m = 0
  let mut d = 0
  for i in 0..<10 {
    if i == 4 || i == 7 {
      continue
    }
    let c = text[i]
    if c < '0' || c > '9' {
      invalid("date", path, "date must contain ASCII digits and hyphens")
    }
    let n = c.to_int() - 48
    if i < 4 {
      y = y * 10 + n
    } else if i < 7 {
      m = m * 10 + n
    } else {
      d = d * 10 + n
    }
  }
  if y == 0 || m < 1 || m > 12 {
    invalid("date", path, "year or month is outside the supported range")
  }
  let leap = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)
  let days = if m == 2 {
    if leap {
      29
    } else {
      28
    }
  } else if [4, 6, 9, 11].contains(m) {
    30
  } else {
    31
  }
  if d < 1 || d > days {
    invalid("date", path, "day does not exist in this Gregorian month")
  }
  y * 10000 + m * 100 + d
}

///|
/// Require ordered nonoverlapping intervals and unique versions. Gaps are
/// allowed but selecting a date inside a gap fails rather than choosing a fallback.
pub fn compile_schedule(
  entries : ArrayView[EffectivePlan],
) -> Schedule raise PricingError {
  if entries.length() == 0 || entries.length() > 128 {
    invalid("size", "schedule.entries", "provide 1 to 128 effective plans")
  }
  let first = entries[0].plan
  let periods : Array[CompiledPeriod] = []
  let versions : Map[String, Unit] = Map([])
  for i, entry in entries {
    let path = "schedule.entries[\{i}]"
    let start = date_key(entry.starts_on, path + ".starts_on")
    let end = entry.ends_before.map(text => {
      date_key(text, path + ".ends_before")
    })
    if end is Some(n) && n <= start {
      invalid("interval", path, "end must be strictly after start")
    }
    if i > 0 {
      let previous = periods[i - 1]
      if start <= previous.start ||
        previous.end is None ||
        (previous.end is Some(n) && start < n) {
        invalid(
          "overlap", path, "intervals must be ordered, disjoint, and only the final end may be null",
        )
      }
    }
    let p = entry.plan
    if p.id != first.id ||
      p.metric != first.metric ||
      p.unit != first.unit ||
      p.currency != first.currency {
      invalid(
        "identity",
        path + ".plan",
        "all versions must share plan id, metric, unit and currency",
      )
    }
    if versions.contains(p.version) {
      invalid(
        "duplicate",
        path + ".plan.version",
        "each price version must have one unique interval",
      )
    }
    versions[p.version] = ()
    periods.push({ start, end, entry, })
  }
  { periods, }
}

///|
/// Select exactly one version by an explicit civil date; usage.period is opaque.
pub fn select_plan(schedule : Schedule, on : String) -> Plan raise PricingError {
  let day = date_key(on, "schedule.on")
  for period in schedule.periods {
    if day >= period.start &&
      (period.end is None || (period.end is Some(n) && day < n)) {
      return period.entry.plan
    }
  }
  invalid(
    "uncovered", "schedule.on", "no price version covers this date; supply an explicit interval instead of assuming the nearest version",
  )
  schedule.periods[0].entry.plan
}

///|
/// Rate one already aggregated snapshot under the selected version.
///
/// ```mbt check
/// test {
///   let p = @jieheng.compile_plan(
///     id="api",
///     version="v1",
///     metric="calls",
///     unit="call",
///     currency="USD",
///     tiers=[{ up_to: None, unit_price: "1", }],
///   )
///   let s = @jieheng.compile_schedule([
///     { starts_on: "2026-10-01", ends_before: None, plan: p, },
///   ])
///   let e = @jieheng.rate_scheduled(
///     s,
///     "2026-10-22",
///     { customer: "acme", metric: "calls", period: "October", quantity: "2", },
///     scale=2,
///     rounding=HalfEven,
///   )
///   inspect(e.evidence.settlement.amount, content="2.00")
/// }
/// ```
pub fn rate_scheduled(
  schedule : Schedule,
  on : String,
  usage : Usage,
  scale~ : Int32,
  rounding~ : Rounding,
) -> ScheduledEvidence raise PricingError {
  let plan = select_plan(schedule, on)
  let calculation = rate(plan, usage)
  {
    on,
    evidence: {
      calculation,
      settlement: settle(calculation, scale~, rounding~),
    },
  }
}

///|
pub fn verify_scheduled(
  schedule : Schedule,
  on : String,
  usage : Usage,
  record : ScheduledEvidence,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  let plan = select_plan(schedule, on)
  if record.on != on {
    invalid(
      "identity", "scheduled.on", "date must match the trusted pricing date",
    )
  }
  verify_evidence(plan, usage, record.evidence, scale~, rounding~)
}
