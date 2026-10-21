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
      message="usage: moon run cmd/schedule -- SCHEDULE.json YYYY-MM-DD USAGE.json SCALE ROUNDING [--json | --verify RECORD.json]",
    )
  }
  let schedule = @jieheng.decode_schedule(@cli.read_input(args[1]))
  let on = args[2]
  let usage = @jieheng.decode_usage(@cli.read_input(args[3]))
  let scale = @cli.scale(args[4])
  let rounding = @cli.rounding(args[5])
  if args.length() == 8 {
    let record = @jieheng.decode_scheduled(@cli.read_input(args[7]))
    @jieheng.verify_scheduled(schedule, on, usage, record, scale~, rounding~)
    @stdio.stdout.write(
      "verified scheduled: \{record.evidence.settlement.currency} \{record.evidence.settlement.amount}\n",
    )
    return
  }
  let record = @jieheng.rate_scheduled(schedule, on, usage, scale~, rounding~)
  let c = record.evidence.calculation
  let output = if args.length() == 7 {
    @jieheng.encode_scheduled(record)
  } else {
    "\{on}: \{c.plan_id}@\{c.plan_version}\nsettled: \{c.currency} \{record.evidence.settlement.amount}"
  }
  @stdio.stdout.write(output + "\n")
}
