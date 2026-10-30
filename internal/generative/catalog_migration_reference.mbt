///|
fn daily_changes(
  input : DailyCase,
  metric : Int32,
  bi : Int32?,
  ai : Int32?,
) -> Array[@jieheng.CatalogChange] {
  let bp = input.before.any(r => r.metric == metric)
  let ap = input.after.any(r => r.metric == metric)
  let out : Array[@jieheng.CatalogChange] = []
  if !bp {
    out.push(MetricAdded)
  }
  if !ap {
    out.push(MetricRemoved)
  }
  if bp && bi is None {
    out.push(BaselineGap)
  }
  if ap && ai is None {
    out.push(CandidateGap)
  }
  if bi is Some(i) && ai is Some(j) {
    let b = input.before[i]
    let a = input.after[j]
    if input.currency_changed {
      out.push(CurrencyChanged)
    }
    if b.unit != a.unit {
      out.push(UnitChanged)
    }
    if b.identity != a.identity {
      out.push(IdentityChanged)
    }
    if b.start != a.start || b.version != a.version {
      out.push(VersionChanged)
    }
    if b.model != 2 && a.model != 2 {
      if b.model != a.model {
        out.push(ModelChanged)
      }
      if b.bound != a.bound || b.first != a.first || b.next != a.next {
        out.push(PricingChanged)
      }
      if b.minimum != a.minimum {
        out.push(MinimumChanged)
      }
      if b.waive != a.waive {
        out.push(ZeroPolicyChanged)
      }
    } else if b.model == 2 && a.model == 2 {
      if b.size != a.size || b.first != a.first {
        out.push(PricingChanged)
      }
    } else {
      out.push(ModelChanged)
    }
  }
  out
}

///|
fn check_daily_report(
  input : DailyCase,
  report : @jieheng.CatalogMigration,
  ctx : Context,
) -> Unit raise {
  let expected : Array[@jieheng.MigrationSpan] = []
  for metric in 0..<2 {
    if !input.before.any(r => r.metric == metric) &&
      !input.after.any(r => r.metric == metric) {
      continue
    }
    let mut day = 0
    while day < 8 {
      let bi = daily_select(input.before, metric, day)
      let ai = daily_select(input.after, metric, day)
      let start = day
      day += 1
      while day < 8 &&
            daily_select(input.before, metric, day) == bi &&
            daily_select(input.after, metric, day) == ai {
        day += 1
      }
      expected.push({
        metric: "metric-\{metric}",
        starts_on: input.dates[start],
        ends_before: input.dates[day],
        baseline_entry: bi,
        candidate_entry: ai,
        changes: daily_changes(input, metric, bi, ai),
      })
    }
  }
  daily_assert(
    ctx,
    report.starts_on == input.dates[0] && report.ends_before == input.dates[8],
    "window",
  )
  daily_assert(
    ctx,
    report.spans == expected,
    "daily-enumerated-spans-and-change-classes",
  )
  for metric in 0..<2 {
    if !input.before.any(r => r.metric == metric) &&
      !input.after.any(r => r.metric == metric) {
      continue
    }
    for day in 0..<8 {
      let covering = report.spans.filter(s => {
        s.metric == "metric-\{metric}" &&
        s.starts_on <= input.dates[day] &&
        input.dates[day] < s.ends_before
      })
      daily_assert(ctx, covering.length() == 1, "exactly-one-span-per-day")
    }
  }
}
