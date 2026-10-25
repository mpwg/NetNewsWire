# Reader-only repository — 2026-10-25

## Decision and removal

The owner explicitly requested immediate deletion of unused legacy files, relying on Git history. This supersedes the earlier retirement-after-acceptance timing rule. It does not accept unfinished Reader behavior or close platform/audit requirements. The preceding Reader implementation and refresh repair are recorded at c6ebcdaf7.

The cleanup deletes 1,337 tracked files (222,723 lines), including the original Mac/iOS apps, Shared, Modules, Widget, AppleScript, Resources, Themes, AppStore/Appcasts/Technotes, original tests/projects/test plans, build scripts/xcconfig, obsolete repository policies and superseded root Reader.xcodeproj/ReaderApp. Ignored build output and obsolete workspace metadata were also removed. No archive copy or compatibility project is retained in the repository.

Reader/Reader.xcodeproj is the sole application project. ReaderKit/Package.swift defines the six active libraries and independent store-recovery probe. Active source, current CI, recovery orchestration, evidence, the root MIT notice and required Mozilla extraction resources/license remain. The legacy iOS/Resources/Info.plist was clean before its authorized removal; unrelated active changes must still be preserved.

## Test strategy

All code-testable behavior belongs in Swift Testing. The former Python runner unit suite is replaced by three native Swift Testing functions / five executions: successful all-platform aggregation, each platform's test failure and preventing stale tests after a failed build. CI runs this suite directly before trusting the aggregate script. Python remains only as process orchestration for the real SwiftData recovery executable.

Two Swift Testing functions / seven executions exercise connection validation with isolated credentials, HTTP transport and storage: six invalid inputs cause no HTTP, credential save or account write; valid input actually connects and persists the account. The corresponding business-validation assertion was removed from the UI test. No validation is covered only by UI automation.

The five remaining native UI methods cover automatic first-window creation and sheets, two-window draft isolation, keyboard range selection/context menus, input/scrolling during held work and actual view-disappearance cancellation. Their service and presentation logic also has code contracts; UI automation proves the platform interaction only.

## Current verification

- Xcode MCP built the native Reader-only project for testing after legacy removal.
- The full My Mac plan passes **134 Swift Testing functions plus five native UI methods / 226 executions**: 139 distinct tests, 31 parameterized functions / 118 cases, no failures, skips or runtime warnings.
- Original authoritative bundle: `/Users/mat/Library/Developer/Xcode/DerivedData/Reader-fuevgxanyutuuihcfejpioljllaa/Logs/Test/Test-Reader-2026.10.25_15-39-40-+0100.xcresult`.
- [Versioned raw summary](k-reader-only-native-2026-10-25.json). A focused run of both new code suites passes all twelve executions.
- Strict SwiftLint, shell syntax and Actionlint pass. Actionlint excludes only its obsolete runner-label catalogue entry for the already exercised xcode-27 runner.
- Hosted verification of the changed single Reader workflow is pending at this checkpoint; the workflow retains strict lint, direct Swift runner contracts, the complete native plan and process recovery. Automatic testing remains Mac-first; manual all-platform coverage remains available.

Source retirement is fulfilled. K/#56 remains open for actual platform/accessibility/offline acceptance, representative load/energy/distribution and unresolved Swift CodeQL analysis. Final iPhone/iPad, PCC entitlement and model/feed quality requirements are unchanged. The deferred real Mac network-off run is not re-requested.

## Separate CodeQL result

At e61b2fa26, [CodeQL run 40204058261](https://github.com/mpwg/NetNewsWire/actions/runs/40204058261) fails outside Reader tests. Its [Swift job 121201115860](https://github.com/mpwg/NetNewsWire/actions/runs/40204058261/job/121201115860) again exits 139 in preload_tracer/autobuild before analysis. This failure is intermittent: the earlier Swift job 121190509088 in run 40200513521 at 410887e7c completed analysis successfully. Source cleanup is not evidence of fixing or causing the tracer crash.

The first cleanup run also retains a stale Ruby matrix entry; job 121201115930 fails with no Ruby source, as expected after original tooling removal. GitHub's automatic default-setup language configuration subsequently excludes Ruby (observed updated_at=2026-10-25T14:49:52Z). No security check was manually disabled or narrowed. The next run must confirm that automatic update. Reader test/lint success does not imply repository-wide security-analysis success.
