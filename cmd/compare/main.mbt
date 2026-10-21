///|
async fn main {
  run_cli() catch {
    e => @cli.exit_error(e)
  }
}

///|
async fn run_cli() -> Unit {
  let args = @env.args()
  if (args.length() != 6 && args.length() != 7 && args.length() != 8) ||
    (args.length() == 7 && args[6] != "--json") ||
    (args.length() == 8 && args[6] != "--verify") {
    raise @jieheng.Invalid(
      code="arguments",
      path="cli",
      message="usage: moon run cmd/compare -- BASELINE.json CANDIDATE.json USAGE.json SCALE ROUNDING [--json | --verify REPORT.json]",
    )
  }
  let scale = @cli.scale(args[4])
  let rounding = @cli.rounding(args[5])
  let baseline = @jieheng.decode_plan(@cli.read_input(args[1]))
  let candidate = @jieheng.decode_plan(@cli.read_input(args[2]))
  let usage = @jieheng.decode_usage(@cli.read_input(args[3]))
  if args.length() == 8 {
    let report = @jieheng.decode_comparison(@cli.read_input(args[7]))
    @jieheng.verify_comparison(
      baseline,
      candidate,
      usage,
      report,
      scale~,
      rounding~,
    )
    @stdio.stdout.write(
      "verified comparison: exact delta \{report.exact_delta}; settled delta \{report.settled_delta}\n",
    )
    return
  }
  let report = @jieheng.compare_plans(
    baseline,
    candidate,
    usage,
    scale~,
    rounding~,
  )
  if args.length() == 7 {
    @stdio.stdout.write(@jieheng.encode_comparison(report) + "\n")
    return
  }
  let before = report.baseline.calculation
  let after = report.candidate.calculation
  @stdio.stdout.write(
    "\{before.plan_id}@\{before.plan_version} -> \{after.plan_id}@\{after.plan_version}\n" +
    "\{usage.customer} / \{usage.period} / \{usage.quantity} \{before.unit}\n" +
    "baseline: \{before.currency} \{report.baseline.settlement.amount} (exact \{before.total})\n" +
    "candidate: \{after.currency} \{report.candidate.settlement.amount} (exact \{after.total})\n" +
    "exact delta: \{report.exact_delta}\nsettled delta: \{report.settled_delta}\n",
  )
}
