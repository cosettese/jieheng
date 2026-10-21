///|
async fn main {
  run_cli() catch {
    e => @cli.exit_error(e)
  }
}

///|
async fn run_cli() -> Unit {
  let args = @env.args()
  if args.length() != 6 {
    raise @jieheng.Invalid(
      code="arguments",
      path="cli",
      message="usage: moon run cmd/verify -- PLAN.json USAGE.json EVIDENCE.json SCALE half-even|half-up|down|up",
    )
  }
  let scale = @cli.scale(args[4])
  let rounding = @cli.rounding(args[5])
  let plan = @jieheng.decode_plan(@cli.read_input(args[1]))
  let usage = @jieheng.decode_usage(@cli.read_input(args[2]))
  let evidence = @jieheng.decode_evidence(@cli.read_input(args[3]))
  @jieheng.verify_evidence(plan, usage, evidence, scale~, rounding~)
  @stdio.stdout.write(
    "verified: \{evidence.settlement.currency} \{evidence.settlement.amount}\n",
  )
}
