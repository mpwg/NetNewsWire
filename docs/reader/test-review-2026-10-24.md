# Reader test and infrastructure review — 2026-10-24

The contract tests remain useful. The original native macOS test setup and its diagnosis needed correction. The project infrastructure is being migrated to Apple's Xcode templates, created and maintained through Xcode MCP, at the owner's request.

## Findings and disposition

| Finding | Evidence | Disposition |
|---|---|---|
| The macOS test launch suppressed the initial window | With `-ApplePersistenceIgnoreState YES`, XCTest initially reported zero windows. Command-N then created the first window, while the original second test expected a second window. Removing that launch argument allows the original typed button/text-field queries to work. | Keep an explicit assertion that exactly one window appears on launch, without a keyboard workaround. The full baseline Mac plan subsequently passed through Xcode MCP. |
| The Accessibility diagnosis was invalid | The generated XCTest runner is sandboxed. Its direct `AXIsProcessTrusted=false` / `AXUIElement` result does not establish that XCTest's separate automation service lacks permission. The same test failure occurred on the hosted runner. | Remove the misleading direct-AX diagnostic and correct the acceptance record. The owner enabled Xcode Helper; do not claim that this alone fixed the tests. |
| The original two-window test could pass without proving concurrent isolation | It dismissed the draft in B before opening A and addressed windows by changing array positions. | Bind windows by their identifiers; keep both sheets open and verify that cancelling A leaves B's draft intact. Raise A before interacting with a control obscured by B. |
| The custom project generator diverged from normal Xcode authoring | Flat file references initially made files discoverable but not editable through Xcode MCP. The generator also owned the project, scheme and test plan. | Replace this infrastructure with an Xcode-MCP-created native project. Keep the existing Swift packages and application implementation. Remove the generator once the replacement is verified. |
| Some async test gates have no bounded, cancellation-aware wait | `ReaderSessionTests` and several `DigestTests` wait on manually resumed continuations. An early production failure can leave a test waiting for a gate that will never be entered. | Add cancellation-safe gates and explicit limits when maintaining these suites. A time-limit annotation alone is insufficient for a continuation that ignores cancellation. |
| The aggregate shell runner stops after the first failed platform | `set -e` stops `all` on a failed Mac run, so it does not collect iPhone/iPad results. CI's independent matrix jobs correctly use `fail-fast: false`. | Preserve failure propagation; improve local aggregation if this runner is retained after native-project migration. Do not describe a partial local run as complete platform coverage. |
| External integrations and model quality are not established by fixtures | HTTP tests use URLProtocol scripts; summary tests use deterministic fake generators. UI smoke tests do not disable networking or exercise a real account. | Keep these as code contracts. Keep real FreshRSS, PCC, offline operation, content quality, device and accessibility criteria open until exercised in the required mode. |

## Test strategy

Most coverage belongs in code tests: canonical article versions, rollback, exact outbox acknowledgement, stale-result rejection, pagination, source retention, request cancellation, OPML metadata and digest revision semantics. Swift Testing is appropriate for these contracts; migrating native XCUIAutomation tests away from XCTest would be incorrect.

The small native suite should establish launch/window behavior and independent sheets. It should not duplicate the synchronization and digest test matrix through slow UI interactions. English is the source language; tests should identify controls by stable IDs rather than translated labels.

The separate recovery probe uses the shipping SwiftData core with 10,000 synthetic articles across three actual processes, including SIGKILL. It is valid evidence for core process recovery. It does not establish complete application UI recovery, FreshRSS synchronization, or device behavior.

## Baseline evidence before native-project migration

Xcode MCP `RunAllTests`, Reader scheme on My Mac, completed with **87 passing executions, zero failures and zero skips**: 79 distinct contract tests plus two native UI tests; parameterized contracts account for the remaining executions.

Result bundle:
`/var/folders/b5/h7f8ws9x5cj4_5n6rtgypdhh0000gn/T/ActionArtifacts/default/RunAllTests/Test-Reader-2026.10.24_19-57-38-+0200.xcresult`

