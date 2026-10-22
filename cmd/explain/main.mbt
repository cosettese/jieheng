///|
async fn main {
  run_cli() catch {
    e => @cli.exit_error(e)
  }
}

///|
async fn run_cli() -> Unit {
  let args = @env.args()
  if args.length() != 5 {
    raise @jieheng.Invalid(
      code="arguments",
      path="cli",
      message="usage: moon run cmd/explain -- INPUT.json BILL.json SCALE ROUNDING",
    )
  }
  let items = @jieheng.decode_bill_input(@cli.read_input(args[1]))
  let bill = @jieheng.decode_bill(@cli.read_input(args[2]))
  let scale = @cli.scale(args[3])
  let rounding = @cli.rounding(args[4])
  @stdio.stdout.write(
    @jieheng.render_bill_markdown(items[:], bill, scale~, rounding~),
  )
}
