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
      message="usage: moon run cmd/quota -- PLAN.json REQUEST.json SCALE ROUNDING [--json | --verify QUOTE.json]",
    )
  }
  let plan = @jieheng.decode_plan(@cli.read_input(args[1]))
  let request = @jieheng.decode_budget_request(@cli.read_input(args[2]))
  let scale = @cli.scale(args[3])
  let rounding = @cli.rounding(args[4])
  if args.length() == 7 {
    let quote = @jieheng.decode_quota(@cli.read_input(args[6]))
    @jieheng.verify_quota(plan, request, quote, scale~, rounding~)
    @stdio.stdout.write(
      "verified quota: 0..\{quote.evidence.calculation.usage.quantity}\n",
    )
    return
  }
  let quote = @jieheng.quote_quota(plan, request, scale~, rounding~)
  let output = if args.length() == 6 {
    @jieheng.encode_quota(quote)
  } else {
    let next = match quote.first_unaffordable {
      Some(e) =>
        "first unaffordable: \{e.calculation.usage.quantity} (\{e.settlement.currency} \{e.settlement.amount})"
      None => "trusted search limit reached"
    }
    "safe quota: 0..\{quote.evidence.calculation.usage.quantity}\nsettled at quota: \{quote.evidence.settlement.currency} \{quote.evidence.settlement.amount}\n" +
    next
  }
  @stdio.stdout.write(output + "\n")
}
