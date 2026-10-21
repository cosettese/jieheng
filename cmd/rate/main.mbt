///|
async fn main {
  run_cli() catch {
    @jieheng.Invalid(code~, path~, message~) => {
      @stdio.stderr.write("\{code}: \{path}: \{message}\n")
      @sys.exit(2)
    }
    e => {
      @stdio.stderr.write("runtime: \{e}\n")
      @sys.exit(1)
    }
  }
}

///|
async fn run_cli() -> Unit {
  let args = @env.args()
  if args.length() != 5 {
    raise @jieheng.Invalid(
      code="arguments",
      path="cli",
      message="usage: moon run cmd/rate -- PLAN.json USAGE.json SCALE half-even|half-up|down|up",
    )
  }
  let scale = @string.parse_int(args[3]) catch {
    _ =>
      raise @jieheng.Invalid(
        code="scale",
        path="cli.scale",
        message="expected an integer from 0 to 18",
      )
  }
  let rounding : @jieheng.Rounding = match args[4] {
    "half-even" => HalfEven
    "half-up" => HalfUp
    "down" => Down
    "up" => Up
    _ =>
      raise @jieheng.Invalid(
        code="rounding",
        path="cli.rounding",
        message="choose half-even, half-up, down, or up",
      )
  }
  let plan = @jieheng.decode_plan(read_input(args[1]))
  let usage = @jieheng.decode_usage(read_input(args[2]))
  let result = @jieheng.rate(plan, usage)
  let settlement = @jieheng.settle(result, scale~, rounding~)
  let output = StringBuilder()
  output.write_string("\{result.plan_id}@\{result.plan_version}\n")
  output.write_string(
    "\{usage.customer} / \{usage.period} / \{usage.quantity} \{result.unit}\n",
  )
  for line in result.lines {
    output.write_string(
      "tier \{line.tier}: \{line.quantity} x \{line.unit_price} = \{line.subtotal}\n",
    )
  }
  output.write_string("exact: \{result.currency} \{result.total}\n")
  output.write_string(
    "settled: \{settlement.currency} \{settlement.amount} (delta \{settlement.delta})\n",
  )
  @stdio.stdout.write(output.to_string())
}

///|
async fn read_input(path : String) -> String {
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let buffer = @buffer.Buffer()
  for ;; {
    match file.read_some(max_len=65536) {
      None => break
      Some(bytes) => {
        if bytes.length() > 4194304 - buffer.length() {
          raise @jieheng.Invalid(
            code="size",
            path~,
            message="input file exceeds 4 MiB",
          )
        }
        buffer.write_bytes(bytes)
      }
    }
  }
  @utf8.decode(buffer.to_bytes()) catch {
    _ =>
      raise @jieheng.Invalid(
        code="encoding",
        path~,
        message="input must be valid UTF-8",
      )
  }
}
