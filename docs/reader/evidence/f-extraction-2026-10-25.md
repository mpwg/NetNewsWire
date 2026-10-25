# F / #51: extraction publication and ownership — 2026-10-25

## First stable code checkpoint

Eight new Swift Testing functions / sixteen executions exercise the shipping ReaderSession, ArticleContentService, real ReaderStore and isolated URLSession transport. The first fourteen-case run reproduces eight failures: old success can cache after selection changes, A→B→A accepts old error/success, older requests alter newer outcomes, and pre-cancelled/in-flight cancellation surfaces an alert. [Raw initial result](f-extraction-red-2026-10-25.json), original 16-24-46. Two additional contracts verify independent detail-lookup generations and full-text error/retry state.

ReaderSession now distinguishes selection generations from detail lookup and extraction request generations. It validates the current request/selection/cancellation before caching, after the awaited atomic save and before publishing errors. Current success and HTTP failure still publish; status/outbox state remains untouched. A persistent, localized warning identifies saved feed content when full text is unavailable; changing selection or retrying clears only that extraction warning.

The ArticleDetailView button now starts a view-owned task through task(id:), rather than an unstructured Task. Disappearance cancels extraction and explicitly stops WebPage resource loading. WebPage errors check cancellation and article identity before presentation. Source ownership has changed; actual native disappearance/page release remains a separate required check.

The final native Mac plan for this first checkpoint passes **142 Swift Testing functions plus six UI methods / 243 executions**, 148 distinct tests, 36 parameterized functions / 131 cases, no failures/skips/runtime warnings. [Raw current result](f-extraction-core-native-2026-10-25.json), original `/Users/mat/Library/Developer/Xcode/DerivedData/Reader-fuevgxanyutuuihcfejpioljllaa/Logs/Test/Test-Reader-2026.10.25_16-29-43-+0100.xcresult`. Strict SwiftLint and diff checks pass. Xcode authoring/build/tests use Xcode MCP; compiler/concurrency policy remains enabled.

## After-parsing delivery checkpoint

ReaderContent now exposes the small Sendable ArticleContentExtracting protocol; the shipping actor conforms without changing its parser/network behavior. ReaderServices accepts that port. Tests wrap the real service, capture its fully computed success or failure, then hold delivery. B completes its own extraction before A is released. The held adapter does not replace the parser, store or transport.

Restoring the old publication implementation in a controlled run makes the specifically selected parsed-success case fail: A caches after B completes and the service revision incorrectly increases from one to two. The selector executes one case, not both parameter values; [its raw failure](f-after-parsing-red-2026-10-25.json) is preserved. The repaired suite-level run exercises every case, including delayed failure. The fixed implementation was restored before final verification.

The complete extraction suite now has **nine Swift Testing functions / twenty executions**. It includes cancellation after parsing and weak release of the held-result adapter as well as the six original graph objects. Combined extraction/session/content/lifetime suites pass 61 executions at 16-34-50; the final extraction-only run after whitespace formatting passes all twenty at 16-40-27.

The current full native Mac plan at **16-36-58** passes **143 Swift Testing functions plus six unchanged UI methods / 247 executions**, 149 distinct tests and 37 parameterized functions / 135 cases, zero failures/skips/runtime warnings. [Raw final summary](f-after-parsing-full-native-2026-10-25.json). Strict SwiftLint and diff checks pass. [Reader Mac CI 40208187456](https://github.com/mpwg/NetNewsWire/actions/runs/40208187456) passes at 7d433f6fe: all 143 Swift Testing functions in 23 suites, all 135 parameter-case starts, all six native UI methods, direct runner bootstrap, 10,000-article process recovery and strict SwiftLint. No new UI case substitutes for these code-testable contracts. Recovery seed PID 5193 exits -9; recover/reopen PIDs 5330/5334 exit 0. The normal Debug app was restored through Xcode MCP, PID 4446.

## Criteria and next evidence

| Criterion | Status | Evidence or next check |
|---|---|---|
| Current and stale extraction publication | Fulfilled in the controlled HTTP cases | Late success/failure, A→B→A, overlapping requests including a newer failure, current outcomes and same-selection detail lookup. The subsequent real-parser result gate also verifies the precise after-parsing/before-delivery boundary, including B finishing before A resumes. |
| Code cancellation and graph release | Fulfilled | Before-request/in-flight/post-parsing cancellation ends while its corresponding gate remains held, without cached content/revisions/alerts. Weak references to session, services, content, store, server, transport and the optional held-result adapter disappear after success/failure/cancellation. The adapter weak reference is nonnil in the post-parsing cancellation case; the other six objects are checked across success, failure and both active cancellation stages. |
| Actual native view/WebPage lifetime | Open | Source task ownership is corrected; native disappearance, page release and rendering still need their own evidence. |
| Restricted source coverage | Open | Current HTTP failure records a warning; changing selection/retry clears it. Native saved-content/warning rendering is still open. English source text and German catalog translation are present. |
| Parser/network/offline/rendering | Open beyond existing contracts | Existing parser/403/timeout/relative-link/stale-store checks remain; add malformed/varied native content and exact lifecycle evidence. The actual Mac network-off run remains deferred by the owner. |
| Hosted confirmation of this code checkpoint | Fulfilled | [Reader Mac CI 40208187456](https://github.com/mpwg/NetNewsWire/actions/runs/40208187456) passes at 7d433f6fe: all 143 Swift Testing functions in 23 suites, all 135 parameter-case starts, all six native UI methods, direct runner bootstrap, 10,000-article process recovery and strict SwiftLint. |
| Final platforms | Open | iPhone/iPad/accessibility remain deferred; physical devices need signing. |

F and mapped #33/#34 remain open. These checkpoints are not complete F acceptance or proof of native page deallocation or actual offline operation. The result-delivery gate is now proved; native rendering/lifetime, malformed-page variants and deferred platforms remain next.

Separate security-analysis result: [CodeQL run 40208186963, Swift job 121213555275](https://github.com/mpwg/NetNewsWire/actions/runs/40208186963/job/121213555275) fails before analysis with preload_tracer/autobuild exit 139. The other three language jobs pass. K/#56 retains the tracer problem; passing Reader tests do not prove Swift security-analysis success.
