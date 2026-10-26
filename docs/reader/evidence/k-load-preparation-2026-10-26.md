# K: isolated native load preparation — 2026-10-26

## Status

The synthetic workload and one native scrolling measurement are exercised. Full representative latency, scrolling, whole-app memory and energy acceptance remains **open**. The first scrolling checkpoint passes its metric case but fails a separate existing UI assertion; its corrected modal-diagnostic check requires a fresh full run.

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
| Shipping store/query workload checks | Passed for synthetic code contract | Both 1,000- and 10,000-record cases pass in Reader CI 40245263068 at faaefe391. The 10,000 case initially expects an unbounded repository query, but ReaderStore deliberately caps each page at 1,000. The corrected check reads bounded pages and verifies exact full key order/count plus an empty tail, then exercises All/Unread/Starred/feed/folder/body-search and two-page transitions through ReaderSession. [Scoped original failure](k-load-fixture-single-query-red-2026-10-26.json). The repository contract is unchanged. |
| Actual workload entry / visible rows | Passed for synthetic hosted scope | At 7c3890d04 the native metric case observes committed 10,000/100/10 counts, a visible first row, actual down/up movement and return. The window attachment shows the normal 200-row initial page. This is not launch-latency acceptance. |
| Whole-app performance / energy | Open | Scoped hosted scrolling/app-process samples are recorded below. Representative hardware/data, a performance budget, sustained article/WebKit load, hitches, startup and energy remain unaccepted. |
| Representative real-account load | Open | This documented synthetic workload does not establish representativeness for the owner's actual feed history. |
| Final release/device coverage | Open | DEBUG/macOS guards are source evidence; no new Release or final iPhone/iPad run is claimed. |

The new code contract uses the shipping SwiftData store and session, without app hosting or XCUIAutomation. It checks complete stored coverage and the same query transitions at 1,000 and 10,000 records. A generic oversized collection-diff diagnostic from the rejected first check is omitted from the scoped failure record; counts and the first exact failure are retained. The original result bundle is named there. No assertion is disabled or marked as expected failure.

### Hosted preparation checkpoint

