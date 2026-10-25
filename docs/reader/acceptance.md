# Reader acceptance — updated 2026-10-25

Current owner direction: concentrate development verification on macOS and defer iPhone/iPad revalidation to final acceptance. Push/PR CI runs Mac; manual Reader OS 27 `coverage: all` retains the complete final matrix. Earlier platform results below remain historical evidence for their named checkpoints, not coverage of subsequent changes.

The existing Reader is implemented and partially verified; **full product acceptance remains open**. The active goal continues on `main` under [umbrella #45](https://github.com/mpwg/NetNewsWire/issues/45), packages #46–#56. Evidence below concerns Reader, not renewed acceptance of the original NetNewsWire targets.

## A / #46: accepted foundation

Accepted on 2026-10-25 at **2be912aef**: [current hosted run, attempt 2](https://github.com/mpwg/NetNewsWire/actions/runs/40172667411/attempts/2) passes Mac/iPhone/iPad. The shared Debug default is saved through Xcode. Current local full plans pass on all three destinations; their raw summaries and the failed first iPad hosted bootstrap are preserved in [A evidence](evidence/a-2026-10-25.md). No full product or physical-device acceptance is implied. Superseded infrastructure retirement stays in K with foreign edits preserved.

PR [#57](https://github.com/mpwg/NetNewsWire/pull/57) adopted `codex/intelligence-reader` (`2528bc1b8`) onto `main` as `4f9f256e5` before this continuation. The trees were identical; no second implementation or merge was needed. `iOS/Resources/Info.plist` was clean on resumption and remains unchanged.

Commit `96b05cbbe` fixed the hosted Icon URLProtocol fixture's task capture using explicit `@Sendable` and immutable captures. Hosted [run 40116159532](https://github.com/mpwg/NetNewsWire/actions/runs/40116159532) subsequently compiled on Mac and passed iPhone/iPad jobs; Mac failed in the original UI window setup. It is not a green overall CI run.

At the owner's request, Xcode MCP created `Reader/Reader.xcodeproj` directly from Apple's multiplatform app template. It preserves the existing app and six libraries. ReaderTests now contains the existing code contracts in a native **unhosted Swift Testing** target; ReaderUITests retains native XCTest/XCUIAutomation. The shared scheme uses Apple's automatic test plan. CI references this project and performs no generation. The unused Python generator has been removed after native CI success. The older root project/Info.plist remain to preserve user edits until K; they are not active build inputs. Release/namespace verification has passed. On 2026-10-25 Xcode saved the shared Debug launch default; its current native build, local full plans and hosted revalidation pass.

| Criterion | Status | Evidence and remaining work |
|---|---|---|
| OS 27 builds and correct bundle IDs | Passed on native replacement | Native Debug builds/tests pass on Mac and iPhone/iPad Simulator; native Release builds pass on Mac and iOS Simulator. Expanded app Plists confirm minimum 27.0 and `eu.mpwg.reader.debug` / `eu.mpwg.reader`. Actual Debug launch is verified; Xcode saved the shared Debug launch default on 2026-10-25 and its native Mac build passes. |
| Real native tests and failure propagation | Fulfilled at 2be912aef | Run 40172667411 attempt 2 passes Mac/iPhone/iPad: 86 Swift Testing contracts in 12 suites plus two Mac / one iOS UI tests. At that checkpoint local full plans pass 101/100/100 case executions. Three runner contracts prove aggregate/error behavior. The failed initial iPad hosted startup and prior local Mac activation failure remain documented; broad reliability is separate. Current Mac-only results are recorded under C/G. |
| Approachable Concurrency and warnings as errors | Enabled and verified | All three native targets enable `SWIFT_APPROACHABLE_CONCURRENCY`, `SWIFT_TREAT_WARNINGS_AS_ERRORS` and `GCC_TREAT_WARNINGS_AS_ERRORS`. All seven package targets share both remaining Swift 6 upcoming features and `.treatAllWarnings(as: .error)` without configuration restrictions. Native Debug/Release builds exercise the six libraries; the standalone probe also builds through Xcode MCP and passes fresh process recovery. |
| Separate persistent Debug/Release stores | Passed on native replacement | Actual native Mac launches without UI-test mode: Release PID 96200 and Debug PID 97086 opened SQLite/WAL/SHM files in their respective bundle-ID containers. See [native evidence](evidence/native-2026-10-24.md). |
| README and test review | Updated | Canonical Reader source and guides are English; German UI/error translations live in String Catalogs with tested plural forms. Native project, code-test emphasis, compiler policy, Debug launch default and evidence are documented. Superseded root-project cleanup is retained in K with user edits preserved. |
| SwiftLint and runner checks | Passed | Whole repository passes SwiftLint 0.65.1 `--strict`. Three Python runner contracts pass. Shell syntax and Actionlint pass, excluding only Actionlint's outdated known-label list for `xcode-27`. |

## Native full-plan baseline with requested compiler settings

Environment: MacBook Pro arm64, macOS 27.0.1 (26A434), Xcode 27.1, Swift 6.4. Interactive builds and tests were executed through Xcode MCP. Full paths and detailed review: [test review](test-review-2026-10-24.md).

| Destination | Distinct tests / executions | Result bundle suffix under `ActionArtifacts/default/RunAllTests/` |
|---|---|---|
| My Mac, macOS 27.0.1 | 86 / 99 | `Test-Reader-2026.10.24_21-17-27-+0200.xcresult` |
| iPhone Duo, iOS 27.1 Simulator | 85 / 98 | `Test-Reader-2026.10.24_21-22-12-+0200.xcresult` |
| iPad Pro 13-inch (M5), iOS 27.0 Simulator | 85 / 98 | `Test-Reader-2026.10.24_21-22-56-+0200.xcresult` |

Counts come from each xcresult bundle's summary and device execution count. The MCP's inline iOS count incorrectly includes the Mac-only second-window test. No nonexistent iOS test is counted as acceptance.

The subsequent test-fixture cleanup replaces all remaining unchecked continuation gates with a shared bounded, cancellation-aware actor and adds two gate contracts. Current suite-scoped Mac and iPad runs verify all 86 code tests / 99 executions; iPhone verifies the full plan, 87 distinct tests / 100 executions. Use the original DerivedData bundles where an MCP-exported copy lacks Info.plist. Exact paths and the failed local Mac UI activation result are in the [native evidence](evidence/native-2026-10-24.md). App/library/UI-test source is unchanged by this fixture-only step. Its [hosted rerun at f5f502957](https://github.com/mpwg/NetNewsWire/actions/runs/40130440777) is green on all three platforms.

The first Mac window appears automatically without Command-N. The second-window test keeps both connection sheets open and verifies independent drafts and cancellation. A hosted Mac failure showed completely overlapping windows on its small display; native Command-backtick cycling now replaces the obscured-window click, with a bounded hittability wait. Run 40126819993 passed Mac but failed to start parallel Simulator clones. After disabling parallel target clones, run 40128954068 passed all three jobs. The newer fixture cleanup is also green on all platforms in [run 40130440777](https://github.com/mpwg/NetNewsWire/actions/runs/40130440777) at f5f502957. No tests are omitted. The former direct-AX diagnosis was invalid: a sandboxed runner's `AXIsProcessTrusted=false` does not establish XCTest automation-service permissions. Removing the `-ApplePersistenceIgnoreState YES` launch argument fixed the suppressed initial window. The owner enabled Xcode Helper, but this alone is not claimed as the fix. The later local activation failure has not been diagnosed as a permission block. VoiceOver and broad accessibility acceptance remain separate.

Approachable Concurrency initially exposed mixed cached module signatures and a further FreshRSS fixture task capture. After consistent package settings and full code-target recompilation, normal incremental builds and the full test plan pass. Temporary recompilation settings were removed. Compiler warning promotion remains enabled; Apple's build tool can still report skipped App Intents metadata extraction when the app has no AppIntents dependency.

## B / #47: persistence evidence

The existing ReaderStore implementation is unchanged. Commit `929b7b830` added a deletion-only query/count/retention contract and a separate executable using the shipping store.

| Criterion | Status | Evidence |
|---|---|---|
| Durable state after abrupt process termination | Passed on documented Mac core | Seed process killed with SIGKILL after commit marker, WAL 271,952 bytes. Two new native processes verify 10,000 synthetic articles, account, exact pending UUIDs, preferences, rollback and digest revision. |
| One complete canonical article version | Passed | Recovery checks title, HTML/text, URL, publication date and original arrival time together. The corresponding code contract passes across all three native destinations. |
| Deletion-only queries/counts and retained originals | Passed | Code test checks committed revision, removed identities and unread/star counts. Recovery retains the two originals protected by pending/star/digest references after unsubscribing, then verifies another process restart. |
| README | Updated | [B evidence](evidence/b-2026-10-24.md), [raw report](evidence/b-recovery-2026-10-24.json), module and Reader guides. |

B is accepted on 2026-10-25 after dependency A. Current hosted recovery at 2be912aef again verifies 10,000 articles, exact pending revisions, rollback and retained originals: seed PID 34418 exits -9, recovery/reopen PIDs 34422/34428 exit 0. [Current report](evidence/b-ci-recovery-2026-10-25.json) · [B criteria and scope](evidence/b-2026-10-25.md). All 25 persistence contracts pass on the current native destinations. The process probe is core recovery evidence, not full application UI recovery, physical-device behavior or real FreshRSS synchronization.

## Work-package matrix

| Package | Implemented or exercised evidence | Still open |
|---|---|---|
| A / #46 | Accepted 2026-10-25 at 2be912aef: native OS-27 foundation, Debug/Release namespaces, real tests, compiler policy, failure contracts and saved Debug default | No remaining A criterion. K retains infrastructure retirement and sustained reliability; physical-device signing remains open. |
| B / #47 | Accepted 2026-10-25 after A: 25 persistence contracts and current 10,000-article SIGKILL recovery, exact revisions, rollback, retention and complete canonical content | No remaining B core criterion. Complete persistent-app UI restart, device and real service evidence remain separate. |
| C / #48 | At 449d59abc, queue/own-commit and real-store HTTP contracts pass: 111 code functions + three UI tests / 176 Mac executions; Reader CI 40189552390 passes. #5/#17/#21/#22/#25 accepted for corresponding replacement contracts. A journaled real-server round trip between separate native Mac stores/sessions verifies propagated read state, restored original flag and empty outboxes | C stays open for separate-device and actual offline/restart acceptance; the owner deferred the Mac network-off run on 2026-10-25. Mac work may continue on this proved core. Separate dynamic Swift CodeQL fails before analysis. See [C evidence](evidence/c-2026-10-25.md) and [queue/live evidence](evidence/c-queue-2026-10-25.md). |
| D / #49 | Query/detail checkpoint fa7740dc6 passes Reader Mac CI 40197607594. Owner-approved Mac multi-selection and shared actions are implemented. Current full native Mac plan passes 119 code functions plus four UI tests / 193 executions, including captured keys/revisions, filter reconciliation and native Shift-Down/context-menu/exact two-change observation | Current multi-selection hosted confirmation, confirmed bulk-feed action, native delayed-query input, broader state/counter checks and final platforms remain open. Earlier local full-plan initialization failure and incorrect MCP inline count remain preserved. See [D evidence](evidence/d-2026-10-25.md). |
| E / #50 | Scene state, shared/debounced refresh, Mac automatic first window and simultaneous independent connection sheets | iPad multiwindow, resizing, RTL, complete keyboard, VoiceOver and Dynamic Type acceptance. |
| F / #51 | Nine content/OPML contracts: local extraction without page scripts, relative links, HTTP 403, timeout, changing content, size limits and atomic stale-write rejection | Real blocked pages, varied HTML/media and native reader rendering on target devices. |
| G / #52 | Mac/service criteria fulfilled at 10b5777d7: full local plan 101 code functions + three UI tests / 143 executions; Mac CI 40186614810 passes. Native task ownership repairs observed transport retention; three full graph outcomes and completed/cancelled image paths release all weak references. Credential errors, recovery cancellation and chunk bounds pass. After owner permission, live Keychain retrieval and real 32×32 thumbnail pass. #16/#30/#37/#38 closed for Reader replacement | G stays open for deferred final scope; #10 awaits platform revalidation. C may proceed with current Mac dependency evidence. Final iPhone/iPad checks and broad energy acceptance remain open. See [lifetime evidence](evidence/g-lifetimes-2026-10-25.md) and current G evidence. |
| H / #53 | Nested OPML paths, homepage fallback, redirects, repeat imports and concurrent preference preservation | Confirm against real FreshRSS; remote categories remain flat with local hierarchy metadata. |
| I / #54 | Prior local Foundation Models experiment with two synthetic offer sources; dynamic budgets, structured sources and live consent | Apple PCC entitlement/provisioning and native PCC acceptance; broad language, long-text and quality evaluation. |
| J / #55 | Nine digest/fixture contracts including 250 sources, partial coverage, source revision, consent revocation and shared job ownership | Real Preisjäger feed and representative news quality, model/error variants and editorial review. |
| K / #56 | Mapping of all 40 audit findings, new dependency graph and retained legacy inventory | Complete replacement acceptance before removing legacy targets/code; physical devices, accessibility, sustained load and distribution. |

## Historical experiments and limits

Separate current CI limit: GitHub-managed dynamic Swift CodeQL fails before analysis in run 40187588904 at 3a8ead9a5 and again in 40188090219 at 5e24292c8, with preload_tracer/autobuild exit 139; its four other language jobs pass. Reader test CI success does not prove repository-wide CI or Swift security-analysis success. No CodeQL configuration is disabled or changed. [Exact observed scope](evidence/c-2026-10-25.md#separate-repository-ci-limitation).

Three local model calls with two synthetic offers produced two sourced sections with correct merchants/prices, around 1.6–1.7 seconds per inference. This is a narrow functional experiment, not systematic quality acceptance. A synthetic PCC probe reported availability but terminated when requesting without `com.apple.developer.private-cloud-compute`; the normal build therefore blocks the request before calling that API. Availability alone is not authorization.

A previous 10,000-article core load experiment measured insertion 0.82 s, first 200 articles 0.006 s, normalized search 0.007 s and 1,000 status changes 1.97 s. It did not compare legacy behavior or measure scrolling, energy or devices.

The owner explicitly closed 21 excluded audit issues as not planned: #2, #3, #4, #6, #7, #8, #9, #11, #13, #14, #18, #19, #20, #23, #24, #27, #28, #31, #32, #35 and #36. Superseded proposal #42 is not planned; #43/#44 are completed reports. These closures are not repairs or evidence of removed legacy code. Of the original 19 mapped findings, #5/#16/#17/#21/#22/#25/#30/#37/#38 are accepted for the Reader replacement; the remaining ten findings and nine implementation packages require criterion-specific evidence before closure.

Audit #37/#38 were accepted at ea7e60fbe with explicit HTTP ordering/fallback evidence. #16/#30 were accepted at 10b5777d7 with complete service-release, controlled OS-error and cancellation evidence. #21/#22/#25 were accepted at 5e24292c8 with mutation errors and real-store status/folder contracts; #5/#17 at 449d59abc with actual queue-state/response order, cancellation repair and overlapping commit proof. All include current native Mac/Reader-CI evidence. These closures do not claim changes to retained legacy modules or completion of deferred platform acceptance.

Temporary result bundles can expire. Source fixtures, reproduction instructions and the recovery JSON are versioned. Continue from the [handoff](handoff-2026-10-24.md), preserving the existing implementation and unrelated user changes.
