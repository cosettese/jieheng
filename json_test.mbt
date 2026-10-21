///|
fn plan_document() -> String {
  let text =
    #|{"schema":"jieheng.plan.v1","id":"p","version":"v1","metric":"calls","unit":"call","currency":"USD","mode":"graduated","tiers":[{"up_to":"3","unit_price":"0.000"},{"up_to":null,"unit_price":"0.00100"}]}
  text
}

///|
test "canonical plan and usage round trips preserve pricing semantics" {
  let p = @jieheng.decode_plan(plan_document())
  let encoded = @jieheng.encode_plan(p)
  assert_eq(@jieheng.encode_plan(@jieheng.decode_plan(encoded)), encoded)
  assert_true(encoded.contains("0.001"))
  for q in 0..<=40 {
    let u = usage(q.to_string())
    assert_eq(@jieheng.decode_usage(@jieheng.encode_usage(u)), u)
    assert_eq(
      @jieheng.rate(p, u),
      @jieheng.rate(@jieheng.decode_plan(encoded), u),
    )
  }
}

///|
test "unknown unsupported and duplicate fields fail without data loss" {
  for
    text in [
      plan_document().replace(
        old="\"mode\":\"graduated\"",
        new="\"mode\":\"unsupported\"",
      ),
      plan_document().replace(
        old="\"mode\":\"graduated\"",
        new="\"mode\":\"graduated\",\"tax\":0.1",
      ),
      plan_document().replace(
        old="\"unit_price\":\"0.000\"",
        new="\"unit_price\":\"0.000\",\"flat_fee\":\"10\"",
      ),
      plan_document().replace(
        old="\"id\":\"p\"",
        new="\"id\":\"a\",\"id\":\"p\"",
      ),
      plan_document().replace(
        old="\"id\":\"p\"",
        new="\"id\":\"a\",\"\\u0069d\":\"p\"",
      ),
      plan_document().replace(
        old="\"unit_price\":\"0.000\"",
        new="\"unit_price\":\"1\",\"unit_price\":\"0\"",
      ),
      plan_document().replace(
        old="\"schema\":\"jieheng.plan.v1\"",
        new="\"schema\":\"jieheng.plan.v2\"",
      ),
      plan_document().replace(old="\"up_to\":\"3\"", new="\"up_to\":3"),
      plan_document().replace(old="\"version\":\"v1\",", new=""),
      "{}",
      "[]",
      "null",
      "",
      "{",
      "{} {}",
    ] {
    rejected(() => ignore(@jieheng.decode_plan(text)))
  }
  assert_eq(
    @jieheng.rate(@jieheng.decode_plan(plan_document()), usage("4")).total,
    "0.001",
  )
}

///|
test "unicode escapes delimiters and nesting are handled as JSON tokens" {
  let u : @jieheng.Usage = {
    customer: "引号\" { : } \\ 😀",
    metric: "calls",
    period: "2026-09",
    quantity: "4",
  }
  assert_eq(@jieheng.decode_usage(@jieheng.encode_usage(u)), u)
  let duplicate =
    #|{"schema":"jieheng.usage.v1","customer":"a","metric":"calls","period":"x","quantity":"1","quantity":"2"}
  let number =
    #|{"schema":"jieheng.usage.v1","customer":"a","metric":"calls","period":"x","quantity":1}
  rejected(() => ignore(@jieheng.decode_usage(duplicate)))
  rejected(() => ignore(@jieheng.decode_usage(number)))
  rejected(() => {
    ignore(@jieheng.decode_plan("[".repeat(40) + "0" + "]".repeat(40)))
  })
  rejected(() => ignore(@jieheng.decode_plan(" ".repeat(1048577))))
}
