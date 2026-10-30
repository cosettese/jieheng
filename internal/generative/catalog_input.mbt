///|
priv struct DailyRule {
  metric : Int32
  start : Int32
  end : Int32
  open : Bool
  identity : Int32
  version : Int32
  unit : Int32
  model : Int32
  bound : Int32
  first : Int32
  next : Int32
  minimum : Int32
  waive : Bool
  size : Int32
}

///|
priv struct DailyCase {
  dates : Array[String]
  before : Array[DailyRule]
  after : Array[DailyRule]
  currency_changed : Bool
  replay_before : Array[DailyRule]
  replay_after : Array[DailyRule]
  quantities : Array[Array[Int32]]
  scale : Int32
  round : Int32
}

///|
fn calendar_window(index : Int32) -> Array[String] {
  match index {
    0 =>
      [
        "2000-02-27", "2000-02-28", "2000-02-29", "2000-03-01", "2000-03-02", "2000-03-03",
        "2000-03-04", "2000-03-05", "2000-03-06",
      ]
    1 =>
      [
        "1900-02-27", "1900-02-28", "1900-03-01", "1900-03-02", "1900-03-03", "1900-03-04",
        "1900-03-05", "1900-03-06", "1900-03-07",
      ]
    2 =>
      [
        "2024-12-28", "2024-12-29", "2024-12-30", "2024-12-31", "2025-01-01", "2025-01-02",
        "2025-01-03", "2025-01-04", "2025-01-05",
      ]
    _ =>
      [
        "2024-02-27", "2024-02-28", "2024-02-29", "2024-03-01", "2024-03-02", "2024-03-03",
        "2024-03-04", "2024-03-05", "2024-03-06",
      ]
  }
}

///|
fn daily_rules(
  rng : Generator,
  gaps : Bool,
  changed : Bool,
) -> Array[DailyRule] {
  let rules : Array[DailyRule] = []
  for metric in 0..<2 {
    if gaps && metric == 1 && rng.draw(3) == 0 {
      continue
    }
    let identity = if changed { rng.draw(2) } else { 0 }
    let unit = if changed { rng.draw(2) } else { 0 }
    let version = rng.draw(2)
    let mut cursor = 0
    while cursor < 8 {
      if gaps && cursor > 0 && rng.draw(4) == 0 {
        cursor += 1
        continue
      }
      let end = (cursor + 1 + rng.draw(3)).min(8)
      rules.push({
        metric,
        start: cursor,
        end,
        open: end == 8 && rng.draw(2) == 1,
        identity,
        version,
        unit,
        model: rng.draw(3),
        bound: 1 + rng.draw(5),
        first: rng.draw(100),
        next: rng.draw(100),
        minimum: rng.draw(100),
        waive: rng.draw(2) == 0,
        size: 1 + rng.draw(5),
      })
      cursor = end
    }
  }
  rules
}

///|
fn generate_daily(rng : Generator) -> DailyCase {
  let dates = calendar_window(rng.draw(4))
  let before = daily_rules(rng, true, false)
  let after = daily_rules(rng, true, true)
  let currency_changed = rng.draw(4) == 0
  let replay_before = daily_rules(rng, false, false)
  let replay_after = daily_rules(rng, false, false)
  let quantities = Array::makei(4, i => {
    if i == 0 {
      [0, 0]
    } else {
      [rng.draw(21), rng.draw(21)]
    }
  })
  {
    dates,
    before,
    after,
    currency_changed,
    replay_before,
    replay_after,
    quantities,
    scale: [0, 1, 2, 3, 18][rng.draw(5)],
    round: rng.draw(4),
  }
}

///|
fn daily_assert(c : Context, condition : Bool, phase : String) -> Unit raise {
  c.checks += 1
  if !condition {
    fail(
      "catalog seed=\{c.seed} case=\{c.index} phase=\{phase}; replay: moon run cmd/generative -- catalog \{c.seed} \{c.index+1} --case \{c.index}",
    )
  }
}

///|
fn daily_reject(
  c : Context,
  action : () -> Unit raise @jieheng.PricingError,
  phase : String,
) -> Unit raise {
  let rejected = try {
    action()
    false
  } catch {
    @jieheng.Invalid(..) => true
  }
  daily_assert(c, rejected, phase)
}

///|
fn daily_catalog(
  rules : Array[DailyRule],
  dates : Array[String],
  currency : String,
) -> @jieheng.Catalog raise @jieheng.PricingError {
  let entries : Array[@jieheng.CatalogEntry] = []
  for r in rules {
    let metric = "metric-\{r.metric}"
    let id = "id-\{r.metric}-\{r.identity}"
    let version = "v-\{r.start}-\{r.version}"
    let unit = "unit-\{r.metric}-\{r.unit}"
    let tariff : @jieheng.Tariff = if r.model == 2 {
      PackageTariff(
        @jieheng.compile_package(
          id~,
          version~,
          metric~,
          unit~,
          currency~,
          package_size=r.size.to_string(),
          package_price=money(r.first),
        ),
      )
    } else {
      MeteredTariff(
        @jieheng.compile_plan(
          id~,
          version~,
          metric~,
          unit~,
          currency~,
          mode=if r.model == 0 { Graduated } else { Volume },
          tiers=[
            { up_to: Some(r.bound.to_string()), unit_price: money(r.first), },
            { up_to: None, unit_price: money(r.next), },
          ],
        ),
        money(r.minimum),
        if r.waive {
          Waive
        } else {
          Charge
        },
      )
    }
    entries.push({
      starts_on: dates[r.start],
      ends_before: if r.open {
        None
      } else {
        Some(dates[r.end])
      },
      tariff,
    })
  }
  @jieheng.compile_catalog(entries[:])
}

///|
// Selection uses integer day slots, never the producer's calendar or boundary code.
fn daily_select(
  rules : Array[DailyRule],
  metric : Int32,
  day : Int32,
) -> Int32? {
  for i, r in rules {
    if r.metric == metric && r.start <= day && (r.open || day < r.end) {
      return Some(i)
    }
  }
  None
}
