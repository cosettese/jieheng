///|
test "json guards reject excessive nesting before materializing values" {
  for n in [33, 1025, 100000] {
    try {
      ignore(@jieheng.decode_plan("[".repeat(n) + "0" + "]".repeat(n)))
      fail("expected depth rejection")
    } catch {
      @jieheng.Invalid(code~, path~, message~) => {
        assert_eq(code, "depth")
        assert_eq(path, "$")
        assert_true(message.contains("32"))
      }
      e => raise e
    }
  }
}

///|
fn json_diagnostic(text : String) -> String raise {
  try {
    ignore(@jieheng.decode_plan(text))
    fail("expected rejection")
  } catch {
    @jieheng.Invalid(code~, ..) => code
    e => raise e
  }
}

///|
test "JSON limit boundaries and escaped duplicates preserve diagnostics and recovery" {
  for depth in [31, 32, 33] {
    for (open, close) in [("[", "]"), ("{\"x\":", "}")] {
      let input = open.repeat(depth) + "0" + close.repeat(depth)
      assert_eq(
        json_diagnostic(input),
        if depth <= 32 {
          if open == "[" {
            "type"
          } else {
            "unknown"
          }
        } else {
          "depth"
        },
      )
    }
  }
  assert_eq(json_diagnostic(" ".repeat(1048577)), "size")
  assert_eq(json_diagnostic(" ".repeat(1048574) + "{}"), "missing")
  for
    input in [
      "{\"a\":1,\"\\u0061\":2}", "{\"a\":[{\"😀\":1,\"\\uD83D\\uDE00\":2}]}",
    ] {
    assert_eq(json_diagnostic(input), "duplicate")
  }
  assert_eq(json_diagnostic("{\"a\":{\"x\":1},\"b\":{\"x\":2}}"), "unknown")
  for input in ["{", "[}", "{\"x\":", "{\"x\":\"\\uD800\"}"] {
    assert_eq(json_diagnostic(input), "json")
  }
  let u = { ..usage("4"), customer: "[".repeat(100) + "\"\\:{}", }
  assert_eq(@jieheng.decode_usage(@jieheng.encode_usage(u)), u)
  assert_eq(
    @jieheng.rate(@jieheng.decode_plan(plan_document()), usage("4")).total,
    "0.001",
  )
}
