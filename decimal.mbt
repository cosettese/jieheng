///|
// Amounts are BigInt counts of 10^-18 currency units. Never converted to Float.
fn factor() -> BigInt {
  1000000000000000000N
}

///|
fn natural(text : String, path : String) -> BigInt raise PricingError {
  if text.length() == 0 || text.length() > 30 {
    invalid("integer", path, "use 1..30 ASCII digits (maximum 10^30 - 1)")
  }
  if text.length() > 1 && text[0] == '0' {
    invalid("integer", path, "remove leading zeroes")
  }
  for c in text {
    if c < '0' || c > '9' {
      invalid("integer", path, "use a nonnegative decimal integer string")
    }
  }
  BigInt::from_string(text)
}

///|
fn decimal(text : String, path : String) -> BigInt raise PricingError {
  if text.length() == 0 || text.length() > 49 {
    invalid("decimal", path, "use at most 30 integer and 18 fractional digits")
  }
  let parts = text.split(".").collect()
  if parts.length() > 2 {
    invalid(
      "decimal", path, "use plain nonnegative decimal notation, without exponent",
    )
  }
  let whole = natural(parts[0].to_owned(), path)
  let fraction = if parts.length() == 2 {
    let part = parts[1].to_owned()
    if part.length() == 0 || part.length() > 18 {
      invalid("decimal", path, "fraction must contain 1..18 ASCII digits")
    }
    for c in part {
      if c < '0' || c > '9' {
        invalid("decimal", path, "fraction must contain only ASCII digits")
      }
    }
    BigInt::from_string(part + "0".repeat(18 - part.length()))
  } else {
    0N
  }
  whole * factor() + fraction
}

///|
fn format_atoms(atoms : BigInt) -> String {
  if atoms < 0N {
    return "-" + format_atoms(-atoms)
  }
  let whole = (atoms / factor()).to_string()
  let remainder = (atoms % factor()).to_string()
  if atoms % factor() == 0N {
    return whole
  }
  let digits = "0".repeat(18 - remainder.length()) + remainder
  let mut end = digits.length()
  while end > 0 && digits[end - 1] == '0' {
    end -= 1
  }
  whole + "." + digits[:end].to_owned()
}

///|
fn label(text : String, path : String) -> Unit raise PricingError {
  if text.length() == 0 || text.length() > 256 {
    invalid(
      "label", path, "use a nonempty label of at most 256 UTF-16 code units",
    )
  }
  for c in text {
    if c < ' ' || c == '\u007f' {
      invalid("label", path, "control characters are not allowed")
    }
  }
}
