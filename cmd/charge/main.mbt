///|
async fn main {
  run_cli() catch {
    e => @cli.exit_error(e)
  }
}

///|
async fn run_cli() -> Unit {
  let args = @env.args()
  if (args.length() != 7 && args.length() != 8 && args.length() != 9) ||
    (args.length() == 8 && args[7] != "--json") ||
    (args.length() == 9 && args[7] != "--verify") {
    raise @jieheng.Invalid(
      code="arguments",
      path="cli",
      message="usage: moon run cmd/charge -- PLAN.json USAGE.json MINIMUM charge|waive SCALE ROUNDING [--json | --verify REPORT.json]",
    )
  }
  let plan = @jieheng.decode_plan(@cli.read_input(args[1]))
  let usage = @jieheng.decode_usage(@cli.read_input(args[2]))
  let minimum = args[3]
  let zero_usage : @jieheng.ZeroUsageMinimum = match args[4] {
    "charge" => Charge
    "waive" => Waive
    _ =>
      raise @jieheng.Invalid(
        code="policy",
        path="cli.zero_usage",
        message="choose charge or waive explicitly",
      )
  }
  let scale = @cli.scale(args[5])
  let rounding = @cli.rounding(args[6])
  if args.length() == 9 {
    let report = @jieheng.decode_charge(@cli.read_input(args[8]))
    @jieheng.verify_charge(
      plan,
      usage,
      report,
      minimum~,
      zero_usage~,
      scale~,
      rounding~,
    )
    @stdio.stdout.write(
      "verified charge: \{report.settlement.currency} \{report.settlement.amount}\n",
    )
    return
  }
  let report = @jieheng.rate_charge(
    plan,
    usage,
    minimum~,
    zero_usage~,
    scale~,
    rounding~,
  )
  let output = if args.length() == 8 {
    @jieheng.encode_charge(report)
  } else {
    "usage total: \{report.calculation.total}\nminimum top-up: \{report.top_up}\nexact total: \{report.total}\nsettled: \{report.settlement.currency} \{report.settlement.amount}"
  }
  @stdio.stdout.write(output + "\n")
}
