///|
priv struct Generator {
  mut state : UInt32
}

///|
fn Generator::draw(self : Generator, bound : Int32) -> Int32 {
  let mut x = self.state
  x = x ^ (x << 13)
  x = x ^ (x >> 17)
  x = x ^ (x << 5)
  self.state = x
  (x % bound.reinterpret_as_uint()).reinterpret_as_int()
}

///|
priv struct GeneratedCase {
  bounds : Array[Int32]
  prices : Array[Int32]
  volume : Bool
  minimum : Int32
  waive : Bool
  scale : Int32
  round : Int32
  budget : Int32
  quantity : Int32
  package_size : Int32
  package_price : Int32
}

///|
fn generate(rng : Generator) -> GeneratedCase {
  let count = 1 + rng.draw(6)
  let bounds : Array[Int32] = []
  let prices : Array[Int32] = []
  let mut edge = 0
  for i in 0..<count {
    if i + 1 < count {
      edge += 1 + rng.draw(7)
      bounds.push(edge)
    }
    prices.push(rng.draw(100))
  }
  {
    bounds,
    prices,
    volume: rng.draw(2) == 1,
    minimum: rng.draw(100),
    waive: rng.draw(2) == 1,
    scale: [0, 1, 2, 3, 18][rng.draw(5)],
    round: rng.draw(4),
    budget: rng.draw(2000),
    quantity: rng.draw(41),
    package_size: 1 + rng.draw(9),
    package_price: rng.draw(100),
  }
}

///|
priv struct Context {
  seed : UInt32
  mut index : Int32
  mut checks : Int32
  mut fingerprint : UInt32
}

///|
fn ensure(c : Context, condition : Bool, phase : String) -> Unit raise {
  c.checks += 1
  if !condition {
    fail(
      "generated failure: seed=\{c.seed} case=\{c.index} phase=\{phase}; replay: moon run cmd/generative -- \{c.seed} \{c.index + 1} --case \{c.index}",
    )
  }
}

///|
// Integer thousandths only: independent of the library's decimal parser.
fn money(mills : Int32) -> String {
  let whole = (mills / 1000).to_string()
  let digits = (mills % 1000).to_string()
  let mut fraction = "0".repeat(3 - digits.length()) + digits
  while fraction.has_suffix("0") {
    fraction = fraction[:fraction.length() - 1].to_owned()
  }
  if fraction.is_empty() {
    whole
  } else {
    whole + "." + fraction
  }
}

///|
// Intentionally enumerate each unit instead of copying tier partition formulas.
fn reference(c : GeneratedCase, q : Int32) -> Int32 {
  if q == 0 {
    return 0
  }
  let mut total = 0
  for unit in 1..<=q {
    let selected = if c.volume { q } else { unit }
    let mut tier = 0
    while tier < c.bounds.length() && selected > c.bounds[tier] {
      tier += 1
    }
    total += c.prices[tier]
  }
  total
}

///|
fn pow10(n : Int32) -> BigInt {
  BigInt::from_string("1" + "0".repeat(n))
}

///|
fn minor_units(mills : Int32, scale : Int32, round : Int32) -> BigInt {
  if scale >= 3 {
    return BigInt::from_int(mills) * pow10(scale - 3)
  }
  let divisor = [1000, 100, 10][scale]
  let whole = mills / divisor
  let remainder = mills % divisor
  let up = match round {
    0 => remainder * 2 > divisor || (remainder * 2 == divisor && whole % 2 == 1)
    1 => remainder * 2 >= divisor
    2 => false
    _ => remainder > 0
  }
  BigInt::from_int(whole + (if up { 1 } else { 0 }))
}

///|
fn rounding(n : Int32) -> @jieheng.Rounding {
  match n {
    0 => HalfEven
    1 => HalfUp
    2 => Down
    _ => Up
  }
}

///|
fn rejection(
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
  ensure(c, rejected, phase)
}

