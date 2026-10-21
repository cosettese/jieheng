///|
async fn main {
  run_cli() catch {
    e => @cli.exit_error(e)
  }
}

///|
async fn run_cli() -> Unit {
  let args = @env.args()
  if (args.length() != 5 && args.length() != 6 && args.length() != 7) ||
    (args.length() == 6 && args[5] != "--json") ||
    (args.length() == 7 && args[5] != "--verify") {
    raise @jieheng.Invalid(
      code="arguments",
      path="cli",
      message="usage: moon run cmd/budget -- PLAN.json REQUEST.json SCALE ROUNDING [--json | --verify QUOTE.json]",
    )
  }
  let plan = @jieheng.decode_plan(@cli.read_input(args[1]))
  let request = @jieheng.decode_budget_request(@cli.read_input(args[2]))
  let scale = @cli.scale(args[3])
  let rounding = @cli.rounding(args[4])
  if args.length() == 7 {
    let quote = @jieheng.decode_budget(@cli.read_input(args[6]))
    @jieheng.verify_budget(plan, request, quote, scale~, rounding~)
    @stdio.stdout.write(
      "verified budget: quantity \{quote.evidence.calculation.usage.quantity}\n",
    )
    return
  }
  let quote = @jieheng.quote_budget(plan, request, scale~, rounding~)
  let output = if args.length() == 6 {
    @jieheng.encode_budget(quote)
  } else {
    "maximum quantity: \{quote.evidence.calculation.usage.quantity}\nlimit: \{request.limit}\nbudget: \{request.budget}\nsettled: \{quote.evidence.settlement.currency} \{quote.evidence.settlement.amount}"
  }
  @stdio.stdout.write(output + "\n")
}
