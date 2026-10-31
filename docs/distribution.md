# Distribution and installation

The module remains cosettese/jieheng. Its source version is recorded in moon.mod; a Git push is not a Mooncakes publication. Check the registry before assuming a particular version is installable.

## Published 0.8.0

On 2026-10-31, `cosettese/jieheng@0.8.0` was published from clean source commit `4c85a4c2e2662f66b808300c802f78562383c6ee` using the authorized `cosettese` account. The server returned HTTP 200. The dry-run server returned HTTP 202 with an explicit success message, although the CLI returned exit code 1 for that dry-run.

`moon run scripts/distribution.mbtx portable registry` then passed in a fresh consumer directory with no local library copy or `moon.work`: strict checking for all targets, followed by two passing consumer workflow tests on each of Wasm, Wasm-GC and JavaScript. This registry run did not execute Native. The source commit's CI separately verifies Native execution; those are different checks.

To install in a downstream module:

~~~text
moon add cosettese/jieheng@0.8.0
~~~

Import `cosettese/jieheng` in `moon.pkg` as shown in the [consumer example](../integration/consumer/moon.pkg). The publication archive contains the pre-publication README and changelog; this repository update records the successful release without republishing the same version.

## Verified archive

~~~text
moon run scripts/distribution.mbtx portable archive
~~~

This uses the official moon package command, inspects the real ZIP member list, rejects development workspace/nested-module/build-cache leakage, extracts into a new directory and runs the separate consumer module against the extracted package. It checks all targets and executes Wasm, Wasm-GC and JavaScript consumer tests. The all profile also executes Native and requires a C toolchain.

The archive excludes moon.work and integration/ using .moonignore. It retains the library, CLI packages, source tests, source documentation, examples, license and provenance. No include/exclude manifest fields are used. This policy follows the [official module documentation](https://docs.moonbitlang.com/en/stable/toolchain/moon/module.html).

Archive inspection requires tar; extraction uses tar on Windows and unzip on Linux/macOS. Logs and a JSON result are retained in the printed temporary directory. Toolchain/dependency caches may be reused; this is not a claim of an offline build.

## Registry release

1. Review CHANGELOG.md, public interfaces, compatibility notes and the actual package listing.
2. Run complete snapshot CI and archive-consumer verification for that exact source.
3. Check moon whoami and the target namespace; run moon publish --dry-run before an actual publish. Do not rename a module to bypass missing permissions.
4. Publish the reviewed version using an account authorized for cosettese/jieheng.
5. Verify installation with no local workspace override:

~~~text
moon run scripts/distribution.mbtx portable registry
~~~

Registry mode creates only the consumer module in a fresh directory, updates the index, and resolves the exact dependency declared in integration/consumer/moon.mod. It does not copy the library or write a moon.work. Failure is reported; it is never described as a successful registry installation. Use all on a machine with a C toolchain.

After registry verification, an application can declare the exact published module version in its moon.mod and import cosettese/jieheng in moon.pkg. The separate [consumer source](https://github.com/cosettese/jieheng/tree/main/integration/consumer) is the complete example; [API policy](api-policy.md) documents compatibility and input boundaries.
