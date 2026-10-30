///|
test "xorshift32 stream and bounded run summary stay reproducible" {
  let rng = { state: 1U, }
  assert_eq([rng.draw(100), rng.draw(100), rng.draw(100)], [69, 89, 61])
  let first = run_generated(1U, 4).stringify()
  assert_true(first.contains("\"checks\":1028"))
  assert_true(first.contains("\"fingerprint\":\"1644184956\""))
  assert_eq(run_generated(1U, 4).stringify(), first)
}

///|
test "one-case replay is independent of earlier case execution" {
  let selected = run_generated(1U, 4, only_case=3).stringify()
  assert_true(selected.contains("\"executed_cases\":1"))
  assert_true(selected.contains("\"checks\":257"))
  assert_eq(run_generated(1U, 4, only_case=3).stringify(), selected)
  let zero = run_generated(0U, 2).stringify()
  assert_true(zero.contains("\"result\":\"passed\""))
}

///|
test "invalid generator bounds fail and a valid run still recovers" {
  for (count, index) in [(0, None), (4097, None), (2, Some(2)), (2, Some(-1))] {
    let rejected = try {
      ignore(run_generated(1U, count, only_case?=index))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  assert_true(
    run_generated(42U, 1).stringify().contains("\"result\":\"passed\""),
  )
}
