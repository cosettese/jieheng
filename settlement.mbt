///|
/// Settle an exact total with an explicit decimal scale and rounding rule.
/// Currency is a label, not an ISO currency database; callers choose the scale.
pub fn settle(
  calculation : Calculation,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Settlement raise PricingError {
  settle_total(calculation.currency, calculation.total, scale~, rounding~)
}

///|
fn settle_total(
  currency : String,
  exact : String,
  scale~ : Int32,
  rounding~ : Rounding,
) -> Settlement raise PricingError {
  if scale < 0 || scale > 18 {
    invalid(
      "scale", "settlement.scale", "choose an explicit scale between 0 and 18",
    )
  }
  // Totals can have up to 60 integer digits, unlike individual unit prices.
  let total = amount_atoms(exact, "calculation.total")
  let divisor = BigInt::from_string("1" + "0".repeat(18 - scale))
  let quotient = total / divisor
  let remainder = total % divisor
  let increase = match rounding {
    Down => false
    Up => remainder != 0N
    HalfUp => remainder * 2N >= divisor
    HalfEven =>
      remainder * 2N > divisor ||
      (remainder * 2N == divisor && quotient % 2N != 0N)
  }
  let units = if increase { quotient + 1N } else { quotient }
  let digits = units.to_string()
  let amount = if scale == 0 {
    digits
  } else {
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
  {
    currency,
    scale,
    rounding,
    minor_units: digits,
    amount,
    delta: format_atoms(units * divisor - total),
  }
}

///|
fn amount_atoms(text : String, path : String) -> BigInt raise PricingError {
  // Keep the normal decimal parser's syntax, but allow larger accumulated totals.
  if text.length() > 80 {
    invalid(
      "amount", path, "amount exceeds 60 integer and 18 fractional digits",
    )
  }
  let parts = text.split(".").collect()
  if parts.length() > 2 || parts[0].length() == 0 || parts[0].length() > 60 {
    invalid("amount", path, "expected a nonnegative exact decimal amount")
  }
  let whole = parts[0].to_owned()
  if whole.length() > 1 && whole[0] == '0' {
    invalid("amount", path, "remove leading zeroes")
  }
  for c in whole {
    if c < '0' || c > '9' {
      invalid("amount", path, "expected ASCII decimal digits")
    }
  }
  let fraction = if parts.length() == 2 {
    decimal("0." + parts[1].to_owned(), path)
  } else {
    0N
  }
  BigInt::from_string(whole) * factor() + fraction
}
