///|
/// Verify a supplied breakdown against trusted plan and usage snapshots.
/// Does not invoke rate(): checks a contiguous partition, per-tier products,
/// and conservation of the exact quantity and amount independently.
pub fn verify_calculation(
  plan : Plan,
  usage : Usage,
  calculation : Calculation,
) -> Unit raise PricingError {
  let quantity = validate_usage(plan, usage)
  if calculation.plan_id != plan.id ||
    calculation.plan_version != plan.version ||
    calculation.currency != plan.currency ||
    calculation.unit != plan.unit ||
    calculation.usage != usage {
    invalid(
      "identity", "calculation", "plan, version, currency, unit and usage must match trusted inputs",
    )
  }
  if plan.mode == Volume {
    verify_volume(plan, quantity, calculation)
    return
  }
  if calculation.lines.length() > plan.tiers.length() {
    invalid("partition", "calculation.lines", "more lines than price tiers")
  }
  let mut covered = 0N
  let mut sum = 0N
  for i, line in calculation.lines {
    let path = "calculation.lines[\{i}]"
    let tier = plan.tiers[i]
    let lower = natural(line.from_exclusive, path + ".from_exclusive")
    let upper = natural(line.to_inclusive, path + ".to_inclusive")
    let count = natural(line.quantity, path + ".quantity")
    if line.tier != i ||
      lower != covered ||
      count == 0N ||
      upper - lower != count ||
      upper > quantity {
      invalid(
        "partition", path, "lines must be ordered, contiguous, positive and cover the trusted quantity exactly once",
      )
    }
    match tier.up_to {
      Some(bound) =>
        if upper > bound ||
          (i + 1 < calculation.lines.length() && upper != bound) {
          invalid(
            "boundary", path, "finish the current tier before entering the next tier",
          )
        }
      None =>
        if i + 1 < calculation.lines.length() {
          invalid("boundary", path, "no lines may follow an unbounded tier")
        }
    }
    if line.unit_price != format_atoms(tier.price) {
      invalid(
        "price",
        path + ".unit_price",
        "price must match the canonical price from the trusted plan",
      )
    }
    let product = count * tier.price
    if line.subtotal != format_atoms(product) {
      invalid(
        "subtotal",
        path + ".subtotal",
        "expected exact quantity multiplied by unit price",
      )
    }
    covered = upper
    sum += product
  }
  if covered != quantity {
    invalid(
      "coverage", "calculation.lines", "missing usage units or extra lines for zero usage",
    )
  }
  if calculation.total != format_atoms(sum) {
    invalid(
      "total", "calculation.total", "expected the exact sum of all tier subtotals",
    )
  }
}

///|
/// Verify arithmetic and an explicitly trusted settlement policy.
/// This checker uses rounding error intervals and tie parity, not settle().
pub fn verify_settlement(
  calculation : Calculation,
  settlement : Settlement,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Unit raise PricingError {
  if scale < 0 || scale > 18 {
    invalid(
      "scale", "settlement.scale", "choose a trusted scale between 0 and 18",
    )
  }
  if settlement.currency != calculation.currency ||
    settlement.scale != scale ||
    settlement.rounding != rounding {
    invalid(
      "policy", "settlement", "currency, scale and rounding must match the trusted policy",
    )
  }
  let units = wide_natural(settlement.minor_units, 78, "settlement.minor_units")
  let step = BigInt::from_string("1" + "0".repeat(18 - scale))
  let total = amount_atoms(calculation.total, "calculation.total")
  let paid = units * step
  let delta = paid - total
  let valid = match rounding {
    Down => delta <= 0N && delta > -step
    Up => delta >= 0N && delta < step
    HalfUp => delta * 2N > -step && delta * 2N <= step
    HalfEven => {
      let twice = delta * 2N
      twice >= -step &&
      twice <= step &&
      ((twice != step && twice != -step) || units % 2N == 0N)
    }
  }
  if !valid {
    invalid(
      "rounding", "settlement.minor_units", "rounded amount violates the requested rounding interval or tie parity",
    )
  }
  if amount_atoms(settlement.amount, "settlement.amount") != paid ||
    settlement.amount != fixed_amount(units, scale) {
    invalid(
      "amount", "settlement.amount", "amount must equal minor_units at the explicit fixed decimal scale",
    )
  }
  if settlement.delta != format_atoms(delta) {
    invalid(
      "delta", "settlement.delta", "expected settled amount minus exact total",
    )
  }
}

///|
fn wide_natural(
  text : String,
  max_digits : Int32,
  path : String,
) -> BigInt raise PricingError {
  if text.length() == 0 ||
    text.length() > max_digits ||
    (text.length() > 1 && text[0] == '0') {
    invalid(
      "integer",
      path,
      "expected a canonical nonnegative integer of at most \{max_digits} digits",
    )
  }
  for c in text {
    if c < '0' || c > '9' {
      invalid("integer", path, "expected ASCII decimal digits")
    }
  }
  BigInt::from_string(text)
}

///|
fn fixed_amount(units : BigInt, scale : Int32) -> String {
  let digits = units.to_string()
  if scale == 0 {
    return digits
  }
  let padded = "0".repeat(
      if digits.length() <= scale {
        scale + 1 - digits.length()
      } else {
        0
      },
    ) +
    digits
  let split = padded.length() - scale
  padded[:split].to_owned() + "." + padded[split:].to_owned()
}
