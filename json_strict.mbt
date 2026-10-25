///|
fn parse_document(text : String) -> Json raise PricingError {
  if text.length() > 1048576 {
    invalid("size", "$", "JSON input exceeds 1048576 UTF-16 code units")
  }
  let value = @json.parse(text, max_nesting_depth=32) catch {
    @json.DepthLimitExceeded =>
      raise Invalid(
        code="depth",
        path="$",
        message="maximum JSON nesting depth is 32",
      )
    e => raise Invalid(code="json", path="$", message="invalid JSON: \{e}")
  }
  // Core's Json object model is a map. Inspect original string tokens as well,
  // so duplicate names (including escaped aliases) cannot be silently replaced.
  let objects : Array[Map[String, Unit]] = []
  let mut i = 0
  let mut depth = 0
  while i < text.length() {
    match text[i] {
      '{' => {
        objects.push(Map([]))
        depth += 1
        i += 1
      }
      '}' => {
        ignore(objects.pop())
        depth -= 1
        i += 1
      }
      '[' => {
        depth += 1
        i += 1
      }
      ']' => {
        depth -= 1
        i += 1
      }
      '"' => {
        let start = i
        i += 1
        while i < text.length() && text[i] != '"' {
          i += if text[i] == '\\' { 2 } else { 1 }
        }
        i += 1
        let end = i
        while i < text.length() &&
              (
                text[i] == ' ' ||
                text[i] == '\n' ||
                text[i] == '\r' ||
                text[i] == '\t'
              ) {
          i += 1
        }
        if i < text.length() && text[i] == ':' {
          let decoded = @json.parse(text[start:end]) catch {
            _ =>
              raise Invalid(
                code="json",
                path="$",
                message="invalid object name",
              )
          }
          if decoded is String(key) {
            let names = objects[objects.length() - 1]
            if names.contains(key) {
              invalid(
                "duplicate",
                "$",
                "duplicate key '\{key}' at UTF-16 offset \{start}",
              )
            }
            names[key] = ()
          }
        }
      }
      _ => i += 1
    }
    if depth > 32 {
      invalid("depth", "$", "maximum JSON nesting depth is 32")
    }
  }
  value
}

///|
fn fields(
  value : Json,
  names : ArrayView[String],
  path : String,
) -> Map[String, Json] raise PricingError {
  guard value is Object(object) else {
    invalid("type", path, "expected an object")
    return Map([])
  }
  for key, _ in object {
    if !names.contains(key) {
      invalid(
        "unknown",
        path + "." + key,
        "unsupported field; input is rejected rather than discarded",
      )
    }
  }
  for name in names {
    if !object.contains(name) {
      invalid("missing", path + "." + name, "required field is missing")
    }
  }
  object
}

///|
fn text_value(value : Json, path : String) -> String raise PricingError {
  guard value is String(text) else {
    invalid(
      "type", path, "expected a string; quantities and prices must not be JSON numbers",
    )
    return ""
  }
  text
}

///|
fn expect_value(
  object : Map[String, Json],
  key : String,
  expected : String,
  path : String,
) -> Unit raise PricingError {
  if text_value(object[key], path + "." + key) != expected {
    invalid("unsupported", path + "." + key, "only '\{expected}' is supported")
  }
}
