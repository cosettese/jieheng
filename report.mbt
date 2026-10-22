///|
fn report_text(text : String) -> String {
  let out = StringBuilder()
  for c in text.iter() {
    match c {
      '&'
      | '<'
      | '>'
      | '|'
      | '`'
      | '*'
      | '_'
      | '['
      | ']'
      | '\\'
      | '!'
      | '#'
      | '~'
      | '"'
      | '\'' => out.write_string("&#\{c.to_int()};")
      _ => out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn report_fence(text : String) -> String {
  let mut longest = 2
  let mut run = 0
  for c in text.iter() {
    if c == '`' {
      run += 1
      if run > longest {
        longest = run
      }
    } else {
      run = 0
    }
  }
  "`".repeat(longest + 1)
}

///|
/// Verify against the complete trusted manifest before returning a deterministic
/// Markdown statement. Includes lossless canonical input and bill JSON appendices.
/// No partial output is returned on verification, encoding or size failure.
pub fn render_bill_markdown(
  items : ArrayView[BillItem],
  bill : Bill,
  scale~ : Int32,
  rounding~ : Rounding,
) -> String raise PricingError {
  verify_bill(items, bill, scale~, rounding~)
  let input_json = encode_bill_input(items)
  let record_json = encode_bill(bill)
  let out = StringBuilder()
  out.write_string("# Usage pricing statement\n\n")
  out.write_string(
    "Customer: \{report_text(bill.customer)}\n\nPeriod: \{report_text(bill.period)}\n\n",
  )
  out.write_string(
    "Currency: \{bill.currency}. Scale: \{scale}. Rounding: \{rounding_name(rounding)}.\n\n",
  )
  out.write_string(
    "| Usage charges | Minimum top-ups | Exact total | Settled total | Rounding delta | Minor units |\n| --- | --- | --- | --- | --- | --- |\n",
  )
  let t = bill.totals
  out.write_string(
    "| \{t.usage_total} | \{t.top_up} | \{t.total} | \{t.amount} | \{t.delta} | \{t.minor_units} |\n\n",
  )
  out.write_string(
    "Each item is settled once after its minimum, if any; settled items are summed without rounding again. This statement covers usage pricing only.\n\n",
  )
  for i, evidence in bill.items {
    let u = bill_evidence_usage(evidence)
    out.write_string("## Metric: \{report_text(u.metric)}\n\n")
    out.write_string(
      "Quantity: \{u.quantity} \{report_text(bill_item_unit(items[i]))}.\n\n",
    )
    let settlement = match evidence {
      MeteredCharge(c) => {
        let p = match items[i] {
          Metered(input) => input.plan
          _ => abort("verified model alignment")
        }
        let mode = match p.mode {
          Graduated => "graduated"
          Volume => "volume"
        }
        out.write_string(
          "Plan: \{report_text(p.id)} @ \{report_text(p.version)}. Model: \{mode}.\n\n",
        )
        out.write_string(
          "Minimum: \{c.minimum}. At zero usage: \{zero_usage_name(c.zero_usage)}. Usage charge: \{c.calculation.total}. Top-up: \{c.top_up}. Exact total: \{c.total}.\n\n",
        )
        if c.calculation.lines.is_empty() {
          out.write_string("No occupied tiers at zero usage.\n\n")
        } else {
          out.write_string(
            "| Tier | From (exclusive) | To (inclusive) | Quantity | Unit price | Subtotal |\n| --- | --- | --- | --- | --- | --- |\n",
          )
          for line in c.calculation.lines {
            out.write_string(
              "| \{line.tier} | \{line.from_exclusive} | \{line.to_inclusive} | \{line.quantity} | \{line.unit_price} | \{line.subtotal} |\n",
            )
          }
          out.write_string("\n")
        }
        c.settlement
      }
      PackageCharge(c) => {
        out.write_string(
          "Plan: \{report_text(c.plan_id)} @ \{report_text(c.plan_version)}. Model: package.\n\n",
        )
        out.write_string(
          "| Capacity per package | Price per package | Packages | Unused units | Exact total |\n| --- | --- | --- | --- | --- |\n",
        )
        out.write_string(
          "| \{c.package_size} | \{c.package_price} | \{c.packages} | \{c.unused_units} | \{c.total} |\n\n",
        )
        c.settlement
      }
    }
    out.write_string(
      "Settled: \{settlement.currency} \{settlement.amount}. Rounding delta: \{settlement.delta}. Minor units: \{settlement.minor_units}.\n\n",
    )
  }
  out.write_string(
    "## Complete contract input\n\nThe trusted input includes every tier, including unoccupied tiers.\n\n",
  )
  let input_fence = report_fence(input_json)
  out.write_string("\{input_fence}json\n\{input_json}\n\{input_fence}\n\n")
  out.write_string(
    "## Complete bill evidence\n\nVerification requires the trusted contract and settlement policy; this is not a signature.\n\n",
  )
  let record_fence = report_fence(record_json)
  out.write_string("\{record_fence}json\n\{record_json}\n\{record_fence}\n")
  let result = out.to_string()
  if result.length() > 4194304 {
    invalid(
      "size", "report", "Markdown exceeds 4 Mi UTF-16 units; split the bill explicitly",
    )
  }
  result
}
