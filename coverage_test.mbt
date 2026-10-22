///|
test "coverage clips gaps, merges adjacent coverage and preserves metric order" {
  let e = catalog_entries()
  let c = @jieheng.compile_catalog([
    { ..e[0], starts_on: "2026-10-03", ends_before: Some("2026-10-07"), },
    { ..e[1], starts_on: "2026-10-02", ends_before: Some("2026-10-04"), },
    { ..e[2], starts_on: "2026-10-06", ends_before: Some("2026-10-08"), },
  ])
  let gaps = @jieheng.catalog_gaps(c, "2026-10-01", "2026-10-10")
  assert_eq(gaps, [
    { metric: "calls", starts_on: "2026-10-01", ends_before: "2026-10-03", },
    { metric: "calls", starts_on: "2026-10-07", ends_before: "2026-10-10", },
    { metric: "messages", starts_on: "2026-10-01", ends_before: "2026-10-02", },
    { metric: "messages", starts_on: "2026-10-04", ends_before: "2026-10-06", },
    { metric: "messages", starts_on: "2026-10-08", ends_before: "2026-10-10", },
  ])
  assert_eq(@jieheng.catalog_gaps(c, "2026-10-04", "2026-10-06"), [
    { metric: "messages", starts_on: "2026-10-04", ends_before: "2026-10-06", },
  ])
  let detached = @jieheng.decode_catalog(@jieheng.encode_catalog(c))
  assert_eq(@jieheng.catalog_gaps(detached, "2026-10-01", "2026-10-10"), gaps)
  let complete = @jieheng.compile_catalog(e[:])
  assert_eq(@jieheng.catalog_gaps(complete, "2026-10-01", "9999-12-31"), [])
}

///|
test "coverage agrees with daily selection over every small window" {
  let e = catalog_entries()
  for left in 1..<6 {
    for right in (left + 1)..<8 {
      let date = fn(n : Int32) { "2026-02-0\{n}" }
      let c = @jieheng.compile_catalog([
        { ..e[0], starts_on: date(left), ends_before: Some(date(right)), },
      ])
      for a in 1..<8 {
        for b in (a + 1)..<9 {
          let gaps = @jieheng.catalog_gaps(c, date(a), date(b))
          for d in a..<b {
            let mut uncovered = false
            for g in gaps {
              if g.starts_on <= date(d) && date(d) < g.ends_before {
                uncovered = true
              }
            }
            assert_eq(uncovered, d < left || d >= right)
          }
          assert_true(gaps.length() <= 2)
          for i in 1..<gaps.length() {
            assert_true(gaps[i - 1].ends_before < gaps[i].starts_on)
          }
        }
      }
    }
  }
}

///|
test "coverage validates Gregorian boundaries and recovers without changing catalog" {
  let e = catalog_entries()
  let c = @jieheng.compile_catalog([
    { ..e[0], starts_on: "2000-02-29", ends_before: Some("2000-03-01"), },
  ])
  assert_eq(@jieheng.catalog_gaps(c, "2000-02-28", "2000-03-02"), [
    { metric: "calls", starts_on: "2000-02-28", ends_before: "2000-02-29", },
    { metric: "calls", starts_on: "2000-03-01", ends_before: "2000-03-02", },
  ])
  for
    (a, b) in [
      ("1900-02-29", "2000-03-01"),
      ("0000-01-01", "9999-12-31"),
      ("2026-10-01", "2026-10-01"),
      ("2026-10-02", "2026-10-01"),
      ("2026-10-01T00:00:00Z", "2026-10-03"),
    ] {
    rejected(() => ignore(@jieheng.catalog_gaps(c, a, b)))
  }
  assert_eq(@jieheng.catalog_gaps(c, "2000-02-29", "2000-03-01"), [])
  assert_eq(@jieheng.catalog_gaps(c, "0001-01-01", "0001-01-02"), [
    { metric: "calls", starts_on: "0001-01-01", ends_before: "0001-01-02", },
  ])
}
