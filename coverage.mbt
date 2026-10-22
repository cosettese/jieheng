///|
/// A maximal uncovered half-open interval for one required catalog metric.
pub(all) struct CatalogGap {
  metric : String
  starts_on : String
  ends_before : String
} derive(Debug, Eq)

///|
pub extend CatalogGap with Debug::{to_repr}

///|
pub extend CatalogGap with Eq::{equal, not_equal}

///|
/// Inspect every required metric over [starts_on, ends_before), without usage
/// samples or day-by-day expansion. Results follow catalog metric order, then
/// chronological order. Empty results mean complete date coverage only.
pub fn catalog_gaps(
  catalog : Catalog,
  starts_on : String,
  ends_before : String,
) -> Array[CatalogGap] raise PricingError {
  let start = date_key(starts_on, "coverage.starts_on")
  let end = date_key(ends_before, "coverage.ends_before")
  if end <= start {
    invalid("interval", "coverage", "end must be strictly after start")
  }
  let gaps : Array[CatalogGap] = []
  for metric in catalog.metrics {
    let mut cursor = start
    let mut cursor_text = starts_on
    for dated in catalog.entries {
      if tariff_info(dated.entry.tariff).metric != metric ||
        (dated.end is Some(n) && n <= cursor) {
        continue
      }
      if dated.start >= end {
        break
      }
      if dated.start > cursor {
        gaps.push({
          metric,
          starts_on: cursor_text,
          ends_before: dated.entry.starts_on,
        })
      }
      match dated.end {
        None => {
          cursor = end
          break
        }
        Some(n) => {
          if n >= end {
            cursor = end
            break
          }
          cursor = n
          cursor_text = dated.entry.ends_before.unwrap()
        }
      }
    }
    if cursor < end {
      gaps.push({ metric, starts_on: cursor_text, ends_before, })
    }
  }
  gaps
}
