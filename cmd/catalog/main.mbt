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
      message="usage: moon run cmd/catalog -- CATALOG.json YYYY-MM-DD USAGES.json SCALE ROUNDING [--json | --verify RECORD.json]",
    )
  }
  let catalog = @jieheng.decode_catalog(@cli.read_input(args[1]))
  let usages = @jieheng.decode_usage_bundle(@cli.read_input(args[3]))
  let scale = @cli.scale(args[4])
  let rounding = @cli.rounding(args[5])
  if args.length() == 8 {
    let r = @jieheng.decode_catalog_bill(@cli.read_input(args[7]))
    @jieheng.verify_catalog(catalog, args[2], usages[:], r, scale~, rounding~)
    @stdio.stdout.write(
      "verified catalog bill: \{r.bill.currency} \{r.bill.totals.amount}\n",
    )
    return
  }
  let r = @jieheng.rate_catalog(catalog, args[2], usages[:], scale~, rounding~)
  let output = if args.length() == 7 {
    @jieheng.encode_catalog_bill(r)
  } else {
    "\{r.on}: \{r.bill.customer} / \{r.bill.period}\nsettled: \{r.bill.currency} \{r.bill.totals.amount}"
  }
  @stdio.stdout.write(output + "\n")
}
