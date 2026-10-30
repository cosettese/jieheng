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
    (
      args.length() == 6 &&
      args[5] != "--require-compatible" &&
      args[5] != "--require-unchanged"
    ) ||
    (args.length() == 7 && args[5] != "--verify") {
    raise @jieheng.Invalid(
      code="arguments",
      path="cli",
      message="usage: moon run cmd/migration -- BEFORE.json AFTER.json START END [--require-compatible | --require-unchanged | --verify REPORT.json]",
    )
  }
  let b = @jieheng.decode_catalog(@cli.read_input(args[1]))
  let a = @jieheng.decode_catalog(@cli.read_input(args[2]))
  let r = if args.length() == 7 {
    @jieheng.decode_catalog_migration(@cli.read_input(args[6]))
  } else {
    @jieheng.audit_catalog_migration(b, a, args[3], args[4])
  }
  @jieheng.verify_catalog_migration(b, a, args[3], args[4], r)
  if args.length() == 6 {
    for span in r.spans {
      for change in span.changes {
        if args[5] == "--require-unchanged" || change.is_blocking() {
          raise @jieheng.Invalid(
            code="migration",
            path="migration.spans",
            message="metric '\{span.metric}' [\{span.starts_on}, \{span.ends_before}) requires mapping or review; run without the gate to inspect all changes",
          )
        }
      }
    }
  }
  @stdio.stdout.write(@jieheng.encode_catalog_migration(r) + "\n")
}
