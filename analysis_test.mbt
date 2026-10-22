///|
fn reference_atoms(s : String) -> BigInt {
  if s.has_prefix("-") {
    return -reference_atoms(s[1:].to_owned())
  }
  let parts = s.split(".").collect()
  let fraction = if parts.length() == 2 { parts[1].to_owned() } else { "" }
  BigInt::from_string(
    parts[0].to_owned() + fraction + "0".repeat(18 - fraction.length()),
  )
}

///|
fn curve_plan(
  mode : @jieheng.PricingMode,
  shifted~ : Bool = false,
) -> @jieheng.Plan raise @jieheng.PricingError {
  @jieheng.compile_plan(
    id="api",
    version=if shifted { "v2" } else { "v1" },
    metric="calls",
    unit="call",
    currency="USD",
    mode~,
    tiers=if shifted {
      [
        { up_to: Some("5"), unit_price: "0.006", },
        { up_to: Some("9"), unit_price: "0.010", },
        { up_to: None, unit_price: "0", },
      ]
    } else {
      [
        { up_to: Some("3"), unit_price: "0.007", },
        { up_to: Some("7"), unit_price: "0.003", },
        { up_to: None, unit_price: "0.009", },
      ]
    },
  )
}

///|
test "analysis affine spans and extrema match exhaustive forward pricing" {
  for before_mode in [@jieheng.Graduated, Volume] {
    for after_mode in [@jieheng.Graduated, Volume] {
      let before = curve_plan(before_mode)
      let after = curve_plan(after_mode, shifted=true)
      for cap in [0, 1, 3, 5, 9, 30] {
        let r = @jieheng.analyze_prices(before, after, cap.to_string())
        let mut minimum = 0N
        let mut maximum = 0N
        let mut min_at = 0
        let mut max_at = 0
        for q in 0..<=cap {
          let bt = reference_atoms(
            @jieheng.rate(before, usage(q.to_string())).total,
          )
          let ct = reference_atoms(
            @jieheng.rate(after, usage(q.to_string())).total,
          )
          let delta = ct - bt
          if delta < minimum {
            minimum = delta
            min_at = q
          }
          if delta > maximum {
            maximum = delta
            max_at = q
          }
          let mut covered = 0
          for span in r.spans {
            let from = BigInt::from_string(span.from_quantity)
            let to = BigInt::from_string(span.to_quantity)
            let n = BigInt::from_int(q)
            if n >= from && n <= to {
              covered += 1
              assert_eq(
                reference_atoms(span.baseline_total) +
                reference_atoms(span.baseline_step) * (n - from),
                bt,
              )
              assert_eq(
                reference_atoms(span.candidate_total) +
                reference_atoms(span.candidate_step) * (n - from),
                ct,
              )
            }
          }
          assert_eq(covered, 1)
        }
        assert_eq(reference_atoms(r.minimum_delta), minimum)
        assert_eq(reference_atoms(r.maximum_delta), maximum)
        assert_eq(r.minimum_at, min_at.to_string())
        assert_eq(r.maximum_at, max_at.to_string())
        let text = @jieheng.encode_analysis(r)
        assert_eq(@jieheng.decode_analysis(text), r)
        assert_eq(
          @jieheng.encode_analysis(@jieheng.decode_analysis(text)),
          text,
        )
        @jieheng.verify_analysis(before, after, cap.to_string(), r)
      }
    }
  }
}

///|
test "analysis proves maximum tier partition and huge integer domains" {
  let a : Array[@jieheng.Tier] = []
  let b : Array[@jieheng.Tier] = []
  for i in 1..<=1023 {
    a.push({ up_to: Some((i * 2 - 1).to_string()), unit_price: "1", })
    b.push({ up_to: Some((i * 2).to_string()), unit_price: "1", })
  }
  a.push({ up_to: None, unit_price: "1", })
  b.push({ up_to: None, unit_price: "1", })
  let before = @jieheng.compile_plan(
    id="api",
    version="a",
    metric="calls",
    unit="call",
    currency="USD",
    tiers=a[:],
  )
  let after = @jieheng.compile_plan(
    id="api",
    version="b",
    metric="calls",
    unit="call",
    currency="USD",
    tiers=b[:],
    mode=Volume,
  )
  let r = @jieheng.analyze_prices(
    before, after, "999999999999999999999999999999",
  )
  assert_eq(r.spans.length(), 2047)
  assert_eq(r.minimum_delta, "0")
  assert_eq(r.maximum_delta, "0")
  assert_eq(r.minimum_at, "0")
  assert_eq(r.maximum_at, "0")
  let text = @jieheng.encode_analysis(r)
  assert_eq(@jieheng.decode_analysis(text), r)
}

///|
test "analysis verifier rejects holes merged boundaries incorrect slopes and extrema" {
  let before = curve_plan(Graduated)
  let after = curve_plan(Volume, shifted=true)
  let r = @jieheng.analyze_prices(before, after, "30")
  let first = r.spans[0]
  for
    fake in [
      { ..r, spans: [], },
      { ..r, spans: [first], },
      { ..r, spans: [{ ..first, to_quantity: "30", }], },
      {
        ..r,
        spans: [{ ..first, from_quantity: "1", }] + r.spans[1:].to_owned(),
      },
      {
        ..r,
        spans: [{ ..first, baseline_total: "1", }] + r.spans[1:].to_owned(),
      },
      {
        ..r,
        spans: [{ ..first, candidate_step: "0", }] + r.spans[1:].to_owned(),
      },
      { ..r, minimum_delta: "0", },
      { ..r, maximum_delta: "999", },
      { ..r, minimum_at: "0", },
      { ..r, maximum_at: "30", },
      { ..r, baseline: { ..r.baseline, version: "wrong", }, },
      { ..r, currency: "EUR", },
      { ..r, limit: "31", },
    ] {
    rejected(() => @jieheng.verify_analysis(before, after, "30", fake))
  }
  for limit in ["-1", "01", "1.5", "1e2", "9".repeat(31)] {
    rejected(() => ignore(@jieheng.analyze_prices(before, after, limit)))
  }
  @jieheng.verify_analysis(before, after, "30", r)
}

///|
test "analysis transport rejects unsupported and duplicate fields and recovers" {
  let a = curve_plan(Graduated)
  let b = curve_plan(Volume, shifted=true)
  let r = @jieheng.analyze_prices(a, b, "30")
  let text = @jieheng.encode_analysis(r)
  for
    bad in [
      "{}",
      "null",
      "[",
      text.replace(
        old="jieheng.price-analysis.v1",
        new="jieheng.price-analysis.v2",
      ),
      text.replace(old="\"spans\":[", new="\"tax\":0,\"spans\":["),
      text.replace(old="\"limit\":\"30\"", new="\"limit\":30"),
      text.replace(
        old="\"limit\":\"30\"",
        new="\"limit\":\"30\",\"limit\":\"31\"",
      ),
      text.replace(
        old="\"from_quantity\":\"0\"",
        new="\"from_quantity\":\"0\",\"unknown\":true",
      ),
    ] {
    rejected(() => ignore(@jieheng.decode_analysis(bad)))
  }
  assert_eq(@jieheng.decode_analysis(text), r)
}
