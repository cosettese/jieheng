///|
async fn main {
  run_cli() catch {
    e => @cli.exit_error(e)
  }
}

///|
async fn run_cli() -> Unit {
  let args = @env.args()
  if (args.length() != 4 && args.length() != 5) ||
    (args.length() == 5 && args[4] != "--require-complete") {
    raise @jieheng.Invalid(
      code="arguments",
      path="cli",
      message="usage: moon run cmd/coverage -- CATALOG.json START END [--require-complete]",
    )
  }
  let catalog = @jieheng.decode_catalog(@cli.read_input(args[1]))
  let gaps = @jieheng.catalog_gaps(catalog, args[2], args[3])
  if args.length() == 5 && gaps.length() > 0 {
    let first = gaps[0]
    raise @jieheng.Invalid(
      code="uncovered",
      path="coverage",
      message="\{gaps.length()} pricing gaps; first: metric '\{first.metric}' [\{first.starts_on}, \{first.ends_before}); run without --require-complete to inspect all gaps",
    )
  }
  let rows : Array[Json] = gaps.map(g => {
    "metric": g.metric,
    "starts_on": g.starts_on,
    "ends_before": g.ends_before,
  })
  let report : Json = {
    "schema": "jieheng.coverage.v1",
    "starts_on": args[2],
    "ends_before": args[3],
    "gaps": rows,
  }
  @stdio.stdout.write(report.stringify() + "\n")
}
