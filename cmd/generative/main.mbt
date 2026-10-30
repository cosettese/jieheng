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
  let catalog = args.length() > 1 && args[1] == "catalog"
  let offset = if catalog { 1 } else { 0 }
  if (args.length() != 3 + offset && args.length() != 5 + offset) ||
    (args.length() == 5 + offset && args[3 + offset] != "--case") {
    fail(
      "usage: moon run cmd/generative -- [catalog] SEED COUNT [--case INDEX]",
    )
  }
  let count = number(args[2 + offset])
  if count > 4096U {
    fail("count must be 1..4096")
  }
  let selected = if args.length() == 5 + offset {
    let n = number(args[4 + offset])
    if n > 4095U {
      fail("selected case must be 0..4095")
    }
    Some(n.reinterpret_as_int())
  } else {
    None
  }
  let result = if catalog {
    @checks.run_generated_catalogs(
      number(args[1 + offset]),
      count.reinterpret_as_int(),
      only_case?=selected,
    )
  } else {
    @checks.run_generated(
      number(args[1]),
      count.reinterpret_as_int(),
      only_case?=selected,
    )
  }
  println(result.stringify())
}
