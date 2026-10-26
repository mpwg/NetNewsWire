# I: Reader-owned numeric references — 2026-10-26

Status: **opt-in research only, not adopted**. The owner retains free app-language summaries. Main remains policy v5.

The preceding long draft changes source250000 into250.000 and inserts inline citation digits. Numeric validation correctly rejects it. Rather than normalizing model output or relaxing source checks, the new package-only `protectNumericLiterals` option replaces numeric literals in an isolated draft's input with Reader-assigned `⟦readerNumber:packet:slot⟧` markers. The planner may still inspect source numbers; the fresh drafting session receives only masked text/focus. Reader restores markers from its own literal table for packets actually cited by that draft. Unknown/malformed/uncited markers and source namespace collisions fail closed. Unmasked unsupported values and inline citation numbers still face the existing unchanged per-reference numeric/URL validator.

The option requires isolated selected-evidence drafting and defaults false. `--trace --isolate --sentences --numbers` enables it only in the owned probe. No text normalization, price calculation, numeric-format guessing, reviewer, model tool or app mutation is introduced. Marker expansion and instructions are counted on the actual draft request before execution. This protocol does not prove semantic entailment, preserve every condition by itself, recognize spelled-out numbers, or make the model infallible. Native restoration proves literal/origin handling only.

## Current code criteria

| Criterion | Status | Evidence |
|---|---|---|
| Exact original numeric punctuation, repeated values and Unicode round-trip | Fulfilled on current Mac candidate | Five pure Swift Testing cases exercise original strings, decimal/group separators, clock/date fragments and nonnumeric text. |
| Malformed/unknown/uncited references, spoofed namespace and unrelated numbers | Fulfilled on current Mac candidate | Eight pure negative cases plus five actual native draft cases; equal prices from a different uncited packet remain distinct. |
| Actual native masked context/focus, exact restored value and original identity | Fulfilled on current Mac candidate | Controlled LanguageModelExecutor inspects the actual JSON and returns a marker; Reader emits source250000 and the exact ArticleKey. |
| Expanded JSON budget and invalid option combination | Fulfilled on current Mac candidate | Native cases reject before draft/model execution with exact request counts. |
| Existing focus/context, source checks, cancellation/consent and store/coordinator behavior | Fulfilled for exercised Mac code boundary | All69 intelligence functions /166 executions pass through Xcode MCP, no failures/skips. |
| Actual long/news/conditions/offers/injection quality and representative sources | Open | Fixed changed-source model series pending; no prior result is relabelled. |
| Full current CI, PCC/final platforms/offline/accessibility/performance/distribution | Open | New code is not accepted by previous CI; external prerequisites/deferrals remain explicit. |

Xcode MCP app/test build16:27:44, native run16:28:10 and package probe build16:29:21 pass. Strict SwiftLint0.65.1 and whitespace checks pass. [Original native summary](i-number-code-summary-2026-10-26.json), [all module nodes](i-number-code-cases-2026-10-26.json). Discovery has262 enabled distinct functions, none disabled. No UI test/app launch or account data is involved. MCP file creation reported an insertion-mode error while writing the helper; its actual file was read back through MCP and discovered by native SwiftPM builds without project edits/generation.

Generator SHA-256 `b4d13d81d2862a4b6d28f6d2b11f6ccbc2628a5632c52481c88ec2a3cb474f25`; helper `d5a6c0f28c39a587c365a69736a4185046c75a0f19be0ba3c0a6de5d69bab78a`; probe `d06efd78b8731aa87f7154138ad817749d83a96e6652f7b2cf3b0e5e757c1558`.

The prior focused-context CI40347228928 is terminal failure only in lint (two redundant optional nil initializers, fixed at94e7315c3); its native job passes all528 executions, no failures/skips. Artifact12662602586 is downloaded and its ZIP SHA-256 `f723a2b42d6eb5021dce3c9b826c9f2234e62409ce42b3a0a07647adddc5f210` matches GitHub's digest. Preserve that result independently of any changed-source run. No candidate implementation is adopted; restore main's source/binaries before handoff.
