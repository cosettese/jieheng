# Amazon S3 Standard storage price snapshot

This fixture uses **real public prices**, observed on 2026-10-21, and a **synthetic** aggregated quantity of 60,000 GB-Mo. It estimates only the selected storage SKU, not a complete AWS bill.

Source: [AWS AmazonS3 us-east-1 offer file](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonS3/current/us-east-1/index.json). The downloaded file had `publicationDate` = `2026-10-15T17:35:40Z`, product SKU `WP9ANXZGBYYSGJEA`, term `JRTCKXETXF`, effective date `2026-10-01T00:00:00Z`. SHA-256 of that complete source file: `a298361f29bd9bc926d810d1eb093720827275689c1e2db5a7af90890b1dc67c`. The `current` URL can change; use this metadata to identify the observation.

Product attributes: AmazonS3, US East (N. Virginia), Standard, General Purpose, `TimedStorage-ByteHrs`. The published price dimensions use `GB-Mo`:

| Rate-code suffix | Begin | End | USD per GB-Mo |
| --- | ---: | ---: | ---: |
| PGHJ3S3EYE | 0 | 51200 | 0.0230000000 |
| D42MF2PVJS | 51200 | 512000 | 0.0220000000 |
| PXJDJ3YRG3 | 512000 | Inf | 0.0210000000 |

Only these numerical price facts and identifiers were transcribed. AWS material is not relicensed under this project's Apache-2.0 license. No AWS source implementation or documentation prose was copied.

```text
moon run cmd/rate --target wasm -- examples/s3/plan.json examples/s3/usage.json 2 half-even
```

The expected exact total is `1371.2` and the settlement is `USD 1371.20`: `51200 × 0.023 + 8800 × 0.022`. There is no need for an AWS account or network access to run this checked-in fixture.

The quantity is an integer in the price list's **GB-Mo billing unit**. This project does not turn bytes, hours, or calendar months into GB-Mo, does not combine accounts or buckets, and does not include request charges, data transfer, minimum charges, taxes, free allowances, discounts, or any other SKU. Do not round a fractional production usage quantity to fit this example; choose an exact integer subunit and an exactly representable price, or reject unsupported precision upstream.
