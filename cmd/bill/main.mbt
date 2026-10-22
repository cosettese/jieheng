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
      message="usage: moon run cmd/bill -- INPUT.json SCALE ROUNDING [--json | --verify BILL.json]",
    )
  }
  let items = @jieheng.decode_bill_input(@cli.read_input(args[1]))
  let scale = @cli.scale(args[2])
  let rounding = @cli.rounding(args[3])
  if args.length() == 6 {
    let bill = @jieheng.decode_bill(@cli.read_input(args[5]))
    @jieheng.verify_bill(items[:], bill, scale~, rounding~)
    @stdio.stdout.write(
      "verified bill: \{bill.currency} \{bill.totals.amount}\n",
    )
    return
  }
  let bill = @jieheng.rate_bill(items[:], scale~, rounding~)
  let output = if args.length() == 5 {
    @jieheng.encode_bill(bill)
  } else {
    "\{bill.customer} / \{bill.period}\nitems: \{bill.items.length()}\nsettled: \{bill.currency} \{bill.totals.amount} (delta \{bill.totals.delta})"
  }
  @stdio.stdout.write(output + "\n")
}