The successful launch assertion did not create a window through Command-N. Command-N is used only to request the second window. The successful independent-sheet test keeps B's draft present while opening and dismissing A's sheet.

Hosted baseline run [40116159532](https://github.com/mpwg/NetNewsWire/actions/runs/40116159532): iPhone and iPad jobs succeeded; the Mac job compiled successfully, then failed in the original window setup. The earlier Icon fixture compile failure is therefore resolved on the hosted Mac compiler. This is not a green overall CI run.

The native replacement project is not accepted by this baseline result. It requires its own current builds, test-plan inspection and native execution after package linking and configuration are complete.

## Native replacement and compiler-policy verification

The native project is `Reader/Reader.xcodeproj`, created through Xcode MCP with Apple's multiplatform app template. Existing contracts moved into the unhosted ReaderTests target, linked to the six ReaderKit libraries. ReaderUITests retains native XCUIAutomation. The shared scheme uses Apple's automatic test plan; CI builds this committed project without generation. Superseded root-project cleanup awaits remaining Release/configuration checks and preservation of user edits.

All three native targets enable Approachable Concurrency and Swift/C-family compiler warnings as errors without configuration restrictions. All seven ReaderKit targets share `InferIsolatedConformances`, `NonisolatedNonsendingByDefault` and `.treatAllWarnings(as: .error)`. The other three Approachable features are enabled by Swift 6 language mode. Current native builds exercise the six libraries; fresh recovery-probe compilation remains to verify.

The owner's no-spaces naming convention supersedes the sentence-identifier recommendation in modernize-tests. Code-test identifiers now use English lowerCamelCase; readable descriptions remain in `@Test("…")`, including parameterized tests and existing traits. This follows [Swift API naming conventions](https://www.swift.org/documentation/api-design-guidelines/) and [Apple's separate test display-name API](https://developer.apple.com/documentation/testing/definingtests). XCTest UI methods retain their required `test` prefix.

With mixed package/test concurrency settings, ControlledGenerator's live-consent overload was not reached and three tests waited indefinitely. The fixture now uses bounded, cancellation-aware waits; new tests verify missing-start failure and cancellation. The package graph initially retained old settings in the managed MCP context. Resolving packages and updating through the actual Xcode window context refreshed them. Full recompilation was necessary after the signature change; a further FreshRSS URLProtocol Task capture was corrected with explicit `@Sendable` and immutable captures. Temporary recompilation settings were removed before final incremental verification. Do not disable Approachable Concurrency to bypass these failures.

Current Xcode MCP full native runs, all without failures, skips or expected failures:

| Destination | Distinct tests | Executions | Result bundle |
|---|---|---|---|
| My Mac / macOS 27.0.1 | 81 code + 2 UI | 89 | `Test-Reader-2026.10.24_20-56-35-+0200.xcresult` |
| iPhone Duo / iOS 27.1 Simulator | 81 code + 1 UI | 88 | `Test-Reader-2026.10.24_20-57-27-+0200.xcresult` |
| iPad Pro 13-inch (M5) / iOS 27.0 Simulator | 81 code + 1 UI | 88 | `Test-Reader-2026.10.24_20-59-00-+0200.xcresult` |

All bundles are under `/var/folders/b5/h7f8ws9x5cj4_5n6rtgypdhh0000gn/T/ActionArtifacts/default/RunAllTests/`. Counts are verified from the raw xcresult summary and device execution counts. MCP's inline iOS result incorrectly includes the Mac-only window test and reports 89; that extra entry is not acceptance evidence. The code suite has two parameterized contracts with eight cases in total, adding six executions to the distinct-test count.

The normal incremental Mac run is green after complete recompilation; the additional whole-module diagnostic run at `20-55-44` also passed 89 executions. Compiler logs contain both upcoming-feature flags and `-warnings-as-errors`. An Xcode MCP snippet in ReaderDomain confirms both features enabled. Build-tool messages about skipped App Intents metadata extraction are separate from compiler warnings.

The aggregate CI runner now continues across all platforms after a failed platform and reports failure overall. Every build/signature failure returns before test-without-building, preventing stale-product execution. Three Python runner contracts cover successful native-project calls, each platform's injected test failure and an injected build failure. Shell syntax, Actionlint and whole-repository SwiftLint pass. No physical-device, real FreshRSS/PCC, broad accessibility or product-quality acceptance follows from these results.

## Current localization and Release follow-up

The latest [native verification record](evidence/native-2026-10-24.md) supersedes the earlier migration counts above. English source with German catalogs, compiled resource tests, native Debug/Release configuration checks and fresh process recovery are now verified. Current results: Mac 86 distinct tests / 99 executions; iPhone/iPad 85 / 98 each, no failures or skips. Of these, 84 are code contracts; only two Mac / one iOS checks require UI automation.

Hosted run 40123747892 passed the strict native Mac test build and process probe, then exposed completely overlapping windows on its small display. The old `first.click()` fell back to a point inside the front window and failed to raise the intended scene. The test now uses native Command-backtick cycling and a bounded hittability wait before clicking A. The first-form test likewise waits for hittability after existence instead of assuming the layout is ready immediately. The current local full plan passes; current hosted acceptance remains open.

Three parameterized code tests execute ten English/German language, HTTP-formatting and plural cases against Xcode's generated String Catalog resources. They do not duplicate the feature matrix through UI scripts. Developer/model instructions are English; model output follows the current locale, with actual multilingual quality still requiring separate acceptance. Fresh recovery uses an executable built through Xcode MCP, passed with the orchestrator's optional `--executable` argument.

## Hosted Simulator startup follow-up

The corrected Mac job in run 40126819993 succeeds. iPhone/iPad jobs in both that run and 40123747892 fail while launching parallel Simulator clones, with Apple's service-hub/lockdown connection failure or 120-second timeout. These failures do not prove execution of the simulator code/UI suite. Local MCP simulator runs remain separate successful evidence.

The CI script now requests `-parallel-testing-enabled NO` to avoid parallel target clones while keeping every test case. Contract tests assert the flag and unchanged platform/error behavior. The workflow bounds each job to 20 minutes. The next actual hosted run must establish whether this resolves startup; no success is inferred from the script change. The shared launch-scheme Debug default is also being reconciled after the temporary Release check, although actual Debug launch and storage are already verified.

## Gate cleanup and result-scope audit

The remaining HTTP/OPML/query fixtures had the same unchecked-continuation risk as the generator. They now share a bounded, cancellation-aware RequestGate, also used by ControlledGenerator and per-query gates. The actor retains early release instead of losing the signal; deadlines use ContinuousClock, and Task.sleep/checkCancellation cooperates with cancellation. Two new contracts cover early release and an unreleased gate; existing generator contracts cover missing entry and cancellation. No unbounded checked continuations remain in ReaderTests.

Current code coverage is 86 distinct contracts / 99 case executions. Full iPhone verification passes 87 distinct tests / 100 executions. Mac/iPad suite-scoped code runs pass 99 each. The latest local Mac overall run failed its two unchanged UI tests because the app could not be activated from Running Background. This is preserved as a failure and is not diagnosed speculatively as a privacy or lock-screen issue. The unchanged UI suite is green in hosted c44b99642, whose Mac/iPhone/iPad jobs all succeed. Current fixture-only changes still require a hosted rerun.

Result handling also needs care: the GUI MCP export can omit Info.plist from copied simulator bundles. Original DerivedData result bundles remain readable and are the authoritative count source. A diagnostic call selecting individual functions returned fewer parameter cases than expected; suite-scoped selection and full-plan execution retain the full 18-case parameter matrix. The [native record](evidence/native-2026-10-24.md) gives exact original paths and scopes. Never infer complete parameter coverage or a green overall plan from selected-test success.
