///|
// Validate the claimed selected tier using its interval, rather than calling
// the rating implementation's first-matching-tier search.
fn verify_volume(
  plan : Plan,
  quantity : BigInt,
  calculation : Calculation,
) -> Unit raise PricingError {
  if quantity == 0N {
    if !calculation.lines.is_empty() || calculation.total != "0" {
      invalid(
        "coverage", "calculation", "zero volume requires no lines and an exact zero total",
      )
    }
    return
  }
  if calculation.lines.length() != 1 {
    invalid(
      "partition", "calculation.lines", "positive volume requires exactly one line charging all units",
    )
  }
  let line = calculation.lines[0]
  if line.tier < 0 || line.tier >= plan.tiers.length() {
    invalid(
      "tier", "calculation.lines[0].tier", "selected tier index is outside the trusted plan",
    )
  }
  let tier = plan.tiers[line.tier]
  if line.tier > 0 {
    if plan.tiers[line.tier - 1].up_to is Some(lower) && quantity <= lower {
      invalid(
        "boundary", "calculation.lines[0].tier", "quantity must exceed the selected tier's lower bound",
      )
    }
  }
  if tier.up_to is Some(upper) && quantity > upper {
    invalid(
      "boundary", "calculation.lines[0].tier", "quantity exceeds the selected tier's upper bound",
    )
  }
  if line.from_exclusive != "0" ||
    line.to_inclusive != quantity.to_string() ||
    line.quantity != quantity.to_string() {
    invalid(
      "coverage", "calculation.lines[0]", "the selected price must charge the complete trusted quantity",
    )
  }
  if line.unit_price != format_atoms(tier.price) {
    invalid(
      "price", "calculation.lines[0].unit_price", "price must match the selected tier in the trusted plan",
    )
  }
  let total = format_atoms(quantity * tier.price)
  if line.subtotal != total || calculation.total != total {
    invalid(
      "total", "calculation", "expected complete quantity multiplied by the selected tier price",
    )
  }
}
