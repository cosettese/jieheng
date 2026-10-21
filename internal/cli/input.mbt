///|
pub async fn read_input(path : String) -> String {
  read_bounded(path) catch {
    @jieheng.PricingError::_ as e => raise e
    e =>
      raise @jieheng.Invalid(
        code="file",
        path~,
        message="cannot read file; check path and permissions: \{e}",
      )
  }
}

///|
async fn read_bounded(path : String) -> String {
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

///|
pub fn scale(text : String) -> Int32 raise @jieheng.PricingError {
  let value = @string.parse_int(text) catch {
    _ =>
      raise @jieheng.Invalid(
        code="scale",
        path="cli.scale",
        message="choose an integer from 0 to 18",
      )
  }
  if value < 0 || value > 18 {
    raise @jieheng.Invalid(
      code="scale",
      path="cli.scale",
      message="choose an integer from 0 to 18",
    )
  }
  value
}

///|
pub fn rounding(text : String) -> @jieheng.Rounding raise @jieheng.PricingError {
  match text {
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
}

///|
pub async fn exit_error(error : Error) -> Unit {
  match error {
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
