///|
fn pack(
  size : String,
  price~ : String = "0.005",
) -> @jieheng.PackagePlan raise @jieheng.PricingError {
  @jieheng.compile_package(
    id="api",
    version="v1",
    metric="calls",
    unit="call",
    currency="USD",
    package_size=size,
    package_price=price,
  )
}

///|
test "package ceiling agrees with independent repeated capacity addition" {
  for size in 1..<=11 {
    let p = pack(size.to_string())
    for q in 0..<=100 {
      let mut capacity = 0
      let mut count = 0
      while capacity < q {
        capacity += size
        count += 1
      }
      for rounding in [@jieheng.HalfEven, HalfUp, Down, Up] {
        let e = @jieheng.rate_packages(
          p,
          usage(q.to_string()),
          scale=2,
          rounding~,
        )
        assert_eq(e.packages, count.to_string())
        assert_eq(e.unused_units, (capacity - q).to_string())
        @jieheng.verify_packages(p, usage(q.to_string()), e, scale=2, rounding~)
        let text = @jieheng.encode_packages(e)
        assert_eq(@jieheng.decode_packages(text), e)
        assert_eq(
          @jieheng.encode_packages(@jieheng.decode_packages(text)),
          text,
        )
      }
    }
  }
}

///|
test "package exact boundaries zero and very large capacity remain precise" {
  for
    (size, q, count, unused) in [
      ("1", "0", "0", "0"),
      ("5", "4", "1", "1"),
      ("5", "5", "1", "0"),
      ("5", "6", "2", "4"),
      (
        "999999999999999999999999999999", "1", "1", "999999999999999999999999999998",
      ),
      (
        "999999999999999999999999999998", "999999999999999999999999999999", "2",
        "999999999999999999999999999997",
      ),
    ] {
    let p = pack(size, price="0.000000000000000001")
    let e = @jieheng.rate_packages(p, usage(q), scale=18, rounding=HalfEven)
    assert_eq(e.packages, count)
    assert_eq(e.unused_units, unused)
    @jieheng.verify_packages(p, usage(q), e, scale=18, rounding=HalfEven)
    let plan_text = @jieheng.encode_package_plan(p)
    assert_eq(
      @jieheng.encode_package_plan(@jieheng.decode_package_plan(plan_text)),
      plan_text,
    )
  }
  let free = pack("1", price="0")
  assert_eq(
    @jieheng.rate_packages(
      free,
      usage("999999999999999999999999999999"),
      scale=0,
      rounding=Up,
    ).total,
    "0",
  )
  let huge = pack(
    "1",
    price="999999999999999999999999999999.999999999999999999",
  )
  let e = @jieheng.rate_packages(
    huge,
    usage("999999999999999999999999999999"),
    scale=18,
    rounding=Up,
  )
  @jieheng.verify_packages(huge, e.usage, e, scale=18, rounding=Up)
}

///|
test "package verifier rejects unused capacity forgery overbilling and zero fee" {
  let p = pack("5", price="10")
  let u = usage("6")
  let e = @jieheng.rate_packages(p, u, scale=2, rounding=HalfEven)
  for
    fake in [
      { ..e, packages: "3", unused_units: "9", total: "30", },
      { ..e, packages: "1", unused_units: "0", },
      { ..e, packages: "02", },
      { ..e, unused_units: "-1", },
      { ..e, unused_units: "3", },
      { ..e, package_size: "6", },
      { ..e, package_price: "9", },
      { ..e, total: "20.0", },
      { ..e, plan_version: "v2", },
      { ..e, currency: "EUR", },
      { ..e, unit: "byte", },
      { ..e, usage: usage("7"), },
      { ..e, settlement: { ..e.settlement, amount: "19.99", }, },
    ] {
    rejected(() => {
      @jieheng.verify_packages(p, u, fake, scale=2, rounding=HalfEven)
    })
  }
  let zero = @jieheng.rate_packages(p, usage("0"), scale=2, rounding=HalfEven)
  assert_eq(zero.total, "0")
  rejected(() => {
    @jieheng.verify_packages(
      p,
      usage("0"),
      { ..zero, packages: "1", unused_units: "5", total: "10", },
      scale=2,
      rounding=HalfEven,
    )
  })
  @jieheng.verify_packages(p, u, e, scale=2, rounding=HalfEven)
}

///|
test "package rejects invalid plans and strict unknown data then recovers" {
  for size in ["0", "-1", "01", "1.5", "1e2", "9".repeat(31)] {
    rejected(() => ignore(pack(size)))
  }
  for price in ["-1", "01", "1e2", "0.", "1.0000000000000000001"] {
    rejected(() => ignore(pack("1", price~)))
  }
  let p = pack("5")
  let plan_text = @jieheng.encode_package_plan(p)
  for
    bad in [
      "{}",
      "null",
      "[",
      plan_text.replace(old="jieheng.package-plan.v1", new="jieheng.plan.v1"),
      plan_text.replace(old="\"package_size\":\"5\"", new="\"package_size\":5"),
      plan_text.replace(
        old="\"package_size\":\"5\"",
        new="\"package_size\":\"5\",\"allowance\":\"1\"",
      ),
      plan_text.replace(
        old="\"package_size\":\"5\"",
        new="\"package_size\":\"5\",\"package_size\":\"6\"",
      ),
    ] {
    rejected(() => ignore(@jieheng.decode_package_plan(bad)))
  }
  rejected(() => ignore(@jieheng.decode_plan(plan_text)))
  let e = @jieheng.rate_packages(p, usage("6"), scale=2, rounding=HalfEven)
  let text = @jieheng.encode_packages(e)
  for
    bad in [
      "{}",
      "null",
      text.replace(
        old="jieheng.package-evidence.v1",
        new="jieheng.package-evidence.v2",
      ),
      text.replace(
        old="\"packages\":\"2\"",
        new="\"packages\":2,\"packages\":\"2\"",
      ),
      text.replace(old="\"packages\":\"2\"", new="\"packages\":\"2\",\"tax\":0"),
    ] {
    rejected(() => ignore(@jieheng.decode_packages(bad)))
  }
  assert_eq(@jieheng.decode_packages(text), e)
}
