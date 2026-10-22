///|
async fn main {
  run_cli() catch {
    e => @cli.exit_error(e)
  }
}

///|
async fn run_cli() -> Unit {
  let args = @env.args()
  if (args.length() != 4 && args.length() != 5 && args.length() != 6) ||
    (args.length() == 5 && args[4] != "--json") ||
    (args.length() == 6 && args[4] != "--verify") {
    raise @jieheng.Invalid(
      code="arguments",
      path="cli",
      message="usage: moon run cmd/bill-quota -- INPUT.json SCALE ROUNDING [--json | --verify REPORT.json]",
    )
  }
  let input = @jieheng.decode_bill_quota_input(@cli.read_input(args[1]))
  let scale = @cli.scale(args[2])
  let rounding = @cli.rounding(args[3])
  if args.length() == 6 {
    let r = @jieheng.decode_bill_quota(@cli.read_input(args[5]))
    @jieheng.verify_bill_quota(input, r, scale~, rounding~)
    @stdio.stdout.write(
      "verified bill quota: \{r.bill.currency} \{r.bill.totals.amount}\n",
    )
    return
  }
  let r = @jieheng.quote_bill_quota(input, scale~, rounding~)
  let variable = r.bill.items[r.bill.items.length() - 1]
  let q = match variable {
    MeteredCharge(c) => c.calculation.usage.quantity
    PackageCharge(c) => c.usage.quantity
  }
  let output = if args.length() == 5 {
    @jieheng.encode_bill_quota(r)
  } else {
    "safe variable quota: \{r.variable_metric} 0..\{q}\nsettled bill: \{r.bill.currency} \{r.bill.totals.amount}"
  }
  @stdio.stdout.write(output + "\n")
}
