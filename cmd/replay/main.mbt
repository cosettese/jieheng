///|
async fn main {
  run_cli() catch {
    e => @cli.exit_error(e)
  }
}

///|
async fn run_cli() -> Unit {
  let args = @env.args()
  if (args.length() != 6 && args.length() != 8 && args.length() != 10) ||
    (args.length() == 8 && args[6] != "--verify" && args[6] != "--policy") ||
    (args.length() == 10 && (args[6] != "--verify" || args[8] != "--policy")) {
    raise @jieheng.Invalid(
      code="arguments",
      path="cli",
      message="usage: moon run cmd/replay -- BEFORE.json AFTER.json CASES.json SCALE ROUNDING [--verify REPORT.json] [--policy POLICY.json]",
    )
  }
  let before = @jieheng.decode_catalog(@cli.read_input(args[1]))
  let after = @jieheng.decode_catalog(@cli.read_input(args[2]))
  let cases = @jieheng.decode_replay_cases(@cli.read_input(args[3]))
  let scale = @cli.scale(args[4])
  let rounding = @cli.rounding(args[5])
  let report = if args.length() >= 8 && args[6] == "--verify" {
    @jieheng.decode_catalog_replay(@cli.read_input(args[7]))
  } else {
    @jieheng.replay_catalogs(before, after, cases[:], scale~, rounding~)
  }
  @jieheng.verify_catalog_replay(
    before,
    after,
    cases[:],
    report,
    scale~,
    rounding~,
  )
  if args.length() == 10 || (args.length() == 8 && args[6] == "--policy") {
    let file = args[args.length() - 1]
    let policy = @jieheng.decode_replay_policy(@cli.read_input(file))
    @jieheng.check_replay_policy(
      before,
      after,
      cases[:],
      report,
      policy,
      scale~,
      rounding~,
    )
  }
  @stdio.stdout.write(@jieheng.encode_catalog_replay(report) + "\n")
}