///|
fn exercise(input : GeneratedCase, ctx : Context) -> Unit raise {
  let mode : @jieheng.PricingMode = if input.volume {
    Volume
  } else {
    Graduated
  }
  let tiers : Array[@jieheng.Tier] = input.prices.mapi((i, p) => {
    up_to: if i < input.bounds.length() {
      Some(input.bounds[i].to_string())
    } else {
      None
    },
    unit_price: money(p),
  })
  let p = @jieheng.compile_plan(
    id="generated",
    version="v1",
    metric="calls",
    unit="call",
    currency="USD",
    mode~,
    tiers=tiers[:],
  )
  let encoded_plan = @jieheng.encode_plan(p)
  let restored_plan = @jieheng.decode_plan(encoded_plan)
  ensure(
    ctx,
    @jieheng.encode_plan(restored_plan) == encoded_plan,
    "plan-roundtrip",
  )
  let policy = rounding(input.round)
  let usage = (q : Int32) => @jieheng.Usage::{
    customer: "generated",
    period: "seed-\{ctx.seed}",
    metric: "calls",
    quantity: q.to_string(),
  }
  let mut best = 0
  let mut prefix = 40
  let mut failed_prefix = false
  let available = minor_units(input.budget, input.scale, 2)
  for q in 0..<=40 {
    let expected = reference(input, q)
    ctx.fingerprint = (ctx.fingerprint << 5) ^
      (ctx.fingerprint >> 27) ^
      expected.reinterpret_as_uint()
    let calculation = @jieheng.rate(p, usage(q))
    ensure(ctx, calculation.total == money(expected), "rate-q\{q}")
    ensure(
      ctx,
      @jieheng.rate(restored_plan, usage(q)) == calculation,
      "restored-plan-q\{q}",
    )
    let settled = @jieheng.settle(
      calculation,
      scale=input.scale,
      rounding=policy,
    )
    let units = minor_units(expected, input.scale, input.round)
    ensure(ctx, settled.minor_units == units.to_string(), "rounding-q\{q}")
    let evidence : @jieheng.Evidence = { calculation, settlement: settled, }
    let archive = @jieheng.encode_evidence(evidence)
    let restored = @jieheng.decode_evidence(archive)
    ensure(ctx, restored == evidence, "evidence-roundtrip-q\{q}")
    @jieheng.verify_evidence(
      p,
      usage(q),
      restored,
      scale=input.scale,
      rounding=policy,
    )
    let zero : @jieheng.ZeroUsageMinimum = if input.waive {
      Waive
    } else {
      Charge
    }
    let raw_min = if q == 0 && input.waive { 0 } else { input.minimum }
    let charged = if expected > raw_min { expected } else { raw_min }
    let charge = @jieheng.rate_charge(
      p,
      usage(q),
      minimum=money(input.minimum),
      zero_usage=zero,
      scale=input.scale,
      rounding=policy,
    )
    ensure(ctx, charge.total == money(charged), "minimum-q\{q}")
    ensure(
      ctx,
      charge.settlement.minor_units ==
      minor_units(charged, input.scale, input.round).to_string(),
      "minimum-round-q\{q}",
    )
    if units <= available {
      best = q
    } else if !failed_prefix {
      prefix = q - 1
      failed_prefix = true
    }
  }
  let request : @jieheng.BudgetRequest = {
    customer: "generated",
    period: "seed-\{ctx.seed}",
    budget: money(input.budget),
    limit: "40",
  }
  let budget = @jieheng.quote_budget(
    p,
    request,
    scale=input.scale,
    rounding=policy,
  )
  let quota = @jieheng.quote_quota(
    p,
    request,
    scale=input.scale,
    rounding=policy,
  )
  ensure(
    ctx,
    budget.evidence.calculation.usage.quantity == best.to_string(),
    "budget-global-maximum",
  )
  ensure(
    ctx,
    quota.evidence.calculation.usage.quantity == prefix.to_string(),
    "quota-first-failure",
  )
  @jieheng.verify_budget(p, request, budget, scale=input.scale, rounding=policy)
  @jieheng.verify_quota(p, request, quota, scale=input.scale, rounding=policy)
  let bundle = @jieheng.compile_package(
    id="package",
    version="v1",
    metric="messages",
    unit="message",
    currency="USD",
    package_size=input.package_size.to_string(),
    package_price=money(input.package_price),
  )
  let pu : @jieheng.Usage = { ..usage(input.quantity), metric: "messages", }
  let result = @jieheng.rate_packages(
    bundle,
    pu,
    scale=input.scale,
    rounding=policy,
  )
  let mut packages = 0
  let mut capacity = 0
  while capacity < input.quantity {
    capacity += input.package_size
    packages += 1
  }
  ensure(
    ctx,
    result.packages == packages.to_string() &&
    result.unused_units == (capacity - input.quantity).to_string(),
    "package-minimal-capacity",
  )
  let package_units = minor_units(
    packages * input.package_price,
    input.scale,
    input.round,
  )
  ensure(
    ctx,
    result.settlement.minor_units == package_units.to_string(),
    "package-rounding",
  )
  @jieheng.verify_packages(
    bundle,
    pu,
    result,
    scale=input.scale,
    rounding=policy,
  )
  let items : Array[@jieheng.BillItem] = [
    Metered({
      plan: p,
      usage: usage(input.quantity),
      minimum: money(input.minimum),
      zero_usage: if input.waive {
        Waive
      } else {
        Charge
      },
    }),
    Packaged(bundle, pu),
  ]
  let bill = @jieheng.rate_bill(items[:], scale=input.scale, rounding=policy)
  let raw = reference(input, input.quantity)
  let floor = if input.quantity == 0 && input.waive { 0 } else { input.minimum }
  let charged = if raw > floor { raw } else { floor }
  ensure(
    ctx,
    bill.totals.minor_units ==
    (minor_units(charged, input.scale, input.round) + package_units).to_string(),
    "bill-sum-of-settlements",
  )
  let bill_text = @jieheng.encode_bill(bill)
  ensure(
    ctx,
    @jieheng.encode_bill(@jieheng.decode_bill(bill_text)) == bill_text,
    "bill-roundtrip",
  )
  @jieheng.verify_bill(items[:], bill, scale=input.scale, rounding=policy)
  rejection(
    ctx,
    () => {
      @jieheng.verify_bill(
        items[:],
        { ..bill, totals: { ..bill.totals, amount: "999", }, },
        scale=input.scale,
        rounding=policy,
      )
    },
    "forged-bill",
  )
  rejection(
    ctx,
    () => {
      ignore(
        @jieheng.decode_plan(
          encoded_plan.replace(
            old="\"schema\":",
            new="\"extension\":true,\"schema\":",
          ),
        ),
      )
    },
    "unknown-data",
  )
  rejection(
    ctx,
    () => {
      ignore(
        @jieheng.decode_plan(
          encoded_plan.replace(
            old="\"schema\":",
            new="\"schema\":\"duplicate\",\"schema\":",
          ),
        ),
      )
    },
    "duplicate-key",
  )
  ensure(
    ctx,
    @jieheng.rate_bill(items[:], scale=input.scale, rounding=policy) == bill,
    "recovery",
  )
}

///|
/// Reproducible bounded checks; only_case replays one case after advancing the
/// same generator input stream. It does not depend on earlier successful tests.
pub fn run_generated(
  seed : UInt32,
  count : Int32,
  only_case? : Int32,
) -> Json raise {
  if count < 1 ||
    count > 4096 ||
    (only_case is Some(i) && (i < 0 || i >= count)) {
    fail("count must be 1..4096; selected case must be within count")
  }
  let rng = { state: if seed == 0U { 2463534242U } else { seed }, }
  let ctx = { seed, index: 0, checks: 0, fingerprint: 2166136261U, }
  let mut executed = 0
  for i in 0..<count {
    let c = generate(rng)
    if only_case is Some(n) && i != n {
      continue
    }
    ctx.index = i
    exercise(c, ctx) catch {
      e => fail("seed=\{seed} case=\{i}: \{e}; replay --case \{i}")
    }
    executed += 1
  }
  {
    "schema": "jieheng.generated.v1",
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
