///|
async fn main {
  run_cli() catch {
    e => @cli.exit_error(e)
  }
}

///|
async fn run_cli() -> Unit {
  let args = @env.args()
  if (args.length() != 5 && args.length() != 6) ||
    (args.length() == 6 && args[5] != "--json") {
    raise @jieheng.Invalid(
      code="arguments",
      path="cli",
      message="usage: moon run cmd/rate -- PLAN.json USAGE.json SCALE half-even|half-up|down|up [--json]",
    )
  }
  let scale = @cli.scale(args[3])
  let rounding = @cli.rounding(args[4])
  let plan = @jieheng.decode_plan(@cli.read_input(args[1]))
  let usage = @jieheng.decode_usage(@cli.read_input(args[2]))
  let result = @jieheng.rate(plan, usage)
  let settlement = @jieheng.settle(result, scale~, rounding~)
  let evidence : @jieheng.Evidence = { calculation: result, settlement, }
  @jieheng.verify_evidence(plan, usage, evidence, scale~, rounding~)
  if args.length() == 6 {
    @stdio.stdout.write(@jieheng.encode_evidence(evidence) + "\n")
    return
  }
  let output = StringBuilder()
  output.write_string("\{result.plan_id}@\{result.plan_version}\n")
  output.write_string(
    "\{usage.customer} / \{usage.period} / \{usage.quantity} \{result.unit}\n",
  )
  for line in result.lines {
    output.write_string(
      "tier \{line.tier}: \{line.quantity} x \{line.unit_price} = \{line.subtotal}\n",
    )
  }
  output.write_string("exact: \{result.currency} \{result.total}\n")
  output.write_string(
    "settled: \{settlement.currency} \{settlement.amount} (delta \{settlement.delta})\n",
  )
  @stdio.stdout.write(output.to_string())
}
