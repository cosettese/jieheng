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
      message="usage: moon run cmd/packages -- PACKAGE-PLAN.json USAGE.json SCALE ROUNDING [--json | --verify RECORD.json]",
    )
  }
  let plan = @jieheng.decode_package_plan(@cli.read_input(args[1]))
  let usage = @jieheng.decode_usage(@cli.read_input(args[2]))
  let scale = @cli.scale(args[3])
  let rounding = @cli.rounding(args[4])
  if args.length() == 7 {
    let record = @jieheng.decode_packages(@cli.read_input(args[6]))
    @jieheng.verify_packages(plan, usage, record, scale~, rounding~)
    @stdio.stdout.write(
      "verified packages: \{record.currency} \{record.settlement.amount}\n",
    )
    return
  }
  let record = @jieheng.rate_packages(plan, usage, scale~, rounding~)
  let output = if args.length() == 6 {
    @jieheng.encode_packages(record)
  } else {
    "packages: \{record.packages} x \{record.package_size} \{record.unit}\nunused: \{record.unused_units} \{record.unit}\nsettled: \{record.currency} \{record.settlement.amount}"
  }
  @stdio.stdout.write(output + "\n")
}
