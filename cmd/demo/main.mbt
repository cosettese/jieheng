///|
fn main raise {
  let plan = @jieheng.compile_plan(
    id="stripe-graduated-example",
    version="2026-10-21",
    metric="units",
    unit="unit",
    currency="USD",
    tiers=[
      { up_to: Some("5"), unit_price: "7", },
      { up_to: Some("10"), unit_price: "6.5", },
      { up_to: None, unit_price: "6", },
    ],
  )
  for quantity in ["6", "20", "25"] {
    let result = @jieheng.rate(plan, {
      customer: "example-customer",
      metric: "units",
      period: "example-period",
      quantity,
    })
    let bill = @jieheng.settle(result, scale=2, rounding=HalfEven)
    println("\{quantity} units: \{bill.currency} \{bill.amount}")
    for line in result.lines {
      println(
        "  tier \{line.tier}: \{line.quantity} x \{line.unit_price} = \{line.subtotal}",
      )
    }
  }
}
