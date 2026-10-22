///|
fn changed_items() -> Array[@jieheng.BillItem] raise @jieheng.PricingError {
  let base = invoice_input("calls", "0.004")
  let p = @jieheng.compile_plan(
    id="messages-unit",
    version="v2",
    metric="messages",
    unit="message",
    currency="USD",
    tiers=[{ up_to: None, unit_price: "0.001", }],
  )
  [
    Metered({
      plan: p,
      usage: { ..base.usage, metric: "messages", quantity: "6", },
      minimum: "0",
      zero_usage: Waive,
    }),
    Metered(base),
  ]
}

///|
test "bill comparison aligns reordered metrics across models and minimum changes" {
  let before = mixed_items()
  let after = changed_items()
  let r = @jieheng.compare_bills(
    before[:],
    after[:],
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(r.exact_delta, "-0.007")
  assert_eq(r.settled_delta, "0")
  assert_eq(r.changes[0].metric, "calls")
  assert_eq(r.changes[0].candidate_index, 1)
  assert_eq(r.changes[0].usage_delta, "0")
  assert_eq(r.changes[0].top_up_delta, "-0.001")
  assert_eq(r.changes[1].candidate_index, 0)
  assert_eq(r.changes[1].usage_delta, "-0.006")
  for scale in [0, 2, 18] {
    for rounding in [@jieheng.HalfEven, HalfUp, Down, Up] {
      let report = @jieheng.compare_bills(
        before[:],
        after[:],
        scale~,
        rounding~,
      )
      let reverse = @jieheng.compare_bills(
        after[:],
        before[:],
        scale~,
        rounding~,
      )
      assert_eq(
        reference_atoms(report.exact_delta),
        -reference_atoms(reverse.exact_delta),
      )
      assert_eq(
        reference_atoms(report.settled_delta),
        -reference_atoms(reverse.settled_delta),
      )
      let mut exact = 0N
      let mut settled = 0N
      for row in report.changes {
        exact += reference_atoms(row.exact_delta)
        settled += reference_atoms(row.settled_delta)
      }
      assert_eq(reference_atoms(report.exact_delta), exact)
      assert_eq(reference_atoms(report.settled_delta), settled)
      @jieheng.verify_bill_comparison(
        before[:],
        after[:],
        report,
        scale~,
        rounding~,
      )
      let text = @jieheng.encode_bill_comparison(report)
      assert_eq(@jieheng.decode_bill_comparison(text), report)
      assert_eq(
        @jieheng.encode_bill_comparison(@jieheng.decode_bill_comparison(text)),
        text,
      )
    }
  }
}

///|
test "bill comparison rejects forged alignment rows deltas and nested bills" {
  let before = mixed_items()
  let after = changed_items()
  let r = @jieheng.compare_bills(
    before[:],
    after[:],
    scale=2,
    rounding=HalfEven,
  )
  let row = r.changes[0]
  for
    fake in [
      { ..r, changes: [], },
      { ..r, changes: [r.changes[1], row], },
      { ..r, changes: [{ ..row, candidate_index: 0, }, r.changes[1]], },
      { ..r, changes: [{ ..row, top_up_delta: "0", }, r.changes[1]], },
      { ..r, changes: [{ ..row, usage_delta: "1", }, r.changes[1]], },
      { ..r, changes: [{ ..row, metric: "other", }, r.changes[1]], },
      { ..r, exact_delta: "0", },
      { ..r, settled_delta: "-0.01", },
      { ..r, candidate: { ..r.candidate, currency: "EUR", }, },
    ] {
    rejected(() => {
      @jieheng.verify_bill_comparison(
        before[:],
        after[:],
        fake,
        scale=2,
        rounding=HalfEven,
      )
    })
  }
  let unchanged = @jieheng.compare_bills(
    before[:],
    before[:],
    scale=2,
    rounding=HalfEven,
  )
  assert_eq(unchanged.exact_delta, "0")
  assert_eq(unchanged.settled_delta, "0")
}

///|
test "bill comparison rejects changed usage incomplete coverage and unknown exchange data" {
  let before = mixed_items()
  let after = changed_items()
  guard after[0] is Metered(c) else { fail("expected metered candidate") }
  for
    bad in [
      [after[0]],
      [after[0], after[0]],
      [Metered({ ..c, usage: { ..c.usage, quantity: "7", }, }), after[1]],
      [Metered({ ..c, usage: { ..c.usage, customer: "other", }, }), after[1]],
    ] {
    rejected(() => {
      ignore(
        @jieheng.compare_bills(before[:], bad[:], scale=2, rounding=HalfEven),
      )
    })
  }
  let r = @jieheng.compare_bills(
    before[:],
    after[:],
    scale=2,
    rounding=HalfEven,
  )
  let text = @jieheng.encode_bill_comparison(r)
  for
    bad in [
      "{}",
      "null",
      text.replace(
        old="jieheng.bill-comparison.v1",
        new="jieheng.bill-comparison.v2",
      ),
      text.replace(old="\"changes\":[", new="\"tax\":0,\"changes\":["),
      text.replace(old="\"baseline_index\":0", new="\"baseline_index\":64"),
      text.replace(
        old="\"baseline_index\":0",
        new="\"baseline_index\":0,\"baseline_index\":1",
      ),
    ] {
    rejected(() => ignore(@jieheng.decode_bill_comparison(bad)))
  }
  assert_eq(@jieheng.decode_bill_comparison(text), r)
}
