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
      message="usage: moon run cmd/cohort -- BASELINE.json CANDIDATE.json USAGES.json SCALE ROUNDING [--json | --verify REPORT.json]",
    )
  }
  let baseline = @jieheng.decode_plan(@cli.read_input(args[1]))
  let candidate = @jieheng.decode_plan(@cli.read_input(args[2]))
  let usages = @jieheng.decode_cohort_usage(@cli.read_input(args[3]))
  let scale = @cli.scale(args[4])
  let rounding = @cli.rounding(args[5])
  if args.length() == 8 {
    let report = @jieheng.decode_cohort(@cli.read_input(args[7]))
    @jieheng.verify_cohort(
      baseline,
      candidate,
      usages[:],
      report,
      scale~,
      rounding~,
    )
    @stdio.stdout.write(
      "verified cohort: \{report.rows.length()} snapshots; settled delta \{report.settled_delta}\n",
    )
    return
  }
  let report = @jieheng.compare_cohort(
    baseline,
    candidate,
    usages[:],
    scale~,
    rounding~,
  )
  let output = if args.length() == 7 {
    @jieheng.encode_cohort(report)
  } else {
    "snapshots: \{report.rows.length()}\nbaseline settled: \{report.baseline_settled}\ncandidate settled: \{report.candidate_settled}\nexact delta: \{report.exact_delta}\nsettled delta: \{report.settled_delta}"
  }
  @stdio.stdout.write(output + "\n")
}
