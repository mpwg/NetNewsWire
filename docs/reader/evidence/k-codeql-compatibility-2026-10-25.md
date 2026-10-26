# K: CodeQL execution and supported-toolchain gap

Checked on 2026-10-25 at ed8e9f8a9. This narrows the remaining investigation; it does not close #56 or establish successful Swift security analysis. [Structured observations](k-codeql-compatibility-2026-10-25.json).

Rechecked on 2026-10-26 for ee2cefe14: the linked manufacturer requirements still restrict the SDK-27 host/toolchain combination to build mode none, while Swift supports only autobuild/manual; the language table still ends at Swift 6.3. [CodeQL 40247860085 / Swift job 121333161631](https://github.com/mpwg/NetNewsWire/actions/runs/40247860085/job/121333161631) again uses CLI 2.27.3 and exits 139 in preload_tracer/autobuild before analysis. Actions, Python and JavaScript/TypeScript pass. No setting or coverage is changed; the exact crash cause remains unproved.

## Observed execution

[CodeQL 40238561575 / Swift job 121305244261](https://github.com/mpwg/NetNewsWire/actions/runs/40238561575/job/121305244261) uses CLI **2.27.3** on macos-26-arm64 image **20261013.0424.1**, macOS **26.6.2 (25G83)**. It exits 139 in preload_tracer while invoking Swift autobuild, before analysis. The three Actions, Python and JavaScript/TypeScript jobs pass. The job does not emit an actual selected Xcode version before the crash. Its [pinned image manifest](https://github.com/actions/runner-images/blob/macos-26-arm64/20261013.0424/images/macos/macos-26-arm64-Readme.md) lists Xcode 26.6 as the default and no SDK 27. That is an image declaration, not a captured xcode-select result.

The exact crash cause remains **unproved**. In particular, this job is not evidence that macOS 27 itself caused the crash. An earlier intermittent successful Swift run is retained as historical evidence; it does not validate the current complete Reader.

GitHub default setup remains configured, with the existing languages, default query suite, remote threat model and weekly schedule unchanged. The connector provides job logs but no default-setup endpoint; its read-only configuration was inspected through `gh api repos/mpwg/NetNewsWire/code-scanning/default-setup`. No repository workflow or security setting was changed, and no check was disabled.

## Independent compatibility constraint

GitHub's current [supported-language table](https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/) lists Swift 5.4–6.3. Its [system requirements](https://codeql.github.com/docs/codeql-overview/system-requirements/) restrict macOS 27, and macOS 26 with Xcode 27 selected, to build mode `none`. The [Swift build reference](https://docs.github.com/en/code-security/reference/code-scanning/codeql/build-options-for-compiled-languages#building-swift) supports only `autobuild` and `manual` for Swift. These documented limits leave no supported complete Swift scan for the required Reader SDK-27 stack today. A manual traced build does not remove that platform constraint.

Reader's [native CI configuration](../../../.github/workflows/reader.yml) explicitly uses Xcode 27.1 and the OS-27 runner. ReaderKit requires macOS/iOS 27 and uses SDK-27 APIs. [Current Reader acceptance](h-file-export-2026-10-25.md) proves all 392 native Mac executions independently. The package's tools-version 6.2 declaration is not proof that the unchanged app can compile against SDK 26, or that the actual compiler is Swift 6.2.

The observed tracer crash and this supported-stack gap are separate facts. The latter remains even if the current crash can be eliminated. Downgrading the product SDK, stubbing new APIs, excluding ReaderUI/ReaderIntelligence, scanning only a compatible library subset, or reporting Swift build-mode `none` as full coverage would not satisfy the original objective.

## Criteria and next action

| Criterion | Status | Evidence / necessary action |
|---|---|---|
| Current failure, runner and CLI identified | Fulfilled | Terminal job and versioned observations above. |
| Exact tracer-crash cause established | Open | No diagnostic proves a specific binary/toolchain interaction. |
| Supported whole-Reader Swift analysis | Not currently verifiable | A CodeQL release/support matrix covering the actual SDK-27 compiler and traced host is required; then run the unchanged complete app and libraries and inspect extraction/analysis coverage. |
| Existing security coverage retained | Fulfilled | Default setup and all existing language jobs remain enabled and unchanged. |
| README and acceptance matrix | Updated | Root README, matrix and handoff link this scoped result. |

Recheck the manufacturer requirements before changing CI. Once an appropriate stack is supported, select that exact environment and prove complete extraction rather than treating a green job or partial database as sufficient. Until then, #56 and the umbrella remain open. This is an external analysis prerequisite, not an application test failure and not a whole-goal pause. Other native Mac acceptance work can continue.
