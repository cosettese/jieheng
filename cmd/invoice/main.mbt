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
      message="usage: moon run cmd/invoice -- INPUT.json SCALE ROUNDING [--json | --verify INVOICE.json]",
    )
  }
  let items = @jieheng.decode_invoice_input(@cli.read_input(args[1]))
  let scale = @cli.scale(args[2])
  let rounding = @cli.rounding(args[3])
  if args.length() == 6 {
    let invoice = @jieheng.decode_invoice(@cli.read_input(args[5]))
    @jieheng.verify_invoice(items[:], invoice, scale~, rounding~)
    @stdio.stdout.write(
      "verified invoice: \{invoice.currency} \{invoice.amount}\n",
    )
    return
  }
  let invoice = @jieheng.rate_invoice(items[:], scale~, rounding~)
  let output = if args.length() == 5 {
    @jieheng.encode_invoice(invoice)
  } else {
    let lines : Array[String] = ["\{invoice.customer} / \{invoice.period}"]
    for charge in invoice.charges {
      lines.push(
        "\{charge.calculation.usage.metric}: usage \{charge.calculation.total} + top-up \{charge.top_up} = \{charge.total}; settled \{charge.settlement.amount}",
      )
    }
    lines.push(
      "settled: \{invoice.currency} \{invoice.amount} (rounding delta \{invoice.delta})",
    )
    lines.join("\n")
  }
  @stdio.stdout.write(output + "\n")
}