[Reader CI 40245263068](https://github.com/mpwg/NetNewsWire/actions/runs/40245263068) passes at faaefe3915b2f3c112fc5fbbfe369fa435bcf104. Test job 121325366786 records 198 Swift Testing functions in 33 suites, including both corrected workload cases; eight existing UI methods also pass. The [raw native summary](k-load-preparation-ci-2026-10-26.json) records **403 executions: 395 code and eight UI**, 206 distinct tests, 69 parameterized functions / 266 cases, zero failures/skips and one deliberate model-guardrail runtime warning. Strict lint and runner failure propagation pass. The separate [10,000-article process-recovery receipt](k-load-preparation-ci-recovery-2026-10-26.json) passes SIGKILL/reopen/verify. The hosted native device is an arm64 virtual Mac running macOS 27.0.1. This checkpoint contains no scrolling measurement method and does not accept whole-app performance or energy.

The [raw workload case detail](k-load-preparation-ci-cases-2026-10-26.json) confirms both argument values and passed results. Their roughly 0.42 s and 5.80 s durations cover the entire code contract, including setup and assertions; they are not isolated query-latency measurements.

The first attempted absolute workspace path is rejected by this GUI MCP bridge; the tool is then called with the verified native workspace identifier. In that code-only test action, Xcode ends the prior normal Reader process even though ReaderTests itself is unhosted. Reader is restored normally via Xcode MCP, PID 53387. Later build/lint checks leave that process alive. Further local test actions are deferred during the manual VoiceOver request; the corrected code contract is handed to hosted CI. No normal store or server fixture is changed.

## Measurement boundaries still to implement and exercise

### Native scrolling case executed; full checkpoint failed

The next measurement step adds exactly one Mac-only native UI method, testLoadedTimelineScrollingMetrics. Code-testable workload/query rules remain in the parameterized Swift Testing contract. This method requires the actual app window, visible native list and scroll input.

It launches only the isolated load mode, waits for committed fixture counts and the visible first row, verifies that scrolling moves that row out of view and back, then records five down/up cycles with XCTClockMetric, XCTCPUMetric(application: app) and XCTMemoryMetric(application: app). A window-only screenshot follows the measurement. Workload ingestion and the initial scroll warmup are outside the measured interval. Standard XCTest measurement checks are retained; no tolerance or compiler warning policy is weakened.

The store contains 10,000 records, while the normal initial ReaderSession page exposes 200 rows. The scroll case stays within that page; it does not claim to render all 10,000 rows or time pagination. XCTest also performs one discarded warmup iteration before the five recorded iterations. XCTMemoryMetric documents the physical-memory difference before/after a measured block; any returned metric must be interpreted by its actual identifier and unit, not automatically described as peak or total resident memory. There is no committed regression baseline or product performance budget yet.

The separate [CodeQL run 40246136504 / Swift job 121327988407](https://github.com/mpwg/NetNewsWire/actions/runs/40246136504/job/121327988407) at 7c3890d04 fails before analysis. CLI 2.27.3 on macos-26-arm64 image 20261013.0424.1 again reports preload_tracer/autobuild exit 139. The Actions, Python and JavaScript/TypeScript jobs pass. The exact crash cause remains unproved; the independent documented SDK-27 support gap and unchanged security settings are described in [CodeQL compatibility evidence](k-codeql-compatibility-2026-10-25.md). Reader test success cannot establish complete repository CI/security-analysis success.

Xcode MCP build-for-testing at 00:36:20 succeeds and discovery reports 207 enabled functions/methods, zero disabled. [Reader CI 40246136595](https://github.com/mpwg/NetNewsWire/actions/runs/40246136595), source 7c3890d04edbf7b72a0c377588516fa11f9f9f53, executes the new native metric case successfully. The [raw metric samples](k-load-scrolling-metrics-2026-10-26.json) and [window-only screenshot](k-load-scrolling-2026-10-26.png) are preserved. The clock result includes driver/interaction time and must not be reported as app-internal query latency. These list-only measurements cannot accept article/WebKit load, cold persistent startup, hitches, energy or the owner's real-account workload.

| Recorded metric | Five-sample mean | Observed range / limit |
|---|---|---|
| Clock Monotonic Time | 5.068 s per down/up pair | 4.326–5.654 s; includes automation. |
| Reader CPU Time | 4.609 s per pair | 3.839–5.203 s; CPU is not energy. |
| Reader Memory Peak Physical | 256,389.670 kB | 251,153.344–261,245.888 kB; actual physical_peak identifier. |
| Reader Absolute Memory Physical | 244,177.037 kB | 238,488.512–249,629.632 kB. |
| Reader Memory Physical change | 3,224.371 kB | 1,409.024–4,980.736 kB; short-run growth is not a leak diagnosis. |
| CPU instructions/cycles | All zero | Not usable as evidence of actual instruction/cycle consumption. |

The arm64 hosted device is an OS-27.0.1 virtual Mac, running Debug. The raw log reports relative standard deviations of 11.309% for clock, 12.523% for CPU time and 48.009% for physical-memory change; the method nevertheless passes without a baseline. Do not describe its success as an enforced variance/regression budget or calibrated product performance acceptance.

The app CPU sample also includes work requested by automation, including resolving accessible elements. This method does not separate scrolling/rendering CPU from accessibility-query overhead. Frame cadence and user-perceived scroll smoothness require a separate suitable rendering measurement; the elapsed pair duration is not a frame-time statistic.

The [full raw summary](k-load-scrolling-ci-red-2026-10-26.json) remains **failed**: 403 passed executions, one failed execution, no skips. All 395 code executions and eight of nine UI methods pass. Lint, runner propagation and the separate [process-recovery check](k-load-scrolling-ci-recovery-2026-10-26.json) pass. The failure is the existing delayed-query UI method, at a background counter read while the native feed-read confirmation is open. The [recorded failure frame](k-load-delayed-confirmation-red-2026-10-26.png) visibly retains counter 20 and zero writes; the [query diagnostic](k-load-delayed-confirmation-query-2026-10-26.txt) contains only the unresolved background lookup chain. No changed count is evidenced.

The correction moves the unchanged-query and zero-feed-write observations after Cancel, explicitly waits for the dialog to close, and retains zero pending changes. It verifies the complete menu/dialog/cancellation interval once native background controls are accessible again. The actual confirmation/300-row commit and held-query interaction assertions remain. No counter tolerance or deadline is increased and no assertion is marked expected or skipped. Xcode MCP build-for-testing at 00:57:03 and strict lint pass; a fresh full hosted run is required. The normal Reader PID 53387 remains alive; no local test action interrupts the pending manual VoiceOver journey.

Apple's app-targeted [XCTMemoryMetric](https://developer.apple.com/documentation/xctest/xctmemorymetric/init(application:)) and [XCTCPUMetric](https://developer.apple.com/documentation/xctest/xctcpumetric/init(application:)) select the app process; their parameterless forms measure the caller. A UI-runner measurement must not be reported as Reader memory/CPU. [Launch responsiveness](https://developer.apple.com/documentation/xctest/xctapplicationlaunchmetric/init(waituntilresponsive:)) and [scrolling metrics](https://developer.apple.com/documentation/xctest/xctossignpostmetric/scrollinganddecelerationmetric) require actual platform execution and usable samples before acceptance.

Workload generation/ingestion must be excluded from warm interaction/scroll intervals and reported separately. The in-memory entry does not prove cold persistent-store startup or disk performance. CPU measurements are not energy acceptance. Actual UI observations, comparable hardware/run conditions, raw measurements and the separate energy method remain required. Business-rule matrices continue to use Swift Testing; app input/rendering and XCTest measure APIs retain their native boundaries.

## Code timing attachments compiled; execution pending

The existing parameterized Swift Testing function now prepares a JSON attachment for each 1,000/10,000-record case. ContinuousClock samples applyRefresh separately, then each direct ReaderSession reload and loadMore call. Assertions and expected-array construction are outside those operation intervals. No extra test function or UI method is added, and no threshold replaces correctness checks.

These are single observations, not medians or a regression benchmark. Full stored-coverage reads precede the query loop, so the session measurements use a warm in-memory store. reload includes metadata, repository queries and row construction; it excludes app rendering, automation input and service synchronization. The attachment labels those boundaries explicitly. Factory/account setup is outside the ingestion interval. No runtime samples from this addition are claimed yet.

Native warnings-as-errors initially reject an unnecessary Decodable synthesis for constant report metadata; the payload types require only Encodable and are corrected accordingly. Xcode MCP build-for-testing at 01:02:09 and strict lint then pass. The normal Reader PID 53387 stays alive. These changes remain outside the currently running c29d13483 checkpoint and require their own hosted verification after that run completes.
