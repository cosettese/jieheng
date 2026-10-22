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
      message="usage: moon run cmd/analyze -- BASELINE.json CANDIDATE.json LIMIT [--json | --verify REPORT.json]",
    )
  }
  let baseline = @jieheng.decode_plan(@cli.read_input(args[1]))
  let candidate = @jieheng.decode_plan(@cli.read_input(args[2]))
  if args.length() == 6 {
    let report = @jieheng.decode_analysis(@cli.read_input(args[5]))
    @jieheng.verify_analysis(baseline, candidate, args[3], report)
    @stdio.stdout.write("verified analysis: \{report.spans.length()} spans\n")
    return
  }
  let report = @jieheng.analyze_prices(baseline, candidate, args[3])
  let output = if args.length() == 5 {
    @jieheng.encode_analysis(report)
  } else {
    "quantity domain: 0..\{report.limit}\nspans: \{report.spans.length()}\nminimum exact delta: \{report.minimum_delta} at \{report.minimum_at}\nmaximum exact delta: \{report.maximum_delta} at \{report.maximum_at}"
  }
  @stdio.stdout.write(output + "\n")
}
