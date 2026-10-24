# Reader acceptance — 2026-10-24

The existing Reader is implemented and partially verified; **full product acceptance remains open**. The active goal continues on `main` under [umbrella #45](https://github.com/mpwg/NetNewsWire/issues/45), packages #46–#56. Evidence below concerns Reader, not renewed acceptance of the original NetNewsWire targets.

## A / #46: current foundation

PR [#57](https://github.com/mpwg/NetNewsWire/pull/57) adopted `codex/intelligence-reader` (`2528bc1b8`) onto `main` as `4f9f256e5` before this continuation. The trees were identical; no second implementation or merge was needed. `iOS/Resources/Info.plist` was clean on resumption and remains unchanged.

Commit `96b05cbbe` fixed the hosted Icon URLProtocol fixture's task capture using explicit `@Sendable` and immutable captures. Hosted [run 40116159532](https://github.com/mpwg/NetNewsWire/actions/runs/40116159532) subsequently compiled on Mac and passed iPhone/iPad jobs; Mac failed in the original UI window setup. It is not a green overall CI run.

At the owner's request, Xcode MCP created `Reader/Reader.xcodeproj` directly from Apple's multiplatform app template. It preserves the existing app and six libraries. ReaderTests now contains the existing code contracts in a native **unhosted Swift Testing** target; ReaderUITests retains native XCTest/XCUIAutomation. The shared scheme uses Apple's automatic test plan. CI references this project and performs no generation. The older root Reader.xcodeproj/ReaderApp infrastructure remains temporarily pending Release/configuration verification and preservation of user edits.

| Criterion | Status | Evidence and remaining work |
|---|---|---|
| OS 27 builds and correct bundle IDs | Passed on native replacement | Native Debug builds/tests pass on Mac and iPhone/iPad Simulator; native Release builds pass on Mac and iOS Simulator. Expanded app Plists confirm minimum 27.0 and `eu.mpwg.reader.debug` / `eu.mpwg.reader`. The scheme is restored to Debug. |
| Real native tests and failure propagation | Local evidence passed; hosted acceptance open | Current native Mac: 84 distinct code tests plus two UI tests, 99 executions. iPhone/iPad: 84 code tests plus one UI test, 98 executions each. No failures or skips. Three runner contracts prove all-platform collection, failure propagation and refusal to test stale products after a failed build. Await current hosted workflow evidence. |
| Approachable Concurrency and warnings as errors | Enabled and verified | All three native targets enable `SWIFT_APPROACHABLE_CONCURRENCY`, `SWIFT_TREAT_WARNINGS_AS_ERRORS` and `GCC_TREAT_WARNINGS_AS_ERRORS`. All seven package targets share both remaining Swift 6 upcoming features and `.treatAllWarnings(as: .error)` without configuration restrictions. Native Debug/Release builds exercise the six libraries; the standalone probe also builds through Xcode MCP and passes fresh process recovery. |
| Separate persistent Debug/Release stores | Passed on native replacement | Actual native Mac launches without UI-test mode: Release PID 96200 and Debug PID 97086 opened SQLite/WAL/SHM files in their respective bundle-ID containers. See [native evidence](evidence/native-2026-10-24.md). |
| README and test review | Updated | Canonical Reader source and guides are English; German UI/error translations live in String Catalogs with tested plural forms. Native project, code-test emphasis, compiler policy and evidence are documented. Superseded root-project cleanup remains pending hosted acceptance. |
| SwiftLint and runner checks | Passed | Whole repository passes SwiftLint 0.65.1 `--strict`. Three Python runner contracts pass. Shell syntax and Actionlint pass, excluding only Actionlint's outdated known-label list for `xcode-27`. |

## Native test evidence with requested compiler settings

Environment: MacBook Pro arm64, macOS 27.0.1 (26A434), Xcode 27.1, Swift 6.4. Interactive builds and tests were executed through Xcode MCP. Full paths and detailed review: [test review](test-review-2026-10-24.md).

| Destination | Distinct tests / executions | Result bundle suffix under `ActionArtifacts/default/RunAllTests/` |
|---|---|---|
| My Mac, macOS 27.0.1 | 86 / 99 | `Test-Reader-2026.10.24_21-17-27-+0200.xcresult` |
| iPhone Duo, iOS 27.1 Simulator | 85 / 98 | `Test-Reader-2026.10.24_21-22-12-+0200.xcresult` |
| iPad Pro 13-inch (M5), iOS 27.0 Simulator | 85 / 98 | `Test-Reader-2026.10.24_21-22-56-+0200.xcresult` |

Counts come from each xcresult bundle's summary and device execution count. The MCP's inline iOS count incorrectly includes the Mac-only second-window test. No nonexistent iOS test is counted as acceptance.

The first Mac window appears automatically without Command-N. The second-window test keeps both connection sheets open and verifies independent drafts and cancellation. A hosted Mac failure showed completely overlapping windows on its small display; native Command-backtick cycling now replaces the obscured-window click, with a bounded hittability wait. Hosted revalidation remains open. The former direct-AX diagnosis was invalid: a sandboxed runner's `AXIsProcessTrusted=false` does not establish XCTest automation-service permissions. Removing the `-ApplePersistenceIgnoreState YES` launch argument fixed the suppressed initial window. The owner enabled Xcode Helper, but this alone is not claimed as the fix. VoiceOver and broad accessibility acceptance remain separate.

Approachable Concurrency initially exposed mixed cached module signatures and a further FreshRSS fixture task capture. After consistent package settings and full code-target recompilation, normal incremental builds and the full test plan pass. Temporary recompilation settings were removed. Compiler warning promotion remains enabled; Apple's build tool can still report skipped App Intents metadata extraction when the app has no AppIntents dependency.

## B / #47: persistence evidence

The existing ReaderStore implementation is unchanged. Commit `929b7b830` added a deletion-only query/count/retention contract and a separate executable using the shipping store.

| Criterion | Status | Evidence |
|---|---|---|
| Durable state after abrupt process termination | Passed on documented Mac core | Seed process killed with SIGKILL after commit marker, WAL 271,952 bytes. Two new native processes verify 10,000 synthetic articles, account, exact pending UUIDs, preferences, rollback and digest revision. |
| One complete canonical article version | Passed | Recovery checks title, HTML/text, URL, publication date and original arrival time together. The corresponding code contract passes across all three native destinations. |
| Deletion-only queries/counts and retained originals | Passed | Code test checks committed revision, removed identities and unread/star counts. Recovery retains the two originals protected by pending/star/digest references after unsubscribing, then verifies another process restart. |
| README | Updated | [B evidence](evidence/b-2026-10-24.md), [raw report](evidence/b-recovery-2026-10-24.json), module and Reader guides. |

B remains formally open while dependency A and current hosted evidence remain open. A fresh Xcode-MCP-built probe passed after localization/compiler changes: seed PID 96660, SIGKILL, recovery/reopen PIDs 96690/96692, 10,000 articles and exact retained revisions. [Current raw report](evidence/b-native-recovery-2026-10-24.json). The process probe is core recovery evidence, not full application UI recovery, physical-device behavior or real FreshRSS synchronization.

## Work-package matrix

| Package | Implemented or exercised evidence | Still open |
|---|---|---|
| A / #46 | Standalone OS-27 Reader, native Apple-template app/test targets, Debug/Release namespaces, local native tests, compiler policy and runner failure contracts | Current hosted CI success and safe retirement of superseded Reader project infrastructure; physical-device provisioning remains separate. |
| B / #47 | 25 persistence contracts and native SIGKILL recovery with 10,000 articles, exact outbox acknowledgements, rollback, retention, streams and atomic source/import validation | Dependency A; complete persistent-app UI restart, device and real service evidence remain separate. |
| C / #48 | FreshRSS HTTP/store contracts: complete pagination, old publication dates, exact acknowledgements, errors, empty folders and complete content | Real FreshRSS API login, multiple devices and offline recovery against an authorized test account. |
| D / #49 | Shared views, async search/pagination, generation checks, source access and frozen displayed revisions | Representative real feed content and full native keyboard/navigation acceptance. |
| E / #50 | Scene state, shared/debounced refresh, Mac automatic first window and simultaneous independent connection sheets | iPad multiwindow, resizing, RTL, complete keyboard, VoiceOver and Dynamic Type acceptance. |
| F / #51 | Nine content/OPML contracts: local extraction without page scripts, relative links, HTTP 403, timeout, changing content, size limits and atomic stale-write rejection | Real blocked pages, varied HTML/media and native reader rendering on target devices. |
| G / #52 | Device-local Keychain service; bounded icon requests, independent fallback, transient retry and cancellation contracts | Real Keychain-backed login, energy/image load and acceptance of UI icon usage. UI currently uses system symbols. |
| H / #53 | Nested OPML paths, homepage fallback, redirects, repeat imports and concurrent preference preservation | Confirm against real FreshRSS; remote categories remain flat with local hierarchy metadata. |
| I / #54 | Prior local Foundation Models experiment with two synthetic offer sources; dynamic budgets, structured sources and live consent | Apple PCC entitlement/provisioning and native PCC acceptance; broad language, long-text and quality evaluation. |
| J / #55 | Nine digest/fixture contracts including 250 sources, partial coverage, source revision, consent revocation and shared job ownership | Real Preisjäger feed and representative news quality, model/error variants and editorial review. |
| K / #56 | Mapping of all 40 audit findings, new dependency graph and retained legacy inventory | Complete replacement acceptance before removing legacy targets/code; physical devices, accessibility, sustained load and distribution. |

## Historical experiments and limits

Three local model calls with two synthetic offers produced two sourced sections with correct merchants/prices, around 1.6–1.7 seconds per inference. This is a narrow functional experiment, not systematic quality acceptance. A synthetic PCC probe reported availability but terminated when requesting without `com.apple.developer.private-cloud-compute`; the normal build therefore blocks the request before calling that API. Availability alone is not authorization.

A previous 10,000-article core load experiment measured insertion 0.82 s, first 200 articles 0.006 s, normalized search 0.007 s and 1,000 status changes 1.97 s. It did not compare legacy behavior or measure scrolling, energy or devices.

The owner explicitly closed 21 excluded audit issues as not planned: #2, #3, #4, #6, #7, #8, #9, #11, #13, #14, #18, #19, #20, #23, #24, #27, #28, #31, #32, #35 and #36. Superseded proposal #42 is not planned; #43/#44 are completed reports. These closures are not repairs or evidence of removed legacy code. The remaining 19 relevant audit issues and all implementation packages require criterion-specific evidence before closure.

Temporary result bundles can expire. Source fixtures, reproduction instructions and the recovery JSON are versioned. Continue from the [handoff](handoff-2026-10-24.md), preserving the existing implementation and unrelated user changes.
