///|
fn number(text : String) -> UInt32 raise {
  if text.is_empty() || text.length() > 10 {
    fail("expected UInt32 decimal")
  }
  let mut value = 0U
  for c in text.iter() {
    if c < '0' || c > '9' {
      fail("expected UInt32 decimal")
    }
    let digit = (c.to_int() - 48).reinterpret_as_uint()
    if value > 429496729U || (value == 429496729U && digit > 5U) {
      fail("UInt32 seed overflow")
    }
    value = value * 10U + digit
  }
  value
}

///|
fn main {
  run_cli() catch {
    e => {
      println("generated error: \{e}")
      abort("generated checks failed")
    }
  }
}

///|
#cfg(target="js")
fn arguments() -> Array[String] {
  let raw = @env.args()
  if raw.is_empty() {
    []
  } else {
    raw[1:].to_owned()
  }
}

///|
#cfg(not(target="js"))
fn arguments() -> Array[String] {
  @env.args()
}

///|
fn run_cli() -> Unit raise {
  let args = arguments()
  if (args.length() != 3 && args.length() != 5) ||
    (args.length() == 5 && args[3] != "--case") {
    fail("usage: moon run cmd/generative -- SEED COUNT [--case INDEX]")
  }
  let count = number(args[2])
  if count > 4096U {
    fail("count must be 1..4096")
  }
  let selected = if args.length() == 5 {
    let n = number(args[4])
    if n > 4095U {
      fail("selected case must be 0..4095")
    }
    Some(n.reinterpret_as_int())
  } else {
    None
  }
  println(
    @checks.run_generated(
      number(args[1]),
      count.reinterpret_as_int(),
      only_case?=selected,
    ).stringify(),
  )
}
