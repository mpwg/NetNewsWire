# K: isolated native load preparation — 2026-10-26

## Status

Preparation only. The required latency, scrolling, whole-app memory and energy measurements remain **open**. A compiled Debug entry and workload correctness checks do not accept those criteria.

The new workload uses 100 synthetic feeds, ten folders, 20 root feeds and a default 10,000 articles spanning roughly seven days. Titles, bodies, IDs, dates and mixed read/star memberships are deterministic. Each body contains passive HTML/text; a sparse marker exercises body search. Feed homepages are nil, so icon requests are not started by these records. Data contains no credentials, account tokens or external article resources.

## Native entry

In Mac Debug only, use both --ui-testing and --ui-testing-load. The existing test-mode store is in-memory. Bootstrap returns ReaderServices(repository: store) before constructing Keychain credentials, FreshRSS, content-extraction or intelligence clients. The load factory is guarded by DEBUG; the app fixture/panel additionally require macOS. No package target, project, scheme or test plan is generated or added.

The panel exposes loadFixturePhase and loadFixtureCounts. A ready phase means the data commit completed, **not** that the first article frame is rendered. Actual performance capture must separately wait for visible rows, exercise the normal UI and measure the app process. Normal launches have no workload fixture.

New source files and edits use Xcode MCP. Its first Package-file write reports an insertion-mode error after physically creating the Swift file. The package graph initially misses the type. A native manifest-comment edit triggers normal reevaluation; subsequent native builds succeed. No filesystem generator or direct project-file editing is used.

## Verification so far

| Criterion | Status | Evidence |
|---|---|---|
| Native build including test targets | Passed | Xcode MCP build-for-testing succeeds at 00:29:47; warnings remain errors. |
| Strict lint / whitespace | Passed | Whole-repository strict SwiftLint and git diff validation pass. |
| Correctness test discovery | Passed | 206 enabled functions/methods, zero disabled. One parameterized Swift Testing function adds two executions; no UI method is added. |
| Shipping store/query workload checks | Initial fixture failure corrected; rerun pending | The 1,000-record case passes. The 10,000 case initially expects an unbounded repository query, but ReaderStore deliberately caps each page at 1,000. The check now reads bounded pages and verifies exact full key order/count plus an empty tail, then exercises All/Unread/Starred/feed/folder/body-search and two-page transitions through ReaderSession. [Scoped original failure](k-load-fixture-single-query-red-2026-10-26.json). The repository contract is unchanged. |
| Actual workload entry / first frame | Open | The new launch mode has been compiled but not launched locally while the owner's VoiceOver journey is pending. |
| Whole-app performance / energy | Open | No current-source latency, scroll, footprint, hitch or energy result is claimed. |
| Representative real-account load | Open | This documented synthetic workload does not establish representativeness for the owner's actual feed history. |
| Final release/device coverage | Open | DEBUG/macOS guards are source evidence; no new Release or final iPhone/iPad run is claimed. |

The new code contract uses the shipping SwiftData store and session, without app hosting or XCUIAutomation. It checks complete stored coverage and the same query transitions at 1,000 and 10,000 records. A generic oversized collection-diff diagnostic from the rejected first check is omitted from the scoped failure record; counts and the first exact failure are retained. The original result bundle is named there. No assertion is disabled or marked as expected failure.

The first attempted absolute workspace path is rejected by this GUI MCP bridge; the tool is then called with the verified native workspace identifier. In that code-only test action, Xcode ends the prior normal Reader process even though ReaderTests itself is unhosted. Reader is restored normally via Xcode MCP, PID 53387. Later build/lint checks leave that process alive. Further local test actions are deferred during the manual VoiceOver request; the corrected code contract is handed to hosted CI. No normal store or server fixture is changed.

## Measurement boundaries still to implement and exercise

Apple's app-targeted [XCTMemoryMetric](https://developer.apple.com/documentation/xctest/xctmemorymetric/init(application:)) and [XCTCPUMetric](https://developer.apple.com/documentation/xctest/xctcpumetric/init(application:)) select the app process; their parameterless forms measure the caller. A UI-runner measurement must not be reported as Reader memory/CPU. [Launch responsiveness](https://developer.apple.com/documentation/xctest/xctapplicationlaunchmetric/init(waituntilresponsive:)) and [scrolling metrics](https://developer.apple.com/documentation/xctest/xctossignpostmetric/scrollinganddecelerationmetric) require actual platform execution and usable samples before acceptance.

Workload generation/ingestion must be excluded from warm interaction/scroll intervals and reported separately. The in-memory entry does not prove cold persistent-store startup or disk performance. CPU measurements are not energy acceptance. Actual UI observations, comparable hardware/run conditions, raw measurements and the separate energy method remain required. Business-rule matrices continue to use Swift Testing; app input/rendering and XCTest measure APIs retain their native boundaries.
