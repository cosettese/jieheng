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
      message="usage: moon run cmd/compare-bills -- BASELINE-INPUT.json CANDIDATE-INPUT.json SCALE ROUNDING [--json | --verify REPORT.json]",
    )
  }
  let before = @jieheng.decode_bill_input(@cli.read_input(args[1]))
  let after = @jieheng.decode_bill_input(@cli.read_input(args[2]))
  let scale = @cli.scale(args[3])
  let rounding = @cli.rounding(args[4])
  if args.length() == 7 {
    let r = @jieheng.decode_bill_comparison(@cli.read_input(args[6]))
    @jieheng.verify_bill_comparison(before[:], after[:], r, scale~, rounding~)
    @stdio.stdout.write(
      "verified bill comparison: settled delta \{r.settled_delta}\n",
    )
    return
  }
  let r = @jieheng.compare_bills(before[:], after[:], scale~, rounding~)
  let output = if args.length() == 6 {
    @jieheng.encode_bill_comparison(r)
  } else {
    "matched metrics: \{r.changes.length()}\nexact delta: \{r.exact_delta}\nsettled delta: \{r.settled_delta}"
  }
  @stdio.stdout.write(output + "\n")
}
