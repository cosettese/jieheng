///|
test "cohort sums separately rounded snapshots and preserves exact differences" {
  let before = priced("0.004")
  let after = priced("0.006", version="v2")
  let usages = [usage("1"), { ..usage("1"), customer: "beta", }]
  let report = @jieheng.compare_cohort(
    before,
    after,
    usages[:],
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(report.baseline_exact, "0.008")
  assert_eq(report.candidate_exact, "0.012")
  assert_eq(report.baseline_settled, "0")
  assert_eq(report.candidate_settled, "0.02")
  assert_eq(report.exact_delta, "0.004")
  assert_eq(report.settled_delta, "0.02")
  let text = @jieheng.encode_cohort(report)
  assert_eq(@jieheng.decode_cohort(text), report)
  assert_eq(@jieheng.encode_cohort(@jieheng.decode_cohort(text)), text)
  let input = @jieheng.encode_cohort_usage(usages[:])
  assert_eq(@jieheng.decode_cohort_usage(input), usages)
  let tampered = [
    { ..report, rows: [report.rows[1], report.rows[0]], },
    { ..report, rows: [report.rows[0]], },
    { ..report, rows: [report.rows[0], report.rows[0]], },
    { ..report, baseline_exact: "0", },
    { ..report, candidate_exact: "0", },
    { ..report, baseline_settled: "0.01", },
    { ..report, candidate_settled: "0.01", },
    { ..report, exact_delta: "0", },
    { ..report, settled_delta: "0", },
  ]
  for fake in tampered {
    rejected(() => {
      @jieheng.verify_cohort(
        before,
        after,
        usages[:],
        fake,
        scale=2,
        rounding=HalfEven,
      )
    })
  }
  @jieheng.verify_cohort(
    before,
    after,
    usages[:],
    report,
    scale=2,
    rounding=HalfEven,
  )
}

///|
test "cohort identity bounds all rounding modes and aggregation conservation" {
  let p = priced("0.005")
  let q = priced("0.004")
  let usages : Array[@jieheng.Usage] = []
  for i in 0..<256 {
    usages.push({ ..usage(i.to_string()), customer: "customer-\{i}", })
  }
  for rounding in [@jieheng.HalfEven, HalfUp, Down, Up] {
    for scale in [0, 2, 18] {
      let report = @jieheng.compare_cohort(p, q, usages[:], scale~, rounding~)
      @jieheng.verify_cohort(p, q, usages[:], report, scale~, rounding~)
      assert_eq(report.baseline_exact, "163.2")
      assert_eq(report.candidate_exact, "130.56")
      assert_eq(report.exact_delta, "-32.64")
      let text = @jieheng.encode_cohort(report)
      assert_eq(@jieheng.decode_cohort(text), report)
    }
  }
  for
    invalid in [
      [],
      [usage("1"), usage("2")],
      usages + [usage("1")],
      [{ ..usage("1"), quantity: "-1", }],
    ] {
    rejected(() => {
      ignore(
        @jieheng.compare_cohort(p, q, invalid[:], scale=2, rounding=HalfEven),
      )
    })
  }
  // Separate keys avoid delimiter-collision bugs; different periods are allowed.
  let distinct = [
    { ..usage("0"), customer: "a/b", period: "c", },
    { ..usage("0"), customer: "a", period: "b/c", },
    { ..usage("1"), customer: "a", period: "next", },
  ]
  ignore(@jieheng.compare_cohort(p, q, distinct[:], scale=2, rounding=HalfEven))
}

///|
test "cohort rejects malformed exchange and recovers without losing data" {
  let p = priced("1")
  let usages = [usage("1")]
  let report = @jieheng.compare_cohort(
    p,
    p,
    usages[:],
    scale=2,
    rounding=HalfEven,
  )
  let text = @jieheng.encode_cohort(report)
  for
    bad in [
      "{}",
      "null",
      "[",
      text.replace(old="\"rows\":[", new="\"tax\":0,\"rows\":["),
      text.replace(old="\"rows\":[", new="\"rows\":[],\"rows\":["),
      text.replace(
        old="jieheng.cohort-comparison.v1",
        new="jieheng.cohort-comparison.v2",
      ),
    ] {
    rejected(() => ignore(@jieheng.decode_cohort(bad)))
  }
  let input = @jieheng.encode_cohort_usage(usages[:])
  for
    bad in [
      "{}",
      input.replace(old="\"usages\":[", new="\"usages\":null,\"tax\":["),
      input.replace(old="\"quantity\":\"1\"", new="\"quantity\":1"),
    ] {
    rejected(() => ignore(@jieheng.decode_cohort_usage(bad)))
  }
  let huge = { ..report, baseline_exact: "x".repeat(1048576), }
  rejected(() => ignore(@jieheng.encode_cohort(huge)))
  assert_eq(@jieheng.decode_cohort(text), report)
}
